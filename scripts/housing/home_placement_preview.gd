extends Node2D
var controller: Node
func _draw() -> void:
	if not is_instance_valid(controller) or not controller.active: return
	for cells in HomeLayout.placement_regions(int(Housing.state.level)):
		var bounds:=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
		draw_rect(bounds,Color(.72,.85,.69,.055))
		for x in range(cells.position.x,cells.end.x+1): draw_line(Vector2(x*32,bounds.position.y),Vector2(x*32,bounds.end.y),Color(.9,.87,.68,.14),1)
		for y in range(cells.position.y,cells.end.y+1): draw_line(Vector2(bounds.position.x,y*32),Vector2(bounds.end.x,y*32),Color(.9,.87,.68,.14),1)
	if controller.preview_cell.x<0: return
	var item: Dictionary=controller.current_geometry()
	if item.is_empty(): return
	var tone:=Color("789c79") if controller.preview_valid else Color("bf7658")
	if controller.dragging: tone=Color("e7b96b")
	var texture: Texture2D=controller.preview_texture(item)
	if texture: draw_texture(texture,item.position,Color(1,1,1,.60))
	var rect: Rect2=item.footprint
	draw_rect(rect,Color(tone,.12));draw_rect(rect,tone,false,2)
