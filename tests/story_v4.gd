extends RefCounted

static func run(test: Node, game: Node) -> void:
	var saved := FarmSaveStore.snapshot(game)
	game.hud.close_active_panel()
	game.change_location("farm",Vector2(700,500))
	await test.frames()
	Story.restore({})
	Letters.restore({})
	VillageProjects.restore({})
	Inventory.items = {"carrot":3,"wood":30,"stone":30}
	test.check(Story.complete("letter","renew") and Story.complete("welcome"),"新序幕读信、交谈顺序解锁")
	var coins: int = Inventory.coins
	test.check(not Story.complete("harvest") and Inventory.count("carrot")==3 and Inventory.coins==coins,"未完成种植教学不能用库存跳过新序幕")
	for id in ["plant","water","harvest"]: Letters.record(id)
	test.check(Story.complete("harvest") and "first_crop" in Letters.completed,"多条件任务识别教学与真实交付")
	test.check(not Story.complete("carpenter"),"未调查不能跳过周砚的心结")
	Story.complete("bridge_survey")
	test.check(not Story.complete("carpenter"),"单条线索不足以完成多条件调查")
	Story.complete("repair_record")
	test.check(Story.complete("carpenter"),"两条环境线索解锁人物交流")
	test.check(not Story.complete("bridge") and Inventory.count("wood")==30,"材料充足但未读留言册不能修桥")
	test.check(Story.complete("guestbook") and Story.complete("bridge"),"留言册与修桥事务接通")
	coins = Inventory.coins
	test.check(not Story.complete("bridge") and Inventory.count("wood")==22,"重复修桥不会再扣材料")
	test.check(not Story.complete("mill"),"风车任务要求实际探索东岸")
	game.change_location("village",Vector2(1000,480))
	Letters._process(0.6)
	test.check(Story.complete("mill"),"探索区域事实解锁货运记录")
	test.check(Story.complete("cargo_note","ask_departure") and Story.complete("cargo_note","ask_name") and Letters.knows("cargo_departure") and Letters.knows("cargo_name"),"风车货箱有两条可独立阅读的支线对白")
	var v3: Dictionary = saved.duplicate(true)
	v3.version = 3;v3.erase("farm_layout");v3.erase("appearance")
	v3.erase("letters")
	v3.erase("xiaojing")
	v3.story.lantern = "tomorrow"
	for stage in [0,2,4,6,8]:
		var legacy := v3.duplicate(true)
		legacy.story.stage=stage
		legacy.story.motive="" if stage==0 else "home"
		legacy.story.lantern="tomorrow" if stage==8 else ""
		legacy.story.seen=[]
		for id in Story.data.scenes:
			if Story.data.scenes[id].has("next") and int(Story.data.scenes[id].next)<=stage: legacy.story.seen.append(id)
		legacy.village={"built":["well","cooperative","arbor"] if stage>=7 else [],"water_day":0,"tea_day":0}
		var normalized := FarmSaveSchema.normalize(legacy)
		test.check(not normalized.is_empty() and normalized.version==FarmSaveStore.VERSION and normalized.coins==legacy.coins and normalized.items==legacy.items and normalized.plots==legacy.plots and normalized.player==legacy.player,"v3不同章节迁移保留经营数据：stage"+str(stage))
		test.check(FarmSaveSchema.normalize(normalized)==normalized,"迁移重复执行幂等：stage"+str(stage))
	test.check(FarmSaveStore.restore(game,saved),"新剧情测试结束恢复原状态")
	await test.frames()
	var branch_base := FarmSaveStore.snapshot(game)
	for direction in ["trade","explore","life"]:
		Letters.restore({})
		Letters.legacy_review=true
		Story.lantern="memory"
		var items := Inventory.items.duplicate(true)
		test.check(Story.complete("future",direction) and Letters.direction==direction,"旧通关档可独立选择发展方向："+direction)
		var branch := FarmSaveStore.snapshot(game)
		Letters.direction=""
		test.check(FarmSaveStore.restore(game,branch) and Letters.direction==direction,"发展方向可保存恢复："+direction)
		test.check(not Story.complete("future",direction) and Inventory.items==branch.items,"发展方向奖励不会重复领取："+direction)
		var all_open := true
		for definition in Letters.definitions:
			if definition.id in ["trade_start","explore_start","life_start"]: all_open = all_open and Letters.conditions_met(definition.unlock)
		test.check(all_open,"选择后其余两个发展方向仍开放："+direction)
		FarmSaveStore.restore(game,branch_base)
	var plot_count: int = Letters.facts.get("chapter2:plant",0)
	test.check(plot_count==0,"第二章种植进度不沿用第一章教学")
	GameClock.minutes=780
	GameClock.changed.emit()
	await test.frames()
	test.check(game.village.villagers.ahe.station==Vector2(432,560),"水井建成后阿禾午间到井边")
	GameClock.minutes=900
	GameClock.changed.emit()
	test.check(game.village.villagers.zhou.station==Vector2(960,528),"修桥后周砚到东岸检查")
	GameClock.minutes=1100
	GameClock.changed.emit()
	test.check(game.village.villagers.linya.visible and not game.world.get_node("Actors/Linya").visible,"林芽傍晚跨地图出现，无重复可见角色")
	test.check(game.village.villagers.zhou.station==Vector2(496,656) and game.village.villagers.ahe.station==Vector2(592,656),"风灯后晚间仍在公共茶座相聚")
	var tea_route := VillagerNavigation.route(game.village.villagers.zhou,Vector2(496,656))
	test.check(not tea_route.is_empty(),"茶座站点与真实陈设碰撞同步，NPC可规划到达")
	var person: Node = game.village.villagers.zhou
	var before: Vector2 = person.position
	GameState.set_modal(true)
	GameClock.running=true
	await test.frames(10)
	test.check(person.position.distance_to(before)<0.1,"对话模态暂停NPC日程")
	GameState.set_modal(false)
	GameClock.running=false
	test.check("共仓" in Story.scene_data("linya_daily").lines[0].text,"共仓建设改变实际交易对白")
	# 在真实物理帧中穿过已修桥梁，而非只验证站点数据。
	GameClock.minutes=900
	GameClock.changed.emit()
	game.change_location("village",Vector2(640,756))
	await test.frames(4)
	person.position=Vector2(752,496)
	person.station=Vector2.INF
	person.set_station(Vector2(960,528))
	GameClock.set_process(false)
	GameClock.running=true
	await test.frames(360)
	GameClock.running=false
	GameClock.set_process(true)
	test.check(person.position.x>940 and person.position.distance_to(Vector2(960,528))<40,"NPC真实移动能通过修好的桥，不穿河水")
	FarmSaveStore.restore(game,saved)
	await test.frames()
