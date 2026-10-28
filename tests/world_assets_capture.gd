extends Node
## Same real-window fixture runs against HEAD and working tree, isolated saves.
var game: Node
var output: String=""
var captures: Array=[]
func _ready() -> void: call_deferred("run")
func frames(count: int=5) -> void:
	for _i in range(count): await get_tree().physics_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	if output=="" or DisplayServer.get_name()=="headless": get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(12);game.tutorial.restore(GameTutorial.defaults(true))
	GameClock.minutes=720;GameClock.changed.emit();await frames()
	await visit("farm",Vector2(656,480));await capture("farm_hud_1280x720")
	get_window().size=Vector2i(1600,720);await frames();await capture("farm_hud_20x9")
	get_window().size=Vector2i(1280,960);await frames();await capture("farm_hud_tablet")
	get_window().size=Vector2i(1536,1024);game.hud.root.hide();game.camera_rig.camera.zoom=Vector2.ONE
	await frames();await capture("farm_full_spring")
	for season in range(1,4):
		GameClock.day=season*28+1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(8)
		await capture("farm_full_"+["spring","summer","autumn","winter"][season])
	GameClock.day=1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	get_window().size=Vector2i(1280,720);game.camera_rig.camera.zoom=Vector2(1.25,1.25);game.hud.root.show()
	for level in range(1,5):
		var house: Dictionary=Housing.defaults(GameClock.day);house.level=level;house.builtins=HomeLayout.default_builtins(level);Housing.restore(house)
		await visit("farm",Vector2(656,440));await capture("house_level_"+str(level))
	await visit("home",Vector2(640,470));await capture("home")
	await visit("village",Vector2(540,480));await capture("village")
	await visit("mist_forest",Exploration.entry("mist_forest"));await capture("forest")
	await visit("farm",Vector2(656,480));game.territory_editor.open();await frames();await capture("farm_edit_permissions")
	game.territory_editor.choose_category("objects");await frames();await capture("farm_edit_assets")
	game.territory_editor.cancel();await frames()
	if TerritoryCatalog.OBJECT_KINDS.has("garden_swing"):
		await garden_showcase()
		load("res://tests/star_runner.gd").fixture(game,true)
		LegendState.state.greenhouse=4;LegendState.changed.emit();Xiaojing.changed.emit()
		GameClock.minutes=720;GameClock.changed.emit()
		await visit("farm",Vector2(1280,812));await capture("greenhouse_restored_story_fixture")
	var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":DisplayServer.get_name(),"captures":captures,"android_device_tested":false},"\t"));file.close()
	print("WORLD ASSET CAPTURE: ",captures.size()," actual window images")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames();get_tree().quit()
func visit(area: String, point: Vector2) -> void:
	while game.hud.close_active_panel(): pass
	game.change_location(area,point);game.auto_move.cancel();game.player.velocity=Vector2.ZERO;game.camera_rig.follow_now();await frames(8)
func capture(label: String) -> void:
	game.hud.toast_time=0
	# Let the normal area-entry banner/fade finish in both versions.
	await get_tree().create_timer(2.9).timeout;await frames(4);await RenderingServer.frame_post_draw
	var path: String=output+"/"+label+".png"
	var error: Error=get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"saved":error==OK,"window_size":[get_window().size.x,get_window().size.y]})
	if error!=OK: push_error("Cannot capture "+path)

func garden_showcase() -> void:
	# A documented showcase fixture: every edit uses the real preview/confirm
	# controller. This is not presented as an unmodified new player's save.
	await visit("farm",Vector2(400,700))
	var field: Node=game.resource_world.fields.farm
	for id in field.objects:
		var point: Vector2=field.objects[id].position
		if not Rect2(64,470,380,345).has_point(point): continue
		var tool: String=FarmResourceCatalog.TYPES[field.objects[id].kind].tool
		while int(field.state[id].hp)>0:
			GameState.stamina=GameState.max_stamina()
			if not field.hit(id,tool): break
	await frames(5)
	var editor: Node=game.territory_editor
	editor.open();await frames(4)
	editor.choose_tool("stone_path")
	for y in range(18,22):
		for x in range(4,11): editor.preview_at(Vector2i(x,y))
	if not editor.confirm(): push_error("Showcase patio rejected: "+str(editor.preview_plan))
	await frames(5)
	for spec in [["wood_bench",Vector2i(4,18)],["square_table",Vector2i(7,19)],["wood_chair",Vector2i(7,20)],["flower_pot",Vector2i(10,18)],["street_lamp",Vector2i(10,21)],["garden_swing",Vector2i(4,21)],["blossom_tree",Vector2i(11,20)],["yellow_wildflowers",Vector2i(9,22)]]:
		editor.choose_tool(spec[0]);editor.preview_at(spec[1]);await frames(4)
		if not editor.confirm(): push_error("Showcase placement rejected: "+str(spec))
		await frames(5)
	editor.cancel();await frames(6);await capture("farm_player_garden")
	editor.open();editor.choose_tool("flower_basket");editor.preview_at(Vector2i(9,21));await frames(6);await capture("farm_player_garden_preview")
	editor.cancel();await frames(5)
	game.hud.atlas_panel.open_panel();game.hud.atlas_panel.map_canvas.show_region("farm");await frames(6);await capture("farm_garden_atlas")
	game.hud.atlas_panel.close_panel()
