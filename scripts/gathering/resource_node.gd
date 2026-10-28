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
	var active: bool = field.state[resource_id].hp > 0
	sprite.visible = active
	collider.set_deferred("disabled",not active)
	Events.navigation_changed.emit()
	queue_redraw()

func hit_feedback() -> void:
	if shake and shake.is_valid(): shake.kill()
	shake = create_tween()
	shake.tween_property(sprite,"position:x",3.0,0.04)
	shake.tween_property(sprite,"position:x",-3.0,0.05)
	shake.tween_property(sprite,"position:x",0.0,0.05)
	refresh()

func can_regrow() -> bool:
	# Check before the off-map fast path: changing scenes must not undo landscaping.
	if Territory.resource_edited(resource_id,field.area_id): return false
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

func set_highlight(active: bool) -> void:
	if highlighted != active:
		highlighted = active
		queue_redraw()

func _draw() -> void:
	var data: Dictionary = field.state[resource_id]
	if data.hp == 0 and not Territory.resource_edited(resource_id,field.area_id):
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
