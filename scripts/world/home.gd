extends Node2D
## 可行走的温馨小屋：统一静态碰撞、原交互坐标、原创纹理家具与四级空间。
const INTERACTABLE=preload("res://scripts/world/interactable.gd")
var house_level: int=1
var left_walls: Array[Node]=[]
var collision_root: Node2D
var art_root: Node2D
var art_token: String=""
var wall_texture: Texture2D

func _ready() -> void:
	y_sort_enabled=true
	var layer: TileMapLayer=$Floor;layer.z_index=-5
	var tiles:=TileSet.new();tiles.tile_size=Vector2i(32,32)
	var atlas:=TileSetAtlasSource.new();atlas.texture=load("res://assets/housing/interior/floor_oak_atlas.png");atlas.texture_region_size=Vector2i(32,32);atlas.create_tile(Vector2i(7,0));tiles.add_source(atlas,0);layer.tile_set=tiles
	var cells:=HomeLayout.main_cells()
	for y in range(cells.position.y,cells.end.y):
		for x in range(cells.position.x,cells.end.x): layer.set_cell(Vector2i(x,y),0,Vector2i(7,0))
	collision_root=Node2D.new();collision_root.name="HomeStaticGeometry";add_child(collision_root)
	art_root=Node2D.new();art_root.name="InteriorArtwork";art_root.y_sort_enabled=true;add_child(art_root)
	set_house_level(1)
	add_point("sleep","睡一觉 · 20:00后休息",HomeLayout.ANCHORS.sleep)
	add_point("exit","返回农场",HomeLayout.ANCHORS.exit)
	var letter_box:=Node2D.new();letter_box.set_script(preload("res://scripts/world/story_point.gd"));letter_box.actor_id="mail";letter_box.title="读窗下书桌上的旧信";letter_box.position=HomeLayout.ANCHORS.mail;add_child(letter_box)
	FarmProgress.changed.connect(refresh_art)

func add_point(kind: String,title: String,pos: Vector2) -> void:
	var point:=Node2D.new();point.set_script(INTERACTABLE);point.kind=kind;point.label=title;point.position=pos;add_child(point)

func set_house_level(value: int) -> void:
	value=clampi(value,1,4)
	if not is_instance_valid(collision_root): return
	if not left_walls.is_empty() and house_level==value:
		refresh_art();return
	house_level=value
	for old in collision_root.get_children(): collision_root.remove_child(old);old.queue_free()
	left_walls.clear()
	for rect in HomeLayout.blocked_rects(value):
		var body:=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=0
		var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;body.add_child(collision);collision_root.add_child(body);left_walls.append(body)
	wall_texture=load("res://assets/housing/interior/walls_"+str(value)+".png")
	art_token="";refresh_art();queue_redraw();Events.navigation_changed.emit()

func prop(id: String,at: Vector2,sort_y: float,layer: int=0) -> void:
	var texture: Texture2D=load("res://assets/housing/interior/"+id+".png")
	var sprite:=Sprite2D.new();sprite.name=id.to_pascal_case();sprite.texture=texture;sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=Vector2(at.x+texture.get_width()/2.0,sort_y);sprite.offset=Vector2(-texture.get_width()/2.0,at.y-sort_y);sprite.z_index=layer
	sprite.set_meta("home_art_id",id);sprite.add_to_group("home_interior_art");art_root.add_child(sprite)

func refresh_art() -> void:
	if not is_instance_valid(art_root): return
	var token: String="%d:%s" % [house_level,FarmProgress.has_upgrade("bedding")]
	if token==art_token: return
	art_token=token
	for child in art_root.get_children(): art_root.remove_child(child);child.queue_free()
	prop("main_rug",Vector2(520,394),520,-3)
	prop("dining_rug",Vector2(540,280),384,-3)
	prop("kitchen_tiles",Vector2(784,368),448,-4)
	prop("bed_rug",Vector2(790,232),376,-3)
	prop("dresser",Vector2(392,216),289)
	prop("fireplace_grand" if house_level>=3 else "fireplace",Vector2(536,156),254)
	prop("window_estate" if house_level>=4 else ("window_cottage" if house_level>=2 else "window"),Vector2(632,154),224)
	prop("window_estate" if house_level>=4 else ("window_cottage" if house_level>=2 else "window"),Vector2(824,154),224)
	prop("bed_quilt" if FarmProgress.has_upgrade("bedding") or house_level>=3 else "bed",Vector2(800,240),368)
	prop("dining_table",Vector2(560,288),362)
	prop("chair_left",Vector2(540,312),350)
	prop("chair_right",Vector2(672,312),350)
	prop("mail_desk",Vector2(684,224),258)
	prop("storage_slim",Vector2(352,432),478)
	prop("kitchen_estate" if house_level>=4 else "kitchen",Vector2(792,368),418)
	prop("sofa_estate" if house_level>=4 else ("sofa_cottage" if house_level>=2 else "sofa"),Vector2(660,448),496)
	prop("lamp",Vector2(896,238),284)
	prop("plant",Vector2(880,504),568)
	if house_level>=3: prop("bedroom_divider",Vector2(744,220),304)
	if house_level>=4:
		prop("star_map",Vector2(442,158),224)
		prop("star_lantern",Vector2(728,154),224)
	if house_level>=2:
		var room:=HomeLayout.extension_cells(house_level)
		var start:=Vector2(room.position)*32
		prop("study_desk_"+str(house_level),start+Vector2(8,-16),start.y+24)
		prop("window_estate" if house_level>=4 else "window_cottage",start+Vector2(Vector2(room.size).x*16-44,-48),start.y)
		prop("study_rug_2" if house_level==2 else ("study_rug_4" if house_level==4 else "study_rug"),start+Vector2(24 if house_level<4 else 32,40),start.y+216,-3)
		prop("plant",start+Vector2(-2,Vector2(room.size).y*32-64),start.y+Vector2(room.size).y*32)
		if house_level>=3: prop("bookcase",start+Vector2(24,Vector2(room.size).y*32-48),start.y+Vector2(room.size).y*32)
		if house_level>=4: prop("bookcase",start+Vector2(184,Vector2(room.size).y*32-48),start.y+Vector2(room.size).y*32)
	queue_redraw()

func _draw() -> void:
	if wall_texture: draw_texture(wall_texture,Vector2(320,144))
