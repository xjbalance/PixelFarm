class_name TouchInteractionExecutor
extends RefCounted
## 不拥有库存、奖励或剧情状态；到达后仅向原规则系统请求一次。
static func execute(game: Node, target: Dictionary, navigation: WorldNavigation) -> void:
	if GameState.modal or game.backgrounded or game.player.action_time > 0: return
	if target.has("object"):
		if not is_instance_valid(target.object) or not target.object.is_visible_in_tree(): return
		target.point = target.object.global_position
	if not navigation.legal_interaction(game.player.global_position,target): return
	var direction: Vector2 = target.point-game.player.global_position
	if direction.length() > 0.01:
		game.player.facing = Vector2(signf(direction.x),0) if absf(direction.x)>absf(direction.y) else Vector2(0,signf(direction.y))
	game.action_cooldown = 0.16
	match target.kind:
		"object": target.object.interact()
		"plot":
			var tool := TouchInteractionResolver.plot_tool(game,target.cell)
			GameState.manual_tool = false
			if tool == "": Events.notice.emit("这里暂时无需操作；播种前请在工具栏选种子。")
			else: game.farm.use_tool(target.cell,tool)
		"resource":
			var object: Node2D = target.object
			var tool: String = GameState.tool() if GameState.manual_tool or not Story.assisted_tools else FarmResourceCatalog.TYPES[object.kind].tool
			GameState.manual_tool = false
			if game.world.resource_field.hit(object.resource_id,tool): game.player.start_action("采集")
