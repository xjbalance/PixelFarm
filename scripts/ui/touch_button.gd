extends Button
## Godot 的鼠标触摸模拟只能代表一个手指；按钮直接接收独立触点。
var finger: int = -1
var press_origin := Vector2.ZERO

func _ready() -> void:
	Events.modal_changed.connect(func(_active: bool): finger = -1)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		finger = -1
		return
	if GameState.modal:
		var parent: Node = get_parent()
		while parent != null and not parent.is_in_group("modal_panels"):
			parent = parent.get_parent()
		if parent == null: return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and contains_touch(event.position):
			finger = event.index
			press_origin = event.position
			var ancestor := get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer and ancestor.has_method("begin_touch"): ancestor.begin_touch(event.index,event.position)
				ancestor = ancestor.get_parent()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			finger = -1
			var ancestor := get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer and ancestor.has_method("end_touch"): ancestor.end_touch(event.index)
				ancestor = ancestor.get_parent()
			# pressed 回调可能立即重建面板、移除本按钮；必须先标记事件再调用回调。
			get_viewport().set_input_as_handled()
			if contains_touch(event.position) and not event.canceled: pressed.emit()
	elif event is InputEventScreenDrag and event.index == finger and event.position.distance_to(press_origin) > 12:
		finger = -1

func contains_touch(point: Vector2) -> bool:
	if not get_global_rect().has_point(point): return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point): return false
		ancestor = ancestor.get_parent()
	return true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		finger = -1
