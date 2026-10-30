extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
const Fixture=preload("res://tests/harvest_fixture.gd")
const UI=preload("res://tests/story.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false);GameState.manual_tool=false
	GameClock.minutes=720;GameClock.changed.emit()
	await Touch.place(self,game,"farm",Vector2(656,480))
	var site: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if "kind" in node and node.kind=="workshop": site=node;break
	check(is_instance_valid(site),"outdoor repair workshop exists")
	if is_instance_valid(site):
		for offset in [Vector2(0,-20),Vector2(0,-42),Vector2.ZERO]:
			while game.hud.close_active_panel(): pass
			await Touch.place(self,game,"farm",Vector2(656,480))
			var point: Vector2=site.global_position+offset
			var intent:=TouchInteractionResolver.resolve(game,point)
			game.auto_move.navigation.rebuild()
			print("WORKSHOP PROBE ",offset," intent=",intent," path=",game.auto_move.navigation.path_to(intent))
			Touch.tap(self,game,point);await Touch.finish(self,game,600);await frames(8)
			check(game.hud.progress_panel.visible and game.hud.progress_panel.mode=="workshop","tap outdoor repair table opens workshop "+str(offset))
	while game.hud.close_active_panel(): pass
	await Touch.place(self,game,"farm",Vector2(464,688))
	var yard: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if "housing_id" in node and node.housing_id=="yard": yard=node;break
	check(is_instance_valid(yard),"outdoor furniture crafting table exists")
	if is_instance_valid(yard):
		var intent:=TouchInteractionResolver.resolve(game,yard.global_position-Vector2(0,20))
		game.auto_move.navigation.rebuild()
		print("YARD PROBE intent=",intent," path=",game.auto_move.navigation.path_to(intent))
		Touch.tap(self,game,yard.global_position-Vector2(0,20));await Touch.finish(self,game,600);await frames(8)
		check(game.hud.housing_panel.visible and game.hud.housing_panel.context=="yard","tap outdoor furniture table opens crafting panel")
	if DisplayServer.get_name()!="headless":
		await frames(4);await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/workshop-access-before.png")
	check(HarvestCatalog.data().processing.has("berry_jam"),"wild berry jam is available at the physical jam pot")
	while game.hud.close_active_panel(): pass
	await Touch.place(self,game,"farm",Kitchen.berry_point()+Vector2(0,32))
	Touch.tap(self,game,Kitchen.berry_point()-Vector2(0,15));await Touch.finish(self,game,600);await frames(5)
	var stock_before:=Inventory.items.duplicate(true)
	await press(game.hud.kitchen_panel,"前往果酱锅")
	check(game.hud.kitchen_panel.visible and Inventory.items==stock_before and Workshop.state.jobs.is_empty(),"no installed pot keeps berry guide open and cannot remotely process or consume anything")
	while game.hud.close_active_panel(): pass
	await Touch.place(self,game,"farm",Vector2(464,688))
	Fixture.stock();game.territory_editor.open();await frames(4)
	var pot: String=""
	for cell in [Vector2i(5,22),Vector2i(7,23),Vector2i(8,22)]:
		var plan:=Territory.plan_place("farm","station_jam_pot",cell)
		print("POT INSTALL PROBE cell=",cell," plan=",plan)
		if plan.valid and Territory.apply_plan(plan): pot=str(Territory.state.objects[-1].id);break
	game.territory_editor.cancel();await frames(5)
	check(pot!="","physical jam pot installed above original poultry shelter")
	if pot!="":
		await Touch.place(self,game,"farm",Vector2(304,688))
		var object: Node2D=game.territory_world.objects[pot]
		var point: Vector2=object.global_position-Vector2(0,24)
		Touch.tap(self,game,point);await Touch.finish(self,game,600);await frames(5)
		print("JAM POT PROBE player=",game.player.global_position," device=",object.global_position," available=",Workshop.available()," near=",Workshop.near_device(pot))
		check(game.hud.workshop_panel.visible and game.hud.workshop_panel.device==pot,"tap jam pot above poultry shelter opens processing panel")
		while game.hud.close_active_panel(): pass
		await Fixture.approach(self,game,pot)
		var screen: Vector2=game.player.get_canvas_transform()*point
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=screen;mouse.pressed=true
		get_viewport().push_input(mouse,true);mouse=mouse.duplicate();mouse.pressed=false;get_viewport().push_input(mouse,true)
		await Touch.finish(self,game,600);await frames(5)
		check(game.hud.workshop_panel.visible and game.hud.workshop_panel.device==pot,"Windows mouse click opens same physical jam pot")
		while game.hud.close_active_panel(): pass
		await shot("jam-pot-location")
		await Touch.place(self,game,"farm",Kitchen.berry_point()+Vector2(0,32))
		Touch.tap(self,game,Kitchen.berry_point()-Vector2(0,15));await Touch.finish(self,game,600);await frames(5)
		check(game.hud.kitchen_panel.visible and game.hud.kitchen_panel.context=="berry","berry bush above poultry opens original harvest interaction")
		check(not game.hud.kitchen_panel.tab_bar.visible and game.hud.kitchen_panel.title.text=="野莓采集 · 果酱原料","berry context hides nonfunctional kitchen tabs and uses a distinct title")
		await shot("berry-guide")
		var from: Vector2=game.player.global_position
		await press(game.hud.kitchen_panel,"前往果酱锅")
		check(game.player.global_position.distance_to(from)<32 and not game.hud.workshop_panel.visible,"guide starts walking and does not teleport or open remote processing")
		await Touch.finish(self,game,600);await frames(5)
		print("BERRY ROUTE PROBE position=",game.player.position," state=",game.auto_move.state," modal=",GameState.modal," berry_panel=",game.hud.kitchen_panel.visible)
		check(game.hud.workshop_panel.visible and game.hud.workshop_panel.device==pot,"berry guide walks to real reachable pot and opens it without teleporting")
		await production(pot)
	while game.hud.close_active_panel(): pass
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
	game.hud.kitchen_panel.open_panel();await frames(4)
	check(game.hud.kitchen_panel.visible and game.hud.kitchen_panel.tab_bar.visible and game.hud.kitchen_panel.title.text=="炉火与麦香 · 小屋厨房","returning indoors restores actual kitchen title and all tabs")
	print("WORKSHOP ACCESS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(6);get_tree().quit(1 if failed else 0)

func press(panel: Node, caption: String) -> void:
	var button: Button=UI.find_button(panel,caption)
	check(button!=null and not button.disabled,"visible enabled action: "+caption)
	if button!=null and not button.disabled:
		var parent: Node=button.get_parent()
		while parent!=null and parent!=panel:
			if parent is ScrollContainer: parent.ensure_control_visible(button)
			parent=parent.get_parent()
		await frames(3);UI.touch(self,button)
	await frames(5)

func production(pot: String) -> void:
	if not HarvestCatalog.data().processing.has("berry_jam"): return
	var recipe: Dictionary=HarvestCatalog.data().processing.berry_jam
	check(recipe.input_items==Kitchen.data.processing.berry_jam.required and recipe.processing_duration==int(Kitchen.data.processing.berry_jam.days)*1440 and recipe.output_item_id=="berry_jam" and recipe.output_quantity==1,"physical recipe preserves existing inputs, two-day timing and output ID")
	var panel: Node=game.hud.workshop_panel
	check(panel.recipe_buttons.has("berry_jam"),"physical pot lists wild berry jam")
	if not panel.recipe_buttons.has("berry_jam"): return
	Inventory.items.wild_berry=4;Inventory.items.wheat=1;Inventory.items.erase("berry_jam");Inventory.changed.emit();await frames(5)
	panel.left_scroll.ensure_control_visible(panel.recipe_buttons.berry_jam);await frames(3)
	UI.touch(self,panel.recipe_buttons.berry_jam);await frames(5)
	check(panel.selected=="berry_jam","native recipe tap selects wild berry jam")
	await shot("jam-recipe")
	await press(panel,"开始加工")
	check(Inventory.count("wild_berry")==4 and not Workshop.state.jobs.has(pot),"preview does not deduct materials")
	await press(panel,"取消")
	check(Inventory.count("wild_berry")==4 and not Workshop.state.jobs.has(pot),"cancel preserves berries and wheat")
	await press(panel,"开始加工");await press(panel,"确认开始")
	check(Workshop.state.jobs.has(pot) and Inventory.count("wild_berry")==0 and Inventory.count("wheat")==0,"confirmed jam order deducts exactly four berries and one wheat")
	if not Workshop.state.jobs.has(pot): return
	var job: Dictionary=Workshop.state.jobs[pot].duplicate(true)
	check(not Workshop.start(pot,"berry_jam") and Workshop.state.jobs[pot]==job,"occupied pot rejects duplicate submission")
	while game.hud.close_active_panel(): pass
	game.territory_editor.open();await frames(4)
	var old:=TerritoryCatalog.to_cell(Territory.object(pot).cell)
	var moved: bool=false
	for offset in [Vector2i(1,0),Vector2i(0,-1),Vector2i(2,0)]:
		var plan:=Territory.plan_move(pot,old+offset)
		if plan.valid and Territory.apply_plan(plan): moved=true;break
	game.territory_editor.cancel();await frames(5)
	check(moved and Workshop.state.jobs[pot]==job,"DIY move preserves device identity and active order")
	var save:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))),"in-progress berry jam and moved pot restore through whole save")
	await frames(5);Fixture.advance(2880);await frames(5)
	await Touch.place(self,game,"farm",Vector2(304,688));await Fixture.approach(self,game,pot)
	Touch.tap(self,game,game.territory_world.objects[pot].global_position-Vector2(0,24));await Touch.finish(self,game,600);await frames(5)
	check(panel.visible and panel.device==pot and Workshop.state.jobs[pot].ready,"moved restored pot opens and completes after two game days")
	Inventory.items.berry_jam=Inventory.MAX_STACK;Inventory.changed.emit();await frames(4)
	await press(panel,"收取成品")
	check(Workshop.state.jobs.has(pot),"full inventory retains completed jam in device")
	Inventory.items.erase("berry_jam");Inventory.changed.emit();await frames(4)
	await shot("jam-ready")
	await press(panel,"收取成品")
	check(not Workshop.state.jobs.has(pot) and Inventory.count("berry_jam")==1,"claim delivers exactly one existing wild berry jam item")
	check(not Workshop.claim(pot,int(job.id)) and Inventory.count("berry_jam")==1,"repeated claim cannot duplicate jam")
	await shot("jam-collected")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"completed new order keeps existing save schema valid")

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute("res://docs/workshop-hotfix")
	await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/workshop-hotfix/"+label+".png")
