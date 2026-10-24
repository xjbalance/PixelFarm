extends "res://tests/runner.gd"
## 实窗口通过原生触点读提示、操作机关、换三图；不是Android真机。
const Touch=preload("res://tests/touch_navigation.gd")
var taps_onscreen: bool=true
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(7)
	Inventory.items={"wood":99,"stone":99,"wheat":99,"fishing_bait":20};Inventory.coins=10000
	game.change_location("mist_forest");await frames(5)
	check(await open_point("forest_order"),"真实窗口点击森林提示自动靠近")
	await click("展开记录")
	check(game.hud.exploration_panel.pending.is_valid() and "forest_order" not in Exploration.state.facts,"读提示中途未提前提交线索")
	game.hud.exploration_panel.close_panel()
	check("forest_order" not in Exploration.state.facts,"中途收起不触发已读进度")
	await open_point("forest_order");await click("展开记录");await click("读完并记下")
	check("forest_order" in Exploration.state.facts,"原生触点读完后实际记录顺序线索")
	game.hud.exploration_panel.close_panel()
	for id in ["forest_spring","forest_summer","forest_autumn","forest_winter"]:
		check(await open_point(id),"原生触点沿地图靠近石桩："+id)
		await click("操作眼前机关一次");game.hud.exploration_panel.close_panel();await frames(4)
	check(Exploration.state.forest.open,"实际触屏四步完成后林径开放")
	await read_point("forest_archive");await snapshot("forest")
	var eco := LakeEcology.defaults(GameClock.day);eco.restored=true;eco.cycle=true;eco.plants=3;eco.health=95;LakeEcology.restore(eco)
	game.change_location("farm",Exploration.point("lake_entry")+Vector2(-32,0));await frames(5)
	check(Exploration.inspect_entrance("lake_ruins") and Exploration.enter("lake_ruins"),"已恢复生态的真实地表入口可进入封闭排水廊")
	await frames(5);await read_point("lake_hint")
	for id in ["lake_north","lake_flow","lake_south"]:
		check(await open_point(id),"真实触点在退水后沿廊道靠近控制："+id)
		await click("操作眼前机关一次");game.hud.exploration_panel.close_panel();await frames(5)
	check(Exploration.state.lake.open,"实际窗口三步水位机关打开石桥")
	await read_point("lake_archive");await snapshot("lake")
	load("res://tests/star_runner.gd").fixture(game,false);Calendar.restore(Calendar.snapshot())
	game.change_location("village");await frames(5)
	check(await open_point("temple_entry"),"先沿原村庄桥路走到神庙入口合法站位")
	game.hud.exploration_panel.close_panel()
	check(Exploration.inspect_entrance("old_temple") and Exploration.enter("old_temple"),"神庙从原村庄东岸合法进入")
	await frames(5);await read_point("temple_hint")
	for i in range(2):
		await open_point("temple_mirror");await click("操作眼前机关一次");game.hud.exploration_panel.close_panel();await frames(4)
	for id in ["temple_grain","temple_water","temple_star"]:
		check(await open_point(id),"原生触点沿光门与中庭靠近符台："+id)
		await click("操作眼前机关一次");game.hud.exploration_panel.close_panel();await frames(4)
	check(Exploration.state.temple.open,"实际窗口校镜与三符台联动开启终室")
	await read_point("temple_archive");await snapshot("temple")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"窗口三图实玩状态仍通过完整存档校验")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(5)
		check(await open_point("temple_archive"),"新地图原生触点适配不同横屏比例："+str(resolution))
		check(game.hud.safe.get_global_rect().encloses(game.hud.exploration_panel.get_global_rect()),"新探索阅读面板位于安全区："+str(resolution))
		game.hud.exploration_panel.close_panel()
	GameState.set_control_mode("joystick",false);game.action_cooldown=0;game.interact();await frames(3)
	check(game.hud.exploration_panel.visible,"新区域备用摇杆与桌面E仍能调查同一档案")
	check(taps_onscreen,"所有原生地图触点均在实际可见窗口内，未用离屏坐标冒充点击")
	print("EXPLORATION D RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func find_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(caption): return child
		var result := find_button(child,caption)
		if result: return result
	return null
func click(caption: String) -> void:
	var panel: PanelContainer=game.hud.exploration_panel
	var control := find_button(panel,caption)
	if not control: check(false,"缺少真实触点操作按钮："+caption);return
	var scroll := panel.content.get_parent() as ScrollContainer;scroll.ensure_control_visible(control);await frames(4)
	load("res://tests/story.gd").touch(self,control);await frames(4)
func open_point(id: String) -> bool:
	while game.hud.close_active_panel(): pass
	var target: Vector2=Exploration.point(id)+Vector2(0,-12)
	var screen: Vector2=game.player.get_canvas_transform()*target
	if not get_viewport().get_visible_rect().grow(-32).has_point(screen) or game.touch_input.ui_at(screen):
		# Walk the real route until the destination is visible, then exercise a native screen tap.
		game.auto_move.request(Exploration.point(id));await Touch.finish(self,game,2400)
		while game.hud.close_active_panel(): pass
		await frames(12)
		screen=game.player.get_canvas_transform()*target
	if not get_viewport().get_visible_rect().has_point(screen) or game.touch_input.ui_at(screen): taps_onscreen=false;return false
	Touch.tap(self,game,target);await Touch.finish(self,game,2400)
	return game.hud.exploration_panel.visible and game.hud.exploration_panel.context==id
func read_point(id: String) -> void:
	check(await open_point(id),"窗口实走打开档案："+id)
	await click("展开记录");await click("读完并记下")
	check(id in Exploration.state.facts,"窗口已读实际保存档案："+id)
	game.hud.exploration_panel.close_panel()
func snapshot(label: String) -> void:
	while game.hud.close_active_panel(): pass
	await frames(6);get_viewport().get_texture().get_image().save_png("res://builds/screenshot-exploration-"+label+".png")
