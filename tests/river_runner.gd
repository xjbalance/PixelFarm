extends "res://tests/runner.gd"
const Flow = preload("res://tests/mining.gd")
const Hidden = preload("res://tests/xiaojing.gd")
var timings: Array[float]=[]
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	game.get_node("Audio").muted=true;GameClock.running=false;GameWeather.enabled=false
	await frames(5)
	load("res://tests/star_runner.gd").fixture(game,false)
	River.restore(River.defaults());LegendState.restore(LegendState.defaults());StarStory.restore(StarStory.defaults())
	Xiaojing.state.greenhouse=false;Xiaojing.state.memories=[]
	var chapter := ChapterTwo.defaults();chapter.policy="rotation"
	for q in ChapterTwo.definitions.slice(0,8):
		chapter.completed.append(q.id)
		for fact in q.conditions:
			if fact not in chapter.facts: chapter.facts.append(fact)
	ChapterTwo.restore(chapter)
	Inventory.coins=100000
	Inventory.items={"wood":900,"stone":900,"wheat":900,"potato":300,"carrot":300,"iron_bar":90,"copper_bar":90,"star_alloy":90,"crystal":400,"starlight_ore":400,"copper_ore":90,"iron_ore":90,"carrot_seed":200,"wheat_seed":200,"potato_seed":200}
	FarmProgress.built.assign(["toolrack","bedding"]);GameState.rest()
	await memories()
	await hundred()
	if failed: finish();return
	await chapter_tail()
	await wedding_room()
	await postlife()
	await compatibility()
	await daily_and_hazards()
	finish()
func finish() -> void:
	print("RIVER RESULT: %d checks, %d failures" % [checked,failed])
	if not timings.is_empty(): timings.sort();print("MAP TIMING USEC P50 ",timings[timings.size()/2]," P95 ",timings[int(timings.size()*.95)])
	print("STATIC MEMORY BYTES ",OS.get_static_memory_usage()," PEAK ",OS.get_static_memory_peak_usage())
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free()
	await frames(4);get_tree().quit(1 if failed else 0)
func place_memory(id: String) -> void:
	for m in Xiaojing.data.memories:
		if m.id==id: await Flow.at(self,game,m.location,Vector2(m.position[0],m.position[1])+Vector2(0,36));return
func memories() -> void:
	await place_memory("window")
	check(not StarStory.memory_action("window",0),"新游戏不能只点读完跳过窗光调查")
	check(game.hud.star_panel.memory_probe("window","date") and game.hud.star_panel.memory_probe("window","light") and StarStory.memory_action("window",0),"窗边日期与光照两步调查才取得记忆")
	for id in ["pond_high","pond_low","bridge_new"]:
		var p: Dictionary=River.data.points[id]
		await Flow.at(self,game,p.area,Vector2(p.position[0],p.position[1])+Vector2(0,36))
		check(game.hud.river_panel.probe(id),"实地测量独立点："+id)
	await place_memory("pond");check(StarStory.memory_action("pond",0),"池岸两处实测关联安全退路")
	await place_memory("bridge");game.hud.star_panel.memory_probe("bridge","old");check(StarStory.memory_action("bridge",0),"新旧桥柱刻度对照取得拓片")
	await place_memory("mill");game.hud.star_panel.memory_probe("mill","seed");game.hud.star_panel.memory_probe("mill","empty");check(StarStory.memory_action("mill",0),"留种与空车两栏对照取得运输记忆")
	await Hidden.person(self,game,"ahe");check(River.talk("ahe") and not River.has("talk2:ahe"),"听阿禾口述完成记忆，不提前完成第二章后半证词")
	await place_memory("post");check(StarStory.memory_action("post",0),"口述后回留言牌取得记忆")
	await Flow.at(self,game,"home",Vector2(752,468))
	for symbol in [0,2,1]: Xiaojing.puzzle_input(symbol)
	await place_memory("hearth");check(StarStory.memory_action("hearth",0),"实体种箱解谜影响炉边记忆")
	await place_memory("orchard");check(not game.hud.star_panel.memory_probe("orchard","night"),"白天不能假装观察晚归灯图")
	GameClock.minutes=1140;GameClock.changed.emit();check(game.hud.star_panel.memory_probe("orchard","night") and StarStory.memory_action("orchard",0),"夜晚实际观察灯图取得最后记忆")
	check(Xiaojing.state.memories.size()==7 and River.state.memory_seen.size()==7,"七份独立机制记忆全部完成且唯一")
	await Flow.at(self,game,"farm",Vector2(1360,816))
	StarStory.inspect_greenhouse();StarStory.repair_vent()
	for id in ["window","bridge","post"]: StarStory.assemble(id)
	StarStory.choose("closure","water")
	await Hidden.near(self,game);StarStory.choose("tables","together")
func act_point(id: String) -> void:
	game.hud.close_active_panel()
	var p: Node2D=game.mine_maps.abyss.objects[id]
	game.auto_move.request(p.global_position+Vector2(0,-14))
	await Flow.settle(self,game,1500)
func read_note() -> void:
	await act_point("note")
	check(game.hud.abyss_panel.visible and game.hud.abyss_panel.reading,"实体刻痕可读："+str(AbyssState.state.depth))
	if game.hud.abyss_panel.visible: game.hud.abyss_panel.finish_reading();game.hud.abyss_panel.close_panel()
func upgrade() -> void:
	await act_point("up");game.hud.close_active_panel();AbyssState.leave()
	await Flow.at(self,game,"village",Vector2(528,480));check(AbyssState.upgrade(),"实际升级护具至"+str(int(AbyssState.state.gear)+1))
func enter_cp(depth: int) -> void:
	await Flow.at(self,game,"mine_c",Vector2(240,688));check(AbyssState.enter(depth),"实体升降机恢复检查点："+str(depth));await frames(5)
func hundred() -> void:
	await Flow.at(self,game,"mine_c",Vector2(240,688));check(AbyssState.unlock() and AbyssState.enter(1),"正常主线条件进入百层深渊")
	await frames(5)
	for depth in range(1,101):
		if GameState.location!="abyss" or AbyssState.state.depth!=depth: check(false,"楼层连续性失败："+str(depth));return
		check(game.mine_maps.abyss.actors.get_child_count()<=16,"单层实体及时清理："+str(depth))
		if AbyssState.state.air<65:
			if AbyssState.state.rations<3: check(AbyssState.ration(),"有限随行补给")
			else:
				await act_point("up");game.hud.close_active_panel();AbyssState.leave();await enter_cp(AbyssState.state.checkpoint)
				for _step in range(10):
					if AbyssState.state.depth>=depth: break
					await act_point("down");await frames(4)
		await read_note()
		var d: Dictionary=AbyssState.layout()
		for round_id in range(int(d.rounds)):
			if depth>20:
				if d.rule=="prism":
					for turn in range(0 if round_id==0 else 2): await act_point("utility_0")
					await act_point("utility_1")
				else:
					await act_point("utility_0");await act_point("utility_1")
			for symbol in d.solution: await act_point("lever_"+str(int(symbol)))
		check(depth in AbyssState.state.gates,"实际完成区域机关："+str(depth))
		if depth in [61,62,63,64,81,82,83]:
			GameState.rest()
			for hit in range(3): await act_point("ore_0")
		if depth==100:
			await act_point("core");game.hud.close_active_panel();check(River.core("records") and not River.core("records"),"手工终局星核室必须实际进入并唯一结算")
		var start: int=Time.get_ticks_usec()
		await act_point("down");await frames(4)
		timings.append(float(game.mine_maps.abyss.last_rebuild_us))
		if depth in [10,15,40,60,80,99]:
			check(AbyssState.state.depth==depth,"护具深度门槛："+str(depth))
			await upgrade()
			if depth==80:
				await Flow.at(self,game,"farm",Vector2(1360,816));check(LegendTrials.begin("cave"),"开始新80–100层终局试炼")
			await enter_cp(AbyssState.state.checkpoint)
			for _step in range(10):
				if AbyssState.state.depth>depth: break
				await act_point("down");await frames(4)
		elif depth%10==0 and depth<100:
			await act_point("up");game.hud.close_active_panel();AbyssState.leave();await enter_cp(depth);await act_point("down");await frames(4)
		if failed: return
	for id in ["ancient_shard","star_fragment"]:
		var before: int=Inventory.count(id)
		DiamondPayments.selected=true
		DiamondPayments.perform(func(): DiamondPayments.buy_good(id,1))
		DiamondPayments.selected=false
		check(Inventory.count(id)==before+1,"百层进度后新材料可正常钻石购买："+id)
	check(AbyssState.state.max_clear==100 and AbyssState.state.bosses==[20,40,60,80,100],"五大机关和百层终局真实可通关")
	await act_point("up");game.hud.close_active_panel();AbyssState.leave()
	await Flow.at(self,game,"farm",Vector2(1360,816));check(LegendTrials.finish(),"80–100层实际路线完成传说试炼")
func at_depth(depth: int) -> void:
	var cp: int=1
	for candidate in AbyssState.checkpoints():
		if candidate<=depth and candidate>cp: cp=candidate
	await enter_cp(cp)
	for _step in range(10):
		if AbyssState.state.depth>=depth: break
		await act_point("down");await frames(4)
func leave_mine() -> void:
	await act_point("up");game.hud.close_active_panel();check(AbyssState.leave(),"沿实体升降绳返回地面")
func prefix_chapter() -> Dictionary:
	var c := ChapterTwo.defaults();c.policy="rotation"
	for q in ChapterTwo.definitions.slice(0,8):
		c.completed.append(q.id)
		for fact in q.conditions:
			if fact not in c.facts: c.facts.append(fact)
	return c
func chapter_tail() -> void:
	var x := Xiaojing.snapshot();var star := StarStory.snapshot();var legend := LegendState.snapshot()
	Xiaojing.restore(Xiaojing.defaults());StarStory.restore(StarStory.defaults());LegendState.restore(LegendState.defaults())
	ChapterTwo.restore(prefix_chapter());River.state.facts=["star_core"];River.state.crop_count=0;River.state.sown={};River.state.crafted={};River.state.jobs=[]
	await at_depth(20);await read_note();await leave_mine()
	check("backwater" in ChapterTwo.completed and not Xiaojing.state.unlocked,"第二章后半调查不要求解锁小京")
	await Hidden.person(self,game,"linya");check(River.talk("linya"),"林芽独立提出农产品车位需要")
	await Flow.at(self,game,"farm",Vector2(700,500));Hidden.grow(game,6,"carrot")
	check("priority" in ChapterTwo.completed,"新田产出与农业利益真正推进主线")
	await at_depth(40);await read_note();await act_point("down");await frames(4);await leave_mine()
	check("prism" in ChapterTwo.completed,"40层水闸档案与实际出口推进第三项")
	await Hidden.person(self,game,"zhou");check(River.talk("zhou") and "testimony" in ChapterTwo.completed,"周砚给检修设边界，不由小京代替")
	await Flow.at(self,game,"village",Vector2(528,480))
	check(MineState.enqueue("iron_bar",2),"主线实际加工两铁锭")
	advance_day();check(MineState.claim_job(int(MineState.state.queue.back().id)),"主线跨日领取器件")
	check(River.prototype() and not River.prototype(),"实际装分流器一次结算，不重复扣料")
	await at_depth(60);await read_note();await leave_mine()
	await Hidden.person(self,game,"ahe");check(River.talk("ahe") and "public_ledger" in ChapterTwo.completed,"阿禾保留不同意的一页，接合60层记录")
	await Flow.at(self,game,"village",Vector2(752,720))
	for branch in ["trade","explore","life"]:
		Letters.direction=branch;check(not ChapterTwo.branch_line().is_empty(),"第二章结尾继承首章方向："+branch)
	Letters.direction="trade"
	check(River.choose_policy("rotation") and not River.choose_policy("commons"),"主线讨论选择保存且不反复改写结算")
	check(River.end_chapter() and not River.end_chapter() and ChapterTwo.current().is_empty() and ChapterTwo.completed.size()==16,"第二章16项完整结尾并留下第三章信使伏笔")
	check(River.weekly() and not River.weekly(),"结尾政策带来周期协作，非一次文字选择")
	Xiaojing.restore(x);StarStory.restore(star);LegendState.restore(legend)
func wedding_room() -> void:
	await Flow.at(self,game,"farm",Vector2(1360,816))
	for pair in [["bridge",10],["pond",12],["post",20]]: LegendState.infer(pair[0],pair[1])
	LegendState.choose("water_first")
	check(LegendTrials.begin("management"),"0.6生产试炼保留独立实际规则")
	Hidden.grow(game,24,"carrot");Hidden.grow(game,24,"wheat");Hidden.grow(game,72,"potato")
	for pair in [["carrot",24],["wheat",24],["potato",72]]: FarmEconomy.sell(pair[0],pair[1])
	check(LegendTrials.finish(),"0.6经营试炼实际种植销售完成")
	check(LegendTrials.begin("planning"),"0.6有限制作链试炼开始")
	await Flow.at(self,game,"village",Vector2(528,480));MineState.enqueue("copper_bar",2);MineState.enqueue("iron_bar",3)
	advance_day()
	for job in MineState.state.queue.duplicate(true): MineState.claim_job(int(job.id))
	MineState.enqueue("star_alloy");advance_day();MineState.claim_job(int(MineState.state.queue.back().id))
	await Flow.at(self,game,"farm",Vector2(1360,816));check(LegendTrials.fabricate() and LegendTrials.finish(),"0.6制作链实际完成")
	check(LegendTrials.begin("mechanism"),"新的20/60/100三段回路开始")
	for depth in [20,60,100]:
		await at_depth(depth);await act_point("conduit");check(LegendTrials.conduit(),"实际高层回路校准："+str(depth));game.hud.close_active_panel();await leave_mine()
	await Flow.at(self,game,"farm",Vector2(1360,816));check(LegendTrials.finish(),"三处高层实体回路全部完成")
	check(LegendTrials.begin("joint"),"高层联合考察开始")
	for crop in Catalog.crops: Hidden.grow(game,12,crop)
	await at_depth(100);await read_note();await leave_mine()
	await Hidden.near(self,game);StarStory.book_appointment();advance_day();await Hidden.near(self,game,1100);check(StarStory.attend_appointment(),"联合考察要求真实守约")
	for id in ["linya","zhou","ahe"]:
		await Hidden.person(self,game,id);check(LegendTrials.cooperate(id),"新联合考察实际村民分工："+id)
	await Flow.at(self,game,"farm",Vector2(1360,816));check(LegendTrials.finish() and LegendState.state.trials.size()==5,"0.6五场终局试炼完整可玩")
	for stage in range(4): check(LegendState.repair(),"五阶段温室修复阶段："+str(stage+1))
	await Hidden.near(self,game);Xiaojing.state.diamonds=1313;check(not StarStory.propose("share_home"),"0.6全进度仍不能以1313钻石求婚")
	Xiaojing.state.diamonds=1314;check(StarStory.propose("share_home"),"完整百层与关系条件满足可求婚")
	for id in ["linya","zhou","ahe"]: await Hidden.person(self,game,id);StarStory.invite(id)
	await Flow.at(self,game,"farm",Vector2(1360,816));check(StarStory.start_ceremony() and GameState.location=="greenhouse","新婚礼自动进入独立可走礼堂")
	await frames(5)
	game.auto_move.request(Vector2(520,506));await Flow.settle(self,game)
	check(game.hud.river_panel.visible,"点击礼堂研究桌自动靠近打开新交互")
	game.hud.close_active_panel();check(StarStory.place_wedding_table(),"礼堂内实际布置左桌")
	game.auto_move.request(Vector2(760,506));await Flow.settle(self,game);game.hud.close_active_panel()
	check(not Xiaojing.confirm_wedding(false) and Xiaojing.state.diamonds==1314,"独立场景取消婚礼不扣钻")
	check(Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0 and not Xiaojing.confirm_wedding(true),"独立场景最终确认恰好扣1314一次")
	game.player.position=Vector2(640,390);check(StarCeremony.vows(),"独立原创婚礼对白第一段")
	var mid := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,mid) and GameState.location=="greenhouse" and Xiaojing.state.diamonds==0,"婚礼中断恢复独立场景与已扣资源")
	await frames(5);game.player.position=Vector2(640,390)
	check(StarCeremony.vows() and StarCeremony.vows() and not StarCeremony.vows(),"双人动作与三段誓言唯一推进")
	check(StarStory.finish_ceremony() and StarStory.state.wedding_phase==4,"完整婚礼对白后才能收尾")
func postlife() -> void:
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(River.begin_post("seed_collab"),"新增独立婚后留种合作任务")
	Hidden.grow(game,1,"wheat");Hidden.grow(game,1,"potato")
	check(River.finish_post() and not River.finish_post(),"两种实际新收作物完成婚后合作，奖励唯一")
	check(River.begin_post("outing"),"新增婚后共同外出项目")
	await at_depth(40);await read_note();await leave_mine()
	await Hidden.near(self,game);StarStory.book_appointment();advance_day();await Hidden.near(self,game,1100)
	check(StarStory.attend_appointment(),"共同外出后次日晚间交换见闻")
	await Flow.at(self,game,"farm",Vector2(1360,816));check(River.finish_post(),"实际外出与守约完成第二个独立婚后项目")
	GameClock.day=ceili(float(GameClock.day)/28)*28
	await Hidden.near(self,game,1100);check(River.festival() and not River.festival(),"季末节日独立互动且不重复推进")
	GameClock.day=int(Xiaojing.state.wedding_day)+519
	await Flow.at(self,game,"farm",Vector2(1360,816));check(not StarStory.post_ready("day520"),"0.6婚后经过519日不开放回信")
	GameClock.day+=1;check(Xiaojing.post_event("day520") and not Xiaojing.post_event("day520"),"婚后经过520日回信唯一结算")
func compatibility() -> void:
	var current := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(current),"完整0.6百层、章节、婚礼、婚后状态可保存")
	var old: Dictionary=current.duplicate(true)
	old.version=9;old.erase("river");old.location="farm";old.player=[1360,816]
	old.chapter_two=prefix_chapter()
	old.items.erase("ancient_shard");old.items.erase("star_fragment")
	var a: Dictionary=old.abyss
	a.depth=20;a.max_clear=20;a.checkpoint=20;a.gear=3;a.gates=[];a.notes=[];a.chests=[];a.ores={};a.seen=[];a.hazards=[];a.steps={}
	for d in range(1,21): a.gates.append(d);a.notes.append(d)
	for key in ["extra","shortcuts","bosses","warnings","diamond_counter"]: a.erase(key)
	var migrated := FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.abyss.max_clear==20 and migrated.river.old_checkpoints==[5,15],"v9前20层与旧5/15检查点迁移不丢失")
	check(not migrated.is_empty() and migrated.xiaojing.married and migrated.xiaojing.diamonds==old.xiaojing.diamonds and migrated.items==JSON.parse_string(JSON.stringify(old.items)),"v9旧资源、婚姻与钻石完整保留，不重复发奖")
	check(FarmSaveSchema.normalize(migrated)==migrated,"v9→v10反复迁移幂等")
	var bad_old: Dictionary=old.duplicate(true);bad_old.abyss.max_clear="broken"
	check(FarmSaveSchema.normalize(bad_old).is_empty(),"损坏v9旧字段安全拒绝，不在迁移中抛错")
	var invalid := current.duplicate(true);invalid.abyss.extra["100"]={"angle":99,"round":0,"confirmed":false,"utility":[]}
	check(not FarmSaveStore.restore(game,invalid),"损坏百层机关状态整档拒绝")
	for mode in ["tap","joystick"]:
		GameState.set_control_mode(mode,false);var s := FarmSaveStore.snapshot(game);check(FarmSaveStore.restore(game,s) and GameState.control_mode==mode,"0.6新内容仍保存操作模式："+mode)
	await frames(5)
	check(not GameClock.next_day(),"0.6内容结束后白天仍禁止通过旧接口睡觉")

func daily_and_hazards() -> void:
	GameState.set_control_mode("tap",false)
	var before := FarmSaveStore.snapshot(game)
	await at_depth(50)
	var cell: Array=AbyssState.layout().hazards[0]
	game.player.position=AbyssState.point(cell)
	var id := "%d:%d,%d" % [AbyssState.state.depth,cell[0],cell[1]]
	AbyssState.state.warnings.erase(id);AbyssState.state.hazards.erase(id)
	var air: int=AbyssState.state.air
	AbyssRules.hazard_at(Vector2i(cell[0],cell[1]));check(AbyssState.state.air==air,"毒雾先明确预警，不突然扣资源")
	GameClock.minutes+=2
	AbyssRules.hazard_at(Vector2i(cell[0],cell[1]));check(AbyssState.state.air==air-6,"忽略毒雾预警才消耗空气")
	await act_point("up");game.hud.close_active_panel();check(AbyssRules.secure() and not AbyssRules.secure(),"实体入口修滤网护栏，只收一次材料")
	await leave_mine()
	GameClock.day=5000
	await Hidden.near(self,game)
	Xiaojing.state.talk_day=5000;Xiaojing.state.gift_day=5000;Xiaojing.state.order_day=5000
	AbyssState.state.ores["81:1"]=0;AbyssState.state.ore_days["81:1"]=5001
	game.farm.plots={"17,16":{"crop":"carrot","days":0,"watered":true}}
	check(not GameClock.next_day() and game.farm.plots["17,16"].days==0 and AbyssState.state.ores["81:1"]==0,"白天拒睡不触发生长和新深渊矿脉刷新")
	check(not Xiaojing.talk() and not Xiaojing.gift("carrot"),"拒睡不会重置小京每日交谈与赠礼限制")
	advance_day()
	check(game.farm.plots["17,16"].days==1 and AbyssState.state.ores["81:1"]==3,"合法跨天一次结算作物与新矿脉再生")
	await Hidden.near(self,game)
	check(Xiaojing.talk() and Xiaojing.gift("carrot"),"合法次日正常恢复每日互动资格")
	MineState.state.commission_mines=["c_star_0","c_star_1","c_diamond_0"]
	check(not Xiaojing.hard_order(),"只过一天不能刷三日委托")
	advance_day();advance_day();await Hidden.near(self,game)
	check(Xiaojing.hard_order() and not Xiaojing.hard_order(),"合法三日后委托仍只发一次奖励")
	check(FarmSaveStore.restore(game,before),"每日与危险回归后完整状态可恢复")
