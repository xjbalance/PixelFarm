class_name TerritoryObject
extends Node2D
## 新建的小型物件没有采集产出。箱子只访问原住宅共用收纳，不创建第二份库存。
var game: Node
var entry_id: String=""
var entry: Dictionary={}
var body: StaticBody2D
var sprite: Sprite2D
var animated: AnimatedSprite2D
var definition: Dictionary={}
var footprint_size:=Vector2(32,32)
var geometry_key: String=""
static var orchard_hit_bounds: Dictionary={}

func _ready() -> void:
	add_to_group("interactables");add_to_group("territory_objects")
	body=StaticBody2D.new();body.collision_layer=0;body.collision_mask=0;add_child(body)
	sprite=Sprite2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite)
	animated=AnimatedSprite2D.new();animated.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(animated);animated.hide()
	Calendar.changed.connect(refresh_art)
	Workshop.changed.connect(refresh_art)
	refresh()

func refresh() -> void:
	entry={}
	for record in Territory.state.get("objects",[]):
		if str(record.id)==entry_id: entry=record;break
	if entry.is_empty(): return
	definition=TerritoryCatalog.OBJECT_KINDS[str(entry.kind)]
	var cells: Rect2i=TerritoryCatalog.footprint(str(entry.kind),Vector2i(entry.cell[0],entry.cell[1]))
	footprint_size=Vector2(cells.size)*32
	position=Vector2(cells.position)*32+footprint_size*.5
	var key: String=str(entry.kind)+":"+str(footprint_size)
	if key!=geometry_key:
		geometry_key=key
		for child in body.get_children(): body.remove_child(child);child.queue_free()
		body.collision_layer=1 if bool(definition.solid) else 0
		if bool(definition.solid):
			var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=footprint_size-Vector2(4,4);shape.shape=rectangle;body.add_child(shape)
		if bool(definition.get("storage",false)): add_to_group("territory_storage")
		elif is_in_group("territory_storage"): remove_from_group("territory_storage")
	z_index=0 if bool(definition.solid) else -2
	refresh_art()

func refresh_art() -> void:
	if entry.is_empty() or not is_instance_valid(sprite): return
	var art: String=str(definition.get("art",""))
	var texture: Texture2D=Workshop.tree_texture(entry) if str(entry.kind).begins_with("orchard_") else SchemeCAssets.placed_texture(art,footprint_size,Calendar.season())
	if texture==null: texture=TerritoryWorld.texture_for(str(entry.kind))
	sprite.texture=texture;sprite.visible=texture!=null
	animated.hide()
	if texture:
		sprite.scale=Vector2.ONE
		sprite.position=Vector2(0,-32) if str(entry.kind).begins_with("orchard_") else Vector2(0,-9) if str(entry.kind).begins_with("station_") else art_position(art,footprint_size)
		var frames:=SchemeCAssets.animation(art)
		if frames:
			if animated.sprite_frames!=frames: animated.sprite_frames=frames;animated.play("loop")
			animated.position=sprite.position;animated.show();sprite.hide()
	queue_redraw()

static func art_position(art: String, extent: Vector2) -> Vector2:
	if SchemeCAssets.has_repeat(art): return Vector2.ZERO
	var base:=Vector2(0,extent.y*.5-3)
	if art.ends_with("_tree") or art=="dead_tree": base=Vector2(0,12)
	return SchemeCAssets.offset(art)+base

func prompt() -> String:
	if entry.is_empty(): return "领地物件"
	if str(entry.kind).begins_with("orchard_"): return str(definition.name)+(" · 可采果" if int(Workshop.state.orchard.get(entry_id,{}).get("fruit",0))>0 else " · 果园")
	if str(entry.kind).begins_with("station_"): return str(definition.name)+(" · 成品待领取" if Workshop.state.jobs.get(entry_id,{}).get("ready",false) else " · 加工")
	return str(definition.name)+(" · 共用住宅收纳" if bool(definition.get("storage",false)) else " · 建造模式可移动或拆除")

func hit_rect() -> Rect2:
	if is_instance_valid(sprite) and sprite.texture:
		var rect:=sprite.get_rect()
		if str(entry.get("kind","")).begins_with("orchard_"):
			# Young trees share the adult 96px canvas; transparent padding must not steal nearby plot taps.
			var path: String=sprite.texture.resource_path
			if not orchard_hit_bounds.has(path):
				var picture:=sprite.texture.get_image()
				if picture.is_compressed(): picture.decompress()
				orchard_hit_bounds[path]=Rect2(picture.get_used_rect()).grow(3)
			var used: Rect2=orchard_hit_bounds[path]
			rect=Rect2(rect.position+used.position,used.size)
		return Rect2(rect.position*sprite.scale+sprite.position,rect.size*sprite.scale)
	return Rect2(-footprint_size*.5,footprint_size)

func storage_accessible() -> bool:
	if entry.is_empty() or not bool(definition.get("storage",false)) or not is_instance_valid(game) or not is_visible_in_tree() or GameState.location!=str(entry.area): return false
	return not game.backgrounded and not game.closing and not GameState.restoring and game.player.global_position.distance_to(global_position)<=54 and game.auto_move.navigation.line_of_sight(game.player.global_position,global_position,self)

func interact() -> void:
	if entry.is_empty() or not is_instance_valid(game) or GameState.modal or game.player.global_position.distance_to(global_position)>54: return
	if str(entry.kind).begins_with("station_") or str(entry.kind).begins_with("orchard_"):
		Events.interaction_requested.emit("workshop:"+entry_id);return
	if bool(definition.get("storage",false)): Events.interaction_requested.emit("housing:territory_storage")
	else: Events.notice.emit(str(definition.name)+"是领地摆设，可在菜单的建造模式中移动或拆除。")

func _draw() -> void:
	if entry.is_empty(): return
	var kind: String=str(entry.kind)
	if bool(definition.solid): draw_ellipse(Vector2(0,10),Vector2(15,4),Color(0.18,.23,.16,.18))
	if Workshop.state.jobs.get(entry_id,{}).get("ready",false):
		draw_colored_polygon(PackedVector2Array([Vector2(0,-42),Vector2(4,-38),Vector2(0,-34),Vector2(-4,-38)]),Color("edd581"))
	if is_instance_valid(sprite) and sprite.texture: return
	var season: int=Calendar.season()
	var leaf: Color=[Color("769b62"),Color("60874e"),Color("ae8c55"),Color("c8d4c2")][season]
	match kind:
		"bush":
			draw_rect(Rect2(-13,-9,26,21),leaf.darkened(.24));draw_rect(Rect2(-16,-5,32,12),leaf)
			draw_rect(Rect2(-9,-12,17,9),leaf.lightened(.14))
		"tall_grass":
			for x in [-9,-4,2,8]: draw_line(Vector2(x,11),Vector2(x+(-3 if x%2 else 2),-7-absi(x)%5),leaf.darkened(.1),2)
		"flowers":
			for at in [Vector2(-8,6),Vector2(6,9),Vector2(1,-2)]:
				draw_line(at,at-Vector2(0,8),leaf.darkened(.2),2)
				draw_rect(Rect2(at-Vector2(3,11),Vector2(7,5)),Color("e0b0a1") if season!=3 else Color("b7b0c8"));draw_rect(Rect2(at-Vector2(1,10),Vector2(2,2)),Color("efd39a"))
		"rock_decor":
			draw_colored_polygon(PackedVector2Array([Vector2(-14,9),Vector2(-11,-5),Vector2(-3,-11),Vector2(10,-7),Vector2(15,7),Vector2(8,12)]),Color("929c8e"))
			draw_line(Vector2(-8,-4),Vector2(5,-7),Color("c5ccba"),3)
		"bench":
			draw_rect(Rect2(-footprint_size.x*.5+3,-8,footprint_size.x-6,15),Color("bc9464"));draw_line(Vector2(-footprint_size.x*.5+3,-3),Vector2(footprint_size.x*.5-3,-3),Color("866242"),2)
			for x in [-footprint_size.x*.5+8,footprint_size.x*.5-8]: draw_rect(Rect2(x,7,4,7),Color("785b42"))
		"chest":
			draw_rect(Rect2(-14,-9,28,23),Color("76553d"));draw_rect(Rect2(-12,-7,24,19),Color("b18a5c"))
			draw_rect(Rect2(-13,-11,26,10),Color("ccaa73"));draw_line(Vector2(-12,-1),Vector2(12,-1),Color("795a3f"),2)
			draw_rect(Rect2(-2,-3,5,7),Color("e7c47e"));draw_rect(Rect2(-13,11,26,3),Color("856543"))
		_:
			draw_rect(Rect2(-footprint_size*.5+Vector2(3,3),footprint_size-Vector2(6,6)),Color("ba9a6c"))

func draw_ellipse(origin: Vector2, extent: Vector2, color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(16): points.append(origin+Vector2(cos(i*TAU/16),sin(i*TAU/16))*extent)
	draw_colored_polygon(points,color)
