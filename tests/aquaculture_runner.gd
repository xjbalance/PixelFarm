extends "res://tests/runner.gd"
## 生产入口、真实跨天、物理寻路及隔离存档联合回归。
const Touch = preload("res://tests/touch_navigation.gd")
var original: Dictionary

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	GameClock.running=false
	game.get_node("Audio").muted=true
	await frames(6)
	original=FarmSaveStore.snapshot(game)
	await construction()
	await construction_spawn_clearance()
	await stocking_and_growth()
	await reproduction_and_care()
	await economy_and_story()
	await fish_processing_variants()
	await persistence_and_time()
	await navigation_and_ui()
	print("AQUACULTURE RESULT: %d checks, %d failures" % [checked,failed])
	game.persistence_enabled=false
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(4)
	get_tree().quit(1 if failed else 0)

func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false
	GameWeather.enabled=false
	GameState.set_control_mode("tap",false)
	Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"wheat":999,"crystal":999,"iron_bar":999,"copper_bar":999,"star_alloy":999}
	for species in Aquaculture.data.species: Inventory.items["fry_"+species]=100
	Inventory.items.fish_feed=999
	Aquaculture.restore(Aquaculture.defaults(GameClock.day))
	await frames(5)

func object(id: String) -> Node2D:
	for point in get_tree().get_nodes_in_group("interactables"):
		if "pen_id" in point and point.pen_id==id: return point
	return null

func near(id: String = "pen_1") -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("farm",object(id).global_position-object(id).water_direction*32)
	await frames(4)

func transaction() -> Dictionary:
	return {"fish":Aquaculture.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}

func next() -> void:
	GameClock.minutes=1200
	if not GameClock.request_sleep(GameClock.day): check(false,"养殖日期通过合法20点睡眠进入次日")
	await frames(3)

func construction() -> void:
	await reset()
	check(not Aquaculture.pen("pen_1").built and not Aquaculture.pen("pen_2").built,"新档开放两个待建栏位，不凭空赠送设施")
	check(Aquaculture.available("pen_1") and Aquaculture.available("pen_2") and not Aquaculture.available("pen_3"),"扩展栏位保留建设解锁条件")
	var before := transaction()
	check(not Aquaculture.build("pen_1") and transaction()==before,"远离湖岸不能远程建造")
	await near()
	Inventory.coins=0
	before=transaction()
	check(not Aquaculture.build("pen_1") and transaction()==before,"金币不足时整笔建造不部分扣费")
	Inventory.coins=100000;Inventory.items.wood=0
	before=transaction()
	check(not Aquaculture.build("pen_1") and transaction()==before,"木材不足不扣石料或金币")
	Inventory.items.wood=999
	var coins: int=Inventory.coins
	check(Aquaculture.build("pen_1") and Aquaculture.pen("pen_1").built and Aquaculture.pen("pen_1").level==1 and Inventory.coins<coins,"合法湖岸建造一级栏并消耗真实资源")
	before=transaction()
	check(not Aquaculture.build("pen_1") and transaction()==before,"重复建造请求不再次扣资源")
	check(not Aquaculture.build("invented_pen"),"不存在的设施ID被拒绝")
	check(Aquaculture.stock("pen_1","crucian",4),"建成后可实际投放四尾鱼苗")
	var population := Aquaculture.summary("pen_1").duplicate(true)
	check(Aquaculture.upgrade("pen_1") and Aquaculture.pen("pen_1").level==2,"可以用材料升级加固鱼栏")
	check(Aquaculture.summary("pen_1").total==population.total and Aquaculture.pen("pen_1").species=="crucian","升级保留种类、成年与幼鱼存量")
	check(Aquaculture.upgrade("pen_1") and Aquaculture.pen("pen_1").level==3 and Aquaculture.summary("pen_1").capacity>Aquaculture.summary("pen_2").capacity,"生态鱼栏提升容量并保留原鱼群")
	before=transaction()
	check(not Aquaculture.upgrade("pen_1") and transaction()==before,"满级再升级不重复扣费")
	check(Aquaculture.available("pen_3"),"升级经营后开放扩展栏位")

func stocking_and_growth() -> void:
	await reset();await near();Aquaculture.build("pen_1")
	var before := transaction()
	check(not Aquaculture.stock("pen_1","crucian",13) and transaction()==before,"超容量投放整笔拒绝")
	check(not Aquaculture.stock("pen_1","crucian",0) and not Aquaculture.stock("pen_1","crucian",-1),"零/负数鱼苗数量被拒绝")
	check(not Aquaculture.stock("pen_1","unknown",1),"未知鱼种不能投放")
	Inventory.items.fry_crucian=0
	before=transaction()
	check(not Aquaculture.stock("pen_1","crucian",1) and transaction()==before,"无鱼苗不能凭空生成鱼群")
	Inventory.items.fry_crucian=100
	check(Aquaculture.stock("pen_1","crucian",4) and Inventory.count("fry_crucian")==96 and Aquaculture.summary("pen_1").fry==4,"成功投放扣除同量鱼苗并生成幼鱼")
	before=transaction()
	check(not Aquaculture.stock("pen_1","carp",1) and transaction()==before,"初期鱼栏不混养不同鱼种")
	var feed_before: int=Inventory.count("fish_feed")
	check(Aquaculture.feed("pen_1") and Inventory.count("fish_feed")<feed_before,"投喂只消耗实际所需饲料")
	check(Aquaculture.pen("pen_1").adults==0,"投喂按钮不会当场跳过生长日")
	before=transaction()
	check(not Aquaculture.feed("pen_1") and transaction()==before,"同日重复投喂不扣饲料、不加成长")
	await next()
	check(Aquaculture.pen("pen_1").adults==0 and Aquaculture.pen("pen_1").cohorts[0].age==4,"喂养后首个日结算只成长一天")
	check(Aquaculture.stock("pen_1","crucian",2),"可以给同种鱼栏追加新鱼苗")
	Aquaculture.feed("pen_1")
	await next()
	check(Aquaculture.pen("pen_1").adults==4 and Aquaculture.summary("pen_1").fry==2,"两日鲫鱼成熟，新投放批次不继承老鱼年龄")
	var adults: int=Aquaculture.pen("pen_1").adults
	Inventory.items.fish_crucian=999
	before=transaction()
	check(not Aquaculture.harvest("pen_1",2) and transaction()==before,"满包收获失败时栏中成熟鱼完整保留")
	Inventory.items.erase("fish_crucian")
	check(Aquaculture.harvest("pen_1",2) and Aquaculture.pen("pen_1").adults==adults-2 and Inventory.count("fish_crucian")==2,"部分收获真实入包并保留两尾种鱼")
	check(not Aquaculture.harvest("pen_1",3),"收获数量不能超出剩余成鱼")
	check(Aquaculture.harvest("pen_1",2) and not Aquaculture.harvest("pen_1",1),"收完成年鱼后重复领取被拒绝，幼鱼不受损")
	check(Aquaculture.summary("pen_1").fry==2,"收获不减少未成熟批次")
	await next()
	check(Aquaculture.pen("pen_1").cohorts[0].age==5,"未喂食按较慢速度成长，不清空鱼群")

func construction_spawn_clearance() -> void:
	await reset()
	for id in ["pen_1","pen_2","pen_3","pen_4"]:
		var point := object(id)
		var tangent := Vector2(-point.water_direction.y,point.water_direction.x)
		await Touch.place(self,game,"farm",point.global_position+tangent*40)
		check(Aquaculture.build(id),"在合法交互圈切线位置确认建造："+id)
		await frames(4)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=game.player.get_node("CollisionShape2D").shape
		query.transform=game.player.global_transform
		query.collision_mask=1
		check(game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"新工具箱不在玩家脚底生成实体碰撞："+id)
		var before: Vector2=game.player.global_position
		game.auto_move.request(point.global_position-point.water_direction*64)
		await Touch.finish(self,game,360)
		check(game.auto_move.state==game.auto_move.State.IDLE and game.player.global_position.distance_to(before)>24,"建成后可以正常走离鱼栏，不被新障碍包围："+id)
		if id=="pen_1":
			await near(id)
			Aquaculture.upgrade(id);Aquaculture.upgrade(id)

func reproduction_and_care() -> void:
	await reset();await near();Aquaculture.build("pen_1");Aquaculture.stock("pen_1","crucian",2)
	for i in range(2): Aquaculture.feed("pen_1");await next()
	check(Aquaculture.pen("pen_1").adults==2,"繁殖种鱼来自实际成长")
	var born := false
	for i in range(12):
		Aquaculture.feed("pen_1");Aquaculture.maintain("pen_1");await next()
		if Aquaculture.summary("pen_1").total>2: born=true;break
	check(born and Aquaculture.summary("pen_1").fry>0,"满足种鱼/水质/食物后每日推进繁殖并产生幼鱼")
	if born: check(Aquaculture.pen("pen_1").cohorts[-1].age==0,"新生鱼不会继承成年鱼成长进度")
	var before := transaction()
	Aquaculture.settle_day();Aquaculture.settle_day()
	check(transaction()==before,"重复发每日事件不能重复繁殖或成长")
	for i in range(55):
		Aquaculture.feed("pen_1");Aquaculture.maintain("pen_1");await next()
	check(Aquaculture.summary("pen_1").total<=Aquaculture.summary("pen_1").capacity,"长期繁殖受鱼栏容量约束")
	var water: int=Aquaculture.pen("pen_1").water
	for i in range(3): await next()
	check(Aquaculture.pen("pen_1").water<=water and Aquaculture.pen("pen_1").water>=water-30,"养殖污染缓慢可预期，不随机瞬间崩溃")
	var total: int=Aquaculture.summary("pen_1").total
	for i in range(12): await next()
	check(Aquaculture.summary("pen_1").total==total and Aquaculture.pen("pen_1").health>=0,"忘记喂食影响健康与效率，不永久删除鱼群")
	water=Aquaculture.pen("pen_1").water
	check(Aquaculture.maintain("pen_1") and Aquaculture.pen("pen_1").water>water,"维护可恢复恶化水质")
	before=transaction()
	check(not Aquaculture.maintain("pen_1") and transaction()==before,"当天反复维护不重复扣料或加水质")
	check(not Aquaculture.species_unlocked("star"),"新手栏不能绕过星辉鱼剧情与设施前置")

func economy_and_story() -> void:
	await reset();await near()
	var before := transaction()
	check(not Aquaculture.buy("fry_star",1) and transaction()==before,"稀有鱼购买不能绕过解锁条件")
	Inventory.items.fry_crucian=0
	var money: int=Inventory.coins
	check(Aquaculture.buy("fry_crucian",3) and Inventory.count("fry_crucian")==3 and Inventory.coins<money,"普通鱼苗可在正常湖岸商店用金币获取")
	before=transaction()
	check(not Aquaculture.buy("fish_crucian",1) and transaction()==before,"商店不出售成鱼代替实际养殖")
	Inventory.items.fish_crucian=3
	money=Inventory.coins
	var commits := [0]
	var on_commit := func(): commits[0]+=1
	Events.progress_committed.connect(on_commit)
	check(FarmEconomy.sell("fish_crucian",2) and Inventory.coins==money+Catalog.sell_price("fish_crucian")*2,"成鱼接入现有统一出售经济")
	check(commits[0]==1,"成功出售鱼类发出持久化提交信号")
	check(not FarmEconomy.sell("fish_crucian",99) and commits[0]==1,"失败出售不产生伪提交或重复保存")
	Events.progress_committed.disconnect(on_commit)
	check(not Aquaculture.claim_quest("intro"),"未经营时不可直接领取初识养殖奖励")
	check(not Aquaculture.invite_xiaojing(),"小京未解锁或关系不足时不开放湖畔合作")
	await economy_expansion()
	await companion_event()

func persistence_and_time() -> void:
	await reset();await near();Aquaculture.build("pen_1");Aquaculture.stock("pen_1","crucian",4);Aquaculture.feed("pen_1")
	var snap := FarmSaveStore.snapshot(game)
	check(snap.version==FarmSaveStore.VERSION and FarmSaveStore.valid(snap),"新养殖栏随完整v11档案通过校验")
	var json: Dictionary=JSON.parse_string(JSON.stringify(snap))
	check(FarmSaveStore.restore(game,json) and Aquaculture.snapshot()==snap.aquaculture,"JSON浮点整数规范后整份恢复批次与每日状态")
	await frames(4)
	var before := transaction()
	Aquaculture.settle_day()
	check(transaction()==before,"存档恢复不会额外结算养殖一天")
	var old := snap.duplicate(true)
	old.version=10;old.erase("aquaculture")
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.coins==old.coins and migrated.items==old.items and migrated.xiaojing==old.xiaojing and migrated.plots==old.plots and migrated.abyss==old.abyss,"v10迁移保留资源/农田/小京/深渊全部旧进度")
	if not migrated.is_empty():
		check(not migrated.aquaculture.pens.pen_1.built and migrated.aquaculture.last_settled_day==int(old.day),"旧档不捏造鱼群或历史成长日")
		check(FarmSaveSchema.normalize(migrated)==migrated,"v11迁移重复执行幂等")
	var bad := snap.duplicate(true)
	bad.aquaculture.pens.pen_1.adults=999
	before=transaction()
	check(not FarmSaveStore.restore(game,bad) and transaction()==before,"超容量存档整份拒绝，不污染运行状态")
	bad=snap.duplicate(true);bad.aquaculture.pens.pen_1.last_feed_day=GameClock.day+1
	check(not FarmSaveStore.valid(bad),"拒绝未来投喂日期")
	bad=snap.duplicate(true);bad.aquaculture.pens.pen_1.cohorts[0].count=1.5
	check(not FarmSaveStore.valid(bad),"拒绝小数鱼苗数量而不静默截断")
	for time in [360,720,1199]:
		GameClock.minutes=time;before=transaction()
		check(not GameClock.request_sleep(GameClock.day) and transaction()==before,"白天不能睡觉刷鱼类成长："+str(time))
	GameClock.minutes=1200
	var today: int=GameClock.day
	check(GameClock.request_sleep(today) and not GameClock.request_sleep(today),"同日连续床请求最多提交一次")
	var settled := Aquaculture.snapshot()
	check(Aquaculture.pen("pen_1").cohorts[0].age==4,"一次合法跨天只增加一个有饲料成长日")
	GameClock.day_advanced.emit()
	check(Aquaculture.snapshot()==settled,"同一日期重复日结算信号不改变鱼栏")
	game._notification(NOTIFICATION_APPLICATION_PAUSED);GameClock._process(600)
	game._notification(NOTIFICATION_APPLICATION_RESUMED);GameClock.running=false
	check(Aquaculture.snapshot()==settled and GameClock.day==today+1,"后台恢复不补算现实时间或重复产鱼")
	for area in ["home","village","farm"]: game.change_location(area);await frames(3)
	check(Aquaculture.snapshot()==settled,"反复切图不改变成长/喂养/繁殖状态")
	await near();Aquaculture.feed("pen_1")
	GameClock.minutes=1440;GameClock._process(0);GameClock._process(0)
	check(GameClock.day==today+2 and Aquaculture.pen("pen_1").adults==4,"午夜强制结算唯一，鱼类按第二个成长日成熟")

func navigation_and_ui() -> void:
	await reset()
	await Touch.place(self,game,"farm",Vector2(880,560))
	for id in ["pen_1","pen_2","pen_3","pen_4"]:
		var node := object(id)
		check(node!=null,"已有湖泊四处岸边设施实体存在："+id)
		if node==null: continue
		game.auto_move.navigation.rebuild()
		var route: PackedVector2Array = game.auto_move.navigation.path_to({"kind":"object","object":node,"point":node.global_position})
		check(not route.is_empty(),"鱼栏合法交互站位可达："+id)
		if route.is_empty(): continue
		check(game.auto_move.navigation.walkable(game.auto_move.navigation.cell(route[-1])),"鱼栏交互终点在可通行湖岸："+id)
	game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.walkable(Vector2i(34,18)),"原有湖心仍是水域碰撞而非可走地面")
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,object("pen_1").global_position+Vector2(0,-12))
	await Touch.finish(self,game,600)
	check(game.auto_move.execution_count==count+1 and GameState.modal,"点击鱼栏自动靠近后只执行一次打开界面")
	check(Aquaculture.near_pen("pen_1"),"自动移动最终位置满足生产层岸边合法检查")
	var position: Vector2=game.player.global_position
	Touch.tap(self,game,Vector2(880,656));await frames(5)
	check(game.auto_move.target.is_empty() and game.player.global_position==position,"鱼栏模态窗口阻止地图触点穿透")
	game.hud.close_active_panel()
	Aquaculture.build("pen_1");await frames(4);game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.path_to({"kind":"object","object":object("pen_1"),"point":object("pen_1").global_position}).is_empty(),"建造后碰撞更新且鱼栏仍可合法靠近")
	game.auto_move.request(Vector2(1104,592));await Touch.finish(self,game)
	check(game.auto_move.state==game.auto_move.State.FAILED and game.player.global_position==position,"点击湖心有限失败，不自动走进水域")
	game.auto_move.request(object("pen_2").global_position);await frames(4)
	GameState.set_control_mode("joystick",false)
	check(game.auto_move.target.is_empty() and game.player.auto_direction==Vector2.ZERO,"切换备用摇杆立即取消待执行鱼栏交互")
	await near("pen_1");game.action_cooldown=0;GameState.select_tool(0);game.interact()
	check(GameState.modal,"备用摇杆/桌面E仍能打开相同鱼栏交互")
	game.hud.close_active_panel();GameState.set_control_mode("tap",false)
	await Touch.place(self,game,"farm",Vector2(880,560))
	var a: Vector2=game.player.get_canvas_transform()*object("pen_1").global_position
	Touch.finger(self,a,true,31);Touch.finger(self,a+Vector2(40,0),true,32)
	Touch.finger(self,a,false,31);Touch.finger(self,a+Vector2(40,0),false,32);await frames(4)
	check(not GameState.modal and game.auto_move.target.is_empty(),"湖岸多指触点不误执行养殖")
	game.auto_move.request(object("pen_2").global_position);await frames(4);game.change_location("home")
	check(game.auto_move.target.is_empty(),"切图清除旧鱼栏寻路与待交互")

func grow(species: String, quantity: int) -> bool:
	if not Aquaculture.stock("pen_1",species,quantity): return false
	for i in range(40):
		if Aquaculture.pen("pen_1").adults>=quantity: return true
		Aquaculture.feed("pen_1")
		Aquaculture.maintain("pen_1")
		await next()
	return false

func economy_expansion() -> void:
	Inventory.items.fish_feed=100
	Aquaculture.build("pen_1");Aquaculture.upgrade("pen_1");Aquaculture.upgrade("pen_1")
	var food_before: int=Inventory.count("fish_feed")
	check(Aquaculture.process("feed",2) and Inventory.count("fish_feed")==food_before+12,"小麦加工为实际饲料，配方产出进入原背包")
	Inventory.items.fish_feed=999
	var before := transaction()
	check(not Aquaculture.process("feed",1) and transaction()==before,"加工产物满包时不先扣小麦")
	Inventory.items.fish_feed=100
	for species in ["crucian","carp","grass","perch"]:
		Inventory.items["fry_"+species]=20
		check(await grow(species,4),"普通品种真实养成："+species)
		check(Aquaculture.harvest("pen_1",4),"普通品种真实收获："+species)
	check(Aquaculture.state.collection.size()==4,"四种普通鱼分别进入收藏记录")
	check(Aquaculture.claim_quest("intro"),"首次养殖委托按实际收获结算")
	before=transaction()
	check(not Aquaculture.claim_quest("intro") and transaction()==before,"初识湖畔一次性奖励不重复发放")
	check(Aquaculture.claim_quest("fresh") and Aquaculture.state.order_count==1,"亲自收获的新鲤鱼交付鲜鱼订单")
	before=transaction()
	check(not Aquaculture.claim_quest("fresh") and transaction()==before,"同一鲜鱼订单不能重复提交")
	for i in range(3): await next()
	Inventory.items.fish_carp=10
	check(not Aquaculture.claim_quest("fresh"),"仅等待三日或塞入库存不会伪造本轮新收获")
	check(await grow("carp",4) and Aquaculture.harvest("pen_1",4) and Aquaculture.claim_quest("fresh") and Aquaculture.state.order_count==2,"再次实际养成后可循环完成订单")
	check(Aquaculture.process("dried",1) and Inventory.count("dried_fish")==1,"成鱼加工风干湖鲜有材料链和设施要求")
	Inventory.items.carrot=2
	check(Aquaculture.process("soup",1) and Inventory.count("fish_soup")==1,"草鱼与农作物可以实际烹制料理")
	GameState.stamina=20
	check(Aquaculture.consume_food("fish_soup") and GameState.stamina==50,"鱼汤正确消耗并恢复30体力")
	before=transaction()
	check(Aquaculture.consume_food("dried_fish") and Inventory.count("dried_fish")==0 and GameState.stamina==68,"体力未满时鱼汤后仍可吃一份鱼干，正确扣物恢复18")
	check(not Aquaculture.species_unlocked("golden"),"收齐普通鱼仍需真实地下水脉探索前置")
	# 本套独立验证养殖接口，矿区完整主线与进入流程由原mining套件实走。
	MineState.state.unlocked=["mine_a","mine_b"]
	check(Aquaculture.species_unlocked("golden") and Aquaculture.collect_rare("golden"),"普通收藏与水脉进度开放金鳞鱼保护站来源")
	check(Aquaculture.collect_rare("golden"),"稀有苗有可重复的有成本来源，不会一次性耗尽")
	check(await grow("golden",2) and Aquaculture.harvest("pen_1",2),"金鳞鱼按独立成长/水质条件实际养成收获")
	check(Aquaculture.claim_quest("research"),"真实金鳞鱼研究交付解锁后续")
	before=transaction()
	check(not Aquaculture.claim_quest("research") and transaction()==before,"研究奖励只结算一次")
	check(not Aquaculture.species_unlocked("star"),"研究完成仍不能绕过晶石洞窟前置")
	MineState.state.unlocked.append("mine_c")
	check(Aquaculture.species_unlocked("star") and Aquaculture.collect_rare("star"),"生态栏与洞窟进度开放星辉鱼培育配方")
	check(await grow("star",1) and Aquaculture.harvest("pen_1",1),"星辉鱼真实成长后进入玩家背包")
	check(Aquaculture.state.collection.size()==6 and Inventory.count("fish_star")==1,"六种鱼均有真实养成与收获流程")
	# 同日先喂少量再补鱼苗必须补足新增群体的饲料。
	Inventory.items.fish_feed=100
	Inventory.items.fry_crucian=20
	check(Aquaculture.stock("pen_1","crucian",1) and Aquaculture.feed("pen_1"),"补差回归先合法投放一尾并喂养")
	food_before=Inventory.count("fish_feed")
	check(Aquaculture.stock("pen_1","crucian",16) and Inventory.count("fish_feed")==food_before-2,"投喂后扩大鱼群同步补差，不能用一份饲料喂满32尾")
	# 存入的自动饲料只扣储备，不暗扣背包。
	Aquaculture.feed_reserve("pen_1",10)
	await next()
	food_before=Inventory.count("fish_feed")
	var reserve: int=Aquaculture.pen("pen_1").feed_stock
	await next()
	check(Aquaculture.pen("pen_1").feed_stock==reserve-3 and Inventory.count("fish_feed")==food_before,"生态自动投喂只使用玩家明确储备的三份饲料")

func companion_event() -> void:
	await reset();await near("pen_2")
	Aquaculture.build("pen_2");Aquaculture.upgrade("pen_2");Aquaculture.upgrade("pen_2");Aquaculture.stock("pen_2","crucian",4)
	var x := Xiaojing.defaults()
	x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=50;x.trust=40;x.bond=97
	Xiaojing.restore(x)
	GameClock.minutes=600;GameClock.changed.emit();await frames(4)
	check(Aquaculture.invite_xiaojing("pen_2"),"关系门槛与现场鱼群满足后可以邀请小京")
	await frames(5)
	check(Aquaculture.xiaojing_present("pen_2"),"邀请后真实小京日程来到岸边，未造第二个剧情人物")
	var before := transaction()
	check(not Aquaculture.complete_xiaojing() and transaction()==before,"仅邀请不能跳过实际合作任务")
	Aquaculture.pen("pen_2").water=100;Aquaculture.pen("pen_2").health=100
	var stamina: int=GameState.stamina
	check(Aquaculture.feed("pen_2") and Aquaculture.maintain("pen_2") and Aquaculture.state.xiaojing.care_days.size()==1 and GameState.stamina==stamina,"满水质生态栏也可实做水样检查，合作无维护死锁")
	check(not Aquaculture.maintain("pen_2") and GameState.stamina==stamina,"同日重复水样检查不消耗体力或重复记录")
	check(not Aquaculture.observe_xiaojing() and Aquaculture.state.xiaojing.care_days.size()==1,"重复观察同日水样不刷共同任务进度")
	var midway := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,midway) and Aquaculture.state.xiaojing.stage==1 and Aquaculture.state.xiaojing.care_days.size()==1,"合作中断后恢复邀请、在场日程与已记录水样")
	await frames(5)
	for i in range(2):
		await next()
		GameClock.minutes=600;GameClock.changed.emit();await frames(5)
		Aquaculture.feed("pen_2");Aquaculture.maintain("pen_2");Aquaculture.observe_xiaojing()
	check(Aquaculture.state.xiaojing.care_days.size()==3,"三个不同游戏日的实际共同养护累计完成")
	check(Aquaculture.harvest("pen_2",2),"共同养护后实际收两尾用于观察")
	GameClock.minutes=1200;GameClock.changed.emit();await frames(4)
	check(not Aquaculture.complete_xiaojing(),"小京已离开湖岸时不能远程结算共同观察")
	GameClock.minutes=600;GameClock.changed.emit();await frames(5)
	check(Aquaculture.complete_xiaojing() and Xiaojing.state.bond==100 and Aquaculture.state.xiaojing.stage==2,"现场完成湖畔事件一次羁绊+3，受100上限限制")
	before=transaction()
	check(not Aquaculture.complete_xiaojing() and not Aquaculture.invite_xiaojing("pen_2") and transaction()==before and Xiaojing.state.bond==100,"湖畔结局和奖励永久唯一，不能反复邀请刷羁绊")

func fish_processing_variants() -> void:
	await reset();await near()
	Aquaculture.build("pen_1");Aquaculture.upgrade("pen_1");Aquaculture.upgrade("pen_1")
	for item in ["fish_crucian","fish_carp","fish_grass","fish_perch","fish_golden","fish_star","carrot"]: Inventory.items[item]=20
	for recipe_id in ["dried","soup","crucian_dried","perch_soup","golden_soup","star_soup"]:
		var definition: Dictionary=Aquaculture.data.recipes.get(recipe_id,{})
		if definition.is_empty(): check(false,"每种鱼均有真实加工配方："+recipe_id);continue
		var before: Dictionary=Inventory.items.duplicate(true)
		var valid: bool=Aquaculture.process(recipe_id,1)
		for item in definition.required: valid=valid and Inventory.count(item)==int(before.get(item,0))-int(definition.required[item])
		for item in definition.rewards: valid=valid and Inventory.count(item)==int(before.get(item,0))+int(definition.rewards[item])
		check(valid,"鱼类配方完整扣料和产出："+recipe_id)
	var snap := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(snap) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snap))) and Aquaculture.state.processed.size()==6,"六种鱼加工记录可随v11跨JSON保存恢复")
