extends "res://tests/runner.gd"
const Flow = preload("res://tests/mining.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	GameClock.day=30
	GameWeather.enabled=false
	await frames(5)
	var settlements := {"count":0,"recursive":false}
	GameClock.day_advanced.connect(func(): settlements.count+=1; settlements.recursive=GameClock.next_day())
	game.farm.plots={"17,16":{"crop":"carrot","days":0,"watered":true}}
	GameState.stamina=17
	var baseline := FarmSaveStore.snapshot(game)
	for minute in [360,720,1199]:
		GameClock.minutes=minute
		var before := FarmSaveStore.snapshot(game)
		check(not GameClock.next_day(),"状态层拒绝白天睡觉："+str(minute))
		game.hud.system_panel.open_panel(true)
		check(not game.hud.system_panel.visible and not GameState.modal,"白天床交互不显示可确认睡眠："+str(minute))
		check(FarmSaveStore.snapshot(game)==before and settlements.count==0,"白天无日期体力作物资源日事件变化："+str(minute))
	for minute in [1200,1439]:
		GameClock.minutes=minute
		var day: int=GameClock.day
		game.hud.system_panel.open_panel(true)
		check(game.hud.system_panel.visible and GameState.modal,"夜间床显示确认："+str(minute))
		var before := FarmSaveStore.snapshot(game)
		game.hud.system_panel.close_panel()
		check(FarmSaveStore.snapshot(game)==before,"取消睡眠无结算："+str(minute))
		game.hud.system_panel.open_panel(true)
		var button: Button=game.hud.system_panel.actions.get_child(0)
		button.pressed.emit()
		button.pressed.emit()
		check(GameClock.day==day+1 and GameClock.minutes==360 and GameState.stamina==GameState.max_stamina(),"确认一次进入次日06:00并恢复全体力："+str(minute))
		check(not settlements.recursive and not GameClock.next_day(),"重复按床及日结算重入不能再过一天")
		await frames(3)
	check(settlements.count==2 and game.farm.plots["17,16"].days==1,"两晚各结算一次，第二晚未浇水不成长")
	GameClock.minutes=720
	await Flow.at(self,game,"home",Vector2(720,440))
	GameState.set_control_mode("tap",false)
	load("res://tests/touch_navigation.gd").tap(self,game,Vector2(786,323))
	await Flow.settle(self,game)
	check(GameClock.minutes==720 and not game.hud.system_panel.visible,"点击移动到床不能绕过白天限制")
	GameState.set_control_mode("joystick",false)
	game.player.position=Vector2(775,365)
	game.action_cooldown=0
	game.interact()
	check(GameClock.minutes==720 and not game.hud.system_panel.visible,"备用摇杆交互仍由统一状态层拒绝")
	var saved := FarmSaveStore.snapshot(game)
	GameClock.minutes=1200
	check(FarmSaveStore.restore(game,saved) and not GameClock.next_day(),"读取白天存档后限制仍生效")
	await frames(4)
	GameState.set_control_mode("tap",false)
	game.auto_move.request(Vector2(640,500))
	GameClock.minutes=1440
	GameState.stamina=1
	game.hud.system_panel.open_panel()
	var day: int=GameClock.day
	var count: int=settlements.count
	GameClock._process(0)
	check(GameClock.day==day+1 and GameClock.minutes==360 and GameState.stamina==ceili(GameState.max_stamina()*.6),"24:00疲劳昏睡进次日06:00并恢复60%体力")
	check(game.auto_move.target.is_empty() and game.player.velocity==Vector2.ZERO and not GameState.modal,"午夜取消路径待交互并关闭模态")
	GameClock._process(0)
	GameClock._process(0)
	check(settlements.count==count+1,"午夜重复轮询只结算一次")
	GameClock.running=true
	GameClock.minutes=1439.9
	GameState.set_modal(true)
	day=GameClock.day
	GameClock._process(1)
	check(GameClock.day==day and GameClock.minutes==1439.9,"正常菜单保留午夜前的暂停行为")
	GameState.set_modal(false)
	GameClock._process(.1)
	check(GameClock.day==day+1 and GameClock.minutes==360,"恢复后跨越午夜只结算一次，无无限增长")
	GameClock.running=false
	GameClock.minutes=1440
	day=GameClock.day
	game.change_location("farm")
	GameClock._process(0)
	check(GameClock.day==day+1 and GameClock.minutes==360,"换地图与暂停标志不能逃避已经到达午夜的结算")
	var invalid := FarmSaveStore.snapshot(game)
	invalid.minutes=1440
	check(not FarmSaveStore.restore(game,invalid),"存档不接受未结算24:00时刻，整档拒绝")
	check(settlements.count==5,"全流程日结算准确执行五次")
	print("SLEEP RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.3).timeout
	game.queue_free()
	await frames(3)
	get_tree().quit(1 if failed else 0)
