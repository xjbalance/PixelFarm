extends "res://tests/ux083_task_equivalence.gd"

func run() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.manual_tool=false
	# Isolated collision specimen: a 19px passage on the real expanded farm.
	# The existing player's 18px-diameter feet can legally pass; no world data is edited.
	for rect in [Rect2(2300,1376,10.5,176),Rect2(2329.5,1376,10.5,176)]:
		var body:=StaticBody2D.new();body.position=rect.get_center()
		var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box;body.add_child(shape)
		var art:=Polygon2D.new();art.polygon=PackedVector2Array([-rect.size*.5,Vector2(rect.size.x,-rect.size.y)*.5,rect.size*.5,Vector2(-rect.size.x,rect.size.y)*.5]);art.color=Color("9b7650");body.add_child(art)
		game.world.actors.add_child(body)
	await frames(4);Events.navigation_changed.emit()
	var goal:=Vector2(2320,1504)
	for mode in ["joystick","tap"]:
		GameState.set_control_mode(mode,false);await Touch.place(self,game,"farm",Vector2(2240,1504));await frames(4)
		probe_name="narrow-passage-"+mode;trace=[];captured=0
		check(not colliding(),"狭窄通路测试起点合法 "+mode)
		if mode=="joystick":
			for point in [Vector2(2240,1344),Vector2(2320,1344),goal]: await walk(point)
		else:
			Touch.tap(self,game,goal)
			for i in range(900):
				await tick()
				if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
		var arrived: bool=game.player.position.distance_to(goal)<2
		var overlaps: int=trace.filter(func(row: Dictionary): return row.collision).size()
		check(overlaps==0,"真实物理行走不穿过两侧碰撞墙 "+mode)
		if mode=="joystick" or not baseline: check(arrived,"同一脚底可以穿过19px通道 "+mode)
		records.append({"mode":mode,"arrived":arrived,"stop":[game.player.position.x,game.player.position.y],"collisions":overlaps,"trace":trace.duplicate(true)})
		await capture("result")
	if not baseline: await blocked_targets()
	DirAccess.make_dir_recursive_absolute("res://docs/ux083/p0")
	var file:=FileAccess.open("res://docs/ux083/p0/"+("before" if baseline else "after")+("-window" if DisplayServer.get_name()!="headless" else "")+"-geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline":baseline,"checks":checked,"failures":failed,"cases":records},"\t",true,true));file.close()
	print("UX083 GEOMETRY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(5);get_tree().quit(1 if failed else 0)

func wall(rect: Rect2) -> void:
	var body:=StaticBody2D.new();body.position=rect.get_center()
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box;body.add_child(shape)
	var art:=Polygon2D.new();art.polygon=PackedVector2Array([-rect.size*.5,Vector2(rect.size.x,-rect.size.y)*.5,rect.size*.5,Vector2(-rect.size.x,rect.size.y)*.5]);art.color=Color("9b7650");body.add_child(art)
	game.world.actors.add_child(body)

func blocked_targets() -> void:
	GameState.set_control_mode("tap",false);await Touch.place(self,game,"farm",Vector2(2240,1504))
	probe_name="blocked-ground";trace=[];captured=0
	var blocked:=Vector2(2305,1440)
	Touch.tap(self,game,blocked)
	for i in range(300):
		await tick()
		if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
	check(game.auto_move.state==game.auto_move.State.IDLE and game.player.position.distance_to(blocked)<=64 and game.player.position.x<2300,"墙内地面点击只走向同侧64px内的连通落脚点")
	check(not colliding(),"邻近落点没有穿墙或透明碰撞重叠")
	await capture("result")
	for rect in [Rect2(2448,1408,64,8),Rect2(2448,1464,64,8),Rect2(2448,1408,8,64),Rect2(2504,1408,8,64)]: wall(rect)
	var point:=Node2D.new();point.set_script(preload("res://scripts/world/story_point.gd"));point.actor_id="repair_record";point.prop_kind="post";point.position=Vector2(2480,1440);game.world.actors.add_child(point)
	await frames(4);Events.navigation_changed.emit()
	for mode in ["tap","joystick"]:
		await Touch.place(self,game,"farm",Vector2(2428,1440));GameState.set_control_mode(mode,false);await frames(3)
		probe_name="sealed-task-"+mode;trace=[];captured=0
		var before:=business()
		if mode=="tap":
			Touch.tap(self,game,point.global_position-Vector2(0,20))
			for i in range(300):
				await tick()
				if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
			check(game.auto_move.state==game.auto_move.State.FAILED and game.auto_move.retries<=3,"被完全围住的真实任务对象有限失败，不走到墙另一侧")
		else:
			game.player.facing=Vector2.RIGHT;game.action_cooldown=0;UI.touch(self,game.hud.action_button);await frames(4)
		check(not game.hud.dialogue.visible and business()==before,"两种模式都不能隔着封闭墙开启任务或推进进度 "+mode)
		await capture("result")
		while game.hud.close_active_panel(): pass
