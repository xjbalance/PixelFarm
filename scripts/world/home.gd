extends Node2D
## 温馨田园小屋：家具绘制、碰撞与交互位置共用HomeLayout动态记录。
const INTERACTABLE=preload("res://scripts/world/interactable.gd")
var house_level: int=1
var left_walls: Array[Node]=[]
var collision_root: Node2D
var art_root: Node2D
var art_token: String=""
var geometry_token: String=""
var wall_texture: Texture2D

func _ready() -> void:
	y_sort_enabled=true
	var layer: TileMapLayer=$Floor;layer.z_index=-5
	var tiles:=TileSet.new();tiles.tile_size=Vector2i(32,32)
	var atlas:=TileSetAtlasSource.new();atlas.texture=SchemeCAssets.home_texture("floor_oak_atlas");atlas.texture_region_size=Vector2i(32,32)
	for variant in range(8): atlas.create_tile(Vector2i(variant,0))
	tiles.add_source(atlas,0);layer.tile_set=tiles
	var cells:=HomeLayout.main_cells()
	for y in range(cells.position.y,cells.end.y):
		for x in range(cells.position.x,cells.end.x):
			var cell:=Vector2i(x,y);layer.set_cell(cell,0,floor_variant(cell))
	collision_root=Node2D.new();collision_root.name="HomeStaticGeometry";add_child(collision_root)
	art_root=Node2D.new();art_root.name="InteriorArtwork";art_root.y_sort_enabled=true;add_child(art_root)
	set_house_level(int(Housing.state.level))
	add_point("sleep","睡一觉 · 20:00后休息",HomeLayout.anchor("sleep",house_level,Housing.state.get("builtins",{})))
	add_point("exit","返回农场",HomeLayout.ANCHORS.exit)
	var letter_box:=Node2D.new();letter_box.set_script(preload("res://scripts/world/story_point.gd"));letter_box.actor_id="mail";letter_box.title="读书桌上的旧信";letter_box.position=HomeLayout.anchor("mail",house_level,Housing.state.get("builtins",{}));add_child(letter_box)
	FarmProgress.changed.connect(refresh_art)

func floor_variant(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x+floori(cell.y/2.0)*3,8),0)

func add_point(kind: String,title: String,pos: Vector2) -> void:
	var point:=Node2D.new();point.set_script(INTERACTABLE);point.kind=kind;point.label=title;point.position=pos;add_child(point)

func set_house_level(value: int) -> void:
	value=clampi(value,1,4)
	if not is_instance_valid(collision_root): return
	var builtins: Dictionary=Housing.state.get("builtins",{})
	var token: String="%d:%s" % [value,JSON.stringify(builtins)]
	if geometry_token==token:
		refresh_art();return
	house_level=value;geometry_token=token
	for old in collision_root.get_children(): collision_root.remove_child(old);old.queue_free()
	left_walls.clear()
	var builtin_by_collision: Dictionary={}
	for entry in HomeLayout.builtin_layout(value,builtins):
		if entry.solid and not entry.get("stored",false): builtin_by_collision[entry.collision]=str(entry.id)
	for rect in HomeLayout.blocked_rects(value,builtins):
		var body:=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=0
		if builtin_by_collision.has(rect):
			body.set_meta("builtin_id",builtin_by_collision[rect]);body.add_to_group("home_builtin_colliders")
		var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;body.add_child(collision);collision_root.add_child(body);left_walls.append(body)
	wall_texture=SchemeCAssets.home_texture("walls_"+str(value))
	art_token="";refresh_art();queue_redraw();Events.navigation_changed.emit()

func prop(id: String,at: Vector2,sort_y: float,layer: int=0,builtin_id: String="") -> void:
	var texture: Texture2D=load("res://assets/housing/interior/"+id+".png")
	var replacement: Texture2D=SchemeCAssets.home_texture(id)
	if replacement: texture=replacement
	var sprite:=Sprite2D.new();sprite.name=(builtin_id if builtin_id!="" else id).to_pascal_case();sprite.texture=texture;sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=Vector2(at.x+texture.get_width()/2.0,sort_y);sprite.offset=Vector2(-texture.get_width()/2.0,at.y-sort_y);sprite.z_index=layer
	sprite.set_meta("home_art_id",id);sprite.add_to_group("home_interior_art")
	if builtin_id!="": sprite.set_meta("home_builtin_id",builtin_id);sprite.set_meta("builtin_id",builtin_id);sprite.add_to_group("home_builtin_art")
	art_root.add_child(sprite)

func refreshed_art_id(id: String) -> String:
	if id=="bed" and (FarmProgress.has_upgrade("bedding") or house_level>=3): return "bed_quilt"
	if id=="sofa": return "sofa_estate" if house_level>=4 else ("sofa_cottage" if house_level>=2 else "sofa")
	if id=="kitchen" and house_level>=4: return "kitchen_estate"
	if id=="fireplace" and house_level>=3: return "fireplace_grand"
	return id

func refresh_art() -> void:
	if not is_instance_valid(art_root): return
	var builtins: Dictionary=Housing.state.get("builtins",{})
	var token: String="%d:%s:%s" % [house_level,FarmProgress.has_upgrade("bedding"),JSON.stringify(builtins)]
	if token==art_token: return
	art_token=token
	for child in art_root.get_children(): art_root.remove_child(child);child.queue_free()
	# 建筑附着的窗户和壁画保持固定；家具不再写死在场景坐标中。
	var window_id: String="window_estate" if house_level>=4 else ("window_cottage" if house_level>=2 else "window")
	prop(window_id,Vector2(632,154),224);prop(window_id,Vector2(824,154),224)
	if house_level>=4:
		prop("star_map",Vector2(442,158),224);prop("star_lantern",Vector2(728,154),224)
	if house_level>=2:
		var room:=HomeLayout.extension_cells(house_level)
		var start:=Vector2(room.position)*32
		prop("window_estate" if house_level>=4 else "window_cottage",start+Vector2(Vector2(room.size).x*16-44,-48),start.y)
	for entry in HomeLayout.builtin_layout(house_level,builtins):
		if bool(entry.get("stored",false)) or not bool(entry.get("visible",true)): continue
		prop(refreshed_art_id(str(entry.art)),entry.position,float(entry.sort_y),int(entry.layer),str(entry.id))
		if entry.action=="mail":
			for object in get_children():
				if "actor_id" in object and object.actor_id=="mail": object.position=entry.anchor
		elif entry.action=="sleep":
			for object in get_children():
				if "kind" in object and object.kind=="sleep": object.position=entry.anchor
	queue_redraw()

func _draw() -> void:
	if wall_texture: draw_texture(wall_texture,Vector2(320,144))
