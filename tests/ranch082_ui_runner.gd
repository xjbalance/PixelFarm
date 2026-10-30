extends "res://tests/ui05_layout_runner.gd"
## Real controls, safe rectangles, native ScreenTouch, scene mapping and product feedback.
var mature: Dictionary
var duck_id: String=""
var density: bool=false
func run() -> void:
	density="--dpi480" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	if density: UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	else: UIMetrics.screen_provider=Callable()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/ranch082/legacy081-v29.json"))
	check(FarmSaveStore.restore(game,legacy),"UI specimen starts from actual migrated old farm");await frames(5)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	game.change_location("farm",Livestock.site_point("coop")+Vector2(0,32));await frames(4)
	check(Livestock.buy_animal("coop","duck"),"UI specimen uses a purchased legal duck")
	duck_id=str(Livestock.state.animals[-1].id)
	for day in range(7):
		var duck:=Livestock.animal(duck_id)
		game.change_location("pasture_coop",Livestock.animal_point(duck)+Vector2(0,32));await frames(3)
		check(Livestock.feed(duck_id) and Livestock.pet(duck_id),"real daily duck care before visual acceptance")
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"real day change produces duck eggs");await frames(3)
	check(Livestock.animal(duck_id).product==2,"UI duck eggs actually produced by two eligible cycles")
	GameClock.minutes=720;GameClock.changed.emit()
	mature=FarmSaveStore.snapshot(game)
	var resolutions: Array=[Vector2i(1280,720)] if density else [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]
	for resolution in resolutions: await one_resolution(resolution)
	UIMetrics.screen_provider=Callable()
	var path: String="res://docs/ranch082/ui-"+("dpi480" if density else "matrix")+"-"+("window" if DisplayServer.get_name()!="headless" else "headless")+"-results.json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"samples":samples,"issues":issues,"actual_window":DisplayServer.get_name()!="headless","android_device_tested":false},"  "));file.close()
	if DisplayServer.get_name()!="headless":
		file=FileAccess.open("res://docs/ranch082/ui-"+("dpi480" if density else "matrix")+"-results.json",FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string(path));file.close()
	print("RANCH082 UI RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ranch082/"+label+".png")
func one_resolution(resolution: Vector2i) -> void:
	get_window().size=resolution;await frames(8)
	check(FarmSaveStore.restore(game,mature),"UI matrix restores production specimen");await frames(5)
	prefix="ranch082-%dx%d%s" % [resolution.x,resolution.y,"-dpi480" if density else ""];configuration=prefix
	var visible: Vector2=get_viewport().get_visible_rect().size
	game.hud.apply_safe_area(Rect2(64,0,visible.x-128,visible.y) if density else Rect2(Vector2.ZERO,visible),visible);await frames(5)
	await egg_collection()
	await animal_product("barn","milk")
	await animal_product("fold","wool")
	await atlas()
	await joystick()
func egg_collection() -> void:
	game.change_location("farm",Livestock.gate_point("coop")+Vector2(0,48));await frames(5);game.camera_rig.follow_now()
	await shot(prefix+"-barn-gates")
	game.change_location("pasture_coop",Livestock.nest_point("coop","pasture_coop")+Vector2(0,64));await frames(5)
	var nest: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("livestock_id")=="nest:coop" and node.is_visible_in_tree(): nest=node;break
	check(nest!=null,"actual nest is visible in rear poultry pasture")
	if nest==null: return
	var egg: int=Inventory.count("egg");var duck: int=Inventory.count("duck_egg")
	var calls: int=game.auto_move.execution_count
	GameClock.running=true
	Touch.tap(self,game,nest.position+Vector2(0,-12));await Touch.finish(self,game,600)
	GameClock.running=false
	var panel: PanelContainer=game.hud.livestock_panel
	check(panel.visible and panel.context=="nest:coop" and game.auto_move.execution_count==calls+1,"native nest tap approaches once and opens egg stock")
	if not panel.visible: return
	await shot(prefix+"-egg-stock");await audit(panel,"鸡窝收取")
	var position: Vector2=game.player.position;var camera: Vector2=game.camera_rig.view_center
	Touch.finger(self,panel.get_global_rect().position+Vector2(18,18),true,871);Touch.finger(self,panel.get_global_rect().position+Vector2(18,18),false,871);await frames(3)
	check(game.player.position==position and game.camera_rig.view_center==camera and game.auto_move.target.is_empty(),"nest UI neither moves player nor pans world camera")
	var sound: Node=game.get_node("Audio");var channel: int=sound.next_player;sound.muted=false
	await tap(find_button(panel,"收取鸡窝里的蛋"))
	check(sound.next_player==(channel+1)%sound.players.size() and sound.players[channel].playing,"actual nest collection starts exactly one existing harvest sound stream")
	sound.muted=true
	check(Inventory.count("egg")==egg+6 and Inventory.count("duck_egg")==duck+2,"native collect delivers actual chicken6 and duck2 eggs")
	check(not Livestock.collect_nest("coop"),"stale second collect cannot duplicate eggs")
	await shot(prefix+"-egg-collected");panel.close_panel();await shot(prefix+"-nest-feedback")
	check(nest.art!=nest.empty_art,"empty and ready nest use distinct real pixel resources")
func animal_product(site: String, item: String) -> void:
	var entry: Dictionary=Livestock.animals_at(site)[0]
	game.change_location(RanchLayout.area(site),Livestock.animal_point(entry)+Vector2(0,80));await frames(5)
	GameClock.running=true;Touch.tap(self,game,Livestock.animal_point(entry)+Vector2(0,-14));await Touch.finish(self,game,600);GameClock.running=false
	var panel: PanelContainer=game.hud.livestock_panel
	check(panel.visible and panel.context=="animal:"+str(entry.id),"native tap opens correct moving "+site+" animal")
	if not panel.visible: return
	await shot(prefix+"-"+item+"-care");await audit(panel,site+"照料")
	var hay: int=Inventory.count("hay");var amount: int=int(Livestock.data.species[entry.species].feed)
	await tap(find_button(panel,"投喂"));check(Inventory.count("hay")==hay-amount,"animal feed uses existing daily hay quantity "+site)
	await tap(find_button(panel,"抚摸"));check(entry.pet_day==GameClock.day,"native pet updates same animal identity "+site)
	var quantity: int=int(entry.product);var before: int=Inventory.count(item)
	await tap(find_button(panel,"收集"));check(panel.pending.is_valid(),"product collection has deliberate confirmation "+item)
	await shot(prefix+"-"+item+"-confirm");await tap(find_button(panel,"确认"))
	check(quantity>0 and entry.product==0 and Inventory.count(item)==before+quantity,"actual existing animal product collected without yield change "+item)
	panel.close_panel()
func atlas() -> void:
	game.change_location("farm",Vector2(76,50)*32+Vector2(16,16));await frames(5)
	var state:=FarmSaveStore.snapshot(game);var panel: PanelContainer=game.hud.atlas_panel
	check(panel.open_panel(),"parchment map opens in expanded farm");panel.show_current();await frames(18)
	var canvas: Control=panel.map_canvas
	check(canvas.region_id=="farm" and FarmAtlasData.bounds("farm").size==Vector2(3072,2048),"farm parchment uses true expanded boundary")
	check(canvas.player_map_position().distance_to(FarmAtlasData.world_to_map("farm",game.player.position))<.01,"expanded farm player marker correct")
	var zones: int=0;var gates: int=0
	for place in canvas.places:
		if str(place.id).begins_with("expansion_"): zones+=1
		if str(place.id).begins_with("pasture_"): gates+=1
	check(zones==4 and gates==3,"expanded farm paper shows real planning zones and built pasture gates")
	await shot(prefix+"-farm-atlas");await audit(panel,"扩建农场图纸")
	var before: Vector2=game.player.position;var camera: Vector2=game.camera_rig.view_center
	var center: Vector2=canvas.get_global_rect().get_center();Touch.finger(self,center,true,872)
	var drag:=InputEventScreenDrag.new();drag.index=872;drag.position=center+Vector2(48,30);drag.relative=Vector2(48,30);get_viewport().push_input(drag,true);Touch.finger(self,drag.position,false,872);await frames(4)
	canvas.zoom_by(2);canvas.pan_by(Vector2(110,-75));check(game.player.position==before and game.camera_rig.view_center==camera,"paper drag and zoom do not reach world inputs")
	check(canvas.screen_to_map(canvas.map_to_screen(canvas.player_map_position())).distance_to(canvas.player_map_position())<2,"zoom and pan keep actual farm marker aligned")
	panel.close_panel()
	check(Inventory.items==state.items and Inventory.coins==state.coins and Xiaojing.snapshot()==state.xiaojing,"viewing map cannot mutate economy or relationship progress")
	for site in RanchLayout.ENABLED:
		game.change_location(RanchLayout.area(site),RanchLayout.entry(site));await frames(5)
		check(FarmAtlasData.known(RanchLayout.area(site)),"real built pasture is discoverable in paper "+site)
		panel.open_panel();panel.show_current();await frames(18)
		check(canvas.region_id==RanchLayout.area(site) and canvas.player_map_position().distance_to(FarmAtlasData.world_to_map(RanchLayout.area(site),game.player.position))<.01,"pasture independent coordinate marker correct "+site)
		panel.show_world();check(canvas.player_map_position()==FarmAtlasData.WORLD_POINTS.farm,"overview uses farm-region pin rather than invented continuous coordinates "+site)
		panel.show_current();await shot(prefix+"-"+site+"-atlas");panel.close_panel()
func joystick() -> void:
	game.change_location("pasture_coop",RanchLayout.entry("coop"));GameState.set_control_mode("joystick",false);await frames(5)
	var start: Vector2=game.player.position;var at: Vector2=game.hud.joystick.get_global_rect().get_center()
	Touch.finger(self,at+Vector2(40,0),true,873);await frames(30);Touch.finger(self,at+Vector2(40,0),false,873);await frames(3)
	check(game.player.position.x>start.x+10 and game.player.touch_direction==Vector2.ZERO,"native backup joystick moves inside real pasture and releases cleanly")
	GameState.set_control_mode("tap",false);await frames(3)
	var target: Vector2=Vector2(20,19)*32+Vector2(16,16)
	Touch.tap(self,game,target);await Touch.finish(self,game,1000)
	check(game.player.position.distance_to(target)<2,"closing menus restores native tap movement inside pasture")
