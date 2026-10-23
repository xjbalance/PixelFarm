class_name WorldNavigation
extends RefCounted
## 32px 基数网格。静态碰撞按变更缓存，动态 NPC 在每次规划时刷新。
## 保守格占位 + 起点脚底扫掠，避免旧档非格心位置直接穿进障碍。
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

func _init(owner_game: Node) -> void:
	game = owner_game
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(20,20)
	query.shape = footprint
	query.collision_mask = 1
	query.margin = 0.01

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
		var excluded: Array[RID] = []
		for object in game.get_tree().get_nodes_in_group("interactables"):
			if object is CharacterBody2D: excluded.append(object.get_rid())
		query.exclude = excluded
		var space := game.player.get_world_2d().direct_space_state as PhysicsDirectSpaceState2D
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var id := Vector2i(x,y)
				query.transform = Transform2D(0,center(id))
				for hit in space.intersect_shape(query,64):
					if active_collider(hit.collider):
						static_solid[id] = true
						break
				grid.set_point_solid(id,static_solid.has(id))
		# 仅格心无碰撞不足以保证相邻格之间可走：薄围栏可能恰好位于格边。
		# 以20px脚底方框扫过相邻格，缓存每条静态边的通行性。
		var foot_shape: Shape2D = query.shape
		var edge_shape := RectangleShape2D.new()
		query.shape=edge_shape
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var id := Vector2i(x,y)
				if static_solid.has(id): continue
				for step in [Vector2i.RIGHT,Vector2i.DOWN]:
					var other: Vector2i=id+step
					if not region.has_point(other) or static_solid.has(other): continue
					edge_shape.size=Vector2(20,20)+Vector2(step)*32
					query.transform=Transform2D(0,(center(id)+center(other))*0.5)
					for hit in space.intersect_shape(query,64):
						if active_collider(hit.collider):
							grid.blocked_edges[id+other]=true
							break
		query.shape=foot_shape
		dirty = false
		rebuild_count += 1
	for id in dynamic_cells: grid.set_point_solid(id,static_solid.has(id))
	dynamic_cells.clear()
	for person in people():
		var at := cell(person.global_position)
		for y in range(at.y-1,at.y+2):
			for x in range(at.x-1,at.x+2):
				var id := Vector2i(x,y)
				var offset: Vector2 = (center(id)-person.global_position).abs()
				if region.has_point(id) and offset.x < 26 and offset.y < 26:
					grid.set_point_solid(id,true)
					dynamic_cells.append(id)

func walkable(id: Vector2i) -> bool:
	return region.has_point(id) and not grid.is_point_solid(id)

func collider_rids(node: Node) -> Array[RID]:
	var result: Array[RID] = []
	if node is CollisionObject2D: result.append(node.get_rid())
	for child in node.get_children(): result.append_array(collider_rids(child))
	return result

func clear_segment(from: Vector2, to: Vector2) -> bool:
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = game.player.get_node("CollisionShape2D").shape
	sweep.transform = Transform2D(0,from)
	sweep.motion = to-from
	sweep.collision_mask = 1
	sweep.margin = 0.2
	var space := game.player.get_world_2d().direct_space_state as PhysicsDirectSpaceState2D
	# cast_motion 不检查起点相交；两项一起防止读档或动态阻挡时穿透。
	if not space.intersect_shape(sweep,1).is_empty(): return false
	return space.cast_motion(sweep)[0] >= 0.999

func line_of_sight(from: Vector2, to: Vector2, object: Node = null) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from,to,1)
	if object != null: ray.exclude = collider_rids(object)
	return game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func legal_interaction(from: Vector2, target: Dictionary) -> bool:
	var reach: float = 38.0 if target.kind == "plot" else 54.0
	return from.distance_to(target.point) <= reach and line_of_sight(from,target.point,target.get("object"))

func path_to(target: Dictionary) -> PackedVector2Array:
	var origin: Vector2 = game.player.global_position
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
