extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await facilities_and_berries()
	await queues_and_meals()
	await production_unlocks()
	await effects()
	await persistence_and_navigation()
	print("KITCHEN B RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false;GameWeather.enabled=false
	Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"copper_bar":100,"iron_bar":100,"carrot":100,"potato":100,"wheat":100,"milk":100,"egg":100,"fish_carp":100,"wild_berry":100,"hay":100,"fishing_bait":99}
	Kitchen.restore(Kitchen.defaults(GameClock.day))
	await frames(4)
func home() -> void:
	await Touch.place(self,game,"home",Vector2(848,464))
func next_day() -> void:
	GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(3)
func stamp() -> Dictionary:
	return {"state":Kitchen.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"meal_day":Aquaculture.state.meal_day}
func facilities_and_berries() -> void:
	await reset()
	var before := stamp()
	check(not Kitchen.build("mill") and stamp()==before,"远离小屋厨房不能远程建加工设备")
	await home();Inventory.coins=0;before=stamp()
	check(not Kitchen.build("mill") and stamp()==before,"设备建设金币不足整笔拒绝")
	Inventory.coins=100000;Inventory.items.wood=0;before=stamp()
	check(not Kitchen.build("mill") and stamp()==before,"设备材料不足不部分扣费")
	Inventory.items.wood=999
	for id in Kitchen.FACILITIES:
		check(Kitchen.build(id) and id in Kitchen.state.built,"可以实际建造加工设施："+id)
		before=stamp();check(not Kitchen.build(id) and stamp()==before,"重复建造不重扣资源："+id)
	check(not Kitchen.build("invented"),"未知加工设施被拒绝")
	before=stamp();check(not Kitchen.harvest_berries() and stamp()==before,"不能在小屋远程收农场野莓")
	await Touch.place(self,game,"farm",Vector2(240,592))
	Inventory.items.wild_berry=999;before=stamp()
	check(not Kitchen.harvest_berries() and stamp()==before,"野莓满包不会消耗体力或今天采摘机会")
	Inventory.items.wild_berry=0
	var stamina: int=GameState.stamina
	check(Kitchen.harvest_berries() and Inventory.count("wild_berry")==2 and GameState.stamina==stamina-2,"农场实体莓丛春季每日产两份并消耗体力")
	before=stamp();check(not Kitchen.harvest_berries() and stamp()==before,"重复点击莓丛不刷食材")
	GameClock.day=85;Calendar.restore(Calendar.snapshot(85));GameClock.changed.emit()
	check(Kitchen.harvest_berries() and Inventory.count("wild_berry")==3,"冬季仍可收一份野莓，不依赖不存在森林")

func queues_and_meals() -> void:
	await reset();await home()
	check(Kitchen.recipe_unlocked("carrot_stew") and not Kitchen.recipe_unlocked("potato_bread"),"基础炖菜可做，面包需先建磨坊")
	var before := stamp()
	check(not Kitchen.enqueue("flour") and stamp()==before,"没有对应设备不能下加工订单")
	for id in Kitchen.FACILITIES: Kitchen.build(id)
	for id in Kitchen.PROCESSING:
		check(Kitchen.enqueue(id,2),"真实配方下单并扣料："+id)
	check(Kitchen.state.queue.size()==4 and Kitchen.state.next_job==5,"四队列使用唯一递增序号")
	before=stamp();check(not Kitchen.enqueue("flour") and stamp()==before,"加工队列满时不再扣材料")
	check(not Kitchen.claim_job(1) and not Kitchen.claim_job(99),"未到完成日期和不存在订单都不能领奖")
	var snapshot := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snapshot))) and Kitchen.state.queue.size()==4,"跨天加工队列与序号随完整存档恢复")
	await frames(4);await next_day()
	check(Kitchen.state.queue[0].ready and not Kitchen.state.queue[1].ready and Kitchen.state.queue[2].ready and not Kitchen.state.queue[3].ready,"统一真实日结算只标记达到时长的订单")
	Inventory.items.flour=999;before=stamp()
	check(not Kitchen.claim_job(1) and stamp()==before,"成品满包保留整笔已完成订单")
	Inventory.items.flour=0
	check(Kitchen.claim_job(1) and Inventory.count("flour")==2 and Kitchen.state.queue.size()==3,"腾出背包后领取一次真实加工产物")
	before=stamp();check(not Kitchen.claim_job(1) and stamp()==before,"已领取序号无法重复产出")
	check(Kitchen.claim_job(3) and Inventory.count("smoked_fish")==2,"另一笔同时成熟的熏鱼可独立领取")
	await next_day()
	check(Kitchen.claim_job(2) and Kitchen.claim_job(4) and Inventory.count("cheese")==2 and Inventory.count("berry_jam")==2,"两日奶酪和果酱按各自队列完成")
	before=stamp();GameClock.day_advanced.emit();Kitchen.settle_day()
	check(stamp()==before,"重复日信号不重复生成已领取加工成品")
	check(Kitchen.cook("carrot_stew",2) and Inventory.count("carrot_stew")==2,"基础料理真实扣除农作物并进入背包")
	Inventory.items.carrot_stew=999;before=stamp()
	check(not Kitchen.cook("carrot_stew") and stamp()==before,"料理背包满时原材料不丢失")
	Inventory.items.carrot_stew=2
	check(Kitchen.cook("potato_bread") and Inventory.count("potato_bread")==1,"加工面粉与土豆形成真实面包制作链")
	check(not Kitchen.recipe_unlocked("egg_meal") and not Kitchen.recipe_unlocked("milk_porridge") and not Kitchen.recipe_unlocked("fish_feast"),"只有库存食材不能代替实际畜牧和钓鱼菜谱前置")

func production_unlocks() -> void:
	await reset()
	var ids: Array[String]=[]
	for site in ["coop","barn"]:
		await Touch.place(self,game,"farm",Livestock.SITES[site]+Vector2(0,48))
		check(Livestock.build(site) and Livestock.buy_animal(site),"菜谱联动从真实畜舍与幼畜开始："+site)
		ids.append(str(Livestock.animals_at(site)[0].id))
	for i in range(7):
		for id in ids:
			var animal: Dictionary=Livestock.animal(id)
			await Touch.place(self,game,Livestock.animal_area(animal),Livestock.animal_point(animal)+Vector2(0,28))
			Livestock.feed(id);Livestock.pet(id)
		await next_day()
	var collected := true
	for id in ids:
		var animal: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,Livestock.animal_area(animal),Livestock.animal_point(animal)+Vector2(0,28))
		collected=Livestock.collect(id) and collected
	check(collected and Kitchen.recipe_unlocked("egg_meal"),"每日照料实际产蛋产奶后解锁煎蛋料理")
	await home();Kitchen.build("mill");Kitchen.build("smoker")
	Inventory.items.flour=4;Inventory.items.cheese=4;Inventory.items.smoked_fish=4
	check(Kitchen.recipe_unlocked("milk_porridge") and Kitchen.cook("milk_porridge") and Kitchen.cook("egg_meal"),"真实畜牧记录与厨房设施共同解锁奶粥并可以制作")
	await Touch.place(self,game,"farm",Vector2(944,464));GameState.select_tool(GameState.tools.find("fishing_rod"));game.player.action_time=0
	check(Fishing.start("farm_lake"),"湖鲜菜谱联动从真实抛竿开始")
	for i in range(3600):
		if not Fishing.active(): break
		Fishing.tick(1.0/120.0,float(Fishing.session.player)>float(Fishing.session.fish))
	check(Fishing.state.total==1,"完成实际追鱼小游戏才能取得湖鲜菜谱钓获证明")
	await home()
	check(Kitchen.recipe_unlocked("fish_feast") and Kitchen.cook("fish_feast"),"钓获证明、熏鱼和奶酪串成可制作湖鲜餐")

func effects() -> void:
	await reset();await home()
	for item in Kitchen.RECIPES: Inventory.items[item]=4
	for pair in [["carrot_stew",32],["potato_bread",18],["egg_meal",20],["milk_porridge",24],["fish_feast",28]]:
		GameState.stamina=10
		check(Kitchen.consume(pair[0]) and GameState.stamina==10+pair[1],"料理恢复明确体力："+pair[0])
		var before := stamp()
		check(Kitchen.consume(pair[0]) and Inventory.count(pair[0])==int(before.items[pair[0]])-1 and GameState.stamina==10+2*pair[1] and Kitchen.state.buff==before.state.buff,"同日独立再次食用消耗物品恢复体力，不叠加或延长增益："+pair[0])
		Inventory.items.fish_soup=2
		check(Aquaculture.consume_food("fish_soup") and Inventory.count("fish_soup")==1 and GameState.stamina==mini(GameState.max_stamina(),10+2*pair[1]+30),"厨房料理后仍可吃原鱼汤，按份恢复且扣物："+pair[0])
		if pair[0]=="potato_bread": check(is_equal_approx(Kitchen.speed_multiplier(),1.15),"面包提供15%移速查询，不叠加")
		if pair[0]=="egg_meal": check(Kitchen.energy_cost(4)==3 and Kitchen.energy_cost(3)==2 and Kitchen.energy_cost(1)==1,"省力料理向下取整75%且每次正费用至少1")
		if pair[0]=="milk_porridge": check(Kitchen.mining_power()==1,"奶粥提供一次采矿伤害+1")
		if pair[0]=="fish_feast": check(is_equal_approx(Kitchen.fishing_assist(),.03),"湖鲜餐提供钓鱼带宽辅助0.03")
		if Kitchen.state.buff.id!="":
			var seconds: float=Kitchen.state.buff.remaining
			GameClock.running=false;Kitchen._process(30)
			check(Kitchen.state.buff.remaining==seconds,"暂停时间不消耗料理增益："+pair[0])
			GameClock.running=true;GameState.set_modal(true);Kitchen._process(30)
			check(Kitchen.state.buff.remaining==seconds,"阅读UI不消耗料理增益："+pair[0])
			GameState.set_modal(false);game.backgrounded=true;Kitchen._process(30)
			check(Kitchen.state.buff.remaining==seconds,"应用后台不消耗料理增益："+pair[0])
			game.backgrounded=false;Kitchen._process(5)
			check(is_equal_approx(Kitchen.state.buff.remaining,seconds-5),"增益只按有效游戏秒数衰减："+pair[0])
			var buff_saved: Dictionary=Kitchen.snapshot();Kitchen.restore(JSON.parse_string(JSON.stringify(buff_saved)))
			check(Kitchen.state.buff.remaining==buff_saved.buff.remaining,"增益剩余秒数正常保存恢复："+pair[0])
			Kitchen._process(500)
			check(Kitchen.state.buff.id=="" and Kitchen.speed_multiplier()==1 and Kitchen.mining_power()==0 and Kitchen.fishing_assist()==0,"到期移除唯一增益："+pair[0])
			GameClock.running=false
		await next_day()
	GameState.stamina=GameState.max_stamina()
	var before := stamp();check(not Kitchen.consume("carrot_stew") and stamp()==before,"满体力不白耗料理或改变增益")
	GameState.stamina=20;Inventory.items.dried_fish=1
	check(Aquaculture.consume_food("dried_fish") and Kitchen.consume("potato_bread") and GameState.stamina==56,"原鱼干后仍可独立吃面包，恢复18加18体力")

func persistence_and_navigation() -> void:
	await reset();await home();Kitchen.build("mill");Kitchen.enqueue("flour",3)
	var save := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(save),"厨房分区与待加工订单构成合法整档")
	var bad := Kitchen.snapshot();bad.queue.append(bad.queue[0].duplicate(true))
	check(not Kitchen.validate(bad,GameClock.day),"重复队列序号整份拒绝")
	bad=Kitchen.snapshot();bad.queue[0].ready=true
	check(not Kitchen.validate(bad,GameClock.day),"提前伪造就绪标记不能领取成品")
	bad=Kitchen.snapshot();bad.built.append("unknown_machine")
	check(not Kitchen.validate(bad,GameClock.day),"未知设备存档被拒绝")
	bad=Kitchen.snapshot();bad.buff={"id":"speed","remaining":9999.0}
	check(not Kitchen.validate(bad,GameClock.day),"超过规定时长的增益被拒绝")
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))) and Kitchen.state.queue.size()==1,"完整JSON恢复保持厨房与加工序号")
	await frames(5)
	await Touch.place(self,game,"home",Vector2(640,500))
	Touch.tap(self,game,Vector2(848,410));await Touch.finish(self,game,500)
	check(game.hud.kitchen_panel.visible and Kitchen.near_kitchen(),"点击实体厨房自动绕桌靠近并打开面板")
	game.hud.close_active_panel();game.auto_move.navigation.rebuild()
	for target in [Vector2(640,556),Vector2(786,342)]:
		var kind: String="exit" if target.y>500 else "sleep"
		var point: Node2D
		for object in get_tree().get_nodes_in_group("interactables"):
			if "kind" in object and object.kind==kind and object.is_visible_in_tree(): point=object;break
		check(point!=null and not game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(),"厨房不挡原房门/睡眠必要通道："+kind)
	await Touch.place(self,game,"farm",Vector2(304,560))
	Touch.tap(self,game,Vector2(240,542));await Touch.finish(self,game,500)
	check(game.hud.kitchen_panel.visible and game.hud.kitchen_panel.context=="berry" and Kitchen.near_berry(),"原农场野莓灌木可点击寻路并实际交互")
	game.hud.close_active_panel()
