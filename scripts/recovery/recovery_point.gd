extends Node2D
var kind: String="recovery"
func _ready() -> void: add_to_group("interactables")
func hit_rect() -> Rect2: return Rect2(-27,-26,54,30)
func prompt() -> String: return "休息椅 · 体力恢复"
func interact() -> void: Events.interaction_requested.emit("recovery")
func _draw() -> void:
	for x in [-20,16]: draw_rect(Rect2(x,0,5,10),Color("5b5444"))
	draw_rect(Rect2(-25,-12,50,8),Color("b99865"))
	draw_rect(Rect2(-25,-21,50,6),Color("c7aa79"))
	draw_rect(Rect2(-23,-8,46,6),Color("a98757"))
