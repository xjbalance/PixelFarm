extends Node2D
## 河湾村：三层地景、可修复的真实桥梁碰撞和剧情交互点。
const SIZE := Vector2i(40,28)
@onready var ground: TileMapLayer = $Ground
@onready var actors: Node2D = $Actors
var bridge_open: bool = false
var villagers: Dictionary = {}

func _ready() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32,32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tilesets/ground.png")
	atlas.texture_region_size = Vector2i(32,32)
	tiles.add_source(atlas,0)
	for i in range(8):
		atlas.create_tile(Vector2i(i,0))
		if i in [5,6]:
			var data := atlas.get_tile_data(Vector2i(i,0),0)
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set = tiles
	var rng := RandomNumberGenerator.new()
	rng.seed = 234
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var cell := rng.randi_range(0,2)
			if y in [14,15] or (x in [19,20] and y>8) or Rect2i(15,13,9,7).has_point(Vector2i(x,y)): cell = 3
			if x in [26,27,28]: cell = 6 if x==27 else 5
			ground.set_cell(Vector2i(x,y),0,Vector2i(cell,0))
	for bounds in [Rect2(-32,-32,1344,32),Rect2(-32,896,1344,32),Rect2(-32,0,32,896),Rect2(1280,0,32,896)]: blocker(bounds,self)
	house(Vector2(290,357),preload("res://assets/buildings/tea_house.png"))
	house(Vector2(520,350),preload("res://assets/buildings/workshop.png"))
	npc("ahe",Vector2(284,452))
	npc("zhou",Vector2(488,480))
	npc("linya",Vector2(610,442))
	point("farm_return","返回农场",Vector2(640,826),"sign")
	point("bridge","看看旧桥",Vector2(790,450),"")
	point("bridge_survey","调查桥墩水线",Vector2(785,540),"post")
	point("repair_record","查看维修记录",Vector2(570,389),"post")
	point("cargo_note","查看货箱便条",Vector2(1020,370),"post")
	point("mill","读风车下的记录簿",Vector2(1090,350),"windmill")
	point("lantern","点亮风灯",Vector2(628,524),"festival")
	point("bench","长椅 · 等到傍晚",Vector2(540,610),"bench")
	point("well","看看井边的刻痕",Vector2(370,565),"well")
	point("ribbon","树下的蓝丝带",Vector2(1110,590),"ribbon")
	point("post","读旧明信片",Vector2(227,514),"post")
	point("community","河湾共建板",Vector2(680,650),"community")
	decor("cooperative",Vector2(720,342))
	var tea_sign := RiverScenery.new()
	tea_sign.kind = "shop_sign"
	tea_sign.caption = "禾间茶屋"
	tea_sign.position = Vector2(290,361)
	actors.add_child(tea_sign)
	var wood_sign := RiverScenery.new()
	wood_sign.kind = "shop_sign"
	wood_sign.caption = "周砚木作"
	wood_sign.position = Vector2(520,354)
	actors.add_child(wood_sign)
	for origin in [Vector2(218,420),Vector2(740,420),Vector2(950,420),Vector2(700,666)]: decor("lantern",origin)
	for origin in [Vector2(340,420),Vector2(1080,430)]: decor("table",origin)
	decor("cart",Vector2(415,350))
	for origin in [Vector2(190,440),Vector2(410,585),Vector2(710,570),Vector2(990,370),Vector2(1180,380)]:
		decor("flowers",origin)
	for x in range(180,740,64):
		decor("fence",Vector2(x,222))
	for x in range(160,470,64): decor("fence",Vector2(x,700))
	for x in [200,244,288]: decor("garden",Vector2(x,644))
	for origin in [Vector2(165,314),Vector2(650,250),Vector2(740,615),Vector2(180,685),Vector2(1020,710),Vector2(1130,200)]:
		decor("bush",origin)
		decor("flowers",origin+Vector2(32,24))
	for y in [2,3,24,26]:
		for x in range(2,38,3):
			if x in [17,20,26,29]: continue
			var tree := Sprite2D.new()
			tree.texture = preload("res://assets/tilesets/tree.png")
			tree.position = Vector2(x*32,y*32)
			actors.add_child(tree)
			blocker(Rect2(-6,31,12,14),tree)
	var atmosphere := Node2D.new()
	atmosphere.set_script(preload("res://scripts/presentation/landscape_details.gd"))
	atmosphere.set("village",true)
	add_child(atmosphere)
	Story.changed.connect(refresh_bridge)
	GameClock.changed.connect(refresh_gathering)
	Story.changed.connect(refresh_gathering)
	GameWeather.changed.connect(refresh_gathering)
	VillageProjects.changed.connect(refresh_gathering)
	refresh_bridge()
	refresh_gathering()

func refresh_gathering() -> void:
	# 固定工作时段与少量站点；只在可见地图中沿真实可通行路径行走。
	var ending: bool=River.gathering()
	var evening: bool=GameClock.minutes >= 1080 or ending
	var gathering := Story.stage == 7 and evening
	villagers.linya.visible = evening
	villagers.linya.process_mode = Node.PROCESS_MODE_INHERIT if evening else Node.PROCESS_MODE_DISABLED
	var linya_station := Vector2(610,442) if not VillageProjects.has_project("arbor") else Vector2(704,592)
	var zhou_station := Vector2(488,480)
	var ahe_station := Vector2(284,452)
	if Story.stage == 4: zhou_station = Vector2(752,496)
	elif Story.stage >= 5 and GameClock.minutes >= 840 and not evening: zhou_station = Vector2(960,528)
	if VillageProjects.has_project("well") and GameClock.minutes >= 720 and GameClock.minutes < 840: ahe_station = Vector2(432,560)
	if evening and VillageProjects.has_project("arbor"):
		zhou_station = Vector2(496,656)
		ahe_station = Vector2(592,656)
	if (GameWeather.is_rainy() or GameWeather.is_snowy()) and not gathering and not ending:
		# 三位仍留在原地图，改在门廊与木作坊附近，必需人物不消失。
		linya_station=Vector2(608,432)
		zhou_station=Vector2(488,432)
		ahe_station=Vector2(272,432)
	if gathering:
		linya_station=Vector2(610,442)
		zhou_station = Vector2(548,495)
		ahe_station = Vector2(713,510)
	if ending:
		linya_station=Vector2(700,690)
		zhou_station=Vector2(760,690)
		ahe_station=Vector2(810,690)
	var community_linya: Vector2=WorldDevelopment.community_station("linya")
	if community_linya!=Vector2.INF: linya_station=community_linya
	villagers.linya.set_station(linya_station)
	var community_zhou: Vector2=WorldDevelopment.community_station("zhou")
	if community_zhou!=Vector2.INF: zhou_station=community_zhou
	var community_ahe: Vector2=WorldDevelopment.community_station("ahe")
	if community_ahe!=Vector2.INF: ahe_station=community_ahe
	if villagers.zhou.get_parent()==actors: villagers.zhou.set_station(zhou_station)
	if villagers.ahe.get_parent()==actors: villagers.ahe.set_station(ahe_station)

func refresh_bridge() -> void:
	bridge_open = Story.stage >= 5
	for y in [14,15]:
		for x in [26,27,28]: ground.set_cell(Vector2i(x,y),0,Vector2i(7 if bridge_open else 5,0))
	Events.navigation_changed.emit()
	queue_redraw()

func blocker(rect: Rect2,parent: Node) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func house(origin: Vector2, texture: Texture2D) -> void:
	var prop := Node2D.new()
	prop.position = origin
	actors.add_child(prop)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position.y = -78
	prop.add_child(sprite)
	blocker(Rect2(-72,-68,144,58),prop)

func npc(id: String,origin: Vector2) -> void:
	var person := preload("res://scenes/npc/linya.tscn").instantiate()
	person.person_id = id
	person.position = origin
	person.get_node("Sprite2D").texture = load("res://assets/characters/%s.png" % id)
	actors.add_child(person)
	villagers[id] = person

func decor(kind: String,origin: Vector2) -> void:
	var prop := RiverScenery.new()
	prop.kind = kind
	prop.position = origin
	actors.add_child(prop)

func point(id: String,title: String,origin: Vector2,kind: String) -> void:
	var site := Node2D.new()
	site.set_script(preload("res://scripts/world/story_point.gd"))
	site.actor_id = id
	site.title = title
	site.prop_kind = kind
	site.position = origin
	actors.add_child(site)

func _draw() -> void:
	# 桥面与碰撞由同一个状态驱动，旧档恢复也会立即更新通行状态。
	for x in range(824,939,12):
		if not bridge_open and x in range(848,913): continue
		draw_rect(Rect2(x,445,10,68),Color("be9d6f"))
		draw_rect(Rect2(x,447,2,64),Color("d7ba8a"))
	for y in [442,510]:
		if bridge_open: draw_line(Vector2(820,y),Vector2(944,y),Color("78664c"),5)
	for x in [820,940]:
		for y in [443,511]: draw_rect(Rect2(x,y-13,6,20),Color("aa8a60"))
