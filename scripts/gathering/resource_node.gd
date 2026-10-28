extends StaticBody2D
## 采集物负责碰撞与反馈，数量和再生状态由 ResourceField 统一管理。
var resource_id: String
var kind: String
var field: Node2D
var sprite: Sprite2D
var collider: CollisionShape2D
var highlighted: bool = false
var shake: Tween
var art_id: String=""

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art_id=["oak_tree","birch_tree","pine_tree"][absi(resource_id.hash())%3] if kind=="tree" else "shore_rocks"
	add_child(sprite)
	collider = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22,19) if kind == "tree" else Vector2(30,16)
	collider.shape = shape
	collider.position.y = -5
	add_child(collider)
	Calendar.changed.connect(refresh_art)
	Territory.changed.connect(queue_redraw)
	refresh_art()
	refresh()

func refresh_art() -> void:
	if not is_instance_valid(sprite): return
	sprite.texture=SchemeCAssets.texture(art_id,Calendar.season())
	sprite.position=SchemeCAssets.offset(art_id)
	sprite.set_meta("scheme_c_id",art_id)

func refresh() -> void:
	var stored: bool=is_stored()
	var active: bool = field.state[resource_id].hp > 0 and not stored
	visible=not stored;collision_layer=0 if stored else 1
	sprite.visible = active
	collider.set_deferred("disabled",not active)
	Events.navigation_changed.emit()
	queue_redraw()

func is_stored() -> bool:
	return field.area_id=="farm" and FarmLayout.stored("resource",resource_id)

func hit_feedback() -> void:
	if shake and shake.is_valid(): shake.kill()
	shake = create_tween()
	shake.tween_property(sprite,"position:x",3.0,0.04)
	shake.tween_property(sprite,"position:x",-3.0,0.05)
	shake.tween_property(sprite,"position:x",0.0,0.05)
	refresh()

func can_regrow() -> bool:
	if is_stored(): return false
	if field.area_id=="farm":
		var rect: Rect2i=FarmResourceCatalog.current_footprint(resource_id)
		var game: Node=FarmLayout.get("game") as Node
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var at:=Vector2i(x,y)
				if Territory.state.get("terrain",{}).get("farm",{}).has(TerritoryCatalog.key(at)): return false
				if FarmTerrain.effective_index(at) in [5,6] or not Territory.object_at("farm",at).is_empty(): return false
				if is_instance_valid(game) and not game.farm.plot_at(at).is_empty(): return false
		# A moved or stored fixture can differ from the original map. Check its actual
		# shape properties even while this map is inactive in the shared World2D.
		if _farm_shape_blocked(): return false
	elif Territory.resource_edited(resource_id,field.area_id): return false
	# 三张地图共用World2D；离图时别图同坐标玩家不能拖延这片林地恢复。
	if field.area_id!=GameState.location: return true
	# 再生时检查玩家脚下，避免在角色位置生成新的障碍物。
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26
	query.shape = shape
	query.transform = Transform2D(0,global_position)
	query.collision_mask = 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query,64):
		if field.get_parent().is_ancestor_of(hit.collider): return false
	return true

func _farm_shape_blocked() -> bool:
	var map: Node=field.get_parent().get_parent()
	if not is_instance_valid(map): return true
	var extent:=Vector2(22,19) if kind=="tree" else Vector2(30,16)
	var footprint:=Rect2(global_position+Vector2(0,-5)-extent*.5,extent)
	for shape_node in map.find_children("*","CollisionShape2D",true,false):
		if shape_node==collider or not shape_node.shape or shape_node.disabled: continue
		var owner: Node=shape_node.get_parent()
		if not owner is CollisionObject2D or owner.collision_layer & 1 == 0: continue
		var local_rect: Rect2=shape_node.shape.get_rect()
		var corners: Array[Vector2]=[local_rect.position,Vector2(local_rect.end.x,local_rect.position.y),local_rect.end,Vector2(local_rect.position.x,local_rect.end.y)]
		var bounds:=Rect2(shape_node.global_transform*corners[0],Vector2.ZERO)
		for point in corners: bounds=bounds.expand(shape_node.global_transform*point)
		if footprint.intersects(bounds): return true
	return false

func set_highlight(active: bool) -> void:
	if highlighted != active:
		highlighted = active
		queue_redraw()

func _draw() -> void:
	if is_stored(): return
	var data: Dictionary = field.state[resource_id]
	var covered: bool=false
	if field.area_id=="farm":
		var game: Node=FarmLayout.get("game") as Node
		var rect: Rect2i=FarmResourceCatalog.current_footprint(resource_id)
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var at:=Vector2i(x,y)
				if Territory.state.get("terrain",{}).get("farm",{}).has(TerritoryCatalog.key(at)) or FarmTerrain.effective_index(at) in [5,6] or not Territory.object_at("farm",at).is_empty() or (is_instance_valid(game) and not game.farm.plot_at(at).is_empty()): covered=true
		if data.hp==0 and not covered: covered=_farm_shape_blocked()
	if data.hp == 0 and not covered:
		if kind == "tree":
			SchemeCAssets.draw(self,"tree_stump",Vector2.ZERO,Calendar.season())
		else:
			draw_rect(Rect2(-8,-2,6,4),Color("768a7a"))
			draw_rect(Rect2(4,-5,5,5),Color("9ba58c"))
	if highlighted:
		draw_rect(Rect2(-20,-19,40,30),Color("efdaa0"),false,2)
		if data.hp > 0:
			var maximum: int = FarmResourceCatalog.TYPES[kind].hits
			draw_rect(Rect2(-18,-29,36,5),Color("354d3d"))
			draw_rect(Rect2(-18,-29,36.0*data.hp/maximum,5),Color("e6c786"))
