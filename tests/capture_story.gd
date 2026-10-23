extends Node
## 用真实渲染场景展示阶段状态；这里的作物/资源/建设进度是截图夹具，不是新档赠送物。
var game: Node

func _ready() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled = false
	add_child(game)
	GameClock.running = false
	GameClock.minutes = 570
	GameClock.changed.emit()
	game.hud.toast_time = 0
	await capture("03-farm")
	Story.request("mail")
	for i in range(16):
		if game.hud.dialogue.choices_box.visible: break
		game.hud.dialogue.advance()
	await capture("03-letter-choice")
	game.hud.dialogue.close_dialogue()
	for x in range(18,25):
		for y in range(17,20):
			game.farm.plots["%d,%d" % [x,y]] = {"crop":["carrot","potato","wheat"][posmod(x,3)],"days":posmod(x+y,3),"watered":true}
	game.farm.queue_redraw()
	set_story(4)
	game.change_location("village",Vector2(650,575))
	await capture("03-village-before")
	set_story(6)
	Inventory.items = {"wood":30,"stone":20,"wheat":2,"carrot":1}
	Inventory.coins = 500
	game.change_location("village",Vector2(680,688))
	game.hud.story_panel.open_panel(true)
	await capture("03-construction")
	game.hud.story_panel.close_panel()
	VillageProjects.restore({"built":["well","cooperative","arbor"],"water_day":0,"tea_day":0})
	set_story(8)
	game.change_location("village",Vector2(650,575))
	await capture("03-village-after")
	game.hud.story_panel.open_panel()
	game.hud.story_panel.select_page(1)
	await capture("03-map")
	game.hud.story_panel.close_panel()
	set_story(7)
	GameClock.minutes = 1100
	GameClock.changed.emit()
	game.hud.dialogue.open_story("festival")
	for i in range(20):
		if game.hud.dialogue.choices_box.visible: break
		game.hud.dialogue.advance()
	await capture("03-ending")
	game.hud.dialogue.close_dialogue()
	set_story(8)
	GameClock.minutes = 1260
	GameClock.changed.emit()
	await capture("03-lantern-night")
	GameClock.day = 4
	GameClock.minutes = 630
	GameClock.changed.emit()
	game.change_location("farm",Vector2(646,550))
	await capture("03-rain")
	GameClock.day = 5
	GameClock.changed.emit()
	for resolution in [Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size = resolution
		await capture("03-%dx%d" % [resolution.x,resolution.y])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(0.2).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func set_story(stage: int) -> void:
	var seen: Array = []
	for id in Story.data.scenes:
		if Story.data.scenes[id].has("next") and Story.data.scenes[id].next <= stage: seen.append(id)
	Story.restore({"stage":stage,"motive":"renew","lantern":"tomorrow" if stage == 8 else "","seen":seen,"assisted_tools":true})

func capture(label: String) -> void:
	game.hud.toast_time = 0
	await get_tree().create_timer(3.3).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://docs/screenshot-%s.png" % label)
	print("CAPTURE ",label," result=",error)
