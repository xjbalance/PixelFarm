class_name WorldNavigation
extends RefCounted
## 32px 基数网格。静态碰撞按变更缓存，动态 NPC 在每次规划时刷新。
## 使用玩家实际脚底与碰撞掩码采样；起点和终点保留真实世界坐标。
# AStarGrid2D 没有逐边禁用接口；对碰撞边施加不可选的高代价，结果再次拒绝该边。
# 合法地图最远路线不到2000格，因而任何真实可达路线都优先于碰撞边。
class CollisionGrid extends AStarGrid2D:
	var blocked_edges: Dictionary = {}
	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		return 1000000.0 if blocked_edges.has(from_id+to_id) else 1.0

var grid := CollisionGrid.new()
var game: Node
var region := Rect2i()
var static_solid: Dictionary = {}
var dynamic_cells: Array[Vector2i] = []
var dirty: bool = true
var ready_frame: int = 0
var rebuild_count: int = 0
var query := PhysicsShapeQueryParameters2D.new()
const NEARBY_LIMIT: float=64.0

func _init(owner_game: Node) -> void:
	game = owner_game
	query.shape=game.player.get_node("CollisionShape2D").shape
	query.collision_mask=game.player.collision_mask
	query.margin=game.player.safe_margin

func foot_transform(at: Vector2) -> Transform2D:
	var transform: Transform2D=game.player.global_transform
	transform.origin=at
	return transform*game.player.get_node("CollisionShape2D").transform

func invalidate() -> void:
	dirty = true
	# TileMap 和 set_deferred 的碰撞必须先在物理服务器同步。
	ready_frame = Engine.get_physics_frames()+2

func center(id: Vector2i) -> Vector2:
	return Vector2(id)*32+Vector2(16,16)

func cell(point: Vector2) -> Vector2i:
	return Vector2i((point/32).floor())

func active_collider(object: Node) -> bool:
	if object is CanvasItem and not object.is_visible_in_tree(): return false
	var map: Node = game.mine_maps.get(GameState.location)
	if map==null:
		match GameState.location:
			"farm": map=game.world
			"home": map=game.home
			"village": map=game.village
	return map == object or map.is_ancestor_of(object)

func people() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for object in game.get_tree().get_nodes_in_group("interactables"):
		if object is CharacterBody2D and active_collider(object): result.append(object)
	return result

func rebuild() -> void:
	if dirty:
		region = WorldTravel.region(GameState.location)
		grid.region = region
		grid.cell_size = Vector2(32,32)
		grid.offset = Vector2(16,16)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.update()
		static_solid.clear()
		grid.blocked_edges.clear()
		dynamic_cells.clear()
		var excluded: Array[RID] = [game.player.get_rid()]
		for object in game.get_tree().get_nodes_in_group("interactables"):
			if object is CharacterBody2D: excluded.append(object.get_rid())
		query.exclude = excluded
		var space := game.player.get_world_2d().direct_space_state as PhysicsDirectSpaceState2D
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var id := Vector2i(x,y)
				query.transform = foot_transform(center(id))
				for hit in space.intersect_shape(query,64):
					if active_collider(hit.collider):
						static_solid[id] = true
						break
				grid.set_point_solid(id,static_solid.has(id))
		# Sweep the same feet that move_and_slide uses. A 20px rectangle used
		# here used to reject passages that the player's 18px circle can enter.
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var id := Vector2i(x,y)
				if static_solid.has(id): continue
				for step in [Vector2i.RIGHT,Vector2i.DOWN]:
					var other: Vector2i=id+step
					if not region.has_point(other) or static_solid.has(other): continue
					query.transform=foot_transform(center(id));query.motion=Vector2(step)*32
					if space.cast_motion(query)[0]<0.99999: grid.blocked_edges[id+other]=true
		query.motion=Vector2.ZERO
		dirty = false
		rebuild_count += 1
	for id in dynamic_cells: grid.set_point_solid(id,static_solid.has(id))
	dynamic_cells.clear()
	var excluded:=query.exclude
	query.exclude=[game.player.get_rid()]
	for person in people():
		var at := cell(person.global_position)
		for y in range(at.y-1,at.y+2):
			for x in range(at.x-1,at.x+2):
				var id := Vector2i(x,y)
				if not region.has_point(id): continue
				query.transform=foot_transform(center(id))
				for hit in game.player.get_world_2d().direct_space_state.intersect_shape(query,64):
					if active_collider(hit.collider):
						grid.set_point_solid(id,true);dynamic_cells.append(id);break
	query.exclude=excluded

func walkable(id: Vector2i) -> bool:
	return region.has_point(id) and not grid.is_point_solid(id)

func collider_rids(node: Node) -> Array[RID]:
	var result: Array[RID] = []
	if node is CollisionObject2D: result.append(node.get_rid())
	if node.has_method("interaction_colliders"):
		for body in node.interaction_colliders():
			if is_instance_valid(body) and body is CollisionObject2D and not result.has(body.get_rid()): result.append(body.get_rid())
	for child in node.get_children(): result.append_array(collider_rids(child))
	return result

func clear_segment(from: Vector2, to: Vector2) -> bool:
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = game.player.get_node("CollisionShape2D").shape
	sweep.transform = foot_transform(from)
	sweep.motion = to-from
	sweep.collision_mask = game.player.collision_mask
	sweep.exclude=[game.player.get_rid()]
	sweep.margin = game.player.safe_margin
	var space := game.player.get_world_2d().direct_space_state as PhysicsDirectSpaceState2D
	# cast_motion 不检查起点相交；两项一起防止读档或动态阻挡时穿透。
	if not space.intersect_shape(sweep,1).is_empty(): return false
	return space.cast_motion(sweep)[0] >= 0.99999

func line_of_sight(from: Vector2, to: Vector2, object: Node = null) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from,to,game.player.collision_mask)
	var excluded: Array[RID]=[game.player.get_rid()]
	if object != null: excluded.append_array(collider_rids(object))
	ray.exclude=excluded
	return game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_reach(target: Dictionary) -> float:
	if target.kind=="plot": return 38.0
	var object: Node=target.get("object")
	# Preserve the old manual reach for story/NPC/mine interactions. Devices
	# and household facilities already enforce 54px in their business layer.
	if target.kind=="object" and object!=null and ("actor_id" in object or "person_id" in object or "mine_id" in object): return 58.0
	return 54.0

func legal_interaction(from: Vector2, target: Dictionary) -> bool:
	var reach:=interaction_reach(target)
	return from.distance_to(target.point) <= reach and line_of_sight(from,target.point,target.get("object"))

func path_to(target: Dictionary) -> PackedVector2Array:
	var origin: Vector2 = game.player.global_position
	if target.kind=="ground": return ground_path(origin,target.point)
	if target.kind != "ground" and legal_interaction(origin,target): return PackedVector2Array([origin])
	var start := cell(origin)
	if not region.has_point(start): return PackedVector2Array()
	# 不把非格心玩家所在格强行改为可通行；挑实际能走到的起始格。
	var starts: Array[Vector2i] = []
	for y in range(start.y-1,start.y+2):
		for x in range(start.x-1,start.x+2):
			var id := Vector2i(x,y)
			if walkable(id) and clear_segment(origin,center(id)): starts.append(id)
	var goal := cell(target.point)
	var candidates: Array[Vector2i] = []
	if target.kind == "ground":
		if walkable(goal): candidates.append(goal)
	else:
		for y in range(goal.y-2,goal.y+3):
			for x in range(goal.x-2,goal.x+3):
				var id := Vector2i(x,y)
				if walkable(id) and legal_interaction(center(id),target): candidates.append(id)
	var best := PackedVector2Array()
	var cost: float = INF
	for anchor in starts:
		for id in candidates:
			var points := grid.get_point_path(anchor,id)
			if points.is_empty(): continue
			var valid := true
			for i in range(1,points.size()):
				if grid.blocked_edges.has(cell(points[i-1])+cell(points[i])):
					valid=false
					break
			if not valid: continue
			var length := origin.distance_to(points[0])+float(points.size()-1)*32
			if length < cost:
				cost = length
				best = points
	return best

func ground_path(origin: Vector2, point: Vector2, allow_nearby: bool=true) -> PackedVector2Array:
	if not region.has_point(cell(point)) or not region.has_point(cell(origin)): return PackedVector2Array()
	# A ground click is an exact world position. Snapping it back to the centre
	# of a 32px cell can leave the player outside a real quest trigger boundary.
	if clear_segment(origin,point): return PackedVector2Array([point])
	var starts: Array[Vector2i]=[]
	var start:=cell(origin)
	for y in range(start.y-1,start.y+2):
		for x in range(start.x-1,start.x+2):
			var id:=Vector2i(x,y)
			if walkable(id) and clear_segment(origin,center(id)): starts.append(id)
	var goal:=cell(point)
	var best:=PackedVector2Array()
	var cost: float=INF
	for y in range(goal.y-1,goal.y+2):
		for x in range(goal.x-1,goal.x+2):
			var id:=Vector2i(x,y)
			if not walkable(id) or not clear_segment(center(id),point): continue
			for anchor in starts:
				var route:=grid.get_point_path(anchor,id)
				if route.is_empty(): continue
				var valid: bool=true
				for i in range(1,route.size()):
					if grid.blocked_edges.has(cell(route[i-1])+cell(route[i])): valid=false;break
				if not valid: continue
				var length: float=origin.distance_to(route[0])+float(route.size()-1)*32+route[-1].distance_to(point)
				if length<cost:
					cost=length;best=route
					if best[-1].distance_to(point)>.01: best.append(point)
	if best.is_empty() and allow_nearby: return nearby_ground_path(origin,point)
	return best

func route_length(origin: Vector2, route: PackedVector2Array) -> float:
	if route.is_empty(): return INF
	var result: float=origin.distance_to(route[0])
	for i in range(1,route.size()): result+=route[i-1].distance_to(route[i])
	return result

func nearby_ground_path(origin: Vector2, point: Vector2) -> PackedVector2Array:
	var goal:=cell(point)
	var best:=PackedVector2Array()
	var cost: float=INF
	# Search only two map tiles around the clicked point, and only use a route
	# from the actual player position. A near point behind a sealed wall loses
	# to a connected point on this side; a local click never sends us round a map.
	var detour_limit: float=origin.distance_to(point)+256.0
	for y in range(goal.y-2,goal.y+3):
		for x in range(goal.x-2,goal.x+3):
			var id:=Vector2i(x,y);var candidate:=center(id)
			var proximity: float=candidate.distance_to(point)
			if not walkable(id) or proximity>NEARBY_LIMIT: continue
			var route:=ground_path(origin,candidate,false)
			var length:=route_length(origin,route)
			if length>detour_limit: continue
			var score: float=proximity*3.0+length
			if score<cost: cost=score;best=route
	return best
