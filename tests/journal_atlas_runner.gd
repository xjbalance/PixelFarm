extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var panel: PanelContainer
var capture_mode: bool=false
var baseline: bool=false
var captures: Array=[]
func run() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));panel=game.hud.story_panel
	if baseline:
		panel.open_panel();panel.select_page(1);await frames(8)
		check(panel.visible and panel.page==1,"原手记河谷地图公开入口可打开")
		await capture("before-map")
	else:
		await checks()
	print("JOURNAL ATLAS "+("BASELINE" if baseline else "RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	var f:=FileAccess.open("res://builds/journal-atlas-"+("before" if baseline else "render" if capture_mode else "state")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"android_device_tested":false},"\t"));f.close()
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func checks() -> void:
	var original: Dictionary=FarmSaveStore.snapshot(game)
	panel.open_panel();await frames(5)
	check(panel.visible and panel.page==0 and panel.scroll.visible and not panel.map_page.visible,"原手记首页、正文滚动与共建内容保留")
	check(panel.tabs.size()==4 and panel.title.text=="那些没有寄出的信","四个原页签和手记标题保留")
	await capture("after-story")
	await tap(panel.tabs[1]);await frames(5)
	check(panel.page==1 and panel.map_page.visible and not panel.scroll.visible and not game.hud.toast.visible,"原生河谷地图页签打开独立图纸页，旧短提示不盖住图纸说明")
	check(panel.map_canvas.get_script().resource_path=="res://scripts/maps/atlas_canvas.gd","手记直接复用同一羊皮纸画布脚本，没有第二套块状地图")
	check(not panel.scroll.is_processing_input() and not panel.payment_control.visible,"看图期间外层TouchScroll与无关支付控制不抢手势")
	check(panel.map_canvas.layer_id=="region" and panel.map_canvas.region_id==GameState.location,"手记图纸默认对应玩家当前区域")
	check(panel.map_canvas.player_map_position().distance_to(FarmAtlasData.world_to_map(GameState.location,game.player.position))<.01,"手记与真实玩家坐标使用同一映射")
	check(not in_scroll(panel.map_canvas),"图纸画布没有ScrollContainer祖先")
	check(FarmSaveStore.snapshot(game)==original,"切换手记与图纸只读，不改变金币物品剧情和存档")
	await capture("after-map")
	await tap(find_button("世界总览"));game.hud.atlas_panel.map_canvas.show_world();await frames(3)
	check(panel.map_canvas.layer_id=="world" and panel.map_canvas.places==game.hud.atlas_panel.map_canvas.places,"手记与M键地图展示完全相同的世界地点和探索状态")
	var unknown: bool=false
	for item in panel.map_canvas.places:
		if item.id=="old_temple": unknown=not item.discovered and item.name=="尚未探索"
	check(unknown,"原未发现神庙在手记中同样隐藏名字与秘密")
	var village: Dictionary={}
	for item in panel.map_canvas.places:
		if item.id=="village": village=item
	var point: Vector2=panel.map_canvas.get_global_transform()*panel.map_canvas.map_to_screen(village.point)
	Touch.finger(self,point,true,741);Touch.finger(self,point,false,741);await frames(3)
	check(panel.map_selected.get("id","")=="village" and panel.map_info.text.contains("河湾村") and not panel.map_detail.disabled,"手记内原生轻点地点出现同一说明及查看详图")
	await tap(panel.map_detail)
	check(panel.map_canvas.region_id=="village" and GameState.location==original.location,"手记可查看村庄详图，不把角色传送过去")
	await capture("after-village")
	await tap(find_button("当前区域"));await tap(find_button("+"));await frames(2)
	check(panel.map_canvas.zoom>1 and panel.map_zoom.text!="100%","手记原生加号缩放准确更新百分比")
	panel.map_canvas.zoom_by(1.8);await frames(2)
	var start: Vector2=panel.map_canvas.get_global_rect().get_center();var old_pan: Vector2=panel.map_canvas.pan
	Touch.finger(self,start,true,742)
	for i in range(4):
		var drag:=InputEventScreenDrag.new();drag.index=742;drag.position=start+Vector2(40,60)*float(i+1)/4;drag.relative=Vector2(10,15);get_viewport().push_input(drag,true);await frames(1)
	Touch.finger(self,start+Vector2(40,60),false,742);await frames(3)
	check(panel.map_canvas.pan.distance_to(old_pan)>15 and panel.scroll.scroll_vertical==0,"原生拖动只平移图纸，不滚动手记页")
	var zoom: float=panel.map_canvas.zoom;var a: Vector2=start-Vector2(60,0);var b: Vector2=start+Vector2(60,0)
	Touch.finger(self,a,true,743);Touch.finger(self,b,true,744)
	var pinch:=InputEventScreenDrag.new();pinch.index=744;pinch.position=b+Vector2(50,0);pinch.relative=Vector2(50,0);get_viewport().push_input(pinch,true);await frames(2)
	Touch.finger(self,a,false,743);Touch.finger(self,b+Vector2(50,0),false,744);await frames(3)
	check(panel.map_canvas.zoom>zoom and panel.map_selected.is_empty(),"手记双指缩放可用，未被误判为地点点击")
	check(FarmSaveStore.snapshot(game)==original and game.auto_move.target.is_empty(),"手记图纸触摸不穿透到农田或产生待执行操作")
	var old_zoom: float=panel.map_canvas.zoom;var canvas_id: int=panel.map_canvas.get_instance_id();panel.refresh();await frames(3)
	check(panel.map_canvas.get_instance_id()==canvas_id and panel.map_canvas.zoom==old_zoom,"普通手记刷新复用画布，不重建或重置缩放")
	await tap(panel.tabs[2]);await frames(3)
	check(panel.scroll.visible and not panel.map_page.visible and panel.map_canvas.fingers.is_empty(),"切换人物页恢复原滚动并清理地图手势")
	await capture("after-people")
	await tap(panel.tabs[3]);await frames(3);check(panel.page==3 and panel.content.get_child_count()>2,"记忆与线索仍按原进度正常显示")
	await capture("after-memories")
	panel.select_page(1);panel.show_map_world();await frames(3);await tap(find_button("展开地图"));await frames(15)
	check(game.hud.atlas_panel.visible and not panel.visible and GameState.modal,"手记展开按钮进入同一全屏羊皮纸地图，保持模态拦截")
	check(game.hud.atlas_panel.map_canvas.layer_id=="world" and FarmSaveStore.snapshot(game)==original,"展开只交接图纸视图，不重置资源或剧情")
	game.hud.atlas_panel.close_panel();panel.open_panel();panel.select_page(1);await frames(4)
	check(panel.map_selected.is_empty() and panel.map_detail.disabled and panel.map_canvas.zoom==1,"关闭后重新打开不残留地点菜单或旧缩放")
	panel.close_panel()
	for area in ["home","village","farm"]:
		game.change_location(area,WorldTravel.entry(area));await frames(5);panel.open_panel();panel.select_page(1);await frames(4)
		check(panel.map_canvas.region_id==area and panel.map_canvas.player_map_position()!=Vector2.INF,"室内外手记地图采用当前场景坐标："+area)
		panel.close_panel()
	game.change_location("farm",Vector2(original.player[0],original.player[1]));await frames(5)
	var legacy:=FarmRiverMap.new();legacy.location="village";game.hud.safe.add_child(legacy);legacy.hide();await frames(2)
	check(legacy is FarmAtlasCanvas and legacy.region_id=="village","旧FarmRiverMap类作为兼容包装也使用羊皮纸画布")
	check(legacy.point(Vector2(640,826)).distance_to(legacy.map_to_screen(FarmAtlasData.world_to_map("village",Vector2(640,826))))<.01,"旧point接口统一转换为新图纸坐标")
	legacy.queue_free();await frames(2)
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4);game.hud.update_safe_area();await frames(4)
		panel.open_panel();panel.select_page(1);await frames(8)
		check(game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()) and panel.map_canvas.size.y>=150,"手记图纸与主体适配横屏："+str(extent))
		check(panel.get_global_rect().grow(.5).encloses(panel.map_canvas.get_global_rect()),"图纸不超出手记面板："+str(extent))
		await capture("layout_"+str(extent.x)+"x"+str(extent.y));panel.close_panel()
	get_window().size=Vector2i(1280,720);await frames(4)
	for dpi in [320,480]:
		UIMetrics.screen_provider=func(): return {"dpi":dpi,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
		panel.open_panel();panel.select_page(1);await frames(10)
		var usable: bool=game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()) and panel.map_canvas.size.y>=150
		for button in buttons(panel): usable=usable and button.size.x>=UIMetrics.minimum_target() and button.size.y>=UIMetrics.minimum_target() and panel.get_global_rect().grow(.5).encloses(button.get_global_rect())
		check(usable,"手记地图的DPI换算触区和中文按钮可达："+str(dpi))
		await capture("density_"+str(dpi));panel.close_panel()
	UIMetrics.screen_provider=Callable();game.hud.update_safe_area();await frames(4)
	check(FarmSaveStore.restore(game,original),"专项后原完整存档可以恢复")
	await frames(4);var before: Dictionary=FarmSaveStore.snapshot(game)
	panel.open_panel();panel.select_page(1)
	check(FarmSaveStore.write(game,"user://journal-atlas-save.json"),"手记看图期间可写原v24存档")
	check(FarmSaveStore.read("user://journal-atlas-save.json").version==24 and FarmSaveStore.restore(game,FarmSaveStore.read("user://journal-atlas-save.json")),"手记图纸不新增存档结构且能沿原流程读取")
	await frames(4)
	var after: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(FarmSaveStore.snapshot(game))))
	before=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(before)))
	for key in before:
		if before[key]!=after.get(key): print("JOURNAL LOAD DIFFERENCE ",key,": ",before[key]," -> ",after.get(key))
	check(not panel.visible and not GameState.modal and after==before,"读取关闭临时手记地图并逐字段保留原存档")

func buttons(root: Node) -> Array[Button]:
	var out: Array[Button]=[]
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree(): out.append(child)
		out.append_array(buttons(child))
	return out
func find_button(caption: String) -> Button:
	for button in buttons(panel):
		if button.text==caption: return button
	return null
func tap(control: Control,index: int=740) -> void:
	if not is_instance_valid(control): check(false,"缺少应可原生点击的手记按钮");return
	var at: Vector2=control.get_global_rect().get_center();Touch.finger(self,at,true,index);Touch.finger(self,at,false,index);await frames(4)
func in_scroll(control: Node) -> bool:
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: return true
		parent=parent.get_parent()
	return false
func capture(label: String) -> void:
	if not capture_mode and not baseline: return
	if DisplayServer.get_name()=="headless": return
	await frames(8);await RenderingServer.frame_post_draw
	var path: String="res://builds/journal-atlas-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
