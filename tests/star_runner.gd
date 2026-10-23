extends "res://tests/runner.gd"
const Flow = preload("res://tests/mining.gd")
const Hidden = preload("res://tests/xiaojing.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	await frames(5)
	await narratives()
	await trials()
	await married_life()
	await payments()
	await saves()
	print("STAR RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit(1 if failed else 0)

static func fixture(owner_game: Node, married: bool = true) -> void:
	load("res://tests/mining.gd").fresh_chapter(owner_game)
	load("res://tests/xiaojing.gd").advanced_fixture()
	var x := Xiaojing.defaults()
	x.plants=520
	x.plant_serial=520
	x.unlocked=true
	x.affection=100
	x.trust=100
	x.bond=100
	x.dating=true
	x.greenhouse=true
	x.married=married
	x.proposed=married
	x.wedding_day=190 if married else 0
	x.diamonds=1400
	for e in Xiaojing.data.events: x.events.append(e.id)
	for q in Xiaojing.data.quests: x.quests.append(q.id)
	for m in Xiaojing.data.memories: x.memories.append(m.id)
	x.trials=["management","planning","cave","mechanism","joint"]
	Xiaojing.restore(x)
	StarStory.restore(StarStory.migrate(x))
	LegendState.restore(LegendState.migrate(x,StarStory.snapshot()))
	LegendState.state.legacy_vow=true # 本套保留v8原婚约/支付回归；新传说条件在legend_runner真实走完。
	AbyssState.restore(AbyssState.defaults())
	GameClock.minutes=600
	GameClock.changed.emit()
	River.state.legacy_rules=true
	River.state.legacy_scene=true
	River.state.old_checkpoints=[5,15]
	DiamondPayments.selected=false
	Inventory.diamond_payment=false

func point(id: String) -> void:
	var entry: Dictionary=StarStory.data.points[id]
	await Flow.at(self,game,entry.area,Vector2(entry.position[0],entry.position[1])+Vector2(0,36))

func narratives() -> void:
	fixture(game,false)
	Xiaojing.state.quests=[]
	Xiaojing.state.memories=[]
	Xiaojing.state.trials=[]
	Xiaojing.state.events=["meet"]
	Xiaojing.state.dating=false
	Xiaojing.state.greenhouse=false
	StarStory.restore(StarStory.defaults())
	LegendState.restore(LegendState.defaults())
	check(not StarStory.relationship_gate("flower"),"属性满值不能跳过一起种下的花的实际任务")
	check(not StarStory.relationship_gate("secret"),"属性满值仍需历史拼接与桌位选择才能进入恋爱")
	for m in Xiaojing.data.memories:
		await Flow.at(self,game,m.location,Vector2(m.position[0],m.position[1])+Vector2(0,36))
		game.hud.star_panel.open_panel("memory:"+str(m.id))
		game.hud.star_panel.close_panel()
		var count: int=Xiaojing.state.memories.size()
		check(not StarStory.memory_action(m.id,1) and Xiaojing.state.memories.size()==count,"记忆错误观察可重试且不计数："+m.id)
		check(StarStory.memory_action(m.id,0) and StarStory.memory_action(m.id,0) and Xiaojing.state.memories.size()==count+1,"实体观察正确后收藏唯一："+m.id)
	await point("greenhouse")
	check(StarStory.inspect_greenhouse() and StarStory.repair_vent() and not StarStory.repair_vent(),"温室调查与气窗材料事务唯一")
	check(not StarStory.assemble("post") and StarStory.state.assembly==0,"历史证据错序不发奖励并可重摆")
	check(StarStory.assemble("window"),"证据拼接第一步可中断")
	var mid := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,mid) and StarStory.state.assembly==1,"剧情中断读取保留拼接步骤")
	await frames(5)
	check(StarStory.assemble("bridge") and StarStory.assemble("post") and not StarStory.assemble("window"),"育苗水线停用名单还原历史，不能重复提交")
	check(StarStory.choose("closure","seeds") and not StarStory.choose("closure","water"),"关键决定有唯一稳定结果")
	# 使用已解锁茶座和旧任务进度夹具，验证每日互动的状态约束。
	fixture(game,false)
	await Hidden.near(self,game)
	Xiaojing.state.affection=90
	Xiaojing.state.trust=90
	Xiaojing.state.bond=90
	Inventory.items.wheat=20
	Inventory.items.stone=20
	check(Xiaojing.gift("wheat") and Xiaojing.state.affection==92 and not Xiaojing.gift("wheat"),"喜欢礼物使用独立收益且每日不能连送")
	GameClock.day+=1
	check(Xiaojing.gift("stone") and Xiaojing.state.affection==92 and StarStory.state.gift_mood_day==GameClock.day,"不喜欢的礼物没有属性收益并留下当日反馈")
	check(StarStory.book_appointment() and not StarStory.book_appointment(),"约定次日晚间，不能堆叠无限预约")
	var due: int=StarStory.state.appointment.day
	GameClock.day=due
	GameClock.minutes=1199
	StarStory.check_dates()
	check(not StarStory.state.repair_pending,"预约日19:59不算失约")
	GameClock.minutes=1200
	StarStory.check_dates()
	check(StarStory.state.repair_pending and not StarStory.proposal_ready(),"20:00未赴约进入可修复状态，暂停求婚")
	await Hidden.near(self,game)
	var trust: int=Xiaojing.state.trust
	check(StarStory.repair_relationship() and not StarStory.repair_relationship() and Xiaojing.state.trust==trust,"解释修复能恢复推进，不奖励反复失约")
	check(StarStory.book_appointment(),"修复后可以再次约定")
	GameClock.day=int(StarStory.state.appointment.day)
	await Hidden.near(self,game,1100)
	check(StarStory.attend_appointment() and not StarStory.attend_appointment(),"赴约需要当日窗口且只能结算一次")
	var lines := {}
	fixture(game)
	for day in range(201,213):
		GameClock.day=day
		lines[StarStory.daily_text().split("\n")[0]]=true
	check(lines.size()==12,"婚后十二组不同日常对白可轮换")
	GameWeather.enabled=true
	GameClock.day=210
	check("雨" in StarStory.daily_text(),"天气影响实际对白")
	GameWeather.enabled=false

func trials() -> void:
	fixture(game,false)
	Xiaojing.state.trials=[]
	await Hidden.near(self,game)
	check(Xiaojing.start_trial("management") and not StarTrials.complete("management"),"新经营合约不能通过空结算")
	StarStory.state.challenge.plants=61
	StarStory.state.challenge.harvest={"wheat":12,"potato":48}
	StarStory.state.challenge.sold_value=4000
	check(not StarTrials.complete("management"),"超过60种子预算，即便收入充足仍不能通过经营试炼")
	var contract := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(contract),"独立试炼合约可以完整保存")
	Xiaojing.state.trial={}
	StarTrials.cancel()
	check(Xiaojing.start_trial("planning") and not StarTrials.complete("planning"),"制作链试炼必须真正加工铜锭和安装铰链")
	Xiaojing.state.trial={}
	StarTrials.cancel()
	check(Xiaojing.start_trial("cave"),"本轮新矿道试炼合约可开始")
	await Flow.at(self,game,"village",Vector2(1168,240))
	check(MineState.start_expedition(),"实际矿道入口准备考察补给")
	await Flow.at(self,game,"mine_a",WorldTravel.entry("mine_a"))
	await Flow.read(self,game,"a_tutorial")
	GameState.rest()
	for id in ["a_copper_2","a_copper_3","a_copper_4","a_copper_5"]: await Flow.interact(self,game,id)
	await Flow.interact(self,game,"a_down")
	await Flow.read(self,game,"b_hint")
	await Flow.interact(self,game,"b_exit")
	var steps: int=StarStory.state.challenge.steps
	await Flow.interact(self,game,"a_exit")
	check("cave" in Xiaojing.state.trials and StarStory.state.challenge.is_empty(),"新合约实际读手册水位牌、行走采矿并回地面结算")
	print("STAR CAVE OBSERVED SEGMENTS before final return: ",steps)
	await Hidden.near(self,game)
	check(Xiaojing.start_trial("mechanism") and not StarTrials.complete("mechanism"),"星灯试炼不能跳过实体基座线索")
	await Flow.at(self,game,"mine_c",WorldTravel.entry("mine_c"))
	await Flow.read(self,game,"c_star_hint")
	for i in [0,2,4,6,8]: await Flow.interact(self,game,"star_"+str(i))
	check("mechanism" in Xiaojing.state.trials,"读环境线索后走到实体灯台，五步点亮完成深化试炼")

func married_life() -> void:
	fixture(game)
	await point("greenhouse")
	check(not Xiaojing.post_event("separate_desks"),"婚后项目不能只点阅读直接结算")
	check(StarStory.start_post("separate_desks") and not StarStory.start_post("field_trip"),"一次只接一个可玩婚后项目")
	await point("desk_left")
	check(StarStory.work_desk("desk_left") and not Xiaojing.post_event("separate_desks"),"左桌整理后仍需要亲访右桌")
	await point("desk_right")
	check(StarStory.work_desk("desk_right"),"右桌现场整理保留项目进度")
	await point("greenhouse")
	check(Xiaojing.post_event("separate_desks") and not Xiaojing.post_event("separate_desks"),"整理两张桌完成项目且不能重复结算")
	game.farm.plots.clear()
	for i in range(8): game.farm.plots["%d,16" % (17+i)]={"crop":"wheat","days":0,"watered":false}
	await point("greenhouse")
	check(StarStory.cooperate() and not StarStory.cooperate(),"温室协作每日只使用一次")
	var watered := 0
	for plot in game.farm.plots.values():
		if plot.watered: watered+=1
	check(watered==6,"协作只照料六格真实缺水作物")
	check(StarStory.start_post("field_trip"),"第二个婚后事件要求真实采样考察")
	await Flow.at(self,game,"farm",Vector2(930,788))
	check(StarStory.memory_action("pond",0),"池岸重新测水位记录第一份婚后采样")
	await Flow.at(self,game,"mine_b",WorldTravel.entry("mine_b"))
	await Flow.read(self,game,"b_hint")
	await point("greenhouse")
	check(Xiaojing.post_event("field_trip") and not Xiaojing.post_event("field_trip"),"地下水脉实测补齐婚后双水样，重复不结算")
	# 春季活动由实际农田提交点驱动，不接受重复播种。
	GameClock.day=225
	GameClock.minutes=600
	await point("greenhouse")
	check(StarStory.start_season(),"春季活动可接取")
	Inventory.items.wheat_seed=30
	GameState.rest()
	for i in range(3):
		var cell := Vector2i(20+i,18)
		game.farm.plots.erase(game.farm.key(cell))
		game.farm.use_tool(cell,"hoe")
		game.farm.use_tool(cell,"wheat_seed")
	game.farm.use_tool(Vector2i(20,18),"wheat_seed")
	check(StarStory.state.season_run.plant==3 and StarStory.finish_season() and not StarStory.finish_season(),"春活动只数真实播种并且每季唯一领奖")
	GameClock.day=253
	await point("greenhouse")
	check(StarStory.start_season(),"夏季活动重新记录本季目标")
	for i in range(6):
		var cell := Vector2i(17+i,16)
		game.farm.plots[game.farm.key(cell)].watered=false
		game.farm.use_tool(cell,"water")
	check(StarStory.finish_season(),"夏季活动要求六次真实浇水")
	GameClock.day=281
	await point("greenhouse")
	check(StarStory.start_season(),"秋季活动独立开放")
	for i in range(3):
		var cell := Vector2i(17+i,16)
		game.farm.plots[game.farm.key(cell)].days=2
		game.farm.use_tool(cell,"hand")
	check(StarStory.finish_season(),"秋季活动由真实成熟收获提交")
	GameClock.day=309
	await point("greenhouse")
	check(StarStory.start_season(),"冬季活动可开启")
	game.player.position=Vector2(656,440)
	check(not StarStory.winter_lamp(),"冬季活动不能远程点右桌的灯")
	await point("desk_right")
	check(StarStory.winter_lamp(),"冬季活动走到灯罩现场检修")
	await point("greenhouse")
	check(StarStory.finish_season(),"冬季活动完成后唯一结算")
	for days in [519,520,521]:
		GameClock.day=int(Xiaojing.state.wedding_day)+days
		GameClock.running=true
		Xiaojing._process(.6)
		GameClock.running=false
		await point("greenhouse")
		if days==519: check(not StarStory.post_ready("day520") and not Xiaojing.state.ultimate,"婚后经过519天即使总日数很高仍不开回信")
		elif days==520: check(StarStory.post_ready("day520") and Xiaojing.post_event("day520"),"婚后经过520天当日可以读取最终回信")
		else: check(not Xiaojing.post_event("day520"),"第521天不能重复结算最终回信")
	Xiaojing.state.post_events.erase("day520")
	Xiaojing.state.ultimate=false
	GameClock.day=int(Xiaojing.state.wedding_day)+520
	var anniversary := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,anniversary),"第520日未轮询通知的存档可恢复")
	await frames(4)
	check(Xiaojing.post_event("day520") and Xiaojing.state.ultimate,"第520日读档立即阅读按日期结算，不必等待后台通知")
	for hour in [420,600,1000,1100,1300]:
		GameClock.minutes=hour
		GameClock.changed.emit()
		var expected := "farm" if hour in [420,1000] else ("home" if hour==1300 else "village")
		await Flow.at(self,game,expected,WorldTravel.entry(expected))
		var count := 0
		for actor in get_tree().get_nodes_in_group("xiaojing"):
			if actor.is_visible_in_tree(): count+=1
		check(count==1,"婚后日程在合理地图唯一出现："+str(hour))
func confirmation(panel: Control) -> ConfirmationDialog:
	for child in panel.get_children():
		if child is ConfirmationDialog and child.visible: return child
	return null
func payments() -> void:
	fixture(game)
	Inventory.coins=0
	Xiaojing.state.diamonds=1500
	Inventory.items.wheat_seed=0
	game.hud.inventory_panel.open_panel(true)
	DiamondPayments.selected=true
	var panel: Control=game.hud.inventory_panel
	game.hud.inventory_panel.buy("wheat")
	var dialog := confirmation(panel)
	check(dialog!=null and Xiaojing.state.diamonds==1500,"选择钻石支付先弹出确认，尚未扣钻")
	if dialog:
		await dialog_touch(dialog,dialog.get_cancel_button())
	check(Xiaojing.state.diamonds==1500 and Inventory.count("wheat_seed")==0,"取消钻石购买没有物品和货币变化")
	game.hud.inventory_panel.buy("wheat")
	dialog=confirmation(panel)
	if dialog: await dialog_touch(dialog,dialog.get_ok_button())
	await frames(2)
	check(Inventory.count("wheat_seed")==1 and Xiaojing.state.diamonds==1499 and Inventory.coins==0,"无金币也可用已确认钻石购买种子")
	Inventory.items.wheat_seed=999
	game.hud.inventory_panel.buy("wheat")
	dialog=confirmation(panel)
	if dialog: dialog.confirmed.emit()
	await frames(2)
	check(Xiaojing.state.diamonds==1499 and Inventory.count("wheat_seed")==999,"满包钻石购买整笔拒绝不扣钻")
	for id in DiamondPayments.GOODS:
		var before: int=Inventory.count(id)
		var diamond_before: int=Xiaojing.state.diamonds
		var result := {"ok":false}
		DiamondPayments.perform(func(): result.ok=DiamondPayments.buy_good(id,1))
		if not DiamondPayments.good_unlocked(id):
			check(not result.ok and Inventory.count(id)==before and Xiaojing.state.diamonds==diamond_before,"未达到新区域前不可购买材料："+id)
			continue
		check(result.ok and Inventory.count(id)==before+1 and Xiaojing.state.diamonds==diamond_before-int(DiamondPayments.GOODS[id]),"钻石可购买已解锁材料："+id)
	for id in Catalog.crops:
		var before: int=Inventory.count(id)
		var result := {"ok":false}
		DiamondPayments.perform(func(): result.ok=DiamondPayments.buy_crop(id,1))
		check(result.ok and Inventory.count(id)==before+1,"钻石可购买收获物："+id)
	var stored: int=Xiaojing.state.diamonds
	DiamondPayments.perform(func():
		MineState.state.unlocked=[]
		check(not DiamondPayments.buy_good("starlight_ore",1) and not DiamondPayments.buy_good("diamond",1),"钻石购物不能越过高级矿区解锁，也不能直接买钻石")
	)
	check(Xiaojing.state.diamonds==stored,"未解锁购买不会扣钻")
	Hidden.advanced_fixture()
	Inventory.coins=0
	Inventory.items.wood=200
	Inventory.items.stone=200
	FarmProgress.built.clear()
	var upgrade: Dictionary=FarmProgress.upgrades.toolrack
	DiamondPayments.perform(func(): check(FarmProgress.build_upgrade("toolrack"),"原修缮系统可使用钻石替代金币，仍验证材料"))
	check(Inventory.coins==0 and Xiaojing.state.diamonds==stored-DiamondPayments.price(int(upgrade.coins)),"修缮只扣报价钻石，不产生负金币")
	var after: int=Xiaojing.state.diamonds
	DiamondPayments.perform(func(): check(not FarmProgress.build_upgrade("toolrack"),"钻石购买修缮不能重复结算"))
	check(Xiaojing.state.diamonds==after,"重复修缮不扣钻石")
	game.hud.inventory_panel.buy("wheat")
	game.hud.inventory_panel.close_panel()
	check(confirmation(panel)==null and not Inventory.diamond_payment,"关闭商店取消待付款并清理瞬态支付标记")
	fixture(game,false)
	DiamondPayments.selected=true
	Inventory.coins=0
	Inventory.items={"wood":400,"stone":400,"copper_bar":100,"iron_ore":10,"iron_bar":100,"star_alloy":100}
	VillageProjects.built.clear()
	await Flow.at(self,game,"village",Vector2(680,700))
	DiamondPayments.perform(func(): check(VillageProjects.build("well"),"公共水井可用钻石支付金币部分，保留主线和材料条件"))
	MineState.state.furnace=false
	MineState.state.tool=1
	await Flow.at(self,game,"village",Vector2(528,480))
	DiamondPayments.perform(func(): check(MineState.build_furnace(),"熔炼炉建造支持钻石费用"))
	DiamondPayments.perform(func(): check(MineState.upgrade_tool() and MineState.upgrade_tool(),"强化镐与星纹镐两级都支持钻石费用"))
	Xiaojing.state.greenhouse=false
	await Hidden.near(self,game)
	DiamondPayments.perform(func(): check(Xiaojing.repair_greenhouse(),"温室结构修复可支付钻石，婚礼另需1314钻石确认"))
	DiamondPayments.selected=false

func saves() -> void:
	fixture(game)
	StarStory.state.post_run="field_trip"
	StarStory.state.post_steps=["sample_pond"]
	StarStory.state.choices.future="keep_journeys"
	StarStory.state.appointment={"day":GameClock.day+1,"status":"booked"}
	await point("greenhouse")
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved),"剧情选择、预约与婚后在途事件可以共同存档")
	StarStory.restore(StarStory.defaults())
	check(FarmSaveStore.restore(game,saved) and StarStory.state.post_steps==["sample_pond"] and StarStory.state.choices.future=="keep_journeys","读档恢复婚后实际目标和关键选择")
	var old: Dictionary=saved.duplicate(true)
	old.version=7
	old.erase("star_story")
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.xiaojing==old.xiaojing and migrated.items==old.items and migrated.control_mode==old.control_mode,"v7迁移保留婚姻任务记忆试炼钻石和操作方式")
	check(FarmSaveSchema.normalize(migrated)==migrated and old.version==7,"v7迁移幂等，不修改原始存档")
	check(migrated.star_story.wedding_phase==4 and not migrated.star_story.events.is_empty(),"旧婚姻标记已结束仪式，补剧情不扣钻不发奖励")
	for mutation in [{"wedding_phase":2},{"assembly":3},{"choices":{"closure":"bad"}},{"invited":["ahe","ahe"]},{"post_steps":["bad"]},{"challenge":{"id":"cave"}}]:
		var invalid: Dictionary=saved.duplicate(true)
		invalid.star_story.merge(mutation,true)
		check(not FarmSaveStore.restore(game,invalid) and Xiaojing.state.married,"坏剧情字段整档拒绝，当前婚姻不受污染："+str(mutation.keys()))
	var path := "user://star_backup.json"
	check(FarmSaveStore.write(game,path) and FarmSaveStore.write(game,path),"新剧情落盘并保留有效备份")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("broken primary")
	file.close()
	var recovered := FarmSaveStore.read(path)
	check(not recovered.is_empty() and recovered.star_story.post_steps==["sample_pond"],"主档损坏后真实恢复包含新剧情的备份")
	for id in StarStory.data.points:
		var entry: Dictionary=StarStory.data.points[id]
		await Flow.at(self,game,entry.area,WorldTravel.entry(entry.area))
		game.auto_move.navigation.rebuild()
		var object: Node2D
		for node in get_tree().get_nodes_in_group("interactables"):
			if "star_id" in node and node.star_id==id: object=node
		var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":object,"point":object.global_position})
		check(not route.is_empty(),"原碰撞和动态资源下新增实体目标可达："+id)
	# 用原生触点经过相机变换，到达研究桌并打开原模态系统。
	await Flow.at(self,game,"farm",Vector2(1328,912))
	load("res://tests/touch_navigation.gd").tap(self,game,Vector2(1376,834))
	await Flow.settle(self,game)
	check(game.hud.star_panel.visible and game.hud.star_panel.context=="desk_right","Android原生触点点击研究桌，自动寻路并打开深化交互")
	game.hud.star_panel.close_panel()
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution
		game.hud.star_panel.open_panel("overview")
		await frames(4)
		check(game.hud.safe.get_global_rect().encloses(game.hud.star_panel.get_global_rect()),"深化长剧情面板完整位于安全区："+str(resolution))
		game.hud.star_panel.close_panel()
	get_window().size=Vector2i(1280,720)

func dialog_touch(dialog: ConfirmationDialog, button: Button) -> void:
	await frames(3)
	var touch := InputEventScreenTouch.new()
	touch.index=88
	touch.position=button.get_global_rect().get_center()
	touch.pressed=true
	dialog.push_input(touch,true)
	touch=touch.duplicate()
	touch.pressed=false
	dialog.push_input(touch,true)
	await frames(3)
