extends Node2D
var housing_id: String=""
var body: StaticBody2D
var texture: Texture2D
var size := Vector2(32,32)
var label: String=""
var solid: bool=false
var geometry_key: String=""
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
	var preferred: String="res://assets/housing/interior/placeable_"+str(entry.kind)+".png"
	texture=load(preferred if entry.area=="home" and ResourceLoader.exists(preferred) else "res://assets/housing/"+entry.kind+".png")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=0 if solid else -2
	var key: String="%s:%s" % [solid,size]
	if key!=geometry_key:
		geometry_key=key
		for child in body.get_children(): child.queue_free()
		if solid:
			var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=size-Vector2(4,4)
			shape.shape=rectangle;body.add_child(shape)
	queue_redraw()
func hit_rect() -> Rect2:
	return Rect2(-size/2-Vector2(0,20),size+Vector2(0,20)) if Housing.state.flowers.has(housing_id) else Rect2(-size/2,size)
func prompt() -> String:
	if Housing.state.flowers.has(housing_id): return "春铃花 · "+("可以采收" if Housing.flower_age(housing_id)>=3 else "成长中")
	return label+" · 移动或回收"
func interact() -> void:
	if is_instance_valid(Housing.game) and Housing.game.player.action_time>0: return
	Events.interaction_requested.emit("housing:item:"+housing_id)
func _draw() -> void:
	if Housing.state.flowers.has(housing_id):
		var age: int=Housing.flower_age(housing_id)
		draw_rect(Rect2(-size/2,size),Color("8b795d"));draw_rect(Rect2(-size/2+Vector2(3,3),size-Vector2(6,6)),Color("655545"))
		if age>=3:
			draw_texture_rect(load("res://assets/festivals/spring_bloom.png"),Rect2(-16,-24,32,32),false)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-32),Vector2(4,-28),Vector2(0,-24),Vector2(-4,-28)]),Color("e5d38f"))
		elif age>0:
			draw_line(Vector2(0,7),Vector2(0,-6-age*3),Color("7d9d68"),2)
			draw_line(Vector2(0,0),Vector2(-7,-4),Color("9cb57b"),2);draw_line(Vector2(0,-2),Vector2(7,-7),Color("9cb57b"),2)
			if age==2: draw_rect(Rect2(-3,-15,6,5),Color("b9d8c5"))
		else: draw_rect(Rect2(-3,0,6,3),Color("bea47a"))
	elif texture: draw_texture_rect(texture,Rect2(-size/2,size),false)
