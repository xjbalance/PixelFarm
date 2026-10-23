extends Node
## 由 check_project.py 在隔离的用户目录内启动两个独立进程，验证真正重启后自动读档。
func _ready() -> void:
	var writing := "--write-save" in OS.get_cmdline_user_args()
	var legacy_write := "--legacy-write" in OS.get_cmdline_user_args()
	var legacy_read := "--legacy-read" in OS.get_cmdline_user_args()
	if legacy_write:
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json"))
		file.close()
		print("LEGACY FIXTURE WRITE: PASS")
		get_tree().quit()
		return
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled = not writing
	add_child(game)
	GameClock.running = false
	for _i in range(4): await get_tree().physics_frame
	var success: bool
	if writing:
		Story.restore({"stage":8,"motive":"home","lantern":"memory","seen":["letter","welcome","harvest","carpenter","bridge","mill","supper","festival","well"],"assisted_tools":false})
		VillageProjects.restore({"built":["well","cooperative","arbor"],"water_day":12,"tea_day":12})
		game.change_location("village",Vector2(1010,480))
		Inventory.coins = 987
		Inventory.items = {"carrot_seed":7,"wheat":3,"wood":11,"stone":4}
		GameClock.day = 12
		GameClock.minutes = 1057
		FarmProgress.restore({"built":["toolrack","bedding","irrigation"],"quests":{"first_gift":2,"river_path":1},"friendship":37,"last_talk_day":12})
		game.world.resource_field.restore({"tree_7_20":{"hp":0,"ready_day":14},"rock_11_19":{"hp":1,"ready_day":0}})
		GameState.stamina = 117
		GameState.selected = 7
		game.farm.plots = {"20,20":{"crop":"potato","days":2,"watered":true}}
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
		hidden.wedding_day=10
		hidden.diamonds=7
		hidden.ore=6
		for event in Xiaojing.data.events: hidden.events.append(event.id)
		for quest in Xiaojing.data.quests: hidden.quests.append(quest.id)
		for memory in Xiaojing.data.memories: hidden.memories.append(memory.id)
		hidden.trials=["management","planning","cave","mechanism","joint"]
		Xiaojing.restore(hidden)
		StarStory.restore(StarStory.migrate(hidden))
		LegendState.restore(LegendState.migrate(hidden,StarStory.snapshot()))
		# 从真实设置按钮切换，只依靠模式变更的自动保存，再由下一进程读取。
		game.persistence_enabled=true
		game.hud.system_panel.open_panel()
		await get_tree().process_frame
		load("res://tests/story.gd").touch(self,game.hud.system_panel.control_mode_button)
		for _i in range(4): await get_tree().physics_frame
		var automatic := FarmSaveStore.read()
		success = automatic.get("control_mode")=="joystick" and automatic.get("xiaojing",{}).get("married",false)
		game.hud.system_panel.close_panel()
	elif legacy_read:
		success = Inventory.coins == 321 and Inventory.count("carrot") == 3 and GameClock.day == 5 and GameState.stamina == 73 and GameState.control_mode == "tap"
		success = success and FarmProgress.built.is_empty() and FarmProgress.quest_states.is_empty() and FarmProgress.friendship == 0
		success = success and game.world.resource_field.state.tree_7_20.hp == 3 and game.farm.plots["17,16"].days == 1
		success = success and FarmSaveStore.write(game)
		var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FarmSaveStore.PATH+".bak"))
		success = success and backup.version == 1 and FarmSaveStore.read().version == FarmSaveStore.VERSION
	else:
		success = Inventory.coins == 987 and Inventory.count("wheat") == 3 and Inventory.count("carrot_seed") == 7
		success = success and Xiaojing.state.married and Xiaojing.state.plants==520 and Xiaojing.state.diamonds==7 and Xiaojing.state.ore==6
		success = success and GameClock.day == 12 and GameClock.minutes == 1057 and GameState.stamina == 117
		success = success and Inventory.count("wood") == 11 and Inventory.count("stone") == 4 and GameState.selected == 7 and GameState.control_mode == "joystick"
		success = success and FarmProgress.built.size() == 3 and FarmProgress.quest_status("river_path") == "active" and FarmProgress.friendship == 37
		success = success and FarmProgress.last_talk_day == 12 and game.world.resource_field.state.tree_7_20.ready_day == 14 and game.world.resource_field.state.rock_11_19.hp == 1
		success = success and GameState.location == "village" and game.player.position.distance_to(Vector2(1010,480)) < 0.1
		success = success and Story.stage == 8 and Story.motive == "home" and Story.lantern == "memory" and Story.seen.has("well") and not Story.assisted_tools
		success = success and VillageProjects.all_built() and VillageProjects.water_day == 12 and VillageProjects.tea_day == 12 and game.village.bridge_open
		success = success and game.farm.plots.get("20,20",{}).get("days") == 2 and game.farm.plots["20,20"].watered
	print("PERSISTENCE ","WRITE" if writing else ("LEGACY MIGRATION" if legacy_read else "RESTART READ"),": ","PASS" if success else "FAIL")
	game.persistence_enabled = false
	game.get_node("Audio").stop_all()
	# 给音频混音线程一轮清理时间，再结束独立测试进程。
	await get_tree().create_timer(0.2).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)
