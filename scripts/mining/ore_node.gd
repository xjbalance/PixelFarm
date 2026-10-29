extends StaticBody2D
var entry: Dictionary = {}
var mine_id: String = ""
var collider: CollisionShape2D
var active: bool = true
var action_time: float = 0

func _ready() -> void:
	add_to_group("interactables")
	collision_layer=1
	collision_mask=0
	collider=CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(22,18)
	collider.shape=shape
	collider.position.y=-5
	add_child(collider)
	MineState.changed.connect(refresh)
	refresh()
	set_process(false)

func refresh() -> void:
	active=MineState.ore_state(mine_id).hp>0
	collider.set_deferred("disabled",not active)
	queue_redraw()

func prompt() -> String:
	return "%s · 镐等级%d · 耐久%d" % [entry.title,MineState.state.tool,MineState.ore_state(mine_id).hp] if active else "矿脉恢复中"

func interact() -> void:
	if (GameState.manual_tool or not Story.assisted_tools) and GameState.tool()!="pickaxe":
		GameState.manual_tool=false
		Events.notice.emit("矿脉需要使用镐。")
		return
	GameState.manual_tool=false
	if MineState.mine(mine_id):
		action_time=0.18
		set_process(true)

func _process(delta: float) -> void:
	action_time=maxf(0,action_time-delta)
	queue_redraw()
	if action_time==0: set_process(false)

func _draw() -> void:
	if not active:
		draw_rect(Rect2(-9,-2,6,3),Color("777d88"))
		return
	var shake: float=roundf(sin(action_time*65)*2) if action_time>0 else 0
	var color := Color(MineState.data.ores[entry.ore].color)
	draw_colored_polygon(PackedVector2Array([Vector2(-15+shake,0),Vector2(-18+shake,-12),Vector2(-7+shake,-28),Vector2(9+shake,-25),Vector2(18+shake,-10),Vector2(14+shake,1)]),Color("555967"))
	for p in [Vector2(-8,-17),Vector2(3,-22),Vector2(8,-8)]:
		draw_rect(Rect2(p+Vector2(shake,0),Vector2(7,9)),color)
		draw_rect(Rect2(p+Vector2(shake,0),Vector2(3,3)),color.lightened(.3))
