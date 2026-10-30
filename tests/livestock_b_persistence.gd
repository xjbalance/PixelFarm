extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	if "--corrupt-livestock" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted livestock save");file.close()
		print("LIVESTOCK CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-livestock" in OS.get_cmdline_user_args()
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		Inventory.coins=12345;Inventory.items={"wood":100,"stone":100,"hay":99};Xiaojing.state.diamonds=77
		game.change_location("farm",Livestock.SITES.barn+Vector2(0,32))
		for i in range(4): await get_tree().physics_frame
		ok=Livestock.build("barn") and Livestock.buy_animal("barn")
		var entry: Dictionary=Livestock.animals_at("barn")[0]
		for day in range(6):
			game.change_location(Livestock.animal_area(entry),Livestock.animal_point(entry)+Vector2(0,24))
			for i in range(3): await get_tree().physics_frame
			ok=Livestock.feed(entry.id) and ok
			Livestock.pet(entry.id)
			GameClock.minutes=1200;ok=GameClock.request_sleep(GameClock.day) and ok
		GameState.set_control_mode("joystick",false)
		var proof := {"livestock":Livestock.snapshot(),"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"diamonds":Xiaojing.state.diamonds,"day":GameClock.day}
		var file := FileAccess.open("user://livestock-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://livestock-proof.json")))
		ok=AbyssSaveSchema.canonical(Livestock.snapshot())==proof.livestock and Inventory.coins==proof.coins and Inventory.items==proof.items and Xiaojing.state.diamonds==proof.diamonds and GameClock.day==proof.day and GameState.control_mode=="joystick"
		var before: Dictionary=Livestock.snapshot();Livestock.settle_day();GameClock.day_advanced.emit()
		ok=ok and Livestock.snapshot()==before
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("LIVESTOCK PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
