extends "res://tests/runner.gd"
## 0.7阶段A：真实日期结算、气候种植、兼容存档；不替代阶段B–E玩法测试。
var original: Dictionary
const WEATHER_IDS := ["clear","cloudy","rain","heavy_rain","storm","snow","blizzard","fog","meteor"]

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	await frames(6)
	original=FarmSaveStore.snapshot(game)
	await dates_and_boundaries()
	await weather_rules()
	await seasonal_crops()
	await compatibility()
	await world_and_schedules()
	print("SEASONS A RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false
	GameWeather.enabled=true
	await frames(4)

func at_day(day: int) -> void:
	GameClock.day=day;GameClock.minutes=600
	Calendar.restore(Calendar.snapshot(day))
	GameClock.changed.emit()
	await frames(3)

func settle() -> bool:
	GameClock.minutes=1200
	var ok: bool=GameClock.request_sleep(GameClock.day)
	await frames(3)
	return ok

func dates_and_boundaries() -> void:
	await reset()
	for row in [[1,1,0,1],[28,1,0,28],[29,1,1,1],[56,1,1,28],[57,1,2,1],[84,1,2,28],[85,1,3,1],[112,1,3,28],[113,2,0,1],[224,2,3,28],[225,3,0,1],[999999,8929,2,7]]:
		check(Calendar.year(row[0])==row[1] and Calendar.season(row[0])==row[2] and Calendar.day_of_season(row[0])==row[3],"绝对日期派生年月季日："+str(row[0]))
	var events: Array=[]
	var on_season := func(previous_season: int,current_season: int,year: int): events.append([previous_season,current_season,year])
	Calendar.season_changed.connect(on_season)
	await at_day(28)
	check(events.is_empty(),"加载和只读日历定位不播放季节切换奖励事件")
	check(await settle() and GameClock.day==29 and Calendar.season()==1 and events==[[0,1,1]],"春28日晚真实睡眠只触发一次夏季切换")
	GameClock.day_advanced.emit();GameClock.changed.emit();Calendar.snapshot()
	check(events.size()==1,"同一天重复日信号与保存查询不重复季节事件")
	await at_day(112)
	check(await settle() and GameClock.day==113 and Calendar.year()==2 and events[-1]==[3,0,2],"冬28日晚跨入新年仍只增加一个绝对游戏日")
	var before := FarmSaveStore.snapshot(game)
	for day in range(1,340): Calendar.date(day);GameWeather.weather_id(day)
	check(FarmSaveStore.snapshot(game)==before,"预览全年日历和天气不消耗物品或推进游戏状态")
	Calendar.season_changed.disconnect(on_season)
	load("res://tests/star_runner.gd").fixture(game,true)
	await at_day(int(Xiaojing.state.wedding_day)+519)
	Xiaojing.state.ultimate=false
	var greenhouse: Dictionary=StarStory.data.points.greenhouse
	game.change_location("farm",Vector2(greenhouse.position[0],greenhouse.position[1])+Vector2(0,30))
	await frames(4)
	check(not StarStory.post_ready("day520"),"季节年份不替代婚后实际经过519日判断")
	await at_day(int(Xiaojing.state.wedding_day)+520)
	check(StarStory.post_ready("day520"),"跨多个年份后婚后520日仍按绝对日期开放回信")

func weather_rules() -> void:
	await reset()
	var seen := {}
	var seasonal_ok := true
	for day in range(1,1121):
		var id: String=GameWeather.weather_id(day)
		seen[id]=day
		if id not in WEATHER_IDS: seasonal_ok=false
		if id in ["snow","blizzard"] and Calendar.season(day)!=3: seasonal_ok=false
	check(seasonal_ok,"十年日历天气ID合法，积雪天气限冬季")
	for id in WEATHER_IDS: check(seen.has(id),"正常季节天气规律实际包含："+id)
	for id in seen:
		var day: int=seen[id]
		await at_day(day)
		var saved := Calendar.snapshot()
		var first: String=GameWeather.weather_id()
		Calendar.restore(JSON.parse_string(JSON.stringify(saved)))
		check(GameWeather.weather_id()==first,"重新加载不会重抽天气："+id)
		check(GameWeather.is_rainy()==(id in ["rain","heavy_rain","storm"]),"雨水判定与九种天气一致："+id)
		check(GameWeather.is_snowy()==(id in ["snow","blizzard"]),"雪不被错误当作雨灌："+id)
	await at_day(88)
	Calendar.restore(Calendar.migrate(88))
	var prior_weather := [""]
	var yesterday_reader := func(): prior_weather[0]=GameWeather.weather_id(GameClock.day-1)
	GameClock.day_advanced.connect(yesterday_reader)
	check(await settle() and prior_weather[0]=="rain" and GameWeather.weather_id()==Calendar.predicted_weather(89),"旧档冬季雨天跨日时消费者仍结算原昨日天气，今日使用新规则")
	GameClock.day_advanced.disconnect(yesterday_reader)
	GameWeather.enabled=false
	check(not GameWeather.is_rainy() and not GameWeather.is_snowy(),"既有天气关闭开关继续屏蔽物理天气效果")
	GameWeather.enabled=true

func seasonal_crops() -> void:
	await reset()
	GameWeather.enabled=false
	Inventory.items.carrot_seed=10;Inventory.items.potato_seed=10;Inventory.items.wheat_seed=10
	await at_day(85)
	game.farm.plots={"17,16":{"crop":"","days":0,"watered":true},"18,16":{"crop":"carrot","days":1,"watered":true},"19,16":{"crop":"potato","days":1,"watered":true},"20,16":{"crop":"wheat","days":0,"watered":true}}
	var before: Dictionary=Inventory.items.duplicate(true)
	var stamina: int=GameState.stamina
	var plants: int=Xiaojing.state.plants
	check(not game.farm.use_tool(Vector2i(17,16),"carrot_seed") and Inventory.items==before and GameState.stamina==stamina and Xiaojing.state.plants==plants,"冬季拒绝新播不耐寒作物且不扣种子体力或增加520计数")
	check(not game.farm.use_tool(Vector2i(17,16),"potato_seed"),"土豆同样受冬季露天限制")
	check(game.farm.use_tool(Vector2i(17,16),"wheat_seed"),"全年基础小麦仍可冬季种植，不锁死饲料加工材料")
	check(await settle(),"冬季仍通过原20点睡眠结算")
	check(game.farm.plots["18,16"].crop=="carrot" and game.farm.plots["18,16"].days==1 and game.farm.plots["19,16"].days==1,"旧档已栽胡萝卜土豆冬季暂停而不删除")
	check(game.farm.plots["20,16"].days==1 and game.farm.plots["17,16"].days==1,"冬季麦在真实浇水日正常成长")
	await at_day(112)
	game.farm.plots["18,16"].watered=true
	check(await settle() and game.farm.plots["18,16"].days==1,"冬末结算依据昨日冬季，不因今日春季提前成长")
	game.farm.plots["18,16"].watered=true
	check(await settle() and game.farm.plots["18,16"].days==2,"春季恢复后旧作物接原进度成长并可成熟")
	check(game.farm.use_tool(Vector2i(18,16),"hand"),"越冬保留作物能正常收获入原背包")
	await reset()
	var rainy_day := 0
	var snowy_day := 0
	for day in range(2,225):
		if rainy_day==0 and GameWeather.is_rainy(day): rainy_day=day
		if snowy_day==0 and GameWeather.is_snowy(day): snowy_day=day
	await at_day(rainy_day-1)
	game.farm.plots={"17,16":{"crop":"wheat","days":0,"watered":false}}
	check(await settle() and game.farm.plots["17,16"].watered and game.farm.plots["17,16"].days==0,"先结算昨日缺水，再用新一天雨水灌溉露天田")
	await at_day(snowy_day-1)
	game.farm.plots["17,16"].watered=false
	check(await settle() and not game.farm.plots["17,16"].watered,"下雪日不会产生错误的自动雨灌")

func compatibility() -> void:
	await reset()
	load("res://tests/star_runner.gd").fixture(game,true)
	await at_day(210)
	Aquaculture.restore(Aquaculture.defaults(GameClock.day))
	Inventory.coins=4321;Xiaojing.state.diamonds=1427
	GameState.set_control_mode("joystick",false)
	var snap := FarmSaveStore.snapshot(game)
	check(snap.version==FarmSaveStore.VERSION and FarmSaveStore.valid(snap),"新日历世界分区组成完整合法v12快照")
	var raw_json: Dictionary=JSON.parse_string(JSON.stringify(snap))
	check(FarmSaveStore.restore(game,raw_json),"当前v12经JSON保存恢复仍合法")
	var old := snap.duplicate(true)
	old.version=11;old.erase("farm_layout");old.erase("appearance");old.erase("territory")
	# v11夹具只保留v11实际拥有的分区，不伪造尚未存在的开发字段。
	for field in ["calendar","world_changes","recovery","fishing","livestock","ecology","kitchen","festival","social","housing","exploration","world_development"]: old.erase(field)
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty(),"既有v11可迁移到v12")
	if migrated.is_empty(): return
	var kept := true
	for key in old:
		if key!="version" and migrated.get(key)!=old[key]: kept=false
	check(kept,"迁移不改变原金币物品/农田/矿洞/520计数/关系婚姻/模式任一旧分区")
	check(FarmSaveSchema.normalize(migrated)==migrated,"日历与永久世界迁移可重复规范化而不发奖")
	check(FarmSaveStore.restore(game,migrated) and GameWeather.weather_id()=="rain","旧冬季雨日按原天气冻结迁移当日，不在载入时换雪")
	var stable := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(stable))) and AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))==AbyssSaveSchema.canonical(stable),"旧天气来源标记保存后再次恢复稳定")
	var bad := stable.duplicate(true)
	bad.calendar.date.year+=1
	check(not FarmSaveStore.restore(game,bad),"拒绝与绝对游戏日矛盾的独立年份")
	bad=stable.duplicate(true);bad.calendar.weather.id="invented_storm"
	check(not FarmSaveStore.valid(bad),"未知天气ID整份拒绝而非悄悄重抽")
	bad=stable.duplicate(true);bad.calendar.seed=0.5
	check(not FarmSaveStore.valid(bad),"天气种子必须合法完整整数")

func world_and_schedules() -> void:
	await reset()
	load("res://tests/star_runner.gd").fixture(game,true)
	await at_day(200)
	var before: Dictionary=WorldChanges.features().duplicate(true)
	var saved := FarmSaveStore.snapshot(game)
	var coins: int=Inventory.coins
	var diamonds: int=Xiaojing.state.diamonds
	for day in [225,253,281,309]:
		await at_day(day)
		check(WorldChanges.features()==before,"四季叠加不撤销已有桥梁/公共设施/温室："+str(day))
	check(Inventory.coins==coins and Xiaojing.state.diamonds==diamonds,"世界观察和季节呈现不发放重复资源奖励")
	check(FarmSaveStore.restore(game,saved) and WorldChanges.features()==before,"读档还原世界变化并保留原权威剧情状态")
	await frames(5)
	var harsh_day := 0
	for day in range(29,225):
		if GameWeather.is_harsh(day): harsh_day=day;break
	await at_day(harsh_day)
	game.change_location("village",Vector2(640,756));await frames(6)
	game.village.refresh_gathering()
	await frames(5)
	var navigation: WorldNavigation=game.auto_move.navigation
	navigation.rebuild()
	for id in ["zhou","ahe"]:
		var person: Node2D=game.village.villagers[id]
		check(person.station!=Vector2.INF and navigation.region.has_point(navigation.cell(person.station)) and not navigation.static_solid.has(navigation.cell(person.station)),"恶劣天气NPC安排在可通行站位："+id)
