extends "res://tests/runner.gd"
## 保存改造前真实窗口，同镜头采集日后可比较的视觉基线。
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	for item in [["home",Vector2(656,410)],["plots",Vector2(704,608)],["road",Vector2(470,432)]]:
		game.player.global_position=item[1];game.camera_rig.follow_now();await frames(8)
		await shot(str(item[0]))
	game.camera_rig.set_physics_process(false);game.player.get_node("Camera2D").zoom=Vector2(.7,.7)
	game.player.get_node("Camera2D").global_position=Vector2(768,512);game.player.get_node("Camera2D").force_update_scroll()
	game.hud.root.hide();await frames(6);await shot("panorama")
	check(game.world.ground.get_used_cells().size()==1536,"基线完整1536地面格")
	print("FARM VISUAL 06 BASELINE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://builds/farm06-before-"+label+".png")
