extends Button
## 每次原生触点只在同一可见按钮内完成一次短点；滚动、隐藏与后台会取消。
var finger: int = -1
var press_origin := Vector2.ZERO

func _ready() -> void:
	set_process_input(is_visible_in_tree())
	Events.modal_changed.connect(func(_active: bool): reset_touch())
	GameState.control_mode_changed.connect(reset_touch)

func reset_touch() -> void:
	var previous := finger
	finger = -1
	if previous != -1:
		var ancestor := get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer and ancestor.has_method("end_touch"): ancestor.end_touch(previous)
			ancestor = ancestor.get_parent()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		reset_touch()
		return
	if GameState.modal:
		var parent: Node = get_parent()
		while parent != null and not parent.is_in_group("modal_panels"):
			parent = parent.get_parent()
		if parent == null:
			reset_touch()
			return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and finger == -1 and contains_touch(event.position):
			finger = event.index
			queue_redraw()
			press_origin = event.position
			var ancestor := get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer and ancestor.has_method("begin_touch"): ancestor.begin_touch(event.index,event.position)
				ancestor = ancestor.get_parent()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			var accepted: bool = contains_touch(event.position) and not event.canceled and press_origin.distance_to(event.position) <= UIMetrics.drag_threshold()
			reset_touch()
			# 回调可重建面板、移除按钮，先标记本事件，再调用一次。
			get_viewport().set_input_as_handled()
			if accepted: pressed.emit()
	elif event is InputEventScreenDrag and event.index == finger and event.position.distance_to(press_origin) > UIMetrics.drag_threshold():
		# 不终止祖先滚动；它继续消费本次拖动直至手指释放。
		finger = -1
		queue_redraw()

func _draw() -> void:
	if finger != -1 and is_visible_in_tree() and not disabled:
		draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("edcc81"),false,2)

func contains_touch(point: Vector2) -> bool:
	if not get_global_rect().has_point(point): return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point): return false
		ancestor = ancestor.get_parent()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED: set_process_input(is_visible_in_tree())
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_VISIBILITY_CHANGED]:
		reset_touch()
