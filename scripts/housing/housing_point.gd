extends Node2D
var housing_id: String="home"
var builtin_id: String:
	get: return "storage" if housing_id=="home" else ""
func _ready() -> void:
	add_to_group("interactables")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func hit_rect() -> Rect2: return HomeBuiltinTarget.hit_rect(self,"storage") if housing_id=="home" else Rect2(-24,-42,48,56)
func interaction_colliders() -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D]=[]
	if housing_id=="home": result=HomeBuiltinTarget.colliders(self,"storage")
	return result
func prompt() -> String: return "家园装修与储物" if housing_id=="home" else "庭院布置台"
func interact() -> void:
	if is_instance_valid(Housing.game) and Housing.game.player.action_time>0: return
	Events.interaction_requested.emit("housing:"+housing_id)
func _draw() -> void:
	if housing_id=="home": return # 室内柜体由可移动家具渲染，不额外画固定管理台。
	SchemeCAssets.draw(self,"tool_rack",Vector2(0,7))
