extends Node2D
func _ready() -> void:
	z_index=0
	Festival.changed.connect(queue_redraw)
	Calendar.changed.connect(queue_redraw)
func _draw() -> void:
	if Festival.active_id()!="spring": return
	var run: Dictionary=Festival.run_for("spring")
	if run.is_empty() or not Festival.current_run("spring"): return
	for cell in run.cells:
		var origin := Vector2(cell[0]*32,cell[1]*32)
		draw_rect(Rect2(origin+Vector2(1,1),Vector2(30,30)),Color("e2c77e"),false,1)
		draw_line(origin+Vector2(2,3),origin+Vector2(2,-7),Color("8e7450"),1)
		draw_colored_polygon(PackedVector2Array([origin+Vector2(2,-7),origin+Vector2(10,-4),origin+Vector2(2,-1)]),Color("cdb6a0"))
