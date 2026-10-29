extends Node2D
var festival_id: String = "spring"
var _reward_icon: Texture2D
const COLORS := {"spring":Color("d2b784"),"summer":Color("6fa5a4"),"autumn":Color("bd865e"),"winter":Color("a9c5c8")}
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# Canvas draw commands retain a RID, not the Texture2D resource. Keep the
	# icon alive after _draw returns or the renderer shows a solid white quad.
	var event: Dictionary=Festival.data.events[festival_id]
	_reward_icon=load("res://assets/festivals/"+str(event.reward.items.keys()[0])+".png")
	add_to_group("interactables")
	Festival.changed.connect(queue_redraw)
	GameClock.changed.connect(queue_redraw)
func hit_rect() -> Rect2: return Rect2(-26,-52,52,68)
func prompt() -> String:
	return Festival.data.events[festival_id].name+" · "+("正在举行" if Festival.is_open(festival_id) else "查看活动日期")
func interact() -> void:
	Events.interaction_requested.emit("festival:"+festival_id)
func _draw() -> void:
	var today: bool=Festival.active_id()==festival_id
	if not SchemeCAssets.draw(self,"notice_board",Vector2(0,9),Calendar.season()):
		draw_rect(Rect2(-3,-15,6,30),Color("6f6048"))
		draw_rect(Rect2(-23,-44,46,29),Color("59644d"))
		draw_rect(Rect2(-21,-42,42,25),COLORS[festival_id])
	if _reward_icon: draw_texture_rect(_reward_icon,Rect2(-12,-43,24,24),false)
	if not today: return
	# 稀疏横幅与小摊，无碰撞、不占通路或为湖水增添地面。
	for x in [-64,-32,0,32,64]:
		if festival_id=="summer":
			var lit: bool=GameClock.minutes>=1200 and Festival.run_for("summer").get("lantern","")!=""
			var color: Color=Color("f1d29a") if lit else Color("b18c63")
			if lit: draw_circle(Vector2(x,-72),14,Color(1,.78,.4,.08))
			draw_rect(Rect2(x-6,-78,12,14),color);draw_line(Vector2(x,-79),Vector2(x,-88),Color("7d7759"),1)
		elif festival_id=="winter":
			draw_colored_polygon(PackedVector2Array([Vector2(x,-67),Vector2(x+3,-60),Vector2(x+10,-60),Vector2(x+5,-55),Vector2(x+6,-48),Vector2(x,-52),Vector2(x-6,-48),Vector2(x-5,-55),Vector2(x-10,-60),Vector2(x-3,-60)]),Color("e5d6a3"))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x-7,-73),Vector2(x+7,-73),Vector2(x,-60)]),COLORS[festival_id])
	draw_line(Vector2(-80,-84),Vector2(80,-84),Color("b6aa80"),1)
	if festival_id in ["autumn","winter"]:
		for x in [-64,64]:
			draw_rect(Rect2(x-18,8,36,22),Color("77694e"))
			draw_rect(Rect2(x-20,4,40,6),Color("b4a47b"))
