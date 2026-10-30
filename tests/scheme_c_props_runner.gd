extends "res://tests/runner.gd"
## 新素材只更换显示；旧碰撞/状态与可覆盖装饰的层恢复使用真实场景验证。
var capture_mode: bool=false
var captures: Array=[]
var seed: Dictionary

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	seed=FarmSaveStore.snapshot(game)
	await scenery_cover()
	await worksite_state()
	await livestock_stages()
	check(FarmSaveStore.restore(game,seed),"显示专项结束恢复原状态，无玩家文件写入")
	var output:=FileAccess.open("res://builds/scheme-c-props-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));output.close()
	print("SCHEME C PROPS "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func scenery(kind: String, parent: Node, point: Vector2) -> RiverScenery:
	var result:=RiverScenery.new();result.kind=kind;result.position=point;parent.add_child(result);return result

func scenery_cover() -> void:
	var at:=Vector2(368,528);var cell:=Vector2i((at/32).floor())
	var cart:=scenery("cart",game.world.actors,at)
	var mail:=scenery("mail",game.world.actors,at+Vector2(0,64))
	var public_cart:=scenery("cart",game.village.get_node("Actors"),at)
	var windmill:=scenery("windmill",game.village.get_node("Actors"),Vector2(1060,380))
	await frames(4)
	var body: StaticBody2D=cart._collision_body;var shape: RectangleShape2D=body.get_child(0).shape
	check(body.collision_layer==1 and shape.size==Vector2(62,24),"手推车换图保留旧62×24实体占地")
	check(windmill._windmill_art is AnimatedSprite2D and windmill._windmill_art.sprite_frames.get_frame_count("loop")==4 and windmill._windmill_art.sprite_frames.get_animation_speed("loop")==4,"风车使用提供的四帧4FPS动画，无第二套旋转叠图")
	check(not windmill.is_processing(),"接入SpriteFrames后不再每帧重画旧风车几何")
	var original_layer: int=public_cart._collision_body.collision_layer
	var old: Dictionary=Territory.snapshot()
	Territory.state.terrain.farm={TerritoryCatalog.key(cell):"dirt_path",TerritoryCatalog.key(Vector2i((mail.global_position/32).floor())):"grass"};Territory.changed.emit();await frames(4)
	check(cart._decor_covered and body.collision_layer==0,"覆盖农场装饰地格会同时隐藏图像并释放实体碰撞")
	check(not mail._decor_covered and mail._collision_body.collision_layer==1,"邮筒等关键点不随地表改造自动隐藏")
	check(not public_cart._decor_covered and public_cart._collision_body.collision_layer==original_layer,"相同坐标的村庄装饰不受农场编辑影响")
	Territory.restore(old);await frames(4)
	check(not cart._decor_covered and body.collision_layer==1 and shape.size==Vector2(62,24),"恢复自然地表后原手推车与相同碰撞恢复")
	cart.hide();Territory.changed.emit();await frames(2)
	check(not cart.visible,"编辑清除不会抹掉其他系统设置的外部可见性")
	cart.queue_free();mail.queue_free();public_cart.queue_free();windmill.queue_free();await frames(3)

func worksite_state() -> void:
	var protected: Dictionary={"inventory":Inventory.items.duplicate(true),"coins":Inventory.coins,"progress":FarmProgress.snapshot(),"village":VillageProjects.snapshot()}
	var fixtures: Array=[]
	for kind in ["board","workshop"]:
		var node:=Node2D.new();node.set_script(load("res://scripts/world/worksite.gd"));node.kind=kind;game.world.actors.add_child(node);fixtures.append(node)
		var body: StaticBody2D=node.get_child(0);var shape: CollisionShape2D=body.get_child(0)
		check(shape.position==Vector2(0,-21) and shape.shape.size==Vector2(52,20),"方案C修缮/委托显示仍使用原52×20碰撞："+kind)
	FarmProgress.built.assign(["toolrack","irrigation"]);FarmProgress.changed.emit();await frames(5)
	check(Inventory.coins==protected.coins and Inventory.items==protected.inventory and VillageProjects.snapshot()==protected.village,"工具架与灌溉图像同步不扣钱物、不改变公共建设")
	FarmProgress.restore(protected.progress);await frames(2)
	for node in fixtures: node.queue_free()
	await frames(3)

func livestock_stages() -> void:
	var points: Array=[]
	for node in get_tree().get_nodes_in_group("interactables"):
		if game.world.is_ancestor_of(node) and "livestock_id" in node and str(node.livestock_id) in Livestock.SITES: points.append(node)
	check(points.size()==3,"保留鸡舍、牛棚、羊圈三个原交互实体")
	var money: int=Inventory.coins;var items: Dictionary=Inventory.items.duplicate(true)
	game.change_location("farm",Vector2(576,800));await frames(5)
	for level in [0,1,2,3]:
		for point in points: Livestock.state.buildings[point.livestock_id].level=level
		Livestock.changed.emit();await frames(5)
		for point in points:
			check(point.shape.shape.size==Vector2(112,48) and point.shape.get_parent().position==Vector2(0,-92) and point.shape.disabled==(level==0),"所有等级换图不改变原后墙碰撞和开放条件："+point.livestock_id+str(level))
			check((point.label.text.contains("待建") if level==0 else point.label.text.contains("Lv%d" % level)),"未建/已建/升级标签与实际等级一致："+point.livestock_id+str(level))
		if level in [0,1,3]: await capture("livestock_level_"+str(level))
	check(Inventory.coins==money and Inventory.items==items and Livestock.state.animals.is_empty(),"畜舍显示刷新不付建造费、不凭空生成动物或产物")
	Inventory.coins=2000
	var charged: int=0
	for point in points:
		game.player.position=Livestock.SITES[point.livestock_id]+Vector2(0,40)
		charged+=int(Livestock.data.species[Livestock.data.buildings[point.livestock_id].species].price)
		check(Livestock.buy_animal(point.livestock_id),"使用原购买接口生成暖舍中的真实动物："+point.livestock_id)
	await frames(5)
	check(Inventory.coins==2000-charged and Livestock.state.animals.size()==3,"新畜舍外观仍按原价格购买，不改变动物数量与支出")
	for animal in get_tree().get_nodes_in_group("livestock_animals"):
		var entry: Dictionary=Livestock.animal(animal.animal_id)
		game.change_location(Livestock.animal_area(entry));await frames(3)
		check(animal.is_visible_in_tree() and RanchLayout.indoor(str(entry.site)).has_point(animal.position),"暖舍动物在对应独立牧场真实可见："+entry.species)
	game.player.position=Vector2(576,800);await capture("livestock_with_animals")

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK;game.camera_rig.view_center=Vector2(576,750);game.camera_rig.apply_camera()
	await frames(5);await RenderingServer.frame_post_draw
	var path: String="res://builds/scheme-c-props-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
