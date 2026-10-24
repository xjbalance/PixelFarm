extends Node2D
## 左侧新增真实房间；旧床、故事桌、厨房与门位置不动，由原左墙门洞接入。
var game: Node
var floor: TileMapLayer
var walls: Node2D
var previous_level: int=-1
var room := Rect2()
func _ready() -> void:
	floor=TileMapLayer.new();floor.name="ExtensionFloor";floor.z_index=-5
	floor.tile_set=game.home.get_node("Floor").tile_set.duplicate(true);add_child(floor)
	walls=Node2D.new();add_child(walls);refresh()
func blocker(rect: Rect2) -> void:
	var body := StaticBody2D.new();body.position=rect.get_center()
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=rect.size;shape.shape=box
	body.add_child(shape);walls.add_child(body)
func refresh() -> void:
	if not floor: return
	var atlas: TileSetAtlasSource=floor.tile_set.get_source(0)
	var main_atlas: TileSetAtlasSource=game.home.get_node("Floor").tile_set.get_source(0)
	atlas.texture=main_atlas.texture
	if previous_level==Housing.state.level: return
	previous_level=Housing.state.level
	floor.clear()
	for child in walls.get_children(): child.queue_free()
	room=Rect2()
	if Housing.state.level>=2:
		var cells := Rect2i(7,12,4,5) if Housing.state.level==2 else Rect2i(4,8,7,9)
		room=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
		for y in range(cells.position.y,cells.end.y):
			for x in range(cells.position.x,cells.end.x): floor.set_cell(Vector2i(x,y),0,Vector2i(7,0))
		blocker(Rect2(room.position-Vector2(12,12),Vector2(room.size.x+12,12)))
		blocker(Rect2(Vector2(room.position.x-12,room.end.y),Vector2(room.size.x+12,12)))
		blocker(Rect2(room.position-Vector2(12,0),Vector2(12,room.size.y)))
	queue_redraw();Events.navigation_changed.emit()
func _draw() -> void:
	if Housing.state.level<2: return
	draw_rect(Rect2(room.position-Vector2(12,22),Vector2(room.size.x+12,22)),Color("a88f69"))
	draw_rect(Rect2(Vector2(room.position.x-12,room.position.y),Vector2(12,room.size.y+12)),Color("6b6650"))
	draw_rect(Rect2(Vector2(room.position.x,room.end.y),Vector2(room.size.x,12)),Color("8d7959"))
	for x in range(int(room.position.x)+12,330,24):
		draw_rect(Rect2(x,room.position.y-18,13,12),Color("96b7aa"))
		draw_line(Vector2(x+6,room.position.y-18),Vector2(x+6,room.position.y-6),Color("d4c6a2"),2)
