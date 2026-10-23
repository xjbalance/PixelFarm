extends Node2D
## 可交互的修缮台和委托板使用原创像素几何；升级后外观同步改变。
@export var kind: String = "workshop"

func _ready() -> void:
	add_to_group("interactables")
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52,20)
	collider.position.y = -21
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	FarmProgress.changed.connect(queue_redraw)
	queue_redraw()

func prompt() -> String:
	return "查看河谷委托" if kind == "board" else "修缮农场设施"

func interact() -> void:
	Events.interaction_requested.emit(kind)

func _draw() -> void:
	draw_rect(Rect2(-29,-4,60,10),Color("3e573944"))
	if kind == "board":
		draw_rect(Rect2(-22,-32,6,35),Color("78583d"))
		draw_rect(Rect2(16,-32,6,35),Color("78583d"))
		draw_rect(Rect2(-32,-65,64,42),Color("7d5e43"))
		draw_rect(Rect2(-28,-61,56,34),Color("c59c64"))
		for x in [-20,-2,14]:
			draw_rect(Rect2(x,-55,12,21),Color("f1deae"))
			draw_rect(Rect2(x+3,-51,6,2),Color("778e63"))
	else:
		draw_rect(Rect2(-23,-28,7,30),Color("77573d"))
		draw_rect(Rect2(16,-28,7,30),Color("77573d"))
		draw_rect(Rect2(-31,-35,62,14),Color("b38c56"))
		draw_rect(Rect2(-31,-35,62,4),Color("dec18a"))
		draw_rect(Rect2(-22,-43,28,8),Color("e1d6b3"))
		draw_rect(Rect2(12,-46,5,18),Color("806048"))
		draw_rect(Rect2(8,-46,16,6),Color("8fa49c"))
		if FarmProgress.has_upgrade("toolrack"):
			draw_rect(Rect2(-28,-66,56,4),Color("dcbe7f"))
			for x in [-20,-2,18]: draw_rect(Rect2(x,-63,5,19),Color("9baea4"))
		if FarmProgress.has_upgrade("irrigation"):
			draw_rect(Rect2(35,-31,22,31),Color("9b754e"))
			draw_rect(Rect2(37,-28,18,6),Color("7cbeb5"))
