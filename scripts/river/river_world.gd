extends Node2D
func _ready() -> void:
	River.changed.connect(refresh);refresh()
func refresh() -> void:
	visible=River.has("closing_scene");queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-28,-28,56,34),Color("8e775b"))
	draw_rect(Rect2(-34,-34,68,8),Color("bbaa7f"))
	var color: Color={"water":Color("83b9c0"),"rotation":Color("d7bd7e"),"commons":Color("9bba83")}.get(River.state.policy,Color("c4b389"))
	for x in [-20,0,20]:
		draw_rect(Rect2(x-5,-22,10,12),color)
		draw_circle(Vector2(x,12),5,Color("454e47"))
	draw_string(preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-48,-42),"新一班的交接台",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eddcb0"))
