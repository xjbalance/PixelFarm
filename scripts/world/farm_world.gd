extends Node2D
## 可重复生成的小型农场；地形碰撞放在 TileSet，树石建筑使用实体碰撞。
const MAP_SIZE := Vector2i(48, 32)
const TILE_SIZE: int = 32
const INTERACTABLE = preload("res://scripts/world/interactable.gd")
@onready var ground: TileMapLayer = $Ground
@onready var actors: Node2D = $Actors
var resource_field: Node2D

func _ready() -> void:
	build_tiles()
	build_props()
	build_river_life()
	GameClock.changed.connect(refresh_linya)
	Story.changed.connect(refresh_linya)
	refresh_linya()

func refresh_linya() -> void:
	var person := get_node_or_null("Actors/Linya")
	if person:
		person.visible = not (Story.stage >= 7 and GameClock.minutes >= 1080)
		person.process_mode = Node.PROCESS_MODE_INHERIT if person.visible else Node.PROCESS_MODE_DISABLED

func build_tiles() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tilesets/ground.png")
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tiles.add_source(atlas, 0)
	for i in range(8):
		atlas.create_tile(Vector2i(i, 0))
		if i in [5, 6]:
			var data := atlas.get_tile_data(Vector2i(i, 0), 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16,-16), Vector2(16,-16), Vector2(16,16), Vector2(-16,16)]))
	ground.tile_set = tiles
	var random := RandomNumberGenerator.new()
	random.seed = 7129
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var tile: int = random.randi_range(0, 2)
			if y in [13, 14] or (x in [14, 15] and y > 5): tile = 3
			if Rect2i(16, 15, 12, 8).has_point(Vector2i(x,y)): tile = 4
			var pond := Vector2(x - 34, y - 18).length()
			if pond < 4.8: tile = 3
			if pond < 4.1: tile = 5
			if pond < 2.9: tile = 6
			ground.set_cell(Vector2i(x,y), 0, Vector2i(tile, 0))
	# 世界边缘显式碰撞，超宽屏也不能走出地图。
	for bounds in [Rect2(-32,-32,1600,32), Rect2(-32,1024,1600,32), Rect2(-32,0,32,1024), Rect2(1536,0,32,1024)]:
		add_blocker(bounds, self)

func build_props() -> void:
	add_prop("res://assets/buildings/house.png", Vector2(656, 402), Rect2(-72,-68,144,58))
	add_prop("res://assets/buildings/market.png", Vector2(356, 392), Rect2(-52,-32,104,30))
	add_interaction("home", "进入小屋", Vector2(656, 410))
	add_interaction("shop", "逛逛种子摊", Vector2(356, 416))
	for entry in [{"kind":"workshop","pos":Vector2(820,432)},{"kind":"board","pos":Vector2(968,432)}]:
		var site := Node2D.new()
		site.set_script(preload("res://scripts/world/worksite.gd"))
		site.kind = entry.kind
		site.position = entry.pos
		actors.add_child(site)
	resource_field = Node2D.new()
	resource_field.name = "ResourceField"
	resource_field.set_script(preload("res://scripts/gathering/resource_field.gd"))
	actors.add_child(resource_field)
	for x in range(16,28):
		if x in [20,21,22]: continue
		add_prop("res://assets/tilesets/fence.png", Vector2(x*32+16, 742), Rect2(-15,-8,30,10))
	queue_redraw()

func build_river_life() -> void:
	for entry in [
		{"id":"mail","title":"读信箱里的信","point":Vector2(748,440),"kind":"mail"},
		{"id":"village","title":"前往河湾村","point":Vector2(480,216),"kind":"sign"}
	]:
		var point := Node2D.new()
		point.set_script(preload("res://scripts/world/story_point.gd"))
		point.actor_id = entry.id
		point.title = entry.title
		point.position = entry.point
		point.prop_kind = entry.kind
		actors.add_child(point)
	for kind in ["bush","flowers","lantern","cart"]:
		var placements: Array = {
			"bush":[Vector2(560,402),Vector2(755,373),Vector2(910,310),Vector2(305,690),Vector2(1260,690),Vector2(900,770)],
			"flowers":[Vector2(580,414),Vector2(726,416),Vector2(920,375),Vector2(870,748),Vector2(490,765)],
			"lantern":[Vector2(514,419),Vector2(900,438),Vector2(455,715)],
			"cart":[Vector2(262,418)]
		}[kind]
		for origin in placements:
			var prop := RiverScenery.new()
			prop.kind = kind
			prop.position = origin
			actors.add_child(prop)
	var details := Node2D.new()
	details.set_script(preload("res://scripts/presentation/landscape_details.gd"))
	add_child(details)

func add_prop(path: String, origin: Vector2, collision: Rect2) -> void:
	var prop := Node2D.new()
	prop.position = origin
	actors.add_child(prop)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position.y = -sprite.texture.get_height() / 2.0 + 6
	prop.add_child(sprite)
	add_blocker(collision, prop)

func add_blocker(rect: Rect2, parent: Node) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func add_interaction(kind: String, title: String, origin: Vector2) -> void:
	var point := Node2D.new()
	point.set_script(INTERACTABLE)
	point.kind = kind
	point.label = title
	point.position = origin
	add_child(point)

func _draw() -> void:
	# 小花与草丛使用固定种子，加载时地图外观不变化。
	var random := RandomNumberGenerator.new()
	random.seed = 909
	for i in range(190):
		var pos := Vector2(random.randi_range(80,1450), random.randi_range(70,950))
		var cell := Vector2i(pos / 32.0)
		if ground.get_cell_atlas_coords(cell).x > 2: continue
		draw_line(pos, pos + Vector2(0,-6), Color("62854c"), 2)
		var color := Color("f3dfaa") if i % 3 else Color("dcb2a3")
		draw_rect(Rect2(pos + Vector2(-2,-8),Vector2(4,4)),color)
