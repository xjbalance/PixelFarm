class_name StarWorld
extends Node2D
## 日程只在站点改变时规划；仪式宾客为无碰撞表现节点，不挪走主线人物。
var game: Node
var guests: Array[Node2D]=[]
var guest_phase: int = -1
func setup(owner_game: Node) -> void:
	game=owner_game
	StarStory.bind(game)
	for id in StarStory.data.points:
		var entry: Dictionary=StarStory.data.points[id]
		var point := Node2D.new()
		point.set_script(preload("res://scripts/star/star_point.gd"))
		point.star_id=id
		point.position=Vector2(entry.position[0],entry.position[1])
		var map: Node=game.home if entry.area=="home" else game.world.get_node("Actors")
		map.add_child(point)
	for id in ["linya","zhou","ahe"]:
		var sprite := Sprite2D.new()
		sprite.texture=load("res://assets/characters/"+id+".png")
		sprite.position=Vector2(1168+guests.size()*64,870)
		game.world.get_node("Actors").add_child(sprite)
		guests.append(sprite)
	StarStory.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var phase: int=StarStory.state.wedding_phase
	for guest in guests: guest.visible=phase in [1,2,3]
	if phase!=guest_phase:
		guest_phase=phase
		for i in range(guests.size()):
			guests[i].position=Vector2(1168+i*64,870 if phase<3 else 900)
	queue_redraw()
func _process(delta: float) -> void:
	if GameState.modal: return
	if StarStory.state.wedding_phase in [1,2,3]:
		for i in range(guests.size()):
			var goal := Vector2(1168+i*64,850 if StarStory.state.wedding_phase<3 else 880)
			guests[i].position=guests[i].position.move_toward(goal,24*delta)
static func schedule(person: Node, location: String, game: Node) -> void:
	var minute: float=GameClock.minutes
	var married: bool=Xiaojing.state.married
	var place := "village" if minute<1080 else ("home" if married and minute>=1260 else "farm")
	if married and (minute<540 or (minute>=960 and minute<1080)): place="farm"
	if minute>=1080 and minute<1200 and VillageProjects.has_project("arbor"): place="village"
	if StarStory.state.wedding_phase in [1,2,3]: place="farm"
	var desired: Vector2=Vector2(624,624) if location=="village" and minute>=1080 else {"farm":Vector2(1232,800),"village":Vector2(1120,624),"home":Vector2(720,452)}[location]
	if Aquaculture.state.xiaojing.stage==1 and minute>=540 and minute<1080 and StarStory.state.wedding_phase not in [1,2,3]:
		place="farm"
		if location=="farm": desired={"pen_1":Vector2(944,560),"pen_2":Vector2(1072,752),"pen_3":Vector2(1264,624),"pen_4":Vector2(1136,432)}[Aquaculture.state.xiaojing.pen]
	if place=="village" and (GameWeather.is_rainy() or GameWeather.is_snowy()):
		desired=Vector2(352,464) if location=="village" else desired
	var active: bool=Xiaojing.state.unlocked and place==location
	if active and not person.visible:
		if GameState.location==location and game.player.global_position.distance_to(desired)<30:
			if Aquaculture.state.xiaojing.stage==1 and place=="farm":
				desired+={"pen_1":Vector2(0,-32),"pen_2":Vector2(-32,0),"pen_3":Vector2(0,32),"pen_4":Vector2(32,0)}[Aquaculture.state.xiaojing.pen]
			else: desired+=Vector2(40,0)
		person.position=desired
		person.reset_station()
	person.visible=active
	person.process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	person.set_station(desired)
