extends "res://tests/runner.gd"
## 回家入口走真实主场景、物理帧与原生触摸，所有保存使用专用测试文件。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
var captures: Array=[]
var capture_mode: bool=false
var transitions: Array[String]=[]

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func saved() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func protected() -> Dictionary:
	var value:=saved();value.erase("location");value.erase("player");return value

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	Events.location_changed.connect(func(area: String): transitions.append(area))
	check("home_return" in game and is_instance_valid(game.home_return),"真实主场景接入独立回家控制器")
	if "home_return" in game and is_instance_valid(game.home_return):
		await direct_and_cancellation()
		await action_phases()
		await blocking_states()
		await furnished_landing()
		await all_maps()
		await native_ui()
		await save_restart()
	UIMetrics.screen_provider=Callable()
	var file:=FileAccess.open("res://builds/home-teleport-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));file.close()
	print("HOME TELEPORT "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh(area: String="farm",at: Vector2=Vector2(800,600)) -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	while game.hud.close_active_panel(): pass
	game.backgrounded=false;game.closing=false;game.awaiting_character_choice=false
	game.player.suspended=false;GameState.restoring=false;GameClock.settling=false
	FarmSaveStore.restore(game,original);GameClock.running=false;GameWeather.enabled=false
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	await Touch.place(self,game,area,at);await frames(4)
	game.hud.toast_time=0

func collision_free() -> bool:
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=game.player.get_node("CollisionShape2D").shape;query.transform=game.player.global_transform
	query.collision_mask=1;query.margin=.02
	return game.player.get_world_2d().direct_space_state.intersect_shape(query,8).is_empty()

func direct_and_cancellation() -> void:
	await fresh();GameState.stamina=37;Inventory.coins=731;Appearance.set_player_gender("female")
	var before:=protected();var calls: int=game.home_return.execution_count;var changed: int=transitions.size()
	var landing: Vector2=game.home_return.landing_point()
	check(landing!=Vector2.INF and game.home_return.can_return(),"农场普通状态有门口合法落点且可一键回家")
	check(game.home_return.request() and not game.home_return.request(),"第一次传送接受，同帧重复请求拒绝")
	await frames(5)
	check(GameState.location=="home" and game.player.position.distance_to(landing)<.1 and collision_free(),"实际进入家内安全点，不落在家具或墙体里")
	check(protected()==before,"回家不改日期分钟、体力、金币物品、角色、任务和房屋进度")
	check(game.home_return.execution_count==calls+1 and transitions.size()==changed+1,"一次回家只切场景一次，不重复执行")
	var home: Dictionary=saved()
	check(not game.home_return.request() and saved()==home,"已在家里再次回家无效且位置资源不变化")
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and game.player.velocity==Vector2.ZERO,"传送后相机恢复跟随、角色实际速度为零")
	await capture("inside")
	await fresh();game.auto_move.request(Vector2(304,496));await frames(7)
	check(not game.auto_move.path.is_empty() or not game.auto_move.target.is_empty(),"取消测试先实际发起远距离自动移动")
	var executed: int=game.auto_move.execution_count
	check(game.home_return.request(),"自动行走途中可直接回家")
	await frames(8)
	check(game.auto_move.target.is_empty() and game.auto_move.path.is_empty() and game.player.auto_direction==Vector2.ZERO and game.player.touch_direction==Vector2.ZERO,"传送清空旧路径、待交互和触控移动向量")
	check(game.auto_move.execution_count==executed and game.player.action_time<=0,"旧自动操作不在家里继续执行或残留动作锁")
	await fresh();check(game.camera_rig.begin_free_look(),"镜头测试先进入真正自由观察")
	game.camera_rig.pan_screen(Vector2(100,30));game.camera_rig.end_free_look();await frames(3)
	check(game.home_return.request(),"偏离人物的自由观察状态仍可回家")
	await frames(5)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and not game.camera_rig.dragging and game.player.get_node("Camera2D").zoom==Vector2.ONE,"回家清理旧观察偏移并采用室内镜头尺度")

func action_phases() -> void:
	for after_impact in [false,true]:
		await fresh("farm",Vector2(624,592));game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false}}
		GameState.stamina=70
		check(game.player.begin_farm_action(game.farm,Vector2i(20,18),"water"),"浇水阶段测试先开始合法工具动作："+str(after_impact))
		if after_impact:
			for _i in range(10):
				await frames(1)
				if game.farm.plots["20,18"].watered: break
			check(game.farm.plots["20,18"].watered,"生效后用例确实等到了水花与一次资源结算")
		var energy: int=GameState.stamina;var plots: Dictionary=game.farm.plots.duplicate(true)
		check(game.home_return.request(),"工具动作中一键回家会取消尚未结束的动作")
		await frames(8)
		check(game.player.farm_action.is_empty() and game.player.action_time<=0 and not game.player.farm_visual.visible,"传送后工具状态与视觉都清理，没有残余水壶锁")
		check(game.farm.plots==plots and GameState.stamina==energy,"生效前不扣资源，已生效后保持已完成结果且不重复扣体力："+str(after_impact))
		check(game.player.sprite.position==game.player.visual_offset(),"工具取消后方案C精灵保持固定脚底，无横向漂移")
	await fresh("farm",Vector2(624,592));game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false}};GameState.stamina=70
	check(game.player.begin_farm_action(game.farm,Vector2i(20,18),"water"),"按住回家用例先开始尚未生效的浇水")
	var point: Vector2=game.hud.home_return_button.get_global_rect().get_center()
	Touch.finger(self,point,true,618);await frames(12)
	check(GameState.location=="farm" and not game.farm.plots["20,18"].watered and GameState.stamina==70 and game.player.farm_action.is_empty(),"回家按下即取消旧农活，长按期间不会先结算浇水或扣体力")
	Touch.finger(self,point,false,618);await frames(5)
	check(GameState.location=="home" and GameState.stamina==70,"长按抬起才传送，仍只执行一次且资源保留")

func denied(description: String) -> void:
	var before:=saved();var executions: int=game.home_return.execution_count
	check(not game.home_return.can_return() and not game.home_return.request() and saved()==before and game.home_return.execution_count==executions,description)

func blocking_states() -> void:
	await fresh();game.hud.inventory_panel.open_panel(false);denied("背包打开时回家拒绝，不穿透菜单");game.hud.inventory_panel.close_panel()
	game.hud.dialogue.open_dialogue("林芽",["先把这句话听完。"]);denied("对话中回家拒绝，不跳过剧情");game.hud.dialogue.close_dialogue()
	game.backgrounded=true;denied("切后台时回家无效");game.backgrounded=false
	game.closing=true;denied("会话关闭中回家无效");game.closing=false
	game.player.suspended=true;denied("玩家被挂起时回家无效");game.player.suspended=false
	GameState.restoring=true;denied("正在读档时回家无效");GameState.restoring=false
	GameClock.settling=true;denied("跨天结算中回家无效");GameClock.settling=false
	game.awaiting_character_choice=true;denied("新游戏外观未确认时回家无效");game.awaiting_character_choice=false
	Housing.busy=true;denied("家具或住宅事务中回家不能重入");Housing.busy=false
	game.farm.committing=true;denied("农田生效事务中回家不能插入半笔资源结算");game.farm.committing=false
	GameClock.minutes=1440;denied("已到午夜优先原疲劳日结，不能靠回家跳过");GameClock.minutes=360
	MineState.state.expedition={"day":GameClock.day,"visited":[],"mined":[],"energy":0,"areas":[]}
	denied("进行中矿洞考察不能跳过原回程提交");MineState.state.expedition={}
	load("res://tests/star_runner.gd").fixture(game,true);await frames(4)
	game.change_location("greenhouse",Vector2(640,730));await frames(5)
	StarStory.state.wedding_phase=3;denied("温室正式婚礼演出中不可突然回家")
	await fresh()

func furnished_landing() -> void:
	await fresh("home",Vector2(400,496));Housing.state.owned.chair=1
	check(Housing.place("chair","home",Vector2i(19,15)),"用合法家具摆放规则在默认室内出生点边缘放椅子")
	await frames(5)
	var point: Vector2=WorldTravel.entry("home")
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=game.player.get_node("CollisionShape2D").shape
	query.transform=Transform2D(0,point);query.collision_mask=1;query.margin=.02
	check(not game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"夹具实际证明固定640500出生点已被椅子占用")
	game.change_location("farm",Vector2(800,600));await frames(5)
	var furniture: Dictionary=Housing.snapshot();var landing: Vector2=game.home_return.landing_point()
	check(landing!=Vector2.INF and landing.distance_to(point)>10 and game.home_return.request(),"回家选择门旁合法点，避免进入玩家新家具内部")
	await frames(6)
	check(collision_free() and Housing.snapshot()==furniture,"家具不删除、不搬走、不复制，人物安全进入家中")
	for level in range(1,5):
		await fresh()
		var housing: Dictionary=Housing.defaults(GameClock.day);housing.level=level;housing.builtins=HomeLayout.default_builtins(level);Housing.restore(housing);await frames(4)
		check(game.home_return.request(),"各住宅等级均能回家："+str(level));await frames(5)
		check(collision_free() and Housing.state.level==level,"各等级落点合法且住宅等级不改变："+str(level))

func late_fixture() -> void:
	load("res://tests/star_runner.gd").fixture(game,true)
	var chapter: Dictionary=ChapterTwo.defaults();chapter.policy="rotation"
	for quest in ChapterTwo.definitions.slice(0,8):
		chapter.completed.append(quest.id)
		for fact in quest.conditions:
			if fact not in chapter.facts: chapter.facts.append(fact)
	ChapterTwo.restore(chapter)
	var eco: Dictionary=LakeEcology.defaults(GameClock.day);eco.restored=true;eco.cycle=true;eco.plants=3;eco.health=95;LakeEcology.restore(eco)
	var exploration: Dictionary=Exploration.defaults();exploration.unlocked=Exploration.AREAS.duplicate()
	exploration.forest={"step":4,"open":true};exploration.lake={"water":0,"flow":1,"open":true};exploration.temple={"mirror":2,"step":3,"open":true}
	for id in Exploration.data.points:
		if Exploration.data.points[id].kind=="note": exploration.facts.append(id)
	exploration.facts.append("drain_plate");exploration.facts.append("lake_lower_opened");Exploration.restore(exploration)
	Letters.refresh()
	await frames(5)

func all_maps() -> void:
	await fresh();await late_fixture()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"跨地图验证沿用既有完整合法剧情/矿业/隐图夹具")
	for area in ["village","mine_a","mine_b","mine_c","mist_forest","lake_ruins","old_temple","greenhouse"]:
		game.change_location(area);await frames(5)
		check(GameState.location==area,"先实际进入原地图："+area)
		var before:=protected()
		check(game.home_return.request(),"原地图均可一键回到家内："+area);await frames(5)
		check(GameState.location=="home" and collision_free() and protected()==before,"换图只改玩家位置，保留原地图全部开关和产出："+area)
	game.change_location("mine_c",Vector2(208,744));await frames(5)
	check(AbyssState.unlock() and AbyssState.enter(),"通过真实矿区升降机入口解锁并进入深渊")
	await frames(4);AbyssState.state.air=43;GameState.stamina=31
	var abyss: Dictionary=AbyssState.snapshot();var before:=protected()
	check(game.home_return.request(),"深渊中可直接回家，不调用救援")
	await frames(5)
	check(AbyssState.snapshot()==abyss and protected()==before and GameState.location=="home","深渊空气、检查点、救援数和宝箱状态原样保留")
	await fresh()

func native_ui() -> void:
	for size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(4);game.hud.update_safe_area();await frames(4);await fresh()
		var button: Button=game.hud.home_return_button;var safe: Rect2=game.hud.safe.get_global_rect()
		check(button.visible and not button.disabled and button.size.x>=48 and button.size.y>=48 and safe.grow(.5).encloses(button.get_global_rect()),"原生回家按钮位于安全区且触区足够："+str(size))
		check(not button.get_global_rect().intersects(game.hud.atlas_button.get_global_rect()),"回家与地图按钮不重叠："+str(size))
		await capture("button_"+str(size.x)+"x"+str(size.y))
		var point: Vector2=button.get_global_rect().get_center();var before:=protected();var executions: int=game.home_return.execution_count
		Touch.finger(self,point,true,620);Touch.finger(self,point,false,620);await frames(6)
		check(GameState.location=="home" and game.home_return.execution_count==executions+1 and protected()==before,"真正原生点按钮只传送一次且无地图误触："+str(size))
		Touch.finger(self,point,false,620);await frames(3)
		check(game.home_return.execution_count==executions+1 and game.auto_move.target.is_empty(),"按钮关闭/禁用后的旧释放不再传送或寻路："+str(size))
	get_window().size=Vector2i(1280,720);await frames(4);await fresh()
	var point: Vector2=game.hud.home_return_button.get_global_rect().get_center();var at: Vector2=game.player.position;var count: int=game.home_return.execution_count
	Touch.finger(self,point,true,621);Touch.finger(self,Vector2(600,400),true,622)
	Touch.finger(self,point,false,621);Touch.finger(self,Vector2(600,400),false,622);await frames(4)
	check(GameState.location=="farm" and game.home_return.execution_count==count and game.player.position==at,"双指手势不能误确认一键传送")
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.pressed=true
	get_viewport().push_input(mouse,true);Touch.finger(self,point,true,626)
	mouse.pressed=false;get_viewport().push_input(mouse,true);Touch.finger(self,point,false,626);await frames(4)
	check(GameState.location=="farm" and game.home_return.execution_count==count,"混合鼠标与触屏不会重复或误确认回家")
	Touch.finger(self,point,true,623)
	var drag:=InputEventScreenDrag.new();drag.index=623;drag.position=point+Vector2(-40,30);drag.relative=Vector2(-40,30);get_viewport().push_input(drag,true)
	Touch.finger(self,drag.position,false,623);await frames(4)
	check(GameState.location=="farm" and game.home_return.execution_count==count,"拖过按钮只取消，不误触回家")
	Touch.finger(self,point,true,624);Touch.finger(self,point,false,624);await frames(6)
	check(GameState.location=="home" and game.home_return.execution_count==count+1,"多指和拖动取消后下一次正常点击恢复")
	await fresh();GameState.set_control_mode("joystick",false);await frames(3)
	point=game.hud.home_return_button.get_global_rect().get_center();Touch.finger(self,point,true,625);Touch.finger(self,point,false,625);await frames(5)
	check(GameState.location=="home" and GameState.control_mode=="joystick" and game.hud.joystick.visible,"备用摇杆模式原生回家仍有效，且不重置操作方式")
	await fresh();UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	game.hud.reflow_touch_controls();game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(5)
	var button: Button=game.hud.home_return_button
	check(button.size.y>=UIMetrics.minimum_target() and button.size.x>=UIMetrics.minimum_target() and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect()),"480DPI与安全区换算后回家按钮保留实际触区")
	await capture("dpi480_safe");UIMetrics.screen_provider=Callable();game.hud.update_safe_area();game.hud.reflow_touch_controls();await frames(4)

func save_restart() -> void:
	await fresh();Appearance.set_player_gender("female");Inventory.coins=7321;GameState.stamina=34;GameState.set_control_mode("joystick",false)
	check(game.home_return.request(),"存档验证先实际传送回家");await frames(5)
	var path: String="user://home-teleport-%d.json" % Time.get_ticks_usec();var proof:=saved()
	check(FarmSaveStore.write(game,path),"回家后沿原v25临时文件/备份协议写入完整存档")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;await frames(9);game.persistence_enabled=false
	check(saved()==proof and GameState.location=="home" and collision_free(),"真实重建主场景后完整恢复家内坐标、资源与方案C选择")
	check(Appearance.gender("player")=="female" and GameState.control_mode=="joystick" and not game.home_return.busy and game.auto_move.target.is_empty(),"重启不重放传送或旧路径，保留性别和备用摇杆")
	check(not game.home_return.request(),"读档已在家内时回家按钮仍正确拒绝重复请求")

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(5);await RenderingServer.frame_post_draw
	var path: String="res://builds/home-teleport-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
