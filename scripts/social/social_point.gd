extends Node2D
var site_id: String=""
func _ready() -> void:
	add_to_group("interactables");Social.changed.connect(refresh);FarmLayout.changed.connect(refresh);Housing.changed.connect(refresh);refresh()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func refresh() -> void:
	var fixture: String=Social.site_fixture(site_id)
	if fixture!="": set_meta("farm_fixture",fixture)
	position=Social.site_point(site_id)
	visible=false
	if not Social.site_active(site_id): return
	for active in Social.state.active.values():
		var quest: Dictionary=Social.definition(active.id)
		if quest.goals.has("site:"+site_id) and int(active.counts.get("site:"+site_id,0))<int(quest.goals["site:"+site_id]): visible=true
	queue_redraw()
func prompt() -> String: return "个人约定 · 现场观察"
func interact() -> void: Events.interaction_requested.emit("social_site:"+site_id)
func _draw() -> void:
	SchemeCAssets.draw(self,"notice_board",Vector2(0,3),-1,Vector2(.625,.625))
