extends "res://tests/runner.gd"
const Flow = preload("res://tests/mining.gd")
const Hidden = preload("res://tests/xiaojing.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	GameWeather.enabled=false
	await frames(5)
	load("res://tests/star_runner.gd").fixture(game,false)
	# 本套验证三作物生产/结算；先设置第三年春，冬季约束由seasons_a真实跨日验证。
	GameClock.day=225
	Calendar.restore(Calendar.snapshot())
	LegendState.restore(LegendState.defaults())
	Xiaojing.state.greenhouse=false
	var chapter := ChapterTwo.defaults()
	chapter.policy="rotation"
	for q in ChapterTwo.definitions.slice(0,8):
		chapter.completed.append(q.id)
		for fact in q.conditions:
			if fact not in chapter.facts: chapter.facts.append(fact)
	ChapterTwo.restore(chapter)
	Inventory.coins=20000
	Inventory.items={"wood":900,"stone":900,"wheat":500,"potato":200,"carrot":100,"iron_bar":80,"copper_bar":50,"star_alloy":80,"crystal":200,"starlight_ore":100,"copper_ore":100,"iron_ore":100}
	FarmProgress.built.assign(["toolrack","bedding"])
	GameState.rest()
	await floors()
	if failed:
		print("LEGEND RESULT: %d checks, %d failures" % [checked,failed])
		get_tree().quit(1)
		return
	await deduction()
	await contracts()
	await wedding()
	await supply_cycle()
	await saves()
	await gift_rules()
	print("LEGEND RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit(1 if failed else 0)
func at(id: String) -> void:
	game.hud.close_active_panel()
	var object: Node2D=game.mine_maps.abyss.objects[id]
	game.auto_move.request(object.global_position+Vector2(0,-14))
	await Flow.settle(self,game,1200)
func read() -> void:
	await at("note")
	check(game.hud.abyss_panel.visible and game.hud.abyss_panel.reading,"实地调查原件：第%d层" % AbyssState.state.depth)
	if game.hud.abyss_panel.visible:
		game.hud.abyss_panel.finish_reading()
		game.hud.abyss_panel.close_panel()
func floors() -> void:
	await Flow.at(self,game,"mine_c",Vector2(240,688))
	check(AbyssState.unlock() and not AbyssState.unlock(),"第二章讨论与星纹镐后，实体升降机一次解锁")
	check(AbyssState.enter(1) and GameState.location=="abyss","进入真实深渊第一层并复用玩家")
	check("空气" in game.hud.clock_label.text,"深渊空气余量在HUD持续可见")
	await frames(5)
	load("res://tests/touch_navigation.gd").tap(self,game,Vector2(176,720))
	await Flow.settle(self,game)
	check(game.player.position.distance_to(Vector2(176,720))<2,"新深渊原生触点经相机转换可真实移动")
	GameState.set_control_mode("joystick",false)
	var origin: Vector2=game.player.position
	game.player.touch_direction=Vector2.UP
	await frames(8)
	game.player.touch_direction=Vector2.ZERO
	check(game.player.position.y<origin.y-5,"新深渊备用摇杆沿原碰撞控制器移动")
	GameState.set_control_mode("tap",false)
	var layouts := {}
	for depth in range(1,21):
		if int(AbyssState.state.air)<45:
			check(AbyssState.ration(),"在楼层入口使用有限随行补给")
		var d: Dictionary=AbyssState.layout()
		layouts[JSON.stringify(d.floors)]=true
		check(game.mine_maps.abyss.actors.get_child_count()<=12,"切层及时清理旧实体："+str(depth))
		check(AbyssState.state.depth==depth and game.player.get_parent()==game.mine_maps.abyss.actors,"真实层数/角色与场景对应："+str(depth))
		game.auto_move.navigation.rebuild()
		var wall := Vector2i(22,d.gate[1]+5) if depth<=10 else Vector2i(8,14)
		check(not game.auto_move.navigation.walkable(wall),"机关未开时真实闸壁阻挡："+str(depth))
		await read()
		if depth==1:
			await at("lever_1")
			check(int(AbyssState.state.steps.get("1",0))==0,"错误手柄安全复位，可重新尝试")
		for symbol in d.solution: await at("lever_"+str(int(symbol)))
		check(depth in AbyssState.state.gates,"走到每只实体手柄，完成第%d层机关" % depth)
		await frames(4)
		game.auto_move.navigation.rebuild()
		check(not game.auto_move.navigation.path_to({"kind":"object","object":game.mine_maps.abyss.objects.down,"point":game.mine_maps.abyss.objects.down.global_position}).is_empty(),"开闸后导航可到下层："+str(depth))
		if depth==1:
			for hit in range(3): await at("ore_0")
			var count: int=Inventory.count("iron_ore")
			check(not AbyssState.mine(0) and Inventory.count("iron_ore")==count,"真实深层矿脉耗尽后不能重复掉落")
		await at("chest")
		var diamonds: int=Xiaojing.state.diamonds
		check(not AbyssState.chest() and Xiaojing.state.diamonds==diamonds,"本层宝箱一次性领取："+str(depth))
		if depth==5:
			await at("up")
			check(AbyssState.camp(),"第5层实体营地付补给整备")
			game.hud.abyss_panel.close_panel()
		print("FLOOR AIR ",depth," ",AbyssState.state.air)
		await at("down")
		if failed: return
		if depth in [10,15]:
			check(AbyssState.state.depth==depth and AbyssState.state.max_clear==depth,"深度护具门槛保留已完成检查点："+str(depth))
			await at("up")
			game.hud.abyss_panel.close_panel()
			check(AbyssState.leave(),"沿实体安全绳回地面")
			await Flow.at(self,game,"village",Vector2(528,480))
			check(AbyssState.upgrade(),"周砚工台用实际矿料升级护具")
			await Flow.at(self,game,"farm",Vector2(1360,816))
			if depth==10: check(LegendTrials.begin("cave"),"接取深层路线合约")
			await Flow.at(self,game,"mine_c",Vector2(240,688))
			check(AbyssState.enter(depth),"检查点恢复，不重复刷箱")
			await frames(5)
			await at("down")
		if depth<20: await frames(5)
	check(layouts.size()==20,"二十层使用不同的实体路线布局")
	check(AbyssState.state.max_clear==20 and AbyssState.state.checkpoint==20,"前20层实际通关，记录最终检查点")
	check(AbyssState.state.depth==21 and AbyssState.state.max_clear==20,"完成20层后实际进入0.6新增21层")
	await at("up")
	game.hud.abyss_panel.close_panel()
	check(AbyssState.leave(),"第20层仍能沿安全绳返回")
	await Flow.at(self,game,"farm",Vector2(1360,816))
	Xiaojing.state.trials.erase("cave") # 验证直接挑战强化版能认可原同类型目标。
	check(LegendTrials.finish() and not LegendTrials.finish() and "cave" in Xiaojing.state.trials,"实际10–20层路线结算唯一，同时认可原矿道约定")
func deduction() -> void:
	check(not LegendState.marriage_gate(),"三属性100与1314钻石不能跳过传说目标")
	check(not LegendState.infer("window",20) and LegendState.state.review,"错误推理需实地复核，不能连续乱点领奖")
	check(not LegendState.infer("bridge",10),"未复核前拒绝继续猜测")
	await Flow.at(self,game,"mine_c",Vector2(240,688))
	AbyssState.enter(20)
	await frames(5)
	await read()
	await at("up")
	game.hud.abyss_panel.close_panel()
	AbyssState.leave()
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(LegendState.infer("bridge",10),"桥水线与第10层水位账对照")
	var mid := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,mid) and LegendState.state.deduction==1,"最终推理与真实矿层进度可中断存档恢复")
	await frames(5)
	check(LegendState.infer("pond",12) and LegendState.infer("post",20) and not LegendState.infer("post",20),"七记忆与三个独立原件推导停用原因，结算唯一")
	check(LegendState.choose("water_first") and not LegendState.choose("open_records"),"温室最终意见两种可行，选择与后续反馈只提交一次")
	check(LegendState.repair() and LegendState.state.greenhouse==1,"清理遗址阶段消耗木石，保留气窗剧情条件")
	check(LegendState.repair() and LegendState.state.greenhouse==2,"第二阶段结构按原材料价格修复")
	check(LegendState.repair() and LegendState.state.greenhouse==3,"实地查清温室支线后恢复水源")
	check(not LegendState.repair(),"能源核心要求制作链试炼，不能连续交材料跳过")
func depth_at(depth: int) -> void:
	await Flow.at(self,game,"mine_c",Vector2(240,688))
	var camp: int=1
	for candidate in [5,10,15,20]:
		if candidate<=depth: camp=candidate
	check(AbyssState.enter(camp),"从合法检查点进入目标路线："+str(depth))
	await frames(5)
	for _step in range(20):
		if int(AbyssState.state.depth)>=depth: break
		var before: int=AbyssState.state.depth
		await at("down")
		await frames(5)
		if AbyssState.state.depth==before:
			check(false,"检查点路线不能卡在未推进的楼层")
			break
func surface() -> void:
	await at("up")
	game.hud.abyss_panel.close_panel()
	AbyssState.leave()
func contracts() -> void:
	check(LegendTrials.begin("management"),"高难经营合约可接取")
	Inventory.items.carrot_seed=99
	Inventory.items.wheat_seed=99
	Inventory.items.potato_seed=99
	Hidden.grow(game,24,"carrot")
	Hidden.grow(game,24,"wheat")
	Hidden.grow(game,72,"potato")
	var old: int=LegendState.state.contract.sales
	FarmEconomy.sell("wood",1)
	check(LegendState.state.contract.sales==old,"经营合约不计算售卖旧材料")
	for pair in [["carrot",24],["wheat",24],["potato",72]]: FarmEconomy.sell(pair[0],pair[1])
	check(LegendTrials.finish() and not LegendTrials.finish(),"三作120株经营规划有可行利润解，唯一结算")
	check(LegendTrials.begin("planning"),"有限物资制作链合约可开始")
	await Flow.at(self,game,"village",Vector2(528,480))
	check(MineState.enqueue("copper_bar",2) and MineState.enqueue("iron_bar",3),"本轮真正加工铜2铁3，为合金留出一铁")
	advance_day()
	var jobs: Array=MineState.state.queue.duplicate(true)
	for job in jobs: check(MineState.claim_job(int(job.id)),"领取实际新加工金属")
	check(MineState.enqueue("star_alloy",1),"本轮继续完成合金制作链")
	advance_day()
	check(MineState.claim_job(int(MineState.state.queue.back().id)),"跨天领取新合金")
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(LegendTrials.fabricate() and not LegendTrials.fabricate(),"温室现场装分流器，材料只扣一次")
	check(LegendTrials.finish(),"有限木石制作链真实完成可结算")
	check(LegendState.repair() and LegendState.state.greenhouse==4 and Xiaojing.state.greenhouse,"第四阶段安装晶石核心，尚未扣婚礼钻石")
	check(LegendTrials.begin("mechanism"),"多阶段实体回路试炼开始")
	for depth in [5,12,20]:
		await depth_at(depth)
		await at("conduit")
		check(LegendTrials.conduit(),"按原件先后校准真实层回路："+str(depth))
		check(not LegendTrials.conduit(),"同层回路不能重复冒充下一阶段")
		game.hud.abyss_panel.close_panel()
		await surface()
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(LegendTrials.finish(),"风水灯三段实际机关校准完成")
	check(LegendTrials.begin("joint"),"传说联合考察开始")
	for crop in Catalog.crops: Hidden.grow(game,12,crop)
	await depth_at(20)
	await read()
	await surface()
	await Hidden.near(self,game)
	check(StarStory.book_appointment(),"联合考察保留真实守约条件")
	advance_day()
	await Hidden.near(self,game,1100)
	check(StarStory.attend_appointment(),"次日晚间真实赴约才算守约")
	for id in ["linya","zhou","ahe"]:
		await Hidden.person(self,game,id)
		check(LegendTrials.cooperate(id) and not LegendTrials.cooperate(id),"传说现场村民协作唯一："+id)
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(LegendTrials.finish() and LegendState.state.trials.size()==5,"五种强化试炼均完成，不由纯对白代替")
func wedding() -> void:
	load("res://tests/marriage_requirement_fixture.gd").satisfy(game)
	await Hidden.near(self,game)
	Xiaojing.state.diamonds=1313
	check(not StarStory.propose("share_home"),"传说全目标仍不能用1313钻石求婚")
	Xiaojing.state.diamonds=1314
	check(StarStory.propose("share_home") and Xiaojing.state.diamonds==1314,"传说求婚仅记录选择，不预扣钻石")
	for id in ["linya","zhou","ahe"]:
		await Hidden.person(self,game,id)
		check(StarStory.invite(id),"传说婚礼亲访邀请："+id)
	await Flow.at(self,game,"farm",Vector2(1360,816))
	check(StarStory.start_ceremony(),"传说婚礼现场开始")
	game.player.position=Vector2(1280,884)
	check(StarStory.place_wedding_table(),"亲手布置温室左桌")
	game.player.position=Vector2(1376,884)
	check(not Xiaojing.confirm_wedding(false) and Xiaojing.state.diamonds==1314 and LegendState.state.greenhouse==4,"取消最终星灯仪式不扣钻、不推进第五阶段")
	check(Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0 and LegendState.state.greenhouse==5,"最终确认一次消耗1314，完成第五阶段及婚姻")
	check(not Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0,"传说婚礼不能重复扣钻")
func saves() -> void:
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved),"真实20层、全强化试炼和传说婚姻可保存")
	check(FarmSaveStore.restore(game,saved) and LegendState.state.greenhouse==5 and AbyssState.state.max_clear==20,"传说终局完整恢复")
	await frames(5)
	var old: Dictionary=saved.duplicate(true)
	old.version=8;old.erase("appearance")
	old.erase("legend")
	old.erase("abyss")
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.xiaojing==old.xiaojing and migrated.star_story==old.star_story and migrated.control_mode==old.control_mode,"v8迁移保留旧婚姻与关系/钻石，不凭空发矿洞奖励")
	check(FarmSaveSchema.normalize(migrated)==migrated,"v8到v9迁移幂等")
	var unconfirmed: Dictionary=old.duplicate(true)
	unconfirmed.xiaojing.married=false
	unconfirmed.xiaojing.proposed=false
	unconfirmed.xiaojing.wedding_day=0
	unconfirmed.xiaojing.diamonds=1314
	unconfirmed.star_story.wedding_phase=0
	unconfirmed.star_story.invited=[]
	for id in ["proposal","wedding","act_star1314"]: unconfirmed.star_story.events.erase(id)
	var pending := FarmSaveSchema.normalize(unconfirmed)
	check(not pending.is_empty() and not pending.legend.legacy_vow and pending.legend.greenhouse==2 and pending.xiaojing.diamonds==1314,"旧未求婚档保留结构与钻石，同时接入新目标")
	unconfirmed.star_story.events.append("proposal")
	var promised := FarmSaveSchema.normalize(unconfirmed)
	check(not promised.is_empty() and promised.legend.legacy_vow and promised.xiaojing.diamonds==1314,"旧已求婚承诺保留条件，迁移不扣钻")
	var board: Dictionary=saved.duplicate(true)
	board.version=6;board.erase("appearance")
	board.location="farm"
	board.xiaojing.cave={"x":3,"y":1,"air":50,"hard":false,"visited":[10,11,12],"mined":[12]}
	var board_json: Dictionary=JSON.parse_string(JSON.stringify(board))
	var continued := FarmSaveSchema.normalize(board_json)
	check(not continued.is_empty() and continued.xiaojing.cave.mined==[12] and continued.xiaojing.diamonds==board.xiaojing.diamonds,"旧JSON在途路线格编号规范化，迁移不重复发钻")
	check(FarmSaveStore.restore(game,board_json),"旧JSON路线可实际恢复")
	await Hidden.near(self,game)
	check(not Xiaojing.cave_mine() and Xiaojing.state.cave.air==50,"旧路线读档后同矿不能因数字类型变化再采一次")
	board_json.xiaojing.cave.mined=[12.0,12]
	check(FarmSaveSchema.normalize(board_json).is_empty(),"混合数字类型的重复旧矿格整档拒绝")
	FarmSaveStore.restore(game,saved)
	await frames(5)
	for mutation in [{"depth":101},{"air":-1},{"gear":4},{"chests":[1,1]}]:
		var invalid: Dictionary=saved.duplicate(true)
		invalid.abyss.merge(mutation,true)
		check(not FarmSaveStore.restore(game,invalid),"坏深渊状态整档拒绝："+str(mutation.keys()))
	await depth_at(20)
	var checkpoint: int=AbyssState.state.checkpoint
	AbyssState.state.air=0
	AbyssState._process(.2)
	check(GameState.location=="mine_c" and AbyssState.state.checkpoint==checkpoint,"空气耗尽有救援，检查点与旧奖励不丢失")
	var diamonds: int=Xiaojing.state.diamonds
	await depth_at(20)
	await at("chest")
	check(Xiaojing.state.diamonds==diamonds,"救援与检查点重进不重复领取箱中钻石")
	GameState.set_control_mode("joystick",false)
	check(game.auto_move.target.is_empty(),"深渊切摇杆取消自动移动与交互")
	GameState.set_control_mode("tap",false)

func gift_rules() -> void:
	var saved := FarmSaveStore.snapshot(game)
	var x := Xiaojing.defaults()
	x.plants=520
	x.plant_serial=520
	x.unlocked=true
	x.affection=40
	x.trust=40
	x.bond=40
	Xiaojing.restore(x)
	StarStory.restore(StarStory.defaults())
	LegendState.restore(LegendState.defaults())
	await Hidden.near(self,game)
	Inventory.items.carrot=50
	Inventory.items.wheat=50
	check(Xiaojing.gift("carrot") and Xiaojing.state.affection==41 and Xiaojing.state.trust==40 and Xiaojing.state.bond==40,"礼物只推进好感，不同时填满信任羁绊")
	advance_day()
	await Hidden.near(self,game)
	check(Xiaojing.gift("carrot") and Xiaojing.state.affection==41,"连续日送相同样本不再加好感")
	check(Xiaojing.talk() and Xiaojing.state.affection==42 and Xiaojing.state.trust==40 and Xiaojing.state.bond==40,"日常交谈与信任行动分开计量")
	advance_day()
	await Hidden.near(self,game)
	check(Xiaojing.gift("wheat") and Xiaojing.state.affection==44,"不同喜好礼物仍有正常好感收益")
	check(FarmSaveStore.restore(game,saved),"礼物规则验证后恢复传说婚姻夹具")

func supply_cycle() -> void:
	await Flow.at(self,game,"mine_c",Vector2(240,688))
	var wood: int=Inventory.count("wood")
	check(not AbyssState.survey() and Inventory.count("wood")==wood,"未采尽深层矿不提前收取勘探补给")
	await depth_at(16)
	GameState.rest()
	var before: int=Inventory.count("starlight_ore")
	for depth in range(16,21):
		for index in range(2):
			for hit in range(3): await at("ore_"+str(index))
		check(AbyssState.state.ores.get("%d:0" % depth)==0 and AbyssState.state.ores.get("%d:1" % depth)==0,"实际采尽高级层两矿："+str(depth))
		if depth<20:
			await at("down")
			await frames(5)
	check(Inventory.count("starlight_ore")==before+20,"十条深层矿脉实际产出20原矿")
	await surface()
	wood=Inventory.count("wood")
	var boxes: Array=AbyssState.state.chests.duplicate()
	check(AbyssState.survey() and Inventory.count("wood")==wood-6,"采尽后真实补给开启可重复来源")
	var wood_after: int=Inventory.count("wood")
	check(not AbyssState.survey() and Inventory.count("wood")==wood_after and AbyssState.state.chests==boxes,"连续刷新不重复扣补给或重置宝箱")
	# 周期边界夹具：模拟同日又采尽，三日规则仍由状态层校验。
	for depth in range(16,21):
		for index in range(2): AbyssState.state.ores["%d:%d" % [depth,index]]=0
	check(not AbyssState.survey() and Inventory.count("wood")==wood_after,"同日耗尽也不能绕过三日勘探周期")
	for i in range(3): advance_day()
	check(AbyssState.survey() and AbyssState.state.chests==boxes,"合法三日后可补给新脉，永久奖励仍保留")
