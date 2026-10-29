extends Node

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	GameClock.running=false
	GameClock.day=200
	GameClock.minutes=1230
	var seen: Array = []
	for id in Story.data.scenes:
		if Story.data.scenes[id].has("next"): seen.append(id)
	Story.restore({"stage":8,"motive":"home","lantern":"trade","seen":seen,"assisted_tools":true})
	VillageProjects.restore({"built":["well","cooperative","arbor"],"water_day":0,"tea_day":0})
	Letters.direction="trade"
	game.change_location("village",Vector2(640,600))
	await frames(8)
	game.hud.dialogue.open_story("guestbook")
	game.hud.dialogue.advance()
	await frames(3)
	await save_image("res://docs/screenshot-04-guestbook.png")
	game.hud.dialogue.close_dialogue()
	var hidden := Xiaojing.defaults()
	hidden.plants=520
	hidden.plant_serial=520
	hidden.unlocked=true
	hidden.affection=52
	hidden.trust=58
	hidden.bond=50
	Xiaojing.restore(hidden)
	GameClock.minutes=1100
	GameClock.changed.emit()
	game.player.position=Vector2(624,668)
	game.hud.xiaojing_panel.open_panel()
	await frames(5)
	await save_image("res://docs/screenshot-04-xiaojing.png")
	game.hud.xiaojing_panel.close_panel()
	Xiaojing.state.greenhouse=true
	Xiaojing.state.married=true
	GameClock.minutes=1230
	GameClock.changed.emit()
	game.change_location("farm",Vector2(1200,826))
	await frames(8)
	await save_image("res://docs/screenshot-04-greenhouse.png")
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(0.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit()

func frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func save_image(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(path)
	print("CAPTURE ",path," ",result)
	if result!=OK: get_tree().quit(1)
