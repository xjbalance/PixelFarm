class_name TerritoryAtlasDrawing
extends RefCounted
## 羊皮纸上的领地示意，读取真实差异，不截取或缩小 TileMap。
const PAPER:=Color("eddfbd")
const OWNED:=Color("668c65")
const PUBLIC:=Color("8f7a60")
const LOCKED:=Color("a68a61")

static func _paper_rect(canvas: Control, at: Vector2, extent: Vector2) -> Rect2:
	return Rect2(canvas.map_to_screen(at),extent*canvas.map_scale())

static func _world_rect(canvas: Control, rect: Rect2) -> Rect2:
	var start: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,rect.position))
	var end: Vector2=canvas.map_to_screen(FarmAtlasData.world_to_map(canvas.region_id,rect.end))
	return Rect2(start,end-start)

static func draw_sheet(canvas: Control) -> void:
	canvas.draw_rect(_paper_rect(canvas,Vector2.ZERO,FarmAtlasData.PAPER_SIZE),PAPER)
	canvas.draw_rect(_paper_rect(canvas,Vector2(26,26),Vector2(972,588)),Color("bd9c70"),false,2)
	canvas.draw_rect(_paper_rect(canvas,Vector2(70,66),Vector2(884,496)),Color("c5c79a"))
	for y in range(140,530,71):
		for x in range(128,920,93):
			var at: Vector2=canvas.map_to_screen(Vector2(x+(y%3)*7,y))
			for shift in [-3,0,3]: canvas.draw_line(at+Vector2(shift,2),at+Vector2(shift-1,-2),Color("abb58b"),1)
	# 树篱只画地图边界；留出中间的生活与改造空间。
	for x in range(78,960,44):
		for y in [72,554]:
			var at: Vector2=canvas.map_to_screen(Vector2(x,y));var scale: float=canvas.map_scale()
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-10)*scale,at+Vector2(-11,6)*scale,at+Vector2(11,6)*scale]),Color("789167"))
	for y in range(116,536,44):
		for x in [78,946]:
			canvas.draw_circle(canvas.map_to_screen(Vector2(x,y)),7*canvas.map_scale(),Color("8d9b72"))
	canvas.draw_rect(_world_rect(canvas,Rect2(608,64,64,768)),Color("c0a06d"))
	var title: String=FarmAtlasData.title(canvas.region_id)
	var width: float=canvas._font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	canvas.draw_string(canvas._font,canvas.map_to_screen(Vector2(512,44))-Vector2(width*.5,0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,FarmUIStyle.TITLE)
	if canvas.region_id=="lake_holding":
		for x in range(112,920,36):
			var at: Vector2=canvas.map_to_screen(Vector2(x,582))
			canvas.draw_line(at,at+Vector2(20,-2)*canvas.map_scale(),Color("789f9c"),2)

static func draw_overlay(canvas: Control) -> void:
	if canvas.layer_id=="world":
		for area in TerritoryCatalog.EDITABLE_AREAS:
			var at: Vector2=canvas.map_to_screen(FarmAtlasData.WORLD_POINTS[area])
			var origin: Vector2=canvas.map_to_screen(FarmAtlasData.WORLD_POINTS.farm)
			var opened: bool=Territory.unlocked(area)
			for step in range(1,12,2):
				canvas.draw_line(origin.lerp(at,float(step)/12),origin.lerp(at,float(step+1)/12),Color("a58b66"),1)
			var rect:=Rect2(at-Vector2(44,27)*canvas.map_scale(),Vector2(88,54)*canvas.map_scale())
			canvas.draw_rect(rect,Color(OWNED,.14) if opened else Color(LOCKED,.20))
			canvas.draw_rect(rect,OWNED if opened else LOCKED,false,2)
		_draw_legend(canvas)
		return
	if canvas.region_id not in TerritoryCatalog.EDITABLE_AREAS: return
	var info: Dictionary=TerritoryCatalog.region(canvas.region_id)
	var cells: Rect2i=info.editable_rect
	var extent:=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
	canvas.draw_rect(_world_rect(canvas,extent),Color(OWNED,.09))
	canvas.draw_rect(_world_rect(canvas,extent),OWNED,false,2)
	for reserved: Rect2i in info.protected:
		var rect:=_world_rect(canvas,Rect2(Vector2(reserved.position)*32,Vector2(reserved.size)*32))
		canvas.draw_rect(rect,Color(PUBLIC,.10));canvas.draw_rect(rect,Color(PUBLIC,.65),false,1)
	if info.semi_open.has_area():
		var semi: Rect2i=info.semi_open
		canvas.draw_rect(_world_rect(canvas,Rect2(Vector2(semi.position)*32,Vector2(semi.size)*32)),Color("c6ac6c66"))
	var terrain: Dictionary=Territory.state.terrain.get(canvas.region_id,{})
	for key in terrain:
		var cell:=TerritoryCatalog.cell_from_key(key)
		var color: Color={"soil":Color("987352"),"grass":Color("8fa477"),"flowerbed":Color("b69372"),"dirt_path":Color("bc9964"),"stone_path":Color("9fa798"),"wood_path":Color("b68c5c")}.get(terrain[key],OWNED)
		canvas.draw_rect(_world_rect(canvas,Rect2(Vector2(cell)*32,Vector2(32,32))),color)
	for object in Territory.state.objects:
		if object.area!=canvas.region_id: continue
		var footprint:=TerritoryCatalog.footprint(object.kind,TerritoryCatalog.to_cell(object.cell))
		var rect:=_world_rect(canvas,Rect2(Vector2(footprint.position)*32,Vector2(footprint.size)*32))
		var color: Color=OWNED if TerritoryCatalog.OBJECT_KINDS[object.kind].category=="vegetation" else Color("8c7152")
		canvas.draw_rect(rect.grow(-1),color)
	_draw_legend(canvas)

static func _draw_legend(canvas: Control) -> void:
	canvas.draw_style_box(canvas._label_style,Rect2(12,12,282,30))
	canvas.draw_string(canvas._font,Vector2(22,33),"绿框私有 · 褐线保留 · 状态见地名",HORIZONTAL_ALIGNMENT_LEFT,-1,14,FarmUIStyle.TITLE)
