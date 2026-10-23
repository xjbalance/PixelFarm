extends "res://tests/runner.gd"
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);game.get_node("Audio").muted=true;GameClock.running=false
	await frames(5);load("res://tests/star_runner.gd").fixture(game,true);River.restore(River.defaults())
	var a := AbyssState.defaults();a.unlocked=true;a.max_clear=100;a.gear=7;a.checkpoint=100;a.bosses=[20,40,60,80,100]
	for n in range(1,101): a.gates.append(n);a.notes.append(n)
	for depth in range(1,101):
		a.depth=depth;AbyssState.restore(a);game.change_location("abyss",AbyssState.point(AbyssState.layout().controls[1]));await frames(3)
		check(game.mine_maps.abyss.ground.get_used_cells().size()==1120 and game.mine_maps.abyss.actors.get_child_count()<=16,"实际窗口地图与实体："+str(depth))
		if depth in [5,30,50,70,100]:
			game.auto_move.navigation.rebuild()
			var origin: Vector2=game.player.global_position
			var moved := false
			for offset in [Vector2(32,0),Vector2(-32,0),Vector2(0,32),Vector2(0,-32)]:
				var target: Vector2=origin+offset
				if TouchInteractionResolver.resolve(game,target).kind!="ground" or game.auto_move.navigation.path_to({"kind":"ground","point":target}).is_empty(): continue
				load("res://tests/touch_navigation.gd").tap(self,game,target)
				for i in range(60):
					await frames(1)
					if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
				moved=game.player.global_position.distance_to(origin)>5
				if moved: break
			check(moved,"实际窗口原生触点经相机转换移动："+str(depth))
	River.state.venue_used=true;River.state.wedding_step=1;StarStory.state.wedding_phase=3;StarStory.changed.emit()
	game.change_location("greenhouse",Vector2(640,400));game.get_node("Audio").muted=false;await frames(8)
	check(game.mine_maps.greenhouse.music.playing and game.mine_maps.greenhouse.ambience.playing,"独立礼堂音乐与环境循环已播放")
	check(StarCeremony.vows() and StarCeremony.vows() and StarStory.finish_ceremony(),"实际窗口婚礼对白/收尾保持事务")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;game.hud.river_panel.open_panel("archive");await frames(4)
		check(game.hud.safe.get_global_rect().encloses(game.hud.river_panel.get_global_rect()),"新礼堂长面板安全区："+str(resolution));game.hud.close_active_panel()
		game.hud.system_panel.open_panel();await frames(4)
		check(game.hud.safe.get_global_rect().encloses(game.hud.system_panel.get_global_rect()),"开发诊断设置仍在安全区："+str(resolution));game.hud.close_active_panel()
	print("RENDER 061 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").muted=true;game.get_node("Audio").stop_all();await get_tree().create_timer(.4).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
