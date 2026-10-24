extends Node2D
## 只在建设等级变更时创建/清理碰撞；灯与花坛为轻量叠加，不在玩家脚下生出障碍。
var development_id: String = "board"
var level_applied: int = -1
var colliders: Array[StaticBody2D] = []
const WOOD := Color("a58b5f")
const DARK := Color("59604c")
func _ready() -> void:
	add_to_group("interactables")
	refresh()
func prompt() -> String:
	if development_id=="board": return "河湾长期共建 · 码头与社区"
	if development_id=="dock": return "岸边交易棚 · 接单与交货" if WorldDevelopment.state.dock==2 else "装卸码头 · 农渔补货"
	if development_id=="community": return "社区活动桌 · 傍晚交接值日"
	return "检查归路灯 · 每晚一次"
func hit_rect() -> Rect2:
	if development_id=="dock": return Rect2(-34,-104,148 if WorldDevelopment.state.dock==2 else 84,154)
	if development_id=="community" and WorldDevelopment.state.community==2: return Rect2(-92,-88,184,140)
	return Rect2(-20,-55,40,70) if not development_id.begins_with("lamp:") else Rect2(-13,-55,26,66)
func interact() -> void:
	if development_id.begins_with("lamp:"):
		if not WorldDevelopment.inspect_lamp(development_id.trim_prefix("lamp:")): Events.notice.emit("18:00–22:00到灯旁检查；每盏每天一次，需1体力。")
	else: Events.interaction_requested.emit("world_development:"+development_id)
func add_blocker(rect: Rect2) -> void:
	var body := StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=0
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=rect.size;shape.shape=box;body.add_child(shape)
	add_child(body);colliders.append(body)
func refresh() -> void:
	var level: int=WorldDevelopment.state.dock if development_id=="dock" else WorldDevelopment.state.community
	if development_id=="board": level=0
	if level_applied!=level:
		level_applied=level
		for body in colliders: body.collision_layer=0;body.queue_free()
		colliders.clear()
		if development_id=="dock" and level>0:
			add_blocker(Rect2(22,-76,20,14));add_blocker(Rect2(22,-44,20,14))
			if level==2: add_blocker(Rect2(56,-64,48,24))
		elif development_id=="community" and level==2: add_blocker(Rect2(-28,-9,56,18))
		Events.navigation_changed.emit()
	queue_redraw()
func _draw() -> void:
	if development_id=="board": draw_board();return
	if development_id=="dock": draw_dock();return
	if development_id=="community": draw_community();return
	draw_lamp()
func draw_board() -> void:
	for x in [-15,15]: draw_rect(Rect2(x-2,-9,4,24),DARK)
	draw_rect(Rect2(-25,-47,50,39),DARK);draw_rect(Rect2(-23,-45,46,35),Color("c6b17c"))
	var icon: Texture2D=load("res://assets/world_progress/development_sign.png")
	draw_texture_rect(icon,Rect2(-16,-43,32,32),false)
func draw_dock() -> void:
	var level: int=WorldDevelopment.state.dock
	if level<1: return
	# Planks stay at worldx944..992, entirely east of the original river's east bank x928.
	for y in range(-44,46,8): draw_rect(Rect2(-31,y,47,7),WOOD)
	for x in [-30,14]: draw_rect(Rect2(x,-47,3,96),DARK)
	for y in [-36,36]:
		draw_rect(Rect2(-32,y-6,5,10),Color("dbc696"))
		draw_line(Vector2(-30,y),Vector2(-52,y-8),Color("c4bc99"),1)
	for y in [-80,-48]:
		draw_rect(Rect2(19,y,26,22),DARK);draw_rect(Rect2(21,y+2,22,17),Color("b09a70"))
		draw_line(Vector2(21,y+2),Vector2(42,y+17),Color("7f7358"),2)
		draw_line(Vector2(42,y+2),Vector2(21,y+17),Color("7f7358"),2)
	var cargo_color: Color={"trade":Color("c6b36f"),"explore":Color("7bada7"),"life":Color("bd9777")}.get(Letters.direction,Color("afa17c"))
	draw_rect(Rect2(-16,-28,24,18),cargo_color)
	draw_rect(Rect2(-17,-30,26,4),DARK)
	if level==2:
		for x in [53,106]: draw_rect(Rect2(x,-78,4,62),DARK)
		draw_rect(Rect2(50,-84,62,18),Color("718b75"))
		draw_line(Vector2(48,-85),Vector2(113,-85),Color("b9b58a"),3)
		draw_rect(Rect2(56,-66,48,22),Color("927e5c"))
		for x in [62,77,92]: draw_rect(Rect2(x,-60,9,12),cargo_color)
		if Calendar.season()==3: draw_rect(Rect2(49,-88,64,3),Color("e1e7db"))
	draw_string(preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-33,-102),"岸边交易" if level==2 else "农渔装卸",HORIZONTAL_ALIGNMENT_LEFT,-1,13,FarmUIStyle.CREAM)
func draw_community() -> void:
	var level: int=WorldDevelopment.state.community
	if level<1: return
	for x in [-58,58]:
		draw_rect(Rect2(x-12,24,24,12),Color("827c58"))
		for i in [-7,0,7]:
			draw_line(Vector2(x+i,27),Vector2(x+i,19),Color("7da273"),1)
			draw_rect(Rect2(x+i-2,16,4,4),Color("e2c6a0") if Calendar.season()!=3 else Color("dce6d8"))
	if level==2:
		for x in [-80,80]: draw_rect(Rect2(x,-51,4,58),DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(-91,-57),Vector2(-64,-86),Vector2(64,-86),Vector2(91,-57)]),Color("6d8a79"))
		draw_line(Vector2(-91,-58),Vector2(91,-58),Color("b7b38b"),3)
		if Calendar.season()==3: draw_line(Vector2(-68,-88),Vector2(66,-88),Color("e3eadf"),3)
		draw_rect(Rect2(-36,-15,72,30),DARK);draw_rect(Rect2(-34,-17,68,25),Color("bcaa7d"))
		for x in [-20,0,20]:
			draw_circle(Vector2(x,-7),5,Color("d8d4ad"));draw_rect(Rect2(x-3,-12,6,4),Color("8b9c7a"))
		draw_rect(Rect2(-49,35,98,8),Color("9e8b63"))
		if WorldDevelopment.weekly_active():
			for x in [-62,62]: draw_rect(Rect2(x-4,-49,8,12),Color("e7cf8c"))
func draw_lamp() -> void:
	if WorldDevelopment.state.community<1: return
	var id := development_id.trim_prefix("lamp:")
	var checked: bool=int(WorldDevelopment.state.lamps[id])==GameClock.day
	var night: bool=GameClock.minutes>=1080 or GameClock.minutes<420
	if night: draw_circle(Vector2(0,-37),25,Color(1,.8,.42,.10 if checked else .055))
	draw_rect(Rect2(-2,-36,4,48),DARK);draw_rect(Rect2(-10,-51,20,5),Color("8c805e"))
	draw_rect(Rect2(-7,-46,14,18),Color("e4ca8e") if night else Color("bbba93"))
	for x in [-8,7]: draw_rect(Rect2(x,-47,2,21),DARK)
	draw_rect(Rect2(-9,-29,18,3),Color("8c805e"))
	if checked: draw_rect(Rect2(-2,2,4,4),Color("acc38b"))
