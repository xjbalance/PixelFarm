extends Node2D
## 运行时读取家具记录；旧kind和默认坐标接口继续兼容。
var home_action: String="nap"
var builtin_id: String="sofa"
var kind: String:
	get: return "sleep" if home_action=="sleep" else "home:nap"
func _ready() -> void: add_to_group("interactables")
func hit_rect() -> Rect2: return HomeBuiltinTarget.hit_rect(self,builtin_id)
func interaction_colliders() -> Array[CollisionObject2D]: return HomeBuiltinTarget.colliders(self,builtin_id)
func prompt() -> String:
	return "睡觉 · 20:00后睡到明早" if home_action=="sleep" else "沙发 · 小睡1小时 / 恢复50%体力"
func interact() -> void:
	Events.interaction_requested.emit("sleep" if home_action=="sleep" else "home:nap")
