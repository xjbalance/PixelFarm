extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await daily_and_gifts()
	await tasks_and_actions()
	await xiaojing_dates()
	await saves_and_controls()
	print("SOCIAL C RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original);GameClock.running=false;GameWeather.enabled=false
	GameClock.minutes=600;Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"copper_bar":100,"iron_bar":100,"wheat":100,"carrot":100,"potato":100,"milk_porridge":10,"fish_feast":10,"carrot_stew":10,"carrot_seed":100,"potato_seed":100,"wheat_seed":100,"fish_carp":10,"fry_carp":10,"fish_feed":100,"fishing_bait":99}
	Social.restore(Social.defaults(GameClock.day));await frames(4)
func near(person: String) -> void:
	while game.hud.close_active_panel(): pass
	var location := "farm" if person=="linya" and GameClock.minutes<1080 else "village"
	if person=="xiaojing":
		location=Social.area(person)
		if location=="": location="village" if GameClock.minutes<1080 else "farm"
	game.change_location(location);GameClock.changed.emit();await frames(5)
	var node := Social.person_node(person)
	if node:
		game.player.position=node.global_position+Vector2(0,35);game.player.get_node("Camera2D").reset_smoothing()
	await frames(4)
func date(day: int, minute: int = 600) -> void:
	GameClock.day=day;GameClock.minutes=minute;Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit();await frames(4)
func next_day() -> void:
	GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(4)
func stamp() -> Dictionary:
	return {"social":Social.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"xiaojing":Xiaojing.snapshot(),"old_friendship":FarmProgress.friendship}
func setup_quest(person: String, number: int) -> void:
	await reset()
	var state := Social.defaults(GameClock.day)
	for n in range(1,number):
		var id := "%s_%d" % [person,n]
		state.completed.append(id);state.choices[id]=Social.definition(id).choices.keys()[0]
	if person!="xiaojing": state.friendship[person]=100
	else:
		var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=100;x.trust=100;x.bond=20;Xiaojing.restore(x)
	Social.restore(state);await near(person)
	check(Social.accept(person),"现场接取个人任务：%s_%d" % [person,number])
func finish(person: String) -> void:
	await near(person)
	var quest := Social.current(person)
	check(Social.ready(person),"真实行动满足个人任务目标："+str(quest.id))
	var before := stamp()
	check(not Social.finish(person,"not_a_choice") and stamp()==before,"非法选择不结算个人任务："+str(quest.id))
	var choice: String=quest.choices.keys()[0]
	check(Social.finish(person,choice) and quest.id in Social.state.completed and Social.state.choices[quest.id]==choice,"选择与唯一任务结算："+str(quest.id))
	before=stamp();check(not Social.finish(person,choice) and stamp()==before,"重复个人任务不重扣物品或重发关系："+str(quest.id))
func daily_and_gifts() -> void:
	await reset()
	for row in [["linya",6],["zhou",65],["ahe",87],["xiaojing",42]]:
		check(Social.is_birthday(row[0],row[1]) and Social.is_birthday(row[0],row[1]+112) and not Social.is_birthday(row[0],row[1]+28),"生日每年一次，其他季相同日期不是生日："+row[0])
	var before := stamp()
	check(not Social.talk("zhou") and not Social.gift("zhou","wood") and stamp()==before,"远程个人交流/赠礼不能加好感或扣库存")
	await near("linya")
	check(Social.talk("linya") and Social.friendship("linya")==1,"现场每天交谈增加一次村民私交")
	before=stamp();check(not Social.talk("linya") and stamp()==before,"同日重复交谈不刷私交")
	check(Social.gift("linya","carrot") and Social.friendship("linya")==4,"喜欢的礼物使用真实库存并增加好感")
	before=stamp();check(not Social.gift("linya","potato") and stamp()==before,"不同礼物也共享每日一次限制")
	await next_day();await near("linya")
	var friendship: int=Social.friendship("linya")
	check(Social.gift("linya","carrot") and Social.friendship("linya")==friendship,"跨天重复最近同礼不继续刷私交")
	await date(6);await near("linya")
	Inventory.items.berry_jam=2
	check(Social.gift("linya","berry_jam") and Social.friendship("linya")==friendship+5 and Social.state.daily.linya.birthday_year==1,"生日喜欢礼物有唯一年度加成")
	await date(7);await near("linya")
	check(Social.gift("linya","stone") and Social.friendship("linya")==friendship+4,"不喜欢礼物温和减好感，不封锁关系事件")
	var old_friendship: int=FarmProgress.friendship
	check(old_friendship==original.progress.friendship,"村民私交扩展不覆写原主线林芽好感")
	var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=50;x.trust=40;x.bond=10;Xiaojing.restore(x)
	await near("xiaojing")
	check(Social.gift("xiaojing","milk_porridge") and Xiaojing.state.affection==53 and Xiaojing.state.trust==40 and Xiaojing.state.bond==10,"特殊料理经原小京gift只增加好感，不刷三维")
	before=stamp();check(not Xiaojing.gift("carrot") and not Social.gift("xiaojing","fish_feast") and stamp()==before,"小京新旧赠礼入口共享同一个日限")
	check(Social.talk("xiaojing") and not Xiaojing.talk(),"小京新旧交谈入口共享原日限")

func tasks_and_actions() -> void:
	await setup_quest("linya",1)
	check(not Social.finish("linya","people"),"未种植不能只选文本完成留种任务")
	game.change_location("farm",Vector2(656,480));game.farm.plots={}
	for x in [17,18,19]:
		var cell := Vector2i(x,16);game.farm.use_tool(cell,"hoe");game.farm.use_tool(cell,"wheat_seed");game.farm.use_tool(cell,"water")
	await next_day()
	for x in [17,18,19]: game.farm.use_tool(Vector2i(x,16),"water")
	await next_day()
	for x in [17,18,19]: game.farm.use_tool(Vector2i(x,16),"hand")
	await finish("linya")
	await setup_quest("linya",2)
	for id in ["bridge_survey","mill"]:
		Events.world_inspected.emit(id);Events.world_inspected.emit(id)
	await Touch.place(self,game,"farm",Vector2(912,592));Aquaculture.build("pen_1");Aquaculture.stock("pen_1","carp",2)
	for i in range(3): Aquaculture.feed("pen_1");await next_day()
	check(Aquaculture.harvest("pen_1",2),"林芽试单使用亲自养成的两尾鲤鱼")
	await finish("linya")
	await setup_quest("linya",3)
	game.change_location("farm",Vector2(656,480));game.farm.plots={}
	for pair in [[Vector2i(17,16),"carrot_seed"],[Vector2i(18,16),"potato_seed"]]: game.farm.use_tool(pair[0],"hoe");game.farm.use_tool(pair[0],pair[1])
	await Touch.place(self,game,"home",Vector2(848,464));Kitchen.cook("carrot_stew")
	await finish("linya")
	await setup_quest("zhou",1)
	for id in ["repair_record","bridge_survey"]: Events.world_inspected.emit(id)
	await finish("zhou")
	await setup_quest("zhou",2)
	Events.processing_claimed.emit("mines","copper_bar",4321,2)
	Events.processing_claimed.emit("mines","copper_bar",4321,2)
	check(Social.state.active.zhou.counts["process:mines:copper_bar"]==1,"同一熔炼领奖事件只记录一次目标，不重放任务奖励")
	await Touch.place(self,game,"home",Vector2(848,464));Kitchen.build("mill");game.player.position=Vector2(880,464)
	check(Social.observe_site("kitchen"),"周砚任务实际到厨房检查设备，无需重复建设旧机器")
	await finish("zhou")
	await setup_quest("zhou",3)
	Events.world_inspected.emit("b_record")
	await Touch.place(self,game,"farm",LakeEcology.SHORE+Vector2(-32,0))
	check(LakeEcology.clean(),"周砚新检修任务要求实际清理湖岸")
	LakeEcology.state.plants=3;LakeEcology.state.cycle=true
	check(Social.observe_site("cycle"),"周砚现场核对已恢复循环口")
	await finish("zhou")
	await setup_quest("ahe",1)
	await near("linya");Social.talk("linya");await near("zhou");Social.talk("zhou")
	await finish("ahe")
	await setup_quest("ahe",2)
	await Touch.place(self,game,"home",Vector2(848,464));Kitchen.cook("carrot_stew")
	Story.stage=7;VillageProjects.built.assign(["well","cooperative","arbor"]);Story.stage=8
	GameClock.minutes=1100;GameClock.changed.emit();await near("ahe")
	game.player.position=Vector2(592,688)
	check(Social.observe_site("tea"),"阿禾晚饭任务需真正到18点茶座且本人在场")
	await finish("ahe")
	await setup_quest("ahe",3)
	await Touch.place(self,game,"farm",Kitchen.BERRY+Vector2(0,32));Kitchen.harvest_berries();await next_day();Kitchen.harvest_berries()
	VillageProjects.built.assign(["well","cooperative","arbor"]);Story.stage=8
	await Touch.place(self,game,"village",Vector2(592,688));Social.observe_site("tea_season")
	await finish("ahe")
func xiaojing_dates() -> void:
	await setup_quest("xiaojing",1)
	var original_vow: bool=StarStory.state.repair_pending
	GameClock.minutes=1200;GameClock.changed.emit();await frames(4)
	check(Social.state.active.xiaojing.missed and StarStory.state.repair_pending==original_vow,"错过可选湖约只记录个人事件，不锁住旧婚礼条件")
	await near("xiaojing")
	check(not Social.rebook(),"只有解释文本不能直接跳过关系修复行动")
	await Touch.place(self,game,"home",Vector2(848,464));Kitchen.cook("carrot_stew")
	await near("xiaojing")
	check(Social.rebook() and not Social.state.active.xiaojing.missed,"亲手新做一餐后可重新约定，不永久锁结局")
	var meeting_day: int=Social.state.active.xiaojing.meeting_day
	await date(meeting_day,1100)
	await Touch.place(self,game,"farm",Social.LAKE);GameClock.changed.emit();await frames(8);await wait_companion(Social.LAKE)
	check(Social.meeting_now() and Social.observe_site("lake_date"),"约定时段真正的小京来到湖边并一起观察")
	GameState.select_tool(GameState.tools.find("fishing_rod"));game.player.action_time=0;GameState.stamina=100
	check(Fishing.start("farm_lake"),"共同钓鱼使用实体湖岸的正常抛竿")
	for i in range(3600):
		if not Fishing.active(): break
		Fishing.tick(1.0/120.0,float(Fishing.session.player)>float(Fishing.session.fish))
	check(Social.state.active.xiaojing.counts.get("shared_fish",0)==1,"真实小游戏成功且小京在场才记录共同钓获")
	var bond: int=Xiaojing.state.bond
	await finish("xiaojing")
	check(Xiaojing.state.bond==bond+1,"完成湖约只加一次小幅羁绊，不替代旧终局条件")
	await setup_quest("xiaojing",2)
	await date(30,1260);await Touch.place(self,game,"farm",Social.LAKE);GameClock.changed.emit();await frames(8)
	check(Social.observe_site("summer_sky"),"夏季夜晚在实际湖岸与小京一起观星")
	await date(85,600);LegendState.state.greenhouse=2
	await Touch.place(self,game,"farm",Vector2(1312,812))
	check(Social.observe_site("winter_window"),"冬季到温室气窗实地观察，保留旧温室阶段")
	Events.dish_cooked.emit("milk_porridge",1,731,GameClock.day)
	await finish("xiaojing")
	await setup_quest("xiaojing",3)
	LakeEcology.state.restored=true;LakeEcology.state.cycle=true;LakeEcology.state.plants=3;LakeEcology.changed.emit()
	GameClock.minutes=600;GameClock.changed.emit();await Touch.place(self,game,"farm",LakeEcology.SHORE);await frames(8)
	check(Social.observe_site("ecology_after"),"湖泊实际修复状态与小京在场共同触发生态回访")
	var meteor_day := 0
	GameWeather.enabled=true
	for day in range(GameClock.day,GameClock.day+224):
		if Calendar.predicted_weather(day)=="meteor": meteor_day=day;break
	await date(meteor_day,1260);await Touch.place(self,game,"farm",Social.LAKE);GameClock.changed.emit();await frames(8);await wait_companion(Social.LAKE)
	check(Social.observe_site("star_lake"),"隐藏星湖事件需要真实流星夜、清洁湖泊与小京现场")
	await finish("xiaojing")

func saves_and_controls() -> void:
	await reset()
	var old := FarmSaveStore.snapshot(game)
	old.version=16;old.erase("farm_layout");old.erase("appearance");old.erase("territory");old.erase("social");old.erase("festival");old.erase("housing")
	old.progress.friendship=31
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.social.friendship.linya==31 and migrated.social.friendship.zhou==0,"旧档林芽好感迁移至私交起点而不推算其他人")
	if not migrated.is_empty():
		check(migrated.progress==old.progress and migrated.xiaojing==old.xiaojing and migrated.items==old.items,"社交迁移保留旧主线好感、小京关系和全部物品")
		check(FarmSaveSchema.normalize(migrated)==migrated,"社交迁移重复执行不发奖励或清空已完成记录")
	await setup_quest("linya",1)
	game.change_location("farm",Vector2(656,480));game.farm.plots={}
	var cell := Vector2i(17,16);game.farm.use_tool(cell,"hoe");game.farm.use_tool(cell,"wheat_seed");game.farm.use_tool(cell,"water")
	var save := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(save) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))),"进行中个人任务和亲种地格追踪随整档保存恢复")
	var before: Dictionary=Social.snapshot()
	Events.farm_committed.emit("播种",cell,"wheat",Xiaojing.state.plant_serial)
	Events.farm_committed.emit("浇水",cell,"wheat",Xiaojing.state.plant_serial)
	check(Social.snapshot()==before,"读档后重复同播种序号与浇水信号不叠加个人任务")
	var bad := Social.snapshot();bad.friendship.zhou=101
	check(not Social.validate(bad,GameClock.day),"关系上限异常存档被拒绝")
	bad=Social.snapshot();bad.completed=["linya_2"];bad.choices={"linya_2":"early"}
	check(not Social.validate(bad,GameClock.day),"缺前一人物事件的完成记录被拒绝")
	var restore_before: Dictionary=Social.snapshot()
	GameState.restoring=true
	Events.farm_committed.emit("播种",Vector2i(18,16),"wheat",Xiaojing.state.plant_serial+1)
	Events.world_inspected.emit("bridge_survey")
	Events.dish_cooked.emit("carrot_stew",1,999,GameClock.day)
	Social.check_dates();Social.observe_clean()
	GameState.restoring=false
	check(Social.snapshot()==restore_before,"整档恢复期间观察到的信号不伪造个人行动或改约定状态")
	check(Social.migrate({"day":1,"progress":null}).is_empty() and Social.migrate({"day":1,"progress":{"friendship":"bad"}}).is_empty(),"损坏旧关系分区迁移安全拒绝而不抛异常")
	await near("linya")
	Social.game.hud.social_panel.open_panel("linya");await frames(4)
	check(game.hud.social_panel.visible and GameState.modal,"个人面板现场打开且不移除原NPC对话")
	var position: Vector2=game.player.global_position
	Touch.tap(self,game,Vector2(656,480));await frames(5)
	check(game.auto_move.target.is_empty() and game.player.global_position==position,"个人面板拦截地图触点")
	game.hud.close_active_panel();GameState.set_control_mode("joystick",false)
	check(Social.talk("linya"),"备用摇杆模式个人对话同样使用统一状态入口")

func wait_companion(at: Vector2) -> void:
	GameClock.running=true
	for i in range(1800):
		if Social.companion_here(at): break
		await frames(1)
	GameClock.running=false
