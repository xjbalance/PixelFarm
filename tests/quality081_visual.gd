extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var label: String="before"
var captures: Array[String]=[]
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--after" in args: label="after"
	if "--sample" in args: label="sample"
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock();GameClock.minutes=720;GameClock.changed.emit()
	var row: int=16
	for pair in [["carrot","strawberry"],["wheat","corn"],["potato","cabbage"]]:
		for side in range(2):
			var id: String=pair[side];var days: int=Catalog.crops[id].growth_days
			for stage in range(3):
				var cell:=Vector2i(18+side*3+stage,row)
				game.farm.plots[TerritoryCatalog.key(cell)]={"crop":id,"days":[0,maxi(1,days/2),days][stage],"watered":stage%2==1}
		row+=2
	game.farm.queue_redraw();game.player.position=Vector2(816,688);game.hud.root.hide()
	game.camera_rig.set_physics_process(false);var camera: Camera2D=game.player.get_node("Camera2D");camera.zoom=Vector2(2,2);camera.global_position=Vector2(704,592);camera.force_update_scroll()
	await shot("crops")
	game.hud.root.show();camera.zoom=Vector2(1.3333,1.3333);game.camera_rig.set_physics_process(true);game.camera_rig.follow_now()
	var devices: Array[String]=[]
	for id in ["mill","jam_pot","loom","smoker"]:
		var device: String=await Fixture.install(self,game,"station_"+id);devices.append(device);check(device!="","实际布置对照设备："+id)
	game.player.position=Vector2(704,704);game.hud.root.hide();game.camera_rig.set_physics_process(false);camera.zoom=Vector2(2,2);camera.global_position=Vector2(688,760);camera.force_update_scroll();await shot("devices")
	game.hud.root.show();camera.zoom=Vector2(1.3333,1.3333);game.camera_rig.set_physics_process(true);game.camera_rig.follow_now()
	Inventory.items.merge({"flour":8,"potato_bread":3,"egg":6,"milk":4,"bread":4,"mayonnaise":3},true)
	game.hud.inventory_panel.open_panel(false);game.hud.inventory_panel.change_category(3);await frames(4)
	# A visual-audit filter on actual inventory rows; item widgets and quantities are unchanged.
	for id in game.hud.inventory_panel.row_views:
		game.hud.inventory_panel.row_views[id].row.get_parent().get_parent().visible=id in ["flour","potato_bread","bread"]
	game.hud.inventory_panel.scroll.scroll_vertical=0;await shot("inventory")
	for id in game.hud.inventory_panel.row_views:
		game.hud.inventory_panel.row_views[id].row.get_parent().get_parent().visible=id in ["egg","milk","mayonnaise"]
	game.hud.inventory_panel.scroll.scroll_vertical=0;await shot("animal-products")
	game.hud.close_active_panel()
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
	game.hud.kitchen_panel.open_panel();game.hud.kitchen_panel.selected_recipe="bread";game.hud.kitchen_panel.refresh();await frames(4)
	for scroll in game.hud.kitchen_panel.find_children("*","ScrollContainer",true,false):
		if scroll.get_parent() is HBoxContainer: scroll.scroll_vertical=100
	await shot("kitchen");game.hud.close_active_panel()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"同屏素材验收使用合法场景和存档状态")
	var f:=FileAccess.open("res://docs/quality081/"+label+"-window.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"actual_window":DisplayServer.get_name()!="headless","android_device_tested":false},"\t"));f.close()
	print("QUALITY081 VISUAL %s RESULT: %d checks, %d failures" % [label,checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func shot(id: String) -> void:
	game.hud.toast_time=0
	await frames(6);await RenderingServer.frame_post_draw
	var path: String="res://docs/quality081/"+label+"-"+id+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append(path)
