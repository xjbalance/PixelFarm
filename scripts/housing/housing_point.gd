extends Node2D
var housing_id: String="home"
func _ready() -> void:
	add_to_group("interactables")
func hit_rect() -> Rect2: return Rect2(-16,-26,32,42)
func prompt() -> String: return "家园装修与储物" if housing_id=="home" else "庭院布置台"
func interact() -> void:
	if is_instance_valid(Housing.game) and Housing.game.player.action_time>0: return
	Events.interaction_requested.emit("housing:"+housing_id)
func _draw() -> void:
	draw_rect(Rect2(-13,-18,26,23),Color("786247"));draw_rect(Rect2(-16,-23,32,7),Color("bda272"))
	draw_rect(Rect2(-10,-17,20,11),Color("dccb9f"));draw_line(Vector2(-7,-12),Vector2(6,-12),Color("74916f"),2)
	if housing_id=="home": draw_rect(Rect2(5,-21,5,4),Color("85a89d"))
