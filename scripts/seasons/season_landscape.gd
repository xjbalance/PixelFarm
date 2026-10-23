class_name SeasonLandscape
extends Node2D
## 替换纹理而非地图数据。已修桥、鱼栏、可通行格与所有物理形状保持原样。
const NAMES := ["spring","summer","autumn","winter"]
const ORIGINAL_TREE := "res://assets/tilesets/tree.png"
var layers: Dictionary = {}
var trees: Array[Sprite2D] = []
var applied_season: int = -1
var game: Node

class SeasonalLayer extends Node2D:
	var season: int = 0
	var ground: TileMapLayer
	var details: Array[Vector2] = []
	func prepare(terrain: TileMapLayer, width: int, height: int) -> void:
		ground=terrain
		z_index=-3
		var rng := RandomNumberGenerator.new()
		rng.seed=7060+width
		for i in range(140):
			var point := Vector2(rng.randi_range(48,width-48),rng.randi_range(48,height-48))
			if ground.get_cell_atlas_coords(Vector2i(point/32)).x in [0,1,2]: details.append(point)
	func set_season(value: int) -> void:
		season=value
		queue_redraw()
	func _draw() -> void:
		for i in range(details.size()):
			var p: Vector2=details[i]
			match season:
				0:
					draw_line(p,p+Vector2(0,-5),Color("7c9f61"),2)
					if i%3==0:
						draw_rect(Rect2(p+Vector2(-3,-8),Vector2(6,3)),Color("eccfba"))
						draw_rect(Rect2(p+Vector2(-1,-9),Vector2(2,6)),Color("eddfae"))
				1:
					draw_line(p,p+Vector2(-4,-7),Color("5b8054"),2)
					draw_line(p,p+Vector2(2,-9),Color("4d7449"),2)
					draw_line(p+Vector2(2,0),p+Vector2(7,-6),Color("8da66a"),2)
				2:
					var color := Color("c29960") if i%2 else Color("b37953")
					draw_colored_polygon(PackedVector2Array([p+Vector2(-4,0),p+Vector2(0,-3),p+Vector2(5,0),p+Vector2(1,3)]),color)
					draw_line(p+Vector2(-2,0),p+Vector2(4,1),Color("896d4a"),1)
				3:
					draw_rect(Rect2(p+Vector2(-5,0),Vector2(12,3)),Color("b8cbc9"))
					draw_rect(Rect2(p+Vector2(-4,-2),Vector2(10,3)),Color("e5ebe1"))
					if i%4==0: draw_line(p+Vector2(-1,-2),p+Vector2(0,-6),Color("a0b29d"),1)

func attach(owner_game: Node) -> void:
	if not layers.is_empty(): return
	game=owner_game
	add_to_group("season_landscapes")
	for id in ["farm","village"]:
		var map: Node2D=game.world if id=="farm" else game.village
		var terrain: TileMapLayer=map.get_node("Ground")
		var layer := SeasonalLayer.new()
		layer.name="SeasonGroundDetails"
		map.add_child(layer)
		layer.prepare(terrain,1536 if id=="farm" else 1280,1024 if id=="farm" else 896)
		layers[id]=layer
		for node in map.find_children("*","Sprite2D",true,false):
			if node.texture and node.texture.resource_path==ORIGINAL_TREE: trees.append(node)
	Calendar.changed.connect(refresh)
	GameClock.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var current: int=Calendar.season()
	if current==applied_season: return
	applied_season=current
	var ground_texture: Texture2D=load("res://assets/seasons/ground_"+NAMES[current]+".png")
	var tree_texture: Texture2D=load("res://assets/seasons/tree_"+NAMES[current]+".png")
	for layer in layers.values():
		# Source 0 keeps its original TileData and physics polygons; only its bitmap changes.
		var atlas: TileSetAtlasSource=layer.ground.tile_set.get_source(0)
		atlas.texture=ground_texture
		layer.set_season(current)
	for tree in trees:
		if is_instance_valid(tree): tree.texture=tree_texture
