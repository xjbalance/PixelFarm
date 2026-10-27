extends "res://tests/runner.gd"
## 新住宅的施工与午休走真实公开入口；测试仅在调用者临时用户目录运行。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary
var notices: Array[String]=[]

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	Events.notice.connect(func(text: String): notices.append(text))
	await construction()
	await migration()
	await furnished_legacy_migration()
	await construction_safety()
	await furniture_recovery()
	if "--construction-only" not in OS.get_cmdline_user_args():
		await sofa_rules()
		await sofa_upgraded_stamina()
		await sofa_cancellation()
		await midnight_priority()
	print("HOME 05 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

static func visit_builder(test: Node, owner_game: Node) -> void:
	while owner_game.hud.close_active_panel(): pass
	owner_game.change_location("village",MineState.point(MineState.services.forge)+Vector2(0,32))
	await test.frames(5)

static func finish_upgrade(test: Node, owner_game: Node, expected_level: int) -> bool:
	await visit_builder(test,owner_game)
	if not Housing.upgrade(expected_level): return false
	for _i in range(2):
		GameClock.minutes=1200
		if not GameClock.request_sleep(GameClock.day): return false
		await test.frames(5)
	owner_game.change_location("home",Housing.HOME+Vector2(32,0));await test.frames(5)
	return int(Housing.state.level)==expected_level+1 and Housing.state.construction.is_empty()

static func legacy_housing(raw: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for field in ["level","owned","placed","serial","storage","appearance","flowers"]: result[field]=raw[field].duplicate(true) if raw[field] is Dictionary or raw[field] is Array else raw[field]
	return result

func fresh() -> void:
	if "home_rest" in game and is_instance_valid(game.home_rest):
		game.home_rest.close_panel()
		for _i in range(45):
			if not game.home_rest.busy: break
			await frames(1)
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Housing.restore(Housing.defaults(GameClock.day));Inventory.coins=1000000
	Inventory.items={"wood":999,"stone":999,"iron_bar":999,"star_fragment":999,"crystal":99,"carrot_seed":10,"carrot":10,"wheat":10}
	Xiaojing.state.diamonds=1400;GameState.stamina=20;notices.clear();await frames(5)

func state() -> Dictionary:
	return {"housing":Housing.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}

func near_sofa() -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("home",game.home_rest.SOFA+Vector2(0,36));await frames(6)

func wait_sofa() -> void:
	for _i in range(45):
		await frames(1)
		if not game.home_rest.busy: return
	check(false,"沙发过渡在有限物理帧结束")

func construction() -> void:
	await fresh()
	var before:=state();check(not Housing.upgrade(1) and state()==before,"离开周砚服务点不能远程预约住宅")
	await visit_builder(self,game)
	Inventory.coins=0;before=state()
	check(not Housing.upgrade(1) and state()==before,"住宅金币不足整笔保留材料和进度")
	Inventory.coins=1000000;Inventory.items.wood=0;before=state()
	check(not Housing.upgrade(1) and state()==before,"住宅缺木材不先扣金币或其他材料")
	Inventory.items.wood=999
	for level in [1,2,3]:
		await visit_builder(self,game)
		var preview: Dictionary=Housing.preview_upgrade()
		check(int(preview.from_level)==level and int(preview.target_level)==level+1 and int(preview.days)==2,"预览按当前等级展示下一级与真实两日工期："+str(level))
		var day: int=GameClock.day;var coins: int=Inventory.coins;var items: Dictionary=Inventory.items.duplicate(true)
		var accepted:=Housing.upgrade(level)
		check(accepted,"周砚正式受理升级施工："+str(level))
		if not accepted: return
		var job: Dictionary=Housing.state.construction.duplicate(true)
		check(int(Housing.state.level)==level and int(job.started_day)==day and int(job.ready_day)==day+2,"预约只进入施工，不立即升级："+str(level))
		var correct_cost:=Inventory.coins==coins-int(preview.coins)
		for id in items:
			if Inventory.count(id)!=int(items[id])-int(preview.required.get(id,0)): correct_cost=false
		check(correct_cost,"施工整笔只扣预览材料和金币："+str(level))
		before=state()
		check(not Housing.upgrade(level) and not Housing.upgrade(level+1) and state()==before,"施工期间重复点击和下一等级请求均不重扣："+str(level))
		game.change_location("home",game.home_rest.SOFA+Vector2(0,36));await frames(5)
		check(Housing.state.level==level and not Housing.state.construction.is_empty() and await routes(),"施工中旧房型及六处必要交互仍可进入与寻路："+str(level))
		GameClock.minutes=600;GameState.stamina=1
		var nap_ok: bool=game.home_rest.open() and game.home_rest.confirm(game.home_rest.pending_token)
		await wait_sofa()
		check(nap_ok and GameClock.day==day and GameClock.minutes==660 and GameState.stamina==1+ceili(GameState.max_stamina()*.5) and Housing.state.construction==job,"施工中沙发仍正常恢复且不提前完成工单："+str(level))
		game.change_location("home",Kitchen.ANCHOR+Vector2(0,36));await frames(5)
		game.hud.kitchen_panel.open_panel()
		check(game.hud.kitchen_panel.visible and Kitchen.near_kitchen() and Kitchen.recipe_unlocked("carrot_stew"),"施工中原厨房与基础食谱仍开放："+str(level))
		game.hud.kitchen_panel.close_panel()
		GameClock.minutes=1200;check(GameClock.request_sleep(day),"施工第一个合法夜晚跨天："+str(level));await frames(5)
		check(int(Housing.state.level)==level and not Housing.state.construction.is_empty(),"只过一天仍在施工："+str(level))
		Housing.settle_day();check(int(Housing.state.level)==level,"同一天重复结算不提前完成："+str(level))
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"施工第二个合法夜晚跨天："+str(level));await frames(6)
		check(int(Housing.state.level)==level+1 and Housing.state.construction.is_empty() and int(job.job_id) in Housing.state.completed_jobs,"第二日完成一级施工并记唯一job："+str(level))
		var exterior_ok:=false
		for item in game.get_children():
			if item is HouseExterior: exterior_ok=item.applied_level==level+1 and is_instance_valid(item.house) and item.house.texture.resource_path.ends_with("exterior_%d.png" % (level+1))
		check(exterior_ok,"屋外原房子贴图与已完成室内住宅等级一致："+str(level+1))
		before=state();Housing.settle_day();GameClock.day_advanced.emit();await frames(3)
		check(state()==before,"已完成施工重复日信号不再收费或奖励："+str(level))
		game.change_location("home",Housing.HOME+Vector2(32,0));await frames(5)
		check(await routes(),"每一级真实床/门/木盒/厨房/沙发有合法路径："+str(level+1))
	check(int(Housing.state.level)==4 and Housing.slot_count()==16,"真实三次两日施工到四级并开放16种储物")
	await visit_builder(self,game);before=state()
	check(not Housing.upgrade(4) and state()==before,"四级满级后不可继续扣费")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"施工完成后的完整进度可正常保存")

func routes() -> bool:
	game.auto_move.navigation.invalidate();await frames(4);game.auto_move.navigation.rebuild()
	var result:=true;var count:=0
	for point in get_tree().get_nodes_in_group("interactables"):
		if not point.is_visible_in_tree() or not game.home.is_ancestor_of(point): continue
		var required: bool=("home_action" in point and point.home_action in ["sleep","nap"]) or ("housing_id" in point and point.housing_id=="home") or ("kind" in point and point.kind in ["sleep","exit","home:nap","sofa"]) or ("actor_id" in point and point.actor_id=="mail") or ("kitchen_id" in point and point.kitchen_id=="kitchen")
		if required:
			count+=1
			if game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(): result=false;print("HOME ROUTE MISSING ",point.prompt())
	return result and count>=6

func migration() -> void:
	await fresh()
	Inventory.coins=54321;Inventory.items={"wood":17,"carrot_seed":9,"fish_feed":3};Xiaojing.state.diamonds=1314
	var old:=FarmSaveStore.snapshot(game);old.version=22;old.housing=legacy_housing(old.housing)
	var original: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(old)))
	var migrated: Dictionary=FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION,"真实v22格式可以迁入当前住宅版本")
	if migrated.is_empty(): return
	var preserved:=not migrated.is_empty()
	for key in original:
		if key not in ["version","housing"] and AbyssSaveSchema.canonical(migrated.get(key))!=original[key]: preserved=false
	for key in original.housing:
		if AbyssSaveSchema.canonical(migrated.get("housing",{}).get(key))!=original.housing[key]: preserved=false
	check(preserved,"v22逐原字段保留背包金币农田矿洞婚姻钻石家具与布局")
	check(migrated.housing.construction.is_empty() and migrated.housing.completed_jobs.is_empty() and migrated.housing.recovered.is_empty(),"迁移不补历史施工、收费或家具奖励")
	check(FarmSaveSchema.normalize(migrated)==migrated and old.version==22 and not old.housing.has("construction"),"住宅迁移幂等且不原地改写旧档")
	check(FarmSaveStore.restore(game,migrated) and Inventory.coins==54321 and Xiaojing.state.diamonds==1314,"真实恢复旧档不重扣婚礼钻石和住宅材料")
	await frames(6)
	var invalid:=FarmSaveStore.snapshot(game);invalid.version=FarmSaveStore.VERSION+1
	check(not FarmSaveStore.restore(game,invalid),"未来版本存档仍被整份拒绝")

func furnished_legacy_migration() -> void:
	await fresh()
	load("res://tests/star_runner.gd").fixture(game,true)
	Housing.restore(Housing.defaults(GameClock.day));Inventory.coins=100000
	Inventory.items={"wood":300,"stone":300,"iron_bar":50,"crystal":20}
	Xiaojing.state.diamonds=1314;GameState.set_control_mode("joystick",false)
	var built: bool=await finish_upgrade(self,game,1) and await finish_upgrade(self,game,2)
	check(built,"有家具旧档迁移夹具通过真实四日施工建到三级")
	if not built: return
	check(Housing.buy("chair") and Housing.place("chair","home",Vector2i(5,9)) and Housing.deposit("wood",12) and Housing.buy("floor") and Housing.apply_style("floor"),"旧档夹具实际放椅、柜存和应用地板")
	await frames(5)
	var old:=FarmSaveStore.snapshot(game);old.version=22;old.housing=legacy_housing(old.housing)
	var canonical: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(old)))
	var migrated: Dictionary=FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not migrated.is_empty(),"已有婚姻、家具ID和装饰的真实v22存档可迁入当前版本")
	if migrated.is_empty(): return
	var preserved:=true
	for key in canonical:
		if key not in ["version","housing"] and AbyssSaveSchema.canonical(migrated.get(key))!=canonical[key]: preserved=false
	for key in canonical.housing:
		if AbyssSaveSchema.canonical(migrated.housing.get(key))!=canonical.housing[key]: preserved=false
	check(preserved and migrated.housing.recovered.is_empty(),"合法三级旧家具原ID原位保留，柜存地板与已婚关系所有字段不变")
	check(FarmSaveStore.restore(game,migrated) and GameState.control_mode=="joystick" and Xiaojing.state.married and Xiaojing.state.diamonds==1314 and Housing.state.placed[0].id==old.housing.placed[0].id,"迁移真实恢复保留操作模式、婚姻钻石和家具ID")
	var illegal:=old.duplicate(true);illegal.housing.placed[0].cell=[25,10]
	check(FarmSaveSchema.normalize(illegal).is_empty(),"原v22非法床位家具不会被迁移洗成合法暂存或奖励")

func construction_safety() -> void:
	await fresh();await visit_builder(self,game)
	var before:=state();Inventory.diamond_payment=true
	check(not Housing.upgrade(1) and state()==before,"住宅禁止借用钻石支付开关扣钻或错扣金币")
	Inventory.diamond_payment=false
	var attempted: Array[bool]=[]
	var callback:=func(): attempted.append(FarmSaveStore.write(game,"user://home05-reentrant.json"))
	Inventory.changed.connect(callback)
	var accepted:=Housing.upgrade(1)
	Inventory.changed.disconnect(callback)
	check(accepted and not attempted.is_empty() and true not in attempted and not FileAccess.file_exists("user://home05-reentrant.json"),"施工材料交换通知期间拒绝半笔事务存档")
	if not accepted: return
	# 模拟有效旧进程在完工日之前退出，当前日期已到ready_day但日信号尚未补发。
	var job: Dictionary=Housing.state.construction.duplicate(true)
	GameClock.day=int(job.ready_day);Calendar.restore(Calendar.snapshot());GameClock.minutes=600
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved),"未结算但已经到达工期的有效施工存档可校验")
	before=state()
	check(FarmSaveStore.restore(game,saved),"逾期但未结算施工可正常恢复")
	await frames(5);Housing.settle_day();await frames(3)
	check(Housing.state.level==2 and Housing.state.construction.is_empty() and Inventory.items==before.items and Inventory.coins==before.coins and Xiaojing.state.diamonds==before.diamonds,"恢复后到期施工只补完工，不再收取资源")
	before=state();Housing.settle_day()
	check(state()==before,"逾期施工补结算后保持幂等")

func furniture_recovery() -> void:
	await fresh();await near_sofa()
	# 全屋现在都允许自由布置；以间隔一格的2×2地毯真实用完“还能摆一块地毯”的空间，不能沿用旧8格小区满位夹具。
	var raw:=Housing.defaults();raw.owned={"rug":99};raw.storage={"wood":12};Housing.restore(raw)
	for region in HomeLayout.placement_regions(int(raw.level)):
		for y in range(region.position.y,region.end.y-1,3):
			for x in range(region.position.x,region.end.x-1,3):
				if raw.placed.size()>=Housing.MAX_PLACED-1: break
				var cell:=Vector2i(x,y)
				if not Housing.can_place("rug","home",cell,"",false): continue
				raw.serial+=1;raw.placed.append({"id":"furniture_%06d" % int(raw.serial),"kind":"rug","area":"home","cell":[x,y]});Housing.restore(raw)
	var room_left:=false
	for region in HomeLayout.placement_regions(int(raw.level)):
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if Housing.can_place("rug","home",Vector2i(x,y),"",false): room_left=true
	check(not raw.placed.is_empty() and not room_left,"全屋自由摆放夹具已实际用完一块2×2地毯所需的合法空间，原关键路线仍保留")
	var count: int=raw.placed.size();raw.serial+=1
	var conflict: Dictionary={"id":"furniture_%06d" % int(raw.serial),"kind":"rug","area":"home","cell":[25,10]}
	raw.placed.append(conflict.duplicate(true))
	var original: Dictionary=raw.duplicate(true)
	var resolved: Dictionary=Housing.reconciled_furniture(raw)
	check(raw==original and resolved.placed.size()==count and resolved.recovered==[conflict],"真实布置空间不足时冲突家具保留原ID完整进入暂存，不改输入")
	var no_space:=raw.duplicate(true);no_space.placed=resolved.placed;no_space.recovered=resolved.recovered
	Housing.restore(no_space);game.change_location("home",Housing.anchor("storage")+Vector2(0,32));await frames(5)
	check(Housing.validate(no_space,GameClock.day),"保留原冲突坐标的暂存记录仍可正常存档")
	var before:=state()
	check(not Housing.recover_furniture(conflict.id) and state()==before,"家具库存99满时取回整笔失败，暂存家具不丢失")
	Housing.state.owned.rug=98;var serial: int=Housing.state.serial
	check(Housing.recover_furniture(conflict.id) and Housing.state.owned.rug==99 and Housing.state.recovered.is_empty() and Housing.state.serial==serial and Housing.state.storage.wood==12,"取回仅恢复一件家具，保留储物与ID序号")
	before=state();check(not Housing.recover_furniture(conflict.id) and state()==before,"暂存家具取回一次，迟到回调不重复返还")
	var with_room:=original.duplicate(true);with_room.placed.pop_front()
	var partial: Dictionary=Housing.reconciled_furniture(with_room)
	var moved: Dictionary={}
	for entry in partial.placed:
		if entry.id==conflict.id: moved=entry
	var stable:=true
	for entry in with_room.placed:
		if entry.id==conflict.id: continue
		if entry not in partial.placed: stable=false
	check(partial.recovered.is_empty() and not moved.is_empty() and moved.cell!=conflict.cell and stable,"释放完整地毯位置后冲突家具迁到合法空位，安全原位家具全部保持不动")
	with_room.placed=partial.placed;with_room.recovered=partial.recovered;Housing.restore(with_room)
	before=state();check(not Housing.reconcile_layout() and state()==before,"已经协调好的布局再次调用不移动、不复制、不退款")

func sofa_rules() -> void:
	await fresh();await near_sofa()
	var day: int=GameClock.day;GameClock.minutes=360;GameState.stamina=1
	check(game.home_rest.open(),"06:00也可从沙发开始小睡确认")
	var token: int=game.home_rest.pending_token;var before:=state()
	check(GameClock.minutes==360 and GameState.stamina==1,"只打开沙发确认不推进时间或恢复体力")
	check(game.home_rest.confirm(token),"确认沙发小睡成功")
	check(GameClock.day==day and GameClock.minutes==420 and GameState.stamina==mini(GameState.max_stamina(),1+ceili(GameState.max_stamina()*.5)),"普通小睡推进60分钟并恢复最大体力50%向上取整")
	check(not game.home_rest.confirm(token),"同一小睡确认token不能重复提交")
	await wait_sofa()
	check(Inventory.items==before.items and Inventory.coins==before.coins and Xiaojing.state.diamonds==before.diamonds,"沙发不消耗或复制背包金币钻石")
	GameState.stamina=GameState.max_stamina();var time: float=GameClock.minutes
	check(game.home_rest.open() and game.home_rest.body.text.contains("满"),"满体力仍可打开小睡，明确提示不会额外恢复")
	check(game.home_rest.confirm(game.home_rest.pending_token),"满体力确认仍可推进一小时")
	await wait_sofa()
	check(GameClock.minutes==time+60 and GameState.stamina==GameState.max_stamina(),"满体力小睡只推进时间，不越上限")
	var multiple:=true
	for _i in range(4):
		multiple=game.home_rest.open() and game.home_rest.confirm(game.home_rest.pending_token) and multiple
		await wait_sofa()
	check(multiple and GameClock.day==day and GameClock.minutes==time+300,"多次独立小睡没有额外日次数限制")

func sofa_upgraded_stamina() -> void:
	await fresh();await near_sofa()
	if not FarmProgress.has_upgrade("bedding"): FarmProgress.built.append("bedding");FarmProgress.changed.emit()
	GameClock.minutes=600;GameState.stamina=1
	check(GameState.max_stamina()==130 and game.home_rest.open(),"旧卧室升级保留130体力上限，并可使用沙发")
	var token: int=game.home_rest.pending_token
	check(game.home_rest.confirm(token) and GameState.stamina==66,"沙发按当前130上限恢复65点，不误用固定50点")
	game.hud.system_panel.open_panel();game.hud.inventory_panel.open_panel(false)
	check(game.home_rest.busy and not game.hud.system_panel.visible and not game.hud.inventory_panel.visible and not game.home_rest.confirm(token),"小睡过渡期间菜单与重复确认均不产生第二次操作")
	await wait_sofa()
	check(GameClock.minutes==660 and GameState.stamina==66 and GameState.max_stamina()==130,"过渡结束不再恢复或重置原体力升级")

func sofa_cancellation() -> void:
	await fresh();await near_sofa();GameClock.minutes=720;GameState.stamina=10
	check(game.home_rest.open(),"取消回归先打开真实沙发确认")
	var token: int=game.home_rest.pending_token;var before:=FarmSaveStore.snapshot(game)
	game.home_rest.close_panel()
	check(not game.home_rest.confirm(token) and FarmSaveStore.snapshot(game)==before,"取消后迟到回调不恢复体力或推进日期")
	game.home_rest.open();token=game.home_rest.pending_token
	game.change_location("farm");await frames(4)
	var minutes: float=GameClock.minutes;var stamina: int=GameState.stamina
	check(not game.home_rest.confirm(token) and GameClock.minutes==minutes and GameState.stamina==stamina,"切图使旧沙发确认失效")
	await near_sofa();game.home_rest.open();token=game.home_rest.pending_token
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not game.home_rest.confirm(token) and GameClock.minutes==minutes,"后台不能提交旧小睡回调")
	game.notification(NOTIFICATION_APPLICATION_RESUMED);await frames(3)
	game.hud.inventory_panel.open_panel(false)
	check(not game.home_rest.open(),"背包模态期间不能再开沙发确认")
	game.hud.inventory_panel.close_panel()

func midnight_priority() -> void:
	await fresh();await near_sofa();GameClock.minutes=1410;GameState.stamina=1
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":true}}
	var day: int=GameClock.day;var settlements: Array[int]=[0]
	var callback:=func(): settlements[0]+=1
	GameClock.day_advanced.connect(callback)
	check(game.home_rest.open() and game.home_rest.confirm(game.home_rest.pending_token),"23:30确认小睡能抵达午夜")
	await wait_sofa();GameClock._process(0);GameClock._process(0)
	check(GameClock.day==day+1 and GameClock.minutes==360 and settlements[0]==1,"小睡午夜只结算一次，醒来06:00不补余下30分钟")
	check(GameState.stamina==ceili(GameState.max_stamina()*.6),"午夜疲劳60%体力优先，不被沙发50%奖励覆盖")
	check(game.farm.plots["20,18"].days==1,"午夜小睡作物只成长一天")
	GameClock.day_advanced.disconnect(callback)
