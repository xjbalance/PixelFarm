extends Control
## 专用长按控制只认一根手指；松开/取消/切后台立即复位。
var held: bool = false
var finger: int = -1
var normal_style: StyleBoxFlat
var held_style: StyleBoxFlat
func _ready() -> void:
	normal_style=FarmUIStyle.box(FarmUIStyle.GREEN,FarmUIStyle.GOLD,10)
	held_style=FarmUIStyle.box(FarmUIStyle.GOLD,FarmUIStyle.GOLD,10)
	mouse_filter=Control.MOUSE_FILTER_STOP
	custom_minimum_size=Vector2(180,70)
	Events.modal_changed.connect(func(_active: bool): reset())
	GameState.control_mode_changed.connect(reset)
func reset() -> void:
	held=false;finger=-1;queue_redraw()
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): reset();return
	if event is InputEventScreenTouch:
		if event.pressed and finger==-1 and get_global_rect().has_point(event.position):
			finger=event.index;held=true;get_viewport().set_input_as_handled();queue_redraw()
		elif not event.pressed and event.index==finger:
			reset();get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position): held=true;get_viewport().set_input_as_handled();queue_redraw()
		elif not event.pressed and held: reset();get_viewport().set_input_as_handled()
func _draw() -> void:
	draw_style_box(held_style if held else normal_style,Rect2(Vector2.ZERO,size))
	var text := "收紧鱼线 ↑" if held else "按住上移 · 松开下移"
	draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(14,size.y*.5+7),text,HORIZONTAL_ALIGNMENT_CENTER,size.x-28,21,FarmUIStyle.INK if held else FarmUIStyle.CREAM)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: reset()
