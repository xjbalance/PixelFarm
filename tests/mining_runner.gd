extends "res://tests/runner.gd"
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	GameWeather.enabled=false
	await frames(5)
	await load("res://tests/mining.gd").run(self,game)
	print("MINING RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit(1 if failed else 0)
