class_name WorldTravel
extends RefCounted
## 六张地图共享一个玩家与摄像机，地图切换仍由主场景公开入口调用。
static func create_mines(game: Node) -> void:
	MineState.bind(game)
	for id in MineState.AREAS:
		var map := CaveMap.new()
		map.area_id=id
		game.add_child(map)
		map.hide()
		map.process_mode=Node.PROCESS_MODE_DISABLED
		map.ground.enabled=false
		game.mine_maps[id]=map
	for id in MineState.services:
		var entry: Dictionary=MineState.services[id].duplicate(true)
		entry.kind="service"
		var point := Node2D.new()
		point.set_script(preload("res://scripts/mining/mine_point.gd"))
		point.mine_id=id
		point.entry=entry
		point.position=MineState.point(entry)
		game.village.get_node("Actors").add_child(point)
	var abyss := AbyssMap.new()
	game.add_child(abyss)
	abyss.hide()
	abyss.process_mode=Node.PROCESS_MODE_DISABLED
	abyss.ground.enabled=false
	game.mine_maps.abyss=abyss
	AbyssState.game=game
	var hoist := StaticBody2D.new()
	hoist.set_script(preload("res://scripts/abyss/abyss_point.gd"))
	hoist.kind="entrance"
	hoist.abyss_id="entrance"
	hoist.position=Vector2(208,688)
	game.mine_maps.mine_c.actors.add_child(hoist)
	var venue := preload("res://scenes/world/greenhouse.tscn").instantiate()
	venue.game=game
	game.add_child(venue)
	venue.hide();venue.process_mode=Node.PROCESS_MODE_DISABLED;venue.ground.enabled=false
	game.mine_maps.greenhouse=venue
	for id in River.data.points:
		var item: Dictionary=River.data.points[id]
		var probe := Node2D.new()
		probe.set_script(preload("res://scripts/river/river_point.gd"))
		probe.river_id="probe:"+str(id);probe.title=item.title;probe.position=river_point(str(id))
		var parent: Node=game.world.get_node("Actors") if item.area=="farm" else game.village.get_node("Actors")
		parent.add_child(probe)
	var transport := Node2D.new()
	transport.set_script(preload("res://scripts/river/river_world.gd"))
	transport.position=Vector2(800,752)
	game.village.get_node("Actors").add_child(transport)
	# 只用一盏无阴影玩家灯，随地图开关，避免矿区叠加多盏实时灯。
	var light := PointLight2D.new()
	light.name="CaveLamp"
	var texture := GradientTexture2D.new()
	texture.width=128
	texture.height=128
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(1,.88,.68,.9),Color(1,.88,.68,0)])
	texture.gradient=gradient
	light.texture=texture
	light.texture_scale=4
	light.energy=.8
	light.shadow_enabled=false
	light.enabled=false
	game.player.add_child(light)

static func river_point(id: String) -> Vector2:
	var item: Dictionary=River.data.points[id]
	var original:=Vector2(item.position[0],item.position[1])
	return FarmLayout.point("river:"+id) if item.area=="farm" else original

static func maps(game: Node) -> Dictionary:
	var result := {"farm":game.world,"home":game.home,"village":game.village}
	result.merge(game.mine_maps)
	return result

static func region(location: String) -> Rect2i:
	if location in RanchLayout.AREAS: return RanchLayout.region(RanchLayout.site(location))
	if location=="farm": return FarmLayoutCatalog.GRID
	if location=="home": return HomeLayout.navigation_region(int(Housing.state.level))
	return Rect2i(0,0,40,28)

static func entry(location: String) -> Vector2:
	if location in RanchLayout.AREAS: return RanchLayout.entry(RanchLayout.site(location))
	if location in TerritoryCatalog.ANNEX_AREAS:
		var at: Array=TerritoryCatalog.region(location).entry
		return Vector2(at[0],at[1])
	if location in Exploration.AREAS: return Exploration.entry(location)
	if location=="greenhouse": return Vector2(640,730)
	if location=="abyss": return AbyssState.point(AbyssState.layout().entry)
	if location in MineState.AREAS:
		var at: Array=MineState.layouts[location].entry
		return Vector2(at[0]*32+16,at[1]*32+16)
	return {"farm":FarmLayout.transform_point(Vector2(656,440),"home"),"home":Vector2(640,500),"village":Vector2(640,756)}[location]

static func change(game: Node, destination: String, saved_position: Vector2 = Vector2.INF) -> bool:
	var all_maps := maps(game)
	if not all_maps.has(destination): return false
	if destination in RanchLayout.AREAS:
		var site:=RanchLayout.site(destination)
		if site not in RanchLayout.ENABLED or int(Livestock.building(site).level)<1 or not FarmLayout.active(site): return false
	if destination in TerritoryCatalog.ANNEX_AREAS and not Territory.unlocked(destination):
		Events.notice.emit(TerritoryCatalog.region(destination).hint);return false
	if destination in Exploration.AREAS and not Exploration.unlocked(destination):
		Events.notice.emit("遗址尚未开放，请先按入口的调查提示行动。")
		return false
	if destination=="greenhouse" and not Xiaojing.state.married and LegendState.state.greenhouse<4: return false
	if destination=="abyss" and not AbyssState.state.unlocked: return false
	if destination in MineState.AREAS and destination not in MineState.state.unlocked:
		Events.notice.emit("矿道尚未开放，先沿第二章线索调查。")
		return false
	if game.auto_move: game.auto_move.cancel()
	var previous: String=GameState.location
	if previous in MineState.AREAS and destination not in MineState.AREAS: Playtest.record("mine_exit",{"source":previous})
	if previous not in MineState.AREAS and destination in MineState.AREAS: Playtest.record("mine_enter",{"source":destination})
	GameState.location=destination
	game.player.touch_direction=Vector2.ZERO
	game.player.auto_direction=Vector2.ZERO
	game.player.velocity=Vector2.ZERO
	game.player.action_time=0
	game.player.get_node("Sprite2D").position=game.player.visual_offset()
	game.hud.joystick.reset()
	var active: Node2D=all_maps[destination]
	var actors: Node=active.get_node_or_null("Actors")
	game.player.reparent(actors if actors else active,false)
	for id in all_maps:
		var map: Node2D=all_maps[id]
		map.visible=id==destination
		map.process_mode=Node.PROCESS_MODE_INHERIT if map.visible else Node.PROCESS_MODE_DISABLED
		var ground: TileMapLayer=map.get_node_or_null("Ground")
		if ground: ground.enabled=map.visible
	game.player.position=saved_position if saved_position!=Vector2.INF else entry(destination)
	if destination=="farm" and previous!="farm": game.call_deferred("recover_blocked_position")
	var camera: Camera2D=game.player.get_node("Camera2D")
	camera.zoom=Vector2.ONE if destination in ["home","greenhouse"] else Vector2(1.35,1.35)
	camera.position=Vector2.ZERO
	camera.reset_smoothing()
	game.player.get_node("CaveLamp").energy=.55 if destination=="abyss" and AbyssState.state.depth>=81 else .8
	game.player.get_node("CaveLamp").enabled=destination in MineState.AREAS or destination=="abyss"
	game.get_node("DayNight").refresh()
	Events.location_changed.emit(destination)
	if destination in ["farm","home","village"]: Xiaojing.record_location(destination)
	game.call_deferred("restore_schedules")
	GameState.changed.emit()
	return true
