extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-kitchen" in OS.get_cmdline_user_args()
	if "--corrupt-kitchen" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted kitchen fixture");file.close()
		print("KITCHEN B CORRUPT: PASS");get_tree().quit();return
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		game.change_location("home",Vector2(848,464))
		Inventory.coins=10000;Inventory.items={"wood":100,"stone":100,"wheat":10,"potato_bread":2}
		GameState.stamina=20;GameState.set_control_mode("joystick",false)
		ok=Kitchen.build("mill") and Kitchen.enqueue("flour",2) and Kitchen.consume("potato_bread")
		var proof := FarmSaveStore.snapshot(game)
		var file := FileAccess.open("user://kitchen-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://kitchen-proof.json")))
		var current: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		for key in ["kitchen","coins","items","aquaculture","stamina","day","control_mode"]:
			if current.get(key)!=proof.get(key): print("KITCHEN PERSISTENCE MISMATCH: ",key);ok=false
		ok=ok and Kitchen.state.queue.size()==1 and not Kitchen.claim_job(1) and Kitchen.speed_multiplier()==1.15
		var before_buff: Dictionary=Kitchen.snapshot().buff.duplicate(true)
		var bread: int=Inventory.count("potato_bread");var stamina: int=GameState.stamina
		ok=Kitchen.consume("potato_bread") and Inventory.count("potato_bread")==bread-1 and GameState.stamina==mini(GameState.max_stamina(),stamina+18) and Kitchen.state.buff==before_buff and ok
		# 独立检验同日继续食用后恢复证明夹具，后续备份仍逐字段核对。
		ok=FarmSaveStore.restore(game,proof) and ok
		GameState.set_control_mode("tap",false);game.change_location("home",Vector2(640,500))
		for i in range(5): await get_tree().physics_frame
		game.auto_move.request(Vector2(848,410))
		for i in range(600):
			await get_tree().physics_frame
			if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		ok=ok and game.hud.kitchen_panel.visible and Kitchen.near_kitchen()
		while game.hud.close_active_panel(): pass
		GameState.set_control_mode("joystick",false)
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("KITCHEN B PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
