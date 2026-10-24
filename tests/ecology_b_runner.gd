extends "res://tests/runner.gd"
## 实际岸边生态管理、经营联动与唯一事件。测试档完全隔离。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
var restored_lake: Dictionary

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await physical_access()
	await restoration()
	await density_and_recovery()
	await growth_modifiers()
	await saved_world()
	await special_events()
	print("ECOLOGY B RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false;GameWeather.enabled=false
	Inventory.coins=100000;Inventory.items={"wood":999,"stone":999,"wheat":999,"copper_bar":99,"iron_bar":99,"crystal":99,"fish_feed":999,"fry_crucian":99}
	Aquaculture.restore(Aquaculture.defaults(GameClock.day))
	LakeEcology.restore(LakeEcology.defaults(GameClock.day));await frames(5)

func at_shore() -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("farm",LakeEcology.SHORE+Vector2(-32,0));await frames(4)

func at_pen(id: String) -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("farm",Aquaculture.SITES[id]+(Vector2(-32,0) if id=="pen_1" else Vector2(0,32) if id=="pen_2" else Vector2(32,0) if id=="pen_3" else Vector2(0,-32)));await frames(4)

func transaction() -> Dictionary:
	return {"ecology":LakeEcology.snapshot(),"fish":Aquaculture.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"diamonds":Xiaojing.state.diamonds}

func next_day() -> bool:
	GameClock.minutes=1200
	var ok: bool=GameClock.request_sleep(GameClock.day);await frames(3);return ok

func physical_access() -> void:
	await reset()
	await Touch.place(self,game,"farm",Vector2(848,688))
	var point: Node2D
	for object in get_tree().get_nodes_in_group("interactables"):
		if "kind" in object and object.kind=="ecology": point=object;break
	check(point!=null,"已有湖泊西南岸存在实体生态水样台")
	game.auto_move.navigation.rebuild()
	if point:
		check(not game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(),"生态台岸边合法站位真实可达")
		Touch.tap(self,game,point.global_position+Vector2(0,-12));await Touch.finish(self,game,500)
		check(game.hud.ecology_panel.visible and LakeEcology.near(),"点击生态台自动靠岸并打开管理")
		game.hud.close_active_panel()
	await Touch.place(self,game,"home",Vector2(640,500))
	game.auto_move.navigation.rebuild()
	var kitchen: Node2D
	var bed: Node2D
	var door: Node2D
	for object in get_tree().get_nodes_in_group("interactables"):
		if not object.is_visible_in_tree(): continue
		if "kitchen_id" in object and object.kitchen_id=="kitchen": kitchen=object
		if "kind" in object and object.kind=="sleep": bed=object
		if "kind" in object and object.kind=="exit": door=object
	check(kitchen!=null and not game.auto_move.navigation.path_to({"kind":"object","object":kitchen,"point":Kitchen.ANCHOR}).is_empty(),"真实小屋厨房台848432可合法靠近")
	check(bed!=null and not game.auto_move.navigation.path_to({"kind":"object","object":bed,"point":bed.global_position}).is_empty(),"加入厨房后原床仍可到达，不堵睡眠入口")
	check(door!=null and not game.auto_move.navigation.path_to({"kind":"object","object":door,"point":door.global_position}).is_empty(),"加入厨房后房门仍可到达")

func restoration() -> void:
	await reset()
	var before := transaction()
	check(not LakeEcology.clean() and not LakeEcology.plant() and not LakeEcology.repair_cycle() and transaction()==before,"远离湖岸不能隔空恢复生态或扣材料")
	await at_shore()
	check(not LakeEcology.complete_restoration(),"尚未调查修复时不能直接领取环保奖励")
	Inventory.items.wheat=0;before=transaction()
	check(not LakeEcology.plant() and transaction()==before,"水草材料不足时体力与物品都不部分扣除")
	Inventory.items.wheat=999
	GameState.stamina=0;before=transaction()
	check(not LakeEcology.clean() and not LakeEcology.plant() and transaction()==before,"无体力时不能执行照料且不扣资源")
	GameState.stamina=100
	for day in range(3):
		await at_shore()
		check(LakeEcology.clean() and LakeEcology.plant(),"真实日期完成清理与一片水草："+str(GameClock.day))
		before=transaction()
		check(not LakeEcology.clean() and not LakeEcology.plant() and transaction()==before,"当天反复点击不重复加生态或耗材："+str(GameClock.day))
		if day<2: check(await next_day(),"通过原睡眠日结算推进下一次水草照料")
	check(LakeEcology.state.plants==3 and LakeEcology.repair_cycle() and LakeEcology.state.cycle,"三日水草调查后实际交付材料修复循环")
	before=transaction()
	check(not LakeEcology.repair_cycle() and transaction()==before,"重复修复循环不再次扣木石铜与金币")
	var coins: int=Inventory.coins
	var fry: int=Inventory.count("fry_grass")
	check(LakeEcology.complete_restoration() and LakeEcology.state.restored and Inventory.coins==coins+80 and Inventory.count("fry_grass")==fry+2,"达到生态90后环保奖励以原背包事务发放一次")
	before=transaction()
	check(not LakeEcology.complete_restoration() and transaction()==before,"环保委托唯一完成，无法重复领金币鱼苗")
	check(WorldChanges.features().lake_restored,"生态恢复进入统一永久世界变化视图")
	restored_lake=LakeEcology.snapshot()

func density_and_recovery() -> void:
	await reset()
	for id in Aquaculture.SITES:
		await at_pen(id)
		var before_health: int=LakeEcology.state.health
		check(Aquaculture.build(id),"实际建造生态审计鱼栏："+id)
		if id=="pen_1": Aquaculture.upgrade(id);Aquaculture.upgrade(id)
		var penalty := 3 if id in ["pen_3","pen_4"] else 0
		check(LakeEcology.state.health==before_health-penalty,"只有额外外围施工产生温和一次影响："+id)
		var before := transaction()
		check(not Aquaculture.build(id) and transaction()==before,"反复点施工不会重复降低生态："+id)
		var amount: int=29 if id=="pen_1" else 11
		Aquaculture.stock(id,"crucian",amount);Aquaculture.feed(id)
		Aquaculture.pen(id).water=90
	LakeEcology.state.health=80
	check(await next_day() and LakeEcology.state.health==74,"四栏长期高密度单日生态缓慢下降6而非瞬间灾变")
	var stable: Dictionary=LakeEcology.snapshot()
	GameClock.day_advanced.emit();LakeEcology.settle_day()
	check(LakeEcology.snapshot()==stable,"同一天重复日信号不会再降一次生态")
	LakeEcology.state.health=0
	for day in range(2):
		for id in Aquaculture.SITES: await at_pen(id);Aquaculture.feed(id)
		check(await next_day(),"低生态仍可继续真实养成和游戏日推进")
	for id in Aquaculture.SITES:
		await at_pen(id)
		check(Aquaculture.pen(id).adults>2 and Aquaculture.harvest(id,int(Aquaculture.pen(id).adults)-2),"即使生态最低仍可养成并收获减密，不丢鱼："+id)
	for day in range(3):
		await at_shore();LakeEcology.clean();LakeEcology.plant()
		if day<2: await next_day()
	check(LakeEcology.repair_cycle(),"最低生态也不锁住水草与循环设施修复")
	for day in range(10):
		if LakeEcology.state.health>=90: break
		await next_day();await at_shore();LakeEcology.clean()
	check(LakeEcology.state.health>=90 and LakeEcology.complete_restoration(),"减少密度并持续清理后低生态可恢复并完成任务")
	check(LakeEcology.state.health>=0 and LakeEcology.state.health<=100,"长期恢复数值保持0到100范围")

func growth_modifiers() -> void:
	await reset();await at_pen("pen_1")
	Aquaculture.build("pen_1");Aquaculture.stock("pen_1","crucian",2);Aquaculture.feed("pen_1")
	LakeEcology.state.health=95
	await next_day()
	check(Aquaculture.pen("pen_1").cohorts[0].age==5,"高生态在真实日结算给予适宜鱼苗四分日成长加成")
	await reset();await at_pen("pen_1")
	Aquaculture.build("pen_1");Aquaculture.stock("pen_1","crucian",2);Aquaculture.feed("pen_1")
	LakeEcology.state.health=20
	await next_day()
	check(Aquaculture.pen("pen_1").cohorts[0].age==2,"低生态实际放慢鱼苗而不清空鱼群")
	check(LakeEcology.fishing_capacity()==8 and LakeEcology.rare_factor()<1,"低生态向垂钓接口提供有限资源量与较低稀有权重")
	LakeEcology.state.health=95
	check(LakeEcology.fishing_capacity()==12 and LakeEcology.rare_factor()>1 and LakeEcology.rare_factor()<=1.5,"高生态恢复正常资源量，稀有权重加成有上限")

func saved_world() -> void:
	await reset();await at_shore()
	GameClock.day=int(restored_lake.last_settled_day);Calendar.restore(Calendar.snapshot())
	LakeEcology.restore(restored_lake)
	var snapshot := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(snapshot),"生态已恢复与统一永久变化可组成完整合法存档")
	var expected: Dictionary=AbyssSaveSchema.canonical(LakeEcology.snapshot())
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snapshot))) and AbyssSaveSchema.canonical(LakeEcology.snapshot())==expected and WorldChanges.features().lake_restored,"完整JSON读档保留水草/循环/恢复奖励与永久外观标志")
	var before := transaction();LakeEcology.settle_day()
	check(transaction()==before,"读取和再次进入地图不会补一次生态日结算")
	var old := snapshot.duplicate(true)
	old.version=14;old.erase("ecology");old.erase("kitchen")
	old.world_changes.observed.erase("lake_restored")
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.ecology.health==70 and not migrated.ecology.restored,"旧v14添加初始生态，不凭空领取恢复奖励")
	if not migrated.is_empty():
		check(migrated.items==old.items and migrated.xiaojing==old.xiaojing and migrated.aquaculture==old.aquaculture and migrated.livestock==old.livestock,"生态迁移保留原经营、小京、养殖和动物分区")
	var bad := snapshot.duplicate(true);bad.ecology.health=101
	check(not FarmSaveStore.valid(bad),"非法生态范围整份拒绝")
	bad=snapshot.duplicate(true);bad.ecology.plant_day=GameClock.day+1
	check(not FarmSaveStore.valid(bad),"未来照料日期不能绕过日限")

func special_events() -> void:
	await reset()
	GameClock.day=5;GameClock.minutes=600;Calendar.restore(Calendar.snapshot())
	Aquaculture.restore(Aquaculture.defaults(GameClock.day));await at_pen("pen_1");Aquaculture.build("pen_1")
	Aquaculture.state.xiaojing={"stage":2,"invited_day":3,"care_days":[3,4,5],"pen":"pen_1","harvested":2}
	var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=60;x.trust=60;x.bond=60
	for i in range(3): x.events.append(Xiaojing.data.events[i].id)
	x.dating=true;Xiaojing.restore(x)
	LakeEcology.restore(restored_lake);await at_shore();GameClock.changed.emit();await frames(6)
	check(LakeEcology.companion_present(),"原小京日程在生态恢复后实际来到水样台，不增第二个NPC")
	var diamonds: int=Xiaojing.state.diamonds
	check(LakeEcology.xiaojing_after() and Xiaojing.state.trust==61 and Xiaojing.state.bond==61,"现场生态后续仅增加信任与羁绊各1")
	var before := transaction()
	check(not LakeEcology.xiaojing_after() and transaction()==before and Xiaojing.state.trust==61 and Xiaojing.state.bond==61,"生态后续永久唯一，不能刷关系")
	check(not Xiaojing.marriage_ready() and Xiaojing.state.diamonds==diamonds,"生态后续不代替原求婚条件或生产钻石")
	var meteor := 0
	for day in range(29,225):
		if Calendar.predicted_weather(day)=="meteor": meteor=day;break
	GameWeather.enabled=true;GameClock.day=meteor;GameClock.minutes=1199;Calendar.restore(Calendar.snapshot())
	check(not LakeEcology.observe_meteor(),"流星日未到20点不能提前领取现场观测")
	GameClock.minutes=1200
	check(LakeEcology.observe_meteor() and LakeEcology.state.meteor_seen,"20点后岸边可真实记录流星夜线索")
	before=transaction()
	check(not LakeEcology.observe_meteor() and transaction()==before,"星痕观测不会反复发放线索或资源")
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and LakeEcology.state.meteor_seen and LakeEcology.state.xiaojing_seen,"星痕与小京生态唯一事件完成标志保存恢复")
