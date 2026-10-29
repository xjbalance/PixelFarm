extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	await dishes()
	await agricultural_cycle()
	await livestock_cycle()
	await lake_cycle()
	await gifts()
	print("HARVEST MEALS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,original),"恢复隔离场景快照")
	GameClock.running=false;await frames(5);Fixture.stock()
func home() -> void: await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
func dishes() -> void:
	await home()
	check(Kitchen.data.recipes.size()==32,"原五道料理与新增27道在同一厨房注册")
	for id in HarvestCatalog.data().recipes:
		var r: Dictionary=HarvestCatalog.data().recipes[id]
		for input in r.required: Inventory.items[input]=int(r.required[input])+1
		Inventory.items.erase(id);var before:=Inventory.items.duplicate()
		check(Kitchen.cook(id) and Inventory.count(id)==1,"新料理可真正制作："+str(id))
		var deducted: bool=true
		for input in r.required: deducted=deducted and Inventory.count(input)==int(before[input])-int(r.required[input])
		check(deducted,"料理按配方精确扣料："+str(id))
		GameState.stamina=10;Kitchen.state.buff={"id":"speed","remaining":65.0}
		check(Kitchen.consume(id) and GameState.stamina==10+int(Kitchen.data.items[id].energy) and Kitchen.state.buff.id=="speed" and Kitchen.state.buff.remaining==65.0,"恢复并保持唯一增益不叠加："+str(id))
		GameState.stamina=100;Inventory.items[id]=1
		check(not Kitchen.consume(id) and Inventory.count(id)==1,"满体力不消耗新料理："+str(id))
		var coins: int=Inventory.coins
		check(FarmEconomy.sell(id,1) and Inventory.coins==coins+Catalog.sell_price(id),"新料理沿用商店出售与定价："+str(id))
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"所有新增已烹饪记录、食品与增益可保存")
	Inventory.items.flour=1;Inventory.items.erase("bread");var stamp:=Inventory.items.duplicate()
	check(not Kitchen.cook("bread") and Inventory.items==stamp,"缺材料失败不部分扣款")
	Inventory.items.flour=2;Inventory.items.bread=999;stamp=Inventory.items.duplicate()
	check(not Kitchen.cook("bread") and Inventory.items==stamp,"料理满包失败保留材料")
func grow(crops: Array[String]) -> void:
	var cells: Array[Vector2i]=[];var days: int=0
	for i in range(crops.size()):
		var cell:=Vector2i(18+i,17);var crop: String=crops[i]
		Inventory.items[crop+"_seed"]=int(Inventory.items.get(crop+"_seed",0))+1
		check(game.farm.use_tool(cell,"hoe") and game.farm.use_tool(cell,crop+"_seed"),"生产链实际播种："+crop)
		cells.append(cell);days=maxi(days,Catalog.crops[crop].growth_days)
	for i in range(days):
		for cell in cells: game.farm.use_tool(cell,"water")
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
	for cell in cells: check(game.farm.use_tool(cell,"hand"),"生产链实际收获："+str(cell))
	await frames(4)
func process_at(id: String, recipe: String, batches: int=1) -> bool:
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,id)
	if not Workshop.start(id,recipe,batches): return false
	var serial: int=Workshop.state.jobs[id].id
	Fixture.advance(int(HarvestCatalog.data().processing[recipe].processing_duration)*batches);await frames(4)
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,id)
	return Workshop.claim(id,serial)
func agricultural_cycle() -> void:
	await reset();var mill: String=await Fixture.install(self,game,"station_mill")
	await grow(["wheat","wheat"])
	check(Inventory.count("wheat")==2 and await process_at(mill,"mill_flour",2),"真实收获小麦两份转为面粉两份")
	await home();check(Kitchen.cook("bread") and Inventory.count("bread")==1,"实际种田加工后的面粉制作面包")
	var coins: int=Inventory.coins
	check(FarmEconomy.sell("bread",1) and Inventory.coins==coins+Catalog.sell_price("bread"),"农业完整循环：播种→收获→磨粉→面包→出售")
	# A sofa nap advances the same production clock, including midnight precedence.
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill);Inventory.items.wheat=2
	check(Workshop.start(mill,"mill_flour"),"小睡前开始45分钟磨粉")
	await Touch.place(self,game,"home",Housing.anchor("sofa")+Vector2(0,28))
	check(game.home_rest.open(),"生产中可正常打开沙发小睡确认")
	var serial: int=game.home_rest.pending_token;var minute: float=GameClock.minutes
	check(game.home_rest.confirm(serial),"沙发小睡确认一次")
	await frames(30)
	check(GameClock.minutes==minute+60 and Workshop.state.jobs[mill].ready,"沙发小睡一小时自然推进加工进度")
	check(not game.home_rest.confirm(serial),"同次小睡回调不会重复结算工坊时间")
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill)
	var first: int=Workshop.state.jobs[mill].id
	check(Workshop.claim(mill,first),"领取小睡期间完成的第一笔工单")
	GameClock.minutes=1410
	check(Workshop.start(mill,"mill_flour"),"23:30开始新工单，不立即完成")
	var night_job: int=Workshop.state.jobs[mill].id;var day: int=GameClock.day
	await Touch.place(self,game,"home",Housing.anchor("sofa")+Vector2(0,28))
	var meter: Dictionary={"days":0};var observer:=func(): meter.days+=1
	GameClock.day_advanced.connect(observer)
	check(game.home_rest.open() and game.home_rest.confirm(game.home_rest.pending_token),"23:30生产中执行真实沙发小睡")
	await frames(30);GameClock.day_advanced.disconnect(observer)
	check(GameClock.day==day+1 and GameClock.minutes==360 and meter.days==1 and Workshop.state.jobs[mill].ready,"午夜优先结算一次，工坊经正常睡眠完成，不补休到次日06:30")
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill)
	check(Workshop.claim(mill,night_job) and not Workshop.claim(mill,night_job) and Inventory.count("flour")==2,"午夜小睡工单只发一份，不重复材料或成品")
func livestock_cycle() -> void:
	await reset()
	for i in range(28): GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
	await Touch.place(self,game,"farm",Vector2(704,704));var mill: String=await Fixture.install(self,game,"station_mill")
	await grow(["corn","corn","corn","wheat","wheat"])
	check(await process_at(mill,"corn_feed",3) and Inventory.count("hay")==48,"三份实收玉米加工48份合法动物饲料")
	var animals: Array[String]=[]
	for site in ["coop","barn"]:
		await Touch.place(self,game,"farm",Livestock.site_point(site)+Vector2(0,48))
		check(Livestock.build(site) and Livestock.buy_animal(site),"真实建设并购买幼畜："+site)
		animals.append(str(Livestock.animals_at(site)[0].id))
	for day in range(7):
		for id in animals:
			var animal: Dictionary=Livestock.animal(id)
			await Touch.place(self,game,"farm",Vector2(animal.position[0],animal.position[1])+Vector2(0,28))
			check(Livestock.feed(id) and Livestock.pet(id),"用自产玉米饲料每日照料真实动物")
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(3)
	for id in animals:
		var animal: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,"farm",Vector2(animal.position[0],animal.position[1])+Vector2(0,28))
		check(Livestock.collect(id),"从正常养大的动物收集产品")
	check(Inventory.count("egg")>=2 and Inventory.count("milk")>=1,"鸡蛋与牛奶均来自实际养殖")
	check(await process_at(mill,"mill_flour",2),"同时收获的小麦磨成蛋糕面粉")
	await home()
	check(Kitchen.cook("cake") and Inventory.count("cake")==1,"畜牧循环：种玉米→饲料→养鸡产蛋→自家蛋糕")
func lake_cycle() -> void:
	await reset();var smoker: String=await Fixture.install(self,game,"station_smoker")
	await Touch.place(self,game,"farm",Fishing.point("farm_lake"));GameState.select_tool(8);game.player.action_time=0
	check(Fishing.buy_bait(6),"正常购买鱼饵，不生成测试鱼")
	var fish: String=""
	for cast in range(6):
		check(Fishing.start("farm_lake"),"湖泊生产链真实抛竿")
		for i in range(3600):
			if not Fishing.active(): break
			Fishing.tick(1.0/120.0,float(Fishing.session.player)>float(Fishing.session.fish))
		for id in ["fish_carp","fish_crucian"]:
			if Inventory.count(id)>=2: fish=id
		if fish!="": break
	check(fish!="" and Fishing.state.total>=2,"小游戏赢得并领取两条同种普通鱼")
	if fish!="":
		check(await process_at(smoker,"smoke_"+fish) and Inventory.count("smoked_fish")==1,"实际钓获的鱼可投入熏制炉")
		check(FarmEconomy.sell("smoked_fish",1),"湖泊完整循环：抛竿→追鱼→收获→熏制→出售")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"完整生产链保留合法钓鱼、经营与任务状态")
func gifts() -> void:
	await reset()
	for id in HarvestCatalog.data().crops: check(Social.taste("linya",id)=="喜欢","每种新作物有真实NPC礼物用途："+id)
	var person:=Social.person_node("linya")
	if person:
		var area: String="farm" if game.world.is_ancestor_of(person) else "village"
		await Touch.place(self,game,area,person.global_position+Vector2(0,28))
		Inventory.items.strawberry=2
		check(Social.gift("linya","strawberry") and Inventory.count("strawberry")==1,"新增礼物走原每日赠礼事务")
		check(not Social.gift("linya","strawberry") and Inventory.count("strawberry")==1,"新礼物也不能绕过每日赠送限制")
