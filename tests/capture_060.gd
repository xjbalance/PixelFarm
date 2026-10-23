extends "res://tests/capture_v4.gd"
func capture() -> void:
	get_window().size=Vector2i(1280,720)
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);game.get_node("Audio").muted=true
	load("res://tests/star_runner.gd").fixture(game,false);GameClock.running=false;GameWeather.enabled=false
	River.restore(River.defaults());LegendState.state.greenhouse=4;LegendState.state.deduction=3;LegendState.state.evidence=[10,12,20];LegendState.state.trials=LegendTrials.IDS.duplicate()
	var a := AbyssState.defaults();a.unlocked=true;a.max_clear=100;a.checkpoint=100;a.gear=7;a.bosses=[20,40,60,80,100]
	for depth in range(1,101): a.gates.append(depth);a.notes.append(depth)
	River.state.facts=["star_core"]
	for depth in [5,30,50,70,100]:
		a.depth=depth;AbyssState.restore(a);game.change_location("abyss",AbyssState.point(AbyssState.layout().controls[1]));await frames(8)
		game.hud.toast_time=0
		await save_image("res://docs/screenshot-060-%03d.png" % depth)
	StarStory.event("proposal");StarStory.event("kept_appointment");StarStory.state.invited=["linya","zhou","ahe"];StarStory.state.choices.future="share_home"
	Xiaojing.state.diamonds=1314;game.change_location("farm",Vector2(1360,816));StarStory.start_ceremony();await frames(5)
	game.player.position=Vector2(640,500);game.player.get_node("Camera2D").reset_smoothing();game.get_node("Audio").muted=false
	await frames(16);game.hud.toast_time=0
	print("WEDDING AUDIO STATES ",game.mine_maps.greenhouse.music.playing," ",game.mine_maps.greenhouse.ambience.playing)
	await save_image("res://docs/screenshot-060-wedding.png")
	game.player.position=Vector2(520,560);StarStory.place_wedding_table();game.player.position=Vector2(760,560)
	game.hud.river_panel.open_panel("ceremony_right");await frames(5)
	await save_image("res://docs/screenshot-060-confirm.png")
	game.hud.close_active_panel();Xiaojing.confirm_wedding(true);game.player.position=Vector2(640,400);game.player.get_node("Camera2D").reset_smoothing();StarCeremony.vows();await frames(16)
	await save_image("res://docs/screenshot-060-stars.png")
	game.get_node("Audio").muted=true;game.get_node("Audio").stop_all();await get_tree().create_timer(.4).timeout;game.queue_free();await frames(4);get_tree().quit()
