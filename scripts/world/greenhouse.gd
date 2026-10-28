extends Node2D
## 研究温室保留在原农场地图；星灯跟随婚礼事务，不独立扣材料。
func _ready() -> void:
	Xiaojing.changed.connect(queue_redraw)
	StarStory.changed.connect(queue_redraw)
	LegendState.changed.connect(queue_redraw)

func _draw() -> void:
	if not Xiaojing.state.unlocked: return
	var built: bool = Xiaojing.state.greenhouse or LegendState.state.greenhouse>=2
	if built:
		SchemeCAssets.draw(self,"greenhouse",Vector2.ZERO,-1,Vector2(.75,.75))
		if StarStory.has("vent_repaired"): draw_line(Vector2(-12,-74),Vector2(12,-78),Color("8abcaa"),3)
		if StarStory.has("history_solved"): draw_rect(Rect2(-9,-26,18,10),Color("ede1b2"))
		if LegendState.state.greenhouse>=3: SchemeCAssets.draw(self,"star_stele",Vector2(-47,0),-1,Vector2(.7,.7))
		if LegendState.state.greenhouse>=4: SchemeCAssets.draw(self,"star_lamp",Vector2(49,0),-1,Vector2(.7,.7))
		if Xiaojing.state.married:
			draw_circle(Vector2(0,-48),40,Color("ffe5a014"))
			var lamps:=PackedVector2Array()
			for i in range(1314):
				var at:=Vector2(-43+(i%44)*2,-62+int(i/44)*2)
				lamps.append(at);lamps.append(at+Vector2(.8,0))
			draw_multiline(lamps,Color("ffe8a840"),1)
		return
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

	if StarStory.has("vent_repaired"):
		draw_line(Vector2(-12,-80),Vector2(12,-85),Color("8abcaa"),3)
	if StarStory.has("history_solved"):
		draw_rect(Rect2(-9,-26,18,10),Color("ede1b2"))

	if LegendState.state.greenhouse>=3:
		draw_line(Vector2(-52,-4),Vector2(-52,-45),Color("85b8ca"),3)
	if LegendState.state.greenhouse>=4:
		draw_colored_polygon(PackedVector2Array([Vector2(34,-58),Vector2(39,-68),Vector2(44,-58),Vector2(39,-47)]),Color("b8a7eb"))
	if Xiaojing.state.married:
		# 1314个灯点一次批量绘制，不创建1314个节点/实时灯。
		var lamps := PackedVector2Array()
		for i in range(1314):
			var at := Vector2(-43+(i%44)*2,-62+int(i/44)*2)
			lamps.append(at)
			lamps.append(at+Vector2(.8,0))
		draw_multiline(lamps,Color("ffe8a880"),1)
