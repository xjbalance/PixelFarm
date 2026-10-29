extends RefCounted

static func settle(test: Node, game: Node, limit: int = 900) -> void:
	for _i in range(limit):
		await test.frames(1)
		if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: return
	test.check(false,"矿道点击在有限帧内结束："+str(game.auto_move.target))
	game.auto_move.cancel()

static func at(test: Node, game: Node, area: String, point: Vector2) -> void:
	game.hud.close_active_panel()
	game.change_location(area,point)
	await test.frames(5)

static func interact(test: Node, game: Node, id: String) -> void:
	var entry: Dictionary=MineState.placements.get(id,MineState.services.get(id,{}))
	var object_point: Vector2=MineState.point(entry)
	game.auto_move.request(object_point+Vector2(0,-14))
	await settle(test,game)

static func read(test: Node, game: Node, id: String) -> void:
	await interact(test,game,id)
	if MineState.placements.has(id) and MineState.placements[id].kind=="memory":
		test.check(game.hud.star_panel.visible,"实体调查点打开记忆操作："+id)
		if game.hud.star_panel.visible:
			StarStory.memory_action(MineState.placements[id].memory,0)
			game.hud.star_panel.close_panel()
		return
	test.check(game.hud.mine_panel.visible and game.hud.mine_panel.reading,"实体调查点打开矿道记录："+id)
	if game.hud.mine_panel.visible:
		await load("res://tests/story.gd").touch_button(test,game.hud.mine_panel,"读完并记下")
		game.hud.mine_panel.close_panel()

static func fresh_chapter(game: Node) -> void:
	var seen: Array=[]
	for id in Story.data.scenes:
		if Story.data.scenes[id].has("next"): seen.append(id)
	Story.restore({"stage":8,"motive":"home","lantern":"trade","seen":seen,"assisted_tools":true})
	VillageProjects.restore({"built":["well","cooperative","arbor"],"water_day":0,"tea_day":0})
	Letters.restore({})
	Letters.direction="trade"
	StarStory.restore(StarStory.defaults())
	MineState.restore(MineState.defaults())
	ChapterTwo.restore(ChapterTwo.defaults())
	GameState.set_control_mode("tap",false)
	GameState.manual_tool=false
	GameClock.day=200
	GameClock.minutes=600
	GameClock.running=false
	Inventory.coins=5000
	Inventory.items={"wood":300,"stone":300,"wheat":99,"potato":99,"carrot_seed":50}
	GameState.rest()

static func run(test: Node, game: Node) -> void:
	var saved := FarmSaveStore.snapshot(game)
	fresh_chapter(game)
	await at(test,game,"village",Vector2(1184,448))
	game.change_location("mine_a")
	test.check(GameState.location=="village","矿道入口前置未完成时禁止进入")
	await read(test,game,"transport")
	test.check(ChapterTwo.completed==["transport"],"读完真实运输单按顺序完成第二章第一项")
	await at(test,game,"village",Vector2(1168,272))
	await read(test,game,"entrance")
	test.check("mine_a" in MineState.state.unlocked and "entrance" in ChapterTwo.completed,"封矿牌调查解锁废弃矿道，主线不需要小京")
	Events.interaction_requested.emit("mine:enter")
	await test.frames(5)
	test.check(GameState.location=="mine_a" and game.mine_maps.mine_a.visible and not game.village.visible,"从地面入口进入真实角色地图")
	test.check(game.player.get_parent()==game.mine_maps.mine_a.actors and game.mine_maps.mine_a.ground.get_used_cells().size()==1120,"矿区为完整32px TileMap地图并复用原玩家")
	await interact(test,game,"a_tutorial")
	game.hud.mine_panel.close_panel()
	test.check(not ChapterTwo.knows("mining_manual"),"矿道调查中途关闭不提前记录线索")
	await read(test,game,"a_tutorial")
	await interact(test,game,"a_copper_0")
	var hp: int=MineState.ore_state("a_copper_0").hp
	test.check(hp==1 and Inventory.count("copper_ore")==0,"点击矿石只采一次，未耗尽时不提前掉落")
	var stamina: int=GameState.stamina
	await interact(test,game,"a_copper_0")
	test.check(MineState.ore_state("a_copper_0").hp==0 and Inventory.count("copper_ore")==3 and GameState.stamina==stamina-2,"最后一击正确消耗体力并发放铜矿")
	var amount: int=Inventory.count("copper_ore")
	test.check(not MineState.mine("a_copper_0") and Inventory.count("copper_ore")==amount,"耗尽矿石不能重复掉落")
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(game.auto_move.navigation.walkable(Vector2i(4,19)),"矿脉清除后格子可通行")
	await interact(test,game,"rail_west")
	test.check(game.hud.mine_panel.visible,"未修轨道显示明确材料确认")
	game.hud.mine_panel.close_panel()
	var wood: int=Inventory.count("wood")
	test.check(MineState.repair_track("rail_west") and not MineState.repair_track("rail_west") and Inventory.count("wood")==wood-6,"修复轨道事务只扣一次材料")
	await interact(test,game,"rail_west")
	test.check(MineState.gate_open("rail") and "repair" in ChapterTwo.completed,"实体扳杆打开道岔并推进实际修轨任务")
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(game.auto_move.navigation.walkable(Vector2i(24,18)),"轨道机关打开后碰撞和导航同步")
	await read(test,game,"a_record1")
	await read(test,game,"a_record2")
	test.check("mine_b" in MineState.state.unlocked,"两份矿工记录解锁地下水脉")
	# 原路线中的裂隙确实被矿块阻挡，清除后可进入独立隐藏房间。
	await at(test,game,"mine_a",Vector2(336,208))
	game.auto_move.request(Vector2(624,176))
	await settle(test,game)
	test.check(game.auto_move.state==game.auto_move.State.FAILED,"隐藏通道未清理前不能穿过裂隙矿块")
	for _i in range(3): await interact(test,game,"a_crack")
	await interact(test,game,"a_chest")
	test.check("a_chest" in MineState.state.chests,"清理隐藏通道后角色能走入并打开工具箱")
	var chests: Array = MineState.state.chests.duplicate()
	await interact(test,game,"a_chest")
	test.check(MineState.state.chests==chests,"隐藏箱一次性奖励防重复")
	await economy(test,game)
	await mechanism_flow(test,game)
	await load("res://tests/mining_expansion.gd").run(test,game)
	FarmSaveStore.restore(game,saved)
	await test.frames(5)

static func economy(test: Node, game: Node) -> void:
	# 规则测试用定位夹具，行动、消耗与最后一击仍由生产入口执行。
	await at(test,game,"mine_a",Vector2(8*32+16,20*32+48))
	Inventory.items.copper_ore=999
	var before: int=GameState.stamina
	MineState.state.ores.a_copper_1={"hp":1,"ready_day":0}
	test.check(not MineState.mine("a_copper_1") and MineState.ore_state("a_copper_1").hp==1 and GameState.stamina==before,"背包满时最后一击不扣体力、不丢矿物")
	Inventory.items.copper_ore=40
	GameState.stamina=0
	test.check(not MineState.mine("a_copper_1") and MineState.ore_state("a_copper_1").hp==1,"体力不足不能改变矿脉耐久")
	GameState.rest()
	await at(test,game,"village",Vector2(528,480))
	test.check(MineState.build_furnace() and not MineState.build_furnace(),"实体工台熔炼炉建造防重复扣费")
	test.check(MineState.enqueue("copper_bar",3),"铜矿加工正确进入跨天队列")
	var queue_save := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.valid(queue_save) and FarmSaveStore.restore(game,queue_save) and MineState.state.queue.size()==1,"加工队列及领取ID保存恢复")
	await test.frames(5)
	var job: int=MineState.state.queue[0].id
	test.check(not MineState.claim_job(job),"跨天加工未完成不能领取")
	test.advance_day()
	await test.frames(4)
	Inventory.items.copper_bar=999
	test.check(not MineState.claim_job(job) and MineState.state.queue.size()==1,"加工成品满包时保留队列")
	Inventory.items.erase("copper_bar")
	test.check(MineState.claim_job(job) and not MineState.claim_job(job) and Inventory.count("copper_bar")==3,"加工领取与产出只结算一次")
	Inventory.items.iron_ore=40
	test.check(MineState.upgrade_tool() and MineState.state.tool==2,"强化镐升级扣除真实材料")
	GameClock.day+=2
	MineState.advance_day()
	await test.frames(4)
	test.check(MineState.ore_state("a_copper_0").hp==2,"矿石到刷新日恢复耐久")

static func mechanism_flow(test: Node, game: Node) -> void:
	await at(test,game,"mine_a",Vector2(1072,336))
	await interact(test,game,"a_down")
	await test.frames(4)
	test.check(GameState.location=="mine_b","点击实体阶梯切换地下水脉")
	await read(test,game,"b_hint")
	await interact(test,game,"b_valve1")
	test.check(not MineState.state.water_lowered and MineState.state.water_step==0,"错误水闸顺序反馈并可重试")
	await interact(test,game,"b_valve0")
	var valve_save := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.restore(game,valve_save) and MineState.state.water_step==1,"水位机关中断读取恢复正确的第一步")
	await test.frames(5)
	await interact(test,game,"b_valve1")
	test.check(MineState.state.water_lowered,"按环境提示操作两个实体阀门降低水位")
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(game.auto_move.navigation.walkable(Vector2i(26,17)),"退水后石桥实际可导航")
	await interact(test,game,"b_rockgate")
	test.check(MineState.state.hardened,"强化镐清理阻挡深层通道的铁锈岩层")
	await read(test,game,"b_record")
	test.check("mine_c" in MineState.state.unlocked,"水位与值班记录多条件解锁晶石洞窟")
	await interact(test,game,"b_down")
	await test.frames(5)
	test.check(GameState.location=="mine_c","水脉阶梯可进入第三张实体矿区")
	await read(test,game,"c_hint")
	await interact(test,game,"c_res0")
	test.check(MineState.state.resonance_step==0 and not MineState.state.resonance_open,"晶石错序清空本轮，不扣材料且可重试")
	await interact(test,game,"c_res1")
	var resonance_save := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.restore(game,resonance_save) and MineState.state.resonance_step==1,"晶石共鸣中断读取保留已正确激活的顺序")
	await test.frames(5)
	for id in ["c_res0","c_res2"]: await interact(test,game,id)
	test.check(MineState.state.resonance_open,"按麦穗、河沙、白石顺序激活实体晶柱")
	await read(test,game,"c_record")
	test.check("echo" in ChapterTwo.completed,"穿过共鸣门读到签名，完成第二章洞窟任务")
	await interact(test,game,"c_chest")
	test.check("c_chest" in MineState.state.chests,"高级洞窟隐藏星匣可以真实找到并领取")
