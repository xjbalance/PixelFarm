extends "res://tests/runner.gd"
## Actual animal bodies, fixed 60Hz simulation and measured wall intervals. No mobile FPS claim.
var report: Dictionary={"android_device_tested":false,"actual_window":false,"fixed_physics_hz":60,"simulated_seconds":500,"samples":[]}
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.items={"wood":999,"stone":999,"copper_bar":99,"iron_bar":99,"hay":999};Inventory.coins=100000;GameClock.minutes=600
	for site in RanchLayout.ENABLED:
		game.change_location("farm",Livestock.site_point(site)+Vector2(0,32));await frames(4)
		check(Livestock.build(site) and Livestock.upgrade(site) and Livestock.upgrade(site),"stress uses paid maximum original capacity "+site)
		for i in range(6): check(Livestock.buy_animal(site,"duck" if site=="coop" and i%2==1 else ""),"real stress animal purchase "+site+str(i))
		check(Livestock.graze(site),"stress grazing observes original sunny-time rule "+site)
	for entry in Livestock.state.animals: entry.age=Livestock.data.species[entry.species].growth_days
	Livestock.changed.emit()
	for site in RanchLayout.ENABLED:
		game.change_location(RanchLayout.area(site),RanchLayout.service(site)+Vector2(0,64));await frames(12)
		await reachability(site)
	game.change_location("pasture_coop",RanchLayout.service("coop")+Vector2(0,64));await frames(12)
	var baseline_nodes: int=game.get_tree().get_node_count();var baseline_memory: int=OS.get_static_memory_usage();var peak_memory: int=baseline_memory;var peak_nodes: int=baseline_nodes
	var previous: Dictionary={};var start_distance: Dictionary={};var max_step: float=0;var all_legal: bool=true;var hidden_moved: bool=false
	for entry in Livestock.state.animals: previous[entry.id]=Livestock.animal_point(entry);start_distance[entry.id]=animal_node(str(entry.id)).total_distance
	var started: int=Time.get_ticks_usec();var previous_wall: int=started;var day: int=GameClock.day
	GameClock.running=true
	for tick in range(30000):
		if tick>0 and tick%3000==0:
			var site: String=RanchLayout.ENABLED[(tick/3000)%3]
			game.change_location(RanchLayout.area(site),RanchLayout.service(site)+Vector2(0,64))
		for entry in Livestock.state.animals:
			var node: Node2D=animal_node(str(entry.id));var point:=Livestock.animal_point(entry)
			var step: float=point.distance_to(previous[entry.id]);max_step=maxf(max_step,step)
			if not node.is_visible_in_tree() and tick%3000!=0 and step>.001: hidden_moved=true
			previous[entry.id]=point
			if not RanchLayout.point_legal(str(entry.site),point): all_legal=false

		if tick%300==0:
			peak_memory=maxi(peak_memory,OS.get_static_memory_usage());peak_nodes=maxi(peak_nodes,game.get_tree().get_node_count())
			var now: int=Time.get_ticks_usec()
			if tick>0: report.samples.append({"physics_frame":tick,"wall_ms_per_step":float(now-previous_wall)/300000.0,"map":GameState.location,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
			previous_wall=now
		await frames(1)
	GameClock.running=false
	check(all_legal and max_step<.8,"30000 actual physics steps never cross fence / wall or teleport")
	check(peak_nodes<=baseline_nodes+4,"long simulation does not accumulate AI timers or animal nodes")
	check(peak_memory-baseline_memory<33554432,"measured static memory remains bounded through real map / day changes")
	var active: int=0
	for entry in Livestock.state.animals:
		var node: Node2D=animal_node(str(entry.id))
		check(node.total_distance-float(start_distance[entry.id])>100,"every original and duck animal actually moves over long simulation "+str(entry.id))
		if node.is_visible_in_tree(): active+=1
	check(not hidden_moved,"hidden pastures retain stable positions without offscreen per-frame AI")
	check(active==6 and Livestock.state.animals.size()==18,"six visible animals simulate while other maps retain exactly one herd")
	check(GameClock.day==day+1,"long run includes one real midnight daily settlement")
	var before:=Livestock.snapshot();Livestock.settle_day();GameClock.day_advanced.emit()
	check(Livestock.snapshot()==before,"long-run midnight cannot settle products again")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"long-running actual herd and production dates form a valid save")
	report.merge({"baseline_nodes":baseline_nodes,"peak_nodes":peak_nodes,"baseline_static_bytes":baseline_memory,"peak_static_bytes":peak_memory,"wall_seconds":float(Time.get_ticks_usec()-started)/1000000.0,"max_physics_step_pixels":max_step,"herd_count":18,"visible_simulated_animals":active,"scene_changes":10,"start_day":day,"end_day":GameClock.day,"note":"Fixed simulation time is distinct from measured desktop wall performance; no Android hardware was used."})
	game.change_location("farm",WorldTravel.entry("farm"));await frames(4)
	var nav: WorldNavigation=game.auto_move.navigation;var t: int=Time.get_ticks_usec();nav.rebuild();var build_ms: float=float(Time.get_ticks_usec()-t)/1000.0
	var target:=Vector2(93,62)*32+Vector2(16,16);t=Time.get_ticks_usec();var route:=nav.path_to({"kind":"ground","point":target});var route_ms: float=float(Time.get_ticks_usec()-t)/1000.0
	var safe: bool=not route.is_empty()
	for i in range(1,route.size()):
		if not nav.clear_segment(route[i-1],route[i]): safe=false
	check(safe and route.size()>90,"expanded farm long path is physically clear across original border")
	report.navigation={"grid_cells":6144,"rebuild_ms":build_ms,"path_ms":route_ms,"path_cells":route.size(),"all_segments_clear":safe}
	if DisplayServer.get_name()!="headless":
		report.actual_window=true;game.change_location("pasture_barn",RanchLayout.service("barn")+Vector2(0,48));await frames(5);await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/ranch082/stress-actual-herd.png")
	var file:=FileAccess.open("res://docs/ranch082/performance-"+("window" if DisplayServer.get_name()!="headless" else "headless")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RANCH082 STRESS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func animal_node(id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("livestock_animals"):
		if node.animal_id==id: return node
	return null
func reachability(site: String) -> void:
	var map: RanchMap=game.mine_maps[RanchLayout.area(site)];var grid: AStarGrid2D=map.animal_grid
	var start:=Vector2i((RanchLayout.entry(site)/16).floor());var open: Array[Vector2i]=[start];var seen: Dictionary={start:true};var cursor: int=0
	while cursor<open.size():
		var cell: Vector2i=open[cursor];cursor+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var at: Vector2i=cell+offset
			if grid.region.has_point(at) and not grid.is_point_solid(at) and not seen.has(at): seen[at]=true;open.append(at)
	var unconnected: int=0
	for coarse in map.reachable:
		var connected: bool=false
		for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
			if seen.has(coarse*2+offset): connected=true;break
		if not connected: unconnected+=1
	check(unconnected==0,"every counted32px animal cell connects to actual16px AI routing component "+site)
	report[site]={"coarse_connected_cells":map.reachable.size(),"fine_connected_cells":seen.size(),"unconnected_coarse_cells":unconnected}
