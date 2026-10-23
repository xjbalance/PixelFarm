extends Node2D
var river_id: String=""
var title: String=""
var person_id: String=""
func _ready() -> void:
	add_to_group("interactables")
	if person_id=="xiaojing": add_to_group("xiaojing")
func prompt() -> String: return title
func interact() -> void:
	Events.interaction_requested.emit("river:"+river_id)
func _draw() -> void:
	if person_id!="": return
	draw_rect(Rect2(-12,-20,24,22),Color("ac9470"))
	draw_rect(Rect2(-9,-17,18,8),Color("ece0b5"))
