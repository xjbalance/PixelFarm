extends Node2D
## 研究温室保留在原农场地图；星灯跟随婚礼事务，不独立扣材料。
func _ready() -> void:
	Xiaojing.changed.connect(queue_redraw)

func _draw() -> void:
	if not Xiaojing.state.unlocked: return
	var built: bool = Xiaojing.state.greenhouse
	draw_rect(Rect2(-45,-65,90,67),Color("668c9144") if built else Color("9a8b6e44"))
	for x in [-46,0,44]: draw_line(Vector2(x,0),Vector2(x,-64),Color("bba77d"),4)
	for y in [-64,-32,0]: draw_line(Vector2(-46,y),Vector2(46,y),Color("bba77d"),3)
	draw_line(Vector2(-46,-64),Vector2(0,-92),Color("bba77d"),4)
	draw_line(Vector2(0,-92),Vector2(46,-64),Color("bba77d"),4)
	if built:
		for x in [-30,-10,12,30]:
			draw_rect(Rect2(x,-18,10,16),Color("799260"))
			draw_circle(Vector2(x+3,-51),3,Color("ffe5a0") if Xiaojing.state.married else Color("8b8c7b"))
	if Xiaojing.state.married: draw_circle(Vector2(0,-48),40,Color("ffe5a014"))
