extends Node2D
var site_id: String=""
func _ready() -> void:
	add_to_group("interactables");Social.changed.connect(refresh);refresh()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func refresh() -> void:
	visible=false
	for active in Social.state.active.values():
		var quest: Dictionary=Social.definition(active.id)
		if quest.goals.has("site:"+site_id) and int(active.counts.get("site:"+site_id,0))<int(quest.goals["site:"+site_id]): visible=true
	queue_redraw()
func prompt() -> String: return "个人约定 · 现场观察"
func interact() -> void: Events.interaction_requested.emit("social_site:"+site_id)
func _draw() -> void:
	SchemeCAssets.draw(self,"notice_board",Vector2(0,3),-1,Vector2(.625,.625))
