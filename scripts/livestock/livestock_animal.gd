extends CharacterBody2D
## One persistent identity, real movement and four-way native pixel animation.
enum Behavior { IDLE, WANDER, GRAZE, REST, INTERACT, RETURN_HOME }
var animal_id: String=""
var livestock_id: String=""
var species_id: String=""
var age_texture: Texture2D
var label: Label
var station:=Vector2.ZERO
var behavior: Behavior=Behavior.IDLE
var direction: int=0
var animation: float=0
var frame: int=0
var timer: float=0
var held: float=0
var stalled: float=0
var total_distance: float=0
var goals_chosen: int=0
var target:=Vector2.ZERO
var rng:=RandomNumberGenerator.new()
var previous_grazing: bool=false
var large: bool=false
var collider: CollisionShape2D
var route:=PackedVector2Array()
var route_index: int=0
var speed: float=22
var painted: int=-1

func _ready() -> void:
	livestock_id="animal:"+animal_id
	add_to_group("interactables");add_to_group("livestock_animals")
	collision_layer=0;collision_mask=1;motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	rng.seed=absi(animal_id.hash());timer=rng.randf_range(.2,1.7)
	collider=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,8);collider.shape=shape;collider.position.y=-3;add_child(collider)
	label=FarmUIStyle.label("",11,FarmUIStyle.GOLD);label.position=Vector2(-32,-46);label.size=Vector2(64,16)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
	GameWeather.changed.connect(refresh);GameClock.changed.connect(refresh)
	refresh();previous_grazing=Livestock.is_grazing(str(Livestock.animal(animal_id).get("site","")))

func hit_rect() -> Rect2:
	return Rect2(-26,-40,52,50) if large else Rect2(-20,-30,40,42)

func prompt() -> String:
	var entry:=Livestock.animal(animal_id)
	if entry.is_empty(): return ""
	var definition: Dictionary=Livestock.data.species[entry.species]
	return "照料"+Livestock.display_name(animal_id)+(" · 可收%s%d" % [Catalog.item_name(definition.product),entry.product] if entry.product>0 else "")

func interact() -> void:
	if is_instance_valid(Livestock.game) and Livestock.game.player.action_time>0: return
	Events.interaction_requested.emit("livestock:animal:"+animal_id)

func hold_for_interaction() -> void:
	held=30;behavior=Behavior.INTERACT;velocity=Vector2.ZERO;queue_redraw()
func release_interaction() -> void:
	held=0;timer=.8;behavior=Behavior.IDLE

func refresh() -> void:
	var entry:=Livestock.animal(animal_id)
	if entry.is_empty(): return
	if species_id!=str(entry.species):
		species_id=entry.species;large=species_id in ["cow","sheep"]
		age_texture=load("res://assets/livestock/ranch082/"+species_id+".png")
		collider.shape.size=Vector2(22,12) if large else Vector2(12,8)
		speed={"chicken":32.0,"duck":25.0,"cow":18.0,"sheep":23.0}[species_id]
	station=Livestock.home_station(entry)
	label.text=("待收蛋%d" if species_id in ["chicken","duck"] else "产物%d") % int(entry.product) if entry.product>0 else ("饿了" if entry.hunger>=70 else "")
	queue_redraw()

func set_goal(point: Vector2, returning: bool=false) -> bool:
	var entry:=Livestock.animal(animal_id)
	route=Livestock.animal_route(entry,global_position,point)
	if route.is_empty(): return false
	route_index=0;target=point;timer=0;stalled=0;goals_chosen+=1
	behavior=Behavior.RETURN_HOME if returning else Behavior.WANDER
	return true

func choose_activity(entry: Dictionary) -> void:
	var outdoors: bool=Livestock.is_grazing(str(entry.site))
	var choice: float=rng.randf()
	if not outdoors and global_position.distance_to(station)>7:
		if set_goal(station,true): return
	if choice<.58:
		var bounds: Rect2=Livestock.activity_bounds(entry,outdoors)
		for attempt in range(10):
			var candidate:=Vector2(rng.randf_range(bounds.position.x+12,bounds.end.x-12),rng.randf_range(bounds.position.y+10,bounds.end.y-10))
			if candidate.distance_to(global_position)<(40 if outdoors else 12): continue
			if set_goal(candidate): return
	behavior=Behavior.GRAZE if choice<.83 else Behavior.REST
	timer=rng.randf_range(1.2,3.2) if not large else rng.randf_range(2.6,5.5)

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree() or GameState.modal or not GameClock.running or GameState.restoring:
		velocity=Vector2.ZERO;return
	var entry:=Livestock.animal(animal_id)
	if entry.is_empty(): return
	if is_instance_valid(Livestock.game) and (Livestock.game.backgrounded or Livestock.game.closing): velocity=Vector2.ZERO;return
	timer-=delta;held=maxf(0,held-delta)
	var grazing: bool=Livestock.is_grazing(str(entry.site))
	if grazing!=previous_grazing:
		previous_grazing=grazing
		if not grazing: set_goal(station,true)
		else: timer=0;behavior=Behavior.IDLE
	if held>0: behavior=Behavior.INTERACT;velocity=Vector2.ZERO
	elif behavior in [Behavior.WANDER,Behavior.RETURN_HOME]:
		while route_index<route.size() and global_position.distance_to(route[route_index])<2: route_index+=1
		if route_index>=route.size():
			velocity=Vector2.ZERO;behavior=Behavior.IDLE;timer=rng.randf_range(.5,1.8) if not large else rng.randf_range(1.8,3.5)
		else:
			var offset: Vector2=route[route_index]-global_position
			velocity=offset.normalized()*minf(speed,offset.length()/maxf(delta,.001))
			# Stable per-animal routes and a small separation brake; no full-map A* per frame.
			if Livestock.animal_separation_blocked(entry,global_position+velocity*delta): velocity=Vector2.ZERO
			var before:=global_position;move_and_slide();var distance: float=global_position.distance_to(before);total_distance+=distance
			if distance<.03: stalled+=delta
			else: stalled=0
			if stalled>1.2:
				behavior=Behavior.IDLE;timer=rng.randf_range(.3,.8);stalled=0
			if velocity.length_squared()>1:
				direction=(2 if velocity.x>0 else 1) if absf(velocity.x)>absf(velocity.y) else (0 if velocity.y>0 else 3)
	else:
		velocity=Vector2.ZERO
		if timer<=0: choose_activity(entry)
	Livestock.save_animal_position(entry,global_position)
	animation+=delta*(6.0 if behavior==Behavior.WANDER and not large else 4.0 if behavior==Behavior.RETURN_HOME else 2.0 if behavior==Behavior.GRAZE else 1.0)
	frame=int(animation)%4
	var code: int=frame+direction*4+int(behavior)*16
	if code!=painted: painted=code;queue_redraw()

func _draw() -> void:
	var entry:=Livestock.animal(animal_id)
	if entry.is_empty() or age_texture==null: return
	var native_size:=Vector2(48,40) if species_id=="cow" else Vector2(40,36) if species_id=="sheep" else Vector2(32,32)
	var size: Vector2=native_size if Livestock.is_adult(entry) else (native_size*.75).round()
	var action: int=1 if behavior==Behavior.GRAZE else 2 if behavior==Behavior.REST else 0
	var show_frame: int=frame if behavior in [Behavior.WANDER,Behavior.RETURN_HOME,Behavior.GRAZE,Behavior.REST] else 0
	draw_rect(Rect2(-size.x*.3,-1,size.x*.6,3),Color(.18,.28,.19,.20))
	draw_texture_rect_region(age_texture,Rect2(Vector2(-size.x/2,-size.y+4),size),Rect2(Vector2(show_frame,action*4+direction)*native_size,native_size))
	if entry.pet_day==GameClock.day: draw_rect(Rect2(size.x*.35,-size.y+3,3,3),Color("e1a5ad"))
