extends "res://tests/runner.gd"
## 浇水动作坐标、手势按下世界锚点、白天有限恢复；可--movement-only复现旧代码。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
var recovery: Node
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(6)
	original=FarmSaveStore.snapshot(game)
	recovery=get_node_or_null("/root/Recovery")
	await watering_lock()
	await press_anchor()
	if "--movement-only" not in OS.get_cmdline_user_args(): await daytime_recovery()
	release_controls()
	print("CONTROL RECOVERY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func release_controls() -> void:
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	game.player.touch_direction=Vector2.ZERO;game.player.auto_direction=Vector2.ZERO
	game.auto_move.cancel()
	for index in game.touch_input.fingers.keys(): Touch.finger(self,Vector2.ZERO,false,index)
	game.touch_input.reset()

func prepare(at: Vector2, facing: Vector2, mode: String) -> void:
	release_controls()
	while game.hud.close_active_panel(): pass
	GameState.set_control_mode(mode,false)
	game.player.action_time=0
	await Touch.place(self,game,"farm",at)
	game.player.facing=facing
	game.player.sprite.position=Vector2(0,-18)
	GameState.stamina=GameState.max_stamina()
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false},"20,17":{"crop":"carrot","days":0,"watered":false},"19,18":{"crop":"carrot","days":0,"watered":false}}

func watering_lock() -> void:
	await prepare(Vector2(624,592),Vector2.RIGHT,"tap")
	var start: Vector2=game.player.global_position
	var target: Vector2i=game.player.target_cell()
	Input.action_press("move_up")
	check(target==Vector2i(20,18) and game.farm.use_tool(target,"water"),"按住W同时向右浇水进入真实农活事务")
	var held_position := true
	var held_facing := true
	for i in range(14):
		await frames(1)
		held_position=held_position and game.player.global_position.distance_to(start)<.01
		held_facing=held_facing and game.player.facing==Vector2.RIGHT
	check(held_position,"浇水动作前0.233秒锁住真实脚底位置，不被W推动")
	check(held_facing,"浇水动作期间保持最初朝向，不切换到按住方向")
	check(game.farm.plots["20,18"].watered and not game.farm.plots["20,17"].watered and not game.farm.plots["19,18"].watered,"按住方向不误浇相邻地格")
	await frames(8)
	check(game.player.global_position.y<start.y-8,"动作结束后仍按住W可以正常继续移动")
	release_controls()
	await prepare(Vector2(656,592),Vector2.LEFT,"joystick")
	start=game.player.global_position
	game.player.touch_direction=Vector2.UP
	check(game.farm.use_tool(game.player.target_cell(),"water"),"摇杆保持方向时仍可发起一次合法浇水")
	held_position=true;held_facing=true
	for i in range(14):
		await frames(1)
		held_position=held_position and game.player.global_position.distance_to(start)<.01
		held_facing=held_facing and game.player.facing==Vector2.LEFT
	check(held_position and held_facing,"摇杆浇水同样锁住动作位置与朝向")
	await frames(8)
	check(game.player.global_position.y<start.y-8,"摇杆动作结束恢复原方向移动")
	release_controls()
	await prepare(Vector2(624,592),Vector2.RIGHT,"tap")
	var max_offset := 0.0
	for cycle in range(3):
		game.farm.plots["20,18"].watered=false
		check(game.farm.use_tool(Vector2i(20,18),"water"),"重复独立浇水用于检查视觉回原点："+str(cycle))
		for i in range(20):
			await frames(1)
			max_offset=maxf(max_offset,absf(game.player.sprite.position.x))
	check(max_offset<.01 and absf(game.player.sprite.position.x)<.01,"横向浇水精灵x不逐帧累加，连续动作保持与碰撞点对齐")
	game.farm.plots["20,18"].watered=false
	game.farm.use_tool(Vector2i(20,18),"water")
	start=game.player.global_position
	game.auto_move.request(Vector2(752,624))
	await frames(10)
	check(game.player.global_position.distance_to(start)<.01 and not game.auto_move.target.is_empty(),"动作中点击新目标保留导航意图但等待动作结束")
	await Touch.finish(self,game,500)
	check(game.auto_move.state==game.auto_move.State.IDLE and game.player.global_position.distance_to(start)>48,"动作结束后自动路径正常继续而不丢失新目标")

func press_anchor() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution
		await prepare(Vector2(656,480),Vector2.DOWN,"tap")
		var selected_world := Vector2(656,592)
		var screen: Vector2=game.player.get_canvas_transform()*selected_world
		check(not game.touch_input.ui_at(screen),"坐标回归选取真实非UI地图触点："+str(resolution))
		Touch.finger(self,screen,true,41)
		game.player.global_position+=Vector2(96,0)
		game.player.get_node("Camera2D").reset_smoothing()
		game.player.get_node("Camera2D").force_update_scroll()
		await frames(3)
		check(game.touch_input.world_point(screen).distance_to(selected_world)>32,"按住触点期间相机确已移动："+str(resolution))
		Touch.finger(self,screen,false,41)
		check(game.auto_move.target.get("kind","")=="plot" and game.auto_move.target.get("cell",Vector2i(-1,-1))==Vector2i(20,18),"释放时沿用按下看到的农田格，不随相机偏移改目标："+str(resolution))
		game.auto_move.cancel()
	get_window().size=Vector2i(1280,720)
	await prepare(Vector2(656,480),Vector2.DOWN,"tap")
	var selected_world := Vector2(656,592)
	var screen: Vector2=game.player.get_canvas_transform()*selected_world
	var mouse := InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=screen;mouse.pressed=true
	get_viewport().push_input(mouse,true)
	game.player.global_position+=Vector2(96,0);game.player.get_node("Camera2D").reset_smoothing();game.player.get_node("Camera2D").force_update_scroll();await frames(3)
	mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=screen;mouse.pressed=false;get_viewport().push_input(mouse,true)
	check(game.auto_move.target.get("cell",Vector2i(-1,-1))==Vector2i(20,18),"桌面鼠标按下/释放同样锁定最初世界目标")
	game.auto_move.cancel()
	await prepare(Vector2(656,480),Vector2.DOWN,"tap")
	screen=game.player.get_canvas_transform()*selected_world
	Touch.finger(self,screen,true,42);Touch.finger(self,screen,true,42);Touch.finger(self,screen,false,42)
	check(game.auto_move.target.is_empty(),"重复pressed不会重新开始并提交重复地图手势")
	Touch.finger(self,screen,true,43)
	var drag := InputEventScreenDrag.new();drag.index=43;drag.position=screen+Vector2(60,0);drag.relative=Vector2(60,0);get_viewport().push_input(drag,true)
	Touch.finger(self,screen+Vector2(60,0),false,43)
	check(game.auto_move.target.is_empty(),"拖动手势不会被当作点击去浇另一格")
	Touch.finger(self,screen,true,44);Touch.finger(self,screen+Vector2(20,0),true,45);Touch.finger(self,screen,false,44);Touch.finger(self,screen+Vector2(20,0),false,45)
	check(game.auto_move.target.is_empty(),"多指手势不会释放为单指地图动作")
	game.hud.inventory_panel.open_panel(false)
	Touch.finger(self,screen,true,46);game.hud.inventory_panel.close_panel();Touch.finger(self,screen,false,46)
	check(game.auto_move.target.is_empty(),"关闭UI后的旧手指释放不能穿透地图")

func daytime_recovery() -> void:
	check(recovery!=null,"有限白天恢复系统已接入")
	if recovery==null: return
	FarmSaveStore.restore(game,original);GameClock.running=false;GameWeather.enabled=false
	recovery.restore(recovery.defaults(GameClock.day))
	await prepare(Vector2(784,496),Vector2.UP,"tap")
	Touch.tap(self,game,Vector2(784,452));await Touch.finish(self,game,360)
	check(game.hud.recovery_panel.visible and GameState.modal,"点击屋东休息椅可自动靠近并打开恢复界面")
	game.hud.close_active_panel()
	var day: int=GameClock.day
	GameClock.minutes=600;GameState.stamina=10
	var farm_before: Dictionary=game.farm.plots.duplicate(true)
	var fish_before: Dictionary=Aquaculture.snapshot()
	var resources_before: Dictionary=game.world.resource_field.state.duplicate(true)
	var days_advanced := [0]
	var on_day := func(): days_advanced[0]+=1
	GameClock.day_advanced.connect(on_day)
	check(recovery.rest(day,0) and GameState.stamina==25 and GameClock.minutes==620,"白天在休息椅恢复15体力，消耗20游戏分钟")
	var proof: Dictionary=recovery.snapshot()
	check(not recovery.rest(day,0) and GameState.stamina==25 and GameClock.minutes==620 and recovery.snapshot()==proof,"重复确认同一次休息不重复恢复或快进")
	check(recovery.rest(day,1) and recovery.rest(day,2) and GameState.stamina==55 and GameClock.minutes==660,"同日可分别确认余下两次有限休息")
	check(not recovery.rest(day,3) and recovery.snapshot().rests==3,"第四次休息被统一状态层拒绝")
	check(GameClock.day==day and days_advanced[0]==0 and game.farm.plots==farm_before and Aquaculture.snapshot()==fish_before and game.world.resource_field.state==resources_before,"椅子休息不跳日、不成长作物鱼类或刷新矿石")
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and recovery.snapshot().rests==3 and not recovery.rest(day,3),"存读档保留已用休息次数，不刷新白天额度")
	await frames(4)
	recovery.restore(recovery.defaults(GameClock.day));GameState.stamina=40
	game.change_location("home",Vector2(775,365));await frames(4)
	check(not recovery.rest(GameClock.day,0) and not GameClock.request_sleep(GameClock.day),"白天床边既不能睡觉也不能冒充休息椅恢复")
	await prepare(Vector2(784,496),Vector2.UP,"joystick")
	GameClock.minutes=1419;GameState.stamina=40
	check(recovery.rest(GameClock.day,0) and GameClock.minutes==1439 and GameClock.day==day,"23:39可以完成20分钟休息且保持当天")
	recovery.restore(recovery.defaults(GameClock.day));GameClock.minutes=1420
	check(not recovery.rest(GameClock.day,0) and GameClock.minutes==1420,"23:40以后不能用休息跨越午夜结算")
	GameClock.minutes=600;GameState.stamina=GameState.max_stamina()
	check(not recovery.rest(GameClock.day,0) and recovery.snapshot().rests==0,"满体力休息不浪费每日次数")
	GameState.stamina=GameState.max_stamina()-4
	check(recovery.rest(GameClock.day,0) and GameState.stamina==GameState.max_stamina(),"椅子恢复限制在体力上限")
	Inventory.items.carrot=5;Inventory.items.potato=5;Inventory.items.wheat=5
	GameState.stamina=20
	check(recovery.eat_crop("carrot") and GameState.stamina==28 and Inventory.count("carrot")==4,"胡萝卜零食消耗一份恢复8")
	check(recovery.eat_crop("potato") and GameState.stamina==40 and Inventory.count("potato")==4,"土豆零食消耗一份恢复12")
	check(recovery.eat_crop("wheat") and GameState.stamina==44 and Inventory.count("wheat")==4,"小麦零食消耗一份恢复4")
	var inventory_before: Dictionary=Inventory.items.duplicate(true)
	check(recovery.eat_crop("carrot") and Inventory.count("carrot")==int(inventory_before.carrot)-1 and GameState.stamina==52,"体力未满时第四份零食仍消耗一份并恢复8体力")
	inventory_before=Inventory.items.duplicate(true)
	saved=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and recovery.snapshot().snacks==3,"读档保留旧零食兼容字段，该字段不再限制食用")
	recovery.restore(recovery.defaults(GameClock.day));GameState.stamina=GameState.max_stamina()
	check(not recovery.eat_crop("carrot") and Inventory.items==inventory_before and recovery.snapshot().snacks==0,"满体力食用不消耗食材和次数")
	GameState.stamina=40
	check(not recovery.eat_crop("carrot_seed") and not recovery.eat_crop("unknown_food"),"种子和未知物品不能当作零食")
	Inventory.items.erase("carrot")
	check(not recovery.eat_crop("carrot") and recovery.snapshot().snacks==0,"缺少食材不凭空恢复体力")
	GameClock.minutes=1200
	check(GameClock.request_sleep(day) and days_advanced[0]==1 and recovery.snapshot().rests==0 and recovery.snapshot().snacks==0,"合法睡眠唯一跨日后刷新休息次数与兼容记录")
	GameClock.day_advanced.disconnect(on_day)
	var old := FarmSaveStore.snapshot(game)
	old.version=12;old.erase("appearance");old.erase("recovery")
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.recovery.rests==0 and migrated.coins==old.coins and migrated.xiaojing==old.xiaojing,"v12迁移仅增加恢复日限，保留资源和小京进度")
	var invalid := FarmSaveStore.snapshot(game)
	invalid.recovery.rests=4
	check(not FarmSaveStore.valid(invalid),"拒绝非法超过每日休息上限的存档")
