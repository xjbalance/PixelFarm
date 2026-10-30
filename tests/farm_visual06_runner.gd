extends "res://tests/runner.gd"
## 农场视觉样板：真实地图物理/玩法，不改玩家存档。--capture才采集实际窗口。
const Touch=preload("res://tests/touch_navigation.gd")
const Rich=preload("res://tests/resource_rich_runner.gd")
@export var capture_mode: bool=false
var captures: Array=[]
var original: Dictionary

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	await visuals_and_routes()
	await farming_and_resources()
	if capture_mode: await render_sample()
	check(FarmSaveStore.restore(game,original),"视觉样板后原完整存档可恢复")
	await frames(6)
	check(game.farm.plots==original.plots and game.resource_world.snapshot()==original.resources and Housing.snapshot()==original.housing,"旧农田ID、资源耐久/再生和住宅进度完全保留")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"仍为当前有效存档，无视觉专属进度字段")
	var report:=FileAccess.open("res://builds/farm06-"+("render" if capture_mode else "state")+"-evidence.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"platform":DisplayServer.get_name(),"android_device_tested":false,"captures":captures,"farm_cells":6144,"plots":60,"farm_resources":109,"save_version":FarmSaveStore.VERSION},"\t"));report.close()
	print("FARM VISUAL 06 "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func visuals_and_routes() -> void:
	var visual: Node=game.world.get_node("GroundDetail06")
	check(visual is FarmVisual06 and visual.ground_detail.texture.get_size()==FarmLayoutCatalog.WORLD.size and visual.get_child_count()==1,"3072x2048原生像素底图只有一个缓存Sprite，无逐帧地形扫描")
	check(visual.z_index==-4 and game.world.ground.z_index==-5 and game.farm.z_index==-1 and game.world.actors.y_sort_enabled,"Ground/Detail/作物/实体Y排序分层保持正确")
	var cells: Array[Vector2i]=game.world.ground.get_used_cells();var expected:=true
	for cell in cells:
		var kind: int=game.world.ground.get_cell_atlas_coords(cell).x
		var original_kind: int=0
		if cell.y in [13,14] or (cell.x in [14,15] and cell.y>5): original_kind=3
		if Rect2i(16,15,12,8).has_point(cell): original_kind=4
		if not Rect2i(0,0,48,32).has_point(cell) and ((cell.x in [62,63] and cell.y>=14) or (cell.y in [42,43] and cell.x>=14)): original_kind=3
		var pond: float=Vector2(cell-Vector2i(34,18)).length()
		if pond<4.8: original_kind=3
		if pond<4.1: original_kind=5
		if pond<2.9: original_kind=6
		if original_kind==0: expected=expected and kind in [0,1,2]
		else: expected=expected and kind==original_kind
		var data: TileData=game.world.ground.get_cell_tile_data(cell)
		expected=expected and data.get_collision_polygons_count(0)==(1 if kind in [5,6] else 0)
	check(cells.size()==6144 and expected,"全部6144地形格、水碰撞与原坐标类型逐格完全一致")
	game.auto_move.navigation.rebuild()
	for y in range(16,22):
		for x in range(17,27):
			var cell:=Vector2i(x,y);var point:=Vector2(cell)*32+Vector2(16,16)
			check(not game.auto_move.navigation.path_to({"kind":"plot","cell":cell,"point":point}).is_empty(),"原60块可种农田仍可达："+str(cell))
	for id in FarmResourceCatalog.placements("farm"):
		var object: Node2D=game.world.resource_field.objects[id]
		var target: Node2D=game.world.resource_field.access_target(object)
		check(not game.auto_move.navigation.path_to({"kind":"resource","object":target,"point":target.global_position}).is_empty(),"农场资源或其合法清除前置仍可达："+id)
	check(visual.trees.size()==50,"原30棵与新增20棵树均使用真实可砍伐节点")
	var physics: Dictionary=game.auto_move.navigation.static_solid.duplicate()
	var season_pixels: Dictionary={}
	for season in range(4):
		GameClock.day=season*28+1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(3)
		check(visual.applied_season==season and visual.ground_detail.get_meta("season",-1)==season and visual.ground_detail.texture.get_size()==FarmLayoutCatalog.WORLD.size and visual.trees[0].texture.resource_path.contains("/world_scheme_c/seasons/"),"四季有效地形缓存与原生树木同步，不依赖固定PNG路径："+str(season))
		season_pixels[hash(visual.ground_detail.texture.get_image().get_data())]=true
		game.auto_move.navigation.invalidate();await frames(3);game.auto_move.navigation.rebuild()
		check(game.auto_move.navigation.static_solid==physics,"换季只换图，物理导航格不变化："+str(season))
	check(season_pixels.size()==4,"四季地形缓存实际像素各不相同，未只切换季节标记")
	check(FarmSaveStore.restore(game,original),"季节视觉夹具恢复原进度")
	await frames(5)
	var home_point: Node2D
	for point in get_tree().get_nodes_in_group("interactables"):
		if "kind" in point and point.kind=="home": home_point=point;break
	check(home_point!=null and not game.auto_move.navigation.path_to({"kind":"object","object":home_point,"point":home_point.global_position}).is_empty(),"住宅门口原入口合法站位仍可达")
	if home_point:
		game.auto_move.request_target({"kind":"object","object":home_point,"point":home_point.global_position});await Touch.finish(self,game)
		check(GameState.location=="home","沿真实自动路径可进入住宅")
		game.change_location("farm",Vector2(656,438));await frames(6)

func farming_and_resources() -> void:
	GameState.rest();Inventory.items.carrot_seed=5
	var cell:=Vector2i(20,18)
	check(game.farm.use_tool(cell,"hoe"),"原工具事务正常翻土")
	check(game.farm.use_tool(cell,"carrot_seed"),"原播种扣种事务正常")
	check(game.farm.use_tool(cell,"water") and game.farm.plots["20,18"].watered,"湿土纹理及时跟随原浇水状态")
	game.farm.plots["20,18"].days=Catalog.crops.carrot.growth_days
	var held: int=Inventory.count("carrot")
	check(game.farm.use_tool(cell,"hand") and Inventory.count("carrot")==held+1,"成熟夹具按原收获事务入包一次")
	check(not game.farm.use_tool(cell,"hand") and Inventory.count("carrot")==held+1,"新视觉未增加重复收获结算")
	for kind in ["tree","rock"]:
		var id:=Rich.first_resource(game,"farm",kind)
		check(id!="" and await Rich.approach_resource(self,game,"farm",id),"真实行走靠近可采集目标："+kind)
		if id=="": continue
		var field: Node2D=game.world.resource_field;var definition: Dictionary=FarmResourceCatalog.TYPES[kind]
		var before: int=Inventory.count(definition.item)
		for hit in range(int(definition.hits)):
			GameState.rest();check(field.hit(id,definition.tool),"原采集工具成功："+kind+str(hit))
		await frames(4)
		check(field.state[id].hp==0 and Inventory.count(definition.item)==before+int(definition.amount) and not field.objects[id].sprite.visible,"采完取消显示和碰撞，掉落数量沿原规则："+kind)
		game.auto_move.navigation.rebuild();var at: Vector2=field.objects[id].global_position
		check(not game.auto_move.navigation.path_to({"kind":"ground","point":at}).is_empty(),"清除资源后原位置可通行："+kind)
		game.player.global_position=Vector2(656,491);GameClock.day+=3;field.advance_day();await frames(4)
		game.auto_move.navigation.rebuild()
		# 树石脚底位于32px交点，实体上半格才是其实际阻挡格，不把右下格误作脚底。
		check(field.state[id].hp==0 and not field.objects[id].sprite.visible and field.objects[id].collider.disabled and not game.auto_move.navigation.static_solid.has(game.auto_move.navigation.cell(at-Vector2.ONE)),"农场跨日仍清理完成，不恢复实体或导航阻挡："+kind)
	check(FarmSaveStore.restore(game,original),"采集测试恢复原资源与钱物")
	await frames(4)

func render_sample() -> void:
	game.hud.toast_time=0;game.hud.toast.hide()
	await frames(180) # 等真实转场/地点横幅结束，再记录可比较的稳定画面。
	for item in [["home",Vector2(656,410)],["plots",Vector2(704,608)],["road",Vector2(470,432)]]:
		game.player.global_position=item[1];game.camera_rig.follow_now();await frames(8);await capture(str(item[0]))
	await panorama("panorama")
	for y in range(16,22):
		for x in range(17,27):
			if x in [20,21]: continue
			var crop: String=["carrot","potato","wheat"][(x-17)%3]
			game.farm.plots[game.farm.key(Vector2i(x,y))]={"crop":crop,"days":mini((y-16),Catalog.crops[crop].growth_days),"watered":(x+y)%3!=0}
	game.farm.queue_redraw()
	for season in range(4):
		GameClock.day=season*28+1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(6)
		await panorama("season_"+FarmVisual06.SEASONS[season])
	GameClock.day=1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	game.player.global_position=Vector2(704,608);game.camera_rig.follow_now();await frames(6);await capture("crops_detail")
	for level in range(1,5):
		Housing.state.level=level;Housing.state.builtins=HomeLayout.default_builtins(level);Housing.changed.emit();await frames(5)
		var exterior: Sprite2D
		for sprite in game.world.find_children("*","Sprite2D",true,false):
			if sprite.texture and sprite.texture.resource_path.contains("/exterior_"): exterior=sprite;break
		check(exterior!=null and exterior.texture.resource_path.ends_with("exterior_%d.png" % level),"农场样板显示正确住宅等级外观："+str(level))
		game.player.global_position=Vector2(656,410);game.camera_rig.follow_now();await frames(6);await capture("house_level_"+str(level))
	for resolution in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(8);game.camera_rig.follow_now();await frames(3)
		check(game.world.get_node("GroundDetail06").ground_detail.texture.get_size()==FarmLayoutCatalog.WORLD.size and game.hud.safe.size.x>0,"横屏实际窗口农场原像素底图正确："+str(resolution))
		await capture("layout_"+str(resolution.x)+"x"+str(resolution.y))

func panorama(label: String) -> void:
	game.camera_rig.set_physics_process(false);game.player.get_node("Camera2D").zoom=Vector2(.7,.7)
	game.player.get_node("Camera2D").global_position=Vector2(768,512);game.player.get_node("Camera2D").force_update_scroll();game.hud.root.hide();await frames(6)
	await capture(label)
	game.hud.root.show();game.player.get_node("Camera2D").zoom=Vector2.ONE;game.camera_rig.set_physics_process(true);game.camera_rig.follow_now();await frames(3)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://builds/farm06-after-"+label+".png";get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"resolution":[get_window().size.x,get_window().size.y],"season":Calendar.season(),"house_level":int(Housing.state.level)})
