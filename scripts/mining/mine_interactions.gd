class_name MineInteractions
extends RefCounted

static func request(game: Node, id: String) -> void:
	if id=="journal": game.hud.mine_panel.open_panel("journal"); return
	if id=="enter":
		if MineState.near_service("entrance"): game.change_location("mine_a")
		return
	if id.begins_with("talk:"):
		game.hud.mine_panel.open_panel(id)
		return
	if MineState.services.has(id):
		if MineState.near_service(id): game.hud.mine_panel.open_panel(id)
		return
	if not MineState.near_id(id): return
	var entry: Dictionary=MineState.placements[id]
	match entry.kind:
		"exit":
			if entry.destination in MineState.AREAS and entry.destination not in MineState.state.unlocked:
				Events.notice.emit("先完成矿道手记当前任务，再打开下一层。")
				return
			if id=="a_exit" and not MineState.state.expedition.is_empty(): MineState.finish_expedition()
			var at := Vector2.INF
			if entry.has("arrival"): at=Vector2(entry.arrival[0],entry.arrival[1])
			game.change_location(entry.destination,at)
		"rail":
			if not MineState.state.track_repaired: game.hud.mine_panel.open_panel(id)
			else: MineState.operate(id)
		"valve","hardened","resonator": MineState.operate(id)
		"star":
			if not Xiaojing.mechanism_input(int(entry.symbol)): Events.notice.emit("先与小京约定星灯试炼，收齐七份记忆后再试。")
		"chest":
			if not MineState.claim_chest(id): Events.notice.emit("箱中物品已经取走，或背包暂时放不下。")
		"note": game.hud.mine_panel.open_panel(id)
		"memory": game.hud.star_panel.open_panel("memory:"+str(entry.memory))
