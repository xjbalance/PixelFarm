extends Node2D
## 室内功能家具使用实际绘制范围命中；站位仍走原导航与邻位交互。
var home_action: String="nap"
var kind: String:
	get: return "sleep" if home_action=="sleep" else "home:nap"
func _ready() -> void: add_to_group("interactables")
func hit_rect() -> Rect2:
	return Rect2(14,-102,96,128) if home_action=="sleep" else Rect2(-44,-36,88,48)
func prompt() -> String:
	return "睡觉 · 20:00后睡到明早" if home_action=="sleep" else "沙发 · 小睡1小时 / 恢复50%体力"
func interact() -> void:
	Events.interaction_requested.emit("sleep" if home_action=="sleep" else "home:nap")
