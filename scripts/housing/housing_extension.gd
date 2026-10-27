extends Node2D
## 原左侧房间按四级扩展，碰撞全部由HomeLayout和主Home统一创建。
var game: Node
var floor: TileMapLayer
var previous_level: int=-1
var room:=Rect2()
var walls_texture: Texture2D
func _ready() -> void:
	z_index=-4
	floor=TileMapLayer.new();floor.name="ExtensionFloor";floor.z_index=-1
	floor.tile_set=game.home.get_node("Floor").tile_set.duplicate(true);add_child(floor)
	refresh()
func refresh() -> void:
	if not is_instance_valid(floor): return
	var atlas: TileSetAtlasSource=floor.tile_set.get_source(0)
	var main_atlas: TileSetAtlasSource=game.home.get_node("Floor").tile_set.get_source(0)
	atlas.texture=main_atlas.texture
	if previous_level==Housing.state.level: return
	previous_level=Housing.state.level;floor.clear();room=Rect2();walls_texture=null
	var cells:=HomeLayout.extension_cells(int(Housing.state.level))
	if cells.has_area():
		room=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
		for y in range(cells.position.y,cells.end.y):
			for x in range(cells.position.x,cells.end.x):
				var cell:=Vector2i(x,y);floor.set_cell(cell,0,game.home.floor_variant(cell))
		walls_texture=load("res://assets/housing/interior/extension_walls_"+str(previous_level)+".png")
	queue_redraw();Events.navigation_changed.emit()
func _draw() -> void:
	if walls_texture: draw_texture(walls_texture,room.position-Vector2(12,48))
