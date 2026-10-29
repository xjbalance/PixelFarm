extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var devices: Dictionary={}
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock();GameClock.minutes=720
	for station in HarvestCatalog.data().stations:
		var id: String=await Fixture.install(self,game,"station_"+station);devices[station]=id
		check(id!="","实际设备用于状态动画验证："+station)
		if id=="": continue
		var object: Node2D=game.territory_world.objects[id]
		check(WorkshopVisual.status(id)=="idle" and object.sprite.visible and not object.animated.visible,"空闲使用原静态立面："+station)
		await Fixture.approach(self,game,id)
		var selected: String=""
		for recipe in HarvestCatalog.data().processing:
			if HarvestCatalog.data().processing[recipe].processing_station_id==station: selected=recipe;break
		for ingredient in HarvestCatalog.data().processing[selected].input_items: Inventory.items[ingredient]=100
		check(Workshop.start(id,selected),"真实订单驱动工作状态："+station)
		check(object.animated.visible and not object.sprite.visible and object.animated.sprite_frames.get_frame_count("work")==4,"工作精灵使用四帧共享图集："+station)
	var territory: Dictionary=Territory.snapshot();var inventory:=Inventory.items.duplicate();var time: float=GameClock.minutes
	GameClock.running=true;GameClock.changed.emit();await frames(22)
	for id in devices.values():
		var object: Node2D=game.territory_world.objects[id]
		check(object.animated.is_playing() and object.animated.frame>0,"时间正常时工作帧实际变化："+str(id))
	check(Inventory.items==inventory and Territory.snapshot()==territory and GameClock.minutes<time+2,"动画不产出、不改碰撞布局、不额外推进生产时间")
	await shot("working-a");await frames(17);await shot("working-b")
	GameState.set_modal(true);var before:=frames_snapshot();time=GameClock.minutes;await frames(18)
	check(before==frames_snapshot() and GameClock.minutes==time,"菜单期间工作帧和游戏生产时钟同时暂停")
	GameState.set_modal(false);get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(4)
	before=frames_snapshot();time=GameClock.minutes;await frames(20)
	check(game.backgrounded and before==frames_snapshot() and GameClock.minutes==time,"后台通知不推进动画、时间或离线产量")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN);await frames(20)
	check(not game.backgrounded and frames_snapshot()!=before,"回到前台恢复工作显示")
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
	var stopped: bool=true
	for id in devices.values(): stopped=stopped and not game.territory_world.objects[id].animated.is_playing()
	check(stopped,"离开农场后隐藏设备不继续无意义的动画播放")
	await Touch.place(self,game,"farm",Vector2(704,704));GameClock.running=false;GameClock.changed.emit()
	Fixture.advance(1440);await frames(5)
	for id in devices.values():
		var object: Node2D=game.territory_world.objects[id]
		check(WorkshopVisual.status(id)=="ready" and not object.animated.is_playing() and object.sprite.visible,"完成时停止工作动画，恢复静态并等待收取："+str(id))
	check(Inventory.items==inventory,"动画完成不会自动复制或领取产品")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"动画无需新增任何存档字段，生产与布局仍合法")
	print("QUALITY081 ANIMATION RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func frames_snapshot() -> Dictionary:
	var result: Dictionary={}
	for id in devices.values(): result[id]=game.territory_world.objects[id].animated.frame
	return result
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.root.hide();game.player.position=Vector2(704,704);game.camera_rig.set_physics_process(false)
	var camera: Camera2D=game.player.get_node("Camera2D");camera.zoom=Vector2(2,2);camera.global_position=Vector2(688,760);camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/quality081/"+id+".png")
	game.hud.root.show();camera.zoom=Vector2(1.3333,1.3333);game.camera_rig.set_physics_process(true)
