extends CharacterBody2D
## 键盘与独立触点摇杆共享同一移动向量；模态界面禁止移动和动作。
const SPEED: float = 145.0
var facing := Vector2.DOWN
var touch_direction := Vector2.ZERO
var animation_time: float = 0.0
@onready var sprite: Sprite2D = $Sprite2D
var action_time: float = 0

func _ready() -> void:
	add_to_group("farm_player")
	Events.farm_effect.connect(func(_origin: Vector2,_kind: String): action_time=0.24)

func _physics_process(delta: float) -> void:
	action_time = maxf(0,action_time-delta)
	var direction := Vector2.ZERO
	if not GameState.modal:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if touch_direction.length() > 0.08:
			direction = touch_direction
	if direction.length() > 0.05:
		if absf(direction.x) > absf(direction.y):
			facing = Vector2(signf(direction.x), 0)
		else:
			facing = Vector2(0, signf(direction.y))
	velocity = direction.limit_length() * SPEED
	move_and_slide()
	animation_time += delta
	var row: int = 0
	if facing == Vector2.LEFT: row = 1
	elif facing == Vector2.RIGHT: row = 2
	elif facing == Vector2.UP: row = 3
	var frame_index: int = int(animation_time * (9.0 if velocity.length() > 1.0 else 2.0)) % 4
	if velocity.length() < 1.0:
		frame_index = 0 if frame_index < 2 else 2
	sprite.frame = row * 4 + frame_index
	# 待机呼吸使用整数像素位移，避免像素贴图因子像素运动变模糊。
	sprite.position.y = -17.0 if velocity.length() < 1.0 and frame_index == 2 else -18.0
	if action_time > 0: sprite.position += facing*sin(action_time/0.24*PI)*3

func target_cell() -> Vector2i:
	return Vector2i(((global_position + facing * 27.0) / 32.0).floor())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touch_direction = Vector2.ZERO
