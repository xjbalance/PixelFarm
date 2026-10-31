extends "res://tests/ux083_task_equivalence.gd"
var fixture: Dictionary

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));await Touch.place(self,game,"farm",Vector2(656,624))
	check(game.farm.use_tool(Vector2i(20,18),"hoe"),"用真实开垦业务准备可播种地块")
	GameState.rest();await frames(20);fixture=FarmSaveStore.snapshot(game)
	await begin_plant()
	Touch.tap(self,game,Vector2(704,720));await frames(30)
	check(Inventory.count("carrot_seed")==12 and Xiaojing.state.plants==0 and game.farm.plots["20,18"].crop=="","新点击替换未生效的播种，不扣种子、不增加520计数")
	await begin_plant()
	Input.action_press("move_right");await frames(15);Input.action_release("move_right")
	check(Inventory.count("carrot_seed")==12 and Xiaojing.state.plants==0,"手动方向接管取消尚未生效的自动农活")
	await begin_plant()
	GameState.set_control_mode("joystick",false);await frames(3)
	var center: Vector2=game.hud.joystick.get_global_rect().get_center()
	Touch.finger(self,center+Vector2(60,0),true,51);await frames(15);Touch.finger(self,center,false,51);await frames(15)
	check(game.player.position.x>670 and Inventory.count("carrot_seed")==12 and game.auto_move.target.is_empty(),"原生摇杆接管真实行走且释放后不恢复旧播种")
	await begin_plant()
	game.hud.inventory_panel.open_panel(false);await frames(20);game.hud.inventory_panel.close_panel();await frames(20)
	check(Inventory.count("carrot_seed")==12 and Xiaojing.state.plants==0 and game.auto_move.target.is_empty(),"打开关闭背包不提交尚未生效的世界交互")
	await begin_plant()
	for i in range(20):
		await frames(1)
		if Inventory.count("carrot_seed")==11: break
	Touch.tap(self,game,Vector2(704,720));await frames(30)
	check(Inventory.count("carrot_seed")==11 and Xiaojing.state.plants==1 and game.farm.plots["20,18"].crop=="carrot","已经生效的播种不因取消动画退回或重复扣种")
	await reset_fixture()
	var object:=Node2D.new();object.set_script(preload("res://scripts/world/story_point.gd"));object.actor_id="repair_record";object.position=Vector2(2016,1344);game.world.actors.add_child(object)
	await Touch.place(self,game,"farm",Vector2(1872,1344));GameState.manual_tool=false
	Touch.tap(self,game,object.position-Vector2(0,20));await frames(6);object.queue_free();await frames(60)
	check(not game.hud.dialogue.visible and game.auto_move.target.is_empty() and not Letters.knows("repair_record"),"任务对象消失会取消请求，不改投旁边对象或记录调查")
	check(game.auto_move.retries<=3,"失效目标不无限重算路径")
	print("UX083 REQUEST LIFECYCLE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(5);get_tree().quit(1 if failed else 0)

func reset_fixture() -> void:
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,fixture),"取消专项恢复同一份种子、农田和任务前置")
	GameClock.running=false;GameWeather.enabled=false;GameState.set_control_mode("tap",false);await frames(5)

func begin_plant() -> void:
	await reset_fixture();GameState.select_tool(3);Touch.tap(self,game,Vector2(656,592))
	for i in range(30):
		await frames(1)
		if not game.player.farm_action.is_empty(): break
	check(not game.player.farm_action.is_empty() and not game.player.farm_action.committed and Inventory.count("carrot_seed")==12,"真实点击已开始播种动作但尚未到生效帧")
