extends "res://tests/runner.gd"
## 真实HUD入口/原生手势/场景切换/安全区，保存状态始终沿原v24。
const Touch=preload("res://tests/touch_navigation.gd")
var panel: PanelContainer
var sheet: Control
var original: Dictionary
var capture_mode: bool=false
var captures: Array=[]

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	panel=game.hud.atlas_panel;sheet=panel.map_canvas
	original=FarmSaveStore.snapshot(game)
	await entry_and_pause()
	await gestures()
	await scenes_and_layout()
	await persistence()
	check(FarmSaveStore.restore(game,original),"图纸专项结束可完整恢复当前进度")
	var f:=FileAccess.open("res://builds/atlas-ui-"+("render" if capture_mode else "state")+"-evidence.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"android_device_tested":false,"platform":DisplayServer.get_name()},"\t"));f.close()
	print("ATLAS UI "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func key_m() -> void:
	for press in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=KEY_M;event.keycode=KEY_M;event.pressed=press
		get_viewport().push_input(event,true)
	await frames(3)

func tap_control(control: Control,index: int=911) -> void:
	var at: Vector2=control.get_global_rect().get_center()
	Touch.finger(self,at,true,index);Touch.finger(self,at,false,index);await frames(4)

func local_screen(point: Vector2) -> Vector2: return sheet.get_global_transform()*point

func entry_and_pause() -> void:
	check(not panel.visible and not GameState.modal and game.hud.atlas_button.visible,"地图默认收起且HUD仅显示安全区小图标")
	check(game.hud.safe.get_global_rect().encloses(game.hud.atlas_button.get_global_rect()),"地图入口完整在横屏安全区内")
	await capture("closed")
	await tap_control(game.hud.atlas_button)
	await capture("unfolding",0)
	check(panel.visible and GameState.modal and sheet.layer_id=="world","原生HUD点击实际展开羊皮纸总览并进入菜单暂停")
	check(game.auto_move.target.is_empty() and game.player.velocity==Vector2.ZERO,"展开时取消旧寻路和待执行交互")
	await frames(15)
	check(absf(panel.reveal.size.x-panel.stage.size.x)<1,"展开动画结束完整显示图纸，未缩放整个UI")
	var before: Dictionary=FarmSaveStore.snapshot(game)
	GameClock.running=true;var minute: float=GameClock.minutes;await frames(12)
	check(GameClock.minutes==minute,"地图开启期间沿现有模态规则暂停游戏分钟")
	GameClock.running=false
	check(FarmSaveStore.snapshot(game)==before,"展开查看不修改玩家资源、农田、住宅、剧情或存档结构")
	await key_m()
	check(not panel.visible and not GameState.modal,"M键可直接收起已展开地图")
	await key_m()
	check(panel.visible and not game.hud.story_panel.visible,"M键默认展开新地图，原手记仍保留独立入口")
	panel.close_panel()
	var stable: bool=true
	for _i in range(12):
		stable=panel.open_panel() and stable;panel.close_panel()
	await frames(15)
	check(stable and not panel.visible and not GameState.modal,"实际12轮快速展开收起不会留下动画或模态锁")
	game.hud.inventory_panel.open_panel(false)
	check(not panel.open_panel() and game.hud.inventory_panel.visible,"背包等模态菜单开启期间不叠加地图")
	game.hud.inventory_panel.close_panel()
	game.player.action_time=.2
	check(not panel.open_panel() and not GameState.modal,"正在挥工具时不提前打开地图打断生效阶段")
	game.player.action_time=0

func gestures() -> void:
	game.change_location("farm",Vector2(800,600));await frames(6)
	game.camera_rig.begin_free_look();game.camera_rig.pan_screen(Vector2(80,0));game.camera_rig.end_free_look()
	var camera_at: Vector2=game.camera_rig.view_center;var mode: int=game.camera_rig.mode
	panel.open_panel();await frames(18)
	var before: Dictionary=FarmSaveStore.snapshot(game);var executions: int=game.auto_move.execution_count
	var village: Dictionary={}
	for item in sheet.places:
		if item.id=="village": village=item
	check(not village.is_empty(),"总览包含真实河湾村地点")
	if not village.is_empty():
		var point: Vector2=local_screen(sheet.map_to_screen(village.point))
		Touch.finger(self,point,true,921);Touch.finger(self,point,false,921);await frames(4)
		check(panel.selected_place.get("id","")=="village" and panel.info_label.text.contains("河湾村"),"原生轻点图纸地点显示正确中文说明")
		check(not panel.detail_button.disabled,"已知地点提供区域详图查看")
		await tap_control(panel.detail_button)
		check(sheet.layer_id=="region" and sheet.region_id=="village","点击查看详图切换河湾村，玩家并未旅行")
	panel.show_current();await frames(3)
	check(sheet.player_map_position().distance_to(FarmAtlasData.world_to_map("farm",game.player.global_position))<.01,"当前农场人物标记使用真实场景坐标")
	var world: Vector2=FarmAtlasData.map_to_world("farm",sheet.screen_to_map(sheet.map_to_screen(sheet.player_map_position())))
	check(world.distance_to(game.player.global_position)<4,"图纸玩家映射经屏幕逆变换保持原位置")
	await tap_control(panel.zoom_in_button)
	check(sheet.zoom>1,"原生加号按钮实际放大图纸")
	sheet.zoom_by(1.8);await frames(3)
	var start: Vector2=local_screen(sheet.size*.5);var old_pan: Vector2=sheet.pan
	Touch.finger(self,start,true,922)
	for i in range(5):
		var drag:=InputEventScreenDrag.new();drag.index=922;drag.position=start+Vector2(70,28)*float(i+1)/5;drag.relative=Vector2(14,5.6)
		get_viewport().push_input(drag,true);await frames(1)
	Touch.finger(self,start+Vector2(70,28),false,922);await frames(3)
	check(sheet.pan.distance_to(old_pan)>15,"真实单指拖动平移放大后的图纸")
	var zoom: float=sheet.zoom;var first: Vector2=local_screen(sheet.size*.5-Vector2(70,0));var second: Vector2=local_screen(sheet.size*.5+Vector2(70,0))
	Touch.finger(self,first,true,923);Touch.finger(self,second,true,924)
	var pinch:=InputEventScreenDrag.new();pinch.index=924;pinch.position=second+Vector2(55,0);pinch.relative=Vector2(55,0)
	get_viewport().push_input(pinch,true);await frames(2)
	Touch.finger(self,first,false,923);Touch.finger(self,second+Vector2(55,0),false,924);await frames(3)
	check(sheet.zoom>zoom and panel.selected_place.is_empty(),"双指放大实际生效且不被误判为地点点击")
	sheet.show_world();await frames(2)
	var mouse_at: Vector2=local_screen(sheet.size*.5)
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=mouse_at
	get_viewport().push_input(wheel,true);await frames(3)
	check(sheet.zoom>1,"真实鼠标滚轮可缩放图纸")
	sheet.zoom_by(1.8);old_pan=sheet.pan
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=mouse_at
	get_viewport().push_input(mouse,true)
	var motion:=InputEventMouseMotion.new();motion.position=mouse_at+Vector2(65,30);motion.relative=Vector2(65,30);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true);mouse.pressed=false;mouse.position=motion.position;get_viewport().push_input(mouse,true);await frames(3)
	check(sheet.pan.distance_to(old_pan)>15 and panel.selected_place.is_empty(),"真实鼠标拖动平移图纸且不误选地点")
	check(game.camera_rig.mode==mode and game.camera_rig.view_center.distance_to(camera_at)<.01,"图纸拖动与缩放不会拖动游戏自由观察相机")
	check(FarmSaveStore.snapshot(game)==before and game.auto_move.execution_count==executions and game.auto_move.target.is_empty(),"全部图纸手势不移动角色、不执行农活、不消耗资源")
	panel.close_panel();await frames(4)
	check(game.camera_rig.mode==mode and game.camera_rig.view_center.distance_to(camera_at)<.01,"关闭地图保留先前自由观察状态")
	game.camera_rig.follow_now()
	game.auto_move.navigation.rebuild()
	var destination: Vector2=Vector2.INF
	for point in [Vector2(784,496),Vector2(800,752),Vector2(560,752),Vector2(880,480),Vector2(704,800)]:
		var screen: Vector2=game.player.get_canvas_transform()*point
		var intent: Dictionary=TouchInteractionResolver.resolve(game,point)
		if intent.get("kind","")=="ground" and not game.touch_input.ui_at(screen) and not game.auto_move.navigation.path_to({"kind":"ground","point":point}).is_empty(): destination=point;break
	var foot: Vector2=game.player.position
	if destination!=Vector2.INF:
		var screen: Vector2=game.player.get_canvas_transform()*destination
		Touch.finger(self,screen,true,925);Touch.finger(self,screen,false,925);await frames(12)
	check(destination!=Vector2.INF and game.player.position.distance_to(foot)>1,"关闭后真实地图点击恢复原自动移动")
	game.auto_move.cancel()

func scenes_and_layout() -> void:
	for area in ["farm","home","village"]:
		game.change_location(area,WorldTravel.entry(area));await frames(5)
		panel.open_panel();panel.show_current();await frames(4)
		check(sheet.region_id==area and sheet.player_map_position()!=Vector2.INF,"真实切换场景后图纸位置属于当前区域："+area)
		await capture(area);panel.close_panel()
	game.change_location("farm",Vector2(928,656));await frames(5)
	panel.open_panel();sheet.show_region("lake");await frames(3)
	check(sheet.region_id=="lake" and sheet.player_map_position()!=Vector2.INF,"湖泊详图使用农场湖岸子区坐标，玩家标记准确显示")
	await capture("lake");panel.close_panel()
	var old_unlocked: Array=MineState.state.unlocked.duplicate();MineState.state.unlocked.append("mine_a")
	game.change_location("mine_a",WorldTravel.entry("mine_a"))
	check(GameState.location=="mine_a","矿洞查看夹具进入真实已开放矿区")
	await frames(5);panel.open_panel();panel.show_current();await frames(4)
	check(sheet.region_id=="mine_a" and sheet.player_map_position()!=Vector2.INF,"矿洞使用本区入口及实际玩家位置")
	await capture("mine");panel.close_panel();game.change_location("farm",Vector2(800,600));MineState.state.unlocked=old_unlocked
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4);game.hud.update_safe_area();await frames(4)
		panel.open_panel();await frames(16)
		var safe: Rect2=game.hud.safe.get_global_rect()
		check(safe.grow(.5).encloses(panel.get_global_rect()) and panel.stage.size.y>180,"羊皮纸面板与主体完整适配："+str(extent))
		var controls_ok: bool=true
		for button in panel.layout_controls:
			controls_ok=controls_ok and safe.grow(.5).encloses(button.get_global_rect()) and button.size.y>=UIMetrics.minimum_target()
		check(controls_ok,"所有地图按钮位于安全区并达到当前触区："+str(extent))
		await capture("world_"+str(extent.x)+"x"+str(extent.y));panel.close_panel()
	get_window().size=Vector2i(1280,720);await frames(4)
	game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(4);panel.open_panel();await frames(15)
	check(game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),"左右64px安全区注入时图纸和关闭操作不越界")
	await capture("safe_area");panel.close_panel();game.hud.update_safe_area();await frames(4)
	for dpi in [320,480]:
		UIMetrics.screen_provider=func(): return {"dpi":dpi,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
		game.hud.reflow_touch_controls();panel.open_panel();await frames(18)
		var valid: bool=game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()) and panel.stage.size.y>=180
		for button in panel.layout_controls: valid=valid and button.size.y>=UIMetrics.minimum_target() and button.size.x>=UIMetrics.minimum_target() and panel.get_global_rect().grow(.5).encloses(button.get_global_rect())
		check(valid,"真实DPI/视口换算样本地图按钮与正文可用："+str(dpi))
		await capture("dpi_"+str(dpi));panel.close_panel()
	UIMetrics.screen_provider=Callable();game.hud.reflow_touch_controls();await frames(4)
	GameState.set_control_mode("joystick",false);panel.open_panel();panel.close_panel();await frames(3)
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible,"开关地图保留备用摇杆模式和可见操作")
	GameState.set_control_mode("tap",false)

func persistence() -> void:
	check(FarmSaveStore.restore(game,original),"保存前恢复真实有效初始状态")
	await frames(5);panel.open_panel();panel.show_current();sheet.zoom_by(2)
	check(FarmSaveStore.write(game,"user://atlas-ui-save.json"),"展开/缩放期间可写当前完整存档，无新增地图字段")
	var loaded: Dictionary=FarmSaveStore.read("user://atlas-ui-save.json")
	check(loaded.version==FarmSaveStore.VERSION and not loaded.has("atlas") and loaded.housing==AbyssSaveSchema.canonical(original.housing),"图纸查看状态不写入或覆盖住宅家具存档")
	check(FarmSaveStore.restore(game,loaded) and not panel.visible and not GameState.modal,"读取保存清理临时图纸，恢复原操作状态")
	await frames(5);panel.open_panel();panel.show_current();await frames(3)
	check(sheet.player_map_position().distance_to(FarmAtlasData.world_to_map(GameState.location,game.player.global_position))<.01,"读取旧格式有效档后图纸重新映射当前玩家位置")
	panel.close_panel()

func capture(label: String, delay_frames: int=12) -> void:
	if not capture_mode: return
	await frames(delay_frames);await RenderingServer.frame_post_draw
	var path: String="res://builds/atlas-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"size":[get_window().size.x,get_window().size.y]})
