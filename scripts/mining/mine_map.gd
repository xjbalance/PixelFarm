class_name CaveMap
extends Node2D
## 设计好的房间与分岔。TileMapLayer 同时定义视觉与碰撞；不创建每格脚本节点。
var area_id: String = "mine_a"
var ground: TileMapLayer
var actors: Node2D
var objects: Dictionary = {}
var floors: Dictionary = {}
var gate_status: Dictionary = {}
var layout: Dictionary

func _ready() -> void:
	layout=MineState.layouts[area_id]
	name=area_id
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
	for i in range(12):
		atlas.create_tile(Vector2i(i,0))
		if i in [1,5,6,9]:
			var tile := atlas.get_tile_data(Vector2i(i,0),0)
			tile.set_collision_polygons_count(0,1)
			tile.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set=tiles
	for rect in layout.floors:
		for y in range(rect[1],rect[1]+rect[3]):
			for x in range(rect[0],rect[0]+rect[2]): floors[Vector2i(x,y)]=true
	for y in range(28):
		for x in range(40):
			var cell := Vector2i(x,y)
			var tile: int=int(layout.theme)*4+(0 if floors.has(cell) else 1)
			if area_id=="mine_a" and floors.has(cell) and y in [20,21]: tile=2
			ground.set_cell(cell,0,Vector2i(tile,0))
	if area_id=="mine_b":
		# 河道持续存在，退水只露出石桥，不能把地下河变成整片陆地。
		for y in range(1,27):
			for x in range(25,29): ground.set_cell(Vector2i(x,y),0,Vector2i(6,0))
	for entry in layout.objects:
		var object: Node2D
		if entry.kind=="ore":
			object=StaticBody2D.new()
			object.set_script(preload("res://scripts/mining/ore_node.gd"))
		else:
			object=Node2D.new()
			object.set_script(preload("res://scripts/mining/mine_point.gd"))
		object.entry=entry
		object.mine_id=entry.id
		object.position=MineState.point(entry)
		actors.add_child(object)
		objects[entry.id]=object
	MineState.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for gate in layout.gates:
		var opened: bool=MineState.gate_open(gate.id)
		if gate_status.get(gate.id,null)==opened: continue
		gate_status[gate.id]=opened
		var rect: Array=gate.rect
		var tile: int=int(layout.theme)*4+(0 if opened else 1)
		if gate.id=="water": tile=7 if opened else 6
		if gate.id=="rail" and opened: tile=2
		if gate.id=="resonance" and opened: tile=10
		for y in range(rect[1],rect[1]+rect[3]):
			for x in range(rect[0],rect[0]+rect[2]): ground.set_cell(Vector2i(x,y),0,Vector2i(tile,0))
	queue_redraw()

func _draw() -> void:
	if not layout: return
	# 单次绘制的支架、矿轨、矿车与微光；无阴影灯阵、粒子或每格处理循环。
	for at in [Vector2(112,590),Vector2(528,390),Vector2(944,590)]:
		for x in [-28,28]: draw_rect(Rect2(at+Vector2(x,-46),Vector2(6,50)),Color("8d795c"))
		draw_rect(Rect2(at+Vector2(-32,-49),Vector2(70,6)),Color("ab916a"))
	if area_id=="mine_a":
		var at := Vector2(592,432)
		draw_rect(Rect2(at+Vector2(-21,-28),Vector2(43,23)),Color("716451"))
		for x in [-17,14]: draw_circle(at+Vector2(x,0),7,Color("303f45"))
	elif area_id=="mine_b":
		for x in range(798,930,16): draw_line(Vector2(x,516),Vector2(x,600),Color("87b4be44"),2)
	else:
		for entry in layout.objects:
			if entry.kind in ["resonator","memory"]:
				var at: Vector2=MineState.point(entry)
				draw_circle(at+Vector2(0,-24),52,Color(.55,.62,.96,.06))
				draw_circle(at+Vector2(0,-24),32,Color(.62,.76,.96,.09))
