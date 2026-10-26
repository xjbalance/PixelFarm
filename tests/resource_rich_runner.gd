extends "res://tests/runner.gd"
## 地图资源扩充沿用旧资源字段与真实输入；仅在外部隔离用户目录运行。
const Touch=preload("res://tests/touch_navigation.gd")
const LEGACY_IDS=["tree_5_8","tree_7_20","tree_9_24","tree_12_6","tree_27_8","tree_29_11","tree_41_13","tree_40_23","tree_30_26","tree_19_26","tree_4_15","tree_37_6","tree_42_27","tree_25_5","rock_11_19","rock_28_24","rock_30_9","rock_39_24","rock_8_13"]
var initial: Dictionary

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	await catalogs_and_legacy()
	await farm_and_village_routes()
	await forest_routes()
	await real_collection()
	await resource_safety()
	await regrowth()
	await community_materials()
	print("RESOURCE RICH RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

static func legacy_resources(all_resources: Dictionary) -> Dictionary:
	var old: Dictionary={}
	for id in LEGACY_IDS: old[id]=all_resources[id].duplicate(true)
	return old

static func visit(test: Node, owner_game: Node, area: String) -> void:
	while owner_game.hud.close_active_panel(): pass
	GameState.set_control_mode("tap",false)
	owner_game.change_location(area,WorldTravel.entry(area));await test.frames(6)
	owner_game.auto_move.navigation.rebuild()

static func first_resource(owner_game: Node, area: String, kind: String) -> String:
	var field: Node2D=owner_game.resource_world.fields[area]
	var ids: Array=field.objects.keys();ids.sort()
	for id in ids:
		var object: Node2D=field.objects[id]
		if object.kind!=kind or field.state[id].hp<=0: continue
		if not owner_game.auto_move.navigation.path_to({"kind":"resource","object":object,"point":object.global_position}).is_empty(): return id
	return ""

static func approach_resource(test: Node, owner_game: Node, area: String, id: String) -> bool:
	if GameState.location!=area: await visit(test,owner_game,area)
	var field: Node2D=owner_game.resource_world.fields[area]
	if not field.objects.has(id): return false
	var object: Node2D=field.objects[id]
	owner_game.auto_move.navigation.rebuild()
	var intent: Dictionary={"kind":"resource","object":object,"point":object.global_position}
	var path: PackedVector2Array=owner_game.auto_move.navigation.path_to(intent)
	if path.is_empty(): return false
	# 先走到合法站位，不提前挥工具；之后再验证原生点击只采一次。
	owner_game.auto_move.request_target({"kind":"ground","point":path[-1]})
	await Touch.finish(test,owner_game,2400);await test.frames(4)
	return owner_game.auto_move.navigation.legal_interaction(owner_game.player.global_position,intent)

static func click_point(object: Node2D) -> Vector2:
	return object.global_position+Vector2(0,-30 if object.kind=="tree" else -6)

static func visible_click_point(owner_game: Node, object: Node2D) -> Vector2:
	# 保留完整经典HUD；只选择现有精灵/命中框内真正露出且仍命中同一资源的位置。
	var offsets: Array=[Vector2(0,-30),Vector2(0,0),Vector2(0,5),Vector2(12,-12),Vector2(-12,-12),Vector2(12,-40),Vector2(-12,-40)] if object.kind=="tree" else [Vector2(0,-6),Vector2(0,5),Vector2(12,-6),Vector2(-12,-6)]
	for offset in offsets:
		var point: Vector2=object.global_position+offset
		var screen: Vector2=owner_game.player.get_canvas_transform()*point
		if not owner_game.get_viewport().get_visible_rect().grow(-8).has_point(screen) or owner_game.touch_input.ui_at(screen): continue
		var resolved: Dictionary=TouchInteractionResolver.resolve(owner_game,point)
		if resolved.get("kind")=="resource" and resolved.get("object")==object: return point
	return Vector2.INF

static func visible_resource(test: Node, owner_game: Node, area: String, kind: String) -> Dictionary:
	if GameState.location!=area: await visit(test,owner_game,area)
	var field: Node2D=owner_game.resource_world.fields[area]
	var ids: Array=field.objects.keys();ids.sort()
	for id in ids:
		var object: Node2D=field.objects[id]
		if object.kind!=kind or field.state[id].hp<=0: continue
		if not await approach_resource(test,owner_game,area,id): continue
		await test.frames(8)
		var point:=visible_click_point(owner_game,object)
		if point!=Vector2.INF: return {"id":id,"point":point}
	return {}

static func click_resource_once(test: Node, owner_game: Node, area: String, id: String) -> bool:
	if not await approach_resource(test,owner_game,area,id): return false
	await test.frames(8)
	var field: Node2D=owner_game.resource_world.fields[area]
	var object: Node2D=field.objects[id];var point:=visible_click_point(owner_game,object)
	if point==Vector2.INF: return false
	var hp: int=field.state[id].hp;var stamina: int=GameState.stamina;var calls: int=owner_game.auto_move.execution_count
	GameState.manual_tool=false
	Touch.tap(test,owner_game,point);await Touch.finish(test,owner_game);await test.frames(20)
	return field.state[id].hp==hp-1 and GameState.stamina==stamina-3 and owner_game.auto_move.execution_count==calls+1

func fresh() -> void:
	while game.hud.close_active_panel(): pass
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	for index in game.touch_input.fingers.keys(): Touch.finger(self,Vector2.ZERO,false,index)
	check(FarmSaveStore.restore(game,initial),"资源探针恢复完整初始进度")
	GameClock.running=false;GameWeather.enabled=false;GameState.set_control_mode("tap",false)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.items={"wood":1,"stone":1}
	Inventory.coins=321;Xiaojing.state.diamonds=1314;GameState.rest();await frames(5)

func transaction() -> Dictionary:
	return {"resources":game.resource_world.snapshot(),"items":Inventory.items.duplicate(true),"stamina":GameState.stamina,"coins":Inventory.coins,"diamonds":int(Xiaojing.state.diamonds),"plants":int(Xiaojing.state.plants)}

func catalogs_and_legacy() -> void:
	await fresh()
	var all: Dictionary=FarmResourceCatalog.all_placements()
	check(all.size()==128 and game.resource_world.fields.size()==3,"三图真实资源目录合计128个唯一节点")
	for row in [["farm",30,12],["village",10,6],["mist_forest",45,25]]:
		var counts: Dictionary={"tree":0,"rock":0};var entries: Dictionary=FarmResourceCatalog.placements(row[0])
		for entry in entries.values(): counts[entry.kind]+=1
		check(counts.tree==row[1] and counts.rock==row[2] and game.resource_world.fields[row[0]].objects.size()==entries.size(),"配置节点与实体树石数量一致："+str(row[0]))
	var kept:=true
	for id in LEGACY_IDS: kept=kept and FarmResourceCatalog.placements().has(id)
	check(kept,"原14树5石坐标ID全部保留")
	var old:=FarmSaveStore.snapshot(game);old.resources=legacy_resources(old.resources)
	old.resources.tree_7_20={"hp":0,"ready_day":GameClock.day+3};old.resources.rock_11_19={"hp":1,"ready_day":0}
	var normalized:=FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not normalized.is_empty() and normalized.version==23,"只含旧19节点的真实v23资源快照仍可读取，无需改schema")
	if normalized.is_empty(): return
	check(FarmSaveStore.restore(game,old),"旧资源快照通过完整恢复入口")
	await frames(5)
	var expanded: Dictionary=game.resource_world.snapshot();var old_preserved:=true;var new_defaults:=true
	for id in old.resources: old_preserved=old_preserved and expanded[id]==old.resources[id]
	for id in all:
		if not old.resources.has(id): new_defaults=new_defaults and expanded[id]=={"hp":int(FarmResourceCatalog.TYPES[all[id].kind].hits),"ready_day":0}
	check(old_preserved and expanded.size()==128,"旧已砍树和半损石不刷新，新图与新节点被补入")
	check(new_defaults,"缺失新增ID仅初始化各自完整耐久，不提前扣费或发奖")
	var before:=transaction();var snap:=FarmSaveStore.snapshot(game)
	for _i in range(3):
		check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snap))),"同日完整JSON资源恢复")
		for area in ["mist_forest","village","farm"]: await visit(self,game,area)
	check(transaction()==before,"同日反复换图和读档不再生、不复制金币物品钻石或520计数")
	var bad:=snap.duplicate(true);bad.resources.mist_forest_tree_invented={"hp":3,"ready_day":0}
	check(not FarmSaveStore.restore(game,bad) and transaction()==before,"未知资源ID整档拒绝，不洗成新增物品或刷新原节点")
	bad=snap.duplicate(true);bad.resources.tree_7_20.hp=-1
	check(not FarmSaveStore.restore(game,bad) and transaction()==before,"非法负耐久整档拒绝且原资源库存保持")

func farm_and_village_routes() -> void:
	await fresh();load("res://tests/mining.gd").fresh_chapter(game);Calendar.restore(Calendar.snapshot())
	for area in ["farm","village"]:
		await visit(self,game,area)
		var reachable:=true;var checked_points:=0
		for point in get_tree().get_nodes_in_group("interactables"):
			if not point.is_visible_in_tree(): continue
			if ("person_id" in point) or ("kind" in point and point.kind in ["home","village","shop","board","exit"]) or ("actor_id" in point and point.actor_id in ["farm_return","community"]) or ("pen_id" in point) or ("exploration_id" in point and point.exploration_id in ["forest_entry","temple_entry"]):
				checked_points+=1
				if game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(): reachable=false;print("RESOURCE KEY PATH MISSING ",area," ",point.prompt())
		check(reachable and checked_points>=3,"扩充树石后原NPC、门口与建设/养殖入口可达："+area)
		check(await all_resources_reachable(area),"原图每个可采资源都有合法接近路线："+area)

func all_resources_reachable(area: String) -> bool:
	var field: Node2D=game.resource_world.fields[area];var reachable:=true
	for id in field.objects:
		var object: Node2D=field.objects[id]
		if field.state[id].hp<=0: continue
		var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"resource","object":object,"point":object.global_position})
		if route.is_empty(): reachable=false;print("RESOURCE PATH MISSING ",id)
	return reachable

func approach_point(id: String) -> bool:
	var object: Node2D=game.mine_maps.mist_forest.objects[id]
	game.auto_move.request_target({"kind":"object","object":object,"point":object.global_position})
	await Touch.finish(self,game,2400)
	while game.hud.close_active_panel(): pass
	return Exploration.near_id(id)

func forest_routes() -> void:
	await fresh();await visit(self,game,"mist_forest")
	check(game.resource_world.active_field()==game.resource_world.fields.mist_forest,"进入森林后活动资源场属于实体森林")
	for id in ["forest_exit","forest_order","forest_spring","forest_summer","forest_autumn","forest_winter","forest_herbs"]:
		var point: Node2D=game.mine_maps.mist_forest.objects[id]
		check(not game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(),"资源林不堵原闭门阶段必需点："+id)
	var archive: Node2D=game.mine_maps.mist_forest.objects.forest_archive
	check(game.auto_move.navigation.path_to({"kind":"object","object":archive,"point":archive.global_position}).is_empty(),"新增林地没有绕过原四季机关门")
	check(await approach_point("forest_order") and Exploration.read("forest_order"),"真实行走读取原森林顺序线索")
	check(await approach_point("forest_winter") and not Exploration.operate("forest_winter") and Exploration.state.forest.step==0,"新增资源不取消原错误机关反馈")
	for id in ["forest_spring","forest_summer","forest_autumn","forest_winter"]:
		check(await approach_point(id) and Exploration.operate(id),"沿原实体路径依次操作机关："+id)
	await frames(5);game.auto_move.navigation.rebuild()
	check(Exploration.state.forest.open and await all_resources_reachable("mist_forest"),"原谜题实开门后资源丰富森林全部树石有接近路线")
	for id in ["forest_archive","forest_cache","forest_reeds","pond_cache"]:
		var point: Node2D=game.mine_maps.mist_forest.objects[id]
		check(not game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(),"资源增加后档案宝箱采样仍可达："+id)

func real_collection() -> void:
	await fresh()
	for area in ["mist_forest","village","farm"]:
		await visit(self,game,area)
		for kind in ["tree","rock"]:
			var sample:=await visible_resource(self,game,area,kind)
			var id: String=str(sample.get("id",""));check(id!="","真实地图存在可接近且不被界面遮挡的"+kind+"："+area)
			if id=="": continue
			check(await approach_resource(self,game,area,id),"先实走到资源合法站位且不提前采集："+id)
			var field: Node2D=game.resource_world.fields[area];var object: Node2D=field.objects[id]
			var before:=transaction();var hp: int=field.state[id].hp;var executed: int=game.auto_move.execution_count
			GameState.manual_tool=false
			Touch.tap(self,game,visible_click_point(game,object));await Touch.finish(self,game);await frames(20)
			check(field.state[id].hp==hp-1 and GameState.stamina==before.stamina-3 and game.auto_move.execution_count==executed+1,"原生点击只挥一下并准确扣体力："+id)
			await frames(20)
			check(field.state[id].hp==hp-1,"单击等待不自动连砍或重复执行："+id)
			var other_fields_unchanged:=true
			for other in game.resource_world.fields:
				if other==area: continue
				for other_id in game.resource_world.fields[other].state:
					if game.resource_world.fields[other].state[other_id]!=before.resources[other_id]: other_fields_unchanged=false
			check(other_fields_unchanged,"当前图采集不改变同坐标其他地图资源："+id)
			var tool: String=FarmResourceCatalog.TYPES[kind].tool
			GameState.select_tool(GameState.tools.find(tool));GameState.manual_tool=true;GameState.set_control_mode("joystick",false)
			game.player.facing=(object.global_position-game.player.global_position).normalized();game.action_cooldown=0
			var old_hp: int=field.state[id].hp
			Events.action_requested.emit();await frames(20)
			check(field.state[id].hp==old_hp-1,"备用摇杆动作键使用当前地图相同资源："+id)
			GameState.set_control_mode("tap",false)
	await visit(self,game,"home")
	check(game.resource_world.active_field()==null,"室内没有错误沿用上一地图资源场")

func resource_safety() -> void:
	await fresh();await visit(self,game,"mist_forest")
	var id:=first_resource(game,"mist_forest","tree")
	if id=="": check(false,"资源安全探针找到森林树木");return
	await approach_resource(self,game,"mist_forest",id)
	var field: Node2D=game.resource_world.fields.mist_forest
	var before:=transaction()
	check(not field.hit(id,"pickaxe") and transaction()==before,"错误工具整笔拒绝，不扣资源体力")
	GameState.stamina=0;before=transaction()
	check(not field.hit(id,"axe") and transaction()==before,"体力为零不采集、不提前消耗节点")
	GameState.rest()
	for _i in range(2): check(field.hit(id,"axe"),"森林树木实际前置两击")
	Inventory.items.wood=Inventory.MAX_STACK;before=transaction()
	check(not field.hit(id,"axe") and transaction()==before,"材料满堆叠时最后一击不清树、不丢掉落、不扣体力")
	Inventory.items.wood=Inventory.MAX_STACK-4
	var partial_path: String="user://resource-rich-mid-transaction.json"
	var energy_attempts: Array[bool]=[];var inventory_attempts: Array[bool]=[]
	var energy_callback:=func(): energy_attempts.append(FarmSaveStore.write(game,partial_path))
	var inventory_callback:=func(): inventory_attempts.append(FarmSaveStore.write(game,partial_path))
	GameState.changed.connect(energy_callback);Inventory.changed.connect(inventory_callback)
	check(field.hit(id,"axe") and field.state[id].hp==0 and Inventory.count("wood")==Inventory.MAX_STACK,"腾出四份空间后完整获得原木材掉落")
	GameState.changed.disconnect(energy_callback);Inventory.changed.disconnect(inventory_callback)
	check(not energy_attempts.is_empty() and not inventory_attempts.is_empty() and true not in energy_attempts and true not in inventory_attempts and not FileAccess.file_exists(partial_path) and not FileAccess.file_exists(partial_path+".tmp"),"扣体力与入包的同步通知均拒绝保存，不产生半笔资源事务文件")
	var completed:=transaction()
	check(FarmSaveStore.write(game,"user://resource-rich-complete.json") and FarmSaveStore.valid(FarmSaveStore.read("user://resource-rich-complete.json")) and transaction()==completed,"整次采集返回后可正常保存，物品、520计数与钻石均不被保存探针改变")
	before=transaction();check(not field.hit(id,"axe") and transaction()==before,"耗尽节点不可再领取一次木材")
	await frames(4)
	check(field.objects[id].collider.disabled,"采完节点的真实碰撞解除")
	var snap:=FarmSaveStore.snapshot(game);before=transaction()
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snap))),"森林耗尽节点进入原扁平resources存档")
	await visit(self,game,"farm");await visit(self,game,"mist_forest")
	check(transaction()==before,"退出重入和读档不恢复已采树、不复制收益")

func regrowth() -> void:
	await fresh();await visit(self,game,"mist_forest")
	var field: Node2D=game.resource_world.fields.mist_forest
	var ids: Dictionary={}
	for kind in ["tree","rock"]:
		var id:=first_resource(game,"mist_forest",kind);ids[kind]=id
		if id=="": check(false,"再生探针找到"+kind);return
		await approach_resource(self,game,"mist_forest",id)
		for _i in range(int(FarmResourceCatalog.TYPES[kind].hits)): check(field.hit(id,FarmResourceCatalog.TYPES[kind].tool),"按原耐久真实采空："+id)
	var day: int=GameClock.day;var items: Dictionary=Inventory.items.duplicate(true)
	await visit(self,game,"home")
	for elapsed in [1,2,3]:
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"资源再生只依合法夜晚跨天："+str(elapsed));await frames(5)
		check(GameClock.day==day+elapsed and field.state[ids.tree].hp==(3 if elapsed>=3 else 0) and field.state[ids.rock].hp==(2 if elapsed>=2 else 0),"树三日/石二日独立按原配置恢复："+str(elapsed))
		var before: Dictionary=game.resource_world.snapshot();GameClock.day_advanced.emit();await frames(3)
		check(game.resource_world.snapshot()==before and Inventory.items==items,"同日再生日信号不发掉落或重复变状态")
	await visit(self,game,"mist_forest");await approach_resource(self,game,"mist_forest",ids.tree)
	for _i in range(3): field.hit(ids.tree,"axe")
	var object: Node2D=field.objects[ids.tree]
	game.player.global_position=object.global_position;await frames(4)
	for _i in range(3):
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"站在树桩上度过真实再生日期");await frames(4)
	check(field.state[ids.tree].hp==0 and field.objects[ids.tree].collider.disabled,"到期也不在当前玩家脚下生成碰撞")
	await visit(self,game,"home");field.advance_day();await frames(4)
	check(field.state[ids.tree].hp==3 and field.state[ids.tree].ready_day==0,"移至别图后到期资源可安全恢复，不误用其他地图玩家坐标")

func community_materials() -> void:
	await fresh();await visit(self,game,"mist_forest")
	var field: Node2D=game.resource_world.fields.mist_forest
	Inventory.items={"carrot":3}
	check(FarmProgress.accept("first_gift") and FarmProgress.deliver("first_gift") and FarmProgress.accept("river_path"),"沿原村庄委托接取木石需求，不新增奖励规则")
	for kind in ["tree","tree","rock","rock"]:
		var id:=first_resource(game,"mist_forest",kind)
		if id=="": check(false,"委托材料有可采"+kind);return
		await approach_resource(self,game,"mist_forest",id)
		for _i in range(int(FarmResourceCatalog.TYPES[kind].hits)): field.hit(id,FarmResourceCatalog.TYPES[kind].tool)
	check(Inventory.count("wood")==8 and Inventory.count("stone")==6 and FarmProgress.deliver("river_path"),"森林原ID木石能直接用于原村庄委托")
	check(Xiaojing.state.diamonds==1314 and Xiaojing.state.plants==0,"更多资源不会直接增加钻石或伪造520播种")
