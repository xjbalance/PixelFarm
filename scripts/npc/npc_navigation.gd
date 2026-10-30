class_name VillagerNavigation
extends RefCounted
## 同物理帧的日程变更共享静态采样，动态人物仍在每次查询精确覆盖。
## 只缓存一张图、一个物理帧，不持有场景节点，也不跨帧复用可能变化的机关。
static var sample_frame: int = -1
static var sample_map: int = 0
static var sample_grid: AStarGrid2D
static var sample_solids: Dictionary = {}
static var dynamic_cells: Array[Vector2i] = []
static var sample_count: int = 0

static func route(person: CharacterBody2D, destination: Vector2) -> PackedVector2Array:
	var map: Node=person.get_parent().get_parent()
	var in_farm := map.name == "FarmWorld"
	var region := FarmLayoutCatalog.GRID if in_farm else Rect2i(0,0,40,28)
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(31,31)
	query.shape = shape
	query.collision_mask = 1
	var space := person.get_world_2d().direct_space_state
	var people: Array[CharacterBody2D]=[]
	var excluded: Array[RID]=[]
	for object in person.get_tree().get_nodes_in_group("interactables"):
		if object is CharacterBody2D:
			excluded.append(object.get_rid())
			if map.is_ancestor_of(object) and object.is_visible_in_tree(): people.append(object)
	if sample_frame!=Engine.get_physics_frames() or sample_map!=map.get_instance_id():
		sample_frame=Engine.get_physics_frames()
		sample_map=map.get_instance_id()
		sample_grid=AStarGrid2D.new()
		sample_grid.region=region
		sample_grid.cell_size=Vector2(32,32)
		sample_grid.offset=Vector2(16,16)
		sample_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		sample_grid.update()
		sample_solids.clear()
		dynamic_cells.clear()
		query.exclude=excluded
		for y in range(region.size.y):
			for x in range(region.size.x):
				var id := Vector2i(x,y)
				query.transform=Transform2D(0,Vector2(id)*32+Vector2(16,16))
				for hit in space.intersect_shape(query,16):
					if hit.collider is CanvasItem and hit.collider.is_visible_in_tree():
						sample_solids[id]=true
						break
				sample_grid.set_point_solid(id,sample_solids.has(id))
		sample_count+=1
	var grid: AStarGrid2D=sample_grid
	for id in dynamic_cells: grid.set_point_solid(id,sample_solids.has(id))
	dynamic_cells.clear()
	# 人物的精确脚底仍由物理空间核验，不能因共享静态格而相互穿过。
	query.exclude=[person.get_rid()]
	var visited: Dictionary={}
	for other in people:
		if other==person: continue
		var at := Vector2i((other.global_position/32).floor())
		for y in range(at.y-1,at.y+2):
			for x in range(at.x-1,at.x+2):
				var id := Vector2i(x,y)
				if not region.has_point(id) or sample_solids.has(id) or visited.has(id): continue
				visited[id]=true
				query.transform=Transform2D(0,Vector2(id)*32+Vector2(16,16))
				for hit in space.intersect_shape(query,16):
					if hit.collider is CanvasItem and hit.collider.is_visible_in_tree():
						grid.set_point_solid(id,true)
						dynamic_cells.append(id)
						break
	var start := Vector2i((person.global_position/32).floor())
	var goal := Vector2i((destination/32).floor())
	if not grid.region.has_point(start) or not grid.region.has_point(goal): return PackedVector2Array()
	grid.set_point_solid(start,false)
	# 还原本次特例清空的起点，防止同帧下一位NPC继承它。
	dynamic_cells.append(start)
	if grid.is_point_solid(goal): return PackedVector2Array()
	return grid.get_point_path(start,goal)
