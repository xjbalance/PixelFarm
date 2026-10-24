extends Node2D
var site_id: String=""
func _ready() -> void:
	add_to_group("interactables");Social.changed.connect(refresh);refresh()
func refresh() -> void:
	visible=false
	for active in Social.state.active.values():
		var quest: Dictionary=Social.definition(active.id)
		if quest.goals.has("site:"+site_id) and int(active.counts.get("site:"+site_id,0))<int(quest.goals["site:"+site_id]): visible=true
	queue_redraw()
func prompt() -> String: return "个人约定 · 现场观察"
func interact() -> void: Events.interaction_requested.emit("social_site:"+site_id)
func _draw() -> void:
	draw_rect(Rect2(-7,-17,15,17),Color("876c52"));draw_rect(Rect2(-5,-15,11,13),Color("dbcca4"))
	for y in [-12,-8,-4]: draw_line(Vector2(-3,y),Vector2(4,y),Color("8c9273"),1)
	draw_line(Vector2(-7,-18),Vector2(7,-18),Color("bb9b68"),2)
