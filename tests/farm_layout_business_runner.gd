extends "res://tests/runner.gd"
## 隔离的实际主场景：只注入布局，不走材料/剧情结算；验证业务读取同一物理位置。
var original: Dictionary
var layout_seed: Dictionary
var capture_mode: bool=false
var captures: Array=[]
func run() -> void:
	capture_mode="--capture" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	check(is_instance_valid(game.get("farm_layout_world")),"真实主场景完整初始化农场布局控制器，无半初始化验收")
	original=FarmSaveStore.snapshot(game);layout_seed=FarmLayout.snapshot()
	game.tutorial.restore(GameTutorial.defaults(true));game.change_location("farm",Vector2(800,600));await frames(3)
	await utility_points()
	await animal_coordinates()
	await story_coordinates()
	await secondary_coordinates()
	await housing_diy()
	await atlas_coordinates()
	tracking_coordinates()
	FarmLayout.restore(layout_seed);check(FarmSaveStore.restore(game,original),"专项结束恢复全部经营和布局种子，无真实存档写入")
	var output:=FileAccess.open("res://builds/farm-layout-business-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checked,"failures":failed,"platform":DisplayServer.get_name(),"captures":captures,"android_device_tested":false},"\t"));output.close()
	print("FARM LAYOUT BUSINESS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.2).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func fixture(id: String, delta: Vector2i=Vector2i(3,1), stored: bool=false) -> void:
	var data:=FarmLayout.defaults()
	var cell: Vector2i=Vector2i.ZERO
	# catalog定义是原锚点；seed无override时cell()正好是其默认原格。
	FarmLayout.restore(layout_seed,false);cell=FarmLayout.cell("fixture",id)+delta
	data=layout_seed.duplicate(true);data.fixtures[id]={"cell":[cell.x,cell.y],"stored":stored};FarmLayout.restore(data)
func at(point: Vector2) -> void:
	game.auto_move.cancel();game.player.position=point;game.player.velocity=Vector2.ZERO;game.player.auto_direction=Vector2.ZERO
func utility_points() -> void:
	var before: Dictionary={"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"stamina":GameState.stamina,"kitchen":Kitchen.snapshot(),"recovery":Recovery.snapshot(),"fish":Aquaculture.snapshot()}
	var checks: Dictionary={"berry":func(): return Kitchen.near_berry(),"recovery":func(): return Recovery.near_bench(),"yard":func(): return Housing.near("farm"),"ecology":func(): return LakeEcology.near(),"pen_1":func(): return Aquaculture.near_pen("pen_1"),"coop":func(): return Livestock.near_site("coop"),"fishing_farm":func(): return Fishing.near_site("farm_lake"),"festival_spring":func(): return Festival.near_board("spring")}
	for id in checks:
		FarmLayout.restore(layout_seed);var old:=FarmLayout.point(id)
		fixture(id);await frames(3);at(FarmLayout.point(id))
		check(checks[id].call(),"移动后原业务入口跟随新坐标："+id)
		var points: Array=[]
		for point in get_tree().get_nodes_in_group("interactables"):
			if point.get_meta("farm_fixture","")==id: points.append(point)
		var correct: bool=not points.is_empty()
		for point in points: correct=correct and point.global_position.distance_to(FarmLayout.point(id))<.01
		check(correct,"现有交互节点实际移动到原业务新位置："+id)
		at(old);check(not checks[id].call(),"原址不保留幽灵业务入口："+id)
		fixture(id,Vector2i(3,1),true);await frames(3);at(FarmLayout.point(id))
		check(not checks[id].call() and is_finite(FarmLayout.point(id).x),"收纳拒绝原业务交互且坐标仍有限："+id)
		var hidden: bool=true
		for point in points: hidden=hidden and not point.visible
		check(hidden,"收纳隐藏原交互节点："+id)
	FarmLayout.restore(layout_seed)
	check(Inventory.coins==before.coins and Inventory.items==before.items and GameState.stamina==before.stamina and Kitchen.snapshot()==before.kitchen and Recovery.snapshot()==before.recovery and Aquaculture.snapshot()==before.fish,"单纯移动收纳不扣材料、不重复恢复、不改变鱼栏或料理业务状态")
func animal_coordinates() -> void:
	var old:=Livestock.snapshot();Livestock.state.buildings.coop.level=1
	var entry: Dictionary=Livestock._new_animal("coop");var logical:=Vector2(entry.position[0],entry.position[1]);Livestock.changed.emit();await frames(3)
	fixture("coop",Vector2i(4,-1));await frames(3)
	var node: Node2D
	for candidate in get_tree().get_nodes_in_group("livestock_animals"):
		if candidate.animal_id==entry.id: node=candidate;break
	check(is_instance_valid(node) and node.position==logical+FarmLayout.offset("coop"),"原畜舍移动时真实动物使用同一位移，不复制动物")
	check(Vector2(entry.position[0],entry.position[1])==logical and Livestock.validate(Livestock.snapshot(),GameClock.day),"动物保存原逻辑坐标，原严格畜舍范围验证仍通过")
	at(node.position);check(Livestock.near_animal(entry.id),"动物照料用当前位置校验")
	check(FarmLayout.to_logical("coop",node.position)==logical,"动物物理位置回写能精确还原原存档逻辑坐标")
	fixture("coop",Vector2i(4,-1),true);await frames(3)
	check(not node.visible and node.process_mode==Node.PROCESS_MODE_DISABLED and node.collision_mask==0 and not Livestock.near_animal(entry.id),"收纳畜舍保留动物记录并停显示/物理/照料交互")
	FarmLayout.restore(layout_seed);Livestock.restore(old);await frames(3)
func story_coordinates() -> void:
	fixture("star:desk_left",Vector2i(-3,-2));await frames(3)
	var old: Dictionary=StarStory.data.points.desk_left
	check(StarStory.point("desk_left")==Vector2(old.position[0],old.position[1])+FarmLayout.offset("star:desk_left"),"温室研究桌采用自身唯一布局坐标")
	check(WorldTravel.entry("farm")==FarmLayout.transform_point(Vector2(656,440),"home"),"家内返回农场落点读取当前住宅位置")
	var stage: int=Story.stage;Story.stage=1;var minute: float=GameClock.minutes;GameClock.minutes=600
	fixture("shop");check(Vector2(Story.chapter().target[0],Story.chapter().target[1])==FarmLayout.transform_point(Vector2(429,441),"shop"),"教学任务目标随种子摊移动，剧情条件未改")
	Story.stage=stage;GameClock.minutes=minute
	FarmLayout.restore(layout_seed)
func atlas_coordinates() -> void:
	fixture("home",Vector2i(2,-5));var home: Dictionary={}
	for item in FarmAtlasData.region_places("farm"):
		if item.id=="home": home=item
	check(not home.is_empty() and home.world_position==FarmLayout.point("home"),"农场图纸住宅地标跟随唯一实体位置")
	await capture("home_moved")
	fixture("home",Vector2i(2,-5),true);var found: bool=false
	for item in FarmAtlasData.region_places("farm"):
		if item.id=="home": found=true
	check(not found,"收纳住宅后图纸不保留原址图标")
	await capture("home_stored")
	check(FarmAtlasData.picture("farm")=="farm_editable_base" and FarmAtlasData.picture("lake")=="farm_editable_base","农场/湖泊使用无烘焙房屋及水域底图")
	FarmLayout.restore(layout_seed)

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0
	game.hud.atlas_panel.open_panel();game.hud.atlas_panel.show_current()
	await get_tree().create_timer(.3).timeout;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/farm-layout-business-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append(path)
	game.hud.atlas_panel.close_panel();await frames(3)

func tracking_coordinates() -> void:
	var social: Dictionary=Social.defaults(GameClock.day)
	social.active.linya={"id":"linya_1","start_day":GameClock.day,"counts":{},"tracked":{},"seen":[],"meeting_day":0,"missed":false,"repair_ready":false}
	var development: Dictionary=WorldDevelopment.defaults(GameClock.day)
	var festival: Dictionary=Festival.defaults(GameClock.day)
	for y in range(32):
		for x in range(48):
			var key: String="%d,%d" % [x,y]
			social.active.linya.tracked[key]={"crop":"wheat","serial":1}
			development.tracking.farm[key]=GameClock.day
			for action in ["播种","浇水","收获"]: festival.tracking.farm[action+":"+key]="%d:1" % GameClock.day
	check(Social.validate(social,GameClock.day),"1536个合法逻辑农田的社交追踪可以保存，包含原农田外坐标")
	check(WorldDevelopment.validate(development,GameClock.day),"全农场收获追踪可保存，不因60格旧上限拒绝存档")
	check(Festival.validate(festival,GameClock.day),"全农场三类农活4608条去重追踪可保存")
	social.active.linya.tracked.erase("0,0");social.active.linya.tracked["48,0"]={"crop":"wheat","serial":1}
	check(not Social.validate(social,GameClock.day),"扩区后仍拒绝农场范围外的追踪坐标")

func secondary_coordinates() -> void:
	var checks: Dictionary={
		"memory:pond":func(): return StarStory.near_memory("pond"),
		"memory:orchard":func(): return StarStory.near_memory("orchard"),
		"star:desk_left":func(): return StarStory.near_point("desk_left"),
		"star:desk_right":func(): return StarStory.near_point("desk_right"),
		"explore:forest_entry":func(): return Exploration.near_id("forest_entry"),
		"explore:lake_entry":func(): return Exploration.near_id("lake_entry")
	}
	for id in ["cycle","lake_date","summer_sky","winter_window","ecology_after","star_lake"]:
		var site: String=id
		checks["social:"+site]=func(): return Social.near_site(site)
	for id in checks:
		FarmLayout.restore(layout_seed);var old:=FarmLayout.point(id)
		fixture(id);await frames(3);at(FarmLayout.point(id))
		check(checks[id].call(),"独立剧情观察点的新址可交互："+id)
		at(old);check(not checks[id].call(),"独立剧情观察点不残留旧址入口："+id)
		fixture(id,Vector2i(3,1),true);await frames(2);at(FarmLayout.point(id))
		check(not checks[id].call(),"独立剧情观察点收纳后拒绝交互："+id)
	for id in ["pond_high","pond_low"]:
		fixture("river:"+id);await frames(2)
		check(WorldTravel.river_point(id)==FarmLayout.point("river:"+id),"原量尺读取独立布局坐标："+id)
	FarmLayout.restore(layout_seed)

func housing_diy() -> void:
	var previous: Dictionary=Housing.snapshot()
	at(FarmLayout.point("yard"));game.hud.housing_panel.open_panel("yard");await frames(3)
	var panel: Control=game.hud.housing_panel
	check(panel.visible and panel.find_children("*","GridContainer",true,false).is_empty(),"庭院页不生成1380个坐标按钮或超宽网格")
	var entry_found: bool=false
	for button in panel.find_children("*","Button",true,false): entry_found=entry_found or button.get_meta("farm_diy_entry",false)
	check(entry_found,"庭院页提供清楚的农场DIY入口")
	await capture_visible("yard_menu")
	panel._open_farm_editor();await frames(3);at(Vector2(784,592))
	check(game.territory_editor.active and GameState.modal and Housing.farm_editing() and Housing.near("farm"),"从庭院页进入真实DIY后可在远离管理台处布置")
	Housing.state.owned.road=1
	var plots: Dictionary=game.farm.plots.duplicate(true)
	game.farm.plots["22,24"]={"crop":"wheat","days":1,"watered":true}
	check(not Housing.can_place("road","farm",Vector2i(22,24)),"原庭院家具不能压住已开垦的真实田块或作物")
	game.farm.plots=plots
	check(Housing.place("road","farm",Vector2i(22,24)),"DIY可恢复原Housing家具库中的庭院路，不建立第二份物品")
	var item: Dictionary=Housing.state.placed[-1]
	var id: String=item.id
	await frames(3)
	check(Housing.move(id,Vector2i(22,25)) and Housing.placement(id).cell==[22,25],"远离管理台的DIY仍通过原ID移动庭院家具")
	check(Housing.recycle(id) and int(Housing.state.owned.road)==1 and not Housing.recycle(id),"DIY收纳归还原家具库一次，重复收纳无效")
	await frames(3)
	Housing.state.owned.flower=1
	check(Housing.place("flower","farm",Vector2i(22,24)),"DIY可放回原花坛")
	id=str(Housing.state.placed[-1].id);Housing.state.flowers[id]=GameClock.day
	await frames(3)
	check(Housing.move(id,Vector2i(22,25)) and Housing.state.flowers[id]==GameClock.day,"成长花坛全场移动保留原花苗与播种日")
	check(not Housing.recycle(id) and Housing.state.flowers.has(id),"成长花坛不能收纳删除花苗，须先采收或撤回")
	game.territory_editor.cancel();at(Vector2(784,592));GameState.set_modal(true)
	check(not Housing.farm_editing() and not Housing.near("farm"),"普通暂停面板不获得远程布置权限")
	GameState.set_modal(false);Housing.restore(previous);await frames(3)
func capture_visible(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/farm-layout-business-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append(path)
