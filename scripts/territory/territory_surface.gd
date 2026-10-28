class_name TerritorySurface
extends Node2D
## 地表改造叠加在旧地图之上。原农田/水面/道路从不写回，也不改变作物状态。
const GRASS := [Color("86a86e"),Color("71955d"),Color("a59b63"),Color("d5dfd1")]
var area_id: String="farm"
var cells: Dictionary={}
var season: int=-1

func _ready() -> void:
	z_index=-3;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	Calendar.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var next: Dictionary=Territory.state.get("terrain",{}).get(area_id,{})
	var next_season: int=Calendar.season()
	if next==cells and season==next_season: return
	cells=next.duplicate(true);season=next_season;queue_redraw()

func _draw() -> void:
	for key in cells:
		var cell:=TerritoryCatalog.cell_from_key(str(key))
		var kind: String=str(cells[key])
		var origin:=Vector2(cell)*32
		draw_rect(Rect2(origin,Vector2(32,32)),GRASS[season])
		var hash_value: int=absi(cell.x*73+cell.y*193)
		if kind in ["grass","natural"]:
			for i in range(3):
				var at:=origin+Vector2(4+(hash_value+i*11)%25,7+(hash_value+i*7)%21)
				draw_line(at,at+Vector2(1,-3),GRASS[season].darkened(.12),1)
		elif kind in ["soil","flowerbed"]:
			draw_rect(Rect2(origin+Vector2(1,1),Vector2(30,30)),Color("a17b54") if season!=3 else Color("a8977a"))
			for y in [7,15,23]: draw_line(origin+Vector2(4,y),origin+Vector2(28,y),Color("806448"),2)
			if kind=="flowerbed":
				for at in [Vector2(7,9),Vector2(23,18),Vector2(12,26)]:
					draw_rect(Rect2(origin+at,Vector2(3,2)),Color("d3ba8b"))
		elif kind.ends_with("_path"):
			_draw_path(cell,kind,origin)

func _draw_path(cell: Vector2i, kind: String, origin: Vector2) -> void:
	var color: Color={"dirt_path":Color("c3a16d"),"stone_path":Color("afb2a0"),"wood_path":Color("bf9463")}[kind]
	var rect:=Rect2(origin+Vector2(2,2),Vector2(28,28))
	draw_rect(rect,color.darkened(.13));draw_rect(rect.grow(-1),color)
	for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if str(cells.get(TerritoryCatalog.key(cell+direction),""))!=kind: continue
		var connection:=Rect2(origin+Vector2(2,2),Vector2(28,28))
		if direction.x: connection=Rect2(origin+Vector2(0 if direction.x<0 else 27,2),Vector2(5,28))
		else: connection=Rect2(origin+Vector2(2,0 if direction.y<0 else 27),Vector2(28,5))
		draw_rect(connection,color)
	if kind=="wood_path":
		for y in [8,16,24]: draw_line(origin+Vector2(3,y),origin+Vector2(29,y),Color("92734f"),1)
		draw_line(origin+Vector2(6,4),origin+Vector2(6,28),Color("d8b784"),1)
	elif kind=="stone_path":
		for stone in [Rect2(4,4,11,10),Rect2(17,5,10,12),Rect2(5,17,12,10),Rect2(20,20,7,8)]:
			draw_rect(Rect2(origin+stone.position,stone.size),color.lightened(.12))
	else:
		for at in [Vector2(8,8),Vector2(23,19),Vector2(13,26)]: draw_rect(Rect2(origin+at,Vector2(3,1)),color.darkened(.2))
