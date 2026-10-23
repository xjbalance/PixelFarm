extends "res://tests/capture_v4.gd"
func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	load("res://tests/star_runner.gd").fixture(game,false)
	GameClock.running=false
	GameWeather.enabled=false
	var a := AbyssState.defaults()
	a.unlocked=true
	a.max_clear=20
	a.checkpoint=20
	a.gear=3
	for depth in range(1,21): a.gates.append(depth); a.notes.append(depth)
	for depth in [1,10,20]:
		a.depth=depth
		AbyssState.restore(a)
		game.change_location("abyss",Vector2(592,336))
		await frames(8)
		await save_image("res://docs/screenshot-abyss-%02d.png" % depth)
	game.change_location("home",Vector2(775,365))
	GameClock.minutes=720
	GameClock.changed.emit()
	Events.interaction_requested.emit("sleep")
	await frames(5)
	await save_image("res://docs/screenshot-sleep-day-blocked.png")
	GameClock.minutes=1200
	GameClock.changed.emit()
	Events.interaction_requested.emit("sleep")
	await frames(5)
	await save_image("res://docs/screenshot-sleep-night-confirm.png")
	game.hud.close_active_panel()
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit()
