extends Node2D
## 独立室内场景；与农场共享同一玩家，门口和床通过交互信号连接。
var house_level: int = 1
var left_walls: Array[Node]=[]

const INTERACTABLE = preload("res://scripts/world/interactable.gd")

func _ready() -> void:
	var layer: TileMapLayer = $Floor
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32,32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/tilesets/ground.png")
	atlas.texture_region_size = Vector2i(32,32)
	atlas.create_tile(Vector2i(7,0))
	tiles.add_source(atlas,0)
	layer.tile_set = tiles
	for y in range(7,18):
		for x in range(11,29): layer.set_cell(Vector2i(x,y),0,Vector2i(7,0))
	for rect in [Rect2(928,192,16,400),Rect2(352,192,576,32),Rect2(352,576,576,16),Rect2(800,240,96,128),Rect2(400,244,120,45),Rect2(570,304,100,58)]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	set_house_level(1)
	add_point("sleep","睡一觉 · 进入下一天",Vector2(786,342))
	add_point("exit","返回农场",Vector2(640,556))
	var letter_box := Node2D.new()
	letter_box.set_script(preload("res://scripts/world/story_point.gd"))
	letter_box.actor_id = "mail"
	letter_box.title = "读窗下木盒里的旧信"
	letter_box.position = Vector2(720,274)
	add_child(letter_box)
	FarmProgress.changed.connect(queue_redraw)
	queue_redraw()

func add_point(kind: String, title: String, pos: Vector2) -> void:
	var point := Node2D.new()
	point.set_script(INTERACTABLE)
	point.kind = kind
	point.label = title
	point.position = pos
	add_child(point)

func _draw() -> void:
	draw_rect(Rect2(320,144,640,80),Color("263c35"))
	if house_level==1: draw_rect(Rect2(320,224,32,384),Color("263c35"))
	else:
		draw_rect(Rect2(320,224,32,192),Color("263c35"))
		draw_rect(Rect2(320,512,32,96),Color("263c35"))
	draw_rect(Rect2(928,224,32,384),Color("263c35"))
	draw_rect(Rect2(320,576,640,32),Color("263c35"))
	draw_rect(Rect2(336,160,608,64),Color("cfb17d"))
	for x in range(344,940,32):
		draw_line(Vector2(x,160),Vector2(x,222),Color("ad8b63"),2)
	draw_rect(Rect2(336,216,608,8),Color("5f4c3c"))
	# 地毯、床、桌椅与窗户均为原创像素几何，不使用外部素材。
	draw_rect(Rect2(520,394,240,126),Color("7b6660"))
	draw_rect(Rect2(528,402,224,110),Color("bb9268"))
	draw_rect(Rect2(536,410,208,94),Color("bba478"),false,4)
	draw_rect(Rect2(800,240,96,128),Color("5e493e"))
	draw_rect(Rect2(806,250,84,108),Color("ded3a7"))
	draw_rect(Rect2(814,256,68,24),Color("f0e5c4"))
	draw_rect(Rect2(806,290,84,68),Color("658777"))
	for y in range(298,354,16):draw_rect(Rect2(812,y,72,6),Color("87a08b"))
	if FarmProgress.has_upgrade("bedding"):
		draw_rect(Rect2(806,290,84,68),Color("9a777b"))
		for y in range(294,355,14): draw_rect(Rect2(810,y,76,5),Color("d6b694"))
		draw_rect(Rect2(898,250,16,38),Color("a58259"))
		draw_rect(Rect2(898,242,16,12),Color("e7cc83"))
	draw_rect(Rect2(400,244,120,45),Color("72563e"))
	draw_rect(Rect2(406,248,108,31),Color("b58a55"))
	for x in range(414,510,19):draw_rect(Rect2(x,252,11,20),Color("788d6e"))
	draw_rect(Rect2(570,304,100,58),Color("74523f"))
	draw_rect(Rect2(566,298,108,48),Color("bc975f"))
	draw_rect(Rect2(594,310,38,22),Color("ded0a0"))
	draw_circle(Vector2(646,318),7,Color("6d8f79"))
	draw_rect(Rect2(708,254,24,16),Color("947451"))
	draw_rect(Rect2(711,252,18,7),Color("e5d5ae"))
	draw_rect(Rect2(612,172,64,38),Color("665343"))
	draw_rect(Rect2(616,176,56,30),Color("9bc5bc"))
	draw_line(Vector2(644,176),Vector2(644,206),Color("ead9ac"),4)
	draw_rect(Rect2(610,550,60,26),Color("d5bd85"))
	draw_rect(Rect2(620,558,40,8),Color("799079"))

func set_house_level(value: int) -> void:
	if not left_walls.is_empty() and house_level==value: return
	house_level=value
	for body in left_walls:
		remove_child(body);body.queue_free()
	left_walls.clear()
	var bounds: Array=[Rect2(336,192,16,400)] if value==1 else [Rect2(336,192,16,224),Rect2(336,512,16,80)]
	for rect in bounds:
		var body := StaticBody2D.new();body.position=rect.get_center()
		var collision := CollisionShape2D.new();var shape := RectangleShape2D.new();shape.size=rect.size;collision.shape=shape
		body.add_child(collision);add_child(body);left_walls.append(body)
	queue_redraw();Events.navigation_changed.emit()
