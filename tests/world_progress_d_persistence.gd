extends Node
var game: Node
func _ready() -> void: call_deferred("run")
func frames(count: int = 5) -> void:
	for i in range(count): await get_tree().physics_frame
func near(context: String) -> void:
	game.change_location("village",WorldDevelopment.anchor(context)+Vector2(0,16 if context=="board" else 32));await frames()
func crop(cell: Vector2i) -> bool:
	if not game.farm.use_tool(cell,"hoe"): return false
	await frames(16)
	if not game.farm.use_tool(cell,"carrot_seed"): return false
	await frames(16)
	if not game.farm.plots[game.farm.key(cell)].watered:
		if not game.farm.use_tool(cell,"water"): return false
		await frames(16)
	return true
func next_day() -> bool:
	for plot in game.farm.plots.values(): plot.watered=true
	GameClock.minutes=1200;var ok: bool=GameClock.request_sleep(GameClock.day);await frames();return ok
func pilot() -> bool:
	for i in range(4000):
		if not Fishing.active(): return Fishing.session.phase in ["landed","caught"]
		Fishing.tick(1.0/120.0,Fishing.session.player>Fishing.session.fish)
	return false
func run() -> void:
	if "--corrupt-world-progress" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted world progress fixture");file.close()
		print("WORLD PROGRESS CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-world-progress" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6);game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,true)
		GameClock.day=225;GameClock.minutes=600;Calendar.restore(Calendar.snapshot())
		WorldDevelopment.restore(WorldDevelopment.defaults(GameClock.day));Letters.direction="trade"
		Inventory.items={"wood":300,"stone":300,"copper_bar":20,"iron_bar":20,"crystal":20,"wheat":30,"carrot_seed":10,"fishing_bait":30}
		Inventory.coins=24680;Xiaojing.state.diamonds=1427
		await near("board");ok=WorldDevelopment.build("dock",0) and WorldDevelopment.build("community",0)
		await near("dock");ok=WorldDevelopment.accept_order("fresh_baskets") and ok
		game.change_location("farm",Vector2(656,560));await frames()
		ok=await crop(Vector2i(18,18)) and ok
		ok=await next_day() and ok;ok=await next_day() and ok
		ok=game.farm.use_tool(Vector2i(18,18),"hand") and ok;await frames(16)
		ok=ok and int(WorldDevelopment.state.order.credit.get("carrot",0))==1
		await near("board");GameState.set_control_mode("joystick",false)
		var proof := {"world":WorldDevelopment.snapshot(),"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"diamonds":Xiaojing.state.diamonds,"day":GameClock.day,"mode":GameState.control_mode}
		var file := FileAccess.open("user://world-progress-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://world-progress-proof.json")))
		ok=WorldDevelopment.snapshot()==proof.world and Inventory.coins==proof.coins and Inventory.items==proof.items and Xiaojing.state.diamonds==proof.diamonds and Xiaojing.state.married and GameClock.day==proof.day and GameState.control_mode==proof.mode
		var before: Dictionary=WorldDevelopment.snapshot()
		WorldDevelopment.restore(JSON.parse_string(JSON.stringify(before)));GameClock.changed.emit()
		ok=WorldDevelopment.snapshot()==before and ok
		game.change_location("farm",Vector2(656,560));await frames()
		ok=await crop(Vector2i(19,18)) and ok;ok=await crop(Vector2i(20,18)) and ok
		ok=await next_day() and ok;ok=await next_day() and ok
		for cell in [Vector2i(19,18),Vector2i(20,18)]:
			ok=game.farm.use_tool(cell,"hand") and ok;await frames(16)
		GameState.select_tool(GameState.tools.find("fishing_rod"));game.change_location("farm",Vector2(944,464));await frames();game.player.action_time=0
		for i in range(12):
			if int(WorldDevelopment.state.order.credit.get("fish_crucian",0))>=2: break
			ok=Fishing.start("farm_lake") and pilot() and ok
		await near("dock");ok=WorldDevelopment.trade_ready() and WorldDevelopment.use_trade("fresh_baskets") and not WorldDevelopment.use_trade("fresh_baskets") and WorldDevelopment.state.trade_count==1 and ok
		GameState.set_control_mode("joystick",false)
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("WORLD PROGRESS PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
