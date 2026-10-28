class_name SeasonLandscape
extends Node2D
## Shared Scheme C materials replace bitmaps only; existing TileData and physics survive.
const NAMES := ["spring","summer","autumn","winter"]
const ORIGINAL_TREE := "res://assets/tilesets/tree.png"
var layers: Dictionary = {}
var trees: Array[Sprite2D] = []
var applied_season: int = -1
var game: Node

class SeasonalLayer extends Node2D:
	var season: int=0
	var ground: TileMapLayer
	var details: Array[Vector2]=[]
	func prepare(terrain: TileMapLayer, width: int, height: int) -> void:
		ground=terrain;z_index=-3;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var rng:=RandomNumberGenerator.new();rng.seed=7060+width
		for i in range(70):
			var point:=Vector2(rng.randi_range(48,width-48),rng.randi_range(48,height-48))
			if ground.get_cell_atlas_coords(Vector2i(point/32)).x in [0,1,2]: details.append(point)
		Story.changed.connect(queue_redraw)
	func set_season(value: int) -> void:
		season=value;queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(ground): return
		# Draw connected roads from the supplied 47-mask sheet without changing source IDs.
		for cell in ground.get_used_cells():
			var type: int=ground.get_cell_atlas_coords(cell).x
			if type not in [3,4,7]: continue
			var material: String="dirt_path" if type==3 else "dirt" if type==4 else "wood_path"
			var mask: int=0
			for index in range(SchemeCTerrain.DIRECTIONS.size()):
				if ground.get_cell_atlas_coords(cell+SchemeCTerrain.DIRECTIONS[index]).x==type: mask |= 1 << index
			draw_texture(SchemeCTerrain.tile(material,season,mask),Vector2(cell)*32)
		for i in range(details.size()):
			var id: String=["short_grass","clover","grass_clump","white_wildflowers","yellow_wildflowers"][i%5]
			SchemeCAssets.draw(self,id,details[i],season)

func attach(owner_game: Node) -> void:
	if not layers.is_empty(): return
	game=owner_game;add_to_group("season_landscapes")
	for id in ["farm","village"]:
		var map: Node2D=game.world if id=="farm" else game.village
		var terrain: TileMapLayer=map.get_node("Ground")
		var layer:=SeasonalLayer.new();layer.name="SeasonGroundDetails";map.add_child(layer)
		layer.prepare(terrain,1536 if id=="farm" else 1280,1024 if id=="farm" else 896)
		if id=="farm" and map.has_node("GroundDetail06"): layer.visible=false
		layers[id]=layer
		# Gather only the old decorative tree sprites. Collectable trees own their art updates.
		for node in map.find_children("*","Sprite2D",true,false):
			if node.texture and node.texture.resource_path==ORIGINAL_TREE:
				trees.append(node)
				node.set_meta("scheme_c_id",["oak_tree","birch_tree","pine_tree"][absi(int(node.position.x+node.position.y))%3])
	Calendar.changed.connect(refresh);GameClock.changed.connect(refresh);refresh()

func refresh() -> void:
	var current: int=Calendar.season()
	if current==applied_season: return
	applied_season=current
	var ground_texture: Texture2D=load("res://assets/world_scheme_c/derived/ground_"+NAMES[current]+".png")
	for layer in layers.values():
		var atlas: TileSetAtlasSource=layer.ground.tile_set.get_source(0)
		atlas.texture=ground_texture;layer.set_season(current)
	for tree in trees:
		if not is_instance_valid(tree): continue
		var id: String=str(tree.get_meta("scheme_c_id","oak_tree"))
		tree.texture=SchemeCAssets.texture(id,current);tree.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		# Decorative village trees retain their original origin and foot collider at y=38.
		tree.offset=SchemeCAssets.offset(id)+Vector2(0,38)
