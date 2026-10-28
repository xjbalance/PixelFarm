class_name FarmAtlasDrawing
extends RefCounted
## 图纸中的可改造农场从真实地表和设施绘制，不把旧建筑、湖水或田块烘焙在纸上。
static func screen_rect(canvas: Control, world_rect: Rect2) -> Rect2:
	var a: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,world_rect.position))
	var b: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,world_rect.end))
	return Rect2(a,b-a)
static func draw_current(canvas: Control) -> void:
	var bounds:=FarmAtlasData.bounds(canvas.region_id)
	for y in range(32):
		for x in range(48):
			var cell:=Vector2i(x,y)
			var rect:=Rect2(Vector2(cell)*32,Vector2(32,32))
			if not bounds.intersects(rect): continue
			var tile: int=FarmTerrain.effective_index(cell)
			if tile not in [3,4,5,6,7]: continue
			var color: Color={3:Color("c7a878"),4:Color("b6a173"),5:Color("86b5ad"),6:Color("719e9a"),7:Color("b68c5c")}[tile]
			var on_paper:=screen_rect(canvas,rect)
			canvas.draw_rect(on_paper,color)
			if tile in [5,6] and posmod(cell.x+cell.y*3,7)==0:
				canvas.draw_line(on_paper.get_center()+Vector2(-2,0),on_paper.get_center()+Vector2(3,0),Color("b6d1ba"),1)
	if is_instance_valid(canvas.game) and "farm" in canvas.game and is_instance_valid(canvas.game.farm):
		for key in canvas.game.farm.plots:
			if FarmLayout.stored("plot",str(key)): continue
			var cell: Vector2i=FarmLayout.cell("plot",str(key))
			var rect:=Rect2(Vector2(cell)*32+Vector2(2,2),Vector2(28,28))
			var plot: Dictionary=canvas.game.farm.plots[key]
			var on_paper:=screen_rect(canvas,rect)
			canvas.draw_rect(on_paper,Color("8c7654") if plot.watered else Color("a8865c"))
			if str(plot.crop)!="": canvas.draw_line(on_paper.get_center()+Vector2(0,2),on_paper.get_center()+Vector2(0,-3),Color("667d4e"),2)
	# 原经营家具继续来自Housing的唯一列表，不复制储物或经营数据。
	for item in Housing.state.placed:
		if item.area!="farm": continue
		var rect:=Housing.footprint(item.kind,Vector2i(item.cell[0],item.cell[1]))
		var on_paper:=screen_rect(canvas,Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32))
		canvas.draw_rect(on_paper.grow(-1),Color("b99a6c") if item.kind=="road" else Color("8f9b76"))
	# 功能设施由同一组动态地标图标绘制一次，避免额外房屋剪影与图标叠出双重屋顶。
