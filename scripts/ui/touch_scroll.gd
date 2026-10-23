extends ScrollContainer
## 不开启触摸模拟鼠标；长手记以独立触点驱动滚动，保留系统鼠标滚轮行为。
var finger: int = -1
var origin := Vector2.ZERO
var initial_scroll: int = 0

func _ready() -> void:
	Events.modal_changed.connect(func(_active: bool): finger = -1)

func begin_touch(index: int,point: Vector2) -> void:
	if finger != -1 or not is_visible_in_tree() or not get_global_rect().has_point(point): return
	finger = index
	origin = point
	initial_scroll = scroll_vertical

func end_touch(index: int) -> void:
	if finger == index: finger = -1

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		finger = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed: begin_touch(event.index,event.position)
		elif event.index == finger: finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		if event.position.distance_to(origin) > 10:
			scroll_vertical = initial_scroll-roundi(event.position.y-origin.y)
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: finger = -1
