extends "res://tests/runner.gd"
const Flow=preload("res://tests/mining.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);game.get_node("Audio").muted=true;GameClock.running=false
	await frames(5)
	await reproductions()
	await lifecycle()
	await diagnostics()
	await gifts()
	await level_audit()
	await soak()
	print("STABILITY RESULT: %d checks, %d failures" % [checked,failed])
	game.persistence_enabled=false;game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reproductions() -> void:
	load("res://tests/star_runner.gd").fixture(game,false)
	GameClock.minutes=360
	check(not Story.complete("bench","wait") and GameClock.minutes==360,"首章完成后长椅不能反复快进到18点")
	Story.stage=7;Story.lantern="";Story.seen.erase("festival");Story.seen.erase("bench")
	check(Story.complete("bench","wait") and GameClock.minutes==1080,"保留庆典准备的合法剧情快进")
	GameClock.minutes=360
	check(not Story.complete("bench","wait") and GameClock.minutes==360,"庆典待完成期间也不能每天反复跳时")
	load("res://tests/star_runner.gd").fixture(game,false)
	Xiaojing.state.trials=[]
	await Flow.at(self,game,"farm",Vector2(1360,816))
	AbyssState.state.max_clear=20
	check(LegendTrials.begin("cave"),"旧目标兼容夹具开启矿道试炼")
	for d in range(10,20): LegendTrials.visited(d)
	AbyssState.state.air=1;LegendTrials.visited(20)
	# 模拟退出/重入检查点把当前空气补满，终点记录必须保持。
	AbyssState.state.air=160;LegendTrials.visited(20)
	check(not LegendTrials.finish(),"终点空气不足不能靠重进检查点改写试炼结果")
	var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(LegendState.snapshot())))
	LegendState.restore(proof)
	check(LegendState.state.contract.arrival_air==1 and not LegendTrials.finish(),"终点空气证明在JSON恢复后仍不能被当前空气覆盖")
	var old: Dictionary=proof.contract.duplicate(true);old.erase("arrival_air")
	check(AbyssSaveSchema.contract(old,GameClock.day),"旧v10在途合约无证明字段仍可读取，不重置进度")
	LegendTrials.cancel()
	check(LegendTrials.begin("cave"),"失败试炼可明确重试")
	for d in range(10,21): AbyssState.state.air=20;LegendTrials.visited(d)
	check(LegendTrials.finish(),"真正保留终点空气的路线仍可结算")
	load("res://tests/star_runner.gd").fixture(game,false)
	await Flow.at(self,game,"farm",Vector2(700,500))
	Inventory.coins=100
	check(FarmSaveStore.write(game),"隔离目录写入自动保存基线")
	game.persistence_enabled=true;Inventory.coins=101
	for i in range(5): Events.progress_committed.emit()
	await frames(4)
	var backup := FarmSaveStore.read(FarmSaveStore.PATH+".bak")
	check(backup.get("coins")==100 and FarmSaveStore.read().get("coins")==101,"同帧提交仅保存一次，备份保留前一有效状态")
	game.persistence_enabled=false

func lifecycle() -> void:
	load("res://tests/star_runner.gd").fixture(game,true)
	await Flow.at(self,game,"farm",Vector2(700,500))
	var saved := FarmSaveStore.snapshot(game)
	game.hud.xiaojing_panel.open_panel()
	game.hud.xiaojing_panel.read_story("stale","pending",func(): Inventory.coins+=100)
	check(FarmSaveStore.restore(game,saved) and not GameState.modal and not game.hud.xiaojing_panel.pending.is_valid(),"读档清除旧窗口回调，不能在新状态提交旧交互")
	await frames(4)
	game.auto_move.request(Vector2(752,560))
	var day: int=GameClock.day;var minute: float=GameClock.minutes
	game._notification(NOTIFICATION_APPLICATION_PAUSED)
	GameClock._process(90)
	check(GameClock.day==day and GameClock.minutes==minute and game.auto_move.target.is_empty(),"切后台暂停时间并清除自动任务，不离线刷日结算")
	game._notification(NOTIFICATION_APPLICATION_RESUMED)
	GameClock.running=false
	game.auto_move.request(Vector2(752,560));game.freeze_for_close()
	check(not GameClock.running and GameState.modal and game.auto_move.target.is_empty(),"关闭前冻结输入与时间，保存后不会继续采集")
	GameState.set_modal(false)
	River.state.venue_used=true;River.state.wedding_step=1;StarStory.state.wedding_phase=3
	game.change_location("greenhouse",Vector2(640,400));await frames(4)
	var venue: Node=game.mine_maps.greenhouse
	venue.couple.position=Vector2(690,390);game.get_node("Audio").muted=true
	var before: Vector2=venue.couple.position
	venue._process(.5)
	check(venue.couple.position.distance_to(before)>1,"关闭音乐不再停止婚礼角色走位")
	FarmSaveStore.restore(game,saved);await frames(4)
func diagnostics() -> void:
	check(not Playtest.enabled,"无头回归默认关闭诊断，避免混入真人记录")
	var before := FarmSaveStore.snapshot(game)
	check(Playtest.start(),"debug版本可启用本地诊断")
	Playtest.account(2.0,false,false,42);Playtest.account(3.0,false,true);Playtest.account(4.0,true,false)
	Playtest.record("diamonds",{"source":"audit","delta":2,"unwanted_private_field":"must not write"})
	Playtest.record("trial_start",{"id":"test"});Playtest.record("trial_start",{"id":"test"})
	Playtest.trial_failure("test","budget");Playtest.trial_failure("test","budget")
	check(Playtest.summary.active_s==2 and Playtest.summary.paused_s==3 and Playtest.summary.background_s==4 and Playtest.summary.floors_s["42"]==2,"真实时长/菜单/后台/楼层时间分开记录")
	check(Playtest.summary.trial_failures==1 and Playtest.summary.trial_retries==1,"失败反馈去重并记录重试次数")
	check(Playtest.flush(),"诊断可写独立本地日志")
	var text: String=FileAccess.get_file_as_string(Playtest.LOG)
	check("unwanted_private_field" not in text and "audit" in text,"诊断只保存固定字段，不收集任意附加信息")
	check(FarmSaveStore.snapshot(game)==before,"诊断启用/写文件不改变正式存档和经济")
	var plants: int=Xiaojing.state.plants
	game.farm.plots.erase("24,19");Inventory.items.wheat_seed=3;GameState.rest()
	game.farm.use_tool(Vector2i(24,19),"hoe");game.farm.use_tool(Vector2i(24,19),"wheat_seed");game.farm.use_tool(Vector2i(24,19),"wheat_seed")
	check(Playtest.summary.plants==1 and Xiaojing.state.plants==plants+1,"诊断从真实提交记录播种，失败输入不重复记")
	Playtest.flush();Playtest.enabled=false;Playtest.start();Playtest.account(1,false,false);Playtest.flush()
	var total: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Playtest.SUMMARY))
	check(total.lifetime.active_s==3 and total.lifetime.plants==1,"独立诊断文件累计多会话时长与行为，不双算flush")
	Playtest.enabled=false;FarmSaveStore.restore(game,before);await frames(4)
func gifts() -> void:
	var saved := FarmSaveStore.snapshot(game)
	var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true
	Xiaojing.restore(x);StarStory.restore(StarStory.defaults());LegendState.restore(LegendState.defaults())
	Inventory.items.wheat=10;Inventory.items.carrot=10;Inventory.items.potato=10;Inventory.items.crystal=10
	var sum := 0
	for gift in ["wheat","carrot","potato","crystal","wheat"]:
		await load("res://tests/xiaojing.gd").near(self,game)
		check(Xiaojing.gift(gift) and not Xiaojing.gift(gift),"礼物每日限额保留："+gift)
		sum+=int(StarStory.data.gifts[gift].affection)
		advance_day()
	check(Xiaojing.state.affection==sum and Xiaojing.state.trust==0 and Xiaojing.state.bond==0,"四种有用礼物轮换有收益，同礼仍不能填三项属性")
	await load("res://tests/xiaojing.gd").near(self,game)
	check(Xiaojing.gift("wheat") and Xiaojing.state.affection==sum,"紧接着重复同礼无额外收益")
	FarmSaveStore.restore(game,saved);await frames(4)
func fixture(depth: int) -> void:
	var a := AbyssState.defaults();a.unlocked=true;a.depth=depth;a.max_clear=depth-1;a.gear=int(AbyssState.layout(depth).gear)
	for d in range(1,depth): a.gates.append(d);a.notes.append(d)
	for d in range(20,depth,20): a.bosses.append(d)
	a.checkpoint=maxi(1,int((depth-1)/10)*10)
	AbyssState.restore(a)
	game.change_location("abyss",AbyssState.point(AbyssState.layout().entry))
func route(id: String) -> PackedVector2Array:
	var object: Node2D=game.mine_maps.abyss.objects[id]
	return game.auto_move.navigation.path_to({"kind":"object","object":object,"point":object.global_position})
func level_audit() -> void:
	load("res://tests/star_runner.gd").fixture(game,false)
	var chapter := ChapterTwo.defaults();chapter.policy="rotation"
	for q in ChapterTwo.definitions.slice(0,8):
		chapter.completed.append(q.id)
		for f in q.conditions:
			if f not in chapter.facts: chapter.facts.append(f)
	ChapterTwo.restore(chapter)
	Inventory.items.wood=500;Inventory.items.crystal=100
	for depth in range(1,101):
		fixture(depth);await frames(4)
		game.auto_move.navigation.rebuild()
		var accessible := true
		for id in game.mine_maps.abyss.objects:
			if id=="note" or id.begins_with("lever_") or id.begins_with("utility_"): accessible=accessible and not route(id).is_empty()
		check(accessible and route("down").is_empty(),"实际碰撞闭闸前可达全部关键控制点，出口不可穿墙："+str(depth))
		AbyssState.state.notes.append(depth);AbyssState.state.gates.append(depth);AbyssState.commit();Events.navigation_changed.emit();await frames(4);game.auto_move.navigation.rebuild()
		check(not route("down").is_empty() and not route("chest").is_empty() and not route("ore_0").is_empty() and not route("ore_1").is_empty(),"实际碰撞开闸后出口/箱/两矿均可达："+str(depth))
		if AbyssState.layout().has("passage_cells"):
			game.player.position=AbyssState.point(AbyssState.layout().exit)
			var old_route := route("chest")
			var switch_route := route("passage")
			check(not switch_route.is_empty(),"侧廊支架可合法到达："+str(depth))
			if not switch_route.is_empty(): game.player.position=switch_route[-1]
			var wood: int=Inventory.count("wood")
			check(AbyssRules.open_passage() and not AbyssRules.open_passage() and Inventory.count("wood")==wood-2,"侧廊一次付费，不重复扣材料："+str(depth))
			await frames(4);game.auto_move.navigation.rebuild();game.player.position=AbyssState.point(AbyssState.layout().exit)
			check(route("chest").size()<old_route.size(),"新侧廊真实缩短寻路，原路线仍保留："+str(depth))
			var snapshot := FarmSaveStore.snapshot(game)
			check(FarmSaveStore.restore(game,snapshot) and depth in AbyssState.state.shortcuts,"侧廊开启与资源状态保存恢复："+str(depth))
			await frames(4)

func soak() -> void:
	load("res://tests/star_runner.gd").fixture(game,true)
	var chapter := ChapterTwo.defaults();chapter.policy="rotation"
	for q in ChapterTwo.definitions.slice(0,8):
		chapter.completed.append(q.id)
		for id in q.conditions:
			if id not in chapter.facts: chapter.facts.append(id)
	ChapterTwo.restore(chapter)
	var a := AbyssState.defaults();a.unlocked=true;AbyssState.restore(a)
	River.state.venue_used=true
	var memory_start: int=0
	var nodes_start: int=0
	for i in range(352):
		var area: String=["farm","home","village","abyss","greenhouse"][i%5]
		if area=="abyss": game.mine_maps.abyss.rebuild()
		game.change_location(area)
		GameState.set_control_mode("tap" if i%2==0 else "joystick",false)
		await frames(4)
		if i==31: memory_start=OS.get_static_memory_usage();nodes_start=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await frames(5)
	var growth: int=OS.get_static_memory_usage()-memory_start
	var nodes_end: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	check(nodes_end<=nodes_start+16 and growth<8*1024*1024,"320次场景/模式切换后节点和静态内存保持有界")
	print("SOAK MEMORY GROWTH BYTES ",growth," NODE START/END ",nodes_start,"/",nodes_end)
