extends RefCounted

static func finger(test: Node, at: Vector2, pressed: bool, index: int = 20, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	test.get_viewport().push_input(event,true)

static func tap(test: Node, game: Node, world: Vector2) -> void:
	var screen: Vector2 = game.player.get_canvas_transform()*world
	finger(test,screen,true)
	finger(test,screen,false)

static func finish(test: Node, game: Node, limit: int = 360) -> void:
	for _i in range(limit):
		await test.frames(1)
		if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: return
	test.check(false,"点击操作在限定物理帧内结束："+str(game.auto_move.target))
	game.auto_move.cancel()

static func place(test: Node, game: Node, location: String, at: Vector2) -> void:
	game.hud.close_active_panel()
	game.change_location(location,at)
	await test.frames(5)

static func expand_hotbar(test: Node, game: Node) -> void:
	# UI05保留九个旧索引，但默认只显示相邻三个；选中后会收起。
	if not game.hud.hotbar_expanded and not GameState.modal:
		load("res://tests/story.gd").touch(test,game.hud.cycle_button)
		await test.frames(2)

static func run(test: Node, game: Node) -> void:
	var saved := FarmSaveStore.snapshot(game)
	# 前一套旧摇杆测试模拟按住后打开面板；补齐该手指的系统释放。
	for index in game.touch_input.fingers.keys(): finger(test,Vector2.ZERO,false,index)
	GameState.set_control_mode("tap",false)
	GameClock.minutes=600
	GameClock.running=false
	GameClock.changed.emit()
	Story.assisted_tools=true
	GameState.manual_tool=false
	game.world.resource_field.restore({})
	await place(test,game,"farm",Vector2(656,480))
	test.check(not game.hud.joystick.visible,"新默认点击模式隐藏摇杆")
	# 原生触点经过真实 Viewport、相机平移/缩放，再进入物理移动。
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		test.get_window().size=resolution
		await place(test,game,"farm",Vector2(656,480))
		var goal := Vector2(784,496)
		var screen: Vector2 = game.player.get_canvas_transform()*goal
		test.check(game.touch_input.world_point(screen).distance_to(goal)<0.01,"触点坐标正确逆变换相机："+str(resolution))
		tap(test,game,goal)
		await finish(test,game)
		test.check(game.player.position.distance_to(Vector2(784,496))<1.1,"点击地面实际抵达并停在32px格心："+str(resolution))
	test.get_window().size=Vector2i(1280,720)
	await place(test,game,"home",Vector2(530,336))
	tap(test,game,Vector2(710,336))
	await test.frames(4)
	test.check(game.auto_move.path.size()>5,"室内桌子需要绕行的AStar路线")
	var collision_free := true
	for _i in range(220):
		await test.frames(1)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=game.player.get_node("CollisionShape2D").shape
		query.transform=game.player.global_transform
		query.collision_mask=1
		collision_free = collision_free and game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
		if game.auto_move.state==game.auto_move.State.IDLE: break
	test.check(game.player.position.distance_to(Vector2(720,336))<1.1 and collision_free,"玩家沿路线真实绕过桌子，全程未穿墙")
	# 床现为可点击交互目标；不可达探针改用无交互的实体柜体内部。
	game.auto_move.request(Vector2(464,272))
	await finish(test,game)
	test.check(game.auto_move.state==game.auto_move.State.FAILED and game.player.auto_direction==Vector2.ZERO,"不可通行柜体内部有限失败并停止")
	game.auto_move.request(Vector2(-20,300))
	await finish(test,game)
	test.check(game.auto_move.state==game.auto_move.State.FAILED,"地图外目标立即失败")
	# 从保守网格标为障碍的非格心合法旧位置出发，不强行穿到格心。
	game.player.position=Vector2(549,376)
	await test.frames(2)
	game.auto_move.request(Vector2(720,432))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(720,432))<1.1,"非格心旧档位置能连接安全起点")
	await place(test,game,"farm",Vector2(500,480))
	var linya: Node2D = game.world.get_node("Actors/Linya")
	tap(test,game,linya.global_position+Vector2(0,-18))
	await finish(test,game)
	test.check(game.hud.dialogue.visible and GameState.modal and game.player.position.distance_to(linya.global_position)<=54,"点击林芽自动靠近、面对并打开对话")
	var at: Vector2=game.player.position
	await test.frames(5)
	test.check(game.player.position==at and game.auto_move.target.is_empty(),"对话立即清空待执行动作并停止移动")
	game.hud.dialogue.close_dialogue()
	await place(test,game,"farm",Vector2(656,480))
	game.farm.plots.clear()
	GameState.rest()
	Inventory.items={"carrot_seed":12}
	var cell := Vector2i(20,18)
	var point := Vector2(656,592)
	var stamina: int=GameState.stamina
	tap(test,game,point)
	await test.frames(3)
	test.check(GameState.stamina==stamina and game.farm.plots.is_empty(),"自动行走途中不提前扣体力或修改田地")
	await finish(test,game)
	test.check(game.farm.plots.has("20,18"),"点击未开垦农田自动翻土")
	GameState.select_tool(3)
	var plants: int=Xiaojing.state.plants
	tap(test,game,point)
	await finish(test,game)
	test.check(game.farm.plots["20,18"].crop=="carrot" and Inventory.count("carrot_seed")==11 and Xiaojing.state.plants==plants+1,"点击空田播种复用原事务且小京计数一次")
	var screen: Vector2=game.player.get_canvas_transform()*point
	finger(test,screen,false)
	await test.frames(4)
	test.check(Inventory.count("carrot_seed")==11 and Xiaojing.state.plants==plants+1,"重复释放输入不会重复执行或增加播种计数")
	game.farm.plots["20,18"].watered=false
	tap(test,game,point)
	await finish(test,game)
	test.check(game.farm.plots["20,18"].watered,"智能点击为已播种缺水作物浇水")
	game.farm.plots["20,18"].days=Catalog.crops.carrot.growth_days
	var carrots: int=Inventory.count("carrot")
	tap(test,game,point)
	await finish(test,game)
	test.check(Inventory.count("carrot")==carrots+1 and game.farm.plots["20,18"].crop=="","点击成熟作物自动收获一次")
	# 手动水壶优先；关闭辅助时也不能擅自改成翻土。
	GameState.select_tool(1)
	tap(test,game,Vector2(688,592))
	await finish(test,game)
	test.check(not game.farm.plots.has("21,18"),"工具栏主动选择优先于智能翻土")
	Story.assisted_tools=false
	tap(test,game,Vector2(688,592))
	await finish(test,game)
	test.check(not game.farm.plots.has("21,18"),"关闭操作辅助保留玩家的工具选择")
	Story.assisted_tools=true
	GameState.manual_tool=false
	GameState.stamina=0
	tap(test,game,Vector2(688,592))
	await finish(test,game)
	test.check(not game.farm.plots.has("21,18"),"智能操作仍由原规则拒绝体力不足")
	GameState.rest()
	await place(test,game,"farm",Vector2(280,656))
	GameState.manual_tool=false
	tap(test,game,Vector2(224,620))
	await finish(test,game)
	var hp: int=game.world.resource_field.state.tree_7_20.hp
	test.check(hp<3,"点击树木自动走近并使用斧头")
	await test.frames(50)
	test.check(game.world.resource_field.state.tree_7_20.hp==hp,"单次点击不会无限自动砍树")
	while game.world.resource_field.state.tree_7_20.hp>0:
		tap(test,game,Vector2(224,620))
		await finish(test,game)
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(game.auto_move.navigation.walkable(Vector2i(7,19)),"树木清除后更新寻路占位")
	GameClock.day+=3
	game.world.resource_field.advance_day()
	await test.frames(4)
	game.auto_move.navigation.rebuild()
	test.check(not game.auto_move.navigation.walkable(Vector2i(7,19)),"树木再生后恢复寻路障碍")
	await place(test,game,"farm",Vector2(416,624))
	tap(test,game,Vector2(352,598))
	await finish(test,game)
	test.check(game.world.resource_field.state.rock_11_19.hp<2,"点击石堆自动走近并使用镐")
	await place(test,game,"farm",Vector2(470,432))
	tap(test,game,Vector2(356,402))
	await finish(test,game)
	test.check(game.hud.inventory_panel.visible and GameState.modal,"点击商店自动靠近并打开原交易界面")
	game.hud.inventory_panel.close_panel()
	await place(test,game,"farm",Vector2(760,480))
	tap(test,game,Vector2(820,412))
	await finish(test,game)
	test.check(game.hud.progress_panel.visible,"点击修缮台复用原设施交互")
	game.hud.progress_panel.close_panel()
	await place(test,game,"farm",Vector2(656,480))
	tap(test,game,Vector2(656,400))
	await finish(test,game)
	test.check(GameState.location=="home" and game.auto_move.target.is_empty(),"点击房门自动换图且清除旧路径")
	await place(test,game,"village",Vector2(784,480))
	Story.stage=4
	Story.changed.emit()
	await test.frames(4)
	game.auto_move.request(Vector2(1010,480))
	await finish(test,game)
	test.check(game.auto_move.state==game.auto_move.State.FAILED and game.player.position.x<832,"修桥前无法规划或走到河东")
	Story.stage=5
	Story.changed.emit()
	await test.frames(4)
	game.auto_move.request(Vector2(1010,480))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(1008,496))<1.1,"修桥后刷新网格并真实走过桥梁")
	# 当前移动目标变化时正常追踪；日程开关不影响原 NPC 行为。
	await place(test,game,"farm",Vector2(360,780))
	linya.position=Vector2(500,780)
	linya.set_station(Vector2(650,780))
	GameClock.running=true
	await test.frames(3)
	tap(test,game,linya.global_position+Vector2(0,-18))
	await finish(test,game,450)
	test.check(game.hud.dialogue.visible and game.player.position.distance_to(linya.position)<=54,"移动中的NPC能重新规划后到达并交谈")
	GameClock.running=false
	game.hud.close_active_panel()
	linya.position=Vector2(432,480)
	linya.route.clear()
	# 小京进入相同交互组，不新增旁路剧情逻辑。
	var hidden := Xiaojing.defaults()
	hidden.plants=520
	hidden.plant_serial=520
	hidden.unlocked=true
	Xiaojing.restore(hidden)
	await place(test,game,"village",Vector2(1050,670))
	var xj: Node2D
	for person in game.get_tree().get_nodes_in_group("xiaojing"):
		if person.is_visible_in_tree(): xj=person
	tap(test,game,xj.global_position+Vector2(0,-18))
	await finish(test,game)
	test.check(game.hud.xiaojing_panel.visible and game.hud.xiaojing_panel.page=="main","原生触点点击小京自动寻路并打开关系交互")
	game.hud.xiaojing_panel.close_panel()
	await edge_cases(test,game)
	FarmSaveStore.restore(game,saved)
	await test.frames(5)
	await input_and_mode(test,game)
	FarmSaveStore.restore(game,saved)
	await test.frames(5)

static func input_and_mode(test: Node, game: Node) -> void:
	GameState.set_control_mode("tap",false)
	await place(test,game,"farm",Vector2(656,480))
	game.auto_move.request(Vector2(1008,464))
	await test.frames(12)
	tap(test,game,Vector2(592,496))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(592,496))<1.1,"途中新点击立即替换原目标")
	var executions: int=game.auto_move.execution_count
	var at: Vector2=game.player.position
	await expand_hotbar(test,game)
	load("res://tests/story.gd").touch(test,game.hud.tool_buttons[0])
	await test.frames(4)
	test.check(game.auto_move.state==game.auto_move.State.IDLE and game.player.position==at and game.auto_move.execution_count==executions,"点击工具栏不穿透地图")
	# 地面双指、拖动、系统取消、重复 pressed 都不产生点击。
	var screen: Vector2=game.player.get_canvas_transform()*Vector2(784,496)
	finger(test,screen,true,25)
	finger(test,screen+Vector2(50,0),true,26)
	finger(test,screen,false,25)
	finger(test,screen+Vector2(50,0),false,26)
	await test.frames(3)
	test.check(game.auto_move.state==game.auto_move.State.IDLE,"多点触控不误生成地图目标")
	finger(test,screen,true)
	var drag := InputEventScreenDrag.new()
	drag.index=20
	drag.position=screen+Vector2(80,0)
	test.get_viewport().push_input(drag,true)
	finger(test,screen+Vector2(80,0),false)
	finger(test,screen,true)
	finger(test,screen,false,20,true)
	finger(test,screen,true)
	finger(test,screen,true)
	finger(test,screen,false)
	test.check(game.auto_move.state==game.auto_move.State.IDLE,"拖动、取消与重复按下不变成点击")
	game.hud.inventory_panel.open_panel(false)
	finger(test,screen,true)
	game.hud.inventory_panel.close_panel()
	finger(test,screen,false)
	test.check(game.auto_move.state==game.auto_move.State.IDLE,"面板关闭后的原触点释放不会穿透")
	game.auto_move.request(Vector2(784,480))
	await test.frames(4)
	game.hud.system_panel.open_panel()
	await test.frames(3)
	test.check(game.auto_move.state==game.auto_move.State.IDLE and game.auto_move.target.is_empty(),"打开菜单取消自动移动和待交互")
	load("res://tests/story.gd").touch(test,game.hud.system_panel.control_mode_button)
	test.check(GameState.control_mode=="joystick" and game.hud.joystick.visible,"设置中真实触点切换为备用虚拟摇杆")
	game.hud.system_panel.close_panel()
	var joy: Control=game.hud.joystick
	finger(test,joy.get_global_rect().get_center()+Vector2(40,0),true,30)
	await test.frames(4)
	test.check(game.player.touch_direction.x>0.5,"切换后摇杆仍能独立控制玩家")
	GameState.set_control_mode("tap",false)
	finger(test,joy.get_global_rect().get_center(),false,30)
	test.check(joy.finger==-1 and game.player.touch_direction==Vector2.ZERO and game.player.auto_direction==Vector2.ZERO,"切回点击模式立即清理摇杆和旧触点")
	var before: int=game.auto_move.execution_count
	game.auto_move.request(Vector2(656,592))
	await test.frames(4)
	GameState.set_control_mode("joystick",false)
	await test.frames(20)
	test.check(game.auto_move.target.is_empty() and game.auto_move.execution_count==before,"途中切换模式取消待执行农田交互")
	var saved_mode := FarmSaveStore.snapshot(game)
	GameState.set_control_mode("tap",false)
	test.check(FarmSaveStore.restore(game,saved_mode) and GameState.control_mode=="joystick" and game.hud.joystick.visible,"存档恢复所选摇杆模式")
	await test.frames(5)
	var legacy := saved_mode.duplicate(true)
	legacy.version=5
	legacy.erase("control_mode")
	var migrated := FarmSaveSchema.normalize(legacy)
	test.check(migrated.get("control_mode")=="tap" and migrated.items==legacy.items and migrated.xiaojing==legacy.xiaojing,"v5旧档默认点击模式且保留背包与小京进度")
	test.check(FarmSaveSchema.normalize(migrated)==migrated,"v5到v6迁移幂等")
	var invalid := saved_mode.duplicate(true)
	invalid.control_mode="both"
	test.check(not FarmSaveStore.restore(game,invalid) and GameState.control_mode=="joystick","非法模式整份拒绝且不污染运行状态")
	GameState.set_control_mode("tap",false)
	await place(test,game,"farm",Vector2(656,480))
	game.auto_move.request(Vector2(784,480))
	await test.frames(5)
	Input.action_press("move_left")
	await test.frames(2)
	Input.action_release("move_left")
	test.check(game.auto_move.state==game.auto_move.State.IDLE,"Windows键盘移动中断自动行走")
	game.auto_move.request(Vector2(784,480))
	await test.frames(3)
	game.change_location("home")
	test.check(game.auto_move.path.is_empty() and game.auto_move.target.is_empty(),"场景切换清除路径和交互对象引用")
	await test.frames(5)
	game.auto_move.request(Vector2(720,432))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(720,432))<1.1,"读取/换图后当前地图寻路正常")
	game.auto_move.request(Vector2(720,500))
	await test.frames(3)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	test.check(game.auto_move.target.is_empty() and game.player.auto_direction==Vector2.ZERO,"后台恢复清空旧路径，防止离线继续交互")

static func edge_cases(test: Node, game: Node) -> void:
	# 所有原设施、剧情点和记忆使用同一可达位置搜索；包含桥东风车与共建板。
	for location in ["farm","home","village"]:
		await place(test,game,location,{"farm":Vector2(656,480),"home":Vector2(640,500),"village":Vector2(640,756)}[location])
		game.auto_move.navigation.rebuild()
		var reachable := true
		var missing: Array[String] = []
		for object in game.get_tree().get_nodes_in_group("interactables"):
			if not object.is_visible_in_tree(): continue
			var intent := {"kind":"object","object":object,"point":object.global_position}
			if game.auto_move.navigation.path_to(intent).is_empty():
				reachable=false
				missing.append(object.prompt())
		test.check(reachable,"当前地图所有人物/设施/调查点有合法可达位置："+location+str(missing))
	await place(test,game,"farm",Vector2(656,480))
	var linya: Node2D=game.world.get_node("Actors/Linya")
	linya.position=Vector2(688,480)
	await test.frames(3)
	game.auto_move.request(Vector2(784,480))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(784,496))<1.1,"动态NPC占位参与绕行，玩家不会推挤人物")
	var count: int=game.auto_move.navigation.rebuild_count
	game.auto_move.request(Vector2(816,480))
	await finish(test,game)
	test.check(game.auto_move.navigation.rebuild_count==count,"连续点击复用静态网格，避免每次扫描整张地图")
	linya.position=Vector2(432,480)
	# 两个格心均空闲，但格边存在4px细墙，验证逐边碰撞不会漏判。
	await place(test,game,"farm",Vector2(656,480))
	var thin := StaticBody2D.new()
	thin.position=Vector2(704,490)
	var thin_collider := CollisionShape2D.new()
	var thin_shape := RectangleShape2D.new()
	thin_shape.size=Vector2(4,80)
	thin_collider.shape=thin_shape
	thin.add_child(thin_collider)
	game.world.add_child(thin)
	Events.navigation_changed.emit()
	await test.frames(4)
	game.auto_move.request(Vector2(784,480))
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(784,496))<1.1,"格心之间的薄障碍被逐边检测并正确绕过")
	thin.queue_free()
	Events.navigation_changed.emit()
	await test.frames(4)
	# 创建封闭的交互目标，隔墙不能先扣资源或打开商店。
	await place(test,game,"farm",Vector2(1280,900))
	var fixture := Node2D.new()
	game.world.add_child(fixture)
	var point := Node2D.new()
	point.set_script(load("res://scripts/world/interactable.gd"))
	point.position=Vector2(1400,900)
	point.kind="shop"
	fixture.add_child(point)
	for rect in [Rect2(1348,848,104,8),Rect2(1348,944,104,8),Rect2(1348,848,8,104),Rect2(1444,848,8,104)]:
		var wall := StaticBody2D.new()
		wall.position=rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size=rect.size
		shape.shape=box
		wall.add_child(shape)
		fixture.add_child(wall)
	Events.navigation_changed.emit()
	await test.frames(4)
	var before: int=game.auto_move.execution_count
	game.auto_move.request(point.global_position)
	await finish(test,game)
	test.check(game.auto_move.state==game.auto_move.State.FAILED and game.auto_move.execution_count==before and not GameState.modal,"被障碍包围的目标有限失败，不能隔墙交互")
	fixture.queue_free()
	Events.navigation_changed.emit()
	await test.frames(4)
	# 桌面鼠标与手机原生触点共用解析入口。
	await place(test,game,"farm",Vector2(656,480))
	var screen: Vector2=game.player.get_canvas_transform()*Vector2(784,496)
	var mouse := InputEventMouseButton.new()
	mouse.position=screen
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	test.get_viewport().push_input(mouse,true)
	mouse=mouse.duplicate()
	mouse.pressed=false
	test.get_viewport().push_input(mouse,true)
	await finish(test,game)
	test.check(game.player.position.distance_to(Vector2(784,496))<1.1,"电脑鼠标左键可模拟点击移动")
	# 对话/交易/背包/手记/暂停一律挡住地图触摸，不依赖面板尺寸。
	for panel in [game.hud.inventory_panel,game.hud.story_panel,game.hud.progress_panel,game.hud.xiaojing_panel,game.hud.system_panel]:
		if panel==game.hud.inventory_panel: panel.open_panel(false)
		elif panel==game.hud.progress_panel: panel.open_panel("journal",false)
		else: panel.open_panel()
		var at: Vector2=game.player.position
		tap(test,game,Vector2(848,496))
		await test.frames(3)
		test.check(game.player.position==at and game.auto_move.state==game.auto_move.State.IDLE,"模态面板打开期间禁止地图误触："+str(panel.get_script().resource_path.get_file()))
		panel.close_panel()
