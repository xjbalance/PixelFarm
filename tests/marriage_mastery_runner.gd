extends "res://tests/runner.gd"
## Extra marriage achievements use existing, strictly valid save records.
const Ready=preload("res://tests/marriage_requirement_fixture.gd")
const Hidden=preload("res://tests/xiaojing.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var seed: Dictionary
var capture_mode: bool=false
var captures: Array=[]

func goal(id: String) -> Dictionary:
	for entry in Xiaojing.marriage_goals():
		if entry.id==id: return entry
	return {}

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))

func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))

func reset() -> void:
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,seed),"恢复隔离的合法婚前准备夹具")
	GameClock.running=false;GameWeather.enabled=false;await frames(4)

func run() -> void:
	capture_mode="--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	load("res://tests/star_runner.gd").fixture(game,false);Ready.satisfy(game)
	game.tutorial.restore(GameTutorial.defaults(true));await frames(4)
	seed=snapshot();check(FarmSaveStore.valid(seed) and Xiaojing.base_marriage_ready(),"原条件与六项准备齐备的v27夹具合法")
	await independent_gates()
	await real_completions()
	await final_confirmation()
	await legacy_and_restart()
	await windows()
	var file:=FileAccess.open("res://builds/marriage-mastery-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"save_schema":FarmSaveStore.VERSION,"android_device_tested":false},"\t"));file.close()
	print("MARRIAGE MASTERY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func remove_goal(id: String) -> void:
	match id:
		"village_stories":
			Social.state.completed.erase("ahe_3");Social.state.choices.erase("ahe_3")
		"cooking": Kitchen.state.cooked.erase("carrot_stew")
		"fish_collection":
			Fishing.state.counts.erase("carp");Fishing.state.collection.erase("carp")
			Fishing.state.total=0;Fishing.state.xp=0
			for species in Fishing.state.counts:
				Fishing.state.total+=int(Fishing.state.counts[species])
				Fishing.state.xp+=int(Fishing.state.counts[species])*int(Fishing.data.species[species].xp)
			# Removing a catch can lower a minimal level-3 fixture below 160 XP.
			# Keep the missing species absent while supplying valid common-fish XP.
			Ready.caught_species([])
		"ecology": LakeEcology.state.restored=false;LakeEcology.state.xiaojing_seen=false

func independent_gates() -> void:
	for id in ["village_stories","cooking","fish_collection","ecology"]:
		await reset();remove_goal(id);await Hidden.near(self,game)
		check(FarmSaveStore.valid(snapshot()),"只缺一项的既有业务记录仍是合法存档："+id)
		check(not goal(id).ready and not Xiaojing.base_marriage_ready(),"每项新增准备独立阻止求婚："+id)
		var before:=snapshot()
		check(not StarStory.propose("share_home") and snapshot()==before,"旧未婚婚约豁免不能绕过新增条件且不扣资源："+id)
		check(Xiaojing.marriage_goals_missing_text().contains(str(goal(id).short_label)),"缺项提示定位到具体准备："+id)
	await reset()
	var before:=snapshot()
	for _i in range(30): Xiaojing.marriage_goals();Xiaojing.marriage_goals_text()
	check(snapshot()==before,"反复查看准备清单不补发料理鱼类、奖励或进度")
	Social.restore(Social.defaults(GameClock.day))
	for person in Social.state.friendship: Social.state.friendship[person]=100
	check(not goal("village_stories").ready and goal("village_stories").current==0,"村民满好感不能替代9项个人支线")
	Kitchen.state.cooked.clear()
	for id in Kitchen.RECIPES: Inventory.items[id]=2
	check(not goal("cooking").ready and goal("cooking").current==0,"购买、赠品或库存五种料理不算亲手制作")
	Fishing.restore(Fishing.defaults())
	for id in Fishing.data.species: Inventory.items[Fishing.data.species[id].item]=1
	check(not goal("fish_collection").ready and goal("fish_collection").current==0,"库存和养殖来源的七种鱼不能替代自由钓获图鉴")
	LakeEcology.restore(LakeEcology.defaults(GameClock.day));LakeEcology.state.health=100
	check(not goal("ecology").ready,"生态健康100仍需完成修复并在生态台确认")

func real_completions() -> void:
	await reset();remove_goal("cooking")
	Inventory.items.carrot=10;Inventory.items.potato=10
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(-24,0))
	var carrots: int=Inventory.count("carrot")
	check(goal("cooking").current==4 and Kitchen.cook("carrot_stew"),"实际厨房制作最后缺少的暖锅蔬菜炖")
	check(goal("cooking").ready and Inventory.count("carrot")==carrots-2,"仅认可已提交制作，仍消耗原配方材料")
	await reset();remove_goal("fish_collection")
	Fishing.state.serial+=1;Fishing.state.casts_day=GameClock.day;Fishing.state.casts=1
	Fishing.state.pending="carp";Fishing.state.pending_day=GameClock.day;Inventory.items.fish_carp=999
	check(Fishing.validate(Fishing.snapshot(),GameClock.day) and not Fishing.claim() and not goal("fish_collection").ready,"合法暂存渔获在满包时保留，尚未领取不计图鉴")
	Inventory.remove("fish_carp",1)
	check(Fishing.claim() and goal("fish_collection").ready,"实际领取最后一类渔获后图鉴立即完成")
	var fishing: Dictionary=Fishing.snapshot()
	check(not Fishing.claim() and Fishing.snapshot()==fishing,"同一次领取不重复增加新条件进度")
	await reset();remove_goal("ecology")
	await Touch.place(self,game,"farm",LakeEcology.shore_point()+Vector2(-32,0))
	var coins: int=Inventory.coins
	check(LakeEcology.complete_restoration() and goal("ecology").ready,"实际生态台修复结算后完成婚礼准备")
	check(Inventory.coins==coins+int(LakeEcology.data.reward_coins),"生态仍只发放原有修复奖励")
	coins=Inventory.coins
	check(not LakeEcology.complete_restoration() and Inventory.coins==coins,"重复确认不再次发放生态奖励")
	LakeEcology.state.health=70
	check(goal("ecology").ready,"既往修复成就不因后续健康变化被撤销")
	await reset();remove_goal("village_stories")
	Social.state.friendship.ahe=100;Inventory.items.wild_berry=0;GameState.stamina=100
	await Hidden.person(self,game,"ahe")
	check(Social.accept("ahe"),"现场接取最后一条阿禾个人支线")
	for day in range(2):
		await Touch.place(self,game,"farm",Kitchen.berry_point()+Vector2(0,24))
		check(Kitchen.harvest_berries(),"按真实采摘记录推进最后一条支线："+str(day))
		if day==0:
			GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"原睡眠规则推进第二个采摘日");await frames(4)
	await Touch.place(self,game,"village",Social.site_point("tea_season")+Vector2(0,24))
	check(Social.observe_site("tea_season"),"现场观察已有茶座，仍使用原支线条件")
	await Hidden.person(self,game,"ahe")
	check(Social.finish("ahe",Social.definition("ahe_3").choices.keys()[0]) and goal("village_stories").ready,"最后一条个人支线实际结算后9/9完成")
	check(FarmSaveStore.valid(snapshot()),"真实补齐后的业务记录与新增婚礼判断可合法保存")

func final_confirmation() -> void:
	await reset();await Hidden.near(self,game)
	check(StarStory.propose("share_home"),"六项准备完成后保留原求婚流程")
	for person in ["linya","zhou","ahe"]:
		await Hidden.person(self,game,person)
		check(StarStory.invite(person),"仍需当面邀请村民："+person)
	game.change_location("farm",FarmLayout.transform_point(Vector2(1360,800),"greenhouse"));await frames(4)
	check(StarStory.start_ceremony(),"准备齐备可开始原仪式")
	game.player.position=FarmLayout.point("star:desk_left")+Vector2(0,36)
	check(StarStory.place_wedding_table(),"按原步骤布置左研究桌")
	game.player.position=FarmLayout.point("star:desk_right")+Vector2(0,36);await frames(3)
	var ready: Dictionary=snapshot()
	check(Xiaojing.marriage_ready() and FarmSaveStore.valid(ready),"最终确认前全部原仪式与准备状态合法")
	for id in ["village_stories","cooking","fish_collection","ecology"]:
		check(FarmSaveStore.restore(game,ready),"逐项恢复仪式检查点："+id);await frames(3)
		remove_goal(id);var before:=snapshot()
		check(not Xiaojing.confirm_wedding(true) and snapshot()==before,"最终确认重新检查每项新增条件，缺项不扣钻："+id)
	check(FarmSaveStore.restore(game,ready),"恢复真正齐备的最终确认状态");await frames(3)
	Xiaojing.state.diamonds=1314
	var items: Dictionary=Inventory.items.duplicate(true)
	check(not Xiaojing.confirm_wedding(false) and Xiaojing.state.diamonds==1314,"取消婚礼保留1314钻石")
	check(Xiaojing.confirm_wedding(true) and Xiaojing.state.married and Xiaojing.state.diamonds==0 and Inventory.items==items,"完成所有条件后仍只扣1314钻石，不交付鱼或料理")
	var married: Dictionary=snapshot()
	check(not Xiaojing.confirm_wedding(true) and snapshot()==married,"重复最终确认不能再次结婚或重复扣款")

func legacy_and_restart() -> void:
	await reset();var old: Dictionary=snapshot();old.version=26;old.erase("farm_layout")
	var normalized: Dictionary=FarmSaveSchema.normalize(old)
	check(not normalized.is_empty() and normalized.kitchen==old.kitchen and normalized.social==old.social and normalized.ecology==old.ecology and normalized.fishing==old.fishing,"v26旧档直接认可已保存成就，不重置四项业务记录")
	check(FarmSaveStore.restore(game,normalized),"旧档正常恢复到当前存档格式");await frames(3)
	check(Xiaojing.marriage_goals_ready(),"旧档已完成的条件无需重新制作、钓鱼或交任务")
	var path: String="user://marriage-mastery-proof.json"
	check(FarmSaveStore.write(game,path) and FarmSaveStore.read(path).version==FarmSaveStore.VERSION and not FarmSaveStore.read(path).has("marriage_mastery"),"按当前schema保存，婚礼准备继续复用原业务记录")
	var expected: Dictionary=snapshot()
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	check(snapshot()==expected and Xiaojing.marriage_goals_ready(),"重建主场景读取后全部准备进度与经营状态保持")
	game.persistence_enabled=false
	load("res://tests/star_runner.gd").fixture(game,true)
	Kitchen.restore(Kitchen.defaults(GameClock.day));Social.restore(Social.defaults(GameClock.day));LakeEcology.restore(LakeEcology.defaults(GameClock.day));Fishing.restore(Fishing.defaults())
	var before: Dictionary=snapshot()
	check(FarmSaveStore.valid(before) and not Xiaojing.marriage_goals_ready() and Xiaojing.state.married,"缺少新成就的已婚旧档仍合法，不撤销婚姻")
	check(FarmSaveStore.restore(game,before) and snapshot()==before,"已婚旧档恢复不补发物品、不补扣钻石、不修改婚期")

func windows() -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	await reset()
	Kitchen.state.cooked.clear();Social.restore(Social.defaults(GameClock.day));LakeEcology.restore(LakeEcology.defaults(GameClock.day))
	game.hud.xiaojing_panel.open_panel();await frames(6)
	await capture("missing_overview")
	await load("res://tests/story.gd").touch_button(self,game.hud.xiaojing_panel,"查看婚礼准备详情")
	check(game.hud.xiaojing_panel.page=="preparation","原生点击展开准备详情，日常关系页只显示数量摘要")
	var scroll: ScrollContainer=game.hud.xiaojing_panel.content.get_parent()
	scroll.scroll_vertical=80;await frames(5);await capture("missing_achievements")
	var point: Vector2=game.player.position
	Touch.tap(self,game,game.player.global_position+Vector2(100,0));await frames(4)
	check(game.player.position==point and GameState.modal,"较长准备清单与滚动区域不穿透到地图")
	game.hud.xiaojing_panel.close_panel();await reset()
	game.hud.star_panel.open_panel();await frames(6)
	await load("res://tests/story.gd").touch_button(self,game.hud.star_panel,"查看婚礼准备详情")
	check(game.hud.star_panel.page=="preparation","星光手记使用同一展开详情与状态")
	await capture("completed_achievements")
	game.hud.star_panel.close_panel()
	for size in [Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(6);game.hud.star_panel.open_panel();await frames(6)
		await load("res://tests/story.gd").touch_button(self,game.hud.star_panel,"查看婚礼准备详情")
		check(get_viewport().get_visible_rect().encloses(game.hud.star_panel.get_global_rect()),"婚礼准备窗口保持在横屏范围："+str(size))
		await capture("completed_"+str(size.x)+"x"+str(size.y));game.hud.star_panel.close_panel()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://builds/marriage-mastery-"+label+".png"
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"保存真实婚礼准备窗口："+label)
	captures.append({"name":label,"path":path})
