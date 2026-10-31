extends Node2D
## 场景交互点仅发送语义事件；剧情条件由 Story 统一校验。
var actor_id: String = ""
var builtin_id: String=""
var title: String = ""
var prop_kind: String = ""

func _ready() -> void:
	add_to_group("interactables")
	if prop_kind != "":
		var prop := RiverScenery.new()
		prop.kind = prop_kind
		if prop_kind == "sign": prop.caption = "农场 ↓" if actor_id == "farm_return" else "河湾村 ↑"
		add_child(prop)
	Story.changed.connect(queue_redraw)
	queue_redraw()

func hit_rect() -> Rect2: return HomeBuiltinTarget.hit_rect(self,builtin_id) if builtin_id!="" else Rect2(-34,-65,68,88)
func task_marker_rect() -> Rect2:
	var target: Array=Story.chapter().target
	var active: bool=(position.distance_to(Vector2(target[0],target[1]))<24 or (builtin_id=="mail_desk" and Story.stage==0)) and Story.stage<8
	return Rect2(-12,-89,24,26) if active else Rect2()
func interaction_colliders() -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D]=[]
	if builtin_id!="": result=HomeBuiltinTarget.colliders(self,builtin_id)
	return result

func prompt() -> String:
	return title

func interact() -> void:
	if actor_id == "mail" and Xiaojing.state.letter_ready: Events.interaction_requested.emit("xiaojing_letter")
	elif actor_id == "village": Events.interaction_requested.emit("village")
	elif actor_id == "farm_return": Events.interaction_requested.emit("farm_return")
	elif actor_id == "community": Events.interaction_requested.emit("community")
	else: Story.request(actor_id)

func _draw() -> void:
	if task_marker_rect().has_area():
		draw_colored_polygon(PackedVector2Array([Vector2(0,-83),Vector2(6,-76),Vector2(0,-69),Vector2(-6,-76)]),Color("f6d387"))
