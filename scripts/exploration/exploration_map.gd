class_name ExplorationMap
extends Node2D
## 手工设计的三个实体区域。所有格均有真实地形，机关直接更改动态门/桥的碰撞格。
var area_id: String="mist_forest"
var ground: TileMapLayer
var actors: Node2D
var layout: Dictionary
var objects: Dictionary={}
var floors: Dictionary={}
var gates: Dictionary={}
var fog_time: float=0
var forest_background: PackedVector2Array=PackedVector2Array()
var forest_tree_texture: Texture2D
var applied_forest_season: int=-1
func _ready() -> void:
	layout=Exploration.data.areas[area_id];name=area_id
	ground=TileMapLayer.new();ground.name="Ground";ground.z_index=-5;add_child(ground)
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	var tiles := TileSet.new();tiles.tile_size=Vector2i(32,32);tiles.add_physics_layer();tiles.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new();atlas.texture=load("res://assets/exploration/"+layout.theme+"_tiles.png");atlas.texture_region_size=Vector2i(32,32)
	tiles.add_source(atlas,0)
	for tile in range(8):
		atlas.create_tile(Vector2i(tile,0))
		if tile in [1,2,4]:
			var data := atlas.get_tile_data(Vector2i(tile,0),0);data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set=tiles
	for rect in layout.floors:
		for y in range(rect[1],rect[1]+rect[3]):
			for x in range(rect[0],rect[0]+rect[2]): floors[Vector2i(x,y)]=true
	for y in range(28):
		for x in range(40):
			var cell := Vector2i(x,y)
			ground.set_cell(cell,0,Vector2i(0 if floors.has(cell) else 1,0))
	for rect in layout.water: paint(rect,2)
	if area_id=="mist_forest": cache_forest_background()
	for id in Exploration.data.points:
		var record: Dictionary=Exploration.data.points[id]
		if record.area!=area_id: continue
		var point := Node2D.new();point.set_script(preload("res://scripts/exploration/exploration_point.gd"));point.exploration_id=id;point.position=Exploration.point(id)
		actors.add_child(point);objects[id]=point
	Exploration.changed.connect(refresh);Calendar.changed.connect(refresh_forest_season);refresh_forest_season();refresh()
func refresh_forest_season() -> void:
	if area_id=="mist_forest" and applied_forest_season!=Calendar.season():
		applied_forest_season=Calendar.season()
		var atlas: TileSetAtlasSource=ground.tile_set.get_source(0)
		atlas.texture=load("res://assets/world_scheme_c/derived/forest_ground_"+SchemeCAssets.SEASONS[applied_forest_season]+".png")
		forest_tree_texture=SchemeCAssets.texture("pine_tree",applied_forest_season)
	queue_redraw()
func cache_forest_background() -> void:
	# 林壁已有地形碰撞；少量背景树只缓存绘制位置，不创建AI/额外物理节点。
	forest_tree_texture=SchemeCAssets.texture("pine_tree",Calendar.season())
	forest_background.clear()
	for y in range(2,27,3):
		for x in range(1,39,3):
			if floors.has(Vector2i(x,y)) or (x+y)%5==0: continue
			var at:=Vector2(x*32+16,y*32+16)
			var protected: bool=at.distance_to(Exploration.entry(area_id))<90
			for id in Exploration.data.points:
				if Exploration.data.points[id].area==area_id and at.distance_to(Exploration.point(id))<80: protected=true;break
			if not protected: forest_background.append(at)
func paint(rect: Array, tile: int) -> void:
	for y in range(rect[1],rect[1]+rect[3]):
		for x in range(rect[0],rect[0]+rect[2]): ground.set_cell(Vector2i(x,y),0,Vector2i(tile,0))
func refresh() -> void:
	var updated := false
	for gate in layout.gates:
		var opened: bool=Exploration.condition(gate.kind)
		if gates.get(gate.id,null)==opened: continue
		gates[gate.id]=opened;updated=true
		var tile: int=5 if opened else (2 if gate.kind in ["lower_room","lake_bridge"] else 4)
		paint(gate.rect,tile)
	if updated: Events.navigation_changed.emit()
	for point in objects.values(): point.queue_redraw()
	queue_redraw()
func is_fishing_water(cell: Vector2i) -> bool:
	return ground.get_cell_atlas_coords(cell).x==2
func _process(delta: float) -> void:
	if not is_visible_in_tree() or GameState.modal or not GameClock.running or area_id!="mist_forest": return
	fog_time+=delta
	if int(fog_time*2)!=int((fog_time-delta)*2): queue_redraw()
func _draw() -> void:
	if not layout: return
	if area_id=="mist_forest":
		for at in forest_background:
			var tree_id: String=["pine_tree","oak_tree","birch_tree"][absi(int(at.x+at.y))%3]
			SchemeCAssets.draw(self,tree_id,at,Calendar.season())
		# 稀疏低透明雾带，不另加屏幕级大雾；保持32px通路边界能看清。
		for i in range(7):
			var p := Vector2(fposmod(float(i)*233+fog_time*3,1400)-140,float(i%4)*190+120)
			draw_rect(Rect2(p,Vector2(310,26)),Color(.76,.82,.74,.045))
		for at in [Vector2(100,360),Vector2(350,250),Vector2(660,330),Vector2(1010,110)]:
			SchemeCAssets.draw(self,"reeds",at,Calendar.season())
	elif area_id=="lake_ruins":
		# 拱顶/检修栏杆明确表明是在封闭干燥廊道，不是水下普通行走。
		for y in [170,362,554,746]:
			for x in [98,396,942]:
				draw_line(Vector2(x,y),Vector2(x+74,y-28),Color("9aa998"),3)
				draw_line(Vector2(x+74,y-28),Vector2(x+148,y),Color("6a8983"),3)
		for y in range(100,800,80): draw_line(Vector2(758,y),Vector2(758,y+48),Color("a2b9aa"),2)
	else:
		var mirror: int=Exploration.state.temple.mirror
		var origin := Exploration.point("temple_mirror")+Vector2(0,-20)
		var direction: Vector2=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT][mirror]
		draw_line(origin,origin+direction*105,Color(.95,.85,.57,.35),3)
		for at in [Vector2(220,750),Vector2(560,440),Vector2(1010,160)]:
			draw_circle(at,25,Color(.83,.75,.45,.07));draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("d4bc77"))
