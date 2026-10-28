class_name TerritoryWorld
extends Node
## 领地显示及实际占地校验。只新增地上附属地，原地图/作物/地下关卡不重建。
const MAP_SCRIPT=preload("res://scripts/territory/territory_map.gd")
const SURFACE_SCRIPT=preload("res://scripts/territory/territory_surface.gd")
const OBJECT_SCRIPT=preload("res://scripts/territory/territory_object.gd")
const GATE_SCRIPT=preload("res://scripts/territory/territory_gate.gd")
var game: Node
var maps: Dictionary={}
var surfaces: Dictionary={}
var objects: Dictionary={}
var gates: Dictionary={}
var _protected_cache: Dictionary={}
var _base_solids: Dictionary={}
var _base_area: String=""
var _base_revision: int=-1
static var _textures: Dictionary={}

func setup(owner_game: Node) -> void:
	game=owner_game
	maps.farm=game.world
	for area in TerritoryCatalog.ANNEX_AREAS:
		var map:=Node2D.new();map.set_script(MAP_SCRIPT);map.area_id=area
		map.hide();map.process_mode=Node.PROCESS_MODE_DISABLED;game.add_child(map)
		map.ground.enabled=false;game.mine_maps[area]=map;maps[area]=map
		var exit:=Node2D.new();exit.set_script(GATE_SCRIPT);exit.game=game;exit.area_id=area;exit.returning=true
		exit.position=Vector2(640,816);map.actors.add_child(exit)
		var entry: Dictionary=TerritoryCatalog.region(area)
		var gate:=Node2D.new();gate.set_script(GATE_SCRIPT);gate.game=game;gate.destination=area
		var at: Array=entry.gate_position;gate.position=Vector2(at[0],at[1]);game.world.actors.add_child(gate);gates[area]=gate
	for area in maps:
		var surface:=Node2D.new();surface.set_script(SURFACE_SCRIPT);surface.area_id=area;maps[area].add_child(surface);surfaces[area]=surface
	Territory.bind(game,validate_plan)
	Territory.changed.connect(refresh)
	Events.navigation_changed.connect(invalidate_geometry)
	Housing.changed.connect(invalidate_geometry)
	Events.location_changed.connect(func(_area: String): invalidate_geometry())
	refresh()

func invalidate_geometry() -> void:
	_base_revision=-1;_protected_cache.clear()

func refresh() -> void:
	if not is_instance_valid(game): return
	var wanted: Dictionary={}
	for entry in Territory.state.get("objects",[]):
		var id: String=str(entry.id);wanted[id]=true
		if not objects.has(id):
			var object:=Node2D.new();object.set_script(OBJECT_SCRIPT);object.game=game;object.entry_id=id
			maps[str(entry.area)].get_node("Actors").add_child(object);objects[id]=object
		objects[id].refresh()
	for id in objects.keys():
		if wanted.has(id): continue
		var old: Node2D=objects[id];objects.erase(id)
		old.remove_from_group("interactables");old.remove_from_group("territory_objects")
		if old.is_in_group("territory_storage"): old.remove_from_group("territory_storage")
		if is_instance_valid(old.body): old.body.collision_layer=0
		old.queue_free()
	for surface in surfaces.values(): surface.refresh()
	for gate in gates.values(): gate.queue_redraw()
	invalidate_geometry()

static func texture_for(kind: String) -> Texture2D:
	var key: String=kind+("_"+str(Calendar.season()) if kind=="tree" else "")
	if _textures.has(key): return _textures[key]
	var path: String=""
	if kind=="tree": path="res://assets/farm06/tree_"+["spring","summer","autumn","winter"][Calendar.season()]+".png"
	elif kind in ["table","chair"]: path="res://assets/housing/"+kind+".png"
	elif kind=="lamp": path="res://assets/housing/yard_lamp.png"
	elif kind=="fence": path="res://assets/tilesets/fence.png"
	var result: Texture2D=load(path) if path!="" and ResourceLoader.exists(path) else null
	_textures[key]=result;return result

func object_texture(kind: String) -> Texture2D: return texture_for(kind)

func object_at(area: String, cell: Vector2i) -> Dictionary:
	for entry in Territory.state.get("objects",[]):
		if str(entry.area)==area and TerritoryCatalog.footprint(str(entry.kind),TerritoryCatalog.to_cell(entry.cell)).has_point(cell): return entry.duplicate(true)
	return {}

func _mark_rect(result: Dictionary, rect: Rect2, region: Rect2i, margin: float=0) -> void:
	var expanded:=rect.grow(margin)
	var start:=Vector2i((expanded.position/32).floor())
	var end:=Vector2i((expanded.end/32).ceil())
	for y in range(maxi(region.position.y,start.y),mini(region.end.y,end.y)):
		for x in range(maxi(region.position.x,start.x),mini(region.end.x,end.x)):
			if expanded.intersects(Rect2(x*32,y*32,32,32)): result[Vector2i(x,y)]=true

func protected_cells(area: String) -> Dictionary:
	if _protected_cache.has(area): return _protected_cache[area]
	var result: Dictionary={}
	var region:=Rect2i(0,0,48,32) if area=="farm" else Rect2i(0,0,40,28)
	var definition: Dictionary=TerritoryCatalog.region(area)
	for reserved: Rect2i in definition.protected:
		for y in range(reserved.position.y,reserved.end.y):
			for x in range(reserved.position.x,reserved.end.x): result[Vector2i(x,y)]=true
	if area=="farm":
		# 原资源再生坐标永久保留，即使今天已经采尽，也不能被装修覆盖。
		for entry in FarmResourceCatalog.placements("farm").values():
			_mark_rect(result,Rect2(Vector2(entry.cell)*32-Vector2(26,32),Vector2(52,52)),region,8)
		# 建筑的屋顶/外墙也保留，不只保护狭窄的物理脚底。
		for rect in [Rect2(560,242,192,204),Rect2(288,306,136,146)]: _mark_rect(result,rect,region)
		for placed in Housing.state.placed:
			if placed.area!="farm": continue
			var rect: Rect2i=Housing.footprint(placed.kind,TerritoryCatalog.to_cell(placed.cell))
			_mark_rect(result,Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32),region,4)
		for object in game.get_tree().get_nodes_in_group("interactables"):
			if object is CharacterBody2D or not game.world.is_ancestor_of(object) or object.is_in_group("territory_objects"): continue
			# 节日牌即使今天隐藏，也保留下一季到访的合法站位。
			_mark_rect(result,Rect2(object.global_position-Vector2(42,42),Vector2(84,84)),region)
	_protected_cache[area]=result
	return result

func validate_plan(plan: Dictionary) -> Dictionary:
	if not is_instance_valid(game): return {"valid":false,"reason":"领地场景尚未就绪。"}
	var area: String=str(plan.get("area",""))
	if not maps.has(area) or GameState.location!=area: return {"valid":false,"reason":"只能改造当前所在的私人领地。"}
	var operation: String=str(plan.get("op",""))
	if operation=="remove": return {"valid":true,"reason":""}
	var kind: String=str(plan.get("kind",""))
	var cells: Array=plan.get("cells",[])
	if cells.is_empty(): return {"valid":false,"reason":"先在领地中选择要改造的地格。"}
	var claimed: Dictionary=protected_cells(area)
	var rects: Array[Rect2i]=[]
	for value in cells:
		var cell: Vector2i=TerritoryCatalog.to_cell(value)
		var rect: Rect2i=Rect2i(cell,Vector2i.ONE) if operation=="terrain" else TerritoryCatalog.footprint(kind,cell)
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if claimed.has(Vector2i(x,y)): return {"valid":false,"reason":"这里保留原农田、资源、门口或剧情交互通路，不能覆盖。"}
		rects.append(rect)
	var solid: bool=operation!="terrain" and TerritoryCatalog.is_solid(kind)
	var excluded: Array[RID]=[]
	var except_id: String=str(plan.get("id","")) if operation=="move" else ""
	if except_id!="" and objects.has(except_id): excluded=game.auto_move.navigation.collider_rids(objects[except_id])
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=RectangleShape2D.new();query.shape=shape;query.collision_mask=1;query.exclude=excluded
	var map: Node=maps[area]
	for rect in rects:
		var bounds:=Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32)
		if solid and bounds.grow(12).has_point(game.player.global_position): return {"valid":false,"reason":"不能将角色围在新物件里，请换一个位置。"}
		for person in game.get_tree().get_nodes_in_group("interactables"):
			if solid and person is CharacterBody2D and map.is_ancestor_of(person) and person.is_visible_in_tree() and bounds.grow(18).has_point(person.global_position): return {"valid":false,"reason":"请避开人物当前的站位。"}
		shape.size=bounds.size-Vector2(4,4);query.transform=Transform2D(0,bounds.get_center())
		for hit in game.player.get_world_2d().direct_space_state.intersect_shape(query,64):
			if map==hit.collider or map.is_ancestor_of(hit.collider): return {"valid":false,"reason":"这里与水面、建筑或已有物件重叠。"}
	if solid:
		return _validate_routes(plan)
	return {"valid":true,"reason":""}

func _baseline() -> Dictionary:
	var nav: WorldNavigation=game.auto_move.navigation
	if Engine.get_physics_frames()<nav.ready_frame: return {"ready":false}
	nav.rebuild()
	if _base_area==GameState.location and _base_revision==nav.rebuild_count: return {"ready":true,"solids":_base_solids}
	_base_area=GameState.location;_base_revision=nav.rebuild_count;_base_solids=nav.static_solid.duplicate()
	# 基底不包含本系统物件；候选布局将在下面一次性重新覆盖，移动/拆除不留下幽灵占地。
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(20,20);query.shape=shape;query.collision_mask=1
	var excluded: Array[RID]=[];var touched: Dictionary={}
	for node in game.get_tree().get_nodes_in_group("interactables"):
		if node is CharacterBody2D: excluded.append(node.get_rid())
	for node in objects.values():
		excluded.append(node.body.get_rid())
		if str(node.entry.get("area",""))!=GameState.location: continue
		var rect: Rect2i=TerritoryCatalog.footprint(str(node.entry.kind),TerritoryCatalog.to_cell(node.entry.cell))
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): touched[Vector2i(x,y)]=true
	query.exclude=excluded
	var map: Node=maps[GameState.location]
	for cell in touched:
		_base_solids.erase(cell);query.transform=Transform2D(0,Vector2(cell)*32+Vector2(16,16))
		for hit in game.player.get_world_2d().direct_space_state.intersect_shape(query,64):
			if map==hit.collider or map.is_ancestor_of(hit.collider): _base_solids[cell]=true;break
	return {"ready":true,"solids":_base_solids}

func _object_solids(base: Dictionary, records: Array) -> Dictionary:
	var solids:=base.duplicate()
	for entry in records:
		if str(entry.area)!=GameState.location or not TerritoryCatalog.is_solid(str(entry.kind)): continue
		var rect: Rect2i=TerritoryCatalog.footprint(str(entry.kind),TerritoryCatalog.to_cell(entry.cell))
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): solids[Vector2i(x,y)]=true
	return solids

func _flood(solids: Dictionary) -> Dictionary:
	var nav: WorldNavigation=game.auto_move.navigation
	var start:=Vector2i((game.player.global_position/32).floor())
	var region: Rect2i=nav.region
	var open: Array[Vector2i]=[];var reached: Dictionary={}
	for y in range(start.y-1,start.y+2):
		for x in range(start.x-1,start.x+2):
			var cell:=Vector2i(x,y)
			if region.has_point(cell) and not solids.has(cell) and game.player.global_position.distance_to(Vector2(cell)*32+Vector2(16,16))<34 and nav.clear_segment(game.player.global_position,Vector2(cell)*32+Vector2(16,16)):
				open.append(cell);reached[cell]=true
	var head: int=0
	while head<open.size():
		var cell: Vector2i=open[head];head+=1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+step
			if region.has_point(next) and not solids.has(next) and not reached.has(next) and not nav.grid.blocked_edges.has(cell+next): reached[next]=true;open.append(next)
	return reached

func _approachable(point: Vector2, reached: Dictionary, distance: float=54) -> bool:
	var cell:=Vector2i((point/32).floor())
	for y in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var candidate:=Vector2i(x,y)
			if reached.has(candidate) and (Vector2(candidate)*32+Vector2(16,16)).distance_to(point)<=distance: return true
	return false

func _validate_routes(plan: Dictionary) -> Dictionary:
	var baseline:=_baseline()
	if not baseline.ready: return {"valid":false,"reason":"通路正在更新，请稍候再确认。"}
	var current: Array=Territory.state.objects
	var proposed: Array=current.duplicate(true)
	if str(plan.op)=="move":
		for entry in proposed:
			if str(entry.id)==str(plan.id):
				var cell:=TerritoryCatalog.to_cell(plan.cells[0]);entry.cell=[cell.x,cell.y];break
	else:
		var cell:=TerritoryCatalog.to_cell(plan.cells[0]);proposed.append({"id":"preview","area":str(plan.area),"kind":str(plan.kind),"cell":[cell.x,cell.y]})
	var before:=_flood(_object_solids(baseline.solids,current))
	var after:=_flood(_object_solids(baseline.solids,proposed))
	if after.is_empty(): return {"valid":false,"reason":"摆放会封住角色的通路。"}
	# 不因装修切断现有可达的出口、人物、服务点、原农田或资源采集面。
	var points: Array[Vector2]=[]
	var map: Node=maps[GameState.location]
	for object in game.get_tree().get_nodes_in_group("interactables"):
		if not map.is_ancestor_of(object) or not object.is_visible_in_tree() or object.is_in_group("territory_objects"): continue
		if object is CharacterBody2D:
			var cell:=Vector2i((object.global_position/32).floor())
			if before.has(cell) and not after.has(cell): return {"valid":false,"reason":"摆放会将人物与原有通路隔开。"}
		else: points.append(object.global_position)
	if GameState.location=="farm":
		for y in range(16,22):
			for x in range(17,27): points.append(Vector2(x*32+16,y*32+16))
		for entry in FarmResourceCatalog.placements("farm").values(): points.append(Vector2(entry.cell)*32)
	for entry in proposed:
		if str(entry.area)==GameState.location:
			var rect:=TerritoryCatalog.footprint(str(entry.kind),TerritoryCatalog.to_cell(entry.cell));points.append(Vector2(rect.position)*32+Vector2(rect.size)*16)
	for point in points:
		if _approachable(point,before) and not _approachable(point,after): return {"valid":false,"reason":"摆放会切断门口、设施、农田或人物的现有通路。"}
	return {"valid":true,"reason":""}
