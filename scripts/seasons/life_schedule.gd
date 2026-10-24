class_name LifeSchedule
extends Node
## 节日借用原人物而非复制交互NPC；正常时段交还原工作日程。
var game: Node
var summer_active: bool=false
const SUMMER := {"linya":Vector2(1008,816),"zhou":Vector2(1072,816),"ahe":Vector2(1136,816)}
func attach(owner_game: Node) -> void:
	game=owner_game
	GameClock.changed.connect(refresh);Festival.changed.connect(refresh);Social.changed.connect(refresh)
	Story.changed.connect(refresh);StarStory.changed.connect(refresh)
	refresh()
static func gathering_summer() -> bool:
	return Festival.active_id()=="summer" and GameClock.minutes>=1080 and GameClock.minutes<1380 and Story.stage!=7 and not River.gathering() and StarStory.state.wedding_phase not in [1,2,3]

func refresh() -> void:
	if not is_instance_valid(game) or GameState.restoring: return
	var gathering: bool=gathering_summer()
	if gathering:
		for id in ["zhou","ahe"]:
			var person: Node2D=game.village.villagers[id]
			if person.get_parent()!=game.world.get_node("Actors"):
				person.reparent(game.world.get_node("Actors"),false);person.position=SUMMER[id];person.reset_station()
			person.visible=true;person.process_mode=Node.PROCESS_MODE_INHERIT;person.set_station(SUMMER[id])
		var linya: Node2D=game.world.get_node("Actors/Linya")
		if not summer_active:
			linya.position=SUMMER.linya;linya.reset_station()
		linya.visible=true;linya.process_mode=Node.PROCESS_MODE_INHERIT;linya.set_station(SUMMER.linya)
		game.village.villagers.linya.visible=false
		game.village.villagers.linya.process_mode=Node.PROCESS_MODE_DISABLED
	elif summer_active:
		for id in ["zhou","ahe"]:
			var person: Node2D=game.village.villagers[id]
			person.reparent(game.village.get_node("Actors"),false)
			person.position=Vector2(488,480) if id=="zhou" else Vector2(284,452);person.reset_station()
		game.world.get_node("Actors/Linya").position=Vector2(429,441)
		game.world.refresh_linya();game.village.refresh_gathering()
	summer_active=gathering
