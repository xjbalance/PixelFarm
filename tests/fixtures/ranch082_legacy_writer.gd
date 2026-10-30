extends "res://tests/runner.gd"
## Run only in the detached 244c379 worktree. Never manufacture an old save with new code.
func run() -> void:
	if FarmSaveStore.VERSION!=29: push_error("Legacy writer requires the actual 0.8.1 engine/source");get_tree().quit(1);return
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	var args:=OS.get_cmdline_user_args();var output: String=args[0]
	game.auto_move.navigation.rebuild();var clear: int=1536-game.auto_move.navigation.static_solid.size()
	if DisplayServer.get_name()!="headless":
		var viewport:=SubViewport.new();viewport.size=Vector2i(1536,1024);viewport.world_2d=game.player.get_world_2d();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;game.add_child(viewport)
		var camera:=Camera2D.new();camera.position=Vector2(768,512);viewport.add_child(camera);camera.make_current();await frames(4);await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.get_base_dir()+"/before-farm-native.png");viewport.queue_free();await frames(4)
	var base: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/quality081_v28.json"))
	check(FarmSaveStore.restore(game,base),"actual old source loads married level4 v28 fixture")
	game.tutorial.restore(GameTutorial.defaults(true));GameClock.running=false;GameWeather.enabled=false
	Inventory.coins=200000
	for id in ["wood","stone","hay","wheat_seed","copper_bar","iron_bar","fish_crucian"]: Inventory.items[id]=200
	Livestock.restore(Livestock.defaults(GameClock.day))
	for site in Livestock.SITES:
		game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(4)
		check(Livestock.build(site),"old source builds "+site)
		if site!="fold": Livestock.upgrade(site)
		if site=="coop": Livestock.upgrade(site)
		Livestock.buy_animal(site)
		if site=="coop": Livestock.buy_animal(site)
	for day in range(8):
		for entry in Livestock.state.animals:
			game.change_location("farm",Livestock.animal_point(entry)+Vector2(0,24));await frames(3)
			check(Livestock.feed(entry.id) and Livestock.pet(entry.id),"old real daily animal care")
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"old real sleep settles animals");await frames(4)
	GameClock.minutes=600;game.change_location("farm",Vector2(704,736));await frames(18)
	for cell in [Vector2i(17,16),Vector2i(18,16),Vector2i(19,16)]:
		GameState.stamina=100;check(game.farm.use_tool(cell,"hoe") and game.farm.use_tool(cell,"wheat_seed") and game.farm.use_tool(cell,"water"),"old real planted watered plot")
	await frames(24)
	check(game.territory_editor.open(),"old editor opens")
	await frames(4)
	var plan:=FarmLayout.plan_move("fixture","barn",Vector2i(33,30))
	check(plan.valid and FarmLayout.apply_plan(plan),"old real barn relocation")
	await frames(4)
	plan=FarmLayout.plan_store("fixture","decor:bush:1")
	check(plan.valid and FarmLayout.apply_plan(plan),"old real decoration storage")
	game.territory_editor.cancel();await frames(6)
	# One finished old job and one newly started v29 job exercise both save states.
	var device: String=str(Workshop.state.jobs.keys()[0]);var recipe: String=str(Workshop.state.jobs[device].recipe)
	var node: Node2D=game.territory_world.objects[device]
	game.change_location("farm",node.position+Vector2(0,48));await frames(4)
	game.auto_move.navigation.rebuild();var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":node,"point":node.position})
	check(not route.is_empty(),"old device is approachable")
	if not route.is_empty(): game.player.position=route[-1]
	check(Workshop.claim(device,int(Workshop.state.jobs[device].id)),"old ready job legally collected")
	for item in HarvestCatalog.data().processing[recipe].input_items: Inventory.items[item]=200
	check(Workshop.start(device,recipe),"old engine starts real pending production order")
	var field: Node2D=game.resource_world.fields.farm
	GameState.stamina=100
	while field.state.tree_5_8.hp>0: check(field.hit("tree_5_8","axe"),"old paid tree hit")
	GameState.stamina=100;check(field.hit("tree_7_20","axe"),"old partial tree durability")
	game.change_location("farm",Vector2(736,816));await frames(5)
	var data:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(data) and FarmSaveStore.write(game,"user://verified-v29.json"),"old engine writes valid v29 whole save")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
	var evidence:=FileAccess.open(output.get_base_dir()+"/legacy081-source-proof.json",FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"commit":"244c379","source_version":ProjectSettings.get_setting("application/config/version"),"schema":FarmSaveStore.VERSION,"old_total_cells":1536,"old_initial_clear_cells":clear,"animals":Livestock.snapshot(),"checks":checked,"failures":failed},"  "));evidence.close()
	print("RANCH082 LEGACY SOURCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
