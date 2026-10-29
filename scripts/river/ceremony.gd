class_name StarCeremony
extends RefCounted
static func near(id: String) -> bool:
	var g: Node=StarStory.game
	if not is_instance_valid(g) or GameState.location!="greenhouse" or not g.mine_maps.greenhouse.objects.has(id): return false
	var p: Node2D=g.mine_maps.greenhouse.objects[id]
	return g.player.global_position.distance_to(p.global_position)<=64 and g.auto_move.navigation.line_of_sight(g.player.global_position,p.global_position,p)
static func enter() -> bool:
	if not StarStory.near_point("greenhouse") and GameState.location!="greenhouse": return false
	if not Xiaojing.state.married and LegendState.state.greenhouse<4 and StarStory.state.wedding_phase==0: return false
	River.state.venue_used=true
	StarStory.game.change_location("greenhouse",Vector2(640,730))
	River.commit()
	return true
static func vows() -> bool:
	if not near("vows") or not Xiaojing.state.married or StarStory.state.wedding_phase!=3: return false
	if River.state.wedding_step>=3: return false
	River.state.wedding_step+=1
	River.commit()
	return true
static func leave() -> bool:
	if not near("venue_exit"): return false
	StarStory.game.change_location("farm",Vector2(1360,816))
	return true
static func ready() -> bool:
	return River.state.legacy_scene or (GameState.location=="greenhouse" and River.state.venue_used)
