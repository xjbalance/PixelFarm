extends Node2D
## 建物碰撞始终在54px交互圈以外，确认建造时不会包住玩家。
var livestock_id: String = "coop"
var shape: CollisionShape2D
var previous_level: int = 0
var label: Label
var shelter_floor: Node2D

func _ready() -> void:
	add_to_group("interactables")
	shelter_floor=Node2D.new();shelter_floor.set_script(preload("res://scripts/livestock/shelter_floor.gd"));shelter_floor.site=livestock_id;shelter_floor.z_index=-2;add_child(shelter_floor)
	var body := StaticBody2D.new()
	body.position=Vector2(0,-92)
	body.collision_layer=1;body.collision_mask=0
	shape=CollisionShape2D.new()
	var rectangle := RectangleShape2D.new();rectangle.size=Vector2(112,48)
	shape.shape=rectangle;shape.disabled=true
	body.add_child(shape);add_child(body)
	label=FarmUIStyle.label("",12,FarmUIStyle.CREAM)
	label.position=Vector2(-76,-50);label.size=Vector2(152,20)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color",Color("263d32"));label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1);add_child(label)
	Livestock.changed.connect(refresh);refresh()

func hit_rect() -> Rect2:
	return Rect2(-64,-136,128,164)

func prompt() -> String:
	return ("管理" if Livestock.building(livestock_id).level>0 else "建造")+str(Livestock.data.buildings[livestock_id].name)

func interact() -> void:
	if is_instance_valid(Livestock.game) and "action_time" in Livestock.game.player and Livestock.game.player.action_time>0: return
	Events.interaction_requested.emit("livestock:"+livestock_id)

func refresh() -> void:
	var level: int=Livestock.building(livestock_id).level
	if level!=previous_level:
		previous_level=level
		shape.set_deferred("disabled",level==0)
		Events.navigation_changed.emit()
	var name_text: String=Livestock.data.buildings[livestock_id].name
	label.text=name_text+" · 待建" if level==0 else "%s Lv%d · %d/%d" % [name_text,level,Livestock.summary(livestock_id).count,Livestock.summary(livestock_id).capacity]
	if shelter_floor: shelter_floor.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var level: int=Livestock.building(livestock_id).level
	if level==0:
		draw_rect(Rect2(-4,-14,8,20),Color("635d45"))
		draw_rect(Rect2(-24,-30,48,18),Color("c2a276"))
		draw_line(Vector2(-15,-23),Vector2(15,-23),Color("756448"),2)
		return
	var wall := Color("bb9c70") if livestock_id=="coop" else (Color("a6aa8b") if livestock_id=="barn" else Color("b4aa8d"))
	var roof := Color("91654f") if livestock_id=="coop" else (Color("59746a") if livestock_id=="barn" else Color("857b60"))
	draw_rect(Rect2(-58,-110,116,48),Color("514d3d"))
	draw_rect(Rect2(-54,-106,108,40),wall)
	for x in range(-48,51,12): draw_line(Vector2(x,-104),Vector2(x,-67),wall.darkened(.15),1)
	draw_colored_polygon(PackedVector2Array([Vector2(-66,-108),Vector2(-48,-132),Vector2(48,-132),Vector2(66,-108)]),roof)
	for x in range(-45,46,15): draw_line(Vector2(x,-128),Vector2(x+8,-111),roof.lightened(.18),2)
	draw_rect(Rect2(-17,-96,34,31),Color("5b5946"))
	draw_rect(Rect2(-12,-93,24,28),Color("a18a64"))
	draw_rect(Rect2(-7,-80,14,15),Color("d6c593"))
	for x in [-38,38]:
		draw_rect(Rect2(x-9,-98,18,17),Color("5b6b60"))
		draw_rect(Rect2(x-6,-95,12,11),Color("adc5b1"))
		draw_line(Vector2(x,-95),Vector2(x,-84),Color("718370"),2)
	# 仅装饰的前庭围栏，不新增横跨通道的硬碰撞。
	for x in [-64,64]:
		# 两侧牧门留出真实进出缺口，动物不穿过绘制的围栏。
		draw_line(Vector2(x,42),Vector2(x,88),Color("977e58"),3)
		for y in [52,84]: draw_rect(Rect2(x-3,y-12,6,21),Color("b9a174"))
	for x in range(-64,65,32):
		if x in [-32,0,32]: continue
		draw_line(Vector2(x,88),Vector2(x+24,88),Color("b7a277"),2)
	# 掀开的屋面以剖视显示暖舍，动物在草垫与屋檐内可见；放牧走两侧草地。
	draw_rect(Rect2(-60,-53,120,6),roof)
	for x in [-60,56]:
		draw_rect(Rect2(x,-51,4,14),wall)
		draw_rect(Rect2(x,28,4,8),wall)
	if level>=2:
		for x in [-54,54]: draw_rect(Rect2(x-3,-109,6,43),Color("717b70"))
	if level==3:
		draw_rect(Rect2(24,-127,18,8),Color("90ada0"))
		draw_rect(Rect2(30,-130,6,4),Color("c7d6b1"))
