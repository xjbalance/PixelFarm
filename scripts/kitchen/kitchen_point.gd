extends Node2D
var kitchen_id: String="kitchen"
func _ready() -> void:
	add_to_group("interactables")
	Kitchen.changed.connect(queue_redraw)
	Calendar.changed.connect(queue_redraw)
	if kitchen_id=="kitchen":
		var body := StaticBody2D.new();body.position=Vector2(0,-32)
		var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(80,20);shape.shape=box
		body.add_child(shape);add_child(body)
func prompt() -> String:
	return "采摘野莓 · 每日一次" if kitchen_id=="berry" else "小屋厨房 · 料理与加工"
func interact() -> void:
	Events.interaction_requested.emit("kitchen:berry" if kitchen_id=="berry" else "kitchen")
func _draw() -> void:
	if kitchen_id=="berry":
		draw_rect(Rect2(-3,-10,6,12),Color("6f5946"))
		for at in [Vector2(-10,-12),Vector2(8,-14),Vector2(0,-22)]: draw_circle(at,12,Color("71866a") if Calendar.season()!=3 else Color("b9c9be"))
		if Kitchen.state.berry_day!=GameClock.day:
			for at in [Vector2(-13,-16),Vector2(6,-25),Vector2(13,-9)]: draw_rect(Rect2(at,Vector2(4,4)),Color("bd7b85"))
		return
	draw_rect(Rect2(-44,-48,88,40),Color("635440"))
	draw_rect(Rect2(-42,-49,84,9),Color("c5ac7e"))
	draw_rect(Rect2(-39,-38,78,25),Color("a88b61"))
	for x in [-32,4]: draw_rect(Rect2(x,-33,27,17),Color("806b51"))
	draw_rect(Rect2(-25,-29,5,4),Color("d8c18d"));draw_rect(Rect2(15,-29,5,4),Color("d8c18d"))
	for i in range(Kitchen.FACILITIES.size()):
		if Kitchen.FACILITIES[i] not in Kitchen.state.built: continue
		var at := Vector2(-31+i*21,-54)
		match i:
			0:
				draw_circle(at,8,Color("adb0a1"));draw_circle(at,3,Color("655c4b"));draw_line(at,at+Vector2(9,-5),Color("b4a072"),2)
			1:
				draw_rect(Rect2(at-Vector2(7,4),Vector2(14,9)),Color("c8a565"));draw_rect(Rect2(at-Vector2(5,8),Vector2(10,5)),Color("ead79b"))
			2:
				draw_rect(Rect2(at-Vector2(6,10),Vector2(12,16)),Color("646f69"));draw_rect(Rect2(at-Vector2(3,4),Vector2(6,4)),Color("dcad76"))
			3:
				draw_rect(Rect2(at-Vector2(6,7),Vector2(12,12)),Color("a57f72"));draw_rect(Rect2(at-Vector2(5,10),Vector2(10,3)),Color("cbb486"));draw_rect(Rect2(at-Vector2(3,4),Vector2(6,6)),Color("b27081"))
	var ready := 0
	for job in Kitchen.state.queue:
		if job.ready: ready+=1
	if ready>0:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-74),Vector2(5,-69),Vector2(0,-64),Vector2(-5,-69)]),Color("eed58c"))
