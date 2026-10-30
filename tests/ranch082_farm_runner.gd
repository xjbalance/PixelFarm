extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var report: Dictionary={"zones":{},"clearing":{},"navigation":{}}
var seed: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));seed=FarmSaveStore.snapshot(game)
	Inventory.coins=100000;Inventory.items={"wood":200,"stone":200,"hay":100,"copper_bar":50,"iron_bar":50,"wheat_seed":100,"wheat":40}
	check(game.world.ground.get_used_rect()==Rect2i(0,0,96,64) and game.world.ground.get_used_cells().size()==6144,"real farm TileMap expands to96x64 /6144 cells")
	check(game.farm.BOUNDS==FarmLayoutCatalog.GRID and WorldTravel.region("farm")==FarmLayoutCatalog.GRID,"farming and actual navigation share expanded bounds")
	check(game.camera_rig.map_rect()==FarmLayoutCatalog.WORLD and FarmAtlasData.bounds("farm")==FarmLayoutCatalog.WORLD,"camera and parchment map use full expanded world")
	check(FarmLayout.point("home")==Vector2(656,410),"original home coordinate unchanged")
	await frames(4);game.auto_move.navigation.rebuild()
	var old_clear: int=0;var all_clear: int=0
	for y in range(64):
		for x in range(96):
			if game.auto_move.navigation.static_solid.has(Vector2i(x,y)): continue
			all_clear+=1
			if x<48 and y<32: old_clear+=1
	check(all_clear>=old_clear*4,"actual initial unobstructed area reaches at least4x original")
	report.area={"old_dimensions":[48,32],"new_dimensions":[96,64],"old_total_cells":1536,"new_total_cells":6144,"old_initial_clear_cells":old_clear,"new_initial_clear_cells":all_clear,"clear_area_multiplier":float(all_clear)/old_clear}
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"expanded initial farm is a valid whole save")
	if DisplayServer.get_name()!="headless": await panorama("after-farm-initial")
	await clearing()
	await agriculture()
	await construction()
	await permanence()
	if DisplayServer.get_name()!="headless":
		await showcase()
		await seasons()
	var path: String="res://docs/ranch082/farm-"+("window" if DisplayServer.get_name()!="headless" else "headless")+"-results.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	if DisplayServer.get_name()!="headless":
		file=FileAccess.open("res://docs/ranch082/farm-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RANCH082 FARM RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func screenshot(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(5);await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://docs/ranch082/"+name_text+".png")
func panorama(name_text: String) -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(3072,2048);viewport.world_2d=game.player.get_world_2d();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	game.add_child(viewport);var camera:=Camera2D.new();camera.position=Vector2(1536,1024);viewport.add_child(camera);camera.make_current()
	await frames(4);await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png("res://docs/ranch082/"+name_text+".png")
	viewport.queue_free();await frames(3)
func clearing() -> void:
	var field: Node2D=game.resource_world.fields.farm
	var ids: Array[String]=["tree_5_8","rock_11_19","exp082_tree_50_53","exp082_stump_55_6","exp082_rock_52_38","exp082_bush_48_35","exp082_weed_48_49","exp082_boulder_94_39","brush_original_0"]
	for id in ids:
		var object: StaticBody2D=field.objects[id];var definition: Dictionary=FarmResourceCatalog.TYPES[object.kind]
		var old_hp: int=int(field.state[id].hp);var old_items:=Inventory.items.duplicate(true);var energy: int=GameState.stamina
		check(not field.hit(id,"water") and int(field.state[id].hp)==old_hp and Inventory.items==old_items and GameState.stamina==energy,"wrong tool never damages or spends "+id)
		if object.kind=="boulder":
			check(not field.hit(id,"pickaxe") and int(field.state[id].hp)==old_hp,"large rock requires existing tool upgrade")
			check(FarmProgress.build_upgrade("toolrack"),"existing real paid tool upgrade enables large rock removal")
		await frames(3);game.auto_move.navigation.rebuild()
		var path: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"resource","object":object,"point":object.global_position})
		check(not path.is_empty(),"resource has legal approach point "+id)
		if path.is_empty(): continue
		game.player.position=path[-1];game.camera_rig.follow_now();await frames(4)
		if id=="exp082_tree_50_53": await screenshot("clearing-before")
		var before: int=Inventory.count(str(definition.item));var hits: int=0
		while int(field.state[id].hp)>0 and hits<8:
			GameState.stamina=100;GameState.select_tool(GameState.tools.find(str(definition.tool)))
			Touch.tap(self,game,object.global_position+Vector2(0,-12));await Touch.finish(self,game,600);await frames(20)
			check(GameState.stamina==100-Kitchen.energy_cost(int(definition.energy)),"native resource action spends exact stamina "+id)
			hits+=1
		check(int(field.state[id].hp)==0 and Inventory.count(str(definition.item))==before+int(definition.amount),"clear once and award real material exactly once "+id)
		check(not field.hit(id,str(definition.tool)) and Inventory.count(str(definition.item))==before+int(definition.amount),"repeat resource hit cannot duplicate drops "+id)
		await frames(4)
		check(object.collider.disabled and not object.sprite.visible,"clear releases physical shape and sprite "+id)
		report.clearing[id]={"hits":hits,"item":definition.item,"quantity":definition.amount,"ready_day":field.state[id].ready_day,"position":[object.position.x,object.position.y]}
		if id=="exp082_tree_50_53": await screenshot("clearing-after")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"all cleared resource records save correctly")
func agriculture() -> void:
	var cells: Array[Vector2i]=[Vector2i(56,20),Vector2i(70,25),Vector2i(20,50),Vector2i(68,52),Vector2i(93,62),Vector2i(50,53)]
	var plants: int=int(Xiaojing.state.plants)
	for cell in cells:
		var point:=Vector2(cell)*32+Vector2(16,16)
		game.camera_rig.mode=game.camera_rig.Mode.FREE_LOOK;game.camera_rig.view_center=point;game.camera_rig.apply_camera();await frames(3)
		GameState.manual_tool=false
		Touch.tap(self,game,point);await Touch.finish(self,game,5000)
		check(game.player.position.distance_to(point)<2,"native long click reaches new farm land "+str(cell))
		GameState.stamina=100;GameState.select_tool(0);Touch.tap(self,game,point);await Touch.finish(self,game,600)
		check(not game.farm.plot_at(cell).is_empty(),"new / cleared land can really be tilled "+str(cell))
		var seeds: int=Inventory.count("wheat_seed");var serial: int=int(Xiaojing.state.plants)
		GameState.select_tool(5);Touch.tap(self,game,point);await Touch.finish(self,game,600)
		check(game.farm.plot_at(cell).get("crop","")=="wheat" and Inventory.count("wheat_seed")==seeds-1 and Xiaojing.state.plants==serial+1,"new land sow spends1 seed and counts520 once "+str(cell))
		check(not game.farm.use_tool(cell,"wheat_seed") and Xiaojing.state.plants==serial+1,"duplicate sow on occupied new plot refused "+str(cell))
		GameState.select_tool(1);Touch.tap(self,game,point);await Touch.finish(self,game,600)
		check(game.farm.plot_at(cell).watered,"new land watering uses existing farming action "+str(cell))
	check(Xiaojing.state.plants==plants+cells.size(),"all expansion sow actions count once")
	for i in range(Catalog.crops.wheat.growth_days):
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"new plots grow only through existing daily clock")
		await frames(3)
		if i+1<Catalog.crops.wheat.growth_days:
			for cell in cells:
				GameState.stamina=100;check(game.farm.use_tool(cell,"water"),"normal daily watering of expansion plot")
	for cell in cells: check(game.farm.is_mature(game.farm.plot_at(cell)),"new plot reaches correct mature stage "+str(cell))
	game.player.position=Vector2(56,20)*32+Vector2(16,80);game.camera_rig.follow_now();await screenshot("expanded-cultivation")
	game.player.position=Vector2(50,53)*32+Vector2(16,80);game.camera_rig.follow_now();await screenshot("cleared-land-farming")
	var wheat: int=Inventory.count("wheat")
	for cell in cells:
		GameState.stamina=100;check(game.farm.use_tool(cell,"hand"),"real harvest from expansion plot "+str(cell))
	check(Inventory.count("wheat")==wheat+cells.size()*Catalog.crops.wheat.harvest_quantity,"expansion harvest yields original quantities")
	report.plots=game.farm.plots.duplicate(true)
func construction() -> void:
	await frames(24)
	game.player.position=Vector2(52,39)*32+Vector2(16,16);game.camera_rig.follow_now();await frames(4)
	check(game.territory_editor.open(),"existing DIY opens in expanded region");await frames(4)
	var plan:=Territory.plan_place("farm","station_mill",Vector2i(52,38))
	var installed: bool=plan.valid and Territory.apply_plan(plan)
	check(installed,"existing mill can be built on cleared expanded rock land");await frames(4)
	var mill: String=str(Territory.state.objects[-1].id) if installed else ""
	var lamp:=Territory.plan_place("farm","lamp",Vector2i(54,38));check(lamp.valid and Territory.apply_plan(lamp),"expanded land accepts legal decoration with collision");await frames(4)
	var home_plan:=FarmLayout.plan_move("fixture","home",Vector2i(70,22))
	check(home_plan.valid and FarmLayout.apply_plan(home_plan),"player explicitly moves existing home to expanded land")
	game.territory_editor.cancel();await frames(6)
	if mill!="":
		var node: Node2D=game.territory_world.objects[mill];game.auto_move.navigation.rebuild()
		var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":node,"point":node.global_position})
		check(not route.is_empty(),"new workshop has real reachable operating point")
		if not route.is_empty(): game.player.position=route[-1]
		check(Workshop.start(mill,"mill_flour"),"new land mill uses original production engine")
	game.camera_rig.follow_now();await screenshot("expanded-workshop")
	game.player.position=FarmLayout.point("home")+Vector2(0,32);game.camera_rig.follow_now();await screenshot("cleared-land-building")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"new region plots roads buildings and jobs survive JSON save")
	check(FarmLayout.cell("fixture","home")==Vector2i(70,22) and game.farm.plots==report.plots,"new construction positions and sparse crop records remain exact")
	FarmLayout.restore(seed.farm_layout);await frames(5)
func permanence() -> void:
	var field: Node2D=game.resource_world.fields.farm
	var cleared: Dictionary={}
	for id in report.clearing: cleared[id]=field.state[id].duplicate(true)
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"all permanent clearing restores through full save")
	await frames(4)
	game.change_location("home");game.change_location("farm");await frames(4)
	for id in cleared: check(field.state[id].hp==0 and field.state[id].ready_day==0,"travel and load do not revive "+str(id))
	for day in range(8):
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"clearing remains permanent over daily settlement")
		await frames(2)
	for id in cleared: check(field.state[id].hp==0,"eight days do not regenerate farm resource "+str(id))
	var wild: Node2D=game.resource_world.fields.mist_forest;var wild_id: String=str(wild.state.keys()[0])
	wild.state[wild_id]={"hp":0,"ready_day":GameClock.day};wild.objects[wild_id].refresh();game.change_location("home");await frames(3);wild.advance_day()
	check(wild.state[wild_id].hp>0,"forest resource keeps original regeneration behavior")
	game.change_location("farm",Vector2(52,39)*32+Vector2(16,16));await frames(4);game.camera_rig.follow_now();await screenshot("permanent-clearing-reloaded")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"expanded settled world remains valid")
func seasons() -> void:
	for day in [1,29,57,85]:
		GameClock.day=day;GameClock.minutes=600;Calendar.restore(Calendar.snapshot());await frames(5)
		await panorama("farm-season-"+Calendar.SEASON_IDS[Calendar.season()])
		for id in report.clearing: check(game.resource_world.fields.farm.state[id].hp==0,"season never revives cleared farm land")

func showcase() -> void:
	# Isolated screenshot capital; all plots still use real seed, tool and daily APIs.
	var field: Node2D=game.resource_world.fields.farm
	for id in ["exp082_tree_51_29","exp082_weed_51_25"]:
		while field.state[id].hp>0:
			GameState.stamina=100;field.hit(id,str(FarmResourceCatalog.TYPES[field.objects[id].kind].tool))
	await frames(4) # Let deferred physics shape removal synchronize before direct batch hoe calls.
	Inventory.items.wheat_seed=200;Inventory.items.carrot_seed=200;Inventory.items.potato_seed=200
	var cells: Array[Vector2i]=[];var longest: int=0
	for y in range(17,28):
		for x in range(50,74):
			if x in [62,63]: continue
			var cell:=Vector2i(x,y);var crop: String="wheat" if y<20 else "carrot" if y<24 else "potato"
			GameState.stamina=100
			if game.farm.plot_at(cell).is_empty(): check(game.farm.use_tool(cell,"hoe"),"large cultivation specimen genuinely tills new cell")
			check(game.farm.use_tool(cell,crop+"_seed"),"large cultivation specimen genuinely consumes seed")
			game.farm.use_tool(cell,"water");cells.append(cell);longest=maxi(longest,Catalog.crops[crop].growth_days)
	for day in range(longest):
		for cell in cells:
			GameState.stamina=100
			if not game.farm.plot_at(cell).watered: game.farm.use_tool(cell,"water")
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"large cultivation specimen advances original daily growth");await frames(3)
	var mature_count: int=0
	for cell in cells:
		if game.farm.is_mature(game.farm.plot_at(cell)): mature_count+=1
	check(mature_count==242,"242 new-region wheat carrot and potato plots genuinely reach maturity")
	report.showcase={"plots":242,"crops":["wheat","carrot","potato"],"normal_tool_and_seed_calls":true,"real_daily_growth":true,"isolated_test_capital":true}
	GameClock.minutes=720;GameClock.changed.emit();game.player.position=Vector2(62,22)*32+Vector2(16,16);game.camera_rig.follow_now();await screenshot("expanded-cultivation")
