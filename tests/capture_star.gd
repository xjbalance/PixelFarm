extends "res://tests/capture_v4.gd"
func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	load("res://tests/star_runner.gd").fixture(game,false)
	load("res://tests/marriage_requirement_fixture.gd").satisfy(game)
	GameClock.running=false
	GameClock.minutes=1100
	GameClock.changed.emit()
	StarStory.event("proposal")
	StarStory.state.invited=["linya","zhou","ahe"]
	StarStory.state.choices.future="keep_journeys"
	StarStory.state.wedding_phase=1
	StarStory.changed.emit()
	game.change_location("farm",Vector2(1360,884))
	await frames(15)
	await save_image("res://docs/screenshot-star1314-ceremony.png")
	StarStory.state.wedding_phase=2
	game.hud.star_panel.open_panel("desk_right")
	await frames(8)
	await save_image("res://docs/screenshot-star1314-confirm.png")
	game.hud.star_panel.close_panel()
	game.hud.inventory_panel.open_panel(true)
	game.hud.inventory_panel.materials_tab=true
	game.hud.inventory_panel.refresh()
	await frames(8)
	await save_image("res://docs/screenshot-star1314-shop.png")
	DiamondPayments.selected=true
	game.hud.inventory_panel.buy("wheat")
	await frames(8)
	await save_image("res://docs/screenshot-star1314-payment.png")
	game.hud.inventory_panel.close_panel()
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit()
