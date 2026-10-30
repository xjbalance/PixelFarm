extends "res://tests/runner.gd"
## CPU端日程批处理、天气绘制预算与动物移动语义；不代表Android帧率。
var timings: Dictionary = {}

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	await frames(6)
	await navigation_samples()
	await weather_budget()
	await animal_motion()
	print("PERFORMANCE 071 ",JSON.stringify(timings))
	print("PERFORMANCE 071 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func navigation_samples() -> void:
	GameClock.minutes=1110;GameClock.changed.emit()
	game.change_location("village");await frames(5)
	var people: Array=[]
	for object in get_tree().get_nodes_in_group("interactables"):
		if object is CharacterBody2D and game.village.is_ancestor_of(object) and object.is_visible_in_tree(): people.append(object)
	check(people.size()>=3,"日程批处理使用真实村庄三位NPC")
	var navigation: Variant=load("res://scripts/npc/npc_navigation.gd")
	var start: int=Time.get_ticks_usec()
	var baseline: Array=[]
	for i in range(12):
		var person: CharacterBody2D=people[i%people.size()]
		baseline.append(legacy_route(person,Vector2(624,496)))
	var old_us: int=Time.get_ticks_usec()-start
	var samples: int=navigation.sample_count
	start=Time.get_ticks_usec()
	var equivalent := true
	for i in range(12):
		var person: CharacterBody2D=people[i%people.size()]
		var path: PackedVector2Array=navigation.route(person,Vector2(624,496))
		equivalent=equivalent and path==baseline[i]
	var new_us: int=Time.get_ticks_usec()-start
	check(equivalent,"同帧共享采样保留村民合法起终点及原路径结果")
	check(navigation.sample_count==samples+1,"同物理帧十二次村民请求只采样一次静态地图")
	await frames(2)
	navigation.route(people[0],people[0].global_position)
	check(navigation.sample_count==samples+2,"后续物理帧重新采样，不使用过期机关或碰撞")
	var village_sample: int=navigation.sample_count
	var farm_person: CharacterBody2D=game.world.get_node("Actors/Linya")
	navigation.route(farm_person,farm_person.global_position)
	check(navigation.sample_count==village_sample+1,"同帧跨场景请求以真实地图实例隔离缓存")
	# 修改静态障碍，等物理同步后必须拒绝被新碰撞占据的目标。
	var blocker := StaticBody2D.new();blocker.collision_layer=1
	var shape := CollisionShape2D.new();var rect := RectangleShape2D.new();rect.size=Vector2(32,32)
	shape.shape=rect;blocker.add_child(shape);game.village.add_child(blocker)
	var goal := Vector2(624,496);blocker.position=goal
	await frames(3)
	check(navigation.route(people[0],goal).is_empty(),"新增实体障碍后的下次路径不会穿入阻挡格")
	blocker.queue_free();await frames(3)
	var route: PackedVector2Array=navigation.route(people[0],goal)
	check(not route.is_empty(),"动态障碍移除后新物理帧可重新找到路线")
	timings["npc_batch"]={"requests":12,"legacy_full_samples":12,"shared_full_samples":1,"legacy_call_us":old_us,"shared_call_us":new_us,"scope":"Linux headless same-frame NPC scheduling CPU calls; not Android FPS"}

func weather_budget() -> void:
	var weather: Variant=get_tree().get_nodes_in_group("weather_screens")[0]
	GameState.modal=false;GameState.location="farm";GameClock.minutes=600;GameClock.running=true;GameWeather.enabled=false
	check(not weather.animation_active(),"晴朗白天没有动态天气，不安排持续空重绘")
	GameClock.minutes=1200
	check(weather.animation_active(),"晴朗非冬夜保留动态萤火")
	GameClock.running=false
	check(not weather.animation_active(),"游戏暂停不积累天气动画")
	GameClock.running=true;GameState.location="mine_b"
	check(not weather.animation_active(),"矿洞室内不持续运行屏幕天气")
	GameState.location="farm";GameState.modal=true
	check(not weather.animation_active(),"模态界面暂停动态天气")
	GameState.modal=false;GameClock.running=false
	weather.fade=.01;weather.banner_time=0;weather.accumulator=0
	weather._process(.02)
	check(weather.fade==0 and weather.banner_time==0 and weather.accumulator==0,"转场结束主动清除末帧遮罩，即使处于暂停")

func animal_motion() -> void:
	game.change_location("farm");await frames(4)
	Livestock.restore(Livestock.defaults(GameClock.day));Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"copper_bar":99,"iron_bar":99}
	for site in Livestock.SITES:
		game.player.global_position=Livestock.SITES[site]+Vector2(0,32)
		Livestock.build(site);Livestock.upgrade(site);Livestock.upgrade(site)
		for i in range(6): Livestock.buy_animal(site)
	await frames(4)
	var first: Dictionary=Livestock.state.animals[0]
	var initial: Array=first.pasture_position.duplicate()
	var position_array: Array=first.pasture_position
	GameClock.minutes=600;game.player.position=Livestock.site_point("coop")+Vector2(0,32);Livestock.graze("coop")
	game.change_location("pasture_coop");await frames(4);GameClock.running=true;GameClock.changed.emit();await frames(3)
	for object in get_tree().get_nodes_in_group("livestock_animals"):
		if object.animal_id==first.id: object.set_goal(Vector2(416,336))
	await frames(180);GameClock.running=false
	check(Livestock.state.animals.size()==18,"性能夹具真实加载满容量十八只动物")
	check(first.pasture_position!=initial and position_array==first.pasture_position,"动物物理移动继续更新原有位置数组，省去逐帧替换分配")
	check(Livestock.validate(Livestock.snapshot(),GameClock.day),"优化后的移动位置仍可完整合法存档")
	var valid_footprints := true
	for object in get_tree().get_nodes_in_group("livestock_animals"):
		if not object.is_visible_in_tree(): continue
		var query := PhysicsShapeQueryParameters2D.new()
		for child in object.get_children():
			if child is CollisionShape2D: query.shape=child.shape;break
		query.transform=Transform2D(0,object.global_position+Vector2(0,-3));query.collision_mask=1
		if not object.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): valid_footprints=false
	check(valid_footprints,"满栏动物运动未以减低更新频率为代价穿入地图碰撞")
	timings["animals"]={"count":18,"active_in_view":6,"physics_hz":60,"sprite_frames_hz":4,"position_arrays_reallocated_per_physics_frame":0}

func legacy_route(person: CharacterBody2D, destination: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	var in_farm := person.get_parent().get_parent().name=="FarmWorld"
	grid.region=FarmLayoutCatalog.GRID if in_farm else Rect2i(0,0,40,28)
	grid.cell_size=Vector2(32,32);grid.offset=Vector2(16,16);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	var query := PhysicsShapeQueryParameters2D.new();var shape := RectangleShape2D.new();shape.size=Vector2(31,31)
	query.shape=shape;query.exclude=[person.get_rid()];query.collision_mask=1
	var space := person.get_world_2d().direct_space_state
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var id := Vector2i(x,y);query.transform=Transform2D(0,Vector2(id)*32+Vector2(16,16))
			var solid := false
			for hit in space.intersect_shape(query,16):
				if hit.collider is CanvasItem and hit.collider.is_visible_in_tree(): solid=true;break
			grid.set_point_solid(id,solid)
	var start := Vector2i((person.global_position/32).floor());var goal := Vector2i((destination/32).floor())
	if not grid.region.has_point(start) or not grid.region.has_point(goal): return PackedVector2Array()
	grid.set_point_solid(start,false)
	if grid.is_point_solid(goal): return PackedVector2Array()
	return grid.get_point_path(start,goal)
