extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var machines: Dictionary={}
var animal_ids: Array[String]=[]
var chains: Array[String]=[]
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock()
	for id in ["mill","jam_pot","egg_table","cheese_table","loom"]:
		machines[id]=await Fixture.install(self,game,"station_"+id);check(machines[id]!="","正常建造产业链设备："+id)
	await grow(["wheat","wheat","wheat","wheat","strawberry","carrot","potato"])
	check(await process("mill","mill_flour",4) and Inventory.count("flour")==4,"实收四份小麦加工四份面粉")
	await home();check(Kitchen.cook("bread") and Inventory.count("bread")==1,"小麦→面粉→面包完整完成")
	chains.append("wheat/flour/bread")
	check(await process("jam_pot","strawberry_jam") and Inventory.count("strawberry_jam")==1,"实收两份草莓熬成果酱，保留给蛋糕")
	while Calendar.season()!=1: await next_day()
	await grow(["corn","corn","corn"])
	check(await process("mill","corn_feed",3) and Inventory.count("hay")==48,"实收玉米加工合法饲料48份")
	for site in ["coop","barn"]:
		await Touch.place(self,game,"farm",Livestock.site_point(site)+Vector2(0,48))
		check(Livestock.build(site) and Livestock.buy_animal(site),"真实购买并照料幼畜："+site)
		animal_ids.append(str(Livestock.animals_at(site)[0].id))
	for day in range(7): await care();await next_day()
	await collect()
	check(Inventory.count("egg")>=3 and Inventory.count("milk")>=1,"自产玉米饲料支持实际产蛋产奶")
	await home();check(Kitchen.cook("strawberry_cake") and Inventory.count("strawberry_cake")==1,"草莓→果酱→草莓蛋糕，蛋奶均由真实养殖取得")
	chains.append("strawberry/jam/strawberry_cake")
	check(await process("egg_table","mayonnaise") and Inventory.count("mayonnaise")==1,"玉米→饲料→鸡蛋→蛋黄酱完整完成")
	chains.append("corn/hay/chicken/egg/mayonnaise")
	for day in range(2): await care();await next_day()
	await collect()
	check(await process("cheese_table","butter") and Inventory.count("butter")==1,"实际牛奶加工黄油")
	await home();check(Kitchen.cook("cream_stew") and Inventory.count("cream_stew")==1,"牛奶→黄油→奶油炖菜，蔬菜来自春季实收库存")
	chains.append("cow/milk/butter/cream_stew")
	while Calendar.season()!=2: await next_day()
	Fixture.cooperative();await grow(["cotton","cotton"])
	check(await process("loom","cotton_cloth") and Inventory.count("cotton_cloth")==1,"实收两份棉花纺成一份棉布")
	await Touch.place(self,game,"home",Housing.anchor("storage")+Vector2(0,30))
	check(Housing.buy("cotton_chair") and int(Housing.state.owned.get("cotton_chair",0))==1 and Inventory.count("cotton_cloth")==0,"棉花→棉布→可摆放软垫椅完整完成")
	chains.append("cotton/cotton_cloth/cotton_chair")
	check(chains.size()==5 and FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"五条链使用真实作物、养殖和配方，构成合法存档")
	var file:=FileAccess.open("res://docs/quality081/chains.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checked,"failures":failed,"chains":chains,"agricultural_inputs":"actual sow/water/harvest/feed/collect","fixture_only":"construction materials, initial test capital, earned cooperative flag","new_maps_or_gameplay":false},"\t"));file.close()
	print("QUALITY081 CHAINS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func next_day() -> void:
	GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"使用原20:00正式睡眠推进一天")
	await frames(2)
func grow(ids: Array[String]) -> void:
	await Touch.place(self,game,"farm",Vector2(704,608));var cells: Array[Vector2i]=[];var maximum: int=0
	for i in range(ids.size()):
		var id: String=ids[i];var cell:=Vector2i(18+i,17)
		check(FarmEconomy.buy(id,1),"按当前合法季节购买种子："+id)
		if game.farm.plot_at(cell).is_empty(): check(game.farm.use_tool(cell,"hoe"),"正常翻土")
		check(game.farm.use_tool(cell,id+"_seed"),"实际播种："+id);cells.append(cell);maximum=maxi(maximum,Catalog.crops[id].growth_days)
	for day in range(maximum):
		for cell in cells:
			if not game.farm.is_mature(game.farm.plot_at(cell)): check(game.farm.use_tool(cell,"water"),"每日照料未成熟作物")
		await next_day()
	for cell in cells: check(game.farm.use_tool(cell,"hand"),"收获入包且不直接注入作物")
func home() -> void: await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
func process(station: String, recipe: String, batches: int=1) -> bool:
	await Touch.place(self,game,"farm",Vector2(704,704));var id: String=machines[station]
	if not await Fixture.approach(self,game,id) or not Workshop.start(id,recipe,batches): return false
	var serial: int=Workshop.state.jobs[id].id
	Fixture.advance(int(HarvestCatalog.data().processing[recipe].processing_duration)*batches);await frames(3)
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,id)
	return Workshop.claim(id,serial)
func care() -> void:
	for id in animal_ids:
		var animal: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,Livestock.animal_area(animal),Livestock.animal_point(animal)+Vector2(0,28))
		check(Livestock.feed(id) and Livestock.pet(id),"消耗自产饲料并照料真实动物")
func collect() -> void:
	for id in animal_ids:
		var animal: Dictionary=Livestock.animal(id)
		await Touch.place(self,game,Livestock.animal_area(animal),Livestock.animal_point(animal)+Vector2(0,28))
		check(Livestock.collect(id),"收取实际日结算产物")
