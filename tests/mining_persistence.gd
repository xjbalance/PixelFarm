extends Node
## 独立进程验证v7磁盘文件；check_project.py提供隔离用户目录。
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var writing := "--write-mine-save" in OS.get_cmdline_user_args()
	var corrupting := "--corrupt-mine-save" in OS.get_cmdline_user_args()
	if corrupting:
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		file.store_string("intentionally broken test primary")
		file.close()
		print("MINE CORRUPT FIXTURE: PASS")
		get_tree().quit()
		return
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	for i in range(5): await get_tree().physics_frame
	var success := true
	if writing:
		load("res://tests/mining.gd").fresh_chapter(game)
		load("res://tests/xiaojing.gd").advanced_fixture()
		MineState.state.queue=[{"id":1,"recipe":"refine","batches":2,"ready_day":201}]
		MineState.state.job_serial=1
		MineState.state.ores.c_diamond_0={"hp":2,"ready_day":0}
		MineState.state.chests=["c_chest"]
		MineState.state.commission_mines=["c_star_0"]
		var hidden := Xiaojing.defaults()
		hidden.plants=520
		hidden.plant_serial=520
		hidden.unlocked=true
		hidden.affection=100
		hidden.trust=100
		hidden.bond=100
		hidden.dating=true
		hidden.greenhouse=true
		hidden.proposed=true
		hidden.married=true
		hidden.wedding_day=190
		hidden.diamonds=17
		for e in Xiaojing.data.events: hidden.events.append(e.id)
		for q in Xiaojing.data.quests: hidden.quests.append(q.id)
		for m in Xiaojing.data.memories: hidden.memories.append(m.id)
		hidden.trials=["management","planning","cave","mechanism","joint"]
		Xiaojing.restore(hidden)
		StarStory.restore(StarStory.migrate(hidden))
		LegendState.restore(LegendState.migrate(hidden,StarStory.snapshot()))
		GameState.set_control_mode("joystick",false)
		game.change_location("mine_c",Vector2(208,688))
		GameState.stamina=64
		success=FarmSaveStore.write(game) and FarmSaveStore.write(game)
	else:
		success=GameState.location=="mine_c" and game.player.position.distance_to(Vector2(208,688))<.1
		success=success and GameState.control_mode=="joystick" and GameState.stamina==64 and GameClock.day==200
		success=success and MineState.state.tool==3 and MineState.state.resonance_open and MineState.state.water_lowered
		success=success and MineState.state.queue.size()==1 and MineState.state.queue[0].ready_day==201 and MineState.ore_state("c_diamond_0").hp==2
		success=success and "c_chest" in MineState.state.chests and ChapterTwo.completed.size()==6
		success=success and Xiaojing.state.married and Xiaojing.state.diamonds==17 and Xiaojing.state.wedding_day==190
		GameState.set_control_mode("tap",false)
		game.auto_move.request(Vector2(240,688))
		for i in range(90): await get_tree().physics_frame
		success=success and game.player.position.distance_to(Vector2(240,688))<2
		success=success and FarmSaveStore.write(game) and FarmSaveStore.valid(FarmSaveStore.read())
	print("MINE PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP READ",": ","PASS" if success else "FAIL")
	game.persistence_enabled=false
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.25).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)
