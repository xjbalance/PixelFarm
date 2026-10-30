extends "res://tests/runner.gd"
## 农场自由改造：真实采集、再生、全场农活、编辑器与存档。
var initial: Dictionary
var metrics: Dictionary={}
var captures: Array=[]
var capture_mode: bool=false
var save_path: String=""

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	save_path="user://farm-edit-%d.json" % Time.get_ticks_usec()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;game.save_path=save_path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=snapshot()
	await ownership_and_roads()
	await farming_safety()
	await resource_reclamation()
	await hidden_access()
	await art_and_layout()
	var file:=FileAccess.open("res://builds/farm-edit-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"metrics":metrics,"captures":captures,"android_device_tested":false,"platform":DisplayServer.get_name()},"\t"));file.close()
	print("FARM EDIT "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.territory_editor.cancel();game.persistence_enabled=false;game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh() -> void:
	game.territory_editor.cancel();while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,initial),"恢复完整初始农场，不触碰玩家原存档")
	GameClock.running=false;GameWeather.enabled=false;await frames(5)

func begin_edit() -> bool:
	if game.territory_editor.active: return true
	var result: bool=game.territory_editor.open();await frames(4);return result

func paint(kind: String, cell: Vector2i) -> bool:
	if not await begin_edit():
		print("FARM EDIT OPEN DENIED ",kind," ",cell," modal=",GameState.modal," action=",game.player.action_time," active=",game.territory_editor.active)
		return false
	game.territory_editor.choose_tool(kind);game.territory_editor.preview_at(cell);await frames(4)
	var plan: Dictionary=game.territory_editor.preview_plan
	if not plan.get("valid",false): print("FARM EDIT PREVIEW DENIED ",kind," ",cell," ",plan)
	var accepted: bool=plan.get("valid",false) and game.territory_editor.confirm()
	if not accepted and plan.get("valid",false): print("FARM EDIT CONFIRM DENIED ",kind," ",Territory.last_error)
	return accepted

func coverage() -> Dictionary:
	var ground: int=0;var solid: int=0
	var protected_ground: Dictionary=game.territory_world.protected_cells("farm","grass")
	var protected_solid: Dictionary=game.territory_world.protected_cells("farm","fence")
	for y in range(64):
		for x in range(96):
			var cell:=Vector2i(x,y)
			if Territory.permission("farm",cell,"grass").allowed and not protected_ground.has(cell): ground+=1
			if Territory.permission("farm",cell,"fence").allowed and not protected_solid.has(cell): solid+=1
	return {"map_cells":6144,"interior_cells":6144,"legacy_interior_cells":1380,"ground_cells":ground,"ground_fraction":float(ground)/6144.0,"ground_interior_fraction":float(ground)/6144.0,"solid_cells":solid,"solid_fraction":float(solid)/6144.0,"solid_interior_fraction":float(solid)/6144.0,"basis":"Territory.permission and runtime occupied cells; final placement also checks collision and routes"}

func ownership_and_roads() -> void:
	metrics.initial=coverage()
	check(metrics.initial.ground_fraction>=.65,"初始存活资源仍保留时，农场多数地格已可改造："+str(metrics.initial))
	for cell in [Vector2i(20,2),Vector2i(14,20),Vector2i(11,13),Vector2i(17,16)]:
		check(Territory.plan_terrain("farm",[cell],"grass").valid,"旧大矩形内的空地、路面和未开垦田可重铺："+str(cell))
	check(await paint("stone_path",Vector2i(14,20)),"真实编辑器可在原纵向道路重新铺路")
	check(await paint("sand",Vector2i(20,2)) and await paint("gravel",Vector2i(21,2)),"沙地与碎石素材经确认写入农场")
	await capture("wide_farm_terrain");game.territory_editor.cancel()
	await frames(4) # 最后一次确认的TileMap/碰撞先同步，再发起下一次真实预览。
	for cell in [Vector2i(20,11),Vector2i(34,18),Vector2i(0,10)]:
		var preview:=Territory.plan_terrain("farm",[cell],"grass")
		check(preview.valid,"自家房屋下方地表、原水域及边缘内圈均允许重铺："+str(cell)+" / "+str(preview.reason))
	for cell in [Vector2i(-1,10),Vector2i(96,10),Vector2i(0,-1),Vector2i(10,64)]:
		check(not Territory.plan_terrain("farm",[cell],"grass").valid and not Territory.plan_place("farm","fence",cell).valid,"真正超出96×64农场的地表和物件仍拒绝："+str(cell))
	check(await paint("grass",Vector2i(34,18)),"原有水域通过真实确认填为陆地")
	await frames(4);game.territory_editor.cancel()
	check(game.world.ground.get_cell_atlas_coords(Vector2i(34,18)).x==0 and game.world.ground.get_cell_tile_data(Vector2i(34,18)).get_collision_polygons_count(0)==0,"填水同步移除原水瓦片碰撞，没有只盖一层草色")
	game.player.position=Vector2(720,592);await frames(4)
	check(not Territory.plan_place("farm","fence",Vector2i(20,13)).valid,"房门真实站位不能堵住")
	check(not Territory.plan_terrain("village",[Vector2i(11,13)],"stone_path").valid and not Territory.plan_place("abyss","lamp",Vector2i(8,8)).valid,"自由改造只扩展自己的农场，公共及地下权限不变")
	var field: Node=game.resource_world.fields.farm
	var depleted: Dictionary=field.state.duplicate(true)
	for id in depleted: depleted[id]={"hp":0,"ready_day":GameClock.day+3}
	field.restore(depleted);await frames(4);metrics.cleared=coverage()
	check(metrics.cleared.ground_fraction>=.80 and metrics.cleared.ground_cells>metrics.initial.ground_cells,"正常清理资源后可改造面积继续增加，无永久大片禁区："+str(metrics.cleared))

func farming_safety() -> void:
	await fresh()
	var cell:=Vector2i(17,16)
	check(await paint("stone_path",cell),"尚未开垦的原田格可以作为自己规划的道路")
	game.territory_editor.cancel();var stamina: int=GameState.stamina
	check(not game.farm.use_tool(cell,"hoe") and GameState.stamina==stamina,"道路上的误耕有明确提示，不扣体力")
	check(await paint("natural",cell),"恢复自然后解除景观地表的耕种阻挡")
	game.territory_editor.cancel();check(game.farm.use_tool(cell,"hoe"),"原60格通过相同农活事务开垦，体力与作物规则保留")
	check(not Territory.plan_terrain("farm",[cell],"grass").valid and not Territory.plan_place("farm","flowers",cell).valid,"真实翻土记录不能被景观或物件覆盖")
	check(not game.territory_editor.open(),"原农活动画完成前不能进入建造，避免中断已提交动作")
	await frames(20)
	var second:=Vector2i(18,16);check(await paint("soil",second),"空地可预览景观翻土")
	game.territory_editor.cancel();check(game.farm.use_tool(second,"hoe") and not Territory.state.terrain.get("farm",{}).has("18,16"),"真正开垦时移除兼容景观覆盖，避免双份土地状态")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)) and game.farm.can_use_tool(Vector2i(22,5),"hoe",false) and not game.farm.can_use_tool(Vector2i(5,8),"hoe",false),"全场空地可继续正常开垦，活资源仍阻止误耕且存档兼容")

func resource_reclamation() -> void:
	await fresh()
	var id: String="tree_5_8";var field: Node=game.resource_world.fields.farm;var cell:=Vector2i(5,8)
	check(not Territory.plan_terrain("farm",[cell],"grass").valid,"活体采集树的真实脚底仍需先用原斧头处理")
	game.player.position=Vector2(200,256);game.player.facing=Vector2.LEFT;GameState.select_tool(6);await frames(4)
	var wood: int=Inventory.count("wood")
	for _i in range(3): game.interact();await frames(20)
	check(field.state[id].hp==0 and Inventory.count("wood")==wood+4,"原采集交互正常砍尽树木且只获得原4木材")
	var ready_day: int=field.state[id].ready_day
	check(await paint("stone_path",cell) and Territory.resource_edited(id),"采尽后可以改造原树木脚底，不再永久封锁资源位置")
	game.territory_editor.cancel();await capture("cleared_tree_path")
	game.change_location("village");await frames(5)
	for _i in range(3): GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"沿原睡眠系统推进一日");await frames(4)
	check(field.state[id].hp==0 and field.state[id].ready_day==ready_day and Inventory.count("wood")==wood+4,"离图跨过再生日也不从道路里长树，不复制木材或改再生日期")
	check(FarmSaveStore.write(game,save_path),"已采集点改造与原资源日期写入现有存档")
	var expected: Dictionary=canonical(FarmSaveStore.read(save_path));check(not expected.is_empty() and expected.resources[id].hp==0,"存档保留采集耗尽状态，不伪造新奖励")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=save_path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9);game.persistence_enabled=false
	field=game.resource_world.fields.farm
	check(snapshot()==expected and Territory.resource_edited(id) and not field.objects[id].can_regrow(),"独立主场景重建恢复道路并继续抑制原点再生")
	game.change_location("farm",Vector2(200,256));await frames(5)
	check(await paint("natural",cell) and not Territory.resource_edited(id),"恢复自然并清空地面也不复活已清理树木")
	game.territory_editor.cancel();game.change_location("village");await frames(4);GameClock.minutes=1200
	check(GameClock.request_sleep(GameClock.day),"再次推进正式一天")
	await frames(4)
	check(field.state[id].hp==0 and field.state[id].ready_day==0 and Inventory.count("wood")==wood+4,"恢复自然地面后仍保持永久清理，不恢复树木或发资源")

func hidden_access() -> void:
	await fresh();game.player.position=Vector2(720,592);game.camera_rig.follow_now();await frames(4)
	var spring: Node
	for node in get_tree().get_nodes_in_group("interactables"):
		if game.world.is_ancestor_of(node) and "festival_id" in node and node.festival_id=="spring": spring=node;break
	check(is_instance_valid(spring),"实际农场存在春季活动的原入口")
	if not is_instance_valid(spring): return
	spring.hide();check(await begin_edit(),"隐藏场地通路检查进入真实编辑器")
	game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.path_to({"kind":"object","object":spring,"point":spring.global_position}).is_empty(),"开始围栏探针前，隐藏活动点确实可达")
	var perimeter: Array[Vector2i]=[]
	for x in range(26,29): perimeter.append(Vector2i(x,14));perimeter.append(Vector2i(x,17))
	for y in range(15,17): perimeter.append(Vector2i(26,y));perimeter.append(Vector2i(28,y))
	var denied: bool=false;var accepted: int=0
	for at in perimeter:
		var plan:=Territory.plan_place("farm","fence",at)
		if not plan.valid:
			denied=true;metrics.hidden_route_denial=plan.reason;break
		check(Territory.apply_plan(plan),"确认仍保留通路的围栏预览")
		accepted+=1
		await frames(4)
	game.auto_move.navigation.rebuild()
	check(denied and accepted>0 and not game.auto_move.navigation.path_to({"kind":"object","object":spring,"point":spring.global_position}).is_empty(),"隐藏活动点不能被完整围死，拒绝后实际路径仍然可达")
	metrics.hidden_route_accepted_fences=accepted
	game.territory_editor.cancel()

func art_and_layout() -> void:
	await fresh()
	var arts: Dictionary={};var all_native: bool=true
	# 原89款授权景观资源的来源检查；生产设备使用本轮原创目录。
	for kind in TerritoryCatalog.BASE_OBJECT_KINDS:
		var definition: Dictionary=TerritoryCatalog.OBJECT_KINDS[kind];var art: String=str(definition.art);arts[art]=true
		all_native=all_native and not SchemeCAssets.definition(art).is_empty() and game.territory_world.object_texture(str(kind))!=null
	check(all_native and arts.size()==89,"89款唯一源物件均可实际选用，旧kind身份保持兼容")
	check(TerritoryCatalog.OBJECT_KINDS.oak_tree.size==[1,1] and TerritoryCatalog.OBJECT_KINDS.pine_tree.size==[1,1],"树冠保持原生画布，实体仅占合理树干格")
	check(TerritoryCatalog.OBJECT_KINDS.wood_crate.storage and TerritoryCatalog.OBJECT_KINDS.chest.storage,"两种箱子均明确复用住宅同一份收纳")
	check(await begin_edit(),"素材分组界面正常打开")
	var editor: TerritoryEditor=game.territory_editor;editor.choose_category("objects")
	for _i in range(12):
		if editor.subgroup=="water": break
		editor.cycle_group()
	check(editor.subgroup=="water" and editor.tool_buttons.has("large_pond") and not editor.tool_buttons.has("wood_fence"),"点击分组将长清单缩为实际水景素材，不混入围栏")
	await capture("asset_groups")
	for kind in ["wood_fence","stone_wall","hedge_fence","wood_fence_vertical","stone_wall_vertical","hedge_fence_vertical"]:
		var rect:=TerritoryCatalog.footprint(kind,Vector2i.ZERO)
		check(game.territory_world.object_texture(kind).get_size()==Vector2(rect.size)*32,"围栏使用32原生模块连续拼接而非拉伸："+kind)
	for extent in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(5);editor.layout_panel();await frames(3)
		var bounds: Rect2=game.hud.safe.get_global_rect();var good: bool=bounds.grow(.5).encloses(editor.palette.get_global_rect()) and bounds.grow(.5).encloses(editor.panel.get_global_rect())
		for button in [editor.group_button,editor.confirm_button,editor.cancel_button,editor.discard_button]: good=good and bounds.grow(.5).encloses(button.get_global_rect())
		check(good and not editor.panel.get_global_rect().intersects(editor.palette.get_global_rect()),"分组、确认和观察按钮适配横屏且不重叠："+str(extent))
	get_window().size=Vector2i(1280,720);await frames(4)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	editor.layout_panel();await frames(5)
	check(game.hud.safe.get_global_rect().grow(.5).encloses(editor.palette.get_global_rect()) and game.hud.safe.get_global_rect().grow(.5).encloses(editor.panel.get_global_rect()) and editor.confirm_button.size.y>=96,"高DPI触区放大时完整保留分组清单和确认区")
	UIMetrics.screen_provider=Callable();editor.cancel()

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/farm-edit-"+label+".png";get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
