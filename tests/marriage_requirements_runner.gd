extends "res://tests/runner.gd"
## 新门槛使用现有住宅完工和真实钓获数据；测试只写隔离用户目录。
const Ready=preload("res://tests/marriage_requirement_fixture.gd")
const Hidden=preload("res://tests/xiaojing.gd")
const Touch=preload("res://tests/touch_navigation.gd")
const Home=preload("res://tests/home05_runner.gd")
var seed: Dictionary
var captures: Array=[]
var capture_mode: bool=false
var path: String=""

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func goal(id: String) -> Dictionary:
	for entry in Xiaojing.marriage_goals():
		if entry.id==id: return entry
	return {}
func reset() -> void:
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,seed),"独立用例恢复合法未婚旅程")
	GameClock.running=false;GameWeather.enabled=false;await frames(4)

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	path="user://marriage-requirements-%d.json" % Time.get_ticks_usec()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(7)
	load("res://tests/star_runner.gd").fixture(game,false)
	Housing.restore(Housing.defaults(GameClock.day));Fishing.restore(Fishing.defaults())
	Ready.life_milestones();Ready.caught_catalogue(true)
	game.tutorial.restore(GameTutorial.defaults(true));Letters.refresh();await frames(5)
	seed=snapshot();check(FarmSaveStore.valid(seed),"全部原婚礼条件已具备且未添加新门槛的夹具合法")
	await missing_requirements()
	await completed_house()
	await actual_fishing()
	await ceremony_safety()
	await old_married_and_restart()
	var output:=FileAccess.open("res://builds/marriage-requirements-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));output.close()
	print("MARRIAGE REQUIREMENTS "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.persistence_enabled=false;game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func missing_requirements() -> void:
	await reset();await Hidden.near(self,game)
	check(Xiaojing.marriage_goals().size()==6 and not goal("home").ready and not goal("fish").ready,"六项婚礼准备保留四级住宅完工与传说鱼实际钓获")
	var before:=snapshot()
	check(not Xiaojing.base_marriage_ready() and not StarStory.propose("share_home") and snapshot()==before,"旧三属性任务钻石全部满足仍不能跳过新增目标")
	check(LegendState.state.legacy_vow and not StarStory.proposal_ready(),"旧未婚婚约豁免不能绕过新增住宅和渔获要求")
	check(Xiaojing.marriage_goals_text().contains("星光庄园") and Xiaojing.marriage_goals_text().contains("永恒星鲤") and Xiaojing.marriage_goals_missing_text().contains("还需完成"),"统一提示准确列出房屋名称和真正最稀有的鱼")
	Inventory.items.fish_eternal=1
	check(not goal("fish").ready and not Xiaojing.marriage_goals_ready(),"只持有永恒星鲤物品不能冒充亲手钓获")
	Inventory.items.erase("fish_eternal")
	for level in [1,2,3]:
		var house:=Housing.defaults(GameClock.day);house.level=level;house.builtins=HomeLayout.default_builtins(level);Housing.restore(house)
		check(not goal("home").ready,"住宅未完工至四级不能通过新增门槛："+str(level))
	var other:=Fishing.defaults();other.serial=1;other.total=1;other.xp=16;other.counts={"star":1};other.collection=["star"];other.casts_day=GameClock.day;other.casts=1
	Fishing.restore(other)
	check(Fishing.validate(Fishing.snapshot(),GameClock.day) and not goal("fish").ready,"钓过星辉鱼仍不能替代传说级永恒星鲤")
	Ready.caught_catalogue(true)
	Ready.max_home(game)
	check(goal("home").ready and not Xiaojing.base_marriage_ready(),"只有最高级住宅而没有传说鱼仍不能求婚")
	game.hud.xiaojing_panel.open_panel();await frames(4);await capture("missing_fish");game.hud.xiaojing_panel.close_panel()
	Ready.caught_eternal()
	check(Xiaojing.marriage_goals_ready() and Xiaojing.base_marriage_ready() and Fishing.validate(Fishing.snapshot(),GameClock.day),"住宅和合法亲钓记录同时满足才通过新增门槛")
	var old: Dictionary=snapshot();Xiaojing.state.diamonds=1313
	check(not Xiaojing.base_marriage_ready(),"新增目标齐备仍保留原1314钻石要求")
	Xiaojing.state.diamonds=old.xiaojing.diamonds;Xiaojing.state.trials.pop_back()
	check(not Xiaojing.base_marriage_ready(),"新增目标不会替代原试炼要求")

func completed_house() -> void:
	await reset();Ready.caught_eternal()
	var house:=Housing.defaults(GameClock.day);house.level=3;house.builtins=HomeLayout.default_builtins(3);Housing.restore(house)
	Inventory.coins=50000;Inventory.items={"wood":999,"stone":999,"iron_bar":99,"star_fragment":99}
	await Home.visit_builder(self,game)
	check(Housing.validate(Housing.snapshot(),GameClock.day) and Housing.upgrade(3),"三级住宅通过原周砚建造接口预约最高四级")
	var day: int=GameClock.day;var job: Dictionary=Housing.state.construction.duplicate(true)
	check(job.target_level==4 and not goal("home").ready and not Xiaojing.marriage_goals_ready(),"四级施工预约不能算已经完工")
	var before:=snapshot();check(not Housing.upgrade(3) and snapshot()==before,"连续点击施工不重复扣资源或提前解锁婚礼")
	GameClock.minutes=1200;check(GameClock.request_sleep(day),"正式过第一夜推进住宅施工");await frames(5)
	check(Housing.state.level==3 and not goal("home").ready,"施工一天仍不能使用四级住宅婚礼条件")
	GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"正式过第二夜完成住宅施工");await frames(5)
	check(Housing.state.level==4 and Housing.state.construction.is_empty() and goal("home").ready and Xiaojing.marriage_goals_ready(),"原两日施工真实完工后婚礼条件立即同步")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"住宅完工与新增婚礼条件不改变既有存档形状")

func pilot() -> bool:
	for _i in range(3600):
		if not Fishing.active(): return Fishing.session.phase in ["landed","caught"]
		Fishing.tick(1.0/120.0,float(Fishing.session.player)>float(Fishing.session.fish))
	return false

func actual_fishing() -> void:
	await reset();Ready.max_home(game)
	# 提供合法既往普通鱼经验，仍通过原抛竿与追鱼小游戏完成本次传说钓获。
	var fishing:=Fishing.defaults();fishing.rod=3;fishing.counts={"crucian":54};fishing.collection=["crucian"]
	fishing.total=54;fishing.xp=162;fishing.serial=54;fishing.casts_day=5;fishing.casts=6;fishing.legend_pity=3;Fishing.restore(fishing)
	Ready.caught_catalogue(true)
	for candidate in range(GameClock.day,GameClock.day+113):
		if Calendar.weather_id(candidate)=="meteor": GameClock.day=candidate;break
	Calendar.restore(Calendar.snapshot());GameClock.minutes=1260;GameWeather.enabled=true
	var aquaculture:=Aquaculture.defaults(GameClock.day);aquaculture.pens.pen_1.built=true;aquaculture.pens.pen_1.level=1
	aquaculture.xiaojing={"stage":2,"invited_day":GameClock.day-2,"care_days":[GameClock.day-2,GameClock.day-1,GameClock.day],"pen":"pen_1","harvested":2};Aquaculture.restore(aquaculture)
	LakeEcology.state.health=90;Inventory.items.fishing_bait=20;Inventory.items.fish_eternal=999;GameState.stamina=100
	GameState.select_tool(8);await Touch.place(self,game,"farm",Vector2(944,464))
	check(Fishing.validate(Fishing.snapshot(),GameClock.day) and AquacultureSaveSchema.validate(Aquaculture.snapshot(),GameClock.day),"星纹竿经验与婚前共同照料条件夹具满足实际保存校验")
	check(not Xiaojing.state.married and Fishing.eligible("eternal","farm_lake"),"传说鱼所有真实获取前置均可在婚前完成")
	check(Fishing.start("farm_lake") and Fishing.session.species=="eternal","流星夜正确生态与鱼竿条件下实际抛竿遇见永恒星鲤")
	check(pilot() and Fishing.state.pending=="eternal" and Fishing.state.counts.get("eternal",0)==0,"实际追鱼成功但背包堆叠已满时只暂存水桶")
	check(not goal("fish").ready and not Fishing.claim(),"尚未领取的暂存鱼不提前满足婚礼要求")
	Inventory.remove("fish_eternal",1)
	check(Fishing.claim() and goal("fish").ready and Fishing.state.counts.eternal==1,"腾出堆叠空间领取实际鱼获后立即完成婚礼记录")
	var fish_state: Dictionary=Fishing.snapshot();check(not Fishing.claim() and Fishing.snapshot()==fish_state,"同一次钓获重复领取不会重复增加记录")
	Inventory.remove("fish_eternal",999)
	check(Inventory.count("fish_eternal")==0 and goal("fish").ready and Xiaojing.marriage_goals_ready(),"曾亲钓领取后无需一直持有鱼，婚礼不会要求交付")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"真实钓获与新增条件使用现有合法v25字段")
	check(FarmSaveStore.write(game,path) and FarmSaveStore.read(path).fishing.counts.eternal==1,"真实钓获记录通过原存档机制写入")
	var saved: Dictionary=FarmSaveStore.read(path);Fishing.restore(Fishing.defaults());Housing.restore(Housing.defaults(GameClock.day))
	check(FarmSaveStore.restore(game,saved),"既有存档接口恢复已完工住宅及实际钓获记录");await frames(4)
	check(Xiaojing.marriage_goals_ready() and Fishing.state.counts.eternal==1 and Inventory.count("fish_eternal")==0,"读取后仍满足婚礼新门槛，既不要求持鱼也不补发鱼")
	game.hud.xiaojing_panel.open_panel();await frames(4);await capture("goals_complete");game.hud.xiaojing_panel.close_panel()

func ceremony_safety() -> void:
	for gender in ["male","female"]:
		await reset();Ready.satisfy(game);Appearance.set_player_gender(gender);await Hidden.near(self,game)
		Xiaojing.state.diamonds=1314
		check(StarStory.propose("share_home"),"新增要求完成后两种主角均可按原规则求婚："+gender)
		for person in ["linya","zhou","ahe"]:
			await Hidden.person(self,game,person);check(StarStory.invite(person),"原有当面婚礼邀请保留："+gender+person)
		game.change_location("farm",Vector2(1360,800));await frames(4)
		check(StarStory.start_ceremony(),"两种形象都可开始原温室婚礼："+gender)
		game.player.position=Vector2(1280,884);check(StarStory.place_wedding_table(),"准备左研究桌保持原有独立阶段："+gender)
		game.player.position=Vector2(1376,884);await frames(2)
		var valid_fishing: Dictionary=Fishing.snapshot();Fishing.restore(Fishing.defaults())
		var before:=snapshot();check(not Xiaojing.confirm_wedding(true) and snapshot()==before,"最终确认重新检查亲钓记录，失败不扣钻也不推进仪式："+gender)
		Fishing.restore(valid_fishing)
		var house: Dictionary=Housing.snapshot();var lower:=Housing.defaults(GameClock.day);lower.level=3;lower.builtins=HomeLayout.default_builtins(3);Housing.restore(lower)
		before=snapshot();check(not Xiaojing.confirm_wedding(true) and snapshot()==before,"最终确认重新检查完工住宅，不能靠旧求婚状态绕过："+gender)
		Housing.restore(house)
		var items: Dictionary=Inventory.items.duplicate(true);before=snapshot()
		check(not Xiaojing.confirm_wedding(false) and snapshot()==before,"取消最终确认保留全部资源与新目标："+gender)
		game.hud.star_panel.open_panel("desk_right");await frames(4);await capture("ceremony_"+gender);game.hud.star_panel.close_panel()
		check(Xiaojing.confirm_wedding(true) and Xiaojing.state.diamonds==0 and Xiaojing.state.married and Inventory.items==items,"条件齐备仅扣原1314钻石一次，不交付传说鱼："+gender)
		before=snapshot();check(not Xiaojing.confirm_wedding(true) and snapshot()==before,"重复最终确认不再扣除或重放婚姻事务："+gender)
		check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"新门槛完成后的婚姻状态保持原保存兼容："+gender)

func old_married_and_restart() -> void:
	while game.hud.close_active_panel(): pass
	load("res://tests/star_runner.gd").fixture(game,true)
	Housing.restore(Housing.defaults(GameClock.day));Fishing.restore(Fishing.defaults());game.change_location("farm",Vector2(656,440));Letters.refresh();await frames(5)
	var original: Dictionary=snapshot()
	check(Xiaojing.state.married and not Xiaojing.marriage_goals_ready() and FarmSaveStore.valid(original),"已婚旧档缺新增门槛仍是合法存档，不撤销既成婚姻")
	var old: Dictionary=original.duplicate(true);old.version=24;old.erase("farm_layout");old.erase("appearance");old.erase("territory")
	var migrated:=FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.xiaojing==original.xiaojing and migrated.housing==original.housing and migrated.fishing==original.fishing,"真实v24旧婚姻迁移不补发鱼、不补房屋，也不丢原婚后进度")
	check(FarmSaveStore.restore(game,migrated),"无新门槛的旧已婚旅程正常恢复");await frames(5)
	check(Xiaojing.state.married and Xiaojing.state.wedding_day==190 and Housing.state.level==1 and Fishing.state.counts.is_empty(),"迁移保留原婚期与住宅鱼获，不修改完成状态")
	check(FarmSaveStore.write(game,path),"旧已婚旅程可以继续保存到原v25")
	var expected: Dictionary=snapshot();game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	check(snapshot()==expected and Xiaojing.state.married,"重建主场景从已婚旧档恢复，不补扣钻或强制补新目标")
	game.persistence_enabled=false

func capture(name: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var target: String="res://builds/marriage-requirements-"+name+".png"
	get_viewport().get_texture().get_image().save_png(target);captures.append({"name":name,"path":target})
