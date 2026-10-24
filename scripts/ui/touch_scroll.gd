extends ScrollContainer
## 不开启鼠标模拟；一根触点驱动滚动，关闭/换模式/切后台即取消。
var finger: int = -1
var origin := Vector2.ZERO
var initial_scroll: int = 0

func _ready() -> void:
	set_process_input(is_visible_in_tree())
	Events.modal_changed.connect(func(_active: bool): reset_touch())
	GameState.control_mode_changed.connect(reset_touch)

func reset_touch() -> void:
	finger = -1

func begin_touch(index: int,point: Vector2) -> void:
	if finger != -1 or not is_visible_in_tree() or not get_global_rect().has_point(point): return
	# 同时满足祖先裁剪，不能在被遮住的面板边缘抢走触点。
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point): return
		ancestor = ancestor.get_parent()
	finger = index
	origin = point
	initial_scroll = scroll_vertical

func end_touch(index: int) -> void:
	if finger == index: reset_touch()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		reset_touch()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: begin_touch(event.index,event.position)
		elif event.index == finger: reset_touch()
	elif event is InputEventScreenDrag and event.index == finger:
		if event.position.distance_to(origin) > 10:
			scroll_vertical = initial_scroll-roundi(event.position.y-origin.y)
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED: set_process_input(is_visible_in_tree())
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_VISIBILITY_CHANGED]: reset_touch()
