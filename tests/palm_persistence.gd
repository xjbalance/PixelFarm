extends Node
## 调用者必须使用隔离XDG目录。写入/断电残留/独立进程/备份的整合状态守恒。
func _ready() -> void: call_deferred("run")
func frames(count: int=4) -> void:
	for i in range(count): await get_tree().physics_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--hold-palm" in args:
		# 可重复的中断位置：主档/备份完整、临时文件只写入一部分。
		var partial:=FileAccess.open(FarmSaveStore.PATH+".tmp",FileAccess.WRITE)
		partial.store_string("{\"version\":22,");partial.flush()
		print("PALM CRASH READY")
		await get_tree().create_timer(300).timeout
		get_tree().quit(2);return
	if "--corrupt-palm" in args:
		var bad := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		bad.store_string("interrupted palm primary");bad.close()
		print("PALM CORRUPT: PASS");get_tree().quit();return
	if "--interrupt-palm" in args:
		var pending := FarmSaveStore.read()
		pending.coins+=17
		var temporary := FileAccess.open(FarmSaveStore.PATH+".tmp",FileAccess.WRITE)
		temporary.store_string(JSON.stringify(pending));temporary.close()
		print("PALM UNCOMMITTED TEMP: PASS");get_tree().quit();return
	var writing: bool="--write-palm" in args
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(6);game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,true)
		Inventory.coins=20000
		for id in ["wood","stone","iron_bar","crystal","hay","fry_crucian","fish_feed"]: Inventory.items[id]=100
		game.change_location("farm",Recovery.BENCH+Vector2(0,32));await frames()
		GameState.stamina=10
		ok=Recovery.rest(GameClock.day,0) and Recovery.rest(GameClock.day,1) and ok
		for i in range(3): ok=Recovery.eat_crop("potato") and ok
		game.player.position=Aquaculture.SITES.pen_1+Vector2(-32,0)
		ok=Aquaculture.build("pen_1") and Aquaculture.stock("pen_1","crucian",4) and Aquaculture.feed("pen_1") and ok
		game.player.position=Livestock.SITES.coop+Vector2(0,32)
		ok=Livestock.build("coop") and Livestock.buy_animal("coop") and ok
		await frames()
		var animal: Dictionary=Livestock.state.animals[0]
		game.player.position=Vector2(animal.position[0],animal.position[1])+Vector2(0,32)
		ok=Livestock.feed(animal.id) and Livestock.pet(animal.id) and ok
		game.change_location("home",Housing.HOME+Vector2(32,0));await frames()
		ok=Housing.upgrade(1) and ok;await frames()
		ok=Housing.buy("chair") and Housing.place("chair","home",Vector2i(8,13)) and Housing.deposit("wood",7) and ok
		var chapter := ChapterTwo.defaults();chapter.policy="rotation"
		for q in ChapterTwo.definitions.slice(0,8):
			chapter.completed.append(q.id)
			for fact in q.conditions:
				if fact not in chapter.facts: chapter.facts.append(fact)
		ChapterTwo.restore(chapter)
		var a := AbyssState.defaults()
		a.unlocked=true;a.depth=12;a.max_clear=11;a.checkpoint=10;a.gear=2;a.air=77;a.steps={"12":1}
		for depth in range(1,12): a.gates.append(depth);a.notes.append(depth)
		a.notes.append(12);AbyssState.restore(a)
		Xiaojing.state.diamonds=37
		GameState.set_control_mode("joystick",false)
		game.change_location("abyss",AbyssState.point(AbyssState.layout().entry));await frames()
		var proof: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		var file := FileAccess.open("user://palm-proof.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://palm-proof.json")))
		var restored: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		for key in proof:
			if restored.get(key)!=proof[key]: print("PALM MISMATCH ",key);ok=false
		ok=Recovery.snapshot().rests==2 and Recovery.snapshot().snacks==3 and not Recovery.eat_crop("potato") and ok
		ok=not Recovery.rest(GameClock.day,0) and GameState.location=="abyss" and AbyssState.state.depth==12 and AbyssState.state.checkpoint==10 and ok
		ok=Xiaojing.state.married and Xiaojing.state.diamonds==37 and GameState.control_mode=="joystick" and ok
		var before := FarmSaveStore.snapshot(game)
		game._notification(NOTIFICATION_APPLICATION_PAUSED);game._notification(NOTIFICATION_APPLICATION_PAUSED)
		game._notification(NOTIFICATION_APPLICATION_RESUMED);game._notification(NOTIFICATION_APPLICATION_RESUMED)
		ok=FarmSaveStore.snapshot(game)==before and not game.backgrounded and ok
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("PALM PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(3);get_tree().quit(0 if ok else 1)
