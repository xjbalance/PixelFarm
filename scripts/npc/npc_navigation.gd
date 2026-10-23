class_name VillagerNavigation
extends RefCounted
## NPC 使用简单四向网格，采样当前可见地图的真实脚底碰撞。
static func route(person: CharacterBody2D, destination: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	var in_farm := person.get_parent().get_parent().name == "FarmWorld"
	grid.region = Rect2i(0,0,48,32) if in_farm else Rect2i(0,0,40,28)
	grid.cell_size = Vector2(32,32)
	grid.offset = Vector2(16,16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(31,31)
	query.shape = shape
	query.exclude = [person.get_rid()]
	query.collision_mask = 1
	var space := person.get_world_2d().direct_space_state
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var id := Vector2i(x,y)
			query.transform = Transform2D(0,Vector2(id)*32+Vector2(16,16))
			var solid := false
			for hit in space.intersect_shape(query,16):
				if hit.collider is CanvasItem and hit.collider.is_visible_in_tree():
					solid = true
					break
			grid.set_point_solid(id,solid)
	var start := Vector2i((person.global_position/32).floor())
	var goal := Vector2i((destination/32).floor())
	if not grid.region.has_point(start) or not grid.region.has_point(goal): return PackedVector2Array()
	grid.set_point_solid(start,false)
	if grid.is_point_solid(goal): return PackedVector2Array()
	return grid.get_point_path(start,goal)
