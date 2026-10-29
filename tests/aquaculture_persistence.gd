extends Node
## 独立进程共享临时XDG目录：写入、重启、损坏主档、备份恢复。
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-aquaculture" in OS.get_cmdline_user_args()
	if "--corrupt-aquaculture" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		file.store_string("interrupted fish save fixture");file.close()
		print("AQUACULTURE CORRUPT: PASS");get_tree().quit();return
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing;add_child(game)
	game.get_node("Audio").muted=true;GameClock.running=false
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,true)
		Aquaculture.restore(Aquaculture.defaults(GameClock.day))
		Inventory.items.wood=200;Inventory.items.stone=200;Inventory.items.fry_crucian=10;Inventory.items.fish_feed=10
		Inventory.coins=12345;Xiaojing.state.diamonds=37
		game.change_location("farm",Vector2(912,592))
		for i in range(4): await get_tree().physics_frame
		ok=Aquaculture.build("pen_1") and Aquaculture.stock("pen_1","crucian",4) and Aquaculture.feed("pen_1")
		GameClock.minutes=1200
		ok=GameClock.request_sleep(GameClock.day) and ok
		ok=Aquaculture.stock("pen_1","crucian",2) and ok
		GameState.set_control_mode("joystick",false)
		var proof := {"aquaculture":Aquaculture.snapshot(),"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"xiaojing":Xiaojing.snapshot(),"day":GameClock.day}
		var file := FileAccess.open("user://aquaculture-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://aquaculture-proof.json")))
		ok=Aquaculture.snapshot()==proof.aquaculture and Inventory.coins==proof.coins and Inventory.items==proof.items and AbyssSaveSchema.canonical(Xiaojing.snapshot())==proof.xiaojing and GameClock.day==proof.day and GameState.control_mode=="joystick"
		var before: Dictionary=Aquaculture.snapshot()
		Aquaculture.settle_day();GameClock.day_advanced.emit()
		ok=ok and Aquaculture.snapshot()==before and Xiaojing.state.married and Xiaojing.state.diamonds==37
		GameState.set_control_mode("tap",false)
		game.change_location("farm",Vector2(880,560))
		for i in range(5): await get_tree().physics_frame
		game.auto_move.request(Vector2(944,580))
		for i in range(500):
			await get_tree().physics_frame
			if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		ok=ok and game.hud.aquaculture_panel.visible and Aquaculture.near_pen("pen_1") and Aquaculture.snapshot()==before
		game.hud.close_active_panel()
		GameState.set_control_mode("joystick",false)
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("AQUACULTURE PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
