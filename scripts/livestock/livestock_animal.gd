extends CharacterBody2D
## 动物只在已验证的自家前庭小范围走动；不占玩家碰撞层，也不穿过静态地形。
var animal_id: String = ""
var livestock_id: String = ""
var age_texture: Texture2D
var species_id: String = ""
var animation: float = 0
var wander: float = 0
var station := Vector2.ZERO
var label: Label

func _ready() -> void:
	livestock_id="animal:"+animal_id
	add_to_group("interactables");add_to_group("livestock_animals")
	collision_layer=0;collision_mask=1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new();rectangle.size=Vector2(12,8)
	collision.shape=rectangle;collision.position=Vector2(0,-3);add_child(collision)
	label=FarmUIStyle.label("",11,FarmUIStyle.GOLD)
	label.position=Vector2(-30,-38);label.size=Vector2(60,16)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	GameWeather.changed.connect(refresh);GameClock.changed.connect(refresh)
	refresh()

func hit_rect() -> Rect2:
	return Rect2(-19,-30,38,42)

func prompt() -> String:
	var entry := Livestock.animal(animal_id)
	if entry.is_empty(): return ""
	var definition: Dictionary=Livestock.data.species[entry.species]
	return "照料"+Livestock.display_name(animal_id)+(" · 可收%s%d" % [Catalog.item_name(definition.product),entry.product] if entry.product>0 else "")

func interact() -> void:
	if is_instance_valid(Livestock.game) and "action_time" in Livestock.game.player and Livestock.game.player.action_time>0: return
	Events.interaction_requested.emit("livestock:animal:"+animal_id)

func refresh() -> void:
	var entry := Livestock.animal(animal_id)
	if entry.is_empty(): return
	if species_id!=entry.species:
		species_id=entry.species
		age_texture=load("res://assets/livestock/"+species_id+".png")
	var siblings: Array=Livestock.animals_at(entry.site)
	var index := 0
	for i in range(siblings.size()):
		if siblings[i].id==animal_id: index=i;break
	var offsets: Array=Livestock.PASTURE if Livestock.is_grazing(entry.site) else Livestock.INDOOR
	station=Livestock.site_point(entry.site)+offsets[index]
	label.text="产物%d" % int(entry.product) if entry.product>0 else ("饿了" if entry.hunger>=70 else "")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree() or GameState.modal or not GameClock.running: velocity=Vector2.ZERO;return
	var entry := Livestock.animal(animal_id)
	if entry.is_empty(): return
	wander+=delta
	var serial: int=int(animal_id.trim_prefix("animal_"))
	var target: Vector2=station+Vector2(sin(wander*.35+serial)*5,cos(wander*.28+serial)*4)
	var motion: Vector2=target-global_position
	velocity=motion.normalized()*minf(18,motion.length()/maxf(delta,.001)) if motion.length()>1 else Vector2.ZERO
	move_and_slide()
	var bounds := Rect2(Livestock.site_point(entry.site)+Vector2(-112,-46),Vector2(224,150))
	global_position=global_position.clamp(bounds.position,bounds.end-Vector2.ONE)
	# 更新既有两数数组，避免18只动物每物理帧分配新的保存数组。
	var logical:=FarmLayout.to_logical(str(entry.site),global_position)
	entry.position[0]=snappedf(logical.x,.01)
	entry.position[1]=snappedf(logical.y,.01)
	if velocity.length()>1:
		var old_frame: int=int(animation*4)%2
		animation+=delta
		# 节点位移由渲染器同步；只有实际像素帧变化才重建绘制指令。
		if int(animation*4)%2!=old_frame: queue_redraw()

func _draw() -> void:
	var entry := Livestock.animal(animal_id)
	if entry.is_empty() or age_texture==null: return
	var size := Vector2(32,32) if Livestock.is_adult(entry) else Vector2(23,23)
	var frame: int=int(animation*4)%2
	var destination := Rect2(Vector2(-size.x/2,-size.y+4),size)
	draw_ellipse_shadow(size.x*.65)
	draw_texture_rect_region(age_texture,destination,Rect2(frame*32,0,32,32),Color.WHITE if entry.mood>=35 else Color("c5c8b8"))
	if entry.pet_day==GameClock.day: draw_rect(Rect2(11,-27,3,3),Color("e5b2a0"))

func draw_ellipse_shadow(width: float) -> void:
	draw_rect(Rect2(-width/2,-1,width,3),Color(.18,.28,.19,.20))
