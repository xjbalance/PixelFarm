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
	if game:
		game.player.auto_direction = Vector2.ZERO
		game.player.velocity = Vector2.ZERO
	state = State.IDLE

func request(point: Vector2) -> void:
	cancel()
	if GameState.modal or game.backgrounded or GameState.control_mode != "tap": return
	target = TouchInteractionResolver.resolve(game,point)
	marker = target.point
	marker_time = 0.7
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
		target.point = target.object.global_position
	return true

func fail() -> void:
	cancel()
	state = State.FAILED
	Events.notice.emit("暂时走不到那里，试试附近的空地。")

func _physics_process(delta: float) -> void:
	marker_time = maxf(0,marker_time-delta)
	queue_redraw()
	if state not in [State.PATHFINDING,State.MOVING]: return
	if GameState.modal or game.backgrounded or GameState.control_mode != "tap" or Input.get_vector("move_left","move_right","move_up","move_down").length() > 0.1:
		cancel()
		return
	elapsed += delta
	if elapsed > 60:
		fail()
		return
	if state == State.PATHFINDING:
		if Engine.get_physics_frames() >= navigation.ready_frame: plan()
		return
	if not refresh_target(): return
	since_plan += delta
	if game.player.global_position.distance_to(previous) < 0.1: stalled += delta
	else: stalled = 0
	previous = game.player.global_position
	# NPC 的正常移动不占用卡住重试额度；消失/换图则取消。
	var moving_target: bool = target.has("object") and target.point.distance_to(planned)>16
	if navigation.dirty or (since_plan > 0.35 and moving_target) or stalled > 0.65:
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
		state = State.IDLE
		return
	var offset: Vector2 = path[cursor]-game.player.global_position
	game.player.auto_direction = offset.normalized()*minf(1,offset.length()/(game.player.SPEED*delta))

func _draw() -> void:
	if marker_time <= 0: return
	draw_arc(marker,11,0,TAU,24,Color(1,.85,.45,marker_time/0.7),2)
	draw_circle(marker,2,Color("fff0b6"))
