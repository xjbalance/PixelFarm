extends Node
## 独立进程保存中途水闸、已领箱和区域位置，再实走下一步；目录由测试入口隔离。
func _ready() -> void: call_deferred("run")
func run() -> void:
	if "--corrupt-exploration" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted exploration save");file.close()
		print("EXPLORATION CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-exploration" in OS.get_cmdline_user_args()
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/mining.gd").fresh_chapter(game);Calendar.restore(Calendar.snapshot())
		var eco := LakeEcology.defaults(GameClock.day);eco.restored=true;eco.cycle=true;eco.plants=3;eco.health=95;LakeEcology.restore(eco)
		var value := Exploration.defaults(GameClock.day);value.unlocked=["mist_forest","lake_ruins"]
		value.facts=["forest_order","forest_archive","drain_plate","lake_hint","lake_lower_opened"]
		value.forest={"step":4,"open":true};value.lake={"water":1,"flow":1,"open":false};value.chests=["forest_cache"]
		Exploration.restore(value);Inventory.items.rare_fiber=2;Inventory.items.copper_ore=3;Inventory.coins=12345;Xiaojing.state.diamonds=77
		game.change_location("lake_ruins",Vector2(560,720));GameState.set_control_mode("joystick",false)
		for i in range(5): await get_tree().physics_frame
		var proof := {"exploration":Exploration.snapshot(),"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"day":GameClock.day,"diamonds":Xiaojing.state.diamonds}
		var file := FileAccess.open("user://exploration-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game)
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://exploration-proof.json")))
		ok=AbyssSaveSchema.canonical(Exploration.snapshot())==proof.exploration and Inventory.coins==proof.coins and Inventory.items==proof.items and GameClock.day==proof.day and Xiaojing.state.diamonds==proof.diamonds and GameState.location=="lake_ruins" and GameState.control_mode=="joystick"
		ok=Exploration.near_id("lake_south") and Exploration.operate("lake_south") and Exploration.state.lake.open and ok
		GameState.set_control_mode("tap",false)
		for i in range(5): await get_tree().physics_frame
		game.auto_move.request(Exploration.point("lake_archive"))
		for i in range(1200):
			await get_tree().physics_frame
			if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		while game.hud.close_active_panel(): pass
		ok=Exploration.near_id("lake_archive") and Exploration.read("lake_archive") and ok
		ok="forest_cache" in Exploration.state.chests and Inventory.count("rare_fiber")==2 and Xiaojing.state.diamonds==77 and ok
		GameState.set_control_mode("joystick",false)
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("EXPLORATION PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
