extends Node2D
var housing_id: String=""
var body: StaticBody2D
var texture: Texture2D
var size := Vector2(32,32)
var label: String=""
var solid: bool=false
func _ready() -> void:
	add_to_group("interactables");add_to_group("housing_furniture")
	body=StaticBody2D.new();body.collision_layer=1;body.collision_mask=0
	add_child(body);refresh()
func refresh() -> void:
	var entry := Housing.placement(housing_id)
	if entry.is_empty(): return
	var definition: Dictionary=Housing.data.furniture[entry.kind]
	size=Vector2(definition.size[0],definition.size[1])*32
	position=Housing.center(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
	label=definition.name;solid=definition.solid
	texture=load("res://assets/housing/"+entry.kind+".png")
	z_index=0 if solid else -2
	for child in body.get_children(): child.queue_free()
	if solid:
		var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=size-Vector2(4,4)
		shape.shape=rectangle;body.add_child(shape)
	queue_redraw()
func hit_rect() -> Rect2: return Rect2(-size/2,size)
func prompt() -> String: return label+" · 移动或回收"
func interact() -> void:
	if is_instance_valid(Housing.game) and Housing.game.player.action_time>0: return
	Events.interaction_requested.emit("housing:item:"+housing_id)
func _draw() -> void:
	if texture: draw_texture_rect(texture,Rect2(-size/2,size),false)
