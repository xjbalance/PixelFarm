extends Node2D
var river_id: String=""
var title: String=""
var person_id: String=""
func _ready() -> void:
	add_to_group("interactables")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if person_id=="xiaojing": add_to_group("xiaojing")
func prompt() -> String: return title
func interact() -> void:
	Events.interaction_requested.emit("river:"+river_id)
func _draw() -> void:
	if person_id!="": return
	SchemeCAssets.draw(self,"road_sign",Vector2(0,3))
