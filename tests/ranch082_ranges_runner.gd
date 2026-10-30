extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var report: Dictionary={"areas":{},"motion":{}}
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true))
	Inventory.items={"wood":999,"stone":999,"hay":999,"copper_bar":99,"iron_bar":99};Inventory.coins=100000
	for site in RanchLayout.ENABLED: await verify_range(site)
	var file:=FileAccess.open("res://docs/ranch082/ranges-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RANCH082 RANGES RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func verify_range(site: String) -> void:
	var area:=RanchLayout.area(site)
	check(not WorldTravel.change(game,area),"unbuilt pasture has no premature entrance "+site)
	game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(4)
	check(Livestock.build(site),"build legacy barn without covering farm "+site)
	Livestock.upgrade(site);Livestock.upgrade(site)
	for i in range(6): check(Livestock.buy_animal(site,"duck" if site=="coop" and i%2==1 else ""),"capacity6 legal purchase "+site+str(i))
	var gate: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("livestock_id")=="pasture_gate:"+site and not node.get("returning"): gate=node;break
	check(gate!=null,"actual farm fence gate exists "+site)
	if gate==null: return
	game.player.position=Livestock.site_point(site)+Vector2(40,96);game.camera_rig.follow_now();await frames(4)
	Touch.tap(self,game,gate.global_position+Vector2(0,-12));await Touch.finish(self,game,700)
	check(GameState.location==area,"native tap walks to gate and enters actual pasture "+site)
	if GameState.location!=area: return
	await frames(5)
	var map: RanchMap=game.mine_maps[area]
	var required: int=int(RanchLayout.catalog().baseline_cells[site])*int(RanchLayout.definition(site).minimum_multiplier)
	check(map.reachable.size()>=required,"connected animal cells meet multiplier "+site)
	game.auto_move.navigation.rebuild()
	var physically_clear: int=0;var disconnected: int=0
	for cell in map.reachable:
		if not game.auto_move.navigation.static_solid.has(cell): physically_clear+=1
		else: disconnected+=1
	check(disconnected==0 and physically_clear>=required,"area count excludes real obstacles and agrees with engine probes "+site)
	var every_home:=true
	for i in range(6):
		var cell:=Vector2i((RanchLayout.home(site,i)/32).floor())
		if not map.reachable.has(cell): every_home=false
	check(every_home,"all six indoor stalls connect to grazing ground "+site)
	report.areas[site]={"old_cells":35,"new_connected_cells":map.reachable.size(),"engine_clear_cells":physically_clear,"multiplier":float(physically_clear)/35,"grid":[map.grid.region.size.x,map.grid.region.size.y]}
	game.auto_move.request_target({"kind":"ground","point":RanchLayout.service(site)+Vector2(16,64)})
	await Touch.finish(self,game,1200)
	check(game.player.position.distance_to(RanchLayout.service(site)+Vector2(16,64))<4,"player walks across actual pasture "+site)
	GameClock.minutes=600
	game.player.position=RanchLayout.service(site)+Vector2(0,28)
	check(Livestock.graze(site),"same barn management opens sunny grazing "+site)
	for entry in Livestock.animals_at(site): entry.age=Livestock.data.species[entry.species].growth_days
	Livestock.changed.emit();await frames(4)
	var samples: Array=[];var seen: Dictionary={};GameClock.running=true
	for tick in range(1801):
		if tick%30==0:
			var row: Dictionary={"frame":tick,"animals":{}}
			for entry in Livestock.animals_at(site):
				var node: CharacterBody2D=animal_node(str(entry.id));seen[node.behavior]=true
				row.animals[entry.id]={"position":[node.position.x,node.position.y],"behavior":node.behavior,"distance":node.total_distance}
			samples.append(row)
			if DisplayServer.get_name()!="headless" and tick<=600:
				await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://docs/ranch082/"+site+"-walk-%04d.png" % tick)
		await frames(1)
	GameClock.running=false
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		for point in RanchLayout.furniture(site).values():
			var screen: Vector2=game.player.get_canvas_transform()*(point+Vector2(0,-10))
			if Rect2(Vector2.ZERO,image.get_size()).has_point(screen): check(image.get_pixelv(Vector2i(screen))!=Color.WHITE,"rendered furniture retains real texture rather than white RID rectangle "+site)
	for entry in Livestock.animals_at(site):
		var node: CharacterBody2D=animal_node(str(entry.id))
		check(node.total_distance>60,"every animal travels real world distance "+entry.id)
		check(RanchLayout.point_legal(site,node.global_position),"animal stays inside physical fence and clear terrain "+entry.id)
	check(seen.has(1) and seen.has(2),"observed actual walking and grazing states "+site)
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"moving pasture state validates whole save "+site)
	report.motion[site]=samples
	var first: Dictionary=Livestock.animals_at(site)[0];var node: CharacterBody2D=animal_node(str(first.id))
	game.player.position=node.position+Vector2(0,45);game.camera_rig.follow_now();await frames(4)
	GameClock.running=true
	Touch.tap(self,game,node.position+Vector2(0,-14));await Touch.finish(self,game,600)
	check(game.hud.livestock_panel.visible and game.hud.livestock_panel.context=="animal:"+first.id,"moving animal tap retains identity and approaches "+site)
	game.hud.close_active_panel();GameClock.running=false
	var save:=FarmSaveStore.snapshot(game);var position: Vector2=node.position
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))),"range location and all herd states survive JSON save "+site)
	await frames(4)
	check(GameState.location==area and animal_node(str(first.id)).position.distance_to(position)<.1,"restore actual body positions in same pasture "+site)
	GameClock.minutes=1080;GameClock.changed.emit();GameClock.running=true
	var returned:=false
	for tick in range(6001):
		if tick%60==0:
			returned=true
			for entry in Livestock.animals_at(site):
				if not RanchLayout.indoor(site).has_point(Livestock.animal_point(entry)): returned=false
			if returned: break
		await frames(1)
	GameClock.running=false
	check(returned and not Livestock.is_grazing(site),"entire herd walks home at evening without teleport "+site)
	if DisplayServer.get_name()!="headless":
		game.player.position=RanchLayout.service(site)+Vector2(0,40);game.camera_rig.follow_now();await frames(4);await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/ranch082/"+site+"-returned.png")
	game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(4)
	check(Livestock.animals_at(site).size()==6,"travel never duplicates animals "+site)
func animal_node(id: String) -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group("livestock_animals"):
		if node.animal_id==id: return node
	return null
