class_name AbyssMap
extends Node2D
var ground: TileMapLayer
var actors: Node2D
var objects: Dictionary={}
var floors: Dictionary={}
var prior_open: bool=false
var last_rebuild_us: int=0
var rebuild_count: int=0
func _ready() -> void:
	name="abyss"
	ground=TileMapLayer.new()
	ground.name="Ground"
	ground.z_index=-5
	add_child(ground)
	actors=Node2D.new()
	actors.name="Actors"
	actors.y_sort_enabled=true
	add_child(actors)
	var tiles := TileSet.new()
	tiles.tile_size=Vector2i(32,32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture=preload("res://assets/tilesets/mines.png")
	atlas.texture_region_size=Vector2i(32,32)
	tiles.add_source(atlas,0)
	for i in range(20):
		atlas.create_tile(Vector2i(i,0))
		if i in [1,5,6,9,13,17]:
			var tile := atlas.get_tile_data(Vector2i(i,0),0)
			tile.set_collision_polygons_count(0,1)
			tile.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set=tiles
	AbyssState.changed.connect(refresh)
	rebuild()
func add_point(id: String, kind: String, cell: Array, symbol: int = 0) -> void:
	var object := StaticBody2D.new()
	object.set_script(preload("res://scripts/abyss/abyss_point.gd"))
	object.abyss_id=id
	object.kind=kind
	object.symbol=symbol
	object.position=AbyssState.point(cell)
	actors.add_child(object)
	objects[id]=object
func rebuild() -> void:
	var started: int=Time.get_ticks_usec()
	for object in objects.values():
		object.hide()
		object.collision_layer=0
		object.queue_free()
	objects.clear()
	floors.clear()
	var d: Dictionary=AbyssState.layout()
	for rect in d.floors:
		for y in range(maxi(1,rect[1]),mini(27,rect[1]+rect[3])):
			for x in range(maxi(1,rect[0]),mini(39,rect[0]+rect[2])): floors[Vector2i(x,y)]=true
	for y in range(28):
		for x in range(40): ground.set_cell(Vector2i(x,y),0,Vector2i(int(d.theme)*4+(0 if floors.has(Vector2i(x,y)) else 1),0))
	add_point("up","up",d.entry)
	add_point("down","down",d.exit)
	add_point("note","note",d.hint)
	add_point("chest","chest",d.chest)
	for i in range(d.controls.size()): add_point("lever_"+str(i),"lever",d.controls[i],i)
	for i in range(d.ores.size()): add_point("ore_"+str(i),"ore",d.ores[i],i)
	if not d.conduit.is_empty(): add_point("conduit","conduit",d.conduit)
	for i in range(d.utility.size()): add_point("utility_"+str(i),"utility",d.utility[i],i)
	if d.has("passage_switch"): add_point("passage","passage",d.passage_switch)
	if d.depth==100: add_point("core","core",[20,21])
	prior_open=not (int(AbyssState.state.depth) in AbyssState.state.gates)
	refresh()
	last_rebuild_us=Time.get_ticks_usec()-started
	rebuild_count+=1
	Events.navigation_changed.emit()
func refresh() -> void:
	var open: bool=int(AbyssState.state.depth) in AbyssState.state.gates
	var d: Dictionary=AbyssState.layout()
	if open!=prior_open:
		prior_open=open
		var r: Array=d.gate
		for y in range(r[1],r[1]+r[3]):
			for x in range(r[0],r[0]+r[2]):
				var tile: int=int(d.theme)*4+(0 if open and floors.has(Vector2i(x,y)) else 1)
				ground.set_cell(Vector2i(x,y),0,Vector2i(tile,0))
	if not d.shortcut.is_empty():
		var r: Array=d.shortcut
		var cell := Vector2i(r[0],r[1])
		ground.set_cell(cell,0,Vector2i(int(d.theme)*4+(0 if int(AbyssState.state.depth) in AbyssState.state.shortcuts else 1),0))
	for at in d.get("passage_cells",[]):
		ground.set_cell(Vector2i(at[0],at[1]),0,Vector2i(int(d.theme)*4+(0 if int(AbyssState.state.depth) in AbyssState.state.shortcuts else 1),0))
	queue_redraw()
func _draw() -> void:
	if not ground: return
	for cell in AbyssState.layout().hazards:
		var at: Vector2=AbyssState.point(cell)
		var rule: String=AbyssState.layout().rule
		var color: Color={"echo":Color("c09a6555"),"water":Color("649bc366"),"prism":Color("a384bb66"),"rubbing":Color("c28a6977"),"beacon":Color("7767ad66")}[rule]
		draw_rect(Rect2(at-Vector2(14,14),Vector2(28,28)),color)
		if rule=="prism": draw_circle(at,13,Color("9d87b244"))
		draw_line(at-Vector2(8,6),at+Vector2(8,6),Color("685347"),3)
