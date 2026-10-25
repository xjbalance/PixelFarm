extends CharacterBody2D
## 键盘与独立触点摇杆共享同一移动向量；模态界面禁止移动和动作。
const SPEED: float = 145.0
var facing := Vector2.DOWN
var touch_direction := Vector2.ZERO
var auto_direction := Vector2.ZERO
var animation_time: float = 0.0
@onready var sprite: Sprite2D = $Sprite2D
var action_time: float = 0
var action_facing := Vector2.DOWN
var action_kind: String=""
var suspended: bool = false
const FARM_DURATION: float = 0.24
const FARM_IMPACT: float = 0.10
const FARM_KINDS := ["翻土","播种","浇水","收获"]
var farm_action: Dictionary = {}
var farm_visual: Node2D

func _ready() -> void:
	add_to_group("farm_player")
	farm_visual=preload("res://scripts/farming/tool_action_visual.gd").new()
	add_child(farm_visual)
	Events.farm_effect.connect(func(_origin: Vector2,_kind: String):
		if farm_action.is_empty(): start_action(_kind)
	)
	Events.tool_changed.connect(cancel_farm_action)
	Events.modal_changed.connect(func(active: bool):
		if active: cancel_farm_action()
	)
	Events.location_changed.connect(func(_id: String): cancel_farm_action())
	GameState.control_mode_changed.connect(cancel_farm_action)
	GameClock.day_ending.connect(func(_reason: String): cancel_farm_action())

func start_action(kind: String) -> void:
	action_time=0.24;action_kind=kind;action_facing=facing;auto_direction=Vector2.ZERO;velocity=Vector2.ZERO

func begin_farm_action(farm: Node, cell: Vector2i, tool: String) -> bool:
	if not farm_action.is_empty() or action_time>0 or suspended or GameState.modal or GameState.restoring or GameState.location!="farm": return false
	var target:=Vector2(cell)*32+Vector2(16,16)
	if global_position.distance_to(target)>38 or not farm.can_use_tool(cell,tool): return false
	var offset:=target-global_position
	if offset.length_squared()>.001:
		facing=Vector2(signf(offset.x),0) if absf(offset.x)>absf(offset.y) else Vector2(0,signf(offset.y))
	var kind: String="播种" if tool.ends_with("_seed") else {"hoe":"翻土","water":"浇水","hand":"收获"}.get(tool,"")
	start_action(kind)
	farm_action={"farm":farm,"cell":cell,"tool":tool,"day":GameClock.day,"elapsed":0.0,"committed":false,"facing":facing,"origin":global_position}
	farm_visual.display(tool,facing,to_local(target),0.0,FARM_DURATION,FARM_IMPACT)
	return true

func cancel_farm_action() -> void:
	if farm_action.is_empty(): return
	farm_action.clear()
	action_time=0;auto_direction=Vector2.ZERO;velocity=Vector2.ZERO
	if is_instance_valid(farm_visual): farm_visual.clear()
	if is_instance_valid(sprite): sprite.position=Vector2(0,-18)

func advance_farm_action(delta: float) -> void:
	if GameState.modal or GameState.restoring or GameState.location!="farm" or GameClock.day!=int(farm_action.day) or global_position.distance_to(farm_action.origin)>.1:
		cancel_farm_action();return
	farm_action.elapsed=float(farm_action.elapsed)+delta
	facing=farm_action.facing;action_facing=facing
	action_time=maxf(0,FARM_DURATION-float(farm_action.elapsed))
	if not farm_action.committed and float(farm_action.elapsed)+.000001>=FARM_IMPACT:
		# 先锁住本次生效标记；信号重入/重复物理帧不能再次提交。
		farm_action.committed=true
		var ok: bool=farm_action.farm.use_tool(farm_action.cell,farm_action.tool)
		if not ok: cancel_farm_action();return
		if farm_action.is_empty(): return # 成功剧情可能开启模态，已生效结果不回滚。
	if action_time<=0:
		cancel_farm_action();return
	var target:=Vector2(farm_action.cell)*32+Vector2(16,16)
	farm_visual.display(farm_action.tool,facing,to_local(target),float(farm_action.elapsed),FARM_DURATION,FARM_IMPACT)

func _physics_process(delta: float) -> void:
	if suspended:
		cancel_farm_action()
		velocity=Vector2.ZERO
		return
	if not farm_action.is_empty(): advance_farm_action(delta)
	else: action_time = maxf(0,action_time-delta)
	var direction := Vector2.ZERO
	if not GameState.modal and action_time<=0:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction.length() < 0.05: direction = auto_direction
		if GameState.control_mode == "joystick" and touch_direction.length() > 0.08:
			direction = touch_direction
	if direction.length() > 0.05:
		if absf(direction.x) > absf(direction.y):
			facing = Vector2(signf(direction.x), 0)
		else:
			facing = Vector2(0, signf(direction.y))
	velocity = direction.limit_length() * movement_speed()
	move_and_slide()
	animation_time += delta
	var row: int = 0
	if facing == Vector2.LEFT: row = 1
	elif facing == Vector2.RIGHT: row = 2
	elif facing == Vector2.UP: row = 3
	var frame_index: int = int(animation_time * (9.0 if velocity.length() > 1.0 else 2.0)) % 4
	if velocity.length() < 1.0:
		frame_index = 0 if frame_index < 2 else 2
	if action_time>0: frame_index=0
	sprite.frame = row * 4 + frame_index
	# 待机呼吸使用整数像素位移，避免像素贴图因子像素运动变模糊。
	sprite.position = Vector2(0,-17.0 if velocity.length() < 1.0 and frame_index == 2 else -18.0)
	# 从固定原点计算反馈，不能逐帧累加水平偏移。工具动作期间朝向与脚底保持稳定。
	if action_time > 0 and action_kind not in FARM_KINDS: sprite.position += action_facing*sin(action_time/0.24*PI)*3

func movement_speed() -> float:
	return SPEED*Kitchen.speed_multiplier()

func target_cell() -> Vector2i:
	return Vector2i(((global_position + facing * 27.0) / 32.0).floor())

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		cancel_farm_action()
		touch_direction = Vector2.ZERO
		auto_direction = Vector2.ZERO
