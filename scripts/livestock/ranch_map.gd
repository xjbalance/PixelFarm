class_name RanchMap
extends Node2D
## Real playable rear pasture. Static route grid is built once; animal targets reuse it.
var site: String="coop"
var game: Node
var ground: TileMapLayer
var actors: Node2D
var grid:=AStarGrid2D.new()
var reachable: Dictionary={}
var route_requests: int=0
var season: int=-1
var details: Array[Vector2]=[]
var furniture_art: Dictionary={}
func _ready() -> void:
	name=RanchLayout.area(site)
	ground=TileMapLayer.new();ground.name="Ground";ground.z_index=-5;add_child(ground)
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	for kind in ["trough","water_basin"]: furniture_art[kind]=load("res://assets/livestock/ranch082/"+kind+".png")
	var tiles:=TileSet.new();tiles.tile_size=Vector2i(32,32)
	var atlas:=TileSetAtlasSource.new();atlas.texture=load("res://assets/world_scheme_c/derived/ground_spring.png");atlas.texture_region_size=Vector2i(32,32)
	tiles.add_source(atlas,0)
	for i in range(8): atlas.create_tile(Vector2i(i,0))
	ground.tile_set=tiles
	var region:=RanchLayout.region(site);var random:=RandomNumberGenerator.new();random.seed=absi(site.hash())
	for y in range(region.size.y):
		for x in range(region.size.x):
			var kind: int=random.randi_range(0,2)
			if x in [region.size.x/2-1,region.size.x/2] and y>6: kind=3
			ground.set_cell(Vector2i(x,y),0,Vector2i(kind,0))
	for rect in RanchLayout.obstacles(site):
		var body:=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=0
		var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;body.add_child(collision);add_child(body)
	for i in range(region.size.x*region.size.y/18):
		var at:=Vector2(random.randi_range(2,region.size.x-3)*32+16,random.randi_range(8,region.size.y-4)*32+16)
		if absf(at.x-RanchLayout.world_rect(site).get_center().x)>42: details.append(at)
	build_grid()
	var exit:=Node2D.new();exit.set_script(preload("res://scripts/livestock/ranch_gate.gd"));exit.game=game;exit.site=site;exit.returning=true;exit.position=RanchLayout.entry(site)+Vector2(0,32);actors.add_child(exit)
	var service:=Node2D.new();service.set_script(preload("res://scripts/livestock/ranch_gate.gd"));service.game=game;service.site=site;service.service=true;service.position=RanchLayout.service(site);actors.add_child(service)
	if site=="coop":
		var nest:=Node2D.new();nest.set_script(preload("res://scripts/livestock/livestock_nest.gd"));nest.area_id=RanchLayout.area(site);nest.site=site;actors.add_child(nest)
	Calendar.changed.connect(refresh);refresh()
func build_grid() -> void:
	grid.region=RanchLayout.region(site);grid.cell_size=Vector2(32,32);grid.offset=Vector2(16,16);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x): grid.set_point_solid(Vector2i(x,y),not RanchLayout.point_legal(site,Vector2(x*32+16,y*32+16)))
	var start:=Vector2i((RanchLayout.entry(site)/32).floor());var open: Array[Vector2i]=[start];reachable[start]=true;var head: int=0
	while head<open.size():
		var cell: Vector2i=open[head];head+=1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var at: Vector2i=cell+step
			if grid.region.has_point(at) and not grid.is_point_solid(at) and not reachable.has(at): reachable[at]=true;open.append(at)
func animal_path(entry: Dictionary, from: Vector2, to: Vector2) -> PackedVector2Array:
	route_requests+=1
	if not RanchLayout.point_legal(site,to): return PackedVector2Array()
	var start:=Vector2i((from/32).floor());var end:=Vector2i((to/32).floor())
	if not reachable.has(start) or not reachable.has(end): return PackedVector2Array()
	var blocked: Array[Vector2i]=[]
	for other in Livestock.animals_at(site):
		if other.id==entry.id: continue
		var at:=Vector2i((Livestock.animal_point(other)/32).floor())
		if at!=start and at!=end and grid.region.has_point(at) and not grid.is_point_solid(at): grid.set_point_solid(at,true);blocked.append(at)
	var path:=grid.get_point_path(start,end)
	for at in blocked: grid.set_point_solid(at,false)
	if not path.is_empty():
		# Approach the next cell without snapping the actual body to its grid centre.
		if path.size()>1: path.remove_at(0)
		path.append(to)
	return path
func refresh() -> void:
	if season==Calendar.season(): return
	season=Calendar.season();var atlas: TileSetAtlasSource=ground.tile_set.get_source(0)
	atlas.texture=load("res://assets/world_scheme_c/derived/ground_"+SchemeCAssets.SEASONS[season]+".png");queue_redraw()
func _draw() -> void:
	var extent:=RanchLayout.world_rect(site).size;var room:=RanchLayout.shelter(site)
	for at in details: SchemeCAssets.draw(self,["short_grass","clover","white_wildflowers"][absi(int(at.x+at.y))%3],at,Calendar.season())
	# Cutaway shelter retains a visible warm floor in wet weather and at night.
	draw_rect(room,Color("805c41"));draw_rect(room.grow(-5),Color("c9a576"))
	for x in range(int(room.position.x+12),int(room.end.x-5),16): draw_line(Vector2(x,room.position.y+8),Vector2(x,room.end.y-6),Color("b88e61"),1)
	draw_rect(Rect2(room.position,Vector2(room.size.x,12)),Color("b85f4c"));draw_line(room.position+Vector2(2,2),room.position+Vector2(room.size.x-2,2),Color("efa980"),2)
	for x in range(16,int(extent.x),32):
		SchemeCAssets.draw(self,"wood_fence",Vector2(x,27),Calendar.season())
		SchemeCAssets.draw(self,"wood_fence",Vector2(x,extent.y-5),Calendar.season())
	for y in range(48,int(extent.y-32),32):
		for x in [16,extent.x-16]: SchemeCAssets.draw(self,"wood_fence",Vector2(x,y),Calendar.season())
	for kind in RanchLayout.furniture(site):
		draw_texture(furniture_art[kind],RanchLayout.furniture(site)[kind]+Vector2(-24,-34))
	SchemeCAssets.draw(self,"oak_tree",Vector2(extent.x-176,160),Calendar.season())
