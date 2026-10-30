extends Node
var checked: int=0
var failed: int=0
var player: Node2D
var atlas: FarmAtlasCanvas
var selected: Array=[]
func check(ok: bool, title: String) -> void:
	checked+=1
	if not ok: failed+=1;print("FAIL: ",title)
	else: print("PASS: ",title)
func _ready() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame
func run() -> void:
	player=Node2D.new();add_child(player);player.position=Vector2(656,440)
	atlas=FarmAtlasCanvas.new();add_child(atlas);atlas.position=Vector2(16,16);atlas.size=Vector2(1248,688);atlas.setup(self)
	atlas.place_selected.connect(func(info: Dictionary): selected.append(info))
	GameClock.running=false;GameState.location="farm"
	var before: Dictionary={"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"exploration":Exploration.snapshot(),"housing":Housing.snapshot(),"mine":MineState.state.duplicate(true),"legend":LegendState.state.duplicate(true),"xiaojing":Xiaojing.state.duplicate(true)}
	await frames(3)
	check(atlas.layer_id=="world" and atlas.places.size()==FarmAtlasData.WORLD_POINTS.size(),"世界图纸仅有实际已有区域和已制作的待开放领地")
	check(atlas.player_map_position()==FarmAtlasData.WORLD_POINTS.farm,"世界玩家标记使用独立区域坐标")
	for id in ["farm","village","lake","home","mist_forest"]:
		check(FarmAtlasData.known(id),"现有默认开放区域："+id)
	for id in ["lake_ruins","old_temple","mine_a","mine_b","mine_c","abyss"]:
		check(not FarmAtlasData.known(id),"默认未开放区域不会伪装已探索："+id)
		atlas.show_region(id);check(atlas.layer_id=="world","不能跳过探索打开秘密详图："+id)
	for info in atlas.places:
		check(info.has_all(["name","description","region","discovered","point"]),"图纸地标字段完整："+str(info.id))
		if info.id in ["lake_ruins","old_temple"]: check(info.name=="尚未探索" and not info.discovered and info.icon=="unknown","秘密名称和建筑图标不提前暴露："+str(info.id))
	for id in ["farm","village","lake","home","mist_forest","mine_a"]:
		var rect:=FarmAtlasData.bounds(id);var point: Vector2=rect.position+rect.size*.37
		check(FarmAtlasData.map_to_world(id,FarmAtlasData.world_to_map(id,point)).distance_to(point)<.001,"独立场景坐标往返："+id)
	atlas.show_region("farm");await frames(2)
	check(atlas.region_id=="farm" and atlas.resources.size()==109,"农场详图有109个稳定采集坐标")
	var marks: Array[Dictionary]=FarmAtlasData.resource_marks("farm",{"tree_5_8":{"hp":0}})
	check(marks.size()==109 and not marks[0].available and marks[0].id=="tree_5_8","耗尽资源以原稳定ID显示恢复状态，不重新生成资源")
	check(atlas.player_map_position()==FarmAtlasData.world_to_map("farm",player.position),"农场玩家标记使用真实脚底坐标")
	var pin:=atlas.player_map_position();var screen:=atlas.map_to_screen(pin)
	check(atlas.screen_to_map(screen).distance_to(pin)<2,"未缩放图纸正反映射")
	atlas.zoom_by(2);atlas.pan_by(Vector2(140,-85));screen=atlas.map_to_screen(pin)
	check(atlas.screen_to_map(screen).distance_to(pin)<2 and atlas.zoom==2,"缩放拖动后位置保持正确")
	atlas.zoom_by(50);check(atlas.zoom==3,"缩放具有上限")
	atlas.zoom_by(.001);check(atlas.zoom==1,"缩放具有下限")
	atlas.pan_by(Vector2(99999,-99999));check(atlas.pan==Vector2.ZERO,"缩至完整纸面时拖动不能丢失图纸")
	atlas.zoom_by(2);atlas.pan_by(Vector2(99999,-99999));var origin:=atlas.map_origin();var extent:=FarmAtlasData.PAPER_SIZE*atlas.map_scale()
	check(origin.x<=12.01 and origin.y>=atlas.size.y-extent.y-12.01,"放大后的拖动边界合法")
	atlas.center_player();check(atlas.player_map_position()==pin,"定位不改变玩家世界坐标")
	atlas.show_region("home");GameState.location="home";player.position=Housing.anchor("sofa");await frames(2)
	check(atlas.player_map_position()==FarmAtlasData.world_to_map("home",player.position),"室内使用房间独立坐标不是农场坐标")
	var sofa: Dictionary={}
	for info in atlas.places:
		if info.id=="sofa": sofa=info
	check(not sofa.is_empty() and sofa.world_position==Housing.anchor("sofa"),"室内沙发标记读取当前家具锚点")
	GameState.location="village";player.position=Vector2(640,756);atlas.show_region();await frames(2)
	check(atlas.region_id=="village" and atlas.player_map_position()==FarmAtlasData.world_to_map("village",player.position),"换场景后详图自动跟随玩家区域")
	var lantern: Dictionary={}
	for info in atlas.places:
		if info.id=="lantern": lantern=info
	check(lantern.name=="风灯架" and lantern.world_position==Vector2(628,524),"风灯架地标和实际场景一致")
	var stage: int=Story.stage;Story.stage=4
	check("尚未修复" in FarmAtlasData.description("village") and not FarmAtlasData.bridge_open() and FarmAtlasData.WORLD_BRIDGE==Vector2(684,288),"修桥前总览纸面桥位和村庄详图同为道路阻断")
	Story.stage=5;check("已经修复" in FarmAtlasData.description("village") and FarmAtlasData.bridge_open(),"修桥后总览和村庄详图同步已通行")
	Story.stage=stage
	for level in range(1,5):
		Housing.state.level=level;Housing.state.builtins=HomeLayout.default_builtins(level)
		var home_icon: String=""
		for info in FarmAtlasData.world_places():
			if info.id=="farm": home_icon=str(info.icon)
		check(home_icon=="house_"+str(level),"住宅升级图标来自当前真实等级："+str(level))
	Housing.restore(before.housing)
	var health: int=LakeEcology.state.health;var restored: bool=LakeEcology.state.restored
	LakeEcology.state.health=95;LakeEcology.state.restored=true
	check("循环已恢复" in FarmAtlasData.description("lake") and "95/100" in FarmAtlasData.description("lake"),"湖泊修复从既有生态状态读取")
	LakeEcology.state.health=health;LakeEcology.state.restored=restored
	for level in range(5):
		LegendState.state.greenhouse=level
		check(("修复阶段%d/4" % level) in FarmAtlasData.description("greenhouse"),"温室修复阶段映射："+str(level))
	LegendState.state=before.legend.duplicate(true)
	Exploration.state.unlocked.append("lake_ruins");atlas.show_world()
	var found: bool=false
	for info in atlas.places:
		if info.id=="lake_ruins": found=info.discovered and info.name=="湖底遗迹"
	check(found,"实地解锁后秘密区域才显示名字")
	Exploration.restore(before.exploration)
	for id in ["farm","village","lake","mist_forest","home"]:
		atlas.show_region(id);check(not atlas.places.is_empty(),"当前区域详图可读取："+id)
	var fish_pens: Array[Dictionary]=FarmAtlasData.region_places("lake")
	var pen_names: Array=[]
	for item in fish_pens:
		if str(item.id).begins_with("pen_"): pen_names.append(item.name)
	check(pen_names.size()==4 and pen_names.has("东岸鱼栏") and pen_names.has("北岸鱼栏"),"同一湖泊的四岸鱼栏有独立明确名称")
	check(Inventory.items==before.items and Inventory.coins==before.coins and GameState.stamina==before.stamina and MineState.state==before.mine and Xiaojing.state==before.xiaojing,"地图查看没有改变物品金币体力矿洞关系")
	GameState.location="farm";player.position=Vector2(656,440);atlas.show_world();await frames(3)
	await gestures()
	if DisplayServer.get_name()!="headless": await captures()
	print("ATLAS CORE RESULT: %d checks, %d failures" % [checked,failed])
	atlas.queue_free();player.queue_free();await frames(3);get_tree().quit(1 if failed else 0)
func touch(index: int, at: Vector2, down: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=atlas.global_position+at;event.pressed=down;get_viewport().push_input(event,true)
func drag(index: int, at: Vector2) -> void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=atlas.global_position+at;get_viewport().push_input(event,true)
func gestures() -> void:
	var at:=atlas.map_to_screen(FarmAtlasData.WORLD_POINTS.farm)
	touch(80,at,true);touch(80,at,false);await frames(2)
	check(selected.size()==1 and selected[0].id=="farm","原生单指轻点识别准确地标")
	atlas.zoom_by(2);at=atlas.size*.5;var old:=atlas.pan
	touch(80,at,true);drag(80,at+Vector2(75,40));touch(80,at+Vector2(75,40),false);await frames(2)
	check(atlas.pan!=old and selected.size()==1,"原生单指拖动只平移，不选择地点")
	var prior_zoom: float=atlas.zoom
	touch(81,at-Vector2(80,0),true);touch(82,at+Vector2(80,0),true)
	drag(82,at+Vector2(130,0));touch(82,at+Vector2(130,0),false);touch(81,at-Vector2(80,0),false);await frames(2)
	check(atlas.zoom>prior_zoom and selected.size()==1 and atlas.fingers.is_empty(),"原生双指缩放不误认地标点击，抬手清理")
	atlas.show_world();at=atlas.map_to_screen(FarmAtlasData.WORLD_POINTS.farm)
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=atlas.global_position+at;get_viewport().push_input(mouse,true)
	touch(83,at,true);touch(83,at,false);mouse.pressed=false;get_viewport().push_input(mouse,true);await frames(2)
	check(selected.size()==1 and not atlas._mouse_down and atlas.fingers.is_empty(),"混合鼠标与触屏不派发额外地点点击")
	check(player.position==Vector2(656,440),"图纸手势不移动玩家世界坐标")
func captures() -> void:
	for id in ["world","farm","village","lake","mine_a"]:
		if id=="mine_a": MineState.state.unlocked=["mine_a"]
		if id=="world": atlas.show_world()
		else: atlas.show_region(id)
		await frames(3);await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image();image.save_png("res://builds/atlas-core-"+id+".png")
		check(not image.is_empty(),"真实窗口保存图纸："+id)
	var old_stage: int=Story.stage
	atlas.show_world();Story.stage=4;await frames(3);await RenderingServer.frame_post_draw
	var old_image:=get_viewport().get_texture().get_image();old_image.save_png("res://builds/atlas-core-world-bridge-before.png")
	Story.stage=5;atlas.refresh_state();await frames(3);await RenderingServer.frame_post_draw
	var new_image:=get_viewport().get_texture().get_image();new_image.save_png("res://builds/atlas-core-world-bridge-after.png")
	var at: Vector2=atlas.global_position+atlas.map_to_screen(FarmAtlasData.WORLD_BRIDGE)
	var patch:=Rect2i(Vector2i(at)-Vector2i(10,10),Vector2i(20,20))
	check(old_image.get_region(patch).get_data()!=new_image.get_region(patch).get_data(),"真实世界总览桥位在修桥前后有不同水面阻断与木桥绘制")
	Story.stage=old_stage
