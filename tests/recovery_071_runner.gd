extends "res://tests/runner.gd"
## 恢复事务的同步重入、后台旧回调与共享每日料理额度回归。
var original: Dictionary

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(6)
	original=FarmSaveStore.snapshot(game)
	await rest_transactions()
	meal_transactions()
	meal_lifecycle_guards()
	await mine_supply_transactions()
	await storage_safety()
	print("RECOVERY 071 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(3);get_tree().quit(1 if failed else 0)

func reset_recovery() -> void:
	Recovery.restore(Recovery.defaults(GameClock.day));GameState.stamina=10;GameClock.minutes=600
	Inventory.items.carrot=10

func rest_transactions() -> void:
	game.change_location("farm",Recovery.BENCH+Vector2(0,32));await frames(4)
	reset_recovery()
	var day: int=GameClock.day
	var nested := [false]
	var called := [false]
	var rest_again := func():
		if called[0]: return
		called[0]=true;nested[0]=Recovery.rest(day,0)
	Recovery.changed.connect(rest_again)
	check(Recovery.rest(day,0),"椅子正常提交一次恢复事务")
	Recovery.changed.disconnect(rest_again)
	check(called[0] and not nested[0] and Recovery.snapshot().rests==1 and GameState.stamina==25 and GameClock.minutes==620,"椅子changed同步回调不能重入恢复或多扣时间")
	var proof := Recovery.snapshot()
	for mode in ["joystick","tap"]:
		GameState.set_control_mode(mode,false)
		check(not Recovery.rest(day,0) and Recovery.snapshot()==proof,"切换"+mode+"不能重放旧椅子确认")
	game.change_location("home",Vector2(775,365));await frames(3)
	check(not Recovery.rest(day,1) and Recovery.snapshot()==proof,"跨场景旧椅子按钮不恢复、不消耗日限")
	game.change_location("farm",Recovery.BENCH+Vector2(0,32));await frames(3)
	check(Recovery.rest(day,1) and Recovery.snapshot().rests==2,"返回湖岸附近的原休息椅继续保留当天次数")
	proof=Recovery.snapshot()
	for flag in ["backgrounded","closing"]:
		game.set(flag,true)
		var before := Inventory.items.duplicate(true)
		var stamina: int=GameState.stamina
		var minute: float=GameClock.minutes
		check(not Recovery.rest(day,2) and not Recovery.eat_crop("carrot") and Recovery.snapshot()==proof and Inventory.items==before and GameState.stamina==stamina,flag+"期间旧恢复回调不能提交")
		game.set(flag,false)
		Recovery.restore(proof);Inventory.items=before;GameState.stamina=stamina;GameClock.minutes=minute
	GameState.restoring=true
	check(not Recovery.rest(day,2) and not Recovery.eat_crop("carrot") and Recovery.snapshot()==proof,"存档恢复期间拒绝旧椅子和零食回调")
	GameState.restoring=false
	GameClock.minutes=1440
	check(not Recovery.eat_crop("carrot") and Recovery.snapshot()==proof,"午夜结算前一刻不接受迟到的零食交互")
	GameClock.minutes=600
	called[0]=false;nested[0]=false
	var snack_again := func():
		if called[0]: return
		called[0]=true;nested[0]=Recovery.eat_crop("carrot")
	Inventory.changed.connect(snack_again)
	var count_before: int=Inventory.count("carrot")
	var stamina_before: int=GameState.stamina
	check(Recovery.eat_crop("carrot"),"零食正常扣除并恢复一次")
	Inventory.changed.disconnect(snack_again)
	check(called[0] and not nested[0] and Inventory.count("carrot")==count_before-1 and Recovery.snapshot().snacks==1 and GameState.stamina==stamina_before+8,"零食库存变化同步回调不能重复吃同份食物")
	GameClock.minutes=1419.75
	check(Recovery.rest(day,2) and is_equal_approx(GameClock.minutes,1439.75) and GameClock.day==day,"分数分钟边界休息仍停留在当天")
	var endings := [0]
	var on_day := func(): endings[0]+=1
	GameClock.day_advanced.connect(on_day)
	GameClock.minutes=1440;GameClock._process(0);GameClock._process(0)
	check(endings[0]==1 and GameClock.day==day+1 and GameClock.minutes==360 and Recovery.snapshot().rests==0,"午夜只结算一次并重置新一天恢复次数")
	check(not Recovery.rest(day,0) and Recovery.snapshot().rests==0,"次日拒绝昨天的确认令牌")
	GameClock.day_advanced.disconnect(on_day)

func meal_transactions() -> void:
	for first in ["kitchen","fish"]:
		Kitchen.restore(Kitchen.defaults(GameClock.day));Aquaculture.state.meal_day=0
		Inventory.items.carrot_stew=3;Inventory.items.fish_soup=3
		GameState.stamina=10
		var nested := [false]
		var called := [false]
		var attempt := func():
			if called[0]: return
			called[0]=true
			nested[0]=Aquaculture.consume_food("fish_soup") if first=="kitchen" else Kitchen.consume("carrot_stew")
		Inventory.changed.connect(attempt)
		var committed: bool=Kitchen.consume("carrot_stew") if first=="kitchen" else Aquaculture.consume_food("fish_soup")
		Inventory.changed.disconnect(attempt)
		check(committed and called[0],first+"在库存信号内触发跨模块重复料理测试")
		check(not nested[0] and Inventory.count("carrot_stew")== (2 if first=="kitchen" else 3) and Inventory.count("fish_soup")== (3 if first=="kitchen" else 2),first+"先食用时共享事务锁防止同次信号再次扣物")
		check(GameState.stamina== (32 if first=="kitchen" else 40) and Aquaculture.state.meal_day==GameClock.day,"共享料理仅恢复一份并记录当天")
		check(Kitchen.consume("carrot_stew") and Aquaculture.consume_food("fish_soup") and GameState.stamina==(84 if first=="kitchen" else 92),"前一事务结束后可独立继续吃料理，准确扣物恢复体力")
	Kitchen.restore(Kitchen.defaults(GameClock.day));Aquaculture.state.meal_day=0;GameState.stamina=10
	Inventory.items.erase("fish_soup");Inventory.items.erase("carrot_stew")
	check(not Kitchen.consume("carrot_stew") and not Aquaculture.consume_food("fish_soup") and Aquaculture.state.meal_day==0,"缺少料理时共享事务释放，记录与资源不改变")
	Inventory.items.potato_bread=2
	check(Kitchen.consume("potato_bread") and Kitchen.speed_multiplier()==1.15,"正常料理增益保持原数值")
	var buff: Dictionary=Kitchen.snapshot().buff.duplicate(true)
	check(Kitchen.consume("potato_bread") and Kitchen.state.buff==buff and Inventory.count("potato_bread")==0 and GameState.stamina==46,"同日再次吃面包恢复18体力，但不能叠加或刷新增益时长")
	Kitchen._process(50)
	check(Kitchen.state.buff==buff,"暂停的游戏时钟不会消耗或重复生成增益")
	Kitchen.restore(Kitchen.defaults(GameClock.day));Aquaculture.state.meal_day=0
	Inventory.items.carrot_stew=1;Inventory.items.fish_soup=1;GameState.stamina=GameState.max_stamina()
	check(not Kitchen.consume("carrot_stew") and not Aquaculture.consume_food("fish_soup") and Aquaculture.state.meal_day==0 and Inventory.count("carrot_stew")==1 and Inventory.count("fish_soup")==1,"满体力不扣料理或改变食用记录")
	VillageProjects.built.assign(["arbor"]);VillageProjects.tea_day=0;GameState.stamina=10
	var tea_nested := [false]
	var tea_called := [false]
	var tea_again := func():
		if tea_called[0]: return
		tea_called[0]=true;tea_nested[0]=VillageProjects.drink_tea()
	GameState.changed.connect(tea_again)
	check(VillageProjects.drink_tea(),"公共茶座恢复仍可用")
	GameState.changed.disconnect(tea_again)
	check(tea_called[0] and not tea_nested[0] and GameState.stamina==50 and VillageProjects.tea_day==GameClock.day,"茶座同步信号不能重复恢复")

func prepare_meal_guard() -> void:
	Kitchen.restore(Kitchen.defaults(GameClock.day));Aquaculture.state.meal_day=0
	VillageProjects.built.assign(["arbor"]);VillageProjects.tea_day=0
	Inventory.items.carrot_stew=2;Inventory.items.fish_soup=2
	GameState.stamina=10;GameClock.minutes=600

func request_meal(source: String) -> bool:
	match source:
		"kitchen": return Kitchen.consume("carrot_stew")
		"fish": return Aquaculture.consume_food("fish_soup")
		"tea": return VillageProjects.drink_tea()
	return false

func meal_lifecycle_guards() -> void:
	for source in ["kitchen","fish","tea"]:
		for phase in ["backgrounded","closing","restoring","midnight"]:
			prepare_meal_guard()
			var items_before := Inventory.items.duplicate(true)
			if phase in ["backgrounded","closing"]: game.set(phase,true)
			elif phase=="restoring": GameState.restoring=true
			else: GameClock.minutes=1440
			var accepted: bool=request_meal(source)
			check(not accepted and Inventory.items==items_before and GameState.stamina==10 and Aquaculture.state.meal_day==0 and VillageProjects.tea_day==0 and Kitchen.state.buff.id=="",source+"在"+phase+"期间拒绝旧恢复回调且不扣物品或日限")
			game.backgrounded=false;game.closing=false;GameState.restoring=false;GameClock.minutes=600
		prepare_meal_guard()
		var day: int=GameClock.day
		GameState.set_modal(true)
		var consumed: bool=request_meal(source)
		check(consumed and GameState.modal and not GameClock.running and GameClock.day==day and GameClock.minutes==600 and GameState.stamina=={"kitchen":32,"fish":40,"tea":50}[source],source+"在正常暂停菜单内仍可合法恢复一次")
		GameState.set_modal(false)

func mine_supply_transactions() -> void:
	var a := AbyssState.defaults();a.unlocked=true;a.max_clear=10;a.depth=10;a.checkpoint=10
	AbyssState.restore(a);game.mine_maps.abyss.rebuild()
	game.change_location("abyss",AbyssState.point(AbyssState.layout().entry));await frames(5)
	game.player.global_position=game.mine_maps.abyss.objects.up.global_position+Vector2(32,0)
	GameState.stamina=10;Inventory.items.wheat=20;Inventory.items.wood=20
	var called := [false]
	var nested := [false]
	var camp_again := func():
		if called[0]: return
		called[0]=true;nested[0]=AbyssState.camp()
	Inventory.changed.connect(camp_again)
	check(AbyssState.camp(),"检查点露营正常恢复")
	Inventory.changed.disconnect(camp_again)
	check(called[0] and not nested[0] and GameState.stamina==50 and Inventory.count("wheat")==18 and Inventory.count("wood")==18 and AbyssState.state.camp_day==GameClock.day,"露营库存信号不能绕过同日恢复限制")
	AbyssState.state.rations=2;AbyssState.state.air=30
	Inventory.items.wheat=20;Inventory.items.potato=10
	called[0]=false;nested[0]=false
	var ration_again := func():
		if called[0]: return
		called[0]=true;nested[0]=AbyssState.ration()
	Inventory.changed.connect(ration_again)
	check(AbyssState.ration(),"第三份探险补给可以正常使用")
	Inventory.changed.disconnect(ration_again)
	check(called[0] and not nested[0] and AbyssState.state.rations==3 and AbyssState.state.air==66 and Inventory.count("wheat")==17 and Inventory.count("potato")==9,"最后一份补给事务不能被重入到第四份")
	AbyssState.state.camp_day=0;Inventory.items.erase("wood")
	check(not AbyssState.camp() and AbyssState.state.camp_day==0,"露营材料不足不占用当天恢复机会")

func storage_safety() -> void:
	check(FarmSaveStore.restore(game,original),"恢复初始合法场景用于存档故障测试")
	await frames(5)
	var path := "user://palm-write-failure.json"
	check(FarmSaveStore.write(game,path) and FarmSaveStore.write(game,path),"建立隔离主档和有效备份")
	var primary := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.get_file_as_bytes(path+".bak")
	DirAccess.make_dir_absolute(path+".tmp")
	check(not FarmSaveStore.write(game,path),"临时目标不可写时保存明确失败")
	check(FileAccess.get_file_as_bytes(path)==primary and FileAccess.get_file_as_bytes(path+".bak")==backup,"写入失败保留原主档和备份字节")
	DirAccess.remove_absolute(path+".tmp")
	check(not FarmSaveStore.read(path).is_empty(),"失败后原存档仍可完整读取")
