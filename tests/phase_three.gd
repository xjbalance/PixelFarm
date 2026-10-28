extends RefCounted

static func run(test: Node, game: Node) -> void:
	game.player.position = Vector2(656,440)
	game.action_cooldown = 0
	game.interact()
	await test.frames()
	test.check(GameState.location == "home" and game.player.get_parent() == game.home, "房门交互切换到独立室内场景")
	test.check(not game.world.visible and game.home.visible, "室内外显示状态正确")
	# 这里在农场中是房屋碰撞区；切换后必须可自由行走。
	game.player.position = Vector2(710,390)
	Input.action_press("move_left")
	await test.frames(25)
	Input.action_release("move_left")
	test.check(game.player.position.x < 660, "室内移动不受隐藏农场碰撞干扰")
	GameClock.minutes=1200 # 夜间床的确认流程；白天拒绝在sleep_runner单独覆盖。
	game.player.position = Vector2(775,340)
	game.action_cooldown = 0
	game.interact()
	test.check(game.hud.system_panel.visible and game.hud.system_panel.sleep_mode, "床边交互显示休息确认")
	var day: int = GameClock.day
	game.hud.system_panel.actions.get_child(0).pressed.emit()
	test.check(GameClock.day == day+1 and not GameState.modal, "触屏休息按钮进入下一天")
	game.player.position = Vector2(640,528)
	game.action_cooldown = 0
	game.interact()
	await test.frames()
	test.check(GameState.location == "farm" and game.player.get_parent() == game.world.get_node("Actors"), "门口返回农场并复用角色")
	game.farm.use_tool(Vector2i(24,20),"hoe")
	game.farm.use_tool(Vector2i(24,20),"potato_seed")
	game.farm.use_tool(Vector2i(24,20),"water")
	GameState.stamina = 73
	GameClock.minutes = 1110
	Inventory.coins = 432
	game.player.position = Vector2(700,500)
	GameState.select_tool(4)
	var original := FarmSaveStore.snapshot(game)
	var path := "user://integration_test_%d.json" % Time.get_ticks_usec()
	test.check(FarmSaveStore.valid(original), "当前状态通过存档 schema 校验")
	test.check(FarmSaveStore.write(game,path), "真实写入 user:// JSON 存档")
	var loaded := FarmSaveStore.read(path)
	test.check(not loaded.is_empty(), "从磁盘读取 JSON 存档")
	game.farm.plots.clear()
	Inventory.items.clear()
	Inventory.coins = 0
	GameClock.day = 1
	GameClock.minutes = 360
	GameState.stamina = 0
	game.change_location("home")
	test.check(FarmSaveStore.restore(game,loaded), "恢复存档")
	await test.frames()
	test.check(GameState.location == "farm" and game.player.position.distance_to(Vector2(700,500)) < 0.1, "恢复玩家位置和地图")
	test.check(GameClock.day == original.day and GameClock.minutes == 1110 and Inventory.coins == 432, "恢复日期、时刻和金币")
	test.check(GameState.stamina == 73 and GameState.selected == 4 and Inventory.items == original.items, "恢复体力、选中工具和背包")
	test.check(game.farm.plots == original.plots and game.farm.plots["24,20"].watered, "恢复农田、作物生长与浇水状态")
	for mutation in [
		{"coins":-1}, {"day":"oops"}, {"player":[-1,42]}, {"location":"unknown"},
		{"items":{"carrot":-2}}, {"plots":{"24,20":{"crop":"bad","days":0,"watered":false}}},
		{"plots":{"24,20":{"crop":"carrot","days":999,"watered":false}}},
		{"plots":{"48,0":{"crop":"","days":0,"watered":false}}}, {"version":999}
	]:
		var invalid := loaded.duplicate(true)
		invalid.merge(mutation,true)
		test.check(not FarmSaveStore.restore(game,invalid) and Inventory.coins == 432, "损坏字段拒绝且不污染当前游戏: " + str(mutation.keys()))
	Inventory.coins = 444
	test.check(FarmSaveStore.write(game,path) and FileAccess.file_exists(path+".bak"), "覆盖存档保留上一版备份")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	var backup := FarmSaveStore.read(path)
	test.check(backup.get("coins") == 432, "主文件损坏时自动读取有效备份")
	game.change_location("home",Vector2(720,440))
	var indoor := FarmSaveStore.snapshot(game)
	game.change_location("farm")
	test.check(FarmSaveStore.restore(game,indoor), "室内存档可恢复")
	await test.frames()
	test.check(GameState.location == "home" and game.player.position.distance_to(Vector2(720,440)) < 0.1, "室内位置正确恢复")
	game.change_location("farm")
	GameClock.minutes = 800
	GameClock.changed.emit()
	var daytime: Color = game.get_node("DayNight").color
	GameClock.minutes = 1380
	GameClock.changed.emit()
	test.check(game.get_node("DayNight").color.r < daytime.r, "夜晚实际改变世界颜色")
	game.hud.inventory_panel.open_panel(false)
	game.hud.inventory_panel.equip("wheat")
	test.check(not GameState.modal and GameState.tool() == "wheat_seed", "背包装备种子后关闭模态并恢复操作")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
