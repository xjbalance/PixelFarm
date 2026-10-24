extends "res://tests/runner.gd"
## 桌面无头生命周期与导航成本，不把这些数字称作Android帧率。
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	load("res://tests/star_runner.gd").fixture(game,true)
	var eco: Dictionary=LakeEcology.defaults(GameClock.day);eco.restored=true;eco.cycle=true;eco.plants=3;eco.health=95;LakeEcology.restore(eco)
	var exploration: Dictionary=Exploration.defaults()
	exploration.unlocked=Exploration.AREAS.duplicate();exploration.forest={"step":4,"open":true};exploration.lake={"water":0,"flow":1,"open":true};exploration.temple={"mirror":2,"step":3,"open":true}
	for id in Exploration.data.points:
		if Exploration.data.points[id].kind=="note": exploration.facts.append(id)
	exploration.facts.append("drain_plate");exploration.facts.append("lake_lower_opened");Exploration.restore(exploration)
	var housing: Dictionary=Housing.defaults();housing.level=3;Housing.restore(housing);await frames(6)
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"性能夹具为完整合法新存档，不用矛盾状态绕过区域前置")
	var areas: Array[String]=["farm","home","village","mist_forest","lake_ruins","old_temple"]
	var transitions: Array[float]=[];var navigation: Array[float]=[]
	var memory_start: int=0;var nodes_start: int=0;var clean_input: bool=true
	for i in range(264):
		var area: String=areas[i%areas.size()]
		var start: int=Time.get_ticks_usec();game.change_location(area);transitions.append(float(Time.get_ticks_usec()-start)/1000)
		GameState.set_control_mode("tap" if i%2==0 else "joystick",false);await frames(4)
		clean_input=clean_input and game.auto_move.target.is_empty() and game.player.auto_direction==Vector2.ZERO
		if i<24 or i%24==0:
			var nav_start: int=Time.get_ticks_usec();game.auto_move.navigation.rebuild();navigation.append(float(Time.get_ticks_usec()-nav_start)/1000)
		if i==23: memory_start=OS.get_static_memory_usage();nodes_start=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await frames(6)
	var nodes_end: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var growth: int=OS.get_static_memory_usage()-memory_start
	check(nodes_end<=nodes_start+16 and growth<8*1024*1024,"预热后240次新增/原图切换节点与静态内存保持有界")
	check(clean_input,"压力切图与模式切换始终清除旧目标和自动输入")
	transitions.sort();navigation.sort()
	var report: Dictionary={"version":"0.7.0","platform":"Linux headless Godot4.3","android_measurement":false,"warmup":24,"switches":240,"areas":areas,"nodes_start":nodes_start,"nodes_end":nodes_end,"static_memory_growth_bytes":growth,"change_call_ms_p50":transitions[transitions.size()/2],"change_call_ms_p95":transitions[int(transitions.size()*.95)],"navigation_rebuild_ms_p50":navigation[navigation.size()/2],"navigation_rebuild_ms_p95":navigation[int(navigation.size()*.95)],"limits":"Change-call timing excludes deferred scene presentation; no mobile FPS, GPU, power, thermal or long-session RSS claim."}
	var file:=FileAccess.open("res://docs/PERFORMANCE-0.7.0.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PERFORMANCE 070 ",JSON.stringify(report));print("PERFORMANCE 070 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
