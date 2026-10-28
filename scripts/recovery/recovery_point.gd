extends Node2D
var kind: String="recovery"
func _ready() -> void:
	add_to_group("interactables");texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func hit_rect() -> Rect2: return Rect2(-28,-27,56,42)
func prompt() -> String: return "休息椅 · 体力恢复"
func interact() -> void: Events.interaction_requested.emit("recovery")
func _draw() -> void:
	SchemeCAssets.draw(self,"wood_bench",Vector2(0,8))
