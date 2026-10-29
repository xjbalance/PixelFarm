extends Node
## 同一隔离用户目录中的四个真实进程：写入、重启、坏档、备份。
func _ready() -> void: call_deferred("run")

func run() -> void:
	var writing: bool="--write-seasons" in OS.get_cmdline_user_args()
	if "--corrupt-seasons" in OS.get_cmdline_user_args():
		var corrupt := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		corrupt.store_string("interrupted seasons save fixture");corrupt.close()
		print("SEASONS A CORRUPT: PASS");get_tree().quit();return
	var seasonal_events := [0]
	Calendar.season_changed.connect(func(_old: int,_new: int,_year: int): seasonal_events[0]+=1)
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	for i in range(6): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok: bool=seasonal_events[0]==0
	if writing:
		load("res://tests/star_runner.gd").fixture(game,true)
		GameClock.day=210;GameClock.minutes=1234
		Calendar.restore(Calendar.migrate(GameClock.day))
		Aquaculture.restore(Aquaculture.defaults(GameClock.day))
		Inventory.coins=24680;Inventory.items.wood=100;Inventory.items.stone=100;Inventory.items.fry_crucian=5
		Xiaojing.state.diamonds=1427
		GameState.set_control_mode("joystick",false)
		game.change_location("farm",Vector2(912,592))
		for i in range(4): await get_tree().physics_frame
		ok=Aquaculture.build("pen_1") and Aquaculture.stock("pen_1","crucian",3) and ok
		game.farm.plots={"17,16":{"crop":"carrot","days":1,"watered":true},"18,16":{"crop":"wheat","days":1,"watered":false}}
		var proof := FarmSaveStore.snapshot(game)
		var file := FileAccess.open("user://seasons-proof.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://seasons-proof.json")))
		var restored: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		for key in ["calendar","world_changes","coins","items","day","minutes","plots","xiaojing","aquaculture","control_mode","story","village","abyss"]:
			if restored.get(key)!=proof.get(key):
				print("SEASONS PERSISTENCE MISMATCH: ",key)
				ok=false
		ok=ok and GameWeather.weather_id()=="rain" and Calendar.season()==3 and Calendar.year()==2 and Xiaojing.state.married and Xiaojing.state.diamonds==1427
		var before: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		Calendar.advance_day();Calendar.advance_day()
		ok=ok and seasonal_events[0]==0 and AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))==before
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("SEASONS A PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
