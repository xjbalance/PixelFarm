extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
var cases: Array=[]
var captures: Array=[]
var capture_mode: bool=false

func run() -> void:
	capture_mode="--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=true;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	var x:=Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=50;x.trust=40;x.bond=3;Xiaojing.restore(x)
	var fishing:=Fishing.defaults();fishing.rod=3;fishing.xp=162;fishing.total=54;fishing.serial=54
	fishing.counts={"crucian":54};fishing.collection=["crucian"];fishing.casts_day=5;fishing.casts=6;fishing.legend_pity=4;Fishing.restore(fishing)
	Aquaculture.state.pens.pen_1.built=true;Aquaculture.state.pens.pen_1.level=3
	Aquaculture.state.collection=["crucian","carp","grass","golden"]
	Aquaculture.state.harvested={"crucian":1,"carp":1,"grass":1,"golden":1}
	Aquaculture.state.xiaojing.stage=2
	MineState.state.unlocked=["mine_a","mine_b","mine_c"]
	check(int(Fishing.data.eternal_chance_divisor)==10,"正式配置将永恒星鲤最终遇鱼概率降至十分之一")
	check(Fishing.encounter_chances("unknown").is_empty(),"无效钓点不会返回伪造概率或除零")
	for star in [true,false]:
		Aquaculture.state.quests=["intro","research"] if star else ["intro"]
		for health in [90,100]:
			LakeEcology.state.health=health
			for day in [40,96]:
				GameClock.day=day;GameClock.minutes=1260;Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit();await frames(3)
				var before: Dictionary=Fishing.snapshot()
				var weights: Dictionary={};var base_total: int=0
				for species in Fishing.available_species("farm_lake"):
					weights[species]=Fishing.fish_weight(species,"farm_lake");base_total+=int(weights[species])
				var chance: Dictionary=Fishing.encounter_chances("farm_lake")
				var expected: float=float(weights.get("eternal",0))/float(base_total)/10.0
				check(Fishing.eligible("eternal","farm_lake") and GameWeather.is_meteor_night(),"概率案例使用自然流星夜与现有鱼竿生态前置："+str([day,health,star]))
				check(chance.has("eternal") and absf(float(chance.eternal)-expected)<.000000001,"最终概率精确为原鱼池占比的十分之一："+str([day,health,star]))
				var sum: float=0.0
				for value in chance.values(): sum+=float(value)
				check(absf(sum-1.0)<.000000001,"所有可遇鱼种的概率之和仍为100%")
				var ordinary_ratios: bool=true
				for species in weights:
					if species=="eternal": continue
					ordinary_ratios=ordinary_ratios and absf(float(chance[species])/float(chance.crucian)-float(weights[species])/float(weights.crucian))<.000000001
				check(ordinary_ratios and Fishing.snapshot()==before,"普通鱼相对权重保留，查看概率不消耗鱼饵或改变鱼获记录")
				var unchanged: bool=true
				for serial in range(1,129):
					Fishing.state.legend_pity=0;var normal: String=Fishing.choose_species("farm_lake",serial)
					Fishing.state.legend_pity=4;unchanged=unchanged and Fishing.choose_species("farm_lake",serial)==normal
				check(unchanged,"旧保底计数在低概率配置下也不影响抽鱼结果")
				cases.append({"season":Calendar.SEASON_IDS[Calendar.season()],"day":day,"ecology":health,"star_unlocked":star,"probability":chance.eternal,"percent":float(chance.eternal)*100,"all_species":chance})
	Aquaculture.state.quests=["intro","research"];LakeEcology.state.health=100
	var spring_autumn_absent: bool=true
	for day in range(1,225):
		if Calendar.season(day) not in [0,2]: continue
		GameClock.day=day;Calendar.restore(Calendar.snapshot(day));GameClock.minutes=1260
		spring_autumn_absent=spring_autumn_absent and Calendar.weather_id(day)!="meteor" and not Fishing.encounter_chances("farm_lake").has("eternal")
	check(spring_autumn_absent,"当前两年春秋均无自然流星夜，实际永恒星鲤概率为0")
	GameClock.day=40;GameClock.minutes=1199;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	check(not Fishing.encounter_chances("farm_lake").has("eternal"),"流星日20:00前仍为0，不提前开放稀有鱼")
	GameClock.minutes=1260;LakeEcology.state.health=89
	check(not Fishing.encounter_chances("farm_lake").has("eternal"),"生态89仍为0，降低概率不绕过原生态门槛")
	LakeEcology.state.health=90;Aquaculture.state.xiaojing.stage=1
	check(not Fishing.encounter_chances("farm_lake").has("eternal"),"共同照料未完成仍为0")
	Aquaculture.state.xiaojing.stage=2;Fishing.state.legend_season=Calendar.season_serial()
	check(not Fishing.encounter_chances("farm_lake").has("eternal"),"本季已经钓获仍为0，不放宽每季一尾上限")
	Fishing.state.legend_season=-1;Fishing.state.legend_pity=4
	check(Fishing.validate(Fishing.snapshot(),GameClock.day),"概率展示使用合法星纹竿经验和旧计数记录")
	if capture_mode and DisplayServer.get_name()!="headless":
		await Touch.place(self,game,"farm",Fishing.point("farm_lake")+Vector2(-32,0));game.hud.fishing_panel.open_panel("farm_lake");await frames(6)
		await capture("current_pool")
		game.hud.fishing_panel.page="book";game.hud.fishing_panel.refresh();await frames(6)
		var scroll: ScrollContainer=game.hud.fishing_panel.content.get_parent();scroll.scroll_vertical=10000;await frames(5)
		await capture("legend_book");game.hud.fishing_panel.close_panel()
	check(FarmSaveStore.restore(game,original),"概率专项恢复原始完整经营状态，不写玩家文件")
	var report:=FileAccess.open("res://builds/fishing-odds-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"cases":cases,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));report.close()
	print("FISHING ODDS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://builds/fishing-odds-"+label+".png"
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"保存当前鱼池和无保底说明的实际窗口："+label)
	captures.append({"name":label,"path":path})
