extends "res://tests/capture_v4.gd"

func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	load("res://tests/mining.gd").fresh_chapter(game)
	load("res://tests/xiaojing.gd").advanced_fixture()
	for area in MineState.AREAS:
		game.change_location(area,{"mine_a":Vector2(592,640),"mine_b":Vector2(816,560),"mine_c":Vector2(1040,336)}[area])
		await frames(12)
		await save_image("res://docs/screenshot-05-"+area+".png")
	game.change_location("mine_c",Vector2(1040,720))
	await frames(8)
	await save_image("res://docs/screenshot-05-starlamps.png")
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.5).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit()
