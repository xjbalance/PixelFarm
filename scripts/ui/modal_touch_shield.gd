class_name ModalTouchShield
extends Control
## Child controls handle their touches first; blank popup space consumes the rest.
## Mouse picking already respects this Control's STOP filter and the overlay order.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;set_process_input(is_visible_in_tree())
func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event is InputEventScreenTouch or event is InputEventScreenDrag) and get_global_rect().has_point(event.position): get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED: set_process_input(is_visible_in_tree())
