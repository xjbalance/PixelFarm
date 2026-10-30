extends "res://tests/runner.gd"
## 实际畜牧状态层、日结算、世界碰撞与点击交互回归；存档写在隔离XDG。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	await frames(6);original=FarmSaveStore.snapshot(game)
	await construction()
	await daily_animals()
	await pasture_and_breeding()
	await animal_activity_and_restore()
	await persistence()
	await navigation()
	print("LIVESTOCK B RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false;GameWeather.enabled=false
	GameState.set_control_mode("tap",false)
	Inventory.items={"wood":999,"stone":999,"copper_bar":99,"iron_bar":99,"wheat":99,"hay":999}
	Inventory.coins=100000
	Livestock.restore(Livestock.defaults(GameClock.day));await frames(5)

func near_site(site: String) -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("farm",Livestock.SITES[site]+Vector2(0,32));await frames(4)

func near_animal(id: String) -> void:
	while game.hud.close_active_panel(): pass
	var a: Dictionary=Livestock.animal(id)
	game.change_location(Livestock.animal_area(a),Livestock.animal_point(a)+Vector2(0,24));await frames(4)

func transaction() -> Dictionary:
	return {"state":Livestock.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}

func next_day() -> void:
	GameClock.minutes=1200
	check(GameClock.request_sleep(GameClock.day),"畜牧通过原20点睡眠提交一天")
	await frames(3)

func care(site: String, with_pet: bool = false) -> void:
	for entry in Livestock.animals_at(site):
		await near_animal(entry.id)
		Livestock.feed(entry.id)
		if with_pet: Livestock.pet(entry.id)

func construction() -> void:
	await reset()
	check(not Livestock.build("coop"),"远离南庭不可远程建畜舍")
	for site in Livestock.SITES:
		await near_site(site)
		Inventory.coins=0
		var before := transaction()
		check(not Livestock.build(site) and transaction()==before,"金币不足建造整笔不扣料："+site)
		Inventory.coins=100000;Inventory.items.wood=0;before=transaction()
		check(not Livestock.build(site) and transaction()==before,"木材不足不部分扣石料："+site)
		Inventory.items.wood=999
		check(Livestock.build(site) and Livestock.building(site).level==1 and Livestock.summary(site).capacity==2,"合法建造一级设施容量2："+site)
		before=transaction()
		check(not Livestock.build(site) and transaction()==before,"重复建设不重复扣费："+site)
		await frames(4)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=game.player.get_node("CollisionShape2D").shape;query.transform=game.player.global_transform;query.collision_mask=1
		check(game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"建造不在玩家脚底生成碰撞："+site)
		check(Livestock.buy_animal(site) and Livestock.buy_animal(site),"正常接回两只独立幼畜："+site)
		before=transaction()
		check(not Livestock.buy_animal(site) and transaction()==before,"超过容量不能买动物："+site)
		check(Livestock.upgrade(site) and Livestock.summary(site).capacity==4 and Livestock.summary(site).count==2,"升级二级保留原动物："+site)
		check(Livestock.upgrade(site) and Livestock.summary(site).capacity==6 and Livestock.summary(site).count==2,"三级扩容仍保留原动物："+site)
		before=transaction()
		check(not Livestock.upgrade(site) and transaction()==before,"满级不重复扣升级费用："+site)
	check(get_tree().get_nodes_in_group("livestock_animals").size()==6,"三种动物在实体地图中可见")

func daily_animals() -> void:
	await reset()
	for site in Livestock.SITES:
		await near_site(site);Livestock.build(site);Livestock.buy_animal(site)
	for site in Livestock.SITES:
		var a: Dictionary=Livestock.animals_at(site)[0]
		await near_animal(a.id)
		var hay: int=Inventory.count("hay")
		check(Livestock.feed(a.id) and Inventory.count("hay")==hay-int(Livestock.data.species[a.species].feed),"一次喂食正确消耗饲料："+a.species)
		var before := transaction()
		check(not Livestock.feed(a.id) and transaction()==before,"同日重复喂食无收益或扣费："+a.species)
		var energy: int=GameState.stamina
		check(Livestock.pet(a.id) and GameState.stamina==energy-1 and a.bond==3,"抚摸有独立每日关系收益："+a.species)
		before=transaction()
		check(not Livestock.pet(a.id) and transaction()==before,"重复抚摸不能刷亲密："+a.species)
		check(a.age==0 and a.product==0,"按钮本身不当场发产物或成长："+a.species)
	for i in range(8):
		for site in Livestock.SITES: await care(site)
		await next_day()
	for site in Livestock.SITES:
		var a: Dictionary=Livestock.animals_at(site)[0]
		await near_animal(a.id)
		check(Livestock.is_adult(a) and a.product>0 and a.product<=3,"真实日照料后成年且产物受暂存上限："+a.species)
		var item: String=Livestock.data.species[a.species].product
		Inventory.items[item]=999
		var before := transaction()
		check(not Livestock.collect(a.id) and transaction()==before,"满包收集失败产物不丢失："+a.species)
		Inventory.items.erase(item)
		var amount: int=a.product
		check(Livestock.collect(a.id) and Inventory.count(item)==amount and a.product==0,"产物实际进入原背包："+a.species)
		before=transaction()
		check(not Livestock.collect(a.id) and transaction()==before,"收完不能重复领取："+a.species)
	var before := transaction()
	GameClock.day_advanced.emit();Livestock.settle_day()
	check(transaction()==before,"同一天重复日信号不再成长或生产")
	for i in range(8): await next_day()
	check(Livestock.state.animals.size()==3,"长期未喂不永久删除动物")
	for site in Livestock.SITES: await care(site)
	await next_day()
	check(Livestock.validate(Livestock.snapshot(),GameClock.day),"饥饿后重新照料状态仍可保存")
	await near_site("coop")
	Inventory.items.hay=0
	check(Livestock.make_hay(2) and Inventory.count("hay")==10,"现有小麦可加工为真实干草")
	Inventory.items.hay=999;before=transaction()
	check(not Livestock.make_hay(1) and transaction()==before,"干草满包不先扣小麦")

func pasture_and_breeding() -> void:
	await reset();await near_site("coop")
	Livestock.build("coop");Livestock.upgrade("coop")
	Livestock.buy_animal("coop");Livestock.buy_animal("coop")
	for i in range(3): await care("coop",true);await next_day()
	var parents: Array=Livestock.animals_at("coop")
	await near_site("coop")
	var before := transaction()
	check(not Livestock.breed("coop") and transaction()==before,"亲密门槛未满足不能直接繁育")
	for a in parents: a.bond=35;a.mood=80
	await care("coop");await near_site("coop")
	check(Livestock.breed("coop") and Livestock.summary("coop").count==3,"有成本繁育生成独立幼畜")
	var child: Dictionary=Livestock.animals_at("coop")[-1]
	check(child.age==0 and child.product==0,"新生幼畜不继承成年进度或产物")
	before=transaction()
	check(not Livestock.breed("coop") and transaction()==before,"同日重复繁育不重复出生或扣费")
	GameClock.minutes=1260
	check(not Livestock.graze("coop"),"夜间不能一键放牧代替全天饲料")
	GameClock.minutes=600
	check(Livestock.graze("coop") and Livestock.is_grazing("coop"),"晴天白天可以真正开启庭院放牧")
	before=transaction()
	check(not Livestock.graze("coop") and transaction()==before,"同日重复开栏无重复收益")
	var hay: int=Inventory.count("hay")
	var age: int=child.age
	await next_day()
	check(child.age==age+1 and Inventory.count("hay")==hay,"合法晴天放牧提供当天自然草料但不暗扣背包")
	GameClock.day=85;GameClock.minutes=600
	Calendar.restore(Calendar.snapshot());await frames(3)
	check(not Livestock.can_graze("coop") and not Livestock.graze("coop"),"冬季必须室内喂干草，不能无成本放牧")

func persistence() -> void:
	await reset();await near_site("barn")
	Livestock.build("barn");Livestock.buy_animal("barn")
	var a: Dictionary=Livestock.animals_at("barn")[0]
	await near_animal(a.id);Livestock.feed(a.id);Livestock.pet(a.id)
	var saved := FarmSaveStore.snapshot(game)
	check(saved.has("livestock") and FarmSaveStore.valid(saved),"畜牧分区进入完整合法存档")
	var expected: Dictionary=AbyssSaveSchema.canonical(Livestock.snapshot())
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and AbyssSaveSchema.canonical(Livestock.snapshot())==expected,"JSON保存恢复独立动物ID/位置/成长/日额度")
	await frames(5)
	var before := transaction();Livestock.settle_day()
	check(transaction()==before,"读档不额外结算一次畜牧日")
	var bad := Livestock.snapshot();bad.animals[0].position=[1104,592]
	check(not Livestock.validate(bad,GameClock.day),"拒绝把动物存入湖水或其他建筑的非法位置")
	bad=Livestock.snapshot();bad.animals.append(bad.animals[0].duplicate(true))
	check(not Livestock.validate(bad,GameClock.day),"重复动物ID整份拒绝")
	bad=Livestock.snapshot();bad.animals[0].product=999
	check(not Livestock.validate(bad,GameClock.day),"非法无限产物不能随存档进入")

func navigation() -> void:
	await reset();await near_site("coop")
	Livestock.build("coop");Livestock.buy_animal("coop")
	await frames(5)
	var points: Array=get_tree().get_nodes_in_group("interactables")
	var target: Node2D
	for point in points:
		if "livestock_id" in point and point.livestock_id.begins_with("animal:"): target=point;break
	check(target!=null,"实际动物有独立点击交互目标")
	await Touch.place(self,game,"pasture_coop",target.global_position+Vector2(0,96))
	if target:
		var count: int=game.auto_move.execution_count
		Touch.tap(self,game,target.global_position+Vector2(0,-12));await Touch.finish(self,game,500)
		check(game.hud.livestock_panel.visible and game.auto_move.execution_count==count+1,"点击动物自动走近并只打开一次界面")
		check(Livestock.near_animal(target.animal_id),"自动交互到达生产层允许的合法位置")
		var position: Vector2=game.player.global_position
		Touch.tap(self,game,position+Vector2(64,0));await frames(4)
		check(game.player.global_position==position and game.auto_move.target.is_empty(),"动物模态面板过滤地图误触")
		game.hud.close_active_panel()
		GameState.set_control_mode("joystick",false)
		await near_animal(target.animal_id);game.action_cooldown=0;game.interact()
		check(game.hud.livestock_panel.visible,"备用摇杆/桌面E沿用同一动物交互")

func animal_activity_and_restore() -> void:
	await reset();await near_site("barn")
	Livestock.build("barn");Livestock.upgrade("barn");Livestock.upgrade("barn")
	for i in range(6): Livestock.buy_animal("barn")
	GameClock.minutes=600;GameClock.changed.emit()
	var first: Dictionary=Livestock.animals_at("barn")[0]
	var initial := Livestock.animal_point(first)
	check(Livestock.graze("barn"),"晴天开启满级六只动物的实体庭院活动")
	game.change_location("pasture_barn");await frames(4)
	GameClock.running=true;await frames(1800);GameClock.running=false
	check(Livestock.animal_point(first).distance_to(initial)>12,"放牧实际改变动物独立位置，非仅菜单标志")
	var saved := FarmSaveStore.snapshot(game)
	var node: CharacterBody2D
	for candidate in get_tree().get_nodes_in_group("livestock_animals"):
		if candidate.animal_id==first.id: node=candidate;break
	if node:
		var expected := Livestock.animal_point(first)
		node.position+=Vector2(8,4)
		check(FarmSaveStore.restore(game,saved),"动物活动中的完整快照可恢复")
		await frames(4)
		check(node.global_position.distance_to(expected)<.1,"恢复同时校正实际可见动物位置，不只恢复数据表")
	GameClock.day=85;GameClock.minutes=600;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	GameWeather.enabled=true
	GameClock.running=true;await frames(6000);GameClock.running=false
	var sheltered := true
	var collision_clear := true
	var occupants: Array=Livestock.animals_at("barn")
	for i in range(occupants.size()):
		var a: Dictionary=occupants[i]
		var position := Livestock.animal_point(a)
		if not Livestock.activity_bounds(a,false).has_point(position):
			sheltered=false
		var query := PhysicsShapeQueryParameters2D.new()
		var footprint := RectangleShape2D.new();footprint.size=Vector2(12,8)
		query.shape=footprint;query.transform=Transform2D(0,position+Vector2(0,-3));query.collision_mask=1
		if not game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): collision_clear=false
	check(not Livestock.is_grazing("barn") and sheltered,"冬季天气变化后动物实际自动回门廊避风")
	check(collision_clear,"六只返舍动物均未穿入畜舍墙或原地图障碍")
	check(Livestock.validate(Livestock.snapshot(),GameClock.day),"活动与避风后的动物位置仍符合严格保存范围")
