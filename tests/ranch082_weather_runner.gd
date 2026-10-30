extends "res://tests/runner.gd"
var report: Array=[]
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.items={"wood":999,"stone":999,"hay":999};Inventory.coins=100000
	for site in RanchLayout.ENABLED:
		game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(4)
		Livestock.build(site);Livestock.buy_animal(site);Livestock.buy_animal(site,"duck" if site=="coop" else "")
		game.change_location(RanchLayout.area(site));await frames(4)
		GameClock.day=4;GameClock.minutes=600;Calendar.restore(Calendar.snapshot());GameWeather.enabled=false
		game.player.position=RanchLayout.service(site)+Vector2(0,32)
		check(Livestock.graze(site),"sunny period opens pasture before rain transition "+site)
		await scatter(site)
		GameClock.running=true;await frames(120);GameClock.running=false
		GameWeather.enabled=true;GameWeather.changed.emit()
		check(GameWeather.is_rainy() and not Livestock.is_grazing(site),"real calendar rain closes grazing "+site)
		await return_check(site,"rain")
		GameClock.day=85;GameClock.minutes=600;Calendar.restore(Calendar.snapshot());GameWeather.changed.emit()
		check(Calendar.season()==3 and not Livestock.can_graze(site),"winter cannot replace daily feed with free grazing "+site)
		await scatter(site);await return_check(site,"winter")
		var node: Node2D=animal_node(str(Livestock.animals_at(site)[0].id));var before: float=node.total_distance
		GameClock.running=true;await frames(1800);GameClock.running=false
		check(node.total_distance>before+8,"sheltered animal retains light visible indoor activity "+site)
		var map: RanchMap=game.mine_maps[RanchLayout.area(site)]
		check(map.route_requests<2000,"bounded goal refresh reuses one static grid "+site)
	var file:=FileAccess.open("res://docs/ranch082/weather-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RANCH082 WEATHER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func scatter(site: String) -> void:
	var entries:=Livestock.animals_at(site)
	for i in range(entries.size()):
		var point:=Vector2(RanchLayout.world_rect(site).size.x/2-64+i*128,400)
		entries[i].pasture_position=[point.x,point.y]
	Livestock.changed.emit();await frames(4)
func animal_node(id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("livestock_animals"):
		if node.animal_id==id: return node
	return null
func return_check(site: String, reason: String) -> void:
	var entries:=Livestock.animals_at(site);var before: Dictionary={};var previous: Dictionary={};var max_step: float=0;var elapsed: int=0
	for entry in entries: before[entry.id]=entry.pasture_position.duplicate();previous[entry.id]=Livestock.animal_point(entry)
	GameClock.running=true;var returned:=false
	for tick in range(3601):
		elapsed=tick
		for entry in entries:
			var point:=Livestock.animal_point(entry);max_step=maxf(max_step,point.distance_to(previous[entry.id]));previous[entry.id]=point
		if tick%60==0:
			returned=true
			for entry in entries:
				if not RanchLayout.indoor(site).has_point(Livestock.animal_point(entry)): returned=false
			if returned: break
		await frames(1)
	GameClock.running=false
	check(returned,"actual herd walks back to shelter in "+reason+" "+site)
	check(max_step<.8,"weather return never teleports "+reason+" "+site)
	var after: Dictionary={}
	for entry in entries: after[entry.id]=entry.pasture_position.duplicate()
	report.append({"site":site,"reason":reason,"weather":GameWeather.weather_id(),"before":before,"after":after,"frames":elapsed,"maximum_step_pixels":max_step})
