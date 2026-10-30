extends "res://tests/runner.gd"
## Release 0.8.1 measured in the actual engine before any gameplay modification.
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8)
	Inventory.items={"wood":999,"stone":999,"hay":999};Inventory.coins=100000
	var report: Dictionary={"release":"0.8.1","commit":"244c379","grid":[48,32],"cell_pixels":32,"sites":{},"motion":[]}
	for site in Livestock.SITES:
		game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(3)
		check(Livestock.build(site),"baseline build "+site)
		check(Livestock.buy_animal(site),"baseline purchase "+site)
		var envelope:=Rect2(Livestock.site_point(site)+Vector2(-112,-46),Vector2(224,150))
		var nav:=WorldNavigation.new(game);nav.rebuild()
		var count: int=0
		for y in range(32):
			for x in range(48):
				var cell:=Vector2i(x,y)
				if envelope.has_point(nav.center(cell)) and not nav.static_solid.has(cell): count+=1
		report.sites[site]={"envelope_pixels":[224,150],"legal_grid_centers":count,"area_pixels":count*1024,"minimum_multiplier":6 if site=="coop" else 10}
		var entry: Dictionary=Livestock.animals_at(site)[0]
		entry.age=Livestock.data.species[entry.species].growth_days
		game.player.global_position=Livestock.animal_point(entry)+Vector2(0,24)
		check(Livestock.feed(entry.id),"baseline daily feed "+site)
	GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"baseline real sleep")
	await frames(4)
	var chicken: Dictionary=Livestock.animals_at("coop")[0]
	check(chicken.product==1,"baseline adult chicken already produces one egg")
	game.player.global_position=Livestock.animal_point(chicken)+Vector2(0,24)
	check(Livestock.collect(chicken.id) and Inventory.count("egg")==1,"baseline egg collection reaches inventory")
	check(not Livestock.collect(chicken.id),"baseline repeated collection refused")
	GameClock.minutes=600
	for site in Livestock.SITES:
		game.player.global_position=Livestock.site_point(site)+Vector2(0,32)
		check(Livestock.graze(site),"baseline grazing "+site)
	game.change_location("farm",Livestock.SITES.barn+Vector2(0,32));await frames(5)
	game.camera_rig.set_physics_process(false)
	var camera: Camera2D=game.player.get_node("Camera2D")
	camera.global_position=Vector2(500,825);camera.force_update_scroll()
	GameClock.running=true
	for tick in range(901):
		if tick%60==0:
			var row: Dictionary={"frame":tick,"animals":{}}
			for entry in Livestock.state.animals: row.animals[entry.id]=entry.position.duplicate()
			report.motion.append(row)
		if tick in [0,180,360,900] and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/ranch082/before-motion-%04d.png" % tick)
		await frames(1)
	GameClock.running=false;game.hud.hide();camera.zoom=Vector2(.65,.65);camera.global_position=Vector2(768,512);camera.force_update_scroll()
	await frames(5)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/ranch082/before-farm-panorama.png")
	var file:=FileAccess.open("res://docs/ranch082/baseline.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RANCH082 BASELINE RESULT: %d checks, %d failures" % [checked,failed])
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
