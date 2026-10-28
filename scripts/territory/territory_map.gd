class_name TerritoryMap
extends Node2D
## 地上私人附属地，40×28格；不复用或修改矿洞布局。
const SEASON_BASE := [Color("8cae73"),Color("779d63"),Color("b0a16b"),Color("dce3d6")]
static var tile_textures: Dictionary={}
var area_id: String="east_holding"
var ground: TileMapLayer
var actors: Node2D
var applied_season: int=-1

func _ready() -> void:
	name=area_id
	ground=TileMapLayer.new();ground.name="Ground";ground.z_index=-5;add_child(ground)
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	var tiles:=TileSet.new();tiles.tile_size=Vector2i(32,32);tiles.add_physics_layer();tiles.set_physics_layer_collision_layer(0,1)
	var atlas:=TileSetAtlasSource.new();atlas.texture=_tiles(Calendar.season());atlas.texture_region_size=Vector2i(32,32);tiles.add_source(atlas,0)
	for index in range(5):
		atlas.create_tile(Vector2i(index,0))
		if index==4:
			var tile:=atlas.get_tile_data(Vector2i(index,0),0);tile.set_collision_polygons_count(0,1)
			tile.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set=tiles
	for y in range(28):
		for x in range(40):
			var index: int=absi(x*71+y*137)%3
			if x in [19,20] and y>=4: index=3
			if x in [0,1,38,39] or y in [0,1,26,27]: index=4
			ground.set_cell(Vector2i(x,y),0,Vector2i(index,0))
	Calendar.changed.connect(refresh);refresh()
	Events.location_changed.connect(func(area: String):
		if area==area_id: refresh()
	)

static func _tiles(season: int) -> Texture2D:
	if tile_textures.has(season): return tile_textures[season]
	var texture: Texture2D=load("res://assets/world_scheme_c/derived/annex_ground_"+SchemeCAssets.SEASONS[season]+".png")
	tile_textures[season]=texture;return texture

func refresh() -> void:
	var season: int=Calendar.season()
	if season==applied_season: return
	applied_season=season
	var atlas: TileSetAtlasSource=ground.tile_set.get_source(0);atlas.texture=_tiles(season)
	queue_redraw()

func _draw() -> void:
	var season: int=Calendar.season()
	# 边界有实体瓦片，疏落的树篱轮廓只画在不可建设的边缘。
	for y in range(80,840,64):
		for x in [40,1240]:
			SchemeCAssets.draw(self,"bush",Vector2(x,y),season)
	for x in range(96,1200,64):
		SchemeCAssets.draw(self,"hedge_fence",Vector2(x,56),season)
	if area_id=="lake_holding":
		for x in range(90,1200,48): draw_line(Vector2(x,856),Vector2(x+27,856),Color("8ab2ad"),4)
	elif area_id=="manor_holding":
		for at in [Vector2(608,96),Vector2(672,96)]:
			draw_line(at+Vector2(-3,0),at+Vector2(3,0),Color("e8c882"),2);draw_line(at+Vector2(0,-4),at+Vector2(0,4),Color("e8c882"),2)
