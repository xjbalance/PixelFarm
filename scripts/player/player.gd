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

func _ready() -> void:
	add_to_group("farm_player")
	Events.farm_effect.connect(func(_origin: Vector2,_kind: String):
		action_time=0.24;action_kind=_kind;action_facing=facing;auto_direction=Vector2.ZERO;velocity=Vector2.ZERO
	)

func _physics_process(delta: float) -> void:
	action_time = maxf(0,action_time-delta)
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
	if action_time > 0 and action_kind!="浇水": sprite.position += action_facing*sin(action_time/0.24*PI)*3

func movement_speed() -> float:
	return SPEED*Kitchen.speed_multiplier()

func target_cell() -> Vector2i:
	return Vector2i(((global_position + facing * 27.0) / 32.0).floor())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touch_direction = Vector2.ZERO
		auto_direction = Vector2.ZERO
