extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	await all_processing()
	await orchard()
	await textiles()
	print("HARVEST CHAINS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func all_processing() -> void:
	Fixture.stock();var devices: Dictionary={}
	for station in HarvestCatalog.data().stations:
		var device: String=await Fixture.install(self,game,"station_"+str(station))
		check(device!="","每一种设备真实建造："+str(station));devices[station]=device
	for id in HarvestCatalog.data().processing:
		var recipe: Dictionary=HarvestCatalog.data().processing[id];var device: String=devices[recipe.processing_station_id]
		if device=="": continue
		await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,device)
		for input in recipe.input_items: Inventory.items[input]=int(recipe.input_items[input])+2
		var before:=Inventory.items.duplicate();var was: int=Inventory.count(str(recipe.output_item_id))
		check(Workshop.start(device,str(id)),"真实投入加工："+str(id))
		if not Workshop.state.jobs.has(device): continue
		var deducted: bool=true
		for input in recipe.input_items: deducted=deducted and Inventory.count(input)==int(before[input])-int(recipe.input_items[input])
		check(deducted,"配方所有材料精确扣除："+str(id))
		var serial: int=Workshop.state.jobs[device].id
		Fixture.advance(int(recipe.processing_duration));await frames(3)
		await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,device)
		check(Workshop.claim(device,serial) and Inventory.count(str(recipe.output_item_id))==was+int(recipe.output_quantity),"计时结束得到配置成品："+str(id))
		check(not Workshop.claim(device,serial),"重复点击不能复制该配方成品："+str(id))
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"全设备加工历史构成合法存档")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and Workshop.state.claimed.size()==HarvestCatalog.data().processing.size(),"全部实际配方领取记录可恢复")
	var legacy: Dictionary=original.duplicate(true);legacy.version=27;legacy.erase("workshop");legacy.kitchen.built=["mill"]
	check(FarmSaveStore.restore(game,legacy),"有旧磨坊的v27档仍可迁移")
	await frames(5);Fixture.stock();var coins: int=Inventory.coins
	var converted: String=await Fixture.install(self,game,"station_mill")
	check(converted!="" and Inventory.coins==coins,"旧已建设磨坊获得一次免费实体安装")
	coins=Inventory.coins
	var second: String=await Fixture.install(self,game,"station_mill")
	check(second!="" and Inventory.coins==coins-80,"旧设备权益只能使用一次，不复制免费整机")
func orchard() -> void:
	FarmSaveStore.restore(game,original);await frames(5);Fixture.stock()
	check(not Workshop.buy_sapling("apple"),"合作社前树苗未开放")
	Fixture.cooperative()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"果园测试使用合法第一章建设进度")
	var trees: Dictionary={}
	for fruit in HarvestCatalog.data().orchard:
		var coins: int=Inventory.coins
		check(Workshop.buy_sapling(fruit) and Inventory.coins==coins-ceili(int(HarvestCatalog.data().orchard[fruit].sapling_price)*.8),"合作社折扣购买树苗："+fruit)
		var id: String=await Fixture.install(self,game,"orchard_"+fruit);trees[fruit]=id
		check(id!="" and Inventory.count(fruit+"_sapling")==0 and Workshop.tree_age(id)==0,"树苗实体栽种并初始化独立树龄："+fruit)
		if id!="":
			var object: Node2D=game.territory_world.objects[id]
			check(not object.hit_rect().has_point(Vector2(35,-60)) and TouchInteractionResolver.resolve(game,object.global_position+Vector2(35,-60)).get("object")!=object,"幼树透明画布不抢走邻近地格点击："+fruit)
	for i in range(12):
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
	await frames(4)
	check(Workshop.tree_age(trees.apple)==12 and not Workshop.harvest_fruit(trees.apple),"果树独立成长，非结果季不会凭树龄凭空产出")
	for fruit in trees:
		var id: String=trees[fruit];var data: Dictionary=HarvestCatalog.data().orchard[fruit]
		# Advance normally through the calendar to this tree's next natural fruit season.
		var guard: int=0
		while Calendar.season() not in data.seasons or int(Workshop.state.orchard[id].fruit)==0:
			GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);guard+=1
			if guard>130: break
		await Touch.place(self,game,"farm",Vector2(704,704));check(await Fixture.approach(self,game,id),"各级树冠有合法靠近点："+fruit)
		check(int(Workshop.state.orchard[id].fruit)==2,"对应自然季节结果："+fruit)
		Inventory.items[fruit]=999
		check(not Workshop.harvest_fruit(id) and int(Workshop.state.orchard[id].fruit)==2,"满包保留树上果实："+fruit)
		Inventory.items.erase(fruit)
		check(Workshop.harvest_fruit(id) and Inventory.count(fruit)==2 and not Workshop.harvest_fruit(id),"同次采果只结算一次："+fruit)
		var row: Dictionary=Workshop.state.orchard[id].duplicate()
		GameClock.day_advanced.emit()
		check(Workshop.state.orchard[id]==row,"重复日信号不重复结果："+fruit)
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"四树树龄与下次结果日完整保存恢复")
	await Touch.place(self,game,"farm",Vector2(704,704));game.territory_editor.open();await frames(4)
	var id: String=trees.apple;var before: Dictionary=Workshop.state.orchard[id].duplicate()
	var plan:=Territory.plan_move(id,Vector2i(27,25))
	check(plan.valid and Territory.apply_plan(plan) and Workshop.state.orchard[id]==before,"果树搬动不重置树龄或复制果实")
	game.territory_editor.cancel();await frames(4)
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"果园布局与生长状态交叉验证通过")
func textiles() -> void:
	FarmSaveStore.restore(game,original);await frames(4)
	Inventory.coins=1000;Inventory.items.wool_cloth=2;Inventory.items.cotton_cloth=1;Inventory.items.wood=3
	await Touch.place(self,game,"home",Housing.anchor("storage")+Vector2(0,30))
	check(Housing.buy("wool_rug") and int(Housing.state.owned.get("wool_rug",0))==1 and Inventory.count("wool_cloth")==0,"毛布真正进入可装修地毯制作")
	check(Housing.buy("cotton_chair") and int(Housing.state.owned.get("cotton_chair",0))==1 and Inventory.count("cotton_cloth")==0,"棉布真正进入软垫家具制作")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"新织物家具沿用住宅库存存档")
	for kind in ["wool_rug","cotton_chair"]:
		var placed: bool=false
		for y in range(8,17):
			for x in range(11,28):
				if Housing.can_place(kind,"home",Vector2i(x,y)) and Housing.place(kind,"home",Vector2i(x,y)): placed=true;break
			if placed: break
		check(placed,"自产织物家具可真实放入当前住宅："+kind)
		await frames(4)
		if placed:
			var id: String=Housing.state.placed[-1].id;var rendered: bool=false
			for object in get_tree().get_nodes_in_group("housing_furniture"):
				if object.housing_id==id: rendered=object.texture!=null and object.is_visible_in_tree()
			check(rendered and Housing.recycle(id) and int(Housing.state.owned.get(kind,0))==1,"实体家具正确显示并回收原件，不复制材料："+kind)
			await frames(4)
