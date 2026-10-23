class_name TouchInteractionResolver
extends RefCounted

static func resolve(game: Node, point: Vector2) -> Dictionary:
	var nearest: Node2D
	var distance := INF
	for object in game.get_tree().get_nodes_in_group("interactables"):
		if not object.is_visible_in_tree(): continue
		# 物件上半部也可点选；优先脚下相近的对象，避免门口误选房后 NPC。
		var offset: Vector2 = point-object.global_position
		var rect := Rect2(-34,-65,68,88)
		if "person_id" in object: rect = Rect2(-22,-48,44,62)
		elif "memory_id" in object: rect = Rect2(-16,-22,32,32)
		elif "prop_kind" in object and object.prop_kind == "windmill": rect = Rect2(-52,-155,104,168)
		if rect.has_point(offset):
			var score := offset.distance_to(Vector2(0,-20))
			if score < distance:
				distance = score
				nearest = object
	if nearest: return {"kind":"object","object":nearest,"point":nearest.global_position}
	if GameState.location == "farm":
		for object in game.world.resource_field.objects.values():
			if game.world.resource_field.state[object.resource_id].hp <= 0: continue
			var rect := Rect2(-25,-80,50,96) if object.kind == "tree" else Rect2(-25,-35,50,48)
			if rect.has_point(point-object.global_position): return {"kind":"resource","object":object,"point":object.global_position}
		var cell := Vector2i((point/32).floor())
		if game.farm.BOUNDS.has_point(cell): return {"kind":"plot","cell":cell,"point":Vector2(cell)*32+Vector2(16,16)}
	return {"kind":"ground","point":point}

static func plot_tool(game: Node, cell: Vector2i) -> String:
	var selected := GameState.tool()
	if GameState.manual_tool or not Story.assisted_tools: return selected
	var plot: Dictionary = game.farm.plots.get(game.farm.key(cell),{})
	if plot.is_empty(): return "hoe"
	if str(plot.crop) == "": return selected if selected.ends_with("_seed") else ""
	if game.farm.is_mature(plot): return "hand"
	if not plot.watered: return "water"
	return ""
