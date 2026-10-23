extends Node2D
## 所有楼梯、机关、调查和宝箱共用原交互组；状态不存于场景节点。
var entry: Dictionary = {}
var mine_id: String = ""

func _ready() -> void:
	add_to_group("interactables")
	MineState.changed.connect(queue_redraw)
	Xiaojing.changed.connect(queue_redraw)
	if entry.get("kind","") in ["service","exit"]:
		var label := FarmUIStyle.label(str(entry.title),14,FarmUIStyle.GOLD)
		label.position=Vector2(-100,-76)
		label.size=Vector2(200,22)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(label)

func prompt() -> String:
	return str(entry.title)

func interact() -> void:
	Events.interaction_requested.emit("mine:"+mine_id)

func _draw() -> void:
	var kind: String=entry.get("kind","service")
	var color := Color("c3ac7d")
	if mine_id=="entrance":
		draw_rect(Rect2(-27,-57,54,59),Color("5e6260"))
		draw_rect(Rect2(-19,-49,38,51),Color("222d38"))
		for x in [-29,23]: draw_rect(Rect2(x,-60,7,62),Color("a58b65"))
		draw_rect(Rect2(-31,-63,62,8),Color("af946d"))
	elif kind=="exit":
		for i in range(4): draw_rect(Rect2(-18,-i*6,36,4),Color("a6aba0"))
	elif kind=="resonator":
		color=Color(["72b5cf","dfc27c","e0dced"][int(entry.symbol)])
		draw_circle(Vector2(0,-22),23,Color(color,.12))
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-18),Vector2(0,-47),Vector2(13,-18),Vector2(4,0),Vector2(-8,-2)]),color)
	elif kind=="star":
		var lit: bool=(int(Xiaojing.state.mechanism)&(1<<int(entry.symbol)))!=0 or "mechanism" in Xiaojing.state.trials
		draw_rect(Rect2(-7,-25,14,28),Color("9e956e"))
		draw_circle(Vector2(0,-28),9,Color("ffe3a1") if lit else Color("52647c"))
		if lit: draw_circle(Vector2(0,-28),22,Color(1,.86,.59,.12))
	elif kind=="chest":
		draw_rect(Rect2(-17,-24,34,24),Color("7a624f"))
		draw_rect(Rect2(-17,-24,34,5),Color("c5a16c"))
		draw_rect(Rect2(-3,-18,6,9),color if mine_id not in MineState.state.chests else Color("4e5551"))
	elif kind in ["rail","valve","hardened"]:
		draw_rect(Rect2(-13,-15,26,17),Color("687d7b"))
		var active: bool=MineState.state.track_switch==1 if kind=="rail" else (MineState.state.water_lowered if kind=="valve" else MineState.state.hardened)
		draw_line(Vector2.ZERO,Vector2(12 if active else -12,-34),Color("d0bb88"),5)
		draw_circle(Vector2(12 if active else -12,-34),5,Color("88c4b8"))
	elif kind=="memory":
		draw_rect(Rect2(-10,-16,20,17),Color("bacad0"))
		draw_rect(Rect2(-6,-13,12,3),Color("777e9a"))
	else:
		draw_rect(Rect2(-17,-35,34,26),Color("735f4d"))
		draw_rect(Rect2(-14,-32,28,19),color)
		draw_rect(Rect2(-2,-10,4,12),Color("806b52"))
		draw_line(Vector2(-10,-25),Vector2(9,-25),Color("5d6863"),2)
