extends Node
var game: Node
func _ready() -> void: call_deferred("run")
func frames(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(10);game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://builds/territory080-before-farm.png")
	game.hud.atlas_panel.open_panel();await frames(24);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://builds/territory080-before-atlas.png")
	game.hud.atlas_panel.close_panel()
	var file:=FileAccess.open("res://builds/territory080-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"game_version":ProjectSettings.get_setting("application/config/version"),"save_version":FarmSaveStore.VERSION,"platform":DisplayServer.get_name(),"plots":game.farm.plots.size(),"resources":game.resource_world.snapshot(),"appearance":Appearance.snapshot()},"\t"));file.close()
	print("TERRITORY BASELINE WINDOW: PASS")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit()
