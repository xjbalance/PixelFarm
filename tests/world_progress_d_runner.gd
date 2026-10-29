extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await building_guards()
	await trade_and_rounds()
	await community_life()
	await save_and_seasons()
	print("WORLD PROGRESS D RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	load("res://tests/star_runner.gd").fixture(game,true)
	GameClock.day=225;GameClock.minutes=600;Calendar.restore(Calendar.snapshot())
	WorldDevelopment.restore(WorldDevelopment.defaults(GameClock.day))
	GameClock.running=false;GameWeather.enabled=false
	Inventory.items={"wood":999,"stone":999,"copper_bar":999,"iron_bar":999,"crystal":999,"wheat":99,"carrot_seed":30,"potato_seed":30,"wheat_seed":30,"fishing_bait":99,"potato_bread":4,"fish_soup":4,"milk":4}
	Inventory.coins=100000;GameState.stamina=GameState.max_stamina();game.farm.plots={}
	Letters.direction="trade"
	await frames(5)
func at(context: String) -> void:
	await Touch.place(self,game,"village",WorldDevelopment.anchor(context)+Vector2(0,16 if context=="board" else 32))
func stamp() -> Dictionary:
	return {"development":WorldDevelopment.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina}
func building_guards() -> void:
	await reset();await at("board")
	var before := stamp();Story.stage=7
	check(not WorldDevelopment.build("dock",0) and Inventory.items==before.items and WorldDevelopment.state.dock==0,"第一章尚未完成不能越过长期建设前置")
	Story.stage=8;Inventory.items.wood=0;before=stamp()
	check(not WorldDevelopment.build("dock",0) and stamp()==before,"建设缺木时不部分扣金币或其他矿物")
	Inventory.items.wood=999
	await Touch.place(self,game,"village",Vector2(640,756));before=stamp()
	check(not WorldDevelopment.build("dock",0) and stamp()==before,"原共建图纸不能远程建造，必须发展牌现场")
	await at("board");Inventory.items.wheat_seed=999
	check(WorldDevelopment.build("dock",0) and WorldDevelopment.state.dock==1,"在岸上真实建成一级码头")
	before=stamp();check(not WorldDevelopment.build("dock",0) and stamp()==before,"旧级别确认不能重复建造扣费")
	check(WorldDevelopment.state.parcels.has("dock") and not WorldDevelopment.claim_parcel("dock"),"首次分支补给满包时保留，不阻止已完成建设")
	Inventory.remove("wheat_seed",3)
	check(WorldDevelopment.claim_parcel("dock") and Inventory.count("wheat_seed")==999,"农业方向首次补给按原种子ID真实发放")
	before=stamp();check(not WorldDevelopment.claim_parcel("dock") and stamp()==before,"首次建设补给只领取一次")
	check(not WorldDevelopment.build("dock",1),"没有实际交易交接不能直接跳到交易棚")
	check(WorldDevelopment.build("community",0) and WorldDevelopment.state.community==1,"农业方向也能发展社区，不永久封锁其他路线")
	check(not WorldDevelopment.build("community",1),"社区第二阶段需要实际巡灯交接")
	var policy: String=River.state.policy
	Letters.direction="explore";check(WorldDevelopment.branch_line().contains("刻度") and River.state.policy==policy,"探索方向改变推荐对白但不重写原矿道政策")
	Letters.direction="life";check(WorldDevelopment.branch_line().contains("凳子") and WorldDevelopment.state.dock==1,"居民方向改变说明但保留已有码头")
	Letters.direction="trade"
	check(WorldDevelopment.validate(WorldDevelopment.snapshot(),GameClock.day),"两条已建工程和补给状态通过严格保存验证")
func plant(cell: Vector2i, crop: String = "carrot") -> bool:
	if not game.farm.use_tool(cell,"hoe"): return false
	await frames(16)
	if not game.farm.use_tool(cell,crop+"_seed"): return false
	await frames(16)
	if not game.farm.plots[game.farm.key(cell)].watered:
		if not game.farm.use_tool(cell,"water"): return false
		await frames(16)
	return true
func sleep_day() -> bool:
	GameClock.minutes=1200
	var ok: bool=GameClock.request_sleep(GameClock.day)
	await frames(5);return ok
func pilot() -> bool:
	for i in range(4000):
		if not Fishing.active(): return Fishing.session.phase in ["landed","caught"]
		Fishing.tick(1.0/120.0,Fishing.session.player>Fishing.session.fish)
	return false
func catch_required(item: String, count: int) -> bool:
	GameState.select_tool(GameState.tools.find("fishing_rod"))
	await Touch.place(self,game,"farm",Vector2(944,464))
	game.player.action_time=0
	for i in range(12):
		if int(WorldDevelopment.state.order.credit.get(item,0))>=count: return true
		if Fishing.remaining_casts("farm_lake")<1: break
		if not Fishing.start("farm_lake") or not pilot(): return false
	return int(WorldDevelopment.state.order.credit.get(item,0))>=count
func trade_and_rounds() -> void:
	await reset();await at("board");WorldDevelopment.build("dock",0)
	await at("dock")
	check(WorldDevelopment.accept_order("fresh_baskets"),"一级真实码头可登记农渔订单")
	Inventory.items.carrot=30;Inventory.items.fish_crucian=20
	var before := stamp()
	check(not WorldDevelopment.use_trade() and stamp()==before,"仅有旧库存不能代替本轮新生产证明")
	await Touch.place(self,game,"farm",Vector2(656,560))
	for x in range(18,24): check(await plant(Vector2i(x,18)),"订单需要真正种植新一轮作物："+str(x))
	for i in range(2):
		for plot in game.farm.plots.values(): plot.watered=true
		check(await sleep_day(),"订单作物通过统一睡眠结算真实成长")
	for x in range(18,21):
		check(game.farm.use_tool(Vector2i(x,18),"hand"),"本轮亲手收获给贸易单的胡萝卜")
		await frames(16)
	check(await catch_required("fish_crucian",2),"本轮使用原QTE钓获两尾鲫鱼，非菜单造鱼")
	await at("dock")
	check(WorldDevelopment.trade_ready(),"作物与鱼的本轮事实同时满足多条件订单")
	before=stamp();check(not WorldDevelopment.use_trade("grain_fish") and stamp()==before,"不能用错误订单ID结算当前交易")
	var coins: int=Inventory.coins
	check(WorldDevelopment.use_trade("fresh_baskets") and WorldDevelopment.state.trade_count==1 and Inventory.coins==coins+164,"真实交付材料后按农业方向小加成结算")
	before=stamp();check(not WorldDevelopment.use_trade("fresh_baskets") and stamp()==before,"完成订单的重复确认不会重复给钱或扣货")
	check(WorldDevelopment.accept_order("fresh_baskets"),"可登记下一轮，但本轮证明重新从空记录")
	check(WorldDevelopment.state.order.credit.is_empty(),"第二轮不会复用第一轮产物凭据")
	await Touch.place(self,game,"farm",Vector2(656,560))
	for x in range(21,24):
		check(game.farm.use_tool(Vector2i(x,18),"hand"),"第二轮真正收获预留成熟作物")
		await frames(16)
	if not await catch_required("fish_crucian",2):
		check(await sleep_day(),"当日钓鱼额度不足时通过原跨日重试")
		check(await catch_required("fish_crucian",2),"下一天继续真实获取剩余鱼，不丢订单记录")
	await at("dock");check(WorldDevelopment.trade_ready(),"第二轮具有新的合法产物证明")
	before=stamp();check(not WorldDevelopment.use_trade() and stamp()==before,"三日交易间隔不能靠重接单或旧证明绕过")
	while GameClock.day-int(WorldDevelopment.state.trade_day)<3: check(await sleep_day(),"真实游戏日推进贸易补货间隔")
	await at("dock")
	check(WorldDevelopment.use_trade() and WorldDevelopment.state.trade_count==2,"间隔满足后第二轮才可正常交货")
	await at("board");before=stamp()
	check(not WorldDevelopment.build("dock",0) and stamp()==before,"完成贸易后旧一级确认仍不能重复扣建设材料")
	check(WorldDevelopment.build("dock",1) and WorldDevelopment.state.dock==2,"实际交接后扩建交易棚并保留原记录")
	check(not WorldDevelopment.order_unlocked("shared_meal"),"交易棚不直接绕过原料理和畜牧解锁")
	check(WorldDevelopment.validate(WorldDevelopment.snapshot(),GameClock.day),"重复贸易、间隔和两级建设日期记录可保存")
	await advanced_trade_pipeline()
func inspect_all() -> void:
	for id in WorldDevelopment.LAMPS:
		await at("lamp:"+id)
		check(WorldDevelopment.inspect_lamp(id),"走到真实归路灯检查一次："+id)
		var before := stamp();check(not WorldDevelopment.inspect_lamp(id) and stamp()==before,"同一盏灯同日重复点击不扣体力："+id)
func community_life() -> void:
	await reset();await at("board");WorldDevelopment.build("community",0)
	await at("lamp:west");var before := stamp()
	check(not WorldDevelopment.inspect_lamp("west") and stamp()==before,"白天不能假装完成傍晚巡灯")
	GameClock.day=230;GameClock.minutes=1080;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(5)
	await inspect_all();await at("community")
	var coins: int=Inventory.coins;var wheat: int=Inventory.count("wheat")
	check(WorldDevelopment.daily_community() and WorldDevelopment.state.community_count==1 and Inventory.coins==coins+28 and Inventory.count("wheat")==wheat-1,"真实巡三灯并交接木材粮食才发放值日补给")
	before=stamp();check(not WorldDevelopment.daily_community() and stamp()==before,"日常值日不因重复点击而重复给钱")
	await at("board")
	check(WorldDevelopment.build("community",1) and WorldDevelopment.state.community==2,"完成一次真实巡灯后可建二级共餐雨棚")
	check(WorldDevelopment.weekly_active(),"每周第六天傍晚活动时段明确开放")
	for id in ["linya","zhou","ahe"]:
		check(WorldDevelopment.community_station(id)!=Vector2.INF,"二级社区给原NPC提供真实聚集站点："+id)
		var query := PhysicsShapeQueryParameters2D.new()
		var foot := RectangleShape2D.new();foot.size=Vector2(31,31)
		query.shape=foot;query.collision_mask=1;query.transform=Transform2D(0,WorldDevelopment.community_station(id))
		check(game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"社区站位31像素足底不碰活动桌或其他静态障碍："+id)
	GameClock.running=true;game.village.refresh_gathering()
	for i in range(2400):
		await frames(1)
		var complete := true
		for id in ["linya","zhou","ahe"]:
			if game.village.villagers[id].global_position.distance_to(WorldDevelopment.community_station(id))>6: complete=false
		if complete: break
	GameClock.running=false
	for id in ["linya","zhou","ahe"]:
		print("COMMUNITY ARRIVAL ",id," position=",game.village.villagers[id].global_position," station=",game.village.villagers[id].station," cursor=",game.village.villagers[id].cursor," route=",game.village.villagers[id].route," retries=",game.village.villagers[id].retries)
		check(game.village.villagers[id].global_position.distance_to(WorldDevelopment.community_station(id))<=6,"原NPC沿真实移动走到各自共餐站位："+id)
	check(WorldDevelopment.gathered_people()==3,"三位原NPC实际到达雨棚，没有只验证两人或复制替代")
	await at("community");before=stamp()
	check(not WorldDevelopment.daily_community("supper") and stamp()==before,"巡灯与周末共餐共享每日额度，不能双重领取")
	GameClock.day=237;GameClock.minutes=1080;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(5)
	await inspect_all();await at("community")
	GameClock.running=true;game.village.refresh_gathering()
	for i in range(1200):
		await frames(1)
		if WorldDevelopment.gathered_people()>=2: break
	GameClock.running=false
	check(WorldDevelopment.daily_community("supper") and WorldDevelopment.state.supper_count==1,"下一次周末实带面包鱼汤牛奶，与桌旁村民共同结算")
	before=stamp();check(not WorldDevelopment.daily_community("supper") and stamp()==before,"同周同日共餐资源不能反复领取")
	Story.stage=7
	check(WorldDevelopment.community_station("zhou")==Vector2.INF,"新聚集不抢原第一章风灯庆典必需NPC")
	Story.stage=8
	check(WorldDevelopment.validate(WorldDevelopment.snapshot(),GameClock.day),"社区巡灯、共餐、日限与建设保存合法")
func save_and_seasons() -> void:
	await reset();await at("board")
	WorldDevelopment.build("dock",0);WorldDevelopment.build("community",0)
	var snap := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(snap),"世界建设与所有既有系统组成完整合法新存档")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(snap))
	check(FarmSaveStore.restore(game,restored),"码头、路灯和待领分支补给跨JSON恢复")
	var levels := {"dock":WorldDevelopment.state.dock,"community":WorldDevelopment.state.community}
	var resources: Dictionary=Inventory.items.duplicate(true)
	for day in [253,281,309,337]:
		GameClock.day=day;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(4)
		check(WorldDevelopment.state.dock==levels.dock and WorldDevelopment.state.community==levels.community and Inventory.items==resources,"四季叠加不退回建设或重复发分支补给："+str(day))
	var source := WorldDevelopment.snapshot()
	WorldDevelopment.restore(JSON.parse_string(JSON.stringify(source)))
	check(WorldDevelopment.snapshot()==source,"重复恢复世界进度只重建外观，不执行建设和奖励")
	var bad := source.duplicate(true);bad.dock=3
	check(not WorldDevelopment.validate(bad,GameClock.day),"非法第三建设等级被拒绝")
	bad=source.duplicate(true);bad.parcels.dock.items={"diamond":1314}
	check(not WorldDevelopment.validate(bad,GameClock.day),"建设补给不能被伪造成钻石奖励")
	await Touch.place(self,game,"village",Vector2(640,756));game.auto_move.navigation.rebuild()
	var targets := {}
	for node in get_tree().get_nodes_in_group("interactables"):
		if "development_id" in node: targets[node.development_id]=node
	for context in ["board","dock","community","lamp:west","lamp:square","lamp:river"]:
		check(targets.has(context),"原村庄真实建设/服务实体存在："+context)
		if not targets.has(context): continue
		var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":targets[context],"point":targets[context].global_position})
		check(not route.is_empty(),"施工后设施站位合法可达："+context)
	for y in [21,22,23]:
		check(not game.auto_move.navigation.walkable(Vector2i(27,y)),"码头不把原河水变成普通可走地面："+str(y))
	check(not game.auto_move.navigation.walkable(Vector2i(31,20)),"已建货箱具有真实静态碰撞，玩家须绕行")
	GameState.set_control_mode("tap",false)
	game.auto_move.request(WorldDevelopment.anchor("board")+Vector2(0,-15));await Touch.finish(self,game,600)
	check(game.hud.world_development_panel.visible and WorldDevelopment.near("board"),"点击发展牌自动靠近后打开建设界面")
	var position: Vector2=game.player.position
	Touch.tap(self,game,Vector2(800,560));await frames(5)
	check(game.player.position==position and game.auto_move.target.is_empty(),"建设模态UI阻止地图点击穿透")
	game.hud.close_active_panel();await at("board")
	GameState.set_control_mode("joystick",false);game.action_cooldown=0;game.interact()
	check(game.hud.world_development_panel.visible,"备用摇杆/键盘E仍能打开新共建牌")
	game.hud.close_active_panel()

func feed_group(ids: Array) -> void:
	for id in ids:
		var entry: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,"farm",Vector2(entry.position[0],entry.position[1])+Vector2(0,24))
		check(Livestock.feed(id),"订单畜产依真实饲喂推进："+id)
func collect_group(ids: Array) -> void:
	for id in ids:
		var entry: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,"farm",Vector2(entry.position[0],entry.position[1])+Vector2(0,24))
		check(Livestock.collect(id),"新畜产真实进入背包："+id)
func advanced_trade_pipeline() -> void:
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.build("mill") and Kitchen.build("cheese_table"),"高级订单先真实建设原磨坊与奶酪台")
	await Touch.place(self,game,"farm",Livestock.SITES.barn+Vector2(0,32))
	check(Livestock.build("barn") and Livestock.buy_animal("barn") and Livestock.buy_animal("barn") and Livestock.buy_hay(60),"高级乳品订单先建原牛棚并购买两头幼牛")
	var cows: Array=[]
	for entry in Livestock.state.animals:
		if entry.species=="cow": cows.append(entry.id)
	for i in range(6):
		await feed_group(cows)
		check(await sleep_day(),"牛通过六个实际照料日成长并产奶："+str(i))
	check(Kitchen.recipe_unlocked("milk_porridge"),"真实成年牛产奶记录开放原乳品知识")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.enqueue("cheese",1),"订单前的奶酪队列是真实旧加工而非伪造库存")
	var old_job: int=Kitchen.state.queue[-1].id
	await at("dock")
	check(WorldDevelopment.accept_order("dairy_fish"),"交易棚与原设施真实开放乳品组合订单")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.enqueue("cheese",1),"接单后实际开启新奶酪加工链")
	var new_job: int=Kitchen.state.queue[-1].id
	await feed_group(cows);check(await sleep_day(),"新一轮动物产奶进入真实订单记录")
	check(int(WorldDevelopment.state.order.credit.get("milk",0))==2,"动物新生产凭据按一头一日去重并满足两份")
	await collect_group(cows)
	check(await sleep_day(),"奶酪原配方跨两日保存完成状态")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.claim_job(old_job) and int(WorldDevelopment.state.order.credit.get("cheese",0))==0,"接单前旧加工领取不能冒充本轮新加工")
	check(Kitchen.claim_job(new_job) and int(WorldDevelopment.state.order.credit.get("cheese",0))==1,"接单后新加工领取才增加贸易凭据")
	if not await catch_required("fish_grass",1):
		check(await sleep_day(),"钓鱼有日限时原跨日继续而非刷新同日资源")
		check(await catch_required("fish_grass",1),"下一日实际获取草鱼完成高级贸易链")
	await at("dock")
	check(WorldDevelopment.trade_ready() and WorldDevelopment.use_trade("dairy_fish") and WorldDevelopment.state.trade_count==3,"新奶酪、真产牛奶、实钓草鱼三条玩法真正汇合并交货")
	# 烹饪与鸡蛋订单另走原真实新做事件，旧面包库存不能代替。
	await Touch.place(self,game,"farm",Livestock.SITES.coop+Vector2(0,32))
	check(Livestock.build("coop") and Livestock.buy_animal("coop") and Livestock.buy_animal("coop"),"便餐贸易需要自己的两只鸡，不凭空生成鸡蛋")
	var chickens: Array=[]
	for entry in Livestock.state.animals:
		if entry.species=="chicken": chickens.append(entry.id)
	await Touch.place(self,game,"farm",Vector2(656,560))
	check(await plant(Vector2i(18,19),"potato") and await plant(Vector2i(19,19),"potato"),"面包食材使用原农田真实种下土豆")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.enqueue("flour",2),"面包原料从原磨坊真实加工而来")
	var flour_job: int=Kitchen.state.queue[-1].id
	for i in range(3):
		await feed_group(chickens)
		for cell in [Vector2i(18,19),Vector2i(19,19)]:
			if not game.farm.plots[game.farm.key(cell)].watered:
				check(game.farm.use_tool(cell,"water"),"面包土豆每天亲手浇水")
				await frames(16)
		check(await sleep_day(),"鸡与土豆都依原每日生产规则推进")
	for cell in [Vector2i(18,19),Vector2i(19,19)]:
		check(game.farm.use_tool(cell,"hand"),"成熟土豆实际收获给原厨房")
		await frames(16)
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0));check(Kitchen.claim_job(flour_job),"原小麦粉队列只领取一次")
	await at("dock")
	check(WorldDevelopment.accept_order("shared_meal"),"有真实养鸡知识后开放便餐组合订单")
	check(int(WorldDevelopment.state.order.credit.get("potato_bread",0))==0,"旧面包不能自动补入新一轮烹饪凭据")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.cook("potato_bread",2) and int(WorldDevelopment.state.order.credit.get("potato_bread",0))==2,"新烤两份面包经过原配方事务才能记入订单")
	await feed_group(chickens);check(await sleep_day(),"新一轮鸡蛋真实产出")
	await collect_group(chickens)
	if not await catch_required("fish_carp",2):
		check(await sleep_day(),"便餐钓鱼按原日限跨日重试")
		check(await catch_required("fish_carp",2),"原QTE钓到本轮需要的两尾鲤鱼")
	while GameClock.day-int(WorldDevelopment.state.trade_day)<3: check(await sleep_day(),"高级订单也遵守统一三日交货间隔")
	await at("dock")
	check(WorldDevelopment.trade_ready() and WorldDevelopment.use_trade("shared_meal") and WorldDevelopment.state.trade_count==4,"新面包、新鸡蛋与实钓鲤鱼完成原系统联动订单")
	check(WorldDevelopment.validate(WorldDevelopment.snapshot(),GameClock.day),"多条原生产链的凭据和交货进度一起保存合法")
