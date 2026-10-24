extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	Inventory.coins=30000;Inventory.items={"wood":500,"stone":500,"iron_bar":20,"crystal":20}
	game.change_location("home",Housing.HOME+Vector2(32,0));await frames(5)
	check(Housing.upgrade(1) and Housing.upgrade(2),"窗口实际扩建到三级而不移动原床门")
	await frames(5);check(Housing.buy("chair") and Housing.place("chair","home",Vector2i(5,9)),"窗口真实制作并在新增侧间摆椅")
	await frames(5)
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		game.change_location("home",Housing.HOME+Vector2(32,0));await frames(5)
		game.hud.housing_panel.open_panel("home");await frames(4)
		check(game.hud.safe.get_global_rect().encloses(game.hud.housing_panel.get_global_rect()),"装修网格界面适配安全区："+str(resolution))
		game.hud.housing_panel.close_panel()
		game.change_location("farm",Vector2(480,480));GameClock.minutes=600;GameClock.changed.emit();await frames(5)
		var linya: Node2D=Social.person_node("linya")
		game.player.position=linya.global_position+Vector2(0,36)
		game.hud.social_panel.open_panel("linya");await frames(4)
		check(game.hud.social_panel.visible and game.hud.safe.get_global_rect().encloses(game.hud.social_panel.get_global_rect()),"个人任务与礼物界面适配安全区："+str(resolution))
		game.hud.social_panel.close_panel()
		GameClock.day=24;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
		game.player.position=Vector2(880,528);await frames(4)
		game.hud.festival_panel.open_panel("spring");await frames(4)
		check(game.hud.festival_panel.visible and game.hud.safe.get_global_rect().encloses(game.hud.festival_panel.get_global_rect()),"节日活动长文适配安全区："+str(resolution))
		game.hud.festival_panel.close_panel()
	get_window().size=Vector2i(1280,720)
	game.change_location("home",Vector2(272,464));await frames(5)
	var target: Node2D
	for object in get_tree().get_nodes_in_group("housing_furniture"):
		if object.housing_id==Housing.state.placed[0].id: target=object;break
	check(target!=null and not game.touch_input.ui_at(game.player.get_canvas_transform()*target.global_position),"侧间椅子可见且不被任务卡遮挡")
	if target:
		Touch.tap(self,game,target.global_position);await Touch.finish(self,game,600)
		check(game.hud.housing_panel.visible and game.hud.housing_panel.selected_id==target.housing_id,"真实屏幕触点可走到家具并打开移动回收")
		game.hud.housing_panel.close_panel()
	GameClock.day=52;GameClock.minutes=1210;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	game.change_location("farm",Vector2(1088,880));await frames(6)
	for person in ["linya","zhou","ahe"]:
		var node: Node2D=Social.person_node(person)
		check(node!=null and node.get_parent()==game.world.get_node("Actors"),"夏季灯会使用原NPC在湖岸聚集："+person)
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070c-lanterns.png")
	game.change_location("home",Vector2(272,464));await frames(5)
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070c-home.png")
	print("LIFE C RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
