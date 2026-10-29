extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var writing: bool="--write-stability" in OS.get_cmdline_user_args()
	if "--corrupt-stability" in OS.get_cmdline_user_args():
		var f := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);f.store_string("broken audit primary");f.close();print("STABILITY CORRUPT: PASS");get_tree().quit();return
	var game := preload("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game);GameClock.running=false;game.get_node("Audio").muted=true
	for i in range(5): await get_tree().physics_frame
	game.persistence_enabled=false
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game,false)
		var ch := ChapterTwo.defaults();ch.policy="rotation"
		for q in ChapterTwo.definitions.slice(0,8):
			ch.completed.append(q.id)
			for fact in q.conditions:
				if fact not in ch.facts: ch.facts.append(fact)
		ChapterTwo.restore(ch)
		var a := AbyssState.defaults();a.unlocked=true;a.max_clear=100;a.depth=100;a.checkpoint=100;a.gear=7;a.bosses=[20,40,60,80,100]
		for depth in range(1,101): a.gates.append(depth);a.notes.append(depth)
		AbyssState.restore(a);River.state.legacy_rules=false
		game.change_location("farm",Vector2(1360,816))
		ok=LegendTrials.begin("cave")
		for depth in range(80,100): LegendTrials.visited(depth)
		AbyssState.state.air=1;LegendTrials.visited(100);AbyssState.state.air=160
		GameState.set_control_mode("joystick",false)
		ok=ok and FarmSaveStore.write(game) and FarmSaveStore.write(game)
		Playtest.start();Playtest.account(2,false,false,100);Playtest.record("task",{"id":"audit_persistence"});ok=ok and Playtest.flush();Playtest.enabled=false
	else:
		ok=LegendState.state.contract.get("arrival_air")==1 and AbyssState.state.air==160 and not LegendTrials.finish() and GameState.control_mode=="joystick"
		var gameplay := FarmSaveStore.snapshot(game)
		var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Playtest.SUMMARY))
		ok=ok and prior.lifetime.active_s>=2
		Playtest.start();Playtest.account(1,false,false,100);ok=ok and Playtest.flush();Playtest.enabled=false
		var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Playtest.SUMMARY))
		ok=ok and current.lifetime.active_s==prior.lifetime.active_s+1 and current.session!=prior.session and FarmSaveStore.snapshot(game)==gameplay
		ok=ok and FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty()
	print("STABILITY PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await get_tree().process_frame;get_tree().quit(0 if ok else 1)
