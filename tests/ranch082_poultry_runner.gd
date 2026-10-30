extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
var motions: Array=[]
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	Inventory.items={"wood":200,"stone":200,"hay":200};Inventory.coins=10000
	game.change_location("farm",Livestock.site_point("coop")+Vector2(0,32));await frames(3)
	check(Livestock.build("coop"),"build existing poultry shelter")
	check(Livestock.buy_animal("coop") and Livestock.buy_animal("coop","duck"),"chicken and duck purchased in shared legal capacity")
	check(Inventory.coins==10000-160-60-100,"only real animal purchase costs deducted")
	var chicken: Dictionary=Livestock.animals_at("coop")[0];var duck: Dictionary=Livestock.animals_at("coop")[1]
	check(chicken.species=="chicken" and duck.species=="duck","stable separate species identities")
	var eggs: Array=[]
	for day in range(7):
		for entry in Livestock.animals_at("coop"):
			game.player.global_position=Livestock.animal_point(entry)+Vector2(0,24)
			var hay: int=Inventory.count("hay")
			check(Livestock.feed(entry.id) and Inventory.count("hay")==hay-1,"daily feed exactly once "+str(day)+entry.species)
			check(not Livestock.feed(entry.id) and Inventory.count("hay")==hay-1,"repeat feed rejected "+str(day)+entry.species)
			check(Livestock.pet(entry.id) and not Livestock.pet(entry.id),"pet once daily "+str(day)+entry.species)
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"normal game sleep settles poultry")
		await frames(3);eggs.append([chicken.product,duck.product])
		if day<2: check(chicken.product==0,"young chicken has no eggs")
		if day<4: check(duck.product==0,"young duck / incomplete two-day cycle has no eggs")
	check(chicken.product==3 and duck.product==2,"chicken original cap3 and duck one per2 eligible days")
	var product_before:=Livestock.snapshot();Livestock.settle_day();GameClock.day_advanced.emit()
	check(Livestock.snapshot()==product_before,"repeated day signal cannot duplicate products")
	game.player.global_position=Livestock.nest_point("coop")+Vector2(0,24)
	Inventory.items.egg=999
	check(not Livestock.collect_nest("coop") and chicken.product==3 and duck.product==2,"full egg stack retains all nest products atomically")
	Inventory.items.erase("egg")
	check(Livestock.collect_nest("coop") and Inventory.count("egg")==3 and Inventory.count("duck_egg")==2,"nest delivers both egg types to real inventory")
	check(not Livestock.collect_nest("coop") and Inventory.count("duck_egg")==2,"repeat nest click yields nothing")
	check(Catalog.sell_price("duck_egg")==28 and Catalog.is_item("salted_duck_egg"),"duck egg and preserved product registered once")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"mixed poultry state is a valid whole save")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and Livestock.animals_at("coop")[1].species=="duck","duck age feed identity and products survive JSON restore")
	Fixture.stock()
	var jar: String=await Fixture.install(self,game,"station_pickle_jar")
	check(jar!="" and await Fixture.approach(self,game,jar),"real pickling jar installed and reachable")
	Inventory.items.duck_egg=2
	check(Workshop.start(jar,"salted_duck_egg") and Inventory.count("duck_egg")==0,"duck eggs enter existing processing engine")
	var job: Dictionary=Workshop.state.jobs[jar]
	for i in range(2):
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(3)
	await Fixture.approach(self,game,jar)
	check(Workshop.claim(jar,int(job.id)) and Inventory.count("salted_duck_egg")==1,"two game days finish real salted duck egg")
	check(not Workshop.claim(jar,int(job.id)),"salted egg collection once")
	GameClock.minutes=600
	game.change_location("farm",Livestock.site_point("coop")+Vector2(0,32));await frames(4)
	check(Livestock.graze("coop"),"open sunny poultry grazing")
	GameClock.running=true
	for tick in range(1201):
		if tick%60==0:
			var row: Dictionary={"frame":tick,"animals":{}}
			for node in get_tree().get_nodes_in_group("livestock_animals"):
				row.animals[node.animal_id]={"position":[node.position.x,node.position.y],"behavior":node.behavior,"distance":node.total_distance,"direction":node.direction}
			motions.append(row)
		if tick in [0,240,480,900,1200] and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://docs/ranch082/poultry-motion-%04d.png" % tick)
		await frames(1)
	GameClock.running=false
	for node in get_tree().get_nodes_in_group("livestock_animals"):
		check(node.total_distance>80,"real visible bird travel exceeds tiny old wiggle "+node.species_id)
		check(node.goals_chosen>1,"bird selects multiple legal routes "+node.species_id)
		check(Livestock.activity_bounds(Livestock.animal(node.animal_id),true).has_point(node.global_position),"bird remains inside original stageB envelope")
	var file:=FileAccess.open("res://docs/ranch082/poultry-motion.json",FileAccess.WRITE);file.store_string(JSON.stringify({"motion":motions,"daily_eggs":eggs},"  "));file.close()
	print("RANCH082 POULTRY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
