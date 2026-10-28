extends Node2D
var kitchen_id: String="kitchen"
var builtin_id: String:
	get: return "kitchen" if kitchen_id=="kitchen" else ""
func _ready() -> void:
	add_to_group("interactables")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	Kitchen.changed.connect(queue_redraw)
	Calendar.changed.connect(queue_redraw)

func prompt() -> String:
	return "采摘野莓 · 每日一次" if kitchen_id=="berry" else "做饭 · 家庭厨房"
func hit_rect() -> Rect2: return HomeBuiltinTarget.hit_rect(self,"kitchen") if kitchen_id=="kitchen" else Rect2(-25,-36,50,48)
func interaction_colliders() -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D]=[]
	if kitchen_id=="kitchen": result=HomeBuiltinTarget.colliders(self,"kitchen")
	return result
func interact() -> void:
	Events.interaction_requested.emit("kitchen:berry" if kitchen_id=="berry" else "kitchen")
func _draw() -> void:
	if kitchen_id=="berry":
		SchemeCAssets.draw(self,"bush",Vector2.ZERO,Calendar.season())
		if Kitchen.state.berry_day!=GameClock.day:
			for at in [Vector2(-13,-16),Vector2(6,-25),Vector2(13,-9)]: draw_rect(Rect2(at,Vector2(4,4)),Color("bd7b85"))
		return
	var ready := 0
	for job in Kitchen.state.queue:
		if job.ready: ready+=1
	if ready>0:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-74),Vector2(5,-69),Vector2(0,-64),Vector2(-5,-69)]),Color("eed58c"))
