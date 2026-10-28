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
	var image:=Image.create(160,32,false,Image.FORMAT_RGBA8)
	for index in range(5):
		var color: Color=SEASON_BASE[season].lightened((index-1)*.025) if index<3 else Color("c4aa7a") if index==3 else Color("506d48") if season!=3 else Color("829586")
		image.fill_rect(Rect2i(index*32,0,32,32),color)
		for i in range(14):
			var at:=Vector2i(index*32+3+(i*11+index*3)%26,3+(i*7+index*5)%26)
			image.fill_rect(Rect2i(at,Vector2i(2,1)),color.lightened(.07) if i%2 else color.darkened(.08))
		if index==3:
			for y in [1,30]: image.fill_rect(Rect2i(index*32,y,32,1),color.darkened(.08))
	var texture:=ImageTexture.create_from_image(image);tile_textures[season]=texture;return texture

func refresh() -> void:
	var season: int=Calendar.season()
	if season==applied_season: return
	applied_season=season
	var atlas: TileSetAtlasSource=ground.tile_set.get_source(0);atlas.texture=_tiles(season)
	queue_redraw()

func _draw() -> void:
	var season: int=Calendar.season()
	var greens: Array[Color]=[Color("638956"),Color("4c7549"),Color("947f4d"),Color("acbbab")]
	var shade: Color=greens[season]
	# 边界有实体瓦片，疏落的树篱轮廓只画在不可建设的边缘。
	for y in range(80,840,64):
		for x in [40,1240]:
			draw_rect(Rect2(Vector2(x-22,y-26),Vector2(44,40)),shade.darkened(.13))
			draw_rect(Rect2(Vector2(x-27,y-20),Vector2(54,26)),shade)
			draw_rect(Rect2(Vector2(x-17,y-27),Vector2(29,12)),shade.lightened(.13))
	for x in range(96,1200,64):
		draw_rect(Rect2(x,42,44,16),shade)
	if area_id=="lake_holding":
		for x in range(90,1200,48): draw_line(Vector2(x,856),Vector2(x+27,856),Color("8ab2ad"),4)
	elif area_id=="manor_holding":
		for at in [Vector2(608,96),Vector2(672,96)]:
			draw_line(at+Vector2(-3,0),at+Vector2(3,0),Color("e8c882"),2);draw_line(at+Vector2(0,-4),at+Vector2(0,4),Color("e8c882"),2)
