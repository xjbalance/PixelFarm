extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-social" in OS.get_cmdline_user_args()
	if "--corrupt-social" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted personal story fixture");file.close()
		print("SOCIAL C CORRUPT: PASS");get_tree().quit();return
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		GameClock.minutes=600;GameClock.changed.emit()
		var person := Social.person_node("linya")
		game.player.position=person.global_position+Vector2(0,35)
		Inventory.items.carrot=5;Inventory.items.wheat_seed=10
		ok=Social.talk("linya") and Social.gift("linya","carrot") and Social.accept("linya")
		game.player.position=Vector2(656,480)
		ok=game.farm.use_tool(Vector2i(17,16),"hoe") and game.farm.use_tool(Vector2i(17,16),"wheat_seed") and game.farm.use_tool(Vector2i(17,16),"water") and ok
		GameState.set_control_mode("joystick",false)
		var proof := FarmSaveStore.snapshot(game)
		var file := FileAccess.open("user://social-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://social-proof.json")))
		var actual: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		for key in ["social","items","coins","plots","xiaojing","progress","day","control_mode"]:
			if actual.get(key)!=proof.get(key): print("SOCIAL PERSISTENCE MISMATCH: ",key);ok=false
		var before: Dictionary=Social.snapshot()
		Events.farm_committed.emit("播种",Vector2i(17,16),"wheat",Xiaojing.state.plant_serial)
		Events.farm_committed.emit("浇水",Vector2i(17,16),"wheat",Xiaojing.state.plant_serial)
		ok=ok and Social.snapshot()==before
		var person := Social.person_node("linya")
		game.player.position=person.global_position+Vector2(0,35)
		ok=ok and not Social.talk("linya") and not Social.gift("linya","potato")
		game.player.position=Vector2(656,480)
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("SOCIAL C PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
