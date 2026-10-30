extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	await frozen_orders()
	await old_engine_save()
	await payment_and_reentrancy()
	await reused_scene_identity()
	await restored_region_parent()
	print("QUALITY081 PRODUCTION RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	game.territory_editor.cancel();check(FarmSaveStore.restore(game,original),"恢复隔离的基础状态")
	GameClock.running=false;await frames(5);Fixture.stock()
func frozen_orders() -> void:
	await reset();var mill: String=await Fixture.install(self,game,"station_mill")
	check(await Fixture.approach(self,game,mill),"在真实设备合法站位开始稳定性验证")
	Inventory.items.wheat=4
	check(Workshop.start(mill,"mill_flour",2),"两批原料只投入一次")
	var job: Dictionary=Workshop.state.jobs[mill].duplicate(true)
	check(job.inputs=={"wheat":2} and job.outputs=={"flour":2},"工单记录实际投入与成品快照")
	var old_definition: Dictionary=HarvestCatalog.data().processing.mill_flour.duplicate(true)
	HarvestCatalog.data().processing.mill_flour.output_quantity=9
	Fixture.advance(90);await frames(4)
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"配方更新后旧在制品仍可保存恢复")
	await frames(4);await Fixture.approach(self,game,mill)
	check(Workshop.claim(mill,int(job.id)) and Inventory.count("flour")==2,"完成订单只给当初约定的两份，不随新配方变成十八份")
	check(not Workshop.claim(mill,int(job.id)),"已领取订单不可再次领取")
	HarvestCatalog.data().processing.mill_flour=old_definition
	Inventory.items.erase("wheat");var before:=Inventory.items.duplicate()
	check(Workshop.start_error(mill,"mill_flour").contains("小麦") and not Workshop.start(mill,"mill_flour") and Inventory.items==before,"缺少材料具体说明且不部分扣除")
	Inventory.items.wheat=4
	var nested: Dictionary={"calls":0,"accepted":false}
	var during_input:=func(): nested.calls+=1;nested.accepted=Workshop.start(mill,"mill_flour") or nested.accepted
	Inventory.changed.connect(during_input)
	check(Workshop.start(mill,"mill_flour"),"正常开始新订单")
	Inventory.changed.disconnect(during_input)
	check(nested.calls==1 and not nested.accepted and Inventory.count("wheat")==3,"投入通知中的同步重入不能重复扣料")
	var serial: int=Workshop.state.jobs[mill].id
	GameClock.running=true;GameState.set_modal(true);var minute: float=GameClock.minutes
	GameClock._process(3600)
	check(GameClock.minutes==minute and not Workshop.state.jobs[mill].ready,"打开菜单不产生生产时间，即使传入大帧间隔")
	GameState.set_modal(false);get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(4)
	minute=GameClock.minutes;GameClock._process(3600);Workshop.update_ready();await frames(4)
	check(GameClock.minutes==minute and not Workshop.state.jobs[mill].ready,"后台不按现实离线时长增加产品")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN);GameClock.running=false;await frames(3)
	Fixture.advance(45);await Fixture.approach(self,game,mill)
	Inventory.items.flour=999
	check(not Workshop.claim(mill,serial) and Workshop.state.jobs.has(mill),"满包保留完整成品快照")
	Inventory.items.erase("flour");nested={"calls":0,"accepted":false}
	var during_claim:=func(): nested.calls+=1;nested.accepted=Workshop.claim(mill,serial) or nested.accepted
	Inventory.changed.connect(during_claim)
	check(Workshop.claim(mill,serial),"腾出空间后正常领取")
	Inventory.changed.disconnect(during_claim)
	check(nested.calls==1 and not nested.accepted and Inventory.count("flour")==1,"领取通知重入只能获得一份成品")
	game.farm.committing=true;before=Inventory.items.duplicate()
	check(not Workshop.start(mill,"mill_flour") and Inventory.items==before,"农田提交中不能插入另一笔生产事务")
	game.farm.committing=false
func old_engine_save() -> void:
	await reset()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/quality081_v28.json"))
	check(int(raw.version)==28 and int(raw.workshop.version)==1,"读取由原0.8.0引擎实际生成的v28存档")
	var current: Dictionary=HarvestCatalog.data().processing.smoke_fish_crucian.duplicate(true)
	HarvestCatalog.data().processing.smoke_fish_crucian.input_items.fish_crucian=3
	var upgraded:=FarmSaveSchema.normalize(raw)
	check(not upgraded.is_empty() and upgraded.version==FarmSaveStore.VERSION and upgraded.workshop.version==2,"旧工单安全迁移为有投入产出快照的v29")
	if upgraded.is_empty(): HarvestCatalog.data().processing.smoke_fish_crucian=current;return
	var same: bool=true
	for key in raw:
		if key not in ["version","workshop","tutorial"] and JSON.stringify(AbyssSaveSchema.canonical(raw[key]))!=JSON.stringify(upgraded.get(key)): same=false
	check(same,"旧经营、已婚、四级房屋、矿洞、钱物与操作字段逐项保留")
	for id in raw.tutorial.seen: check(id in upgraded.tutorial.seen,"旧教学已读标记保留："+str(id))
	var smoker: String="";var ready_mill: String=""
	for id in upgraded.workshop.jobs:
		var job: Dictionary=upgraded.workshop.jobs[id]
		if job.recipe=="smoke_fish_crucian": smoker=id
		else: ready_mill=id
	check(smoker!="" and upgraded.workshop.jobs[smoker].inputs=={"fish_crucian":2,"wood":1},"旧单保留两条鲫鱼的投入，不追加第三条")
	check(upgraded.workshop.jobs[ready_mill].ready and upgraded.workshop.jobs[ready_mill].outputs=={"flour":1},"已完成未领取的旧成品仍完整保留")
	check(FarmSaveSchema.normalize(upgraded)==upgraded,"迁移幂等，不重复补发任何材料")
	check(FarmSaveStore.restore(game,raw),"原旧引擎存档直接恢复到实际场景")
	await frames(5)
	check(Xiaojing.state.married and Housing.state.level==4 and Xiaojing.state.diamonds==int(raw.xiaojing.diamonds),"婚姻、最高住宅和钻石数不改变")
	await Fixture.approach(self,game,ready_mill)
	check(Workshop.claim(ready_mill,int(Workshop.state.jobs[ready_mill].id)),"旧已完成订单只收取原成品")
	var remaining: int=int(Workshop.state.jobs[smoker].finish_at)-Workshop.now_minutes();var fish: int=Inventory.count("fish_crucian")
	Fixture.advance(remaining);await frames(3);await Fixture.approach(self,game,smoker)
	check(Workshop.claim(smoker,int(Workshop.state.jobs[smoker].id)) and Inventory.count("fish_crucian")==fish,"旧待完成订单不补扣新配方材料")
	var corrupt:=upgraded.duplicate(true);corrupt.workshop.jobs[smoker].outputs={"fish_eternal":1}
	check(not FarmSaveStore.valid(corrupt),"工单不能被错误引用为稀有鱼产出")
	corrupt=upgraded.duplicate(true);corrupt.workshop.jobs[smoker].inputs={"stone":2}
	check(not FarmSaveStore.valid(corrupt),"无关投入快照被拒绝")
	for field in ["day","minutes","kitchen","territory"]:
		corrupt=raw.duplicate(true);corrupt[field]="broken"
		check(not FarmSaveStore.valid(corrupt),"旧档坏字段安全拒绝而不抛脚本异常："+field)
	HarvestCatalog.data().processing.smoke_fish_crucian=current
func payment_and_reentrancy() -> void:
	await reset();check(game.territory_editor.open(),"真实建造模式校验支付上下文")
	await frames(4);var plan:=Territory.plan_place("farm","station_mill",Vector2i(20,5))
	check(plan.valid,"金币报价生成合法预览")
	var old_items:=Inventory.items.duplicate();var old_coins: int=Inventory.coins;var old_diamonds: int=Xiaojing.state.diamonds
	Xiaojing.state.diamonds=20;DiamondPayments.selected=true;var result: Dictionary={"accepted":false}
	DiamondPayments.perform(func(): result.accepted=Territory.apply_plan(plan))
	check(not result.accepted and Inventory.items==old_items and Inventory.coins==old_coins and Xiaojing.state.diamonds==20,"拒绝把金币建设预览误当钻石预览，避免免金币建造")
	DiamondPayments.selected=false;Xiaojing.state.diamonds=old_diamonds
	check(Territory.apply_plan(plan) and Inventory.coins==old_coins-80,"正常金币建设仍只扣一次正确费用")
	game.territory_editor.cancel();await frames(3)

func reused_scene_identity() -> void:
	await reset()
	var tree: String=await Fixture.install(self,game,"tree")
	var scenery:=FarmSaveStore.snapshot(game)
	await reset();var mill: String=await Fixture.install(self,game,"station_mill")
	await Fixture.approach(self,game,mill);Inventory.items.wheat=2;Workshop.start(mill,"mill_flour")
	var production:=FarmSaveStore.snapshot(game);var node: Node2D=game.territory_world.objects[mill]
	check(tree==mill and FarmSaveStore.restore(game,scenery),"不同存档可合法复用同一物件编号")
	await frames(4)
	check(node==game.territory_world.objects[tree] and node.visual_binding=="" and not node.animated.is_playing(),"工坊切回景观后解绑工作信号，不残留动画")
	check(FarmSaveStore.restore(game,production),"同一节点重新恢复为加工设备")
	await frames(4);GameClock.running=true;GameClock.changed.emit();await frames(18)
	check(node.visual_binding=="station" and node.animated.is_playing(),"景观切回工坊后重新绑定实际工作状态")
	GameState.set_modal(true);var frame: int=node.animated.frame;await frames(18)
	check(not node.animated.is_playing() and node.animated.frame==frame,"复用节点仍正确响应菜单暂停")
	GameState.set_modal(false);GameClock.running=false

func restored_region_parent() -> void:
	await reset();load("res://tests/star_runner.gd").fixture(game,false);Territory.refresh_unlocks(false);Fixture.stock()
	var unlocked:=FarmSaveStore.snapshot(game)
	var farm_id: String=await Fixture.install(self,game,"station_mill");await Fixture.approach(self,game,farm_id)
	Inventory.items.wheat=3;Workshop.start(farm_id,"mill_flour");var farm_save:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,unlocked),"准备同一编号在另一合法领地的存档")
	await Touch.place(self,game,"east_holding",Vector2(640,800));game.territory_editor.open();await frames(4)
	var plan:=Territory.plan_place("east_holding","station_mill",Vector2i(8,10))
	check(plan.valid and Territory.apply_plan(plan),"在已通过原章节解锁的河东安装设备")
	var east_id: String=Territory.state.objects[-1].id;game.territory_editor.cancel();await frames(4)
	await Fixture.approach(self,game,east_id);Inventory.items.wheat=3;Workshop.start(east_id,"mill_flour")
	var east_save:=FarmSaveStore.snapshot(game)
	check(farm_id==east_id and FarmSaveStore.restore(game,farm_save),"跨存档复用设备ID但恢复到农场")
	await frames(5)
	check(game.territory_world.objects[farm_id].get_parent()==game.world.get_node("Actors"),"设备实体与碰撞随读档回到正确农场父节点")
	check(FarmSaveStore.restore(game,east_save),"再读取河东在制品存档")
	await frames(5)
	check(game.territory_world.objects[east_id].get_parent()==game.territory_world.maps.east_holding.get_node("Actors") and await Fixture.approach(self,game,east_id),"同一设备重归河东且仍能实际寻路交互")
	check(Workshop.state.jobs[east_id].inputs=={"wheat":1} and Workshop.state.jobs[east_id].outputs=={"flour":1},"跨区域读取不丢投入或复制成品")
