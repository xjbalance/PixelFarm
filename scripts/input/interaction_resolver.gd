class_name TouchInteractionResolver
extends RefCounted

static func resolve(game: Node, point: Vector2) -> Dictionary:
	var nearest: Node2D
	var distance := INF
	for object in game.get_tree().get_nodes_in_group("interactables"):
		if not object.is_visible_in_tree(): continue
		if "fish_point_id" in object and GameState.tool()!="fishing_rod": continue
		if ("mine_id" in object or "abyss_id" in object) and "active" in object and not object.active: continue
		# 物件上半部也可点选；优先脚下相近的对象，避免门口误选房后 NPC。
		var offset: Vector2 = point-object.global_position
		# The visible task diamond belongs to its real object, including the part
		# above a desk/building sprite. Keep the same world anchor for navigation.
		if object.has_method("task_marker_rect") and object.task_marker_rect().has_point(offset):
			return {"kind":"object","object":object,"point":object.global_position}
		var rect := Rect2(-34,-65,68,88)
		if "mine_id" in object or "abyss_id" in object: rect = Rect2(-20,-43,40,58)
		elif object.is_in_group("territory_objects") or object.is_in_group("territory_gates"): rect=object.hit_rect()
		elif "development_id" in object: rect=object.hit_rect()
		elif "exploration_id" in object: rect=object.hit_rect()
		elif "builtin_id" in object and object.builtin_id!="": rect=object.hit_rect()
		elif "home_action" in object: rect=object.hit_rect()
		elif "kitchen_id" in object and object.kitchen_id=="kitchen": rect=object.hit_rect()
		elif "housing_id" in object: rect=object.hit_rect()
		elif "festival_id" in object: rect=object.hit_rect()
		elif "site_id" in object: rect=Rect2(-18,-34,36,48)
		elif "fish_point_id" in object or "livestock_id" in object: rect = object.hit_rect()
		elif "kind" in object and object.kind=="recovery": rect=object.hit_rect()
		elif "pen_id" in object: rect = object.hit_rect()
		elif "person_id" in object: rect = Rect2(-22,-48,44,62)
		elif "star_id" in object: rect=Rect2(-24,-30,48,42)
		elif "memory_id" in object: rect = Rect2(-16,-22,32,32)
		elif "prop_kind" in object and object.prop_kind == "windmill": rect = Rect2(-52,-155,104,168)
		if rect.has_point(offset):
			var score := offset.distance_to(Vector2(0,-20))
			if score < distance:
				distance = score
				nearest = object
	var gathering: bool=GameState.manual_tool and GameState.tool() in ["axe","pickaxe","hoe"]
	if nearest and not gathering: return {"kind":"object","object":nearest,"point":nearest.global_position}
	var fishing_target := FishingWorld.resolve_water(game,point)
	if not fishing_target.is_empty(): return fishing_target
	var field: Node2D=game.resource_world.active_field()
	if field:
		var resource: Node2D
		var resource_distance: float=INF
		for object in field.objects.values():
			if object.has_method("is_stored") and object.is_stored(): continue
			if field.state[object.resource_id].hp <= 0: continue
			# Native Scheme C crowns are wider/taller than the old tree. Hit the
			# visible sprite, preserving a small foot target and transparent gaps.
			var foot:=Rect2(-16,-18,32,30)
			var local: Vector2=object.sprite.to_local(point)
			var hit: bool=foot.has_point(point-object.global_position) or (object.sprite.get_rect().has_point(local) and object.sprite.is_pixel_opaque(local))
			if hit:
				var score: float=point.distance_to(object.global_position-Vector2(0,20))
				if score<resource_distance: resource=object;resource_distance=score
		if resource:
			var accessible: Node2D=field.access_target(resource)
			var result: Dictionary={"kind":"resource","object":accessible,"point":accessible.global_position}
			if accessible!=resource: result.covered_resource=str(resource.resource_id)
			return result
	if nearest: return {"kind":"object","object":nearest,"point":nearest.global_position}
	if GameState.location == "farm":
		var cell := Vector2i((point/32).floor())
		if game.farm.can_target_cell(cell): return {"kind":"plot","cell":cell,"point":Vector2(cell)*32+Vector2(16,16)}
	return {"kind":"ground","point":point}

static func plot_tool(game: Node, cell: Vector2i) -> String:
	var selected := GameState.tool()
	if GameState.manual_tool or not Story.assisted_tools: return selected
	var plot: Dictionary = game.farm.plot_at(cell)
	if plot.is_empty(): return "hoe"
	if str(plot.crop) == "": return selected if selected.ends_with("_seed") else ""
	if game.farm.is_mature(plot): return "hand"
	if not plot.watered: return "water"
	return ""
