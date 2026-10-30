extends "res://tests/runner.gd"
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/ranch082/legacy081-v29.json"))
	check(FarmSaveStore.restore(game,data),"probe old source restored")
	await frames(5)
	for id in RanchLayout.ENABLED:
		var map: RanchMap=game.mine_maps[RanchLayout.area(id)];var atlas: TileSetAtlasSource=map.ground.tile_set.get_source(0)
		print("SEASON PROBE ",id," day ",GameClock.day," calendar ",Calendar.season()," cached ",map.season," texture ",atlas.texture.resource_path," tree ",map.tree_sprite.texture.resource_path)
		map.refresh()
		print("SEASON PROBE AFTER EXPLICIT ",id," ",map.season," ",atlas.texture.resource_path)
		check(map.season==Calendar.season() and atlas.texture.resource_path.ends_with("ground_winter.png"),"pasture cached tiles reflect saved winter")
	if DisplayServer.get_name()!="headless":
		game.change_location("pasture_coop",Vector2(256,400));GameClock.minutes=720;GameClock.changed.emit();game.hud.root.hide();await frames(60);await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image();image.save_png("res://docs/ranch082/winter-render-probe.png")
		var world:=Vector2(200,400);var at: Vector2=game.player.get_canvas_transform()*world;var color:=image.get_pixelv(Vector2i(at));print("WINTER FRAME RGB ",color)
		check(color.r>.65 and color.b>.65,"actual rendered winter grass is snow-colored")
	print("RANCH082 SEASONS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
