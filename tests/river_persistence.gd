extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-river" in OS.get_cmdline_user_args()
	if "--corrupt-river" in OS.get_cmdline_user_args():
		var bad := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);bad.store_string("broken 0.6 primary");bad.close();print("RIVER CORRUPT: PASS");get_tree().quit();return
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game);game.get_node("Audio").muted=true;GameClock.running=false
	for i in range(5): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,true)
		var chapter := ChapterTwo.defaults();chapter.policy="rotation"
		for q in ChapterTwo.definitions.slice(0,8):
			chapter.completed.append(q.id)
			for fact in q.conditions:
				if fact not in chapter.facts: chapter.facts.append(fact)
		ChapterTwo.restore(chapter)
		River.restore(River.defaults());River.state.venue_used=true;River.state.wedding_step=1;River.state.memory_seen=Xiaojing.state.memories.duplicate()
		StarStory.state.wedding_phase=3;Xiaojing.state.diamonds=17
		var a := AbyssState.defaults();a.unlocked=true;a.max_clear=99;a.depth=100;a.checkpoint=90;a.gear=7;a.air=83
		for depth in range(1,100): a.gates.append(depth);a.notes.append(depth)
		a.notes.append(100);a.bosses=[20,40,60,80];a.extra={"100":{"utility":[0],"angle":0,"round":2,"confirmed":false}};a.steps={"100":2}
		AbyssState.restore(a)
		game.change_location("greenhouse",Vector2(640,390));GameState.set_control_mode("joystick",false)
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game)
	else:
		ok=GameState.location=="greenhouse" and River.state.wedding_step==1 and StarStory.state.wedding_phase==3 and Xiaojing.state.diamonds==17 and GameState.control_mode=="joystick"
		ok=ok and AbyssState.state.depth==100 and AbyssState.state.checkpoint==90 and AbyssState.state.air==83 and AbyssState.state.steps.get("100")==2
		ok=ok and StarCeremony.vows() and StarCeremony.vows() and StarStory.finish_ceremony() and not Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==17
		game.change_location("abyss",AbyssState.point(AbyssState.layout().entry));GameState.set_control_mode("tap",false)
		for i in range(5): await get_tree().physics_frame
		for id in ["utility_1","lever_2","lever_3"]:
			game.auto_move.request(game.mine_maps.abyss.objects[id].global_position+Vector2(0,-14))
			for i in range(1200):
				await get_tree().physics_frame
				if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		ok=ok and 100 in AbyssState.state.gates and Xiaojing.state.diamonds==17
		ok=ok and FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty()
	print("RIVER PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
