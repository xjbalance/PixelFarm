class_name RanchMap
extends Node2D
## Real playable rear pasture. Static route grid is built once; animal targets reuse it.
var site: String="coop"
var game: Node
var ground: TileMapLayer
var actors: Node2D
var grid:=AStarGrid2D.new()
var animal_grid:=AStarGrid2D.new()
var indoor_grid:=AStarGrid2D.new()
var reachable: Dictionary={}
var route_requests: int=0
var season: int=-1
var details: Array[Vector2]=[]
var furniture_art: Dictionary={}
var tree_sprite: Sprite2D
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
	WorldBoundarySkirt.attach(self,ground,region,4)
	for kind in RanchLayout.furniture(site):
		var prop:=Node2D.new();prop.position=RanchLayout.furniture(site)[kind]
		var sprite:=Sprite2D.new();sprite.texture=furniture_art[kind];sprite.position=Vector2(0,-14);prop.add_child(sprite);actors.add_child(prop)
	var shade:=Node2D.new();shade.position=Vector2(RanchLayout.world_rect(site).size.x-176,160)
	tree_sprite=Sprite2D.new();tree_sprite.position=SchemeCAssets.offset("oak_tree");shade.add_child(tree_sprite);actors.add_child(shade)
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
	animal_grid.region=Rect2i(Vector2i.ZERO,grid.region.size*2);animal_grid.cell_size=Vector2(16,16);animal_grid.offset=Vector2(8,8);animal_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;animal_grid.update()
	for y in range(animal_grid.region.size.y):
		for x in range(animal_grid.region.size.x): animal_grid.set_point_solid(Vector2i(x,y),not RanchLayout.point_legal(site,Vector2(x*16+8,y*16+8)))
	var room:=RanchLayout.indoor(site)
	var indoor_start:=Vector2i((room.position/16).floor());var indoor_end:=Vector2i((room.end/16).ceil())
	indoor_grid.region=Rect2i(indoor_start,indoor_end-indoor_start);indoor_grid.cell_size=Vector2(16,16);indoor_grid.offset=Vector2(8,8);indoor_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;indoor_grid.update()
	for y in range(indoor_start.y,indoor_end.y):
		for x in range(indoor_start.x,indoor_end.x):
			var point:=Vector2(x*16+8,y*16+8);indoor_grid.set_point_solid(Vector2i(x,y),not room.has_point(point) or not RanchLayout.point_legal(site,point))

func animal_path(entry: Dictionary, from: Vector2, to: Vector2) -> PackedVector2Array:
	route_requests+=1
	var planner: AStarGrid2D=indoor_grid if not Livestock.is_grazing(site) and RanchLayout.indoor(site).has_point(from) else animal_grid
	if not RanchLayout.point_legal(site,to): return PackedVector2Array()
	var radius: float=21 if entry.species in ["cow","sheep"] else 14
	var blocked: Array[Vector2i]=[]
	for other in Livestock.animals_at(site):
		if other.id==entry.id: continue
		var point:=Livestock.animal_point(other);var at:=Vector2i((point/16).floor())
		for y in range(at.y-2,at.y+3):
			for x in range(at.x-2,at.x+3):
				var cell:=Vector2i(x,y)
				if planner.region.has_point(cell) and not planner.is_point_solid(cell) and (Vector2(cell)*16+Vector2(8,8)).distance_to(point)<radius+2:
					planner.set_point_solid(cell,true);blocked.append(cell)
	var starts: Array[Vector2i]=[];var ends: Array[Vector2i]=[]
	for anchor in [from,to]:
		var center:=Vector2i((anchor/16).floor())
		for y in range(center.y-1,center.y+2):
			for x in range(center.x-1,center.x+2):
				var cell:=Vector2i(x,y);var point:=Vector2(cell)*16+Vector2(8,8)
				if not planner.region.has_point(cell) or planner.is_point_solid(cell): continue
				if anchor==from:
					if Livestock._animal_clear(entry,from,point): starts.append(cell)
				elif Livestock._animal_clear(entry,point,to): ends.append(cell)
	starts.sort_custom(func(a: Vector2i,b: Vector2i): return (Vector2(a)*16+Vector2(8,8)).distance_squared_to(from)<(Vector2(b)*16+Vector2(8,8)).distance_squared_to(from))
	ends.sort_custom(func(a: Vector2i,b: Vector2i): return (Vector2(a)*16+Vector2(8,8)).distance_squared_to(to)<(Vector2(b)*16+Vector2(8,8)).distance_squared_to(to))
	var result:=PackedVector2Array();var cost: float=INF
	for i in range(mini(3,starts.size())):
		for j in range(mini(3,ends.size())):
			var path:=planner.get_point_path(starts[i],ends[j])
			if path.is_empty(): continue
			var length: float=from.distance_to(path[0])+float(path.size())*16+path[-1].distance_to(to)
			if length<cost: result=path;cost=length
	for cell in blocked: planner.set_point_solid(cell,false)
	if not result.is_empty(): result.append(to)
	return result

func refresh() -> void:
	if season==Calendar.season(): return
	season=Calendar.season();var atlas: TileSetAtlasSource=ground.tile_set.get_source(0)
	atlas.texture=load("res://assets/world_scheme_c/derived/ground_"+SchemeCAssets.SEASONS[season]+".png")
	if is_instance_valid(tree_sprite): tree_sprite.texture=SchemeCAssets.texture("oak_tree",season)
	queue_redraw()
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
