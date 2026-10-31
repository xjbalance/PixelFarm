class_name TouchQuantitySlider
extends HSlider
var finger: int=-1
var initial_value: float=0
func _ready() -> void:
	set_process_input(is_visible_in_tree());texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("slider",FarmUIStyle.surface("track"))
	add_theme_stylebox_override("grabber_area",FarmUIStyle.surface("fill"))
	add_theme_stylebox_override("grabber_area_highlight",FarmUIStyle.surface("fill"))
	var pixels:=Image.create(16,24,false,Image.FORMAT_RGBA8);pixels.fill(FarmUIStyle.BROWN)
	pixels.fill_rect(Rect2i(2,2,12,20),FarmUIStyle.GOLD);pixels.fill_rect(Rect2i(3,3,3,17),FarmUIStyle.CREAM)
	var handle:=ImageTexture.create_from_image(pixels)
	for name in ["grabber","grabber_highlight","grabber_disabled"]: add_theme_icon_override(name,handle)
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not editable: finger=-1;return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and finger<0 and get_global_rect().has_point(event.position):
			finger=event.index;initial_value=value;drag_started.emit();update_touch(event.position);get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==finger:
			if not event.canceled: update_touch(event.position)
			finger=-1;drag_ended.emit(value!=initial_value);get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==finger:
		update_touch(event.position);get_viewport().set_input_as_handled()
func update_touch(point: Vector2) -> void:
	var fraction: float=clampf((point.x-get_global_rect().position.x-12)/maxf(1,size.x-24),0,1)
	value=roundf(min_value+fraction*(max_value-min_value))
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED: set_process_input(is_visible_in_tree());finger=-1
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: finger=-1
