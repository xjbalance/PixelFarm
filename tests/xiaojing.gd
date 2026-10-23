extends RefCounted

static func near(test: Node, game: Node, minute: int = 600) -> void:
	GameClock.minutes=minute
	GameClock.changed.emit()
	var point := Vector2(1120,674) if minute<1080 else Vector2(624,674)
	game.change_location("village",point)
	await test.frames()

static func collect(test: Node, game: Node, id: String) -> void:
	for memory in Xiaojing.data.memories:
		if memory.id == id:
			game.change_location(memory.location,Vector2(memory.position[0],memory.position[1])+Vector2(0,36))
			await test.frames()
			game.action_cooldown=0
			game.interact()
			test.check(game.hud.xiaojing_panel.visible and game.hud.xiaojing_panel.page=="story","真实邻近交互能选中独立记忆："+id)
			if game.hud.xiaojing_panel.visible:
				game.hud.xiaojing_panel.finish_story()
				game.hud.xiaojing_panel.close_panel()
			test.check(id in Xiaojing.state.memories,"读取独立记忆："+id)

static func grow(game: Node, count: int) -> void:
	for i in range(count):
		var cell := Vector2i(17+i%10,16+int(i/10)%6)
		game.farm.plots.erase(game.farm.key(cell))
		game.farm.use_tool(cell,"hoe")
		game.farm.use_tool(cell,"carrot_seed")
		game.farm.plots[game.farm.key(cell)].days=2
		game.farm.use_tool(cell,"hand")
		GameState.rest()

static func run(test: Node, game: Node) -> void:
	var saved := FarmSaveStore.snapshot(game)
	game.hud.close_active_panel()
	Xiaojing.restore(Xiaojing.defaults())
	GameClock.day=100
	GameClock.running=false
	Inventory.items={"carrot_seed":999,"carrot":30,"wheat":99,"potato":99,"wood":99,"stone":99}
	GameState.rest()
	game.change_location("farm",Vector2(700,500))
	var start_count: int = Xiaojing.state.plants
	test.check(not game.farm.use_tool(Vector2i(1,1),"carrot_seed") and Xiaojing.state.plants==start_count,"失败播种不计数")
	var cell := Vector2i(17,16)
	for i in range(519):
		game.farm.plots.erase("17,16")
		GameState.rest()
		game.farm.use_tool(cell,"hoe")
		game.farm.use_tool(cell,"carrot_seed")
	test.check(Xiaojing.state.plants==519 and not Xiaojing.state.unlocked and not Xiaojing.state.letter_ready,"519次真实成功播种不解锁")
	var serial: int = Xiaojing.state.plant_serial
	for i in range(3):
		game.farm.use_tool(cell,"carrot_seed")
		Events.farm_action.emit("播种")
		Xiaojing.commit_successful_plant(serial)
	test.check(Xiaojing.state.plants==519,"重复输入、展示信号和同一提交序号不重复计数")
	game.farm.plots.erase("17,16")
	game.farm.use_tool(cell,"hoe")
	game.farm.use_tool(cell,"carrot_seed")
	test.check(Xiaojing.state.plants==520 and not Xiaojing.state.letter_ready,"第520次播种达成硬条件，白天不强行弹事件")
	GameClock.minutes=1200
	Xiaojing.check_night()
	test.check(Xiaojing.state.letter_ready and not Xiaojing.state.unlocked,"合适夜晚投递神秘来信")
	game.hud.xiaojing_panel.open_panel("xiaojing_letter")
	game.hud.xiaojing_panel.close_panel()
	test.check(not Xiaojing.state.unlocked,"来信中断不提前解锁")
	game.hud.xiaojing_panel.open_panel("xiaojing_letter")
	game.hud.xiaojing_panel.finish_story()
	game.hud.xiaojing_panel.close_panel()
	test.check(Xiaojing.state.unlocked and not Xiaojing.read_letter(),"读完来信永久解锁且只结算一次")
	Xiaojing.check_night()
	test.check(not Xiaojing.state.letter_ready,"解锁事件不会重复投递")
	await near(test,game)
	test.check(Xiaojing.nearby(),"小京作为长期NPC出现在河东观察点")
	var before_talk: int = Xiaojing.state.affection
	game.action_cooldown=0
	game.interact()
	test.check(game.hud.xiaojing_panel.visible and GameState.modal,"现有靠近交互可打开小京长列表")
	await test.frames(3)
	load("res://tests/story.gd").touch(test,game.hud.xiaojing_panel.content.get_child(1))
	test.check(game.hud.xiaojing_panel.page=="story","原生触点按钮能打开小京交谈剧情")
	game.hud.xiaojing_panel.close_panel()
	test.check(Xiaojing.state.affection==before_talk,"关闭未读完的小京交谈不会提前提交好感")
	test.check(Xiaojing.talk() and not Xiaojing.talk(),"每日交谈只提升一次")
	test.check(Xiaojing.gift("carrot") and not Xiaojing.gift("carrot"),"每日礼物只提升一次")
	test.check(not Xiaojing.gift("diamond") and not FarmEconomy.buy("diamond",1),"不能购买或用钻石刷好感")
	test.check(not Xiaojing.confirm_wedding(true),"未达任务、属性与关系条件不能求婚")
	test.check(Xiaojing.finish_event("meet"),"初识事件有独立提交")
	await collect(test,game,"window")
	await near(test,game)
	test.check(Xiaojing.finish_quest() and not Xiaojing.finish_quest(),"专属调查任务完成且不能越级重复领奖")
	grow(game,30)
	await near(test,game)
	test.check(Xiaojing.finish_quest(),"30次真实种植完成共同试验田任务")
	test.check(Xiaojing.finish_quest(),"留种交付完整提交")
	await collect(test,game,"bridge")
	await collect(test,game,"mill")
	await near(test,game)
	test.check(Xiaojing.finish_quest(),"两岸记忆推进人物调查任务")
	test.check(not Xiaojing.puzzle_input(1) and Xiaojing.state.puzzle_step==0,"解谜错误重置本轮")
	for symbol in [0,2,1]: Xiaojing.puzzle_input(symbol)
	test.check(Xiaojing.finish_quest(),"机关解谜完成专属任务")
	await collect(test,game,"pond")
	await collect(test,game,"post")
	await near(test,game)
	test.check(Xiaojing.finish_quest(),"三地图探索与五份记忆完成路线任务")
	await near(test,game,1100)
	test.check(Xiaojing.activity() and not Xiaojing.activity(),"共同活动有地点、时间和每日限额")
	test.check(Xiaojing.finish_quest(),"共同计划任务可完成")
	await collect(test,game,"hearth")
	await collect(test,game,"orchard")
	await near(test,game)
	test.check(Xiaojing.state.memories.size()==7 and not Xiaojing.start_trial("joint"),"七份独立记忆齐全，联合试炼不提前开放")
	test.check(Xiaojing.start_trial("management"),"经营试炼可以开始")
	var old_profit: int = Xiaojing.state.trial.profit
	FarmEconomy.sell("wood",1)
	test.check(Xiaojing.state.trial.profit==old_profit,"出售旧库存不能冒充经营试炼的新田收入")
	Inventory.items.carrot_seed=200
	grow(game,60)
	FarmEconomy.sell("carrot",60)
	test.check(Xiaojing.check_trial() and Xiaojing.finish_quest(),"真实新田种植、收获与销售完成经营挑战")
	Inventory.coins=5000
	Inventory.items.wood=200
	Inventory.items.stone=200
	FarmProgress.build_upgrade("toolrack")
	FarmProgress.build_upgrade("bedding")
	test.check(Xiaojing.start_trial("planning"),"资源规划试炼可以开始")
	GameState.rest()
	game.change_location("farm",Vector2(700,500))
	game.world.resource_field.restore({})
	# 已有工具架使采集计划可在130体力内完成。
	for id in ["tree_5_8","tree_7_20","tree_9_24","tree_12_6","tree_27_8","rock_11_19","rock_28_24","rock_30_9","rock_39_24"]:
		var object: Node = game.world.resource_field.objects[id]
		while game.world.resource_field.state[id].hp>0:
			game.world.resource_field.hit(id,FarmResourceCatalog.TYPES[object.kind].tool)
	await near(test,game)
	test.check(Xiaojing.check_trial() and Xiaojing.finish_quest(),"真实采集与剩余体力完成资源规划")
	var cave_started := Xiaojing.start_trial("cave") and Xiaojing.start_cave(true)
	test.check(cave_started,"困难基础矿道试炼开启")
	if not cave_started:
		FarmSaveStore.restore(game,saved)
		return
	test.check(not Xiaojing.cave_move(Vector2i.LEFT),"矿道墙体不能穿越")
	var route := [Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(4,3),Vector2i(5,3),Vector2i(6,3),Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6),Vector2i(7,7),Vector2i(6,7),Vector2i(5,7),Vector2i(4,7),Vector2i(3,7),Vector2i(2,7),Vector2i(2,6),Vector2i(2,5),Vector2i(2,4),Vector2i(2,3),Vector2i(1,3),Vector2i(1,2),Vector2i(1,1)]
	var mining_duplicate_safe := true
	for point in route:
		var c: Dictionary = Xiaojing.state.cave
		Xiaojing.cave_move(point-Vector2i(c.x,c.y))
		if point.y*9+point.x in [12,34,66,70]:
			Xiaojing.cave_mine()
			var air: int = c.air
			mining_duplicate_safe = mining_duplicate_safe and not Xiaojing.cave_mine() and c.air==air
		if point==Vector2i(7,3):
			var interrupted := FarmSaveStore.snapshot(game)
			test.check(FarmSaveStore.restore(game,interrupted) and Xiaojing.state.cave.x==7 and Xiaojing.state.cave.mined.size()==2,"矿道中断与读档恢复位置、矿晶和气囊")
			await test.frames()
			await near(test,game)
	test.check(mining_duplicate_safe,"同一矿脉不能重复开采或扣气囊")
	test.check(Xiaojing.leave_cave() and "cave" in Xiaojing.state.trials and Xiaojing.finish_quest(),"合法路线完成矿道原型试炼并获得钻石")
	var diamonds: int = Xiaojing.state.diamonds
	test.check(not Xiaojing.leave_cave() and Xiaojing.state.diamonds==diamonds,"矿道结算不能重复领取")
	test.check(Xiaojing.start_trial("mechanism"),"七份记忆解锁四星机关")
	for i in range(5): Xiaojing.mechanism_input(0)
	test.check(Xiaojing.state.mechanism==0 and Xiaojing.state.mechanism_moves==0,"机关五步失败可重置，不锁死后续进度")
	for symbol in [0,2,4,6,8]: Xiaojing.mechanism_input(symbol)
	test.check("mechanism" in Xiaojing.state.trials and Xiaojing.finish_quest(),"机关试炼推进第11个专属任务")
	test.check(Xiaojing.start_trial("joint"),"四项试炼完成后开放联合考察")
	for location in ["home","farm","village"]: game.change_location(location)
	game.change_location("farm",Vector2(700,500))
	grow(game,6)
	await near(test,game)
	for symbol in [0,2,1]: Xiaojing.puzzle_input(symbol)
	test.check(Xiaojing.check_trial() and Xiaojing.finish_quest() and Xiaojing.state.quests.size()==12,"联合考察要求探索、种植与解谜，12项全部可推进")
	Inventory.coins=5000
	Inventory.items.wood=99
	Inventory.items.stone=99
	test.check(Xiaojing.repair_greenhouse() and not Xiaojing.repair_greenhouse(),"温室修复只扣一次材料")
	# 属性上限与所有关系事件；以测试夹具设置三属性，不伪称150小时试玩。
	Xiaojing.boost(100,100,100)
	test.check(Xiaojing.state.affection==100 and Xiaojing.state.trust==100 and Xiaojing.state.bond==100,"三个独立属性均限制0–100")
	test.check(Xiaojing.finish_event("flower") and not Xiaojing.finish_event("secret",false),"恋爱关系需要明确同意")
	test.check(Xiaojing.finish_event("secret",true) and Xiaojing.finish_event("promise") and Xiaojing.finish_event("stars"),"五段关系事件顺序完成并确立恋爱")
	test.check(Xiaojing.claim_relic() and not Xiaojing.claim_relic(),"遗匣一次性钻石不能重复领取")
	Inventory.items.potato=99
	Inventory.items.wheat=99
	Inventory.items.wood=99
	test.check(Xiaojing.hard_order() and not Xiaojing.hard_order(),"高阶委托三日周期防刷")
	Xiaojing.state.ore=10
	Inventory.items.stone=99
	diamonds=Xiaojing.state.diamonds
	test.check(Xiaojing.refine() and Xiaojing.state.diamonds==diamonds+2 and Xiaojing.state.ore==5,"稀有材料加工扣原矿与石料")
	Xiaojing.state.diamonds=1313
	test.check(not Xiaojing.confirm_wedding(true) and not Xiaojing.state.married,"1313颗钻石不能结婚")
	Xiaojing.state.diamonds=1314
	test.check(not Xiaojing.confirm_wedding(false) and Xiaojing.state.diamonds==1314,"求婚取消不扣钻石")
	game.hud.xiaojing_panel.open_panel()
	game.hud.xiaojing_panel.page="wedding"
	game.hud.xiaojing_panel.refresh()
	await test.frames(3)
	load("res://tests/story.gd").touch(test,game.hud.xiaojing_panel.content.get_child(3))
	test.check(Xiaojing.state.diamonds==1314 and game.hud.xiaojing_panel.page=="main","真实触点取消婚礼返回关系页，钻石保持")
	game.hud.xiaojing_panel.close_panel()
	test.check(Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0 and Xiaojing.state.married,"全部条件且1314颗钻石可一次完成婚礼事务")
	test.check(not Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0,"婚后不能重复扣除钻石")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		test.get_window().size=resolution
		await test.frames(3)
		game.hud.xiaojing_panel.open_panel()
		await test.frames(3)
		test.check(game.hud.safe.get_global_rect().encloses(game.hud.xiaojing_panel.get_global_rect()),"小京长列表完整适配："+str(resolution))
		game.hud.xiaojing_panel.close_panel()
	test.get_window().size=Vector2i(1280,720)
	await test.frames(3)
	var married := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.valid(married),"完整恋爱任务、婚姻和温室状态可保存")
	Xiaojing.restore(Xiaojing.defaults())
	test.check(FarmSaveStore.restore(game,married) and Xiaojing.state.married,"结婚状态恢复后保持")
	await test.frames()
	await near(test,game)
	test.check(Xiaojing.post_event("separate_desks") and not Xiaojing.post_event("separate_desks"),"婚后专属事件只提交一次")
	GameClock.day=int(Xiaojing.state.wedding_day)+519
	GameClock.running=true
	Xiaojing._process(0.6)
	test.check(not Xiaojing.state.ultimate,"婚后519日不提前开放终极彩蛋")
	GameClock.day+=1
	Xiaojing._process(0.6)
	GameClock.running=false
	test.check(Xiaojing.state.ultimate and Xiaojing.post_event("day520"),"婚后520日开放原创回信事件")
	for mutation in [{"diamonds":-1},{"affection":101},{"married":false},{"quests":["survey","survey"]},{"cave":{"x":"bad"}}]:
		var invalid := FarmSaveStore.snapshot(game)
		invalid.xiaojing.merge(mutation,true)
		test.check(not FarmSaveStore.valid(invalid),"非法小京存档整份拒绝："+str(mutation.keys()))
	var old := saved.duplicate(true)
	old.version=4
	old.erase("xiaojing")
	var migrated := FarmSaveSchema.normalize(old)
	test.check(not migrated.is_empty() and migrated.xiaojing.plants==0 and migrated.items==old.items and migrated.story==old.story,"v4存档不推算历史播种，保留原剧情与物品")
	test.check(FarmSaveSchema.normalize(migrated)==migrated,"v4到v5迁移可重复执行")
	FarmSaveStore.restore(game,saved)
	await test.frames()
