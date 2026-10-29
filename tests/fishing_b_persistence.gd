extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	if "--corrupt-fishing" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted fishing save fixture");file.close()
		print("FISHING CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-fishing" in OS.get_cmdline_user_args()
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		GameState.select_tool(GameState.tools.find("fishing_rod"));Inventory.items.fishing_bait=10
		game.change_location("farm",Vector2(944,464))
		for i in range(5): await get_tree().physics_frame
		game.player.action_time=0;ok=Fishing.start("farm_lake")
		var item: String=Fishing.data.species[Fishing.session.species].item
		Inventory.items[item]=999
		for i in range(4000):
			if not Fishing.active(): break
			Fishing.tick(1.0/120.0,Fishing.session.player>Fishing.session.fish)
		ok=ok and Fishing.state.pending!="" and Fishing.state.total==0
		var proof := {"fishing":Fishing.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"day":GameClock.day,"mode":GameState.control_mode}
		var file := FileAccess.open("user://fishing-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://fishing-proof.json")))
		ok=Fishing.snapshot()==proof.fishing and Inventory.items==proof.items and Inventory.coins==proof.coins and GameState.stamina==proof.stamina and GameClock.day==proof.day and GameState.control_mode==proof.mode and not Fishing.active()
		if Fishing.state.pending!="":
			var item: String=Fishing.data.species[Fishing.state.pending].item
			Inventory.remove(item,1)
			ok=Fishing.claim() and not Fishing.claim() and Fishing.state.total==1 and Inventory.count(item)==999 and ok
		else: ok=false
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("FISHING PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
