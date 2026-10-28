extends "res://tests/runner.gd"
## 原有实体通过真实建造界面确认；所有数据与画面来自隔离主场景。
const Touch=preload("res://tests/touch_navigation.gd")
var editor: Node
var original: Dictionary
var capture_mode: bool=false
var captures: Array=[]
var samples: Array=[]
var registry_report: Dictionary={}

func run() -> void:
	capture_mode="--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game);editor=game.get("territory_editor")
	check(is_instance_valid(editor) and is_instance_valid(game.get("farm_layout_world")),"实际主场景完整创建原物DIY控制器")
	if is_instance_valid(editor):
		game.change_location("farm",Vector2(784,592));await frames(5)
		registry_checks()
		await home_cycle()
		await resource_cycle()
		await plot_cycle()
		await housing_cycle()
		await water_and_input()
		await layouts_and_exit()
	UIMetrics.screen_provider=Callable()
	if is_instance_valid(editor) and editor.active: editor.cancel()
	check(FarmSaveStore.restore(game,original),"实际编辑专项恢复原始存档种子，不写用户文件")
	var file:=FileAccess.open("res://builds/farm-diy-editor-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"layout_samples":samples,"registry":registry_report,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));file.close()
	print("FARM DIY EDITOR RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.2).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func frozen_state() -> Dictionary:
	return {"layout":FarmLayout.snapshot(),"territory":Territory.snapshot(),"housing":Housing.snapshot(),"plots":game.farm.plots.duplicate(true),"resources":game.resource_world.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"day":GameClock.day,"minutes":GameClock.minutes,"xiaojing":Xiaojing.snapshot(),"story":Story.snapshot()}
func entry(kind: String,id: String,source: String="layout") -> Dictionary:
	for item in game.farm_layout_world.entries():
		if str(item.kind)==kind and str(item.id)==id and str(item.get("source","layout"))==source: return item
	return {}
func node_ids(id: String) -> Array:
	var ids: Array=[]
	for item in game.farm_layout_world.groups.get(id,[]):
		if is_instance_valid(item.node): ids.append(item.node.get_instance_id())
	ids.sort();return ids
func open_editor() -> bool:
	if editor.active: return true
	while game.hud.close_active_panel(): pass
	game.player.action_time=0;game.player.velocity=Vector2.ZERO
	var accepted: bool=editor.open();await frames(5)
	return accepted
func view(point: Vector2) -> void:
	game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK;game.camera_rig.view_center=game.camera_rig.clamp_center(point);game.camera_rig.apply_camera();await frames(3)
func tap(control: Control,index: int=971) -> void:
	if not is_instance_valid(control): check(false,"预期原生按钮存在");return
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(3)
	var point:=control.get_global_rect().get_center()
	Touch.finger(self,point,true,index);Touch.finger(self,point,false,index);await frames(5)
func action_button(tool: String) -> Button:
	for button in editor.action_buttons:
		if button.get_meta("territory_tool","")==tool: return button
	return null
func plan(item: Dictionary,preferred: Array[Vector2i]) -> Vector2i:
	if item.is_empty(): check(false,"原物列表包含预期身份");return FarmLayoutCatalog.INVALID_CELL
	for cell in preferred:
		editor.select_entity(item);editor.preview_at(cell);await frames(5)
		if editor.preview_plan.get("valid",false): return cell
	print("NO VALID PREVIEW: ",item," ",editor.preview_plan)
	return FarmLayoutCatalog.INVALID_CELL
func commit(title: String) -> bool:
	var count: int=editor.commit_count;await tap(editor.confirm_button)
	var ok: bool=editor.commit_count==count+1
	check(ok,title)
	var state:=frozen_state()
	check(not editor.confirm() and editor.commit_count==count+1 and frozen_state()==state,"重复确认不重放交易："+title)
	return ok
func choose_stored(kind: String,id: String,source: String="layout") -> bool:
	editor.choose_category("farm");editor.subgroup="stored";editor.inventory_page=0;editor._populate_tools();await frames(4)
	var target:=entry(kind,id,source)
	check(not target.is_empty() and target.stored,"已收纳列表保留原身份："+id)
	var key: String="layout:"+kind+":"+id
	for _page in range(8):
		if editor.tool_buttons.has(key): await tap(editor.tool_buttons[key]);break
		editor._inventory_turn(1);await frames(3)
	return editor.selected_id==id and editor.selected_tool=="restore" and editor.selected_entity.get("source")==source

func home_cycle() -> void:
	check(await open_editor(),"正常农场进入真实原物DIY")
	editor.choose_category("farm");await frames(4)
	check(editor.tool_buttons.size()<=32 and game.farm_layout_world.entries().size()>32,"原物浏览器按32项分页，未一次创建全部按钮")
	var first: Array=editor.tool_buttons.keys();editor._inventory_turn(1);await frames(3)
	check(editor.inventory_page==1 and editor.tool_buttons.size()<=32 and editor.tool_buttons.keys()!=first,"下一页显示另一组真实原物")
	await capture("browser")
	var ids:=node_ids("home");var before:=frozen_state();var old_cell:=FarmLayout.cell("fixture","home")
	var destination:=await plan(entry("fixture","home"),[Vector2i(20,5),Vector2i(22,7),Vector2i(21,8),Vector2i(19,7)])
	check(destination!=FarmLayoutCatalog.INVALID_CELL and editor.preview_plan.get("source")=="layout","住宅新址通过真实碰撞与通路预览")
	check(frozen_state()==before and not editor.preview_art().is_empty(),"住宅预览使用实际美术且未修改存档")
	await view(FarmLayoutCatalog.world_point("fixture","home",destination));await capture("home_preview")
	await tap(editor.discard_button);check(frozen_state()==before and editor.preview_plan.is_empty(),"取消住宅预览不移动原物或消耗资源")
	destination=await plan(entry("fixture","home"),[destination])
	if destination==FarmLayoutCatalog.INVALID_CELL: editor.cancel();return
	await commit("原生确认移动住宅一次")
	check(FarmLayout.cell("fixture","home")==destination and node_ids("home")==ids,"住宅保留原实例组，没有复制建筑或门口")
	editor.choose_tool("grass");editor.preview_at(old_cell+Vector2i(0,-1));await frames(5)
	check(editor.preview_plan.get("valid",false),"移走住宅后旧墙体位置可重新规划地表")
	await commit("住宅旧址可确认重新铺设草地")
	check(Territory.state.terrain.get("farm",{}).get(TerritoryCatalog.key(old_cell+Vector2i(0,-1)))=="grass","旧墙体区域实际写入新地表，不残留静态保护")
	await capture("home_after")
	editor.select_entity(entry("fixture","home"));await tap(action_button("store"))
	check(editor.selected_id=="home" and editor.preview_plan.get("stored",false) and editor.preview_plan.get("valid",false),"收纳按钮保留已选住宅并立即生成收纳预览")
	await capture("home_storage_preview");await commit("确认收纳住宅保留原实例")
	check(FarmLayout.stored("fixture","home") and node_ids("home")==ids,"住宅收纳只隐藏原实体，不删除或复制")
	check(await choose_stored("fixture","home"),"原生点击已收纳住宅可选择放回")
	await capture("storage_browser")
	var back:=await plan(entry("fixture","home"),[old_cell])
	if back!=FarmLayoutCatalog.INVALID_CELL: await commit("将原住宅从收纳放回")
	check(not FarmLayout.stored("fixture","home") and FarmLayout.cell("fixture","home")==old_cell and node_ids("home")==ids,"放回后原住宅位置和唯一实例恢复")
	editor.cancel();await frames(4)

func resource_cycle() -> void:
	var field: Node=game.resource_world.fields.farm;var id: String="tree_5_8"
	var object: Node=field.objects[id];var instance: int=object.get_instance_id()
	check(field.hit(id,"axe"),"原采集接口先实际击打树木，制造半损耐久")
	await frames(20)
	var hp: int=field.state[id].hp;var resource: Dictionary=field.state[id].duplicate(true);var wood: int=Inventory.count("wood")
	check(hp>0 and hp<int(FarmResourceCatalog.TYPES.tree.hits),"树木确为未砍倒的受损原资源")
	check(await open_editor(),"受损资源进入真实编辑器")
	var original_cell:=FarmLayout.cell("resource",id)
	var target:=await plan(entry("resource",id),[Vector2i(12,18),Vector2i(14,19),Vector2i(9,17),Vector2i(20,25)])
	if target!=FarmLayoutCatalog.INVALID_CELL: await commit("移动受损原树")
	check(field.objects[id].get_instance_id()==instance and field.state[id]==resource and Inventory.count("wood")==wood,"移动受损树保留耐久、ID与实例，不发木材")
	editor.select_entity(entry("resource",id));await tap(action_button("store"));await commit("收纳受损原树")
	check(FarmLayout.stored("resource",id) and field.state[id]==resource and Inventory.count("wood")==wood,"收纳树木不重置采集耐久或产生掉落")
	check(await choose_stored("resource",id),"从真实已收纳列表选择原树恢复")
	var back:=await plan(entry("resource",id),[original_cell])
	if back!=FarmLayoutCatalog.INVALID_CELL: await commit("恢复受损原树")
	check(field.objects[id].get_instance_id()==instance and field.state[id]==resource and Inventory.count("wood")==wood,"原树恢复后仍半损，没有重生资源或重复奖励")
	editor.cancel();await frames(4)

func plot_cycle() -> void:
	var id: String="20,18";var logical:=Vector2i(20,18)
	game.farm.plots[id]={"crop":"wheat","days":1,"watered":true};game.farm.changed.emit();Events.navigation_changed.emit();await frames(5)
	var crop: Dictionary=game.farm.plots[id].duplicate(true);var old:=FarmLayout.cell("plot",id)
	check(await open_editor(),"带作物的生产田可进入原物列表")
	var target:=await plan(entry("plot",id),[Vector2i(22,24),Vector2i(23,24),Vector2i(21,25)])
	if target!=FarmLayoutCatalog.INVALID_CELL: await commit("确认移动带作物生产田")
	check(FarmLayout.cell("plot",id)==target and game.farm.plots[id]==crop and game.farm.logical_cell(target)==logical,"农田位移保留原逻辑ID、作物、成长日和水分")
	editor.select_entity(entry("plot",id));await tap(action_button("store"));await commit("收纳带作物原田")
	check(FarmLayout.stored("plot",id) and game.farm.plots[id]==crop,"收纳田块保留原作物状态")
	check(await choose_stored("plot",id),"已收纳田块仍可选回")
	var back:=await plan(entry("plot",id),[old])
	if back!=FarmLayoutCatalog.INVALID_CELL: await commit("恢复带作物原田")
	check(game.farm.plots[id]==crop and game.farm.logical_cell(old)==logical,"田块放回后继续映射同一原作物")
	editor.cancel();await frames(4)

func housing_cycle() -> void:
	Housing.state.owned.road=int(Housing.state.owned.get("road",0))+1;Housing.changed.emit();await frames(5)
	check(await open_editor(),"原Housing家具库在农场DIY中可用")
	var layout:=FarmLayout.snapshot();var count: int=Housing.state.placed.size();var owned: int=Housing.state.owned.road
	check(await choose_stored("fixture","road","owned"),"已收纳列表识别原Housing家具库来源")
	var placed:=await plan(entry("fixture","road","owned"),[Vector2i(22,25),Vector2i(24,25),Vector2i(16,25)])
	if placed==FarmLayoutCatalog.INVALID_CELL: editor.cancel();return
	await commit("原家具库通过Housing.place放回")
	check(Housing.state.placed.size()==count+1 and int(Housing.state.owned.get("road",0))==owned-1 and FarmLayout.snapshot()==layout,"恢复只减少原家具库，不写第二份原物记录")
	var id: String=Housing.state.placed[-1].id
	editor.choose_tool("move");editor.preview_at(placed);await frames(4)
	check(editor.selected_entity.get("source")=="housing" and editor.selected_id==id,"实际地图点选识别同一Housing家具ID")
	var target:=await plan(editor.selected_entity.duplicate(true),[placed+Vector2i(1,0),placed+Vector2i(0,1),placed+Vector2i(-1,0)])
	if target!=FarmLayoutCatalog.INVALID_CELL: await commit("移动原Housing家具")
	check(Housing.placement(id).cell==[target.x,target.y] and Housing.state.placed.size()==count+1,"自制家具移动保留同一ID和数量")
	editor.choose_tool("store");editor.preview_at(target);await frames(4);await commit("将自制家具回收到原库")
	check(Housing.placement(id).is_empty() and int(Housing.state.owned.road)==owned,"收纳自制家具只归还一份原库存")
	check(await choose_stored("fixture","road","owned"),"回收后的家具重新出现在原库列表")
	var back:=await plan(entry("fixture","road","owned"),[placed])
	if back!=FarmLayoutCatalog.INVALID_CELL: await commit("原库再次放回家具")
	check(Housing.state.placed.size()==count+1 and int(Housing.state.owned.get("road",0))==owned-1 and FarmLayout.snapshot()==layout,"完整家具闭环不复制物品或布局记录")
	editor.cancel();await frames(4)

func water_and_input() -> void:
	check(await open_editor(),"水形编辑使用同一建造模式")
	var at: Vector2=game.player.position;var execution: int=game.auto_move.execution_count;var stamina: int=GameState.stamina;var mode: int=game.camera_rig.mode
	var state:=frozen_state();editor.choose_tool("grass");editor.preview_at(Vector2i(34,18));await frames(5)
	check(editor.preview_plan.get("valid",false) and frozen_state()==state,"原池塘中央填地先预览，不提前改变水域碰撞")
	await view(Vector2(1104,592));await capture("water_preview")
	await commit("确认一格水面改为草地")
	check(FarmTerrain.effective_index(Vector2i(34,18))==0 and game.world.ground.get_cell_atlas_coords(Vector2i(34,18)).x==0,"水面改形同步真实TileMap地面与碰撞列")
	editor.choose_tool("water");editor.preview_at(Vector2i(34,18));await frames(5)
	check(editor.preview_plan.get("valid",false),"填地后可再次预览挖回浅水")
	await commit("原池塘一格挖回水面")
	check(FarmTerrain.effective_index(Vector2i(34,18))==5,"水形恢复读取当前真实水格")
	state=frozen_state();editor.choose_tool("grass")
	var screen: Vector2=Vector2(900,230)
	check(not editor._ui_at(screen),"世界触点选在真实UI矩形之外")
	Touch.finger(self,screen,true,975);Touch.finger(self,screen,false,975);await frames(4)
	check(game.player.position==at and game.auto_move.execution_count==execution and GameState.stamina==stamina and frozen_state()==state,"编辑地图触点不穿透为移动、工具交互或资源结算")
	await tap(editor.discard_button)
	check(editor.preview_plan.is_empty() and frozen_state()==state,"原生取消按钮不提交世界触点预览")
	editor.cancel();await frames(4)

func layouts_and_exit() -> void:
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(5);game.hud.update_safe_area();await frames(3)
		check(await open_editor(),"不同横屏比例进入原物DIY："+str(extent))
		editor.choose_category("farm");await frames(4);editor.layout_panel();await frames(4)
		var bounds: Rect2=game.hud.safe.get_global_rect();var palette: Rect2=editor.palette.get_global_rect();var footer: Rect2=editor.panel.get_global_rect()
		var valid: bool=bounds.grow(.6).encloses(palette) and bounds.grow(.6).encloses(footer) and not palette.intersects(footer)
		for button in [editor.confirm_button,editor.discard_button,editor.cancel_button]: valid=valid and footer.grow(.6).encloses(button.get_global_rect()) and button.size.x>=UIMetrics.minimum_target() and button.size.y>=UIMetrics.minimum_target()
		check(valid and editor.tool_buttons.size()<=32,"安全区内面板不重叠、分页和触控目标正确："+str(extent))
		samples.append({"window":[extent.x,extent.y],"safe":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"palette":[palette.position.x,palette.position.y,palette.size.x,palette.size.y],"footer":[footer.position.x,footer.position.y,footer.size.x,footer.size.y],"buttons":_button_rects(),"valid":valid,"target":UIMetrics.minimum_target()})
		if not valid: print("EDITOR LAYOUT DIAGNOSTIC ",JSON.stringify(samples[-1]))
		await capture("layout_"+str(extent.x)+"x"+str(extent.y));await tap(editor.cancel_button)
		check(not editor.active and not GameState.modal and game.hud.toolbar.visible,"原生退出恢复正常游戏HUD："+str(extent))
	get_window().size=Vector2i(1280,720);await frames(5)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(4)
	check(await open_editor(),"480DPI及模拟横屏刘海进入DIY")
	editor.layout_panel();await frames(5)
	var safe: Rect2=game.hud.safe.get_global_rect()
	var dpi_valid: bool=UIMetrics.minimum_target()==96 and editor.confirm_button.size.y>=96 and safe.grow(.6).encloses(editor.palette.get_global_rect()) and safe.grow(.6).encloses(editor.panel.get_global_rect()) and not editor.palette.get_global_rect().intersects(editor.panel.get_global_rect())
	for button in editor.movement_buttons+editor.action_buttons:
		dpi_valid=dpi_valid and button.size.x>=96 and button.size.y>=96 and editor.panel.get_global_rect().grow(.6).encloses(button.get_global_rect())
	check(dpi_valid,"DPI按物理/视口缩放换算，安全区和96设计像素触区完整")
	if not dpi_valid: print("EDITOR DPI DIAGNOSTIC ",safe," ",editor.palette.get_global_rect()," ",editor.panel.get_global_rect()," ",_button_rects())
	await capture("dpi_480_inset");editor.cancel();UIMetrics.screen_provider=Callable();game.hud.update_safe_area();await frames(4)
	var previous: String=GameState.control_mode;GameState.set_control_mode("joystick",false);await frames(3)
	game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK;game.camera_rig.view_center=game.camera_rig.clamp_center(Vector2(900,600));game.camera_rig.apply_camera()
	var center: Vector2=game.camera_rig.view_center;var camera_mode: int=game.camera_rig.mode;var state:=frozen_state()
	check(await open_editor(),"备用摇杆保留操作模式进入DIY")
	editor.choose_tool("grass");editor.preview_at(Vector2i(21,24));await frames(4);editor.pan_view(Vector2.LEFT)
	editor.cancel();await frames(4)
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible and not GameState.modal and frozen_state()==state,"退出DIY恢复原摇杆和世界状态，丢弃未确认预览")
	check(game.camera_rig.mode==camera_mode and game.camera_rig.view_center.distance_to(center)<1,"退出恢复进入前镜头观察位置与模式")
	GameState.set_control_mode(previous,false)

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/farm-diy-editor-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path,"window":[get_window().size.x,get_window().size.y]})

func _button_rects() -> Array:
	var values: Array=[]
	for button in [editor.confirm_button,editor.discard_button,editor.cancel_button]:
		var rect: Rect2=button.get_global_rect();values.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	return values

func registry_checks() -> void:
	var definitions: Array=FarmLayoutCatalog.ids("fixture");var listed: Dictionary={}
	for item in game.farm_layout_world.entries():
		if item.kind=="fixture" and item.get("source","layout")=="layout": listed[item.id]=int(listed.get(item.id,0))+1
	check(definitions.size()==64 and listed.size()==64,"全部64个原农场设施ID在真实编辑器注册一次")
	var all_nodes: Dictionary={};var counts: Dictionary={};var groups: int=0
	for id in definitions:
		var valid: bool=listed.get(id,0)==1
		var records: Array=game.farm_layout_world.groups.get(id,[])
		counts[id]=records.size()
		if id=="lake":
			valid=valid and FarmTerrain.effective_index(Vector2i(34,18)) in [5,6]
			check(valid,"天然池塘作为真实地表模块注册，未额外复制建筑节点")
			continue
		groups+=1;valid=valid and not records.is_empty()
		for item in records:
			var node: Node2D=item.node
			if not is_instance_valid(node): valid=false;continue
			var instance: int=node.get_instance_id()
			valid=valid and game.world.is_ancestor_of(node) and not all_nodes.has(instance) and node.get_meta("farm_fixture","")==id
			valid=valid and node.position.distance_to(item.original+FarmLayout.offset(id))<.01
			all_nodes[instance]=id
		check(valid,"真实原设施场景节点、唯一归属及坐标注册："+str(id))
	var original_count: int=all_nodes.size();game.farm_layout_world.collect()
	var recount: int=0
	for records in game.farm_layout_world.groups.values(): recount+=records.size()
	check(recount==original_count,"再次扫描实际场景不复制或重复注册原设施节点")
	var resources: Dictionary=game.resource_world.fields.farm.objects;var resource_nodes: Dictionary={}
	for node in resources.values(): resource_nodes[node.get_instance_id()]=true
	check(resources.size()==42 and resource_nodes.size()==42,"42个原采集资源ID对应42个唯一实际节点")
	registry_report={"fixture_ids":definitions.size(),"listed_fixture_ids":listed.size(),"physical_groups":groups,"scene_fixture_nodes":original_count,"resource_nodes":resource_nodes.size(),"nodes_per_fixture":counts,"lake_representation":"live_tilemap_terrain"}
