extends "res://tests/ui04_runner.gd"
## 设施视图只读/实际触区/跨比例专项，所有游戏数据在隔离测试目录。
var capture_mode: bool=false
var before_mode: bool=false
var captures: Array=[]
var seed_state: Dictionary

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	before_mode="--before" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	load("res://tests/star_runner.gd").fixture(game,true)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Inventory.coins=50000;Inventory.items={"carrot":30,"potato":20,"wheat":40,"wood":200,"stone":150,"copper_bar":15,"iron_bar":10,"crystal":10,"hay":30,"fish_feed":30,"fishing_bait":30}
	seed_state=FarmSaveStore.snapshot(game)
	for extent in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4);game.hud.update_safe_area();await frames(4)
		prefix=str(extent)
		await facilities()
	check(FarmSaveStore.restore(game,seed_state),"设施视觉专项结束可恢复原完整游戏进度")
	var file:=FileAccess.open("res://builds/facility-ui07-"+("before" if before_mode else "after")+"-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"android_device_tested":false,"captures":captures,"platform":DisplayServer.get_name()},"\t"));file.close()
	print("FACILITY UI07 "+("BEFORE" if before_mode else "AFTER")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func inspect(panel: Control,args: Array,title: String) -> void:
	var before: Dictionary=FarmSaveStore.snapshot(game)
	panel.callv("open_panel",args);await frames(4)
	await audit(panel,title)
	check(FarmSaveStore.snapshot(game)==before,prefix+" "+title+"打开和查看不扣资源或修改游戏状态")
	if not before_mode:
		check(panel.get_meta("facility_ui07","")!="",prefix+" "+title+"使用统一设施视觉组件")
		if "tab_bar" in panel: await inspect_tabs(panel,title)
	if capture_mode and get_window().size==Vector2i(1280,720): await capture_facility(title,panel)
	panel.close_panel();await frames(3)
	check(not GameState.modal,prefix+" "+title+"关闭后恢复正常地图操作")

func inspect_tabs(panel: Control,title: String) -> void:
	var entry_page: String=panel.page
	var before: Dictionary=FarmSaveStore.snapshot(game)
	for tab in panel.tab_bar.get_children():
		var target: String=str(tab.get_meta("facility_tab",""))
		if target=="": continue
		await tap(tab)
		var selected: int=0
		for other in panel.tab_bar.get_children():
			if other is Button and other.button_pressed: selected+=1
		check(panel.page==target and tab.button_pressed and selected==1 and FarmSaveStore.snapshot(game)==before,prefix+" "+title+"原生页签切换唯一高亮且不结算资源："+target)
	panel.page=entry_page;panel.refresh();await frames(3)

func facilities() -> void:
	await at("home",Kitchen.ANCHOR+Vector2(0,32));await inspect(game.hud.kitchen_panel,[],"kitchen")
	await at("home",Housing.anchor("storage")+Vector2(0,32));await inspect(game.hud.housing_panel,["home"],"housing")
	await at("farm",Aquaculture.SITES.pen_1+Vector2(-32,0));await inspect(game.hud.aquaculture_panel,["pen_1"],"fishpen")
	await at("farm",LakeEcology.SHORE+Vector2(0,32));await inspect(game.hud.ecology_panel,[],"ecology")
	await at("farm",Livestock.SITES.coop+Vector2(0,32));await inspect(game.hud.livestock_panel,["coop"],"livestock")
	await at("farm",Recovery.BENCH+Vector2(0,32));await inspect(game.hud.recovery_panel,[],"recovery")
	await at("village",WorldDevelopment.anchor("board")+Vector2(0,32));await inspect(game.hud.world_development_panel,["board"],"development")
	var entrance: Dictionary=Exploration.definition("forest_entry")
	await at(entrance.area,Exploration.point("forest_entry")+Vector2(0,32));await inspect(game.hud.exploration_panel,["forest_entry"],"exploration")
	GameClock.day=24;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(3)
	await at("farm",Vector2(880,528));await inspect(game.hud.festival_panel,["spring"],"festival")
	await inspect(game.hud.calendar_panel,[],"calendar")
	await at("farm",Fishing.point("farm_lake")+Vector2(-32,0));GameState.select_tool(8)
	await inspect(game.hud.fishing_panel,["farm_lake"],"fishing")

func capture_facility(label: String, panel: Control) -> void:
	for scroll in panel.find_children("*","ScrollContainer",true,false): scroll.scroll_vertical=0
	game.hud.toast_time=0;await frames(6);await RenderingServer.frame_post_draw
	var name: String="res://builds/facility-ui07-"+("before" if before_mode else "after")+"-"+label+".png"
	get_viewport().get_texture().get_image().save_png(name);captures.append({"name":label,"path":name})
