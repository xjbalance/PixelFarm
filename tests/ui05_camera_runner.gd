extends "res://tests/runner.gd"
## 相机/地图触点专项；桌面原生事件和数值验证，不等于Android真机手感。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary
var metrics: Dictionary={}
var captures: Array[String]=[]

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	initial=FarmSaveStore.snapshot(game)
	if "--baseline" in OS.get_cmdline_user_args():
		await original_measurement()
	else:
		check("camera_rig" in game and game.camera_rig!=null,"相机跟随/查看/返回模块已接入真实主场景")
		if "camera_rig" in game and game.camera_rig!=null:
			await follow_and_coordinates()
			await free_look_and_return()
			await native_drag_guards()
			await scenes_and_storage()
	var tag: String="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
	var file:=FileAccess.open("res://builds/ui05-camera-"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"Linux Godot4.3","android_device_tested":false,"metrics":metrics,"captures":captures},"\t"));file.close()
	print("UI 05 CAMERA METRICS ",JSON.stringify(metrics))
	print("UI 05 CAMERA RESULT: %d checks, %d failures" % [checked,failed])
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh(at: Vector2=Vector2(800,600), location: String="farm") -> void:
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	for index in game.touch_input.fingers.keys(): Touch.finger(self,Vector2.ZERO,false,index)
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	await Touch.place(self,game,location,at)
	game.player.action_time=0;game.action_cooldown=0
	await frames(20)

func screen_foot() -> Vector2:
	return game.player.get_canvas_transform()*game.player.global_position

func center_error() -> Vector2:
	return screen_foot()-get_viewport().get_visible_rect().get_center()

func pointer_start() -> Vector2:
	# 中央下方通常为纯地图；启动点仍通过真实UI命中检查，不穿过面板。
	for point in [Vector2(650,420),Vector2(800,420),Vector2(620,350),Vector2(900,350)]:
		if not game.touch_input.ui_at(point): return point
	return Vector2.INF

func drag(from: Vector2, delta: Vector2, index: int=310, release: bool=true) -> void:
	Touch.finger(self,from,true,index)
	for i in range(5):
		var event:=InputEventScreenDrag.new();event.index=index;event.position=from+delta*float(i+1)/5.0;event.relative=delta/5
		get_viewport().push_input(event,true);await frames(1)
	if release: Touch.finger(self,from+delta,false,index)
	await frames(3)

func original_measurement() -> void:
	await fresh()
	var camera: Camera2D=game.player.get_node("Camera2D")
	camera.reset_smoothing();camera.force_update_scroll();await frames(4)
	metrics["idle_center_error_px"]=[center_error().x,center_error().y]
	var point:=pointer_start();var world_before: Vector2=game.touch_input.world_point(point)
	var at: Vector2=game.player.position;var calls: int=game.auto_move.execution_count
	await drag(point,Vector2(110,0))
	metrics["native_drag_world_delta"]=game.touch_input.world_point(point).distance_to(world_before)
	check(game.player.position==at and game.auto_move.execution_count==calls,"旧拖动没有误成移动或重复交互")
	await capture("baseline")

func follow_and_coordinates() -> void:
	await fresh();game.camera_rig.follow_now();await frames(3)
	metrics["idle_center_error_px"]=[center_error().x,center_error().y]
	check(center_error().length()<=1.1,"地图内陆跟随时玩家脚底位于实际画布中心附近")
	var p: Vector2=game.player.position
	Input.action_press("move_right");await frames(18)
	check(not game.camera_rig.begin_free_look(),"角色实际移动期间拒绝自由查看")
	Input.action_release("move_right")
	await frames(45)
	check(game.player.position.x>p.x+20 and center_error().length()<=2,"键盘实际移动后相机能收敛到玩家，不长期偏离")
	await capture("follow")
	for size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(4);await fresh();game.camera_rig.follow_now();await frames(3)
		var world:=Vector2(784,592);var screen: Vector2=game.player.get_canvas_transform()*world
		check(game.touch_input.world_point(screen).distance_to(world)<.01,"相机跟随坐标逆变换保持准确："+str(size))
	get_window().size=Vector2i(1280,720);await frames(4)

func free_look_and_return() -> void:
	await fresh();game.camera_rig.follow_now();await frames(3)
	var at: Vector2=game.player.position;var facts: Dictionary=game.farm.plots.duplicate(true)
	var calls: int=game.auto_move.execution_count;var before: Vector2=game.touch_input.world_point(Vector2(700,400))
	check(game.camera_rig.begin_free_look(),"闲置时可进入自由查看")
	game.camera_rig.pan_screen(Vector2(90,0));await frames(3)
	var after: Vector2=game.touch_input.world_point(Vector2(700,400))
	metrics["pan_world_shift_px"]=after.x-before.x
	check(after.x<before.x-20 and game.player.position==at,"地图向右拖动时视野向左移动，玩家不被拖动")
	check(game.auto_move.target.is_empty() and game.auto_move.execution_count==calls and game.farm.plots==facts,"自由查看不提交移动、农活或交互")
	game.camera_rig.end_free_look();await frames(3)
	check(game.player.position==at,"结束拖动不自动走到释放位置")
	check(game.camera_rig.return_button.visible,"偏离后实际回到人物按钮出现")
	load("res://tests/story.gd").touch(self,game.camera_rig.return_button)
	await frames(90)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and center_error().length()<=2,"点击返回角色后平滑收敛并恢复跟随")
	check(game.player.position==at,"返回视野不瞬移玩家")
	await capture("return")
	check(game.camera_rig.begin_free_look(),"再次自由查看不残留返回锁")
	game.camera_rig.pan_screen(Vector2(-80,0));game.camera_rig.end_free_look();await frames(2)
	var target:=Vector2(784,496);var screen: Vector2=game.player.get_canvas_transform()*target
	Touch.finger(self,screen,true,311)
	# 角色移动或相机开始回跟时，释放仍必须沿用原按下世界点。
	Touch.finger(self,screen,false,311)
	check(game.auto_move.target.get("point",Vector2.INF).distance_to(target)<.01,"自由查看后新短点沿用按下世界坐标，不被回跟偏移")
	await Touch.finish(self,game,500)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and game.player.position.distance_to(Vector2(784,496))<1.1,"新移动目标自动回跟并实际抵达原目标")

func native_drag_guards() -> void:
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(2400,1080),"canvas":Vector2(1600,720)}
	check(UIMetrics.drag_threshold()==24,"12dp手势阈值按480DPI和1.5画布缩放换成24逻辑像素")
	UIMetrics.screen_provider=Callable()
	await fresh();game.camera_rig.follow_now();await frames(3)
	var point:=pointer_start();var at: Vector2=game.player.position;var calls: int=game.auto_move.execution_count
	var before: Vector2=game.touch_input.world_point(point)
	await drag(point,Vector2(100,0),312)
	var shift: float=game.touch_input.world_point(point).distance_to(before)
	metrics["native_drag_world_delta"]=shift
	check(shift>20 and game.player.position==at,"原生单指地图拖动进入查看并真正改变视野")
	check(game.auto_move.target.is_empty() and game.auto_move.execution_count==calls,"拖动释放不会提交旧点击意图")
	await capture("native_drag")
	game.camera_rig.follow_now();await frames(3)
	before=game.touch_input.world_point(point)
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.pressed=true
	get_viewport().push_input(mouse,true)
	var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(90,0);motion.relative=Vector2(90,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true);await frames(3)
	mouse=mouse.duplicate();mouse.position=motion.position;mouse.pressed=false;get_viewport().push_input(mouse,true);await frames(3)
	check(game.touch_input.world_point(point).distance_to(before)>20 and game.player.position==at,"桌面鼠标按住拖动也能查看地图而不移动人物")
	check(game.auto_move.target.is_empty() and game.auto_move.execution_count==calls,"鼠标拖动释放不把原按下目标提交为交互")
	game.camera_rig.follow_now();await frames(3)
	var old: Vector2=game.touch_input.world_point(point)
	Touch.finger(self,point,true,313);Touch.finger(self,point+Vector2(30,0),true,314)
	var event:=InputEventScreenDrag.new();event.index=313;event.position=point+Vector2(80,0);event.relative=Vector2(80,0)
	get_viewport().push_input(event,true)
	Touch.finger(self,point+Vector2(80,0),false,313);Touch.finger(self,point+Vector2(30,0),false,314);await frames(4)
	check(game.touch_input.world_point(point).distance_to(old)<1 and game.auto_move.target.is_empty(),"多指手势不误拖地图或变成移动任务")
	game.hud.inventory_panel.open_panel(false);await frames(3)
	old=game.touch_input.world_point(point)
	await drag(game.hud.inventory_panel.get_global_rect().position+Vector2(25,25),Vector2(100,0),315)
	check(game.touch_input.world_point(point).distance_to(old)<1 and game.player.position==at,"背包UI拖动不穿透到底层相机")
	check(not game.camera_rig.begin_free_look(),"模态面板期间拒绝自由查看")
	game.hud.inventory_panel.close_panel()
	game.player.start_action("浇水")
	check(not game.camera_rig.begin_free_look(),"工具动作锁定期间拒绝自由查看")
	await frames(20)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not game.camera_rig.begin_free_look(),"应用后台拒绝新查看意图")
	game.notification(NOTIFICATION_APPLICATION_RESUMED);await frames(3)
	GameState.set_control_mode("joystick",false)
	var joystick: Control=game.hud.joystick;var p: Vector2=joystick.get_global_rect().get_center()
	Touch.finger(self,p+Vector2(40,0),true,316);await frames(5);Touch.finger(self,p,false,316)
	check(game.player.position.x>at.x+5 and game.camera_rig.mode==game.camera_rig.Mode.FOLLOW,"备用摇杆仍控制人物并使用跟随相机")

func visible_world() -> Rect2:
	var transform: Transform2D=game.player.get_canvas_transform().affine_inverse()
	var size: Vector2=get_viewport().get_visible_rect().size
	var upper: Vector2=transform*Vector2.ZERO;var lower: Vector2=transform*size
	return Rect2(upper,lower-upper)

func scenes_and_storage() -> void:
	await fresh()
	for position in [Vector2(80,80),Vector2(1450,80),Vector2(80,940),Vector2(1450,940)]:
		game.player.position=position;game.camera_rig.follow_now();await frames(4)
		check(game.camera_rig.map_bounds().grow(1).encloses(visible_world()),"地图边界优先，四角视野不露出地图外背景："+str(position))
	await fresh();game.camera_rig.begin_free_look();game.camera_rig.pan_screen(Vector2(-500,-300));await frames(3)
	game.change_location("home",Vector2(640,500));await frames(6)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and game.auto_move.target.is_empty(),"换图清自由查看状态和旧路线")
	check(game.camera_rig.map_bounds().grow(1).encloses(visible_world()),"小屋视野受房间与合法背景填充范围约束")
	await capture("home")
	var saved:=FarmSaveStore.snapshot(game);var items: Dictionary=Inventory.items.duplicate(true);var diamonds: int=Xiaojing.state.diamonds
	game.camera_rig.begin_free_look();game.camera_rig.pan_screen(Vector2(70,0));await frames(2)
	check(FarmSaveStore.restore(game,saved),"查看状态中读取原存档正常恢复")
	await frames(8)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and Inventory.items==items and Xiaojing.state.diamonds==diamonds,"读取存档回跟，不改物品或钻石，不恢复陈旧查看任务")
	check(saved.version==FarmSaveStore.VERSION and not saved.has("camera_rig"),"相机状态不加入原存档结构")
	load("res://tests/star_runner.gd").fixture(game,true)
	for area in ["village","mine_a","mine_b","mine_c","greenhouse"]:
		game.change_location(area,WorldTravel.entry(area));await frames(6)
		game.camera_rig.follow_now();await frames(3)
		check(GameState.location==area and game.camera_rig.mode==game.camera_rig.Mode.FOLLOW,"原地图切换后使用新的跟随状态："+area)
		check(game.camera_rig.map_bounds().grow(1).encloses(visible_world()),"原地图完整视野落在实际背景/填充边界内："+area)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path: String="res://builds/ui05-camera-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append(path)
