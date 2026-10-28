class_name LifeSchedule
extends Node
## 节日借用原人物而非复制交互NPC；正常时段交还原工作日程。
var game: Node
var summer_active: bool=false
const SUMMER := {"linya":Vector2(1008,816),"zhou":Vector2(1072,816),"ahe":Vector2(1136,816)}
func attach(owner_game: Node) -> void:
	game=owner_game
	GameClock.changed.connect(refresh);Festival.changed.connect(refresh);Social.changed.connect(refresh)
	Story.changed.connect(refresh);StarStory.changed.connect(refresh);FarmLayout.changed.connect(refresh)
	refresh()
static func gathering_summer() -> bool:
	return FarmLayout.active("festival_summer") and Festival.active_id()=="summer" and GameClock.minutes>=1080 and GameClock.minutes<1380 and Story.stage!=7 and not River.gathering() and StarStory.state.wedding_phase not in [1,2,3]

func refresh() -> void:
	if not is_instance_valid(game) or GameState.restoring: return
	var gathering: bool=gathering_summer()
	if gathering:
		for id in ["zhou","ahe"]:
			var person: Node2D=game.village.villagers[id]
			if person.get_parent()!=game.world.get_node("Actors"):
				person.reparent(game.world.get_node("Actors"),false);person.position=FarmLayout.transform_point(SUMMER[id],"festival_summer");person.reset_station()
			person.visible=true;person.process_mode=Node.PROCESS_MODE_INHERIT;person.set_station(FarmLayout.transform_point(SUMMER[id],"festival_summer"))
		var linya: Node2D=game.world.get_node("Actors/Linya")
		if not summer_active:
			linya.position=FarmLayout.transform_point(SUMMER.linya,"festival_summer");linya.reset_station()
		linya.visible=true;linya.process_mode=Node.PROCESS_MODE_INHERIT;linya.set_station(FarmLayout.transform_point(SUMMER.linya,"festival_summer"))
		game.village.villagers.linya.visible=false
		game.village.villagers.linya.process_mode=Node.PROCESS_MODE_DISABLED
	elif summer_active:
		for id in ["zhou","ahe"]:
			var person: Node2D=game.village.villagers[id]
			person.reparent(game.village.get_node("Actors"),false)
			person.position=Vector2(488,480) if id=="zhou" else Vector2(284,452);person.reset_station()
		game.world.get_node("Actors/Linya").position=FarmLayout.transform_point(Vector2(429,441),"shop")
		game.world.refresh_linya();game.village.refresh_gathering()
	summer_active=gathering

static func locate(person_id: String) -> Dictionary:
	if not is_instance_valid(Social.game) or (person_id=="xiaojing" and not Xiaojing.state.unlocked): return {}
	var maps: Dictionary=WorldTravel.maps(Social.game)
	for person in Social.get_tree().get_nodes_in_group("interactables"):
		if not "person_id" in person or person.person_id!=person_id or not person.visible: continue
		for id in maps:
			if not maps[id].is_ancestor_of(person): continue
			var at: Vector2=person.global_position
			var place: String=Story.NAMES[id]
			if id=="farm":
				place="农场星光温室旁" if at.distance_to(FarmLayout.point("greenhouse"))<180 else ("农场湖岸" if at.distance_to(FarmLayout.point("lake"))<240 else "农场种子摊附近")
			elif id=="village":
				place="河湾村东岸" if at.x>832 else ("村南社区活动桌附近" if at.y>=680 else ("茶屋附近" if at.x<400 else ("木作坊附近" if at.x<590 else "村庄广场与茶座附近")))
			return {"area":id,"point":at,"description":place}
	return {}
