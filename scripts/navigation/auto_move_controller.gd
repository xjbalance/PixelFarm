extends Node2D
## 输入只提交意图；待执行操作在抵达后取出并清空，再调用原玩法一次。
enum State { IDLE, PATHFINDING, MOVING, IN_RANGE, INTERACTING, CANCELED, FAILED }
var state: State = State.IDLE
var game: Node
var navigation: WorldNavigation
var target: Dictionary = {}
var path := PackedVector2Array()
var cursor: int = 0
var retries: int = 0
var elapsed: float = 0
var since_plan: float = 0
var stalled: float = 0
var previous := Vector2.ZERO
var planned := Vector2.ZERO
var marker := Vector2.ZERO
var marker_time: float = 0
var marker_color := Color("ffe59a")
var execution_count: int = 0

func setup(owner_game: Node) -> void:
	game = owner_game
	navigation = WorldNavigation.new(game)
	# 在 Player 之前更新输入向量，同一物理帧由原 move_and_slide 执行。
	process_physics_priority = -10
	Events.modal_changed.connect(func(active: bool):
		if active: cancel()
	)
	GameState.control_mode_changed.connect(cancel)
	Events.tool_changed.connect(cancel)
	Events.location_changed.connect(func(_id: String): cancel(); navigation.invalidate())
	Events.navigation_changed.connect(func(): navigation.invalidate())

func cancel() -> void:
	state = State.CANCELED
	path.clear()
	target.clear()
	marker_time = 0
	queue_redraw()
	if game:
		game.player.auto_direction = Vector2.ZERO
		game.player.velocity = Vector2.ZERO
	state = State.IDLE

func request(point: Vector2) -> void:
	request_target(TouchInteractionResolver.resolve(game,point))

func request_target(intent: Dictionary) -> void:
	cancel()
	if GameState.modal or game.backgrounded or GameState.control_mode != "tap": return
	if intent.is_empty(): return
	if is_instance_valid(game.camera_rig): game.camera_rig.follow_now()
	target = intent.duplicate()
	marker = target.point
	marker_time = 0.7
	marker_color = Color("ffe59a") if target.kind=="ground" else Color("a5e3c6")
	retries = 0
	elapsed = 0
	stalled = 0
	previous = game.player.global_position
	state = State.PATHFINDING

func plan() -> void:
	game.player.auto_direction = Vector2.ZERO
	if not refresh_target(): return
	navigation.rebuild()
	planned = target.point
	path = navigation.path_to(target)
	cursor = 0
	since_plan = 0
	if path.is_empty(): fail()
	else: state = State.MOVING

func refresh_target() -> bool:
	if target.has("object"):
		if not is_instance_valid(target.object) or not target.object.is_visible_in_tree() or not navigation.active_collider(target.object):
			fail()
			return false
		if target.kind == "resource" and game.world.resource_field.state[target.object.resource_id].hp <= 0:
			fail()
			return false
		# 与初次点选的矿脉过滤一致：途中耗尽也立即清理目标与反馈。
		if ("mine_id" in target.object or "abyss_id" in target.object) and "active" in target.object and not target.object.active:
			cancel()
			Events.notice.emit("目标已改变，请重新点选。")
			return false
		target.point = target.object.global_position
	return true

func fail() -> void:
	Playtest.record("navigation_fail",{"source":GameState.location,"depth":AbyssState.state.depth if GameState.location=="abyss" else 0})
	var rejected: Vector2=target.get("point",marker)
	cancel()
	state = State.FAILED
	marker=rejected;marker_color=Color("ec9b86");marker_time=.7;queue_redraw()
	Events.notice.emit("暂时走不到那里，试试附近的空地。")

func _physics_process(delta: float) -> void:
	if marker_time > 0:
		marker_time = maxf(0,marker_time-delta)
		queue_redraw()
	if state==State.INTERACTING:
		if game.player.farm_action.is_empty(): state=State.IDLE
		return
	if state not in [State.PATHFINDING,State.MOVING]: return
	if GameState.modal or game.backgrounded or GameState.control_mode != "tap" or Input.get_vector("move_left","move_right","move_up","move_down").length() > 0.1:
		cancel()
		return
	if not refresh_target(): return
	if game.player.action_time>0:
		game.player.auto_direction=Vector2.ZERO
		return
	elapsed += delta
	if elapsed > 60:
		fail()
		return
	if state == State.PATHFINDING:
		if Engine.get_physics_frames() >= navigation.ready_frame: plan()
		return
	if target.has("object"): marker=target.point
	since_plan += delta
	if game.player.global_position.distance_to(previous) < 0.1: stalled += delta
	else: stalled = 0
	previous = game.player.global_position
	# 机关/碰撞变更先等物理同步和重规划，不能用旧网格提前交互。
	if navigation.dirty:
		game.player.auto_direction = Vector2.ZERO
		state = State.PATHFINDING
		return
	# 人物/物件一旦满足原距离与视线就停；农田保留原格心站位与脚前格对齐。
	if target.kind in ["object","resource"] and navigation.legal_interaction(game.player.global_position,target):
		finish_path()
		return
	# NPC 的正常移动不占用卡住重试额度；消失/换图则取消。
	var moving_target: bool = target.has("object") and target.point.distance_to(planned)>16
	if (since_plan > 0.35 and moving_target) or stalled > 0.65:
		if stalled > 0.65:
			retries += 1
			navigation.invalidate()
			if retries > 3:
				fail()
				return
		stalled = 0
		game.player.auto_direction = Vector2.ZERO
		state = State.PATHFINDING
		return
	while cursor < path.size() and game.player.global_position.distance_to(path[cursor]) < 1.0: cursor += 1
	if cursor >= path.size():
		if target.kind != "ground" and not navigation.legal_interaction(game.player.global_position,target):
			state = State.PATHFINDING
			return
		finish_path()
		return
	var offset: Vector2 = path[cursor]-game.player.global_position
	game.player.auto_direction = offset.normalized()*minf(1,offset.length()/(game.player.movement_speed()*delta))
	queue_redraw()

func finish_path() -> void:
	game.player.auto_direction = Vector2.ZERO
	game.player.velocity = Vector2.ZERO
	state = State.IN_RANGE
	var pending := target.duplicate()
	target.clear()
	path.clear()
	state = State.INTERACTING
	if pending.kind != "ground":
		execution_count += 1
		TouchInteractionExecutor.execute(game,pending,navigation)
	state = State.IDLE if game.player.farm_action.is_empty() else State.INTERACTING
	if marker_time > 0: marker_time = minf(marker_time,0.25)
	queue_redraw()

func _draw() -> void:
	var active: bool=state in [State.PATHFINDING,State.MOVING]
	if marker_time <= 0 and not active: return
	var tint := marker_color
	tint.a=maxf(.45 if active else 0.0,marker_time/.7)
	draw_arc(marker,11,0,TAU,24,tint,2)
	draw_circle(marker,2,tint)
