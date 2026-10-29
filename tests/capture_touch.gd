extends "res://tests/capture_v4.gd"

func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	GameClock.running=false
	GameState.set_control_mode("tap",false)
	game.change_location("farm",Vector2(656,480))
	await frames(8)
	game.auto_move.request(Vector2(784,480))
	await frames(8)
	await save_image("res://docs/screenshot-touch.png")
	game.hud.system_panel.open_panel()
	await frames(5)
	await save_image("res://docs/screenshot-touch-settings.png")
	GameState.set_control_mode("joystick",false)
	game.hud.system_panel.close_panel()
	await frames(5)
	await save_image("res://docs/screenshot-joystick.png")
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(0.5).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit()
