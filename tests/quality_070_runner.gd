extends "res://tests/runner.gd"
## 综合风险边界：损坏分区安全拒绝、真实旧版本字段迁移、读档不得补发跨系统收益。
const NEW_SECTIONS := ["calendar","world_changes","recovery","fishing","livestock","ecology","kitchen","festival","social","housing","exploration","world_development"]
var fresh: Dictionary
var rich: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	fresh=FarmSaveStore.snapshot(game)
	await rich_fixture()
	rich=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(rich),"质量夹具保留非空已婚/矿洞/鱼栏/原建设的合法进度")
	await null_and_malformed()
	await cross_partition_rules()
	await real_legacy_migration()
	await expanded_room_restore()
	await no_replay_and_daylight()
	print("QUALITY 070 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func rich_fixture() -> void:
	load("res://tests/star_runner.gd").fixture(game,true)
	Calendar.restore(Calendar.snapshot(GameClock.day))
	Inventory.coins=43321;Inventory.items={"wood":31,"stone":27,"carrot_seed":5,"potato":3,"fish_crucian":4}
	Xiaojing.state.diamonds=1391;Xiaojing.state.plants=624;Xiaojing.state.plant_serial=624
	GameState.set_control_mode("joystick",false)
	GameState.stamina=64;GameClock.minutes=734
	MineState.state.queue=[{"id":1,"recipe":"refine","batches":2,"ready_day":GameClock.day+1}];MineState.state.job_serial=1
	MineState.state.ores.c_diamond_0={"hp":2,"ready_day":0};MineState.state.chests=["c_chest"]
	game.world.resource_field.restore({"tree_5_8":{"hp":0,"ready_day":GameClock.day+2}})
	game.farm.plots={"17,16":{"crop":"carrot","days":1,"watered":true},"18,16":{"crop":"potato","days":2,"watered":false}}
	Aquaculture.restore(Aquaculture.defaults(GameClock.day))
	var p: Dictionary=Aquaculture.pen("pen_1");p.built=true;p.level=1;p.species="carp";p.adults=2
	Aquaculture.state.quests=["intro"];Aquaculture.state.collection=["carp"];Aquaculture.state.harvested={"carp":4}
	GameClock.changed.emit();game.change_location("farm",Vector2(656,480));await frames(6)
func refuse(data: Dictionary, description: String) -> void:
	var before: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
	var normalized := FarmSaveSchema.normalize(data)
	check(normalized.is_empty() and not FarmSaveStore.restore(game,data) and AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))==before,description)
func null_and_malformed() -> void:
	for section in NEW_SECTIONS:
		var bad := rich.duplicate(true);bad[section]=null
		refuse(bad,"空分区安全拒绝且不污染已婚运行态："+section)
	var nested_ok := true
	for entry in [["calendar","weather"],["fishing","counts"],["livestock","animals"],["kitchen","buff"],["festival","production"],["social","daily"],["housing","appearance"],["exploration","forest"],["world_development","build_days"]]:
		var bad := rich.duplicate(true);bad[entry[0]][entry[1]]=null
		if not FarmSaveSchema.normalize(bad).is_empty(): nested_ok=false
	check(nested_ok,"九类嵌套关键字段为null时均安全拒绝，不在完整验证前强制取子字段")
	var queue_ok := true
	for entry in [["kitchen","queue"],["livestock","animals"],["housing","placed"]]:
		var bad := rich.duplicate(true);bad[entry[0]][entry[1]]=[null]
		if not FarmSaveSchema.normalize(bad).is_empty(): queue_ok=false
	check(queue_ok,"加工订单/动物/家具数组中的null实体不进入恢复遍历")
	var old := rich.duplicate(true);old.version=11;old.erase("farm_layout");old.erase("appearance");old.erase("territory")
	for section in NEW_SECTIONS: old.erase(section)
	var old_bad := old.duplicate(true);old_bad.legend="broken legacy object"
	refuse(old_bad,"v11迁移早期观察世界时损坏legend不会抛错")
	old_bad=old.duplicate(true);old_bad.aquaculture.xiaojing=null
	refuse(old_bad,"v11迁移早期观察湖畔子状态为null仍安全拒绝")
	old_bad=rich.duplicate(true);old_bad.version=16;old_bad.erase("farm_layout");old_bad.erase("appearance");old_bad.erase("territory");old_bad.progress=null
	for section in ["festival","social","housing","exploration","world_development"]: old_bad.erase(section)
	refuse(old_bad,"v16社交迁移的旧progress损坏时不读取非法好感字段")
func cross_partition_rules() -> void:
	var bad := fresh.duplicate(true)
	bad.kitchen.buff={"id":"speed","remaining":20.0};bad.aquaculture.meal_day=0
	refuse(bad,"没有任何食用日证明的增益不能从存档凭空恢复")
	bad=fresh.duplicate(true);bad.housing.level=3;bad.housing.builtins=HomeLayout.default_builtins(3);bad.housing.owned={"spouse_desk":1}
	refuse(bad,"未婚档不能靠新增住房分区获得婚后专属家具")
	bad=fresh.duplicate(true);bad.exploration.unlocked.append("lake_ruins")
	bad.exploration.forest={"step":4,"open":true};bad.exploration.facts=["forest_order","forest_archive","drain_plate"]
	refuse(bad,"未生态修复的旧世界不能仅改探险列表进入湖底遗迹")
	bad=fresh.duplicate(true);bad.world_development.dock=1;bad.world_development.build_days.dock=[1];bad.world_development.parcel_claimed=["dock"]
	refuse(bad,"没有旧主线与公共设施的存档不能偷开永久贸易码头")
	bad=rich.duplicate(true);bad.recovery.rests=4
	refuse(bad,"恢复日限超额记录不能经旧人物婚姻完整档绕过")
	bad=rich.duplicate(true);bad.calendar.date.absolute+=1
	refuse(bad,"季节日历的绝对日期必须与主时钟一致")
	bad=rich.duplicate(true);bad.world_changes.observed.unknown_building=GameClock.day
	refuse(bad,"世界永久变化不接受未知奖励或设施记录")
	bad=fresh.duplicate(true)
	bad.social.active.xiaojing={"id":"xiaojing_1","start_day":1,"counts":{},"tracked":{},"seen":[],"meeting_day":1,"missed":false,"repair_ready":false}
	refuse(bad,"未解锁小京的档案不能保留已接湖畔恋爱任务")
	bad=fresh.duplicate(true);bad.festival.xiaojing_summer=true
	refuse(bad,"未解锁小京的档案不能宣称已领取夏季独有关系事件")
func real_legacy_migration() -> void:
	var old := rich.duplicate(true);old.version=11;old.erase("farm_layout");old.erase("appearance");old.erase("territory")
	for section in NEW_SECTIONS: old.erase(section)
	var migrated := FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION,"只含实际v11原分区的已婚矿洞档可跨完整迁移链")
	if migrated.is_empty(): return
	var preserved := true
	var canonical_old: Dictionary=AbyssSaveSchema.canonical(old)
	for key in old:
		if key!="version" and AbyssSaveSchema.canonical(migrated.get(key))!=canonical_old[key]: preserved=false
	check(preserved,"v11逐原字段保留金币/农田/耗尽资源/矿队列/宝箱/520次数/三维/钻石/婚姻/模式")
	check(FarmSaveSchema.normalize(migrated)==migrated and old.version==11 and not old.has("calendar"),"完整迁移幂等且不原地改写输入旧档")
	var old_money: int=Inventory.coins;var old_diamonds: int=Xiaojing.state.diamonds
	check(FarmSaveStore.restore(game,migrated) and Inventory.coins==old_money and Xiaojing.state.diamonds==old_diamonds and Xiaojing.state.wedding_day==190,"实际恢复v11不补婚礼奖励、不重新扣1314且保留结婚日起点")
	await frames(8)
func expanded_room_restore() -> void:
	var old := FarmSaveStore.snapshot(game);old.version=18;old.erase("farm_layout");old.erase("appearance");old.erase("territory")
	old.erase("exploration");old.erase("world_development")
	old.housing=load("res://tests/home05_runner.gd").legacy_housing(Housing.defaults(GameClock.day));old.housing.level=2
	old.location="home";old.player=[272.0,464.0]
	check(not FarmSaveSchema.normalize(old).is_empty() and FarmSaveStore.restore(game,old),"v18二级扩建侧间位置可迁移至当前版本")
	await frames(12)
	check(GameState.location=="home" and game.player.global_position.distance_to(Vector2(272,464))<.1,"恢复侧间坐标不误判为旧小屋边界并传回门口")
	old=FarmSaveStore.snapshot(game);old.version=18;old.erase("farm_layout");old.erase("appearance");old.erase("territory");old.erase("exploration");old.erase("world_development")
	old.housing=load("res://tests/home05_runner.gd").legacy_housing(old.housing);old.housing.level=3;old.player=[176.0,336.0]
	check(FarmSaveStore.restore(game,old),"v18高级住宅更宽侧间可读取")
	await frames(12)
	check(game.player.global_position.distance_to(Vector2(176,336))<.1,"三级侧间原玩家位置经过碰撞同步仍正确保留")
func no_replay_and_daylight() -> void:
	FarmSaveStore.restore(game,rich);await frames(8)
	var proof := FarmSaveStore.snapshot(game)
	var source_before := {"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"diamonds":Xiaojing.state.diamonds,"mines":MineState.snapshot(),"fish":Aquaculture.snapshot(),"social":Social.snapshot(),"festival":Festival.snapshot()}
	for i in range(3): FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(proof)));await frames(4)
	var source_after := {"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"diamonds":Xiaojing.state.diamonds,"mines":MineState.snapshot(),"fish":Aquaculture.snapshot(),"social":Social.snapshot(),"festival":Festival.snapshot()}
	check(AbyssSaveSchema.canonical(source_before)==AbyssSaveSchema.canonical(source_after),"连续三次实际加载不会补采矿宝箱/加工/婚礼/鱼栏/社交或节日奖励")
	var built: Dictionary=WorldChanges.features().duplicate(true)
	for day in [225,253,281,309]:
		GameClock.day=day;Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit()
	check(WorldChanges.features()==built,"四季呈现叠加不会撤销原桥井共仓茶座与温室")
	FarmSaveStore.restore(game,rich);await frames(8)
	game.change_location("farm",Recovery.BENCH+Vector2(0,32));await frames(4)
	GameState.stamina=20;GameClock.minutes=800;Recovery.restore(Recovery.defaults(GameClock.day))
	Inventory.items.potato_bread=1;Aquaculture.state.meal_day=0
	check(Kitchen.consume("potato_bread"),"跨系统恢复测试从真实料理产生唯一增益")
	var day: int=GameClock.day;var remaining: float=Kitchen.state.buff.remaining
	var farm_before: Dictionary=game.farm.plots.duplicate(true);var fish_before: Dictionary=Aquaculture.snapshot()
	check(Recovery.rest(day,0) and GameClock.day==day and GameClock.minutes==820 and Kitchen.state.buff.remaining==remaining and game.farm.plots==farm_before and Aquaculture.snapshot()==fish_before,"带料理增益白天休息仅花20游戏分钟，不伪造活跃秒数或跨天收益")
