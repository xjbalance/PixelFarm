class_name HomeBuiltinTarget
extends RefCounted
## 交互点和实体body分开组织时，仍使用同一家具几何并关联合法的碰撞排除。
static func hit_rect(point: Node2D, id: String) -> Rect2:
	var item: Dictionary=Housing.builtin_geometry(id)
	if item.is_empty(): return Rect2(-16,-24,32,40)
	var rect: Rect2=item.footprint
	return Rect2(rect.position-point.global_position,rect.size)
static func colliders(point: Node, id: String) -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D]=[]
	if not is_instance_valid(Housing.game): return result
	for body in point.get_tree().get_nodes_in_group("home_builtin_colliders"):
		if body is CollisionObject2D and body.is_visible_in_tree() and Housing.game.home.is_ancestor_of(body) and body.get_meta("builtin_id","")==id:
			result.append(body)
	return result
