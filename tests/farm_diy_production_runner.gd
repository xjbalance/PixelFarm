extends "res://tests/runner.gd"
## Production land/resource relocation retains the existing crop and gathering rules.
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary={}
var observed: Array=[]
var captures: Array=[]
var capture_mode: bool=false

func run() -> void:
	capture_mode="--capture-diy-production" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	Events.farm_committed.connect(record_action)
	await crop_layout()
	await resource_layout()
	await real_water()
	check(FarmSaveStore.restore(game,original),"全部DIY生产探针后恢复初始完整存档")
	await frames(6)
	check(game.resource_world.snapshot()==original.resources and game.farm.plots==original.plots and FarmLayout.snapshot()==original.farm_layout,"原资源、作物和布局逐字段恢复，不遗留夹具")
	var report:=FileAccess.open("res://builds/farm-diy-production-"+("render" if DisplayServer.get_name()!="headless" else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"save_version":FarmSaveStore.VERSION,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));report.close()
	print("FARM DIY PRODUCTION RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func record_action(action: String, logical: Vector2i, crop: String, serial: int) -> void:
	observed.append({"action":action,"logical":logical,"crop":crop,"serial":serial})

func fresh() -> void:
	game.territory_editor.cancel()
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,original),"恢复隔离的原始农场")
	GameClock.running=false;GameWeather.enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	observed.clear();await frames(7)

func edit() -> bool:
	await frames(20)
	if not game.territory_editor.active: check(game.territory_editor.open(),"在真实农场建造模式中确认布局")
	await frames(3)
	return game.territory_editor.active

func layout(kind: String, id: String, operation: String, at: Vector2i=Vector2i.ZERO) -> bool:
	if not await edit(): return false
	var plan: Dictionary=FarmLayout.plan_move(kind,id,at) if operation=="move" else FarmLayout.plan_store(kind,id) if operation=="store" else FarmLayout.plan_restore(kind,id,at)
	check(plan.valid,"布局预览合法："+kind+"/"+id+"/"+operation+" "+str(plan.reason))
	if not plan.valid: game.territory_editor.cancel();return false
	var accepted: bool=FarmLayout.apply_plan(plan)
	check(accepted,"一次确认提交布局："+kind+"/"+id+"/"+operation)
	await frames(5);game.territory_editor.cancel();await frames(3)
	return accepted

func crop_layout() -> void:
	await fresh()
	var logical:=Vector2i(20,18);var moved:=Vector2i(22,5);var placed:=Vector2i(24,6)
	Inventory.items.carrot_seed=10;GameState.rest();await frames(2)
	check(game.farm.use_tool(logical,"hoe") and game.farm.use_tool(logical,"carrot_seed"),"原地块依旧使用原翻土和播种事务")
	var crop: Dictionary=game.farm.plots["20,18"].duplicate(true)
	var quantity: int=Inventory.count("carrot_seed");var stamina: int=GameState.stamina;var serial: int=int(Xiaojing.state.plant_serial)
	if not await layout("plot","20,18","move",moved): return
	check(game.farm.plots.has("20,18") and not game.farm.plots.has("22,5") and game.farm.plot_at(moved)==crop,"移动保留旧逻辑ID和完整作物，只改变物理位置")
	check(game.farm.logical_cell(moved)==logical and game.farm.world_origin(logical)==Vector2(moved)*32 and game.farm.plot_at(logical).is_empty(),"双向坐标映射和绘制位置一致，原地点不再读到旧作物")
	check(Inventory.count("carrot_seed")==quantity and GameState.stamina==stamina and int(Xiaojing.state.plant_serial)==serial,"移动不重新播种，不扣种子体力、不增加520进度")
	GameState.manual_tool=false
	check(not game.farm.can_target_cell(Vector2i(22,6)),"普通地图点击不会因为全场可开垦而自动挖地")
	GameState.select_tool(GameState.tools.find("hoe"));GameState.manual_tool=true
	check(game.farm.can_target_cell(Vector2i(22,6)),"显式选锄头后可选原60格外的新地")
	GameState.manual_tool=false
	var before_energy: int=GameState.stamina
	check(game.farm.use_tool(Vector2i(22,6),"hoe") and GameState.stamina==before_energy-Kitchen.energy_cost(2),"原60格外新建真实生产田，仍只扣原翻土体力")
	check(game.farm.plots.has("22,6") and game.farm.plot_at(Vector2i(22,6)).get("crop")=="","新地优先采用空闲的原坐标ID")
	check(game.farm.use_tool(logical,"hoe"),"旧ID已移动后，原物理位置可以重新开垦")
	var replacement: Vector2i=game.farm.logical_cell(logical)
	check(replacement!=logical and replacement!=game.farm.INVALID_CELL and game.farm.plot_at(moved)==crop and game.farm.plots.size()==3,"重新开垦分配另一唯一ID，不覆盖已移动的作物")
	check(FarmLayout.cell("plot",TerritoryCatalog.key(replacement))==logical,"新逻辑ID登记原物理位置，读档可还原")
	game.player.position=Vector2(moved)*32+Vector2(16,50);game.auto_move.cancel();game.camera_rig.follow_now();await frames(7)
	GameState.select_tool(GameState.tools.find("water"));GameState.manual_tool=true
	Touch.tap(self,game,Vector2(moved)*32+Vector2(16,16));await Touch.finish(self,game);await frames(20)
	check(game.farm.plots["20,18"].watered and observed[-1].logical==logical and observed[-1].action=="浇水","实际触摸移动后的田地，工具动作只提交到原逻辑ID")
	game.farm.plots["20,18"].days=1
	var stored_crop: Dictionary=game.farm.plots["20,18"].duplicate(true)
	if not await layout("plot","20,18","store"): return
	check(game.farm.plot_at(moved).is_empty() and game.farm.plots["20,18"]==stored_crop,"带作物收纳保留成长和浇水状态，不复制或退款")
	GameClock.day+=1;game.farm.advance_day();GameClock.day+=1;game.farm.advance_day()
	check(game.farm.plots["20,18"]==stored_crop,"收纳期间暂停成长，完整保留作物状态")
	if not await layout("plot","20,18","restore",placed): return
	check(game.farm.plot_at(placed)==stored_crop and not FarmLayout.stored("plot","20,18"),"放回种植地继续使用同一作物记录")
	GameClock.day+=1;game.farm.advance_day()
	check(int(game.farm.plots["20,18"].days)==2 and not game.farm.plots["20,18"].watered,"放回后的次日遵循原成长与清除浇水规则")
	await capture("relocated_crops",Vector2(752,320))
	game.farm.plots["20,18"].days=Catalog.crops.carrot.growth_days
	var harvested: int=Inventory.count("carrot")
	check(game.farm.use_tool(placed,"hand") and Inventory.count("carrot")==harvested+1 and observed[-1].logical==logical,"移动后成熟作物仍只产出原来的一份，证明使用原ID")
	FarmProgress.built.append("irrigation")
	check(game.farm.use_tool(Vector2i(17,16),"hoe"),"原灌溉权益地块正常开垦")
	if not await layout("plot","17,16","move",Vector2i(22,7)): return
	game.farm.plots["17,16"].watered=false;game.farm.apply_irrigation()
	check(game.farm.plots["17,16"].watered,"原12格灌溉权益随逻辑地块移动")
	if not await layout("plot","22,6","move",Vector2i(18,16)): return
	game.farm.plots["22,6"].watered=false;game.farm.apply_irrigation()
	check(not game.farm.plots["22,6"].watered,"占原灌溉位置不会复制额外灌溉权益")
	GameClock.changed.emit();await frames(5)
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"新地、搬迁、收纳与新增逻辑ID通过完整存档恢复")
	await frames(6)
	check(game.farm.logical_cell(placed)==logical and game.farm.plots.size()==4,"读档保留全部原和新生产田，不重置映射")

func resource_layout() -> void:
	await fresh()
	var field: Node=game.resource_world.fields.farm;var id: String="tree_5_8";var node: Node=field.objects[id]
	var before_wood: int=Inventory.count("wood")
	check(field.hit(id,"axe") and int(field.state[id].hp)==2,"原资源先受一次伤，维持原耐久规则")
	var hp: Dictionary=field.state[id].duplicate(true);var stamina: int=GameState.stamina
	if not await layout("resource",id,"move",Vector2i(22,5)): return
	check(field.objects[id]==node and node.position==Vector2(704,160) and field.state[id]==hp and GameState.stamina==stamina,"移动只重定位原节点，保留半损耐久与体力")
	game.auto_move.navigation.rebuild()
	check(game.auto_move.navigation.walkable(Vector2i(4,7)) and not game.auto_move.navigation.walkable(Vector2i(21,4)),"资源移动清除旧碰撞并在新位置更新原导航")
	check(field.hit(id,"axe") and field.hit(id,"axe") and Inventory.count("wood")==before_wood+4,"移动后的剩余两次采集只结算原一份木材")
	var cleared: Dictionary=field.state[id].duplicate(true)
	if not await layout("resource",id,"store"): return
	check(not node.visible and node.collision_layer==0 and field.state[id]==cleared,"收纳隐藏同一节点与碰撞，不重置再生日期")
	var inventory: Dictionary=Inventory.items.duplicate(true);stamina=GameState.stamina
	check(not field.hit(id,"axe") and Inventory.items==inventory and GameState.stamina==stamina,"收纳资源不能再采，不扣体力也不产生物品")
	GameClock.day=int(cleared.ready_day);field.advance_day()
	check(field.state[id]==cleared,"收纳期间到再生日也不会刷新耐久供重复采集")
	if not await layout("resource",id,"restore",Vector2i(23,5)): return
	check(field.state[id]==cleared and field.objects[id]==node,"放回只复用旧资源，不借确认操作再生或复制")
	if not await edit(): return
	var suppressed:=Territory.plan_terrain("farm",[Vector2i(23,4)],"grass")
	check(suppressed.valid and Territory.apply_plan(suppressed),"新坐标上的草地装修仍可抑制已采集资源恢复")
	await frames(5);game.territory_editor.cancel()
	GameClock.day+=1;field.advance_day()
	check(field.state[id]==cleared,"草地抑制按移动后的脚底检查，不再读取旧资源格")
	if not await edit(): return
	var natural:=Territory.plan_terrain("farm",[Vector2i(23,4)],"natural")
	check(natural.valid and Territory.apply_plan(natural),"恢复自然地表后重新允许原资源按日期恢复")
	await frames(5);game.territory_editor.cancel()
	GameClock.day+=1;field.advance_day();await frames(5)
	check(int(field.state[id].hp)==3 and int(field.state[id].ready_day)==0 and Inventory.items==inventory,"放回后在正常日更新恢复，不自动发放材料")
	check(game.resource_world.snapshot().size()==128 and field.objects.size()==42,"三图仍128个资源ID，农场仍原42个生产节点")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved) and FarmSaveStore.restore(game,saved),"已移动资源的耐久、日期和位置通过完整存档恢复")
	await frames(5)
	check(node.position==Vector2(736,160) and field.state[id].hp==3,"读取后原实例对应正确新坐标，不生成第二棵树")
	await capture("relocated_resource",Vector2(736,320))

func real_water() -> void:
	await fresh()
	var cell:=Vector2i(22,5)
	check(FarmTerrain.effective_index(cell) not in [5,6],"测试新水域的原地确实为干地")
	if not await edit(): return
	var plan:=Territory.plan_terrain("farm",[cell],"water")
	check(plan.valid and Territory.apply_plan(plan),"真实建造确认在干地开挖水域："+str(plan.reason))
	await frames(6);game.territory_editor.cancel();game.auto_move.navigation.rebuild()
	check(game.world.ground.get_cell_atlas_coords(cell).x==5 and game.world.ground.get_cell_tile_data(cell).get_collision_polygons_count(0)==1 and not game.auto_move.navigation.walkable(cell),"水域实际替换原TileMap瓦片并阻挡原导航")
	check(not game.farm.can_use_tool(cell,"hoe",false),"水域不能被普通锄头直接种成作物")
	var before: Image=game.world.get_node("GroundDetail06").ground_detail.texture.get_image()
	await capture("new_water",Vector2(736,320))
	if not await edit(): return
	plan=Territory.plan_terrain("farm",[cell],"grass")
	check(plan.valid and Territory.apply_plan(plan),"填水恢复陆地使用相同原子地表接口")
	await frames(6);game.territory_editor.cancel();game.auto_move.navigation.rebuild()
	var after: Image=game.world.get_node("GroundDetail06").ground_detail.texture.get_image()
	check(game.world.ground.get_cell_atlas_coords(cell).x==0 and game.world.ground.get_cell_tile_data(cell).get_collision_polygons_count(0)==0 and game.auto_move.navigation.walkable(cell),"填水同步移除真实水碰撞并恢复可走格")
	var sample:=cell*32+Vector2i(16,16)
	check(before.get_pixelv(sample)!=after.get_pixelv(sample),"实际缓存像素从水面改为陆地，未残留旧池塘图层")
	check(game.farm.use_tool(cell,"hoe"),"填好的干地可以新建真实生产田")
	var old_water:=Vector2i(34,18)
	check(FarmTerrain.base_index(old_water) in [5,6],"原湖中心仍是可复现的默认水域")
	if not await edit(): return
	plan=Territory.plan_terrain("farm",[old_water],"grass")
	check(plan.valid and Territory.apply_plan(plan),"原有湖水同样可以填成陆地："+str(plan.reason))
	await frames(6);game.territory_editor.cancel()
	check(game.farm.use_tool(old_water,"hoe"),"原湖填土后也能建立生产田")
	await frames(6)
	check(FarmTerrain.effective_index(old_water) not in [5,6] and game.world.ground.get_cell_atlas_coords(old_water).x not in [5,6],"开垦不会擦掉填湖基底而让水碰撞重新出现")
	var offset:=Vector2(-256,0)
	check(FarmTerrain.effective_index(Vector2i(26,18),{},offset,true) in [5,6] and FarmTerrain.effective_index(Vector2i(34,18),{},offset,true) not in [5,6],"候选湖偏移只移动原水域，不残留旧水格")
	check(FarmTerrain.effective_index(Vector2i(34,18),{},Vector2.ZERO,false) not in [5,6],"收纳原湖时其默认水域恢复自然底地")
	var dry: Texture2D=FarmTerrain.texture(Calendar.season(),{},offset,true)
	check(dry.get_size()==Vector2(1536,1024),"移动湖泊按有效地形重绘全尺寸地图，旧PNG没有幽灵水域")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved) and FarmSaveStore.restore(game,saved),"水陆变化与新建生产田共同保存、恢复")
	await frames(5)
	check(not game.farm.plot_at(old_water).is_empty() and game.world.ground.get_cell_atlas_coords(old_water).x not in [5,6],"读档后原湖上的新田仍是干地，不把玩家或作物关进水里")
	await capture("filled_water_and_crop",Vector2(736,320))

func capture(label: String, center: Vector2) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	GameClock.minutes=720;GameClock.changed.emit()
	for weather in get_tree().get_nodes_in_group("weather_screens"):
		weather.banner_time=0;weather.fade=0;weather.queue_redraw()
	game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK;game.camera_rig.view_center=game.camera_rig.clamp_center(center);game.camera_rig.apply_camera()
	game.hud.toast_time=0;await frames(5);await RenderingServer.frame_post_draw
	var path: String="res://builds/farm-diy-production-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
