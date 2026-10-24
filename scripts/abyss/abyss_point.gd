extends StaticBody2D
var abyss_id: String=""
var kind: String="note"
var symbol: int=0
var active: bool=true
var collision: CollisionShape2D
func _ready() -> void:
	add_to_group("interactables")
	collision_layer=1 if kind=="ore" else 0
	collision_mask=0
	if kind=="ore":
		collision=CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size=Vector2(22,18)
		collision.shape=shape
		add_child(collision)
	AbyssState.changed.connect(refresh)
	refresh()
func refresh() -> void:
	if kind=="ore":
		active=int(AbyssState.state.ores.get("%d:%d" % [AbyssState.state.depth,symbol],3))>0
		collision.set_deferred("disabled",not active)
	queue_redraw()
func prompt() -> String:
	return {"passage":"侧廊支架 · 可选捷径","entrance":"深渊升降机","up":"升降绳与营地","down":"下层通道","note":"读本层巡检刻痕","chest":"遗留补给匣","lever":"转动%s手柄" % ["风","水","灯","人"][symbol],"ore":"深层矿脉 · 星纹镐","utility":AbyssRules.utility_title(symbol),"core":"星核档案与共享规则","conduit":"校准星灯回路"}.get(kind,"勘探")
func interact() -> void:
	if kind=="ore":
		if (GameState.manual_tool or not Story.assisted_tools) and GameState.tool()!="pickaxe":
			GameState.manual_tool=false
			Events.notice.emit("请先选择镐。")
			return
		GameState.manual_tool=false
		AbyssState.mine(symbol)
	elif kind=="utility": AbyssRules.utility(symbol)
	elif kind=="core": Events.interaction_requested.emit("river:star_core")
	elif kind=="lever": AbyssState.operate(symbol)
	elif kind=="down": AbyssState.descend()
	elif kind=="chest": AbyssState.chest()
	else: Events.interaction_requested.emit("abyss:"+kind)
func _draw() -> void:
	if kind=="ore":
		if active:
			draw_circle(Vector2(0,-10),15,Color("626577"))
			for x in [-8,2]: draw_rect(Rect2(x,-25,7,18),Color("b8a5d9") if AbyssState.state.depth>=16 else Color("8cbfbd"))
		else: draw_rect(Rect2(-8,-2,16,3),Color("787c87"))
	elif kind in ["up","down","entrance"]:
		for i in range(4): draw_rect(Rect2(-17,-i*7,34,4),Color("b5b49b"))
		draw_line(Vector2(-21,0),Vector2(-21,-45),Color("ad9773"),3)
	elif kind=="lever":
		draw_rect(Rect2(-10,-12,20,16),Color("6c7981"))
		var lit: bool=int(AbyssState.state.depth) in AbyssState.state.gates
		draw_line(Vector2.ZERO,Vector2(10 if lit else -10,-30),Color("d3ba83"),4)
		draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-9,-47),["风","水","灯","人"][symbol],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eadcb6"))
		draw_circle(Vector2(0,-36),4,[Color("92c3cb"),Color("6c96bd"),Color("eed49a"),Color("c9aa92")][symbol])
	elif kind=="chest":
		draw_rect(Rect2(-15,-22,30,24),Color("786350"))
		draw_rect(Rect2(-13,-21,26,4),Color("c4a06c"))
	elif kind=="conduit":
		draw_circle(Vector2(0,-18),16,Color("71819b"))
		draw_circle(Vector2(0,-18),7,Color("eed99c"))
	else:
		if kind=="utility": draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-24,-36),AbyssRules.utility_title(symbol),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ebd8ab"))
		draw_rect(Rect2(-15,-28,30,24),Color("ab9d7b"))
		for y in [-24,-18,-12]: draw_line(Vector2(-10,y),Vector2(10,y),Color("5a6c6d"),2)
