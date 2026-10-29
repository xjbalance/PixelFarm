extends "res://tests/runner.gd"
## 单次农活事务与生效帧；旧规则直接事务入口、真实玩家入口分别验证。
const Touch=preload("res://tests/touch_navigation.gd")
const CELL:=Vector2i(20,18)
const POINT:=Vector2(656,592)
var initial: Dictionary
var facts: Array=[]
var effect_count: int=0
var action_count: int=0

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	Events.farm_committed.connect(func(kind: String,cell: Vector2i,crop: String,serial: int): facts.append({"kind":kind,"cell":cell,"crop":crop,"serial":serial}))
	Events.farm_effect.connect(func(_at: Vector2,_kind: String): effect_count+=1)
	Events.farm_action.connect(func(_kind: String): action_count+=1)
	await basic_rules()
	await count_boundary()
	await transaction_reentry()
	if "--rules-only" not in OS.get_cmdline_user_args():
		check(game.player.has_method("begin_farm_action"),"玩家具有独立农活开始/生效/结束入口")
		if game.player.has_method("begin_farm_action"):
			await action_phases()
			await four_directions()
			await interruption_rules()
			await real_input()
	print("FARMING ACTIONS RESULT: %d checks, %d failures" % [checked,failed])
	for input in ["move_left","move_right","move_up","move_down"]: Input.action_release(input)
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh(at: Vector2=Vector2(624,592),mode: String="tap") -> void:
	for input in ["move_left","move_right","move_up","move_down"]: Input.action_release(input)
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	GameClock.minutes=600;GameState.set_control_mode(mode,false);GameState.manual_tool=false
	game.tutorial.restore(GameTutorial.defaults(true))
	await Touch.place(self,game,"farm",at)
	game.farm.plots.clear();GameState.stamina=100;Inventory.items={"carrot_seed":999,"potato_seed":6,"wheat_seed":6}
	game.player.action_time=0;game.action_cooldown=0
	facts.clear();effect_count=0;action_count=0

func stamp() -> Dictionary:
	return AbyssSaveSchema.canonical({"plots":game.farm.plots.duplicate(true),"items":Inventory.items.duplicate(true),"stamina":GameState.stamina,"plants":Xiaojing.state.plants,"serial":Xiaojing.state.plant_serial,"coins":Inventory.coins})

func plot(crop: String="",days: int=0,watered: bool=false) -> void:
	game.farm.plots["20,18"]={"crop":crop,"days":days,"watered":watered}

func basic_rules() -> void:
	await fresh()
	check(game.farm.use_tool(CELL,"hoe") and GameState.stamina==98 and game.farm.plots.has("20,18"),"正常翻土只形成目标一格并扣原2点体力")
	var before:=stamp();var effects: int=effect_count
	check(not game.farm.use_tool(CELL,"hoe") and stamp()==before and effect_count==effects,"重复翻土不扣体力、不重发首次翻土效果")
	Inventory.items.erase("carrot_seed");before=stamp()
	check(not game.farm.use_tool(CELL,"carrot_seed") and stamp()==before,"无种子播种失败不扣体力或改土地")
	Inventory.items.carrot_seed=3
	check(game.farm.use_tool(CELL,"carrot_seed") and Inventory.count("carrot_seed")==2 and GameState.stamina==97 and game.farm.plots["20,18"].crop=="carrot" and Xiaojing.state.plants==1,"正常播种种子、目标地块、体力和成功计数一起提交")
	before=stamp();effects=effect_count
	check(not game.farm.use_tool(CELL,"potato_seed") and stamp()==before and effect_count==effects,"已占用土地不能覆盖播种，也不消耗另一类种子")
	check(game.farm.use_tool(CELL,"water") and GameState.stamina==96 and game.farm.plots["20,18"].watered,"正常浇水只扣原1点体力并湿润目标格")
	before=stamp();effects=effect_count
	check(not game.farm.use_tool(CELL,"water") and stamp()==before and effect_count==effects,"已浇水地块不会重复扣费或产生成功水花")
	before=stamp()
	check(not game.farm.use_tool(CELL,"hand") and stamp()==before,"未成熟作物不能收获，资源保持")
	game.farm.plots["20,18"].days=Catalog.crops.carrot.growth_days
	Inventory.items.carrot=Inventory.MAX_STACK;before=stamp()
	check(not game.farm.use_tool(CELL,"hand") and stamp()==before,"背包满时保留成熟作物、体力和奖励")
	Inventory.items.carrot=4
	check(game.farm.use_tool(CELL,"hand") and Inventory.count("carrot")==5 and game.farm.plots["20,18"].crop=="" and GameState.stamina==95,"成熟收获只增加一份物品，地块清空且扣原1点体力")
	before=stamp();effects=effect_count
	check(not game.farm.use_tool(CELL,"hand") and stamp()==before and effect_count==effects,"同株作物不能重复领取收获或成功反馈")
	for tool in ["hoe","carrot_seed","water","hand"]:
		game.farm.plots.clear()
		if tool!="hoe": plot("carrot" if tool=="hand" else "",Catalog.crops.carrot.growth_days if tool=="hand" else 0)
		GameState.stamina=0;before=stamp()
		check(not game.farm.use_tool(CELL,tool) and stamp()==before,"体力不足拒绝合法目标农活且不部分扣物："+tool)
	await fresh()
	FarmProgress.built.append("irrigation")
	check(game.farm.use_tool(Vector2i(17,16),"hoe") and game.farm.plots["17,16"].watered,"引水渠覆盖区仍在翻土时自动供水")
	check(game.farm.use_tool(Vector2i(21,18),"hoe") and not game.farm.plots["21,18"].watered,"引水渠作用范围没有扩大到覆盖区之外")
	Events.farm_effect.emit(POINT,"播种");Events.farm_action.emit("播种")
	check(Xiaojing.state.plants==0,"纯动画和音效展示信号不能增加成功播种计数")

func count_boundary() -> void:
	await fresh()
	var valid:=true
	for i in range(519):
		game.farm.plots.erase("20,18");GameState.stamina=100
		valid=game.farm.use_tool(CELL,"hoe") and game.farm.use_tool(CELL,"carrot_seed") and valid
	check(valid and Xiaojing.state.plants==519 and Xiaojing.state.plant_serial==519 and not Xiaojing.state.letter_ready,"519次真实成功种植保持519计数且不提前来信")
	var before:=stamp()
	for i in range(4): game.farm.use_tool(CELL,"carrot_seed")
	check(stamp()==before,"第520次前重复点已占用格不扣种或增加计数")
	game.farm.plots.erase("20,18");GameState.stamina=100
	check(game.farm.use_tool(CELL,"hoe") and game.farm.use_tool(CELL,"carrot_seed") and Xiaojing.state.plants==520 and Xiaojing.state.plant_serial==520,"第520株成功种植严格只增加一次计数")
	var serial: int=Xiaojing.state.plant_serial
	Events.farm_action.emit("播种");Events.farm_effect.emit(POINT,"播种");Xiaojing.commit_successful_plant(serial)
	check(Xiaojing.state.plants==520,"第520株的重复展示/同序号不会多计一次")
	GameClock.minutes=1200;Xiaojing.check_night()
	check(Xiaojing.state.letter_ready and not Xiaojing.state.unlocked,"原520播种条件仍在合适夜晚准备一次来信")

func transaction_reentry() -> void:
	await fresh()
	var callback_state: Dictionary={"fired":false,"accepted":false}
	var repeat_hoe:=func():
		if callback_state.fired: return
		callback_state.fired=true;callback_state.accepted=game.farm.use_tool(CELL,"hoe")
	GameState.changed.connect(repeat_hoe)
	game.farm.use_tool(CELL,"hoe")
	GameState.changed.disconnect(repeat_hoe)
	check(callback_state.fired and not callback_state.accepted and GameState.stamina==98 and facts.size()==1,"体力changed同步重入不能第二次翻土或扣费")
	await fresh();plot();Inventory.items.carrot_seed=3
	callback_state={"fired":false,"accepted":false,"snapshot":{}}
	var repeat_seed:=func():
		if callback_state.fired: return
		callback_state.fired=true;callback_state.snapshot=stamp();callback_state.accepted=game.farm.use_tool(CELL,"carrot_seed")
	Inventory.changed.connect(repeat_seed)
	game.farm.use_tool(CELL,"carrot_seed")
	Inventory.changed.disconnect(repeat_seed)
	check(callback_state.fired and not callback_state.accepted and Inventory.count("carrot_seed")==2 and GameState.stamina==99 and Xiaojing.state.plants==1 and facts.size()==1,"库存changed同步重入不重复播种、不刷520计数")
	check(callback_state.snapshot==stamp(),"库存通知内观察到完整播种结果，不是已扣种却尚未种下的半事务")
	await fresh();plot("carrot",Catalog.crops.carrot.growth_days);Inventory.items.carrot=2
	callback_state={"fired":false,"accepted":false,"snapshot":{}}
	var repeat_harvest:=func():
		if callback_state.fired: return
		callback_state.fired=true;callback_state.snapshot=stamp();callback_state.accepted=game.farm.use_tool(CELL,"hand")
	Inventory.changed.connect(repeat_harvest)
	game.farm.use_tool(CELL,"hand")
	Inventory.changed.disconnect(repeat_harvest)
	check(callback_state.fired and not callback_state.accepted and Inventory.count("carrot")==3 and GameState.stamina==99 and facts.size()==1,"收获库存changed同步重入不能领取第二份作物")
	check(callback_state.snapshot==stamp(),"收获通知内地块、物品和体力均是已完成状态")

func setup_target(tool: String) -> void:
	game.farm.plots.clear()
	if tool!="hoe": plot("carrot" if tool in ["water","hand"] else "",Catalog.crops.carrot.growth_days if tool=="hand" else 0)

func wait_action(limit: int=45) -> void:
	for i in range(limit):
		await frames(1)
		if game.player.farm_action.is_empty() and game.player.action_time<=0: return
	check(false,"农活动作在有限物理帧内结束")

func begin(tool: String) -> bool:
	return game.player.begin_farm_action(game.farm,CELL,tool)

func action_phases() -> void:
	for tool in ["hoe","carrot_seed","water","hand"]:
		await fresh();setup_target(tool)
		var before:=stamp()
		check(begin(tool),"合法农活开始并锁定目标："+tool)
		check(stamp()==before and facts.is_empty() and effect_count==0 and action_count==0,"开始帧不提前改变土地、扣物/体力或发成功反馈："+tool)
		await frames(4)
		check(stamp()==before and facts.is_empty(),"动作前摇阶段仍保留原完整状态："+tool)
		check(not begin(tool),"前一农活未结束时重复开始被拒绝："+tool)
		await frames(5)
		check(facts.size()==1 and effect_count==1 and action_count==1 and facts[0].cell==CELL,"生效帧地块事务、水花/音效事实只发生一次："+tool)
		var committed:=stamp()
		await wait_action()
		check(stamp()==committed and facts.size()==1 and effect_count==1 and game.player.farm_action.is_empty() and game.player.action_time==0,"结束阶段不重放提交并释放动作状态："+tool)
		check(game.player.sprite.frame%4 in [0,2] and absf(game.player.sprite.position.x)<.01,"结束后恢复待机且无横向累计偏移："+tool)
	await fresh();plot();Inventory.items.erase("carrot_seed")
	var before:=stamp()
	check(not begin("carrot_seed") and game.player.farm_action.is_empty() and stamp()==before,"无种子时开始阶段直接拒绝，不空播或扣费")
	await fresh();plot("carrot",Catalog.crops.carrot.growth_days);Inventory.items.carrot=999;before=stamp()
	check(not begin("hand") and game.player.farm_action.is_empty() and stamp()==before,"满包收获在开始阶段拒绝，作物保持成熟")
	await fresh();plot("carrot");GameState.stamina=0;before=stamp()
	check(not begin("water") and game.player.farm_action.is_empty() and stamp()==before,"体力不足不进入农活动画或预扣资源")

func four_directions() -> void:
	var directions: Array[Vector2]=[Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
	for direction in directions:
		for tool in ["hoe","carrot_seed","water","hand"]:
			await fresh(POINT-direction*32);setup_target(tool)
			var at: Vector2=game.player.position
			var accepted:=begin(tool)
			var stable:=true
			for i in range(18):
				await frames(1)
				stable=stable and game.player.position==at and game.player.facing==direction and absf(game.player.sprite.position.x)<.01
			check(accepted and stable and facts.size()==1 and facts[0].cell==CELL,"四方向工具面朝目标且身体/碰撞体不横移："+tool+" "+str(direction))
	await fresh()
	var stable:=true
	var max_foot_move:=0.0
	var max_sprite_x:=0.0
	# 恢复干土仅为隔离连续动画累积；产品中的已湿地块仍在规则测试中严格拒绝。
	for i in range(20):
		var direction: Vector2=directions[i%directions.size()]
		game.player.position=POINT-direction*32;plot("carrot");await frames(2)
		var at: Vector2=game.player.position
		stable=begin("water") and stable
		for tick in range(18):
			await frames(1)
			max_foot_move=maxf(max_foot_move,game.player.position.distance_to(at))
			max_sprite_x=maxf(max_sprite_x,absf(game.player.sprite.position.x))
			stable=stable and game.player.facing==direction
	check(stable and max_foot_move<.01 and max_sprite_x<.01,"20次四向浇水后脚底和精灵横向原点仍无累计漂移")
	check(facts.size()==20 and action_count==20 and effect_count==20 and GameState.stamina==80,"20次合法浇水各结算一次体力、地块与成功反馈")
	print("FARMING WATER METRICS ",JSON.stringify({"operations":20,"max_foot_delta":max_foot_move,"max_sprite_offset_x":max_sprite_x}))

func interruption_rules() -> void:
	for cancellation in ["tool","mode","menu","map","background"]:
		await fresh();plot();var before:=stamp()
		check(begin("carrot_seed"),"取消场景先建立合法未生效播种："+cancellation)
		await frames(3)
		match cancellation:
			"tool": GameState.select_tool(GameState.tools.find("water"))
			"mode": GameState.set_control_mode("joystick",false)
			"menu": game.hud.inventory_panel.open_panel(false)
			"map": game.change_location("home")
			"background": game.notification(NOTIFICATION_APPLICATION_PAUSED)
		await frames(20)
		check(stamp()==before and game.player.farm_action.is_empty() and facts.is_empty(),"生效前取消不扣种/体力、不落错格且不残留任务："+cancellation)
		if cancellation=="background": game.notification(NOTIFICATION_APPLICATION_RESUMED)
		game.hud.close_active_panel()
	await fresh();plot();begin("carrot_seed");await frames(9)
	var committed:=stamp();var count: int=facts.size()
	game.hud.inventory_panel.open_panel(false);await frames(20)
	check(count==1 and stamp()==committed and facts.size()==1 and game.player.farm_action.is_empty(),"生效后开菜单只结束反馈，不回滚或重放已成功播种")
	game.hud.close_active_panel()
	await fresh();plot();begin("carrot_seed");await frames(3)
	Inventory.items.erase("carrot_seed");var before:=stamp();await frames(20)
	check(stamp()==before and facts.is_empty(),"前摇期间种子耗尽，生效帧重新检查并安全失败")
	await fresh();plot();begin("carrot_seed");await frames(3)
	plot("potato");before=stamp();await frames(20)
	check(stamp()==before and facts.is_empty(),"目标在生效前被占用，不覆盖作物或扣旧种子")
	await fresh();plot("carrot");begin("water");await frames(3)
	VillageProjects.irrigation_requested.emit();before=stamp();await frames(20)
	check(stamp()==before and facts.is_empty(),"动作前摇中水井完成自动浇灌，手动水壶不再重复扣体力")
	await fresh();plot();begin("carrot_seed");await frames(3)
	GameState.stamina=0;before=stamp();await frames(20)
	check(stamp()==before and facts.is_empty(),"前摇后体力不足时生效帧再次拒绝，不消费种子")
	await fresh();plot();begin("carrot_seed");await frames(3)
	var today: int=GameClock.day
	GameClock.minutes=1440;GameClock._process(0);await frames(20)
	check(GameClock.day==today+1 and Inventory.count("carrot_seed")==999 and Xiaojing.state.plants==0 and game.farm.plots["20,18"].crop=="" and facts.is_empty() and game.player.farm_action.is_empty(),"午夜唯一跨天取消未生效农活，次日不补扣种或计数")
	await save_boundaries()

func save_boundaries() -> void:
	await fresh();plot()
	var path: String="user://farm_action_phase.json"
	var before:=stamp();begin("carrot_seed");await frames(3)
	check(FarmSaveStore.write(game,path),"未生效农活可以保存完整原状态")
	var pending_save:=FarmSaveStore.read(path)
	check(pending_save.items==JSON.parse_string(JSON.stringify(Inventory.items)) and pending_save.plots["20,18"].crop=="" and pending_save.stamina==100 and pending_save.xiaojing.plants==0,"前摇存档没有已扣种未播种的半状态")
	check(FarmSaveStore.restore(game,pending_save),"前摇保存可以正常重新加载")
	await frames(24)
	check(stamp()==before and game.player.farm_action.is_empty() and facts.is_empty(),"加载前摇档后不补执行内存中的旧动作")
	begin("carrot_seed");await frames(9)
	var committed:=stamp();var count: int=facts.size()
	check(FarmSaveStore.write(game,path),"生效后的后摇可以保存完整新状态")
	check(FarmSaveStore.restore(game,FarmSaveStore.read(path)),"生效后的存档正常恢复")
	await frames(24)
	check(stamp()==committed and facts.size()==count and game.player.farm_action.is_empty(),"加载已提交档不会重新扣种、重计520或产生旧动画提交")
	await fresh();plot();check(FarmSaveStore.write(game,path),"建立同步提交保存保护的原主档")
	var save_call: Dictionary={"fired":false,"accepted":true}
	var save_inside:=func():
		if save_call.fired: return
		save_call.fired=true;save_call.accepted=FarmSaveStore.write(game,path)
	GameState.changed.connect(save_inside)
	game.farm.use_tool(CELL,"carrot_seed");GameState.changed.disconnect(save_inside)
	check(save_call.fired and not save_call.accepted and FarmSaveStore.read(path).plots["20,18"].crop=="","同步农活提交中的保存请求被拒绝，原主档保持完整")
	check(FarmSaveStore.write(game,path) and FarmSaveStore.read(path).plots["20,18"].crop=="carrot","农活提交完成后仍可正常保存最终结果")

func real_input() -> void:
	await fresh(Vector2(656,480));plot("carrot")
	var energy: int=GameState.stamina
	Touch.tap(self,game,POINT);await Touch.finish(self,game)
	check(game.farm.plots["20,18"].watered and GameState.stamina==energy-1 and facts.size()==1,"点击移动模式走到正确农田后完成一次完整浇水")
	await fresh();plot();GameState.select_tool(GameState.tools.find("carrot_seed"));GameState.manual_tool=true
	var screen: Vector2=game.player.get_canvas_transform()*POINT
	Touch.finger(self,screen,true,41);Touch.finger(self,screen,true,41);Touch.finger(self,screen,false,41);await frames(22)
	check(game.farm.plots["20,18"].crop=="" and Xiaojing.state.plants==0,"同一触点重复pressed不生成一次额外播种意图")
	for i in range(5): Touch.tap(self,game,POINT);await frames(1)
	await Touch.finish(self,game);await wait_action()
	check(game.farm.plots["20,18"].crop=="carrot" and Inventory.count("carrot_seed")==998 and Xiaojing.state.plants==1,"快速连续点击同一空田最终只种一株并计数一次")
	await fresh();plot("carrot")
	Touch.tap(self,game,POINT);await frames(3)
	Touch.tap(self,game,Vector2(688,592));await Touch.finish(self,game,500);await wait_action()
	check(game.farm.plots["20,18"].watered and game.farm.plots.has("21,18") and facts.size()==2,"点击另一块田不重定向已开始的水壶，后续新农活各作用于原目标")
	await fresh(Vector2(624,592),"joystick");plot("carrot")
	game.player.facing=Vector2.RIGHT;GameState.select_tool(GameState.tools.find("water"));game.action_cooldown=0
	game.player.touch_direction=Vector2.UP
	game.interact()
	var at: Vector2=game.player.position
	await frames(13)
	check(game.player.position==at and game.player.facing==Vector2.RIGHT and game.farm.plots["20,18"].watered,"备用摇杆保持方向时农活锁脚底/朝向并正确浇水")
	await frames(10)
	check(game.player.position.y<at.y-6 and game.player.farm_action.is_empty(),"备用摇杆农活结束恢复实际移动")
	game.player.touch_direction=Vector2.ZERO
