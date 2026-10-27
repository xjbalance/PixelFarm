extends RefCounted
## 新区规则、真实输入与存档恢复；定位/日期/库存夹具不作为真人通关时间。
const Flow = preload("res://tests/mining.gd")

static func run(test: Node, game: Node) -> void:
	await advanced(test,game)
	await chapter(test,game)
	await input_and_trials(test,game)
	await saves(test,game)

static func advanced(test: Node, game: Node) -> void:
	await Flow.at(test,game,"mine_c",Vector2(30*32+16,9*32+16))
	var energy: int=GameState.stamina
	test.check(not MineState.mine("c_star_0") and GameState.stamina==energy and MineState.ore_state("c_star_0").hp==4,"强化镐不能采星辉原矿，拒绝时耐久体力不变")
	await Flow.at(test,game,"village",Vector2(528,480))
	Inventory.items.iron_bar=10
	Inventory.items.star_alloy=5
	test.check(MineState.upgrade_tool() and MineState.state.tool==3 and not MineState.upgrade_tool(),"星纹镐升级及最高等级防重复扣费")
	await Flow.at(test,game,"village",Vector2(1168,240))
	var wood: int=Inventory.count("wood")
	test.check(not MineState.new_survey() and Inventory.count("wood")==wood,"高级矿脉未采完时不浪费勘探补给")
	var before: int=Xiaojing.state.diamonds
	await Flow.at(test,game,"mine_c",WorldTravel.entry("mine_c"))
	for id in ["c_crystal_0","c_crystal_1"]:
		GameState.rest()
		for hit in range(2): await Flow.interact(test,game,id)
	for id in ["c_star_0","c_star_1","c_star_2","c_diamond_0","c_diamond_1","c_diamond_2"]:
		GameState.rest()
		for hit in range(4): await Flow.interact(test,game,id)
	test.check(Inventory.count("starlight_ore")==9 and Xiaojing.state.diamonds==before+3,"三处星辉矿与三处钻石矿真实点击采集，固定保底产出")
	var depleted := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.restore(game,depleted) and MineState.ore_state("c_diamond_2").hp==0 and Xiaojing.state.diamonds==before+3,"读取耗尽矿脉不会重掷或重复发钻石")
	await test.frames(5)
	await Flow.at(test,game,"village",Vector2(528,480))
	test.check(MineState.enqueue("refine",3),"星辉原矿进入真实跨天精炼队列")
	var job: int=MineState.state.queue[-1].id
	test.advance_day()
	await test.frames(4)
	before=Xiaojing.state.diamonds
	test.check(MineState.claim_job(job) and not MineState.claim_job(job) and Xiaojing.state.diamonds==before+6,"三批星辉精炼产六钻且队列不能重复领取")
	before=Xiaojing.state.diamonds
	test.check(MineState.complete_commission() and not MineState.complete_commission() and Xiaojing.state.diamonds==before+5,"新采高级矿脉支持三日委托，重复提交不扣材料或再发钻")
	await Flow.at(test,game,"village",Vector2(1168,240))
	test.check(MineState.new_survey() and MineState.ore_state("c_diamond_0").hp==4 and "c_chest" in MineState.state.chests,"消耗补给刷新高级矿脉，宝箱与机关不重置")
	await Flow.at(test,game,"mine_c",Vector2(1040,400))
	GameState.rest()
	before=Xiaojing.state.diamonds
	for i in range(4): await Flow.interact(test,game,"c_diamond_0")
	test.check(Xiaojing.state.diamonds==before+2 and MineState.state.diamond_counter==4,"跨存档稳定计数每第四条钻石矿脉额外一颗")
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(not game.auto_move.navigation.walkable(Vector2i(36,7)),"未采完的新矿脉具有真实导航障碍")
	await Flow.at(test,game,"mine_c",Vector2(32*32+16,10*32+16))
	GameClock.day+=3
	MineState.advance_day()
	test.check(MineState.ore_state("c_diamond_0").hp==0,"资源刷新不会在玩家脚下重建碰撞")
	game.player.position=Vector2(1072,432)
	MineState.advance_day()
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(MineState.ore_state("c_diamond_0").hp==4 and not game.auto_move.navigation.walkable(Vector2i(32,10)),"移开后再检查刷新恢复矿脉和导航障碍")

static func chapter(test: Node, game: Node) -> void:
	test.check(ChapterTwo.completed.size()==6,"第二章前六项按真实探索与机关顺序完成")
	for id in ["linya","zhou","ahe"]:
		game.hud.close_active_panel()
		var area: String="farm" if id=="linya" else "village"
		await Flow.at(test,game,area,WorldTravel.entry(area))
		var person: Node2D
		for object in game.get_tree().get_nodes_in_group("interactables"):
			if "person_id" in object and object.person_id==id and object.is_visible_in_tree(): person=object; break
		game.player.global_position=person.global_position+Vector2(0,45)
		Story.request(id)
		test.check(game.hud.mine_panel.visible and game.hud.mine_panel.reading,"真实NPC入口接续第二章口述记录："+id)
		game.hud.mine_panel.finish_reading()
		game.hud.mine_panel.close_panel()
	test.check(ChapterTwo.completed.size()==7,"三位主线NPC各自的记录完成第七项，小京不是主线前置")
	for direction in ["trade","explore","life"]:
		Letters.direction=direction
		test.check(not ChapterTwo.branch_line().is_empty(),"第一章发展方向有第二章对应对白："+direction)
	Letters.direction="trade"
	await Flow.at(test,game,"village",Vector2(752,720))
	var copper: int=Inventory.count("copper_ore")
	test.check(ChapterTwo.finish_discussion("reserve") and not ChapterTwo.finish_discussion("study") and ChapterTwo.completed.size()==8 and Inventory.count("copper_ore")==copper+6,"讨论会确认保存开放规则、首章贸易奖励且不能重领或改写")
	var snapshot := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.restore(game,snapshot) and ChapterTwo.policy=="reserve" and ChapterTwo.current().id=="backwater","第二章八项、开放选择与一次性奖励保存恢复")
	await test.frames(5)

static func input_and_trials(test: Node, game: Node) -> void:
	for area in MineState.AREAS:
		await Flow.at(test,game,area,WorldTravel.entry(area))
		var goal := WorldTravel.entry(area)+Vector2(-32,-64)
		var screen: Vector2=game.player.get_canvas_transform()*goal
		var touch := InputEventScreenTouch.new()
		touch.index=71
		touch.position=screen
		touch.pressed=true
		game.get_viewport().push_input(touch,true)
		touch=touch.duplicate()
		touch.pressed=false
		game.get_viewport().push_input(touch,true)
		await Flow.settle(test,game)
		test.check(game.player.global_position.distance_to(goal)<2,"矿区原生触点经相机转换后真实抵达："+area)
		game.auto_move.request(goal+Vector2(64,0))
		GameState.set_control_mode("joystick",false)
		var origin: Vector2=game.player.global_position
		game.player.touch_direction=Vector2.RIGHT
		await test.frames(8)
		game.player.touch_direction=Vector2.ZERO
		test.check(game.auto_move.target.is_empty() and game.player.global_position.x>origin.x+8,"矿区切换备用摇杆取消自动移动且原角色可行走："+area)
		GameState.set_control_mode("tap",false)
		game.auto_move.request(Vector2(16,16))
		await Flow.settle(test,game)
		test.check(game.auto_move.state==game.auto_move.State.FAILED,"点击矿区岩壁在有限帧内失败："+area)
	# 对低级工具的验证无需重置玩家已有工具进度；在隔离夹具中测试。
	var hidden := Xiaojing.defaults()
	hidden.plants=520
	hidden.plant_serial=520
	hidden.unlocked=true
	for q in Xiaojing.data.quests.slice(0,7): hidden.quests.append(q.id)
	for memory in Xiaojing.data.memories: hidden.memories.append(memory.id)
	hidden.trial={"id":"cave","day":GameClock.day,"plants":0,"harvest":0,"profit":0,"wood":0,"stone":0,"sown":{},"outputs":{},"maps":[],"puzzles":0}
	Xiaojing.restore(hidden)
	LegendState.restore(LegendState.migrate(hidden,StarStory.snapshot()))
	await Flow.at(test,game,"village",Vector2(1168,240))
	test.check(MineState.start_expedition() and not MineState.start_expedition(),"实体矿道试炼补给与本轮状态只创建一次")
	await Flow.at(test,game,"mine_a",WorldTravel.entry("mine_a"))
	GameState.rest()
	for id in ["a_copper_2","a_copper_3","a_copper_4","a_copper_5"]:
		await Flow.interact(test,game,id)
		await Flow.interact(test,game,id)
	await Flow.interact(test,game,"a_down")
	await Flow.interact(test,game,"b_exit")
	await Flow.interact(test,game,"a_exit")
	test.check(GameState.location=="village" and "cave" in Xiaojing.state.trials and MineState.state.expedition.is_empty(),"实体地图同日探索、采矿、到水脉并返回完成小京矿道试炼")
	hidden=Xiaojing.snapshot()
	hidden.trial={"id":"mechanism","day":GameClock.day,"plants":0,"harvest":0,"profit":0,"wood":0,"stone":0,"sown":{},"outputs":{},"maps":[],"puzzles":0}
	Xiaojing.restore(hidden)
	LegendState.restore(LegendState.migrate(hidden,StarStory.snapshot()))
	await Flow.at(test,game,"mine_c",WorldTravel.entry("mine_c"))
	for i in [0,2,4,6,8]: await Flow.interact(test,game,"star_"+str(i))
	test.check("mechanism" in Xiaojing.state.trials and Xiaojing.state.mechanism==511,"行走到五盏实体星灯完成九灯机关试炼")
	var before: int=Xiaojing.state.bond
	await Flow.read(test,game,"c_memory")
	await Flow.read(test,game,"c_memory")
	test.check(Xiaojing.state.memories.size()==7 and Xiaojing.state.bond==before,"已有记忆在洞窟补页重读不会重复计数或刷关系")

static func saves(test: Node, game: Node) -> void:
	var snapshot := FarmSaveStore.snapshot(game)
	var v6 := snapshot.duplicate(true)
	v6.version=6;v6.erase("appearance")
	v6.location="farm"
	v6.player=[656,440]
	v6.erase("mines")
	v6.erase("chapter_two")
	var migrated := FarmSaveSchema.normalize(v6)
	test.check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.xiaojing==v6.xiaojing and migrated.items==v6.items and migrated.plots==v6.plots and migrated.control_mode==v6.control_mode,"v6迁移完整保留小京、钻石、经营、操作方式，新增矿洞不补发旧奖励")
	test.check(FarmSaveSchema.normalize(migrated)==migrated and v6.version==6,"v6迁移幂等且不修改原始字典")
	for mutation in [{"tool":4},{"queue":[{"id":1,"recipe":"bad"}]},{"water_step":7},{"chests":["c_chest","c_chest"]},{"ores":{"c_diamond_0":{"hp":-1,"ready_day":0}}}]:
		var invalid := snapshot.duplicate(true)
		invalid.mines.merge(mutation,true)
		test.check(not FarmSaveStore.restore(game,invalid) and GameState.location==snapshot.location,"非法矿洞状态整份拒绝且不污染当前地图："+str(mutation.keys()))
	var path := "user://mine_backup_test.json"
	test.check(FarmSaveStore.write(game,path) and FarmSaveStore.write(game,path),"v7矿洞状态真实落盘并生成备份")
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	var recovered := FarmSaveStore.read(path)
	# JSON读入的整数为float，统一序列化再比，避免Dictionary的严格类型比较误报。
	var expected: Dictionary=JSON.parse_string(JSON.stringify(snapshot))
	test.check(not recovered.is_empty() and recovered.mines==expected.mines and recovered.xiaojing==expected.xiaojing and recovered.chapter_two==expected.chapter_two,"损坏主档回退有效v7矿洞备份")
	test.check(FarmSaveStore.write(game,path) and not FarmSaveStore.read(path+".bak").is_empty(),"备份恢复后再保存保留有效备份，损坏主档另存corrupt")
