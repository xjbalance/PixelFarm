extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-abyss" in OS.get_cmdline_user_args()
	if "--corrupt-abyss" in OS.get_cmdline_user_args():
		var bad := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		bad.store_string("broken abyss primary")
		bad.close()
		print("ABYSS CORRUPT: PASS")
		get_tree().quit()
		return
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	for i in range(5): await get_tree().physics_frame
	game.persistence_enabled=false # 测试明确控制写入顺序，不让交互自动保存抢写备份。
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,false)
		Xiaojing.state.greenhouse=false
		LegendState.restore(LegendState.defaults())
		var ch := ChapterTwo.defaults()
		ch.policy="rotation"
		for q in ChapterTwo.definitions.slice(0,8):
			ch.completed.append(q.id)
			for id in q.conditions:
				if id not in ch.facts: ch.facts.append(id)
		ChapterTwo.restore(ch)
		game.change_location("farm",Vector2(1360,816))
		ok=LegendTrials.begin("planning")
		Inventory.items.copper_ore=20
		Inventory.items.wood=99
		game.change_location("village",Vector2(528,480))
		ok=ok and MineState.enqueue("copper_bar",2)
		var a := AbyssState.defaults()
		a.unlocked=true
		a.depth=12
		a.max_clear=11
		a.checkpoint=10
		a.gear=2
		a.air=77
		for d in range(1,12): a.gates.append(d); a.notes.append(d)
		a.notes.append(12)
		a.steps={"12":1}
		AbyssState.restore(a)
		LegendState.state.evidence=[10,12]
		GameState.set_control_mode("joystick",false)
		game.change_location("abyss",AbyssState.point(AbyssState.layout().entry))
		ok=ok and FarmSaveStore.write(game) and FarmSaveStore.write(game)
	else:
		ok=GameState.location=="abyss" and AbyssState.state.depth==12 and AbyssState.state.air==77 and AbyssState.state.gear==2
		ok=ok and AbyssState.state.checkpoint==10 and AbyssState.state.steps.get("12")==1 and GameState.control_mode=="joystick"
		ok=ok and LegendTrials.active("planning") and LegendState.state.contract.jobs==[1] and LegendState.state.contract.wood==4
		ok=ok and MineState.state.queue.size()==1 and LegendState.state.evidence==[10,12]
		GameState.set_control_mode("tap",false)
		game.auto_move.request(game.mine_maps.abyss.objects.lever_2.global_position+Vector2(0,-14))
		for i in range(1000):
			await get_tree().physics_frame
			if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		ok=ok and 12 in AbyssState.state.gates and game.auto_move.state==game.auto_move.State.IDLE
		ok=ok and FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty()
	print("ABYSS PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.persistence_enabled=false
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
