extends Node
## 使用实际 OpenGL 渲染器输出截图；不是美术稿或伪造游戏画面。
func _ready() -> void:
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled = false
	add_child(game)
	GameClock.running = false
	GameClock.minutes = 570
	GameClock.changed.emit()
	game.hud.toast_time = 0
	await capture("farm-start")
	for x in range(18,25):
		for y in range(17,20):
			game.farm.plots["%d,%d" % [x,y]] = {"crop":["carrot","potato","wheat"][posmod(x,3)],"days":posmod(x+y,4),"watered":y%2==1}
	game.farm.queue_redraw()
	await capture("farm-grown")
	game.hud.inventory_panel.open_panel(true)
	await capture("shop")
	game.hud.inventory_panel.close_panel()
	Inventory.items["wood"] = 36
	Inventory.items["stone"] = 27
	Inventory.coins = 700
	Inventory.changed.emit()
	game.hud.progress_panel.open_panel("workshop",true)
	game.hud.progress_panel.select("irrigation")
	await capture("workshop")
	game.hud.progress_panel.close_panel()
	FarmProgress.accept("first_gift")
	Inventory.add("carrot",3)
	game.hud.progress_panel.open_panel("journal",true)
	await capture("quests")
	game.hud.progress_panel.close_panel()
	game.hud.inventory_panel.open_panel(false)
	game.hud.inventory_panel.materials_tab = true
	game.hud.inventory_panel.refresh()
	await capture("materials")
	game.hud.inventory_panel.close_panel()
	FarmProgress.build_upgrade("toolrack")
	FarmProgress.build_upgrade("irrigation")
	FarmProgress.build_upgrade("bedding")
	game.hud.toast_time = 0
	await capture("upgraded-farm")
	Events.dialogue_requested.emit("林芽 · 种子收集师",["你好呀，欢迎来到风芽农场！先翻土、播种、浇水，再回小屋睡一觉。每天一点照料，河谷里就会长出新的希望。"])
	await capture("dialogue")
	game.hud.dialogue.close_dialogue()
	GameClock.minutes = 1350
	GameClock.changed.emit()
	await capture("night")
	GameClock.minutes = 570
	GameClock.changed.emit()
	game.change_location("home")
	await capture("home")
	game.change_location("farm",Vector2(646,491))
	for resolution in [Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size = resolution
		await capture("%dx%d" % [resolution.x,resolution.y])
	get_tree().quit()

func capture(label: String) -> void:
	for i in range(24): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/screenshot-%s.png" % label
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",label," result=",error)
