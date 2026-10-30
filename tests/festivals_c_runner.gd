extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await dates_and_spring()
	await summer_lanterns()
	await autumn_exhibit()
	await winter_delivery()
	await migration_and_navigation()
	print("FESTIVALS C RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original);GameClock.running=false
	Inventory.coins=10000;Inventory.items={"carrot_seed":40,"potato_seed":40,"wheat_seed":40,"wheat":100,"wood":100,"stone":100,"fishing_bait":80,"carrot":30,"potato":30}
	Festival.restore(Festival.defaults(GameClock.day));GameWeather.enabled=true
	game.player.action_time=0;GameState.stamina=GameState.max_stamina()
	await frames(4)
func at_day(day: int, minutes: int = 600) -> void:
	GameClock.day=day;GameClock.minutes=minutes;Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit();await frames(4)
func board(id: String) -> void:
	var event: Dictionary=Festival.data.events[id]
	await Touch.place(self,game,event.area,Vector2(event.board[0],event.board[1])+Vector2(0,32))
func person(id: String) -> Node2D:
	for npc in get_tree().get_nodes_in_group("interactables"):
		if "person_id" in npc and npc.person_id==id and npc.visible: return npc
	return null
func approach_person(id: String) -> bool:
	var npc := person(id)
	if npc==null: return false
	var location: String="farm" if game.world.is_ancestor_of(npc) else ("home" if game.home.is_ancestor_of(npc) else "village")
	await Touch.place(self,game,location,npc.global_position+Vector2(0,32))
	return Festival.person_near(id)
func transaction() -> Dictionary:
	return {"festival":Festival.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"diamonds":Xiaojing.state.diamonds}
func crop_action(cell: Vector2i, crop: String) -> bool:
	var plot_key: String=game.farm.key(cell)
	if not game.farm.plots.has(plot_key):
		if not game.farm.use_tool(cell,"hoe"): return false
		await frames(16)
	if not game.farm.use_tool(cell,crop+"_seed"): return false
	await frames(16)
	if not game.farm.plots[plot_key].watered:
		if not game.farm.use_tool(cell,"water"): return false
		await frames(16)
	return true
func dates_and_spring() -> void:
	await reset()
	for row in [[24,"spring"],[52,"summer"],[80,"autumn"],[108,"winter"],[136,"spring"],[164,"summer"]]:
		check(Festival.active_id(row[0])==row[1] and Festival.active_id(row[0]-1)=="","四季活动按实际年季日开放："+str(row[0]))
	await at_day(24,539);await board("spring")
	var before := transaction()
	check(not Festival.begin("spring") and transaction()==before,"春赛09点前不能报名，不扣费或改农田")
	GameClock.minutes=540
	await Touch.place(self,game,"farm",Vector2(656,440));before=transaction()
	check(not Festival.begin("spring") and transaction()==before,"春赛必须到真实农田旁木牌报名")
	await board("spring")
	game.farm.plots["20,17"]={"crop":"carrot","days":1,"watered":true}
	check(Festival.begin("spring") and Festival.run_for("spring").cells.size()==3,"报名预留原农田三格空地")
	check(game.farm.plots["20,17"].crop=="carrot" and game.farm.plots["20,17"].days==1,"比赛不会删除或重置既有玩家作物")
	before=transaction()
	check(not Festival.begin("spring") and not Festival.claim("spring") and transaction()==before,"重复报名或未操作领奖不能得到纪念")
	var cells: Array=Festival.run_for("spring").cells.duplicate(true)
	for index in range(3):
		check(await crop_action(Vector2i(cells[index][0],cells[index][1]),["carrot","potato","wheat"][index]),"在预留原田实际翻土播种浇水："+str(index))
	check(Festival.run_for("spring").ready and Festival.run_for("spring").sown.size()==3 and Festival.run_for("spring").watered.size()==3,"三类实际播种与水分照料完成比赛，而非菜单直接跳过")
	var plants: int=Xiaojing.state.plants
	Events.farm_committed.emit("播种",Vector2i(cells[2][0],cells[2][1]),"wheat",int(Xiaojing.state.plant_serial))
	check(Festival.run_for("spring").sown.size()==3 and Xiaojing.state.plants==plants,"重复成功通知不能重复计比赛或520播种")
	Inventory.items.festival_spring_ribbon=999;before=transaction()
	check(not Festival.claim("spring") and transaction()==before,"满包时节日奖励整体保留，不只发金币")
	Inventory.items.erase("festival_spring_ribbon")
	var coins: int=Inventory.coins
	check(Festival.claim("spring") and Inventory.count("festival_spring_ribbon")==1 and Inventory.coins==coins+40,"实际完成后一次领取年度缎带与原种子金币")
	before=transaction();check(not Festival.claim("spring") and transaction()==before,"春季年度奖励不可反复领取")
	check(Festival.validate(Festival.snapshot(),GameClock.day),"实际春赛记录通过严格存档校验")
	await at_day(136,600);await board("spring")
	check(Festival.begin("spring"),"下一年同季可再参加，不永久锁死活动")
	var first: Array=Festival.run_for("spring").cells.duplicate(true)
	for cell in first: await crop_action(Vector2i(cell[0],cell[1]),"carrot")
	check(not Festival.run_for("spring").ready,"三格同一种作物不会伪造多样种植达标")
	check(Festival.restart_spring() and Festival.run_for("spring").cells!=first,"错误种植可选新空地重试，原作物不删除")
	for cell in first: check(game.farm.plots["%d,%d" % [cell[0],cell[1]]].crop=="carrot","重试保留前一轮实际种下的作物")
func fishing_pilot() -> bool:
	for i in range(4000):
		if not Fishing.active(): return Fishing.session.phase in ["landed","caught"]
		Fishing.tick(1.0/120.0,Fishing.session.player>Fishing.session.fish)
	return false
func summer_lanterns() -> void:
	await reset();await at_day(52,900);await board("summer")
	check(Festival.begin("summer"),"夏24日下午到湖岸报名灯会")
	var rod: int=GameState.tools.find("fishing_rod");GameState.select_tool(rod)
	for i in range(2):
		await Touch.place(self,game,"farm",Vector2(944,464));game.player.action_time=0
		check(Fishing.start("farm_lake") and fishing_pilot(),"灯会通过原实际钓鱼小游戏获得新鱼："+str(i))
	check(Festival.run_for("summer").fish.size()==2,"只有真实湖泊钓获计两尾比赛，不要求购买库存")
	var serial: int=Fishing.state.serial
	Events.fishing_landed.emit("farm_lake",Fishing.session.species,serial,GameClock.day)
	check(Festival.run_for("summer").fish.size()==2,"同一钓获重复通知不重复增加比赛进度")
	await board("summer");var before := transaction()
	check(not Festival.watch_lantern("river") and transaction()==before,"20点前不能通过灯会按钮快进或提前点灯")
	await at_day(52,1200)
	for id in ["linya","zhou"]:
		check(await approach_person(id) and Festival.talk(id),"节日交流需要走到真实村民身边："+id)
	check(not Festival.talk("zhou"),"同一村民节日交流不能反复刷记录")
	await board("summer")
	check(Festival.watch_lantern("river") and Festival.run_for("summer").ready,"夜间选择水纹灯与两钓获两交流共同完成灯会")
	var lantern: String=Festival.run_for("summer").lantern
	before=transaction();check(not Festival.watch_lantern("home") and Festival.run_for("summer").lantern==lantern and transaction()==before,"选定灯型后不能重放结算或覆盖同年选择")
	check(Festival.claim("summer") and Inventory.count("festival_summer_lantern")==1,"灯会纪念只能实际完成后领取")
	var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=50;x.trust=40;x.bond=50
	Xiaojing.restore(x);GameClock.changed.emit();await frames(6)
	await board("summer")
	var npc := person("xiaojing")
	if npc:
		await Touch.place(self,game,"farm",Vector2(1200,800))
		check(Festival.summer_xiaojing() and Xiaojing.state.bond==51,"已解锁且关系足够的小京现场观灯仅小幅羁绊+1")
		before=transaction();check(not Festival.summer_xiaojing() and transaction()==before and Xiaojing.state.bond==51,"小京夏夜共同观灯全存档只奖一次")
	else: check(false,"夏夜原日程应可找到小京，不造替代NPC")
	await board("summer")
	check(Festival.shop("shop_summer_flag",1) and Inventory.count("shop_summer_flag")==1,"限定摊位真实消费购买纪念装饰")
	before=transaction();check(not Festival.shop("shop_summer_flag",1) and transaction()==before,"年度限购不能重复扣费或刷纪念品")
	check(not Festival.shop("fish_feast",1),"限定料理不绕过原食谱与设备解锁")
	check(Festival.validate(Festival.snapshot(),GameClock.day),"灯型、比赛、限购和独立小京记录一起合法保存")
func autumn_exhibit() -> void:
	await reset();await at_day(74,600)
	Inventory.items.hay=20
	await Touch.place(self,game,"farm",Livestock.SITES.coop+Vector2(0,32))
	check(Livestock.build("coop") and Livestock.buy_animal("coop"),"丰收畜产从实际建鸡舍买幼鸡开始")
	var chick: String=Livestock.state.animals[0].id
	for i in range(3):
		var animal: Dictionary=Livestock.animal(chick)
		await Touch.place(self,game,Livestock.animal_area(animal),Livestock.animal_point(animal)+Vector2(0,24))
		check(Livestock.feed(chick),"亲手饲喂幼鸡照料日："+str(i))
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"畜牧经过真实跨天生长")
		await frames(4)
	var adult: Dictionary=Livestock.animal(chick)
	await Touch.place(self,game,Livestock.animal_area(adult),Livestock.animal_point(adult)+Vector2(0,24))
	check(Livestock.collect(chick) and Inventory.count("egg")>=1,"鸡蛋实际产出并领取，节日有本季畜产凭据")
	await at_day(78,600)
	game.change_location("farm",Vector2(656,560))
	game.farm.plots={}
	check(await crop_action(Vector2i(20,18),"carrot"),"秋季展品从本季实际种植开始")
	for i in range(2):
		game.farm.plots["20,18"].watered=true;GameClock.minutes=1200
		check(GameClock.request_sleep(GameClock.day),"秋季作物按合法跨天长成")
		await frames(4)
	GameClock.minutes=600
	check(game.farm.use_tool(Vector2i(20,18),"hand"),"秋季亲手收获产生真实展品证明")
	await frames(16)
	GameState.select_tool(GameState.tools.find("fishing_rod"));await Touch.place(self,game,"farm",Vector2(944,464));game.player.action_time=0
	check(Fishing.start("farm_lake") and fishing_pilot(),"展篮鱼类来自真实钓鱼而非凭空记账")
	var fish_item: String=Fishing.data.species[Fishing.session.species].item
	await board("autumn")
	check(Festival.begin("autumn"),"秋24日在村庄实体展台报名")
	var before := transaction()
	check(not Festival.submit_autumn({"carrot":1,fish_item:2}) and transaction()==before,"背包旧库存不能替代本季真实新产数量")
	await Touch.place(self,game,"farm",Vector2(944,464));game.player.action_time=0
	check(Fishing.start("farm_lake") and fishing_pilot(),"不足的新产展品可以继续实际获取后再试")
	var second_item: String=Fishing.data.species[Fishing.session.species].item
	var selection := {"carrot":1,"egg":1}
	selection[fish_item]=1
	selection[second_item]=int(selection.get(second_item,0))+1
	await board("autumn")
	check(Festival.submit_autumn(selection) and Festival.run_for("autumn").ready and Festival.run_for("autumn").score>=80,"本季真产农作物、鱼和畜产三类实际交付并按组合评分")
	before=transaction();check(not Festival.submit_autumn(selection) and transaction()==before,"同年展篮一次结算，不重复扣除作物鱼类")
	check(Festival.claim("autumn") and Inventory.count("festival_autumn_basket")==1,"丰收评分与纪念奖励真实进入背包")
	check(Festival.validate(Festival.snapshot(),GameClock.day),"秋季生产额度与实际展篮消费保存一致")
func winter_delivery() -> void:
	await reset();await at_day(108,660);await board("winter")
	check(Festival.begin("winter"),"冬24日原村庄集市报名三份暖锅")
	Inventory.items.carrot_stew=3
	check(await approach_person("ahe"),"冬日送餐先实际走到阿禾旁边")
	var before := transaction()
	check(not Festival.deliver_winter("ahe") and transaction()==before,"只有旧库存料理不能跳过报名后的真实烹饪")
	await Touch.place(self,game,"home",Kitchen.ANCHOR+Vector2(-32,0))
	check(Kitchen.cook("carrot_stew",3) and Festival.run_for("winter").cooked==3,"回原厨房实际消耗胡萝卜土豆制作三份热食")
	var total: int=Kitchen.state.cooked.carrot_stew
	Events.dish_cooked.emit("carrot_stew",3,total,GameClock.day)
	check(Festival.run_for("winter").cooked==3,"重复烹饪成功通知不重复计算新做额度")
	for id in ["linya","zhou","ahe"]:
		check(await approach_person(id) and Festival.deliver_winter(id),"实际走到村民旁送达暖锅："+id)
		before=transaction();check(not Festival.deliver_winter(id) and transaction()==before,"同一收餐人不重复扣料理："+id)
	check(Festival.run_for("winter").ready and Festival.run_for("winter").delivered.size()==3,"三处实际送餐完成冬日活动，不能只菜单领取")
	await board("winter")
	check(Festival.claim("winter") and Inventory.count("festival_winter_star")==1,"冬日集市完成后一次领取年度星牌")
	check(Festival.validate(Festival.snapshot(),GameClock.day),"冬季厨房与现场交付进度合法保存")
func migration_and_navigation() -> void:
	await reset();await at_day(24,600);await board("spring");Festival.begin("spring")
	var snap := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(snap) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(snap))),"年度活动进行中能随完整存档跨JSON恢复")
	var before: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
	GameClock.changed.emit();Calendar.changed.emit()
	check(AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))==before,"读档与重复界面刷新不会补发任何节日生产或奖励")
	var bad := Festival.snapshot();bad.runs.spring.ready=true
	check(not Festival.validate(bad,GameClock.day),"未实做的春赛不能伪造ready通过保存")
	bad=Festival.snapshot();bad.claims=["1:spring","1:spring"]
	check(not Festival.validate(bad,GameClock.day),"年度唯一纪念ID不能重复")
	await Touch.place(self,game,"farm",Vector2(848,464))
	var point: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if "festival_id" in node and node.festival_id=="spring": point=node;break
	check(point!=null,"原农场存在可点击的实体播种庆典板")
	if point:
		GameState.set_control_mode("tap",false)
		game.auto_move.request(point.global_position+Vector2(0,-16));await Touch.finish(self,game,600)
		check(game.hud.festival_panel.visible and Festival.near_board("spring"),"点击节日板自动靠近，打开同一活动界面")
		var position: Vector2=game.player.position
		Touch.tap(self,game,Vector2(784,624));await frames(5)
		check(game.player.position==position and game.auto_move.target.is_empty(),"节日界面UI触点不穿透地图")
		game.hud.close_active_panel()
		await Touch.place(self,game,"farm",point.global_position+Vector2(0,16))
		GameState.set_control_mode("joystick",false);game.action_cooldown=0;game.interact()
		check(game.hud.festival_panel.visible,"备用摇杆与桌面E可以操作原节日实体")
		game.hud.close_active_panel()
	await at_day(24,1380)
	var before_festival: Dictionary=Festival.snapshot()
	GameClock.minutes=1440;GameClock._process(0);GameClock._process(0)
	check(GameClock.day==25 and Festival.snapshot()==before_festival,"节日不能规避午夜，重复昏睡不结算额外活动或奖励")
