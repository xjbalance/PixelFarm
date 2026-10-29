extends Control
## 只拥有一个触点索引；其他手指可以同时点击工具和交互按钮。
signal direction_changed(direction: Vector2)
var finger: int = -1
var mouse_active: bool = false
var direction := Vector2.ZERO
const RADIUS: float = 66.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.modal_changed.connect(func(_active: bool): reset())

func _input(event: InputEvent) -> void:
	if GameState.modal or not is_visible_in_tree() or GameState.control_mode != "joystick":
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			mouse_active = true
			update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_active:
			reset()
	elif event is InputEventMouseMotion and mouse_active:
		update_direction(event.position)
		get_viewport().set_input_as_handled()

func update_direction(point: Vector2) -> void:
	direction = ((point - get_global_rect().get_center()) / RADIUS).limit_length()
	if direction.length() < 0.12:
		direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func reset() -> void:
	finger = -1
	mouse_active = false
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		reset()

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, RADIUS + 8, Color("233e3577"))
	draw_arc(center, RADIUS, 0, TAU, 48, Color("ead7a688"), 2, true)
	for angle in [0.0, PI / 2, PI, 3 * PI / 2]:
		var point := center + Vector2.from_angle(angle) * 51
		draw_circle(point, 3, Color("ead7a6bb"))
	draw_circle(center + direction * 43, 26, Color("eed9a9d9"))
	draw_circle(center + direction * 43, 19, Color("b9ad7be6"))
