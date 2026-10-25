extends "res://tests/runner.gd"
## 仅验证点击、合法站位与单次交互；实际农场/村民/矿区业务规则继续由原模块处理。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary
var measurements: Dictionary={}

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true))
	initial=FarmSaveStore.snapshot(game)
	await ground_and_corners()
	await stop_at_interaction()
	await resource_and_plot_actions()
	await lake_and_entry()
	await input_lifecycle()
	await pending_intent_cancellation()
	await inactive_target()
	await mining()
	await inactive_ore()
	var suffix: String="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
	var output:=FileAccess.open("res://builds/touch-polish-metrics-"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measurements,"\t"));output.close()
	print("TOUCH POLISH METRICS ",JSON.stringify(measurements))
	print("TOUCH POLISH RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh(at: Vector2=Vector2(656,480), location: String="farm") -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	for index in game.touch_input.fingers.keys(): Touch.finger(self,Vector2.ZERO,false,index)
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	GameState.set_control_mode("tap",false);GameState.manual_tool=false
	game.tutorial.restore(GameTutorial.defaults(true))
	await Touch.place(self,game,location,at)
	var linya: Node2D=game.world.get_node("Actors/Linya")
	linya.position=Vector2(432,480);linya.route.clear()
	game.action_cooldown=0

func stopped(description: String) -> void:
	check(game.player.velocity==Vector2.ZERO and game.player.auto_direction==Vector2.ZERO and game.auto_move.path.is_empty(),description+"：真实速度/自动向量/路径清零")
	check(game.player.sprite.frame%4 in [0,2],description+"：使用待机帧而非持续走路")

func ground_and_corners() -> void:
	await fresh()
	Touch.tap(self,game,Vector2(656,496));await Touch.finish(self,game)
	check(game.player.position.distance_to(Vector2(656,496))<1.1,"近处地面按原32px格心规则准确停留")
	await frames(3);stopped("近处抵达")
	await fresh()
	Touch.tap(self,game,Vector2(304,496))
	var previous: Vector2=game.player.position
	var collision_free:=true
	var facing_sync:=true
	var max_step:=0.0
	for i in range(450):
		await frames(1)
		var displacement: Vector2=game.player.position-previous
		max_step=maxf(max_step,displacement.length());previous=game.player.position
		if displacement.length()>.1:
			var direction: Vector2=Vector2(signf(displacement.x),0) if absf(displacement.x)>absf(displacement.y) else Vector2(0,signf(displacement.y))
			facing_sync=facing_sync and game.player.facing==direction
		var query:=PhysicsShapeQueryParameters2D.new();query.shape=game.player.get_node("CollisionShape2D").shape
		query.transform=game.player.global_transform;query.collision_mask=1
		collision_free=collision_free and game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
		if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
	check(game.player.position.distance_to(Vector2(304,496))<1.1 and collision_free,"远处地面沿真实碰撞绕行后准确停止")
	check(max_step<=game.player.movement_speed()/60.0+.1,"长距离移动每帧位移有界，不瞬移补位置")
	check(facing_sync,"长距离真实位移方向与角色朝向同步")
	measurements["far_max_step_px"]=max_step
	await frames(3);stopped("远处抵达")
	await fresh(Vector2(530,336),"home")
	Touch.tap(self,game,Vector2(710,336));await Touch.finish(self,game,450)
	check(game.player.position.distance_to(Vector2(720,336))<1.1,"点击桌后地面绕过拐角抵达目标格")
	await frames(3);stopped("拐角抵达")
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,Vector2(850,300));await Touch.finish(self,game)
	check(game.auto_move.state==game.auto_move.State.FAILED and game.auto_move.execution_count==count,"不可达区域有限失败，不执行任何交互")
	await fresh(Vector2(656,480))
	Touch.tap(self,game,Vector2(784,496));await frames(6)
	Touch.tap(self,game,Vector2(592,496));await Touch.finish(self,game)
	check(game.player.position.distance_to(Vector2(592,496))<1.1,"新地面点击立即替换旧路径")

func stop_at_interaction() -> void:
	await fresh(Vector2(656,592))
	var npc: Node2D=game.world.get_node("Actors/Linya")
	npc.position=Vector2(880,592);npc.route.clear()
	await frames(3)
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,npc.position+Vector2(0,-20))
	var first_legal:=Vector2.INF
	var legal_frame: int=-1
	var end_frame: int=-1
	for i in range(400):
		await frames(1)
		if first_legal==Vector2.INF and game.auto_move.navigation.legal_interaction(game.player.global_position,{"kind":"object","object":npc,"point":npc.position}):
			first_legal=game.player.global_position;legal_frame=i
		if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: end_frame=i;break
	var tail: float=game.player.position.distance_to(first_legal) if first_legal!=Vector2.INF else INF
	measurements["npc_after_reach_px"]=tail
	measurements["npc_frames_after_reach"]=end_frame-legal_frame
	check(game.hud.dialogue.visible and game.auto_move.execution_count==count+1,"点击NPC靠近后执行一次原对话")
	check(first_legal!=Vector2.INF and tail<=game.player.movement_speed()/60.0+1.0,"首次进入合法NPC交互范围后及时停步，不再走向余下格心")
	check(end_frame-legal_frame<=2,"进入合法交互范围后至执行至多两物理帧")
	await frames(3);stopped("NPC交谈")
	game.hud.close_active_panel()
	await fresh(Vector2(832,592))
	npc.position=Vector2(880,592);npc.route.clear();await frames(3)
	var at: Vector2=game.player.position
	Touch.tap(self,game,npc.position+Vector2(0,-20));await Touch.finish(self,game)
	check(game.hud.dialogue.visible and game.player.position==at,"已在NPC合法范围内点击不额外迈一步")
	game.hud.close_active_panel()

func resource_and_plot_actions() -> void:
	await fresh(Vector2(624,592))
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false}}
	var count: int=game.auto_move.execution_count
	var energy: int=GameState.stamina
	Touch.tap(self,game,Vector2(656,592));await Touch.finish(self,game)
	var at: Vector2=game.player.position
	check(game.farm.plots["20,18"].watered and GameState.stamina==energy-1 and game.auto_move.execution_count==count+1,"点击农田只浇一次，体力只扣一次")
	var screen: Vector2=game.player.get_canvas_transform()*Vector2(656,592)
	Touch.finger(self,screen,false,20);Touch.finger(self,screen,false,20);await frames(4)
	check(GameState.stamina==energy-1 and game.auto_move.execution_count==count+1,"同手势多次释放不再次执行农活")
	var aligned:=true
	for i in range(18):
		await frames(1)
		aligned=aligned and absf(game.player.sprite.position.x)<.01
	check(aligned and game.player.position==at,"浇水期间及结束后精灵横向不累积偏移，脚底不漂移")
	Touch.tap(self,game,Vector2(688,592));await Touch.finish(self,game)
	check(game.farm.plots.has("21,18") and game.auto_move.execution_count==count+2,"浇水后下一块田合法翻土一次，无永久动作锁")
	await frames(20)
	Touch.tap(self,game,Vector2(784,496));await Touch.finish(self,game)
	check(game.player.position.distance_to(Vector2(784,496))<1.1,"工具动作结束后真实自动移动恢复")
	await fresh(Vector2(280,656))
	var tree: Node2D=game.world.resource_field.objects.tree_7_20
	var hp: int=game.world.resource_field.state.tree_7_20.hp
	count=game.auto_move.execution_count
	Touch.tap(self,game,tree.global_position+Vector2(0,-20));await Touch.finish(self,game)
	check(game.world.resource_field.state.tree_7_20.hp==hp-1 and game.auto_move.execution_count==count+1,"点击实体树木在合法站位采集一次")
	await frames(20)
	Touch.tap(self,game,tree.global_position+Vector2(0,-20));await Touch.finish(self,game)
	check(game.world.resource_field.state.tree_7_20.hp==hp-2,"同树第二次独立点击仍可合法再采一下")
	await fresh(Vector2(416,624))
	Touch.tap(self,game,Vector2(352,598));await Touch.finish(self,game)
	check(game.world.resource_field.state.rock_11_19.hp==1,"点击实体石堆合法靠近并只扣一击耐久")

func lake_and_entry() -> void:
	await fresh(Vector2(880,592))
	Touch.tap(self,game,Vector2(992,592));await Touch.finish(self,game)
	check(game.hud.aquaculture_panel.visible and game.player.position.distance_to(Aquaculture.SITES.pen_1)<=54,"点水中鱼栏使用岸边交互位置打开原管理界面")
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=game.player.get_node("CollisionShape2D").shape
	query.transform=game.player.global_transform;query.collision_mask=1
	check(game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"鱼栏交互后脚底仍在合法岸边，不进入水域碰撞")
	game.hud.close_active_panel()
	await fresh(Vector2(656,480))
	Touch.tap(self,game,Vector2(656,400));await Touch.finish(self,game)
	check(GameState.location=="home" and game.auto_move.target.is_empty(),"点击真实建筑入口自动接近并切图，清掉旧目标")

func input_lifecycle() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		await fresh(Vector2(656,480))
		var camera: Camera2D=game.player.get_node("Camera2D")
		camera.zoom=Vector2(1.6,1.6);camera.reset_smoothing();await frames(3)
		var selected:=Vector2(784,496)
		var screen: Vector2=game.player.get_canvas_transform()*selected
		Touch.finger(self,screen,true,31)
		game.player.position+=Vector2(70,0)
		await frames(8)
		Touch.finger(self,screen,false,31)
		check(game.auto_move.target.get("point",Vector2.INF).distance_to(selected)<.01,"相机跟随与1.6倍缩放中释放仍取按下世界点："+str(resolution))
		await Touch.finish(self,game)
		check(game.player.position.distance_to(selected)<1.1,"相机跟随点击最终抵达原格而非漂移格："+str(resolution))
	get_window().size=Vector2i(1280,720);await frames(4)
	await fresh()
	var count: int=game.auto_move.execution_count
	var at: Vector2=game.player.position
	load("res://tests/story.gd").touch(self,game.hud.tool_buttons[0]);await frames(4)
	check(game.player.position==at and game.auto_move.target.is_empty() and game.auto_move.execution_count==count,"UI工具栏真实触点不穿透到地图")
	var point: Vector2=game.player.get_canvas_transform()*Vector2(784,496)
	Touch.finger(self,point,true,32);Touch.finger(self,point+Vector2(20,0),true,33)
	Touch.finger(self,point,false,32);Touch.finger(self,point+Vector2(20,0),false,33)
	check(game.auto_move.target.is_empty() and game.auto_move.execution_count==count,"多指触摸不产生额外移动或交互任务")
	game.farm.plots.clear();GameState.manual_tool=false
	Touch.tap(self,game,Vector2(656,592));await frames(3)
	Touch.tap(self,game,Vector2(784,496));await Touch.finish(self,game)
	check(game.farm.plots.is_empty() and game.auto_move.execution_count==count,"新点击及时取消旧农田待执行意图")
	Touch.tap(self,game,Vector2(656,592));await frames(4)
	GameState.set_control_mode("joystick",false);await frames(20)
	check(game.hud.joystick.visible and game.auto_move.target.is_empty() and game.auto_move.execution_count==count,"切换备用摇杆立即取消自动移动和农田待执行意图")
	var joystick: Control=game.hud.joystick
	var center: Vector2=joystick.get_global_rect().get_center()
	Touch.finger(self,center+Vector2(40,0),true,34);await frames(4)
	check(game.player.touch_direction.x>.5,"备用摇杆在取消自动路径后仍可正常使用")
	Touch.finger(self,center,false,34)
	GameState.set_control_mode("tap",false)
	game.auto_move.request(Vector2(656,592));await frames(4)
	game.change_location("home");await frames(20)
	check(game.auto_move.target.is_empty() and game.farm.plots.is_empty(),"地图切换清除旧农田意图，之后不补执行")

func inactive_target() -> void:
	await fresh(Vector2(656,592))
	var object:=Node2D.new();object.set_script(load("res://scripts/world/interactable.gd"));object.kind="shop";object.position=Vector2(880,592)
	game.world.add_child(object);await frames(3)
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,object.position+Vector2(0,-20));await frames(4)
	object.hide();await frames(5)
	check(game.auto_move.target.is_empty() and game.player.auto_direction==Vector2.ZERO and game.auto_move.execution_count==count and not GameState.modal,"行走中目标失效及时停止，不执行幽灵交互")
	await frames(50)
	check(game.auto_move.marker_time==0,"失效目标短暂失败反馈结束后不残留目标计时")
	object.queue_free();await frames(3)

func pending_intent_cancellation() -> void:
	await fresh(Vector2(624,592))
	game.farm.plots.clear()
	var energy: int=GameState.stamina
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,Vector2(656,592))
	var screen: Vector2=game.player.get_canvas_transform()*Vector2(784,496)
	Touch.finger(self,screen,true,41);await frames(5)
	check(game.farm.plots.is_empty() and GameState.stamina==energy and game.auto_move.execution_count==count,"新世界触点按下期间旧农田意图立即取消，不等释放才阻止执行")
	Touch.finger(self,screen,false,41);await Touch.finish(self,game)
	check(game.player.position.distance_to(Vector2(784,496))<1.1 and game.farm.plots.is_empty(),"新触点释放只执行新地面目标，不补旧农活")
	await fresh(Vector2(624,592))
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false}}
	Touch.tap(self,game,Vector2(656,592))
	for _i in range(12): # 在动作起手时测试取消，而非等待整段农活结束。
		await frames(1)
		if game.player.action_time>0: break
	Touch.tap(self,game,Vector2(784,496))
	Input.action_press("move_left");await frames(2);Input.action_release("move_left")
	check(game.auto_move.target.is_empty(),"工具动画等待期间短按键盘也立即取消排队路径")
	await frames(24)
	check(game.player.position.distance_to(Vector2(624,592))<.1 and game.player.auto_direction==Vector2.ZERO,"短按取消后动画结束不自行恢复旧路径")

func mining() -> void:
	await fresh()
	load("res://tests/mining.gd").fresh_chapter(game)
	MineState.unlock("mine_a")
	await Touch.place(self,game,"mine_a",Vector2(176,656))
	var ore: Node2D=game.mine_maps.mine_a.objects.a_copper_0
	var hp: int=MineState.ore_state("a_copper_0").hp
	var count: int=game.auto_move.execution_count
	Touch.tap(self,game,ore.position+Vector2(0,-14));await Touch.finish(self,game)
	check(MineState.ore_state("a_copper_0").hp==hp-1 and game.auto_move.execution_count==count+1,"真实矿区点击矿石只采一次，保留工具与体力校验")
	await frames(20)
	Touch.tap(self,game,ore.position+Vector2(0,-14));await Touch.finish(self,game)
	check(MineState.ore_state("a_copper_0").hp==0,"矿石第二次独立点击合法采完，不被永久同目标去重")
	await frames(4);game.auto_move.navigation.rebuild()
	check(game.auto_move.navigation.walkable(Vector2i(4,19)),"矿石清除后原动态导航更新仍生效")

func inactive_ore() -> void:
	await fresh()
	load("res://tests/mining.gd").fresh_chapter(game);MineState.unlock("mine_a")
	await Touch.place(self,game,"mine_a",Vector2(240,688))
	var ore: Node2D=game.mine_maps.mine_a.objects.a_copper_0
	var origin: Vector2=game.player.position
	var count: int=game.auto_move.execution_count
	var energy: int=GameState.stamina
	Touch.tap(self,game,ore.position+Vector2(0,-14))
	MineState.state.ores.a_copper_0={"hp":0,"ready_day":GameClock.day+2}
	MineState.changed.emit()
	await frames(6)
	check(game.auto_move.target.is_empty() and game.auto_move.execution_count==count,"矿脉active失效后立即取消，不再到空矿脉执行一次交互")
	check(game.player.position.distance_to(origin)<.1 and GameState.stamina==energy,"矿脉失效后不多走、不扣体力或发放资源")
