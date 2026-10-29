extends "res://tests/runner.gd"
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	game.player.global_position=Vector2(704,608);game.camera_rig.follow_now();await frames(5)
	await shot("farm")
	game.hud.inventory_panel.open_panel(false);await shot("inventory");game.hud.close_active_panel()
	game.change_location("home",Housing.anchor("kitchen")+Vector2(0,32));await frames(6)
	game.hud.kitchen_panel.open_panel();await shot("kitchen");game.hud.close_active_panel()
	game.get_node("Audio").stop_all();game.queue_free();await frames(4);get_tree().quit()
func shot(id: String) -> void:
	await frames(3);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/harvest-workshop/before-"+id+".png")
