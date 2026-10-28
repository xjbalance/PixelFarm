extends "res://tests/runner.gd"
## 春庆可种种子与特殊月夜：正常玩法链、数量守恒、旧档迁移与一次观察。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await spring_flowers()
	await moon_night()
	print("FINALE 070 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original);GameClock.running=false;GameWeather.enabled=true
	Inventory.coins=10000;Inventory.items={"carrot_seed":12,"potato_seed":12,"wheat_seed":12,"wood":100,"wheat":50}
	GameState.stamina=GameState.max_stamina();game.player.action_time=0;await frames(5)
func set_day(day: int, minutes: int) -> void:
	GameClock.day=day;GameClock.minutes=minutes;Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit();await frames(3)
func next_day() -> void:
	GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(4)
func stamp() -> Dictionary:
	return {"housing":Housing.snapshot(),"festival":Festival.snapshot(),"exploration":Exploration.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}
func plant_competition(cell: Vector2i, crop: String) -> bool:
	await Touch.place(self,game,"farm",Vector2(cell)*32+Vector2(16,-16))
	game.player.facing=Vector2.DOWN
	if not game.farm.plots.has(game.farm.key(cell)):
		if not game.farm.use_tool(cell,"hoe"): return false
		await frames(16)
	if not game.farm.use_tool(cell,crop+"_seed"): return false
	await frames(16)
	if not game.farm.plots[game.farm.key(cell)].watered:
		if not game.farm.use_tool(cell,"water"): return false
		await frames(16)
	return true
func board() -> void:
	var event: Dictionary=Festival.data.events.spring
	await Touch.place(self,game,event.area,Vector2(event.board[0],event.board[1])+Vector2(0,32))
func spring_flowers() -> void:
	await reset();await set_day(24,600);await board()
	var playable: bool=Festival.begin("spring")
	if playable:
		var cells: Array=Festival.run_for("spring").cells.duplicate(true)
		for i in range(3): playable=(await plant_competition(Vector2i(cells[i][0],cells[i][1]),["carrot","potato","wheat"][i])) and playable
	check(playable and Festival.run_for("spring").ready,"首春24日通过真实三格播种照料赢得庆典")
	await board()
	check(Festival.claim("spring") and Inventory.count("spring_bloom_seed")==3,"真实获胜后领取三份可种春铃花种子")
	var before := stamp();check(not Festival.claim("spring") and stamp()==before,"重复领奖不会复制特殊种子")
	var gold: int=Inventory.coins
	check(Festival.shop("spring_bloom_seed",3) and Inventory.coins==gold-45 and not Festival.shop("spring_bloom_seed",1),"春庆种子商店每年限三份且使用真实15金单价")
	await Touch.place(self,game,"farm",Housing.YARD+Vector2(0,-32))
	var cells: Array[Vector2i]=[]
	for y in range(Housing.YARD_RECT.position.y,Housing.YARD_RECT.end.y):
		for x in range(Housing.YARD_RECT.position.x,Housing.YARD_RECT.end.x):
			var cell := Vector2i(x,y)
			if Housing.can_place("flower","farm",cell): cells.append(cell)
	var id := ""
	var built: bool=cells.size()>=2 and Housing.buy("flower") and Housing.place("flower","farm",cells[0])
	if built: id=Housing.state.placed.back().id
	check(built,"通过原庭院购买并摆放真实花坛，未另造种植地图")
	if not built: return
	await frames(4)
	game.player.position=Vector2(656,480);before=stamp()
	check(not Housing.sow_flower(id) and stamp()==before,"远程不能向花坛播特殊种子")
	await at_flower(id)
	var seeds: int=Inventory.count("spring_bloom_seed")
	check(Housing.sow_flower(id) and Inventory.count("spring_bloom_seed")==seeds-1 and Housing.state.flowers[id]==GameClock.day,"现场播种扣一份种子并保存稳定花坛ID与当天日期")
	before=stamp();check(not Housing.sow_flower(id) and not Housing.recycle(id) and stamp()==before,"重复播种和带生长记录直接回收均拒绝，不吞苗也不复制")
	await next_day();await next_day()
	before=stamp();check(not Housing.harvest_flower(id) and stamp()==before,"两次真实跨天后仍未满三日，不能提前收花")
	var start_day: int=Housing.state.flowers[id]
	var moved: bool=Housing.move(id,cells[1])
	await frames(4);await at_flower(id)
	check(moved and Housing.state.flowers[id]==start_day and not Housing.harvest_flower(id),"移动现种花坛保留原种植日，不变成熟度")
	await frames(4);await at_flower(id);await next_day()
	Inventory.items.spring_bloom=999;before=stamp()
	check(not Housing.harvest_flower(id) and stamp()==before,"三日成熟但满包时整朵花及种植记录保留")
	Inventory.items.erase("spring_bloom")
	check(Housing.harvest_flower(id) and Inventory.count("spring_bloom")==1 and not Housing.state.flowers.has(id) and Inventory.count("spring_bloom_seed")==seeds-1,"成熟收获只给一朵花，不额外返种子")
	before=stamp();check(not Housing.harvest_flower(id) and stamp()==before,"收获后反复点击不能重复领取成花")
	check(Housing.sow_flower(id),"同一花坛收获后可以重新种下一轮")
	Inventory.items.spring_bloom_seed=999;before=stamp()
	check(not Housing.uproot_flower(id) and stamp()==before,"撤苗返种子遇满包整笔拒绝，现种记录不丢失")
	Inventory.items.spring_bloom_seed=5
	check(Housing.uproot_flower(id) and Inventory.count("spring_bloom_seed")==6 and not Housing.state.flowers.has(id) and Housing.recycle(id),"先撤苗返一份种子，再回收花坛，资源守恒")
	await Touch.place(self,game,"farm",Housing.YARD+Vector2(0,-32))
	Housing.place("flower","farm",cells[0]);id=Housing.state.placed.back().id
	await at_flower(id);Housing.sow_flower(id)
	var saved := FarmSaveStore.snapshot(game)
	var proof: Dictionary=AbyssSaveSchema.canonical(stamp())
	var restored := true
	for i in range(3): restored=FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and restored;await frames(4)
	check(restored and AbyssSaveSchema.canonical(stamp())==proof,"反复JSON保存读取不加种子、不早熟或重复采收")
	var old := saved.duplicate(true);old.version=20;old.erase("appearance");old.erase("territory");old.housing=load("res://tests/home05_runner.gd").legacy_housing(old.housing);old.housing.erase("flowers")
	var migrated := FarmSaveSchema.normalize(old)
	var preserved: bool=not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.housing.flowers.is_empty()
	if preserved:
		for key in old.housing: preserved=preserved and migrated.housing[key]==old.housing[key]
		preserved=preserved and migrated.items==old.items and migrated.xiaojing==old.xiaojing and migrated.day==old.day
	check(preserved,"v20迁移只加空花坛生长字段，保留原布局物品日期与小京进度")
func moon_night() -> void:
	await reset();await set_day(15,1199)
	var boundary: bool=not GameWeather.is_moon_night()
	GameClock.minutes=1200;boundary=boundary and GameWeather.is_moon_night()
	GameClock.minutes=1439;boundary=boundary and GameWeather.is_moon_night()
	GameClock.minutes=1440;boundary=boundary and not GameWeather.is_moon_night()
	check(boundary,"特殊月夜仅季内15日20:00至午夜前，1199/1200/1439/1440边界正确")
	await set_day(14,1260)
	var restricted: bool=not GameWeather.is_moon_night()
	var tested_rain := false;var tested_snow := false
	for day in range(15,1135,28):
		var weather: String=Calendar.predicted_weather(day)
		if weather in ["rain","heavy_rain","storm","snow","blizzard"]:
			await set_day(day,1260);restricted=restricted and not GameWeather.is_moon_night()
			if weather in ["snow","blizzard"]: tested_snow=true
			else: tested_rain=true
	if not tested_snow:
		# 默认种子十年冬15未出现雪；使用另一个合法世界种子，仍走真实天气预测及校验。
		for seed in range(101):
			var forecast: String=Calendar.predicted_weather(99,seed)
			if forecast not in ["snow","blizzard"]: continue
			var snowy_world: Dictionary=Calendar.snapshot(99)
			snowy_world.seed=seed;snowy_world.weather={"day":99,"id":forecast,"origin":"seasonal"}
			var valid: bool=Calendar.validate(snowy_world,99)
			GameClock.day=99;GameClock.minutes=1260;Calendar.restore(snowy_world);await frames(3)
			tested_snow=valid and GameWeather.is_snowy()
			restricted=restricted and not GameWeather.is_moon_night()
			break
	check(restricted and tested_rain and tested_snow,"非15日或雨雪遮蔽时不把普通夜晚判作月夜")
	await set_day(15,1260)
	var before := stamp();check(not Exploration.observe_moon() and stamp()==before,"必须到湖岸水样台，不能远程领取月影纸笺")
	await Touch.place(self,game,"farm",LakeEcology.SHORE+Vector2(-32,0))
	Inventory.items.moon_note=999;before=stamp()
	check(not Exploration.observe_moon() and stamp()==before and "moon_reflection" not in Exploration.state.facts,"月夜观察满包不先标已领取，线索与收藏仍可稍后获得")
	Inventory.items.erase("moon_note")
	var diamonds: int=Xiaojing.state.diamonds
	check(Exploration.observe_moon() and Inventory.count("moon_note")==1 and "moon_reflection" in Exploration.state.facts and Xiaojing.state.diamonds==diamonds and Catalog.sell_price("moon_note")==0,"现场观察得到唯一月影收藏与线索，不产钻石或售卖套利")
	var saved := FarmSaveStore.snapshot(game)
	var ok: bool=FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved)))
	before=stamp();check(ok and not Exploration.observe_moon() and stamp()==before,"读取月夜已领档后不能再次领取观察奖励")

func at_flower(id: String) -> void:
	var entry: Dictionary=Housing.placement(id)
	var at: Vector2=Housing.center(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
	await Touch.place(self,game,"farm",at+Vector2(0,40))
