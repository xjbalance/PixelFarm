extends Node
## 先记录全部原生触点，再交给 UI 消费。按下归属保持到释放，禁止关闭面板后的释放穿透。
var game: Node
var fingers: Dictionary = {}
var candidate: int = -1
var origin := Vector2.ZERO
var blocked: bool = false
var mouse_origin := Vector2.ZERO
var mouse_down: bool = false
var pressed_world := Vector2.ZERO
var mouse_pressed_world := Vector2.ZERO

func setup(owner_game: Node) -> void:
	game = owner_game
	Events.modal_changed.connect(func(_active: bool): reset())
	GameState.control_mode_changed.connect(reset)
	Events.location_changed.connect(func(_id: String): reset())

func reset() -> void:
	candidate = -1
	blocked = true
	mouse_down = false

func ui_at(point: Vector2, root: Node = null) -> bool:
	if root == null: root = game.hud.root
	if root is Control:
		if not root.is_visible_in_tree(): return false
		if root.clip_contents and not root.get_global_rect().has_point(point): return false
		if root.mouse_filter != Control.MOUSE_FILTER_IGNORE and root.get_global_rect().has_point(point): return true
	for child in root.get_children():
		if ui_at(point,child): return true
	return false

func world_point(screen: Vector2) -> Vector2:
	# event.position 已由 Viewport 换算到画布尺寸，不能再乘屏幕 DPI / stretch。
	return game.player.get_canvas_transform().affine_inverse()*screen

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# 同索引的重复 pressed 不能重启一次手势。
			if fingers.has(event.index):
				blocked = true
				return
			fingers[event.index] = event.position
			if fingers.size() == 1:
				blocked = GameState.modal or ui_at(event.position) or event.canceled
				candidate = event.index
				origin = event.position
				pressed_world=world_point(event.position)
			else: blocked = true
		else:
			fingers.erase(event.index)
			if event.index == candidate:
				var accept: bool = not blocked and not event.canceled and origin.distance_to(event.position)<12 and not ui_at(event.position)
				candidate = -1
				if accept and submit_world(pressed_world): get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == candidate and event.position.distance_to(origin)>12:
		blocked = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_origin = event.position
			mouse_pressed_world=world_point(event.position)
			mouse_down = fingers.is_empty() and not ui_at(event.position) and not GameState.modal
		else:
			var accept: bool = mouse_down and event.position.distance_to(mouse_origin)<12 and not ui_at(event.position)
			mouse_down = false
			if accept and submit_world(mouse_pressed_world): get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_down and event.position.distance_to(mouse_origin)>12:
		mouse_down = false

func submit(point: Vector2) -> bool:
	return submit_world(world_point(point))

func submit_world(point: Vector2) -> bool:
	if GameState.control_mode != "tap" or GameState.modal or game.backgrounded: return false
	game.auto_move.request(point)
	return true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		fingers.clear()
		reset()
