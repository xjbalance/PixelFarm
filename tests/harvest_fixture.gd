extends RefCounted
static func stock() -> void:
	Inventory.coins=100000
	for id in ["wood","stone","copper_bar","iron_bar"]: Inventory.items[id]=200
static func install(test: Node, game: Node, kind: String) -> String:
	while game.hud.close_active_panel(): pass
	if not game.territory_editor.active: game.territory_editor.open()
	await test.frames(4)
	for y in range(23,27):
		for x in range(17,29):
			var plan:=Territory.plan_place("farm",kind,Vector2i(x,y))
			if plan.valid and Territory.apply_plan(plan):
				var id: String=Territory.state.objects[-1].id
				game.territory_editor.cancel();await test.frames(5);return id
	game.territory_editor.cancel();return ""
static func approach(test: Node, game: Node, id: String) -> bool:
	if not game.territory_world.objects.has(id): return false
	var object: Node2D=game.territory_world.objects[id]
	game.auto_move.navigation.rebuild()
	var path: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":object,"point":object.global_position})
	if path.is_empty(): return false
	game.player.position=path[-1];game.camera_rig.follow_now();await test.frames(3)
	return Workshop.near_device(id)
