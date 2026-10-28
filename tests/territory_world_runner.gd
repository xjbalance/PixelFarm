extends "res://tests/runner.gd"
## 实际场景、碰撞、寻路与共享收纳；仅在隔离用户目录运行。
var capture_mode: bool=false
var captures: Array=[]
var territory_world: TerritoryWorld

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	if not is_instance_valid(game.territory_world):
		game.territory_world=TerritoryWorld.new();game.add_child(game.territory_world);game.territory_world.setup(game)
	if not is_instance_valid(game.territory_editor):
		game.territory_editor=TerritoryEditor.new();game.add_child(game.territory_editor);game.territory_editor.setup(game)
	territory_world=game.territory_world
	await gates_and_permissions()
	await landscaping()
	await collision_and_routes()
	await facilities_and_shared_storage()
	await route_guard()
	await seasons()
	game.territory_editor.cancel()
	var report:=FileAccess.open("res://builds/territory-world-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"android_device_tested":false,"platform":DisplayServer.get_name()},"\t"));report.close()
	print("TERRITORY WORLD "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func visit(area: String, point: Vector2) -> void:
	game.territory_editor.cancel()
	while game.hud.close_active_panel(): pass
	game.change_location(area,point);game.auto_move.cancel();game.player.velocity=Vector2.ZERO;await frames(5)

func edit() -> void:
	if not game.territory_editor.active: check(game.territory_editor.open(),"从当前实际领地打开建造模式")
	await frames(3)

func place(kind: String, cell: Vector2i) -> String:
	await edit()
	var plan:=Territory.plan_place(GameState.location,kind,cell)
	check(plan.valid,"实际地形允许放置："+kind+str(cell)+" "+str(plan.reason))
	if not plan.valid: return ""
	check(Territory.apply_plan(plan),"原子确认生成一件领地物体："+kind)
	await frames(4)
	return str(Territory.state.objects[-1].id)

func gates_and_permissions() -> void:
	check(territory_world.maps.size()==5 and territory_world.gates.size()==4,"主农场与四张地上附属地注册，原地下地图未被替换")
	check(not Territory.unlocked("east_holding"),"新旅程尚未完成章节，河东入口未开放")
	await visit("farm",Vector2(1088,352));territory_world.gates.east_holding.interact();await frames(3)
	check(GameState.location=="farm","未解锁路牌不能将角色送入附属地")
	check(not Territory.plan_terrain("farm",[Vector2i(17,16)],"soil").valid,"原60格农田不被领地地表覆盖")
	check(not Territory.plan_place("farm","tree",Vector2i(7,20)).valid,"旧资源再生位置永远受保护")
	check(not Territory.plan_place("farm","fence",Vector2i(20,13)).valid,"原主通路与住宅门前不能堵住")
	check(not Territory.plan_terrain("village",[Vector2i(8,8)],"stone_path").valid,"公共村庄拒绝地表编辑")
	check(not Territory.plan_place("mine_a","lamp",Vector2i(8,8)).valid,"地下区域拒绝放置新设施")
	load("res://tests/star_runner.gd").fixture(game,false)
	Territory.refresh_unlocks(false);await frames(4)
	check(Territory.unlocked("east_holding"),"第一章完成后现有剧情状态开放河东领地")
	await visit("farm",Vector2(1088,352));territory_world.gates.east_holding.interact();await frames(5)
	check(GameState.location=="east_holding" and game.player.position==Vector2(640,800),"沿已开放实体入口进入新地上区域并使用固定安全入口")
	var map: Node=territory_world.maps.east_holding
	var exit: Node=map.actors.get_children().filter(func(node: Node): return node is TerritoryGate)[0]
	exit.interact();await frames(5)
	check(GameState.location=="farm" and game.player.position==Vector2(1088,352),"附属地出口返回对应路口，不改变其他地图入口")
	await visit("east_holding",Vector2(640,800))
	check(not Territory.plan_place("east_holding","fence",Vector2i(19,10)).valid,"附属地中央通道与门口保留")
	check(not Territory.plan_place("east_holding","tree",Vector2i(8,3)).valid,"半开放过渡带不放置阻挡物")
	check(Territory.plan_place("east_holding","flowers",Vector2i(8,3)).valid,"半开放过渡带允许不阻挡花草")

func landscaping() -> void:
	await edit()
	for index in range(6):
		var kind: String=["soil","grass","dirt_path","stone_path","wood_path","flowerbed"][index]
		var cells: Array=[Vector2i(7+index,9),Vector2i(7+index,10)]
		var before: Dictionary=Territory.snapshot();var plan:=Territory.plan_terrain("east_holding",cells,kind)
		check(plan.valid and Territory.snapshot()==before,"双格地表预览不修改存档："+kind)
		check(Territory.apply_plan(plan),"批量确认两格地表："+kind);await frames(3)
		check(territory_world.surfaces.east_holding.cells.get(TerritoryCatalog.key(cells[0]))==kind,"事件驱动叠加层立即显示新地表："+kind)
	var natural:=Territory.plan_terrain("east_holding",[Vector2i(8,9)],"natural")
	check(Territory.apply_plan(natural) and not Territory.state.terrain.east_holding.has("8,9"),"恢复自然只移除对应叠加记录")
	await frames(4)
	await place("tree",Vector2i(8,12));await place("bush",Vector2i(11,12));await place("tall_grass",Vector2i(13,12));await place("flowers",Vector2i(15,12))
	game.territory_editor.cancel();game.player.position=Vector2(420,480);game.camera_rig.follow_now();await frames(4);await capture("vegetation_and_paths")

func collision_and_routes() -> void:
	game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.walkable(Vector2i(8,12)) and not game.auto_move.navigation.walkable(Vector2i(9,13)),"新树的完整2×2实际碰撞同步到原导航网格")
	check(game.auto_move.navigation.walkable(Vector2i(13,12)) and game.auto_move.navigation.walkable(Vector2i(15,12)),"草和花不阻挡原导航")
	var target:=Vector2(14*32+16,12*32+16)
	game.player.position=Vector2(5*32+16,12*32+16);game.camera_rig.follow_now();await frames(3)
	game.auto_move.request(target)
	for _i in range(350):
		await frames(1)
		if game.auto_move.path.is_empty() and game.player.global_position.distance_to(target)<3: break
	check(game.player.global_position.distance_to(target)<3,"原点击移动实际绕过新树抵达另一侧")
	game.auto_move.cancel()
	var person: CharacterBody2D=load("res://scenes/npc/linya.tscn").instantiate();person.name="TerritoryCollisionProbe"
	territory_world.maps.east_holding.actors.add_child(person);person.set_physics_process(false);person.position=Vector2(6*32+16,12*32+16);await frames(3)
	var route:=VillagerNavigation.route(person,target)
	var clear: bool=not route.is_empty()
	for point in route:
		if Rect2i(8,12,2,2).has_point(Vector2i((point/32).floor())): clear=false
	check(clear,"原NPC导航查询绕过新增实体障碍")
	for _i in range(35): person.velocity=Vector2(240,0);person.move_and_slide();await frames(1)
	check(person.position.x<8*32-8,"NPC脚底实际碰撞阻止其直穿新树")
	person.queue_free();await frames(3)
	await edit()
	check(not Territory.plan_place("east_holding","tree",Vector2i((game.player.position/32).floor())).valid,"新实心物体不能覆盖角色站位")

func facilities_and_shared_storage() -> void:
	var chest_id:=await place("chest",Vector2i(8,18));var lamp_id:=await place("lamp",Vector2i(11,18));await place("fence",Vector2i(13,18));await place("table",Vector2i(7,21));await place("chair",Vector2i(10,21));await place("bench",Vector2i(12,21))
	check(territory_world.objects.has(chest_id) and territory_world.objects[chest_id].is_in_group("territory_storage"),"实际箱子加入共用收纳访问点")
	var moved:=Territory.plan_move(chest_id,Vector2i(9,19));check(moved.valid and Territory.apply_plan(moved),"原子移动已有箱子，保持唯一ID");await frames(4)
	check(Territory.object(chest_id).cell==[9,19] and territory_world.objects[chest_id].position==Vector2(304,624),"箱子状态、显示与实际碰撞同时迁移")
	var lamp_move:=Territory.plan_move(lamp_id,Vector2i(12,19));check(lamp_move.valid and Territory.apply_plan(lamp_move),"灯具使用同一安全移动流程");await frames(4)
	var remove:=Territory.plan_remove(lamp_id);check(remove.valid and Territory.apply_plan(remove),"已拥有灯具可以安全拆除");await frames(4)
	check(not territory_world.objects.has(lamp_id) and Territory.object(lamp_id).is_empty(),"拆除从状态与场景同步移除，没有幽灵碰撞")
	game.territory_editor.cancel();game.player.position=Vector2(304,672);game.camera_rig.follow_now();await frames(4)
	var chest: Node=territory_world.objects[chest_id]
	check(chest.storage_accessible(),"角色靠近移动后箱子的真实合法交互位置")
	var original: Dictionary=Housing.state.storage.duplicate(true);Inventory.items.wood=20
	check(Housing.deposit("wood",3) and Inventory.count("wood")==17 and int(Housing.state.storage.get("wood",0))==int(original.get("wood",0))+3,"新箱子只访问原住宅共享收纳，不产生额外容量或副本")
	check(Housing.withdraw("wood",3) and Inventory.count("wood")==20 and Housing.state.storage==original,"取回物品使用原收纳事务，数量不复制")
	await capture("small_facilities")

func seasons() -> void:
	var unchanged:=Territory.snapshot()
	for index in range(4):
		GameClock.day=225+index*28;Calendar.restore(Calendar.snapshot());await frames(3)
		var tree: Node=territory_world.objects.values().filter(func(node: Node): return str(node.entry.kind)=="tree")[0]
		check(tree.sprite.texture.resource_path.contains(["spring","summer","autumn","winter"][index]),"新植被按既有四季切换显示，不产生采集资源："+str(index))
		check(Territory.snapshot()==unchanged,"季节变化保留全部道路、植物与设施布局："+str(index))
		await capture("season_"+str(index))

func route_guard() -> void:
	game.player.position=Vector2(30*32+16,18*32+16);game.camera_rig.follow_now();await frames(4)
	var placed: Array[String]=[]
	for cell in [Vector2i(29,18),Vector2i(31,18),Vector2i(30,17)]: placed.append(await place("fence",cell))
	var before:=Territory.snapshot()
	var closing:=Territory.plan_place("east_holding","fence",Vector2i(30,19))
	check(not closing.valid and not Territory.apply_plan(closing) and Territory.snapshot()==before,"最后一段围栏不能将角色与门口通路完全隔开，也不能强行提交")
	for id in placed:
		check(Territory.apply_plan(Territory.plan_remove(id)),"安全拆除测试围栏恢复原通路")
		await frames(3)
	game.territory_editor.cancel();game.player.position=Vector2(304,672);game.camera_rig.follow_now();await frames(3)

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/territory-world-"+label+".png";get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
