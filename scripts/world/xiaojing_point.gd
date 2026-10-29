extends Node2D
var memory_id: String = ""
var title: String = ""

func _ready() -> void:
	add_to_group("interactables")
	Xiaojing.changed.connect(refresh)
	refresh()

func refresh() -> void:
	visible = Xiaojing.state.unlocked
	queue_redraw()

func prompt() -> String:
	return "查看"+title

func interact() -> void:
	Events.interaction_requested.emit("xiaojing_memory:"+memory_id)

func _draw() -> void:
	draw_rect(Rect2(-9,-12,18,14),Color("c5aa7e"))
	draw_rect(Rect2(-7,-10,14,2),Color("eee0b9"))
	draw_rect(Rect2(-4,-6,8,2),Color("668c91"))
