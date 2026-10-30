class_name FarmAtlasDrawing
extends RefCounted
## 图纸中的可改造农场从真实地表和设施绘制，不把旧建筑、湖水或田块烘焙在纸上。
static func screen_rect(canvas: Control, world_rect: Rect2) -> Rect2:
	var a: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,world_rect.position))
	var b: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,world_rect.end))
	return Rect2(a,b-a)
static var _terrain_signature: int=-1
static var _terrain_cells: Array[Dictionary]=[]
static func terrain_cells() -> Array[Dictionary]:
	var signature: int=hash([FarmTerrain.overrides(),FarmLayout.offset("lake"),FarmLayout.active("lake")])
	if signature==_terrain_signature: return _terrain_cells
	_terrain_signature=signature;_terrain_cells.clear()
	for y in range(FarmLayoutCatalog.GRID.size.y):
		for x in range(FarmLayoutCatalog.GRID.size.x):
			var cell:=Vector2i(x,y);var tile: int=FarmTerrain.effective_index(cell)
			if tile in [3,4,5,6,7]: _terrain_cells.append({"cell":cell,"tile":tile})
	return _terrain_cells
static func draw_current(canvas: Control) -> void:
	var bounds:=FarmAtlasData.bounds(canvas.region_id)
	for entry in terrain_cells():
		var cell: Vector2i=entry.cell;var tile: int=int(entry.tile)
		var rect:=Rect2(Vector2(cell)*32,Vector2(32,32))
		if not bounds.intersects(rect): continue
		var color: Color={3:Color("c7a878"),4:Color("b6a173"),5:Color("86b5ad"),6:Color("719e9a"),7:Color("b68c5c")}[tile]
		var on_paper:=screen_rect(canvas,rect);canvas.draw_rect(on_paper,color)
		if tile in [5,6] and posmod(cell.x+cell.y*3,7)==0: canvas.draw_line(on_paper.get_center()+Vector2(-2,0),on_paper.get_center()+Vector2(3,0),Color("b6d1ba"),1)
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

static func draw_pasture(canvas: Control) -> void:
	var site:=RanchLayout.site(canvas.region_id)
	var border:=screen_rect(canvas,RanchLayout.world_rect(site).grow(-16))
	canvas.draw_rect(border,Color("b0bd8e"));canvas.draw_rect(border,Color("9b7751"),false,2)
	var scale: float=canvas.map_scale()
	for x in range(int(border.position.x)+5,int(border.end.x),18):
		for y in [border.position.y,border.end.y]: canvas.draw_line(Vector2(x,y-3),Vector2(x,y+3),Color("9b7751"),1)
	var path:=Rect2(Vector2(RanchLayout.world_rect(site).size.x*.5-22,224),Vector2(44,RanchLayout.world_rect(site).size.y-256))
	canvas.draw_rect(screen_rect(canvas,path),Color("c7a878"))
	var room:=screen_rect(canvas,RanchLayout.shelter(site))
	canvas.draw_rect(room,Color("c9aa7b"));canvas.draw_rect(room,Color("8d6747"),false,2)
	canvas.draw_colored_polygon(PackedVector2Array([room.position+Vector2(-3,0),room.position+Vector2(room.size.x*.5,-13*scale),Vector2(room.end.x+3,room.position.y)]),Color("b77b58"))
	for x in range(int(room.position.x)+8,int(room.end.x),12): canvas.draw_line(Vector2(x,room.position.y+3),Vector2(x,room.end.y-3),Color("dfc293"),1)
	for kind in RanchLayout.furniture(site):
		var rect:=screen_rect(canvas,Rect2(RanchLayout.furniture(site)[kind]+Vector2(-22,-12),Vector2(44,16)))
		canvas.draw_rect(rect,Color("88b5b0") if kind=="water_basin" else Color("b19565"))
	var random:=RandomNumberGenerator.new();random.seed=absi(site.hash())
	for i in range(45):
		var world:=Vector2(random.randf_range(64,RanchLayout.world_rect(site).size.x-64),random.randf_range(280,RanchLayout.world_rect(site).size.y-80))
		var at: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,world))
		canvas.draw_line(at,at+Vector2(-2,-3),Color("8fa477"),1);canvas.draw_line(at,at+Vector2(2,-4),Color("8fa477"),1)
	for entry in Livestock.animals_at(site):
		var at: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,Livestock.animal_point(entry)))
		canvas.draw_circle(at,4,Color("688176"));canvas.draw_circle(at+Vector2(-1,-1),2.5,Color("d6e3ca") if entry.species=="duck" else Color("f1e6c7"))
