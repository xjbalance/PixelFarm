extends Node2D
## 水面上的栏体可点击，执行目标始终是岸边。水格保留原碰撞。
const SPECIES := ["crucian","carp","grass","perch","golden","star"]
const FISH := preload("res://assets/aquaculture/fish_swim.png")
const WOOD := Color("b79461")
const DARK := Color("5c5e48")
var pen_id: String = "pen_1"
var water_direction := Vector2.RIGHT
var box_collision: CollisionShape2D
var last_built: bool = false
var animation_time: float = 0
var animation_frame: int = 0
var label: Label
var last_summary: Dictionary = {}

func _ready() -> void:
	add_to_group("interactables")
	# 工具箱离锚点80px，位于54px交互圈和玩家脚底范围之外，建造不会包住玩家。
	# 水格始终保留原碰撞。
	var body := StaticBody2D.new()
	body.position=tangent()*80
	body.collision_layer=1
	body.collision_mask=0
	box_collision=CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(16,16)
	box_collision.shape=shape
	box_collision.disabled=true
	body.add_child(box_collision)
	add_child(body)
	label=FarmUIStyle.label("",12,FarmUIStyle.CREAM)
	label.position=Vector2(-72,-28) if water_direction.y>=0 else Vector2(-72,16)
	label.size=Vector2(144,20)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color",Color("294c50"))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	add_child(label)
	Aquaculture.changed.connect(refresh)
	GameClock.changed.connect(refresh_time)
	refresh()

func tangent() -> Vector2:
	return Vector2(-water_direction.y,water_direction.x)

func hit_rect() -> Rect2:
	# 整个栏体、成熟鱼和岸上操作台都能点；自动移动不拿点击水点当目标。
	return Rect2(Vector2(-20,-22),Vector2(40,44)).merge(Rect2(water_direction*48-Vector2(29,24),Vector2(58,48)))

func prompt() -> String:
	var p: Dictionary=Aquaculture.pen(pen_id)
	if not p.built:
		return "建造湖边鱼栏" if Aquaculture.available(pen_id) else "查看鱼栏扩建条件"
	var s: Dictionary=Aquaculture.summary(pen_id)
	return "照料鱼栏 · 可收获%d尾" % int(p.adults) if int(p.adults)>0 else "照料鱼栏 · %d/%d尾" % [int(s.total),int(s.capacity)]

func interact() -> void:
	Events.interaction_requested.emit("fish:"+pen_id)

func refresh_time() -> void:
	# 夜间仅用颜色变化，不增加动态光源。
	if int(GameClock.minutes)%30==0: queue_redraw()

func refresh() -> void:
	var p: Dictionary=Aquaculture.pen(pen_id)
	last_summary=Aquaculture.summary(pen_id)
	var built: bool=bool(p.built)
	if built!=last_built:
		last_built=built
		box_collision.set_deferred("disabled",not built)
		Events.navigation_changed.emit()
	if not built:
		label.text="鱼栏 %s · 待建" % pen_id.trim_prefix("pen_") if Aquaculture.available(pen_id) else "鱼栏 %s · 待扩建" % pen_id.trim_prefix("pen_")
	elif int(p.adults)>0: label.text="可收获 %d尾" % int(p.adults)
	elif str(p.species)!="": label.text="鱼苗 %d尾 · %.1f天" % [int(last_summary.fry),float(last_summary.growth)]
	else: label.text="%s级鱼栏 · 等待投苗" % int(p.level)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or GameState.modal or not GameClock.running: return
	if not last_built or int(last_summary.get("total",0))==0: return
	animation_time+=delta
	var frame: int=int(animation_time*2)%2
	if frame!=animation_frame:
		animation_frame=frame
		queue_redraw()

func _draw() -> void:
	var p: Dictionary=Aquaculture.pen(pen_id)
	var water: Vector2=water_direction*48
	var side: Vector2=tangent()
	if not p.built:
		# 岸上勘测木桩，虚线绳只标可建鱼栏，不产生湖面通路。
		draw_rect(Rect2(-5,-13,10,14),DARK)
		draw_rect(Rect2(-12,-24,24,14),Color("c0a579") if Aquaculture.available(pen_id) else Color("7f8876"))
		draw_line(Vector2(-7,-18),Vector2(7,-18),DARK,2)
		for x in [-1,1]:
			for y in [-1,1]: draw_rect(Rect2(water+Vector2(x*26,y*20)-Vector2(2,2),Vector2(4,4)),Color("b5ba8d"))
		return
	# 木台只在合法湖岸。栏网在水中，两根系绳连接。
	for y in range(-10,11,5): draw_rect(Rect2(-14,y,28,4),WOOD)
	draw_rect(Rect2(-16,-12,32,24),DARK,false,2)
	for sign_value in [-1,1]: draw_line(side*sign_value*10+water_direction*12,water+side*sign_value*24-water_direction*18,Color("dac69a"),1)
	var clean: bool=int(p.water)>=55
	var water_color := Color("427e84") if clean else Color("5d806c")
	if GameClock.minutes>=1200: water_color=water_color.darkened(.15)
	draw_rect(Rect2(water-Vector2(27,21),Vector2(54,42)),Color(water_color,.65))
	for x in range(-24,26,8): draw_line(water+Vector2(x,-20),water+Vector2(x,20),Color("94b4a0",.35),1)
	for y in range(-16,18,8): draw_line(water+Vector2(-26,y),water+Vector2(26,y),Color("94b4a0",.35),1)
	var level: int=int(p.level)
	var rail: Color=WOOD if level==1 else (Color("b1bcb4") if level==2 else Color("83baa2"))
	draw_rect(Rect2(water-Vector2(28,22),Vector2(56,44)),DARK,false,4)
	draw_rect(Rect2(water-Vector2(28,22),Vector2(56,44)),rail,false,2)
	for x in [-1,1]:
		for y in [-1,1]:
			draw_rect(Rect2(water+Vector2(x*27,y*21)-Vector2(3,7),Vector2(6,10)),DARK)
			draw_rect(Rect2(water+Vector2(x*27,y*21)-Vector2(2,7),Vector2(4,3)),rail)
	var box: Vector2=side*80
	draw_rect(Rect2(box-Vector2(10,14),Vector2(20,22)),DARK)
	draw_rect(Rect2(box-Vector2(8,12),Vector2(16,17)),WOOD)
	draw_rect(Rect2(box-Vector2(8,12),Vector2(16,4)),Color("dcc592"))
	draw_rect(Rect2(box+Vector2(-2,-4),Vector2(4,5)),Color("607f7a"))
	if level==3:
		draw_circle(water+Vector2(20,-14),7,Color("a5d5be",.35))
		draw_line(water+Vector2(17,-14),water+Vector2(23,-14),Color("d5e8ba"),2)
	if int(p.feed_stock)>0: draw_rect(Rect2(box+Vector2(-5,-7),Vector2(10,3)),Color("e9d190"))
	var species: String=str(p.species)
	var index: int=SPECIES.find(species)
	if index>=0 and int(last_summary.get("total",0))>0:
		var adults: int=int(p.adults)
		var count: int=mini(3,int(last_summary.total))
		for i in range(count):
			var size: Vector2=Vector2(24,24) if adults>i else Vector2(15,15)
			var offset := Vector2(-12+i*12,-5+(i%2)*12)
			var frame: int=(animation_frame+i)%2
			draw_texture_rect_region(FISH,Rect2(water+offset-size/2,size),Rect2(index*64+frame*32,0,32,32))
		if adults>0:
			var mark: Vector2=water+Vector2(0,-35)
			draw_colored_polygon(PackedVector2Array([mark+Vector2(0,-5),mark+Vector2(5,0),mark+Vector2(0,5),mark+Vector2(-5,0)]),Color("f3d68f"))
	if int(p.water)<55 or int(p.health)<60:
		draw_rect(Rect2(box+Vector2(-2,-24),Vector2(4,8)),Color("efbd80"))
		draw_rect(Rect2(box+Vector2(-2,-14),Vector2(4,3)),Color("efbd80"))
