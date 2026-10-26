extends Node
const Home=preload("res://tests/home05_runner.gd")
## C新增三分区真正跨进程与备份；测试只使用外部隔离目录。
func _ready() -> void: call_deferred("run")
func frames(count: int=4) -> void:
	for i in range(count): await get_tree().physics_frame
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--corrupt-life" in args:
		var broken:=FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);broken.store_string("interrupted life state");broken.close()
		print("LIFE C CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-life" in args
	var game:=preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6);game.persistence_enabled=false
	var ok: bool=true
	if writing:
		GameClock.day=22;GameClock.minutes=600;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
		Inventory.coins=10000;Inventory.items={"wood":200,"stone":200,"carrot":5,"wheat_seed":9,"carrot_seed":9,"iron_bar":8,"crystal":8}
		ok=await Home.finish_upgrade(self,game,1) and ok
		game.change_location("farm",Vector2(656,480));GameClock.minutes=600;GameClock.changed.emit();await frames()
		var linya: Node2D=Social.person_node("linya");game.player.position=linya.global_position+Vector2(0,36)
		ok=Social.talk("linya") and Social.accept("linya") and ok
		game.player.position=Vector2(880,528)
		ok=Festival.begin("spring") and ok
		var cells: Array=Festival.state.runs.spring.cells.duplicate(true)
		for i in range(cells.size()):
			var cell:=Vector2i(cells[i][0],cells[i][1]);var key: String=game.farm.key(cell)
			if not game.farm.plots.has(key): ok=game.farm.use_tool(cell,"hoe") and ok
			ok=game.farm.use_tool(cell,"carrot_seed" if i==0 else "wheat_seed") and ok
			if not game.farm.plots[key].watered: ok=game.farm.use_tool(cell,"water") and ok
		ok=Festival.claim("spring") and ok
		game.change_location("home",Housing.HOME+Vector2(32,0));await frames()
		ok=Housing.buy("chair") and Housing.place("chair","home",Vector2i(8,13)) and Housing.deposit("wood",12) and ok
		await frames();game.player.position=Vector2(272,496)
		var proof: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game));var file:=FileAccess.open("user://life-proof.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(proof));file.close()
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game) and ok
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://life-proof.json")))
		var restored: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		for key in ["housing","social","festival","day","minutes","coins","items","plots","xiaojing","calendar","recovery"]:
			if restored.get(key)!=proof.get(key): print("LIFE C MISMATCH ",key);ok=false
		ok=ok and GameState.location=="home" and game.player.position==Vector2(272,496)
		var coins: int=Inventory.coins
		game.change_location("farm",Vector2(880,528));await frames()
		ok=not Festival.claim("spring") and Inventory.coins==coins and ok
		game.change_location("home",Housing.HOME+Vector2(32,0));await frames()
		ok=Housing.withdraw("wood",12) and not Housing.withdraw("wood",1) and ok
		ok=FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty() and ok
	print("LIFE C PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(3);get_tree().quit(0 if ok else 1)
