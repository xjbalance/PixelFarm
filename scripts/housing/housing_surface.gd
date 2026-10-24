extends Node2D
## 房型/墙纸叠加仅影响外观；原家中所有家具、故事物件与碰撞保留。
var game: Node
var original_floor: Texture2D
func _ready() -> void:
	var floor: TileMapLayer=game.home.get_node("Floor")
	var atlas: TileSetAtlasSource=floor.tile_set.get_source(0)
	original_floor=atlas.texture
	refresh()
func refresh() -> void:
	var floor: TileMapLayer=game.home.get_node("Floor")
	var atlas: TileSetAtlasSource=floor.tile_set.get_source(0)
	atlas.texture=load("res://assets/housing/floor_texture.png") if Housing.state.appearance.floor=="floor" else original_floor
	queue_redraw()
func _draw() -> void:
	if Housing.state.appearance.wallpaper=="wallpaper":
		draw_rect(Rect2(344,165,584,48),Color("a9b095"))
		for x in range(355,926,24):
			draw_line(Vector2(x,177),Vector2(x+8,201),Color("749174"),2)
			draw_line(Vector2(x+7,189),Vector2(x+13,183),Color("d0c99c"),2)
	if Housing.state.level>=2:
		draw_rect(Rect2(356,248,24,104),Color("6b5845"))
		for y in [255,286,317]:
			draw_rect(Rect2(359,y,18,25),Color("a88d66"))
			for x in [361,367,373]: draw_rect(Rect2(x,y+2,4,19),Color("799782") if x!=367 else Color("c1ab7d"))
	if Housing.state.level>=3:
		for x in [376,900]:
			draw_rect(Rect2(x,228,12,116),Color("b6a17c"));draw_rect(Rect2(x+2,231,8,108),Color("ccbb94"))
		draw_line(Vector2(384,232),Vector2(896,232),Color("d6bd8e"),3)
