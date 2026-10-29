extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	original=FarmSaveStore.snapshot(game)
	await core_transactions()
	await full_bag_and_restart()
	await upgrades_and_conditions()
	await controls_and_navigation()
	await framerate_integrator()
	print("FISHING B RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original)
	GameClock.running=false;GameWeather.enabled=true;GameClock.minutes=600
	Inventory.items={"wood":999,"copper_bar":999,"iron_bar":999,"crystal":999,"star_alloy":999,"wheat":999,"fishing_bait":99}
	Inventory.coins=10000
	Fishing.restore(Fishing.defaults())
	GameState.set_control_mode("tap",false)
	var rod: int=GameState.tools.find("fishing_rod")
	if rod>=0: GameState.select_tool(rod)
	await Touch.place(self,game,"farm",Vector2(944,464))
	game.player.action_time=0
func pilot(maximum: int = 3600) -> bool:
	for i in range(maximum):
		if not Fishing.active(): return Fishing.session.phase in ["landed","caught"]
		var holding: bool=float(Fishing.session.player)>float(Fishing.session.fish)
		Fishing.tick(1.0/120.0,holding)
	return false
func stamp() -> Dictionary:
	return {"fishing":Fishing.snapshot(),"items":Inventory.items.duplicate(true),"stamina":GameState.stamina,"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}
func core_transactions() -> void:
	await reset()
	check(GameState.tools.find("fishing_rod")==8,"鱼竿追加第九工具且保留旧八工具索引")
	await Touch.place(self,game,"farm",Vector2(656,440))
	var before := stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"远离岸边不能远程消耗鱼饵或收鱼")
	await Touch.place(self,game,"farm",Vector2(944,464))
	Inventory.items.fishing_bait=0;before=stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"无饵不开始且不扣体力")
	Inventory.items.fishing_bait=99;GameState.stamina=2;before=stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"体力不足不先扣鱼饵")
	GameState.stamina=100;game.player.action_time=.12;before=stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"农具人物动作锁未结束前不能抛竿冲突")
	game.player.action_time=0;GameState.select_tool(0);before=stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"未装备鱼竿不能绕过工具条件")
	GameState.select_tool(8)
	check(Fishing.start("farm_lake") and Inventory.count("fishing_bait")==98 and GameState.stamina==97 and Fishing.state.casts==1,"合法抛竿一次扣一份饵三体力并记录尝试")
	before=stamp()
	check(not Fishing.start("farm_lake") and stamp()==before,"等待上钩时重复点击不能重复扣费")
	for i in range(600):
		if Fishing.session.phase!="waiting": break
		Fishing.tick(1.0/120.0,false)
	check(Fishing.session.phase=="playing","鱼咬钩等待在有限时间进入实际操作")
	before=stamp();Fishing.land()
	check(stamp()==before and Fishing.state.total==0,"未达到实际追鱼进度时不能直接调用成功结算")
	check(pilot() and Fishing.state.total==1 and Fishing.state.collection.size()==1 and Fishing.state.xp>0,"真实追鱼小游戏完成后才给鱼和经验")
	var species: String=Fishing.session.species
	check(Inventory.count(Fishing.data.species[species].item)==1 and Fishing.state.pending=="","成功鱼以原物品ID进入现有背包")
	before=stamp();Fishing.land()
	check(not Fishing.claim() and stamp()==before,"同一成功结算不能重复领取鱼或经验")
	check("first" in Fishing.state.achievements,"首次实操钓获记录唯一成就")
	for i in range(11):
		GameState.stamina=100
		check(Fishing.start("farm_lake"),"当日剩余合法抛竿次数："+str(i+2))
		Fishing.cancel()
	before=stamp()
	check(Fishing.remaining_casts()==0 and not Fishing.start("farm_lake") and stamp()==before,"失败或取消同样占用十二次日限，不能无限刷鱼")
	GameClock.minutes=1200
	check(GameClock.request_sleep(GameClock.day) and Fishing.remaining_casts()==12,"原合法跨日后钓鱼额度重新开放")
	before=stamp();GameClock.day_advanced.emit();Fishing.claim()
	check(stamp()==before,"重复日信号不重复刷新鱼获或发放奖励")
func full_bag_and_restart() -> void:
	await reset();check(Fishing.start("farm_lake"),"满包回归先开始真实抛竿")
	var item: String=Fishing.data.species[Fishing.session.species].item
	Inventory.items[item]=999
	check(pilot() and Fishing.state.pending!="" and Fishing.state.total==0 and Inventory.count(item)==999,"小游戏成功但满包时鱼留在持久水桶，不丢失")
	var saved: Dictionary=Fishing.snapshot()
	var before := stamp()
	Fishing.restore(JSON.parse_string(JSON.stringify(saved)))
	check(Fishing.snapshot()==saved and Fishing.state.pending!="" and not Fishing.active(),"成功待领鱼随JSON保存恢复，QTE不重播")
	check(not Fishing.start("farm_lake"),"未领取水桶鱼之前不能再次抛竿叠加奖励")
	check(not Fishing.claim() and stamp()==before,"满包反复领取不增加经验、鱼或扣额外资源")
	Inventory.remove(item,1)
	check(Fishing.claim() and Inventory.count(item)==999 and Fishing.state.total==1 and Fishing.state.pending=="","腾出空间后一尾鱼只领取一次")
	check(not Fishing.claim(),"水桶领取完成后重复调用无效")
	await reset();Fishing.start("farm_lake");before=stamp();saved=Fishing.snapshot()
	Fishing.restore(JSON.parse_string(JSON.stringify(saved)))
	check(not Fishing.active() and stamp()==before and Fishing.state.casts==1,"进行中读档保留已耗饵体力与尝试，不自动完成或重付费")
	check(Fishing.validate(Fishing.snapshot(),GameClock.day),"正常钓鱼状态通过严格持久化校验")
	var bad := Fishing.snapshot();bad.pending="invented";bad.pending_day=GameClock.day
	check(not Fishing.validate(bad,GameClock.day),"未知水桶鱼ID被拒绝")
	bad=Fishing.snapshot();bad.xp+=1
	check(not Fishing.validate(bad,GameClock.day),"不匹配真实鱼获的伪造经验被拒绝")
func progress_fixture(total: int, day: int) -> void:
	GameClock.day=day;Calendar.restore(Calendar.snapshot(day))
	var s: Dictionary=Fishing.defaults()
	s.serial=total;s.total=total;s.xp=total*3;s.counts={"crucian":total};s.collection=["crucian"];s.achievements=["first"]
	s.casts_day=day;s.casts=posmod(total-1,12)+1
	Fishing.restore(s)
func upgrades_and_conditions() -> void:
	await reset();var before := stamp()
	check(not Fishing.upgrade_rod(1) and stamp()==before,"未达真实钓鱼经验不能仅凭金币升级")
	progress_fixture(14,2)
	check(Fishing.validate(Fishing.snapshot(),GameClock.day),"升级夹具代表合法十四尾鱼与两日尝试历史")
	check(Fishing.upgrade_rod(1) and Fishing.state.rod==2,"二级竿需要经验和真实材料金币")
	before=stamp()
	check(not Fishing.upgrade_rod(1) and stamp()==before,"重复确认旧级别不连升或再次扣费")
	progress_fixture(54,5);Fishing.state.rod=2
	check(Fishing.upgrade_rod(2) and Fishing.state.rod==3,"星纹竿按更高经验和材料条件升级")
	before=stamp()
	check(not Fishing.upgrade_rod(3) and stamp()==before,"满级竿升级请求不扣费")
	check(Fishing.craft_hook() and Inventory.count("fishing_hook")==1 and Fishing.equip_hook() and Fishing.state.hook_charges==30,"真实制作并装上三十次耐久鱼钩")
	check(Fishing.start("farm_lake") and Fishing.state.hook_charges==29,"鱼钩每次抛竿消耗一次耐久")
	Fishing.cancel();check(Fishing.state.hook_charges==29,"取消不返还鱼钩耐久")
	var bait: int=Inventory.count("fishing_bait")
	check(Fishing.craft_bait(2) and Inventory.count("fishing_bait")==bait+12,"原小麦实际加工为共享背包鱼饵")
	Inventory.items.fish_crucian=1
	var fry: int=Inventory.count("fry_crucian")
	check(Fishing.breeding_fry("crucian",1) and Inventory.count("fry_crucian")==fry+2 and Inventory.count("fish_crucian")==0,"钓获同ID亲鱼可有成本转入现有鱼栏苗源")
	GameClock.day=85;GameClock.minutes=600;Calendar.restore(Calendar.snapshot())
	check(Fishing.eligible("crucian","farm_lake") and not Fishing.eligible("carp","farm_lake"),"冬季钓鱼种群与原鱼谱季节一致")
	GameClock.day=4;GameClock.minutes=600;Calendar.restore(Calendar.snapshot())
	check(not Fishing.eligible("golden","farm_lake"),"二级竿也不能跳过原金鳞鱼养殖研究前置")
	var p: Dictionary=Aquaculture.pen("pen_1");p.built=true;p.level=3
	Aquaculture.state.collection=["crucian","carp","grass","golden"];Aquaculture.state.harvested={"crucian":1,"carp":1,"grass":1,"golden":1}
	Aquaculture.state.quests=["intro","research"];MineState.state.unlocked=["mine_a","mine_b","mine_c"]
	check(Fishing.eligible("golden","farm_lake"),"养殖研究和春季雨水满足后金鳞鱼实际进入候选")
	GameClock.day=40;GameClock.minutes=1260;Calendar.restore(Calendar.snapshot())
	check(Fishing.eligible("star","farm_lake"),"夏季夜晚与真实晶石研究条件支持星辉鱼")
	var ecology := get_node_or_null("/root/LakeEcology")
	check(ecology!=null,"稀有鱼由统一湖泊生态状态提供前置")
	if ecology:
		ecology.state.health=39
		check(Fishing.daily_capacity("farm_lake")==8 and Fishing.daily_capacity("village_river")==12,"低生态减少湖泊可用抛竿数量，河流仍用共享十二次总限额")
		var low_weight: int=Fishing.fish_weight("star","farm_lake")
		ecology.state.health=100
		check(Fishing.fish_weight("star","farm_lake")>low_weight and Fishing.fish_weight("star","mine_stream")==int(Fishing.data.species.star.weight),"高生态实际提升湖泊稀有权重，不凭空改变矿洞鱼群")
		ecology.state.health=89
		Aquaculture.state.xiaojing.stage=2
		check(not Fishing.eligible("eternal","farm_lake"),"生态89不能提前遇见永恒星鲤")
		ecology.state.health=90
		check(not Fishing.eligible("eternal","farm_lake"),"未达520解锁的小京不能被伪造的湖畔事件替代")
		var x := Xiaojing.defaults();x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=50;x.trust=40;x.bond=3
		Xiaojing.restore(x)
		check(Fishing.eligible("eternal","farm_lake"),"生态90、流星夜、小京湖畔研究和星纹竿共同解锁永恒星鲤")
		var unchanged: bool=true
		var ordinary: bool=false
		var rare: bool=false
		for serial in range(1,257):
			Fishing.state.legend_pity=0
			var expected: String=Fishing.choose_species("farm_lake",serial)
			ordinary=ordinary or expected!="eternal";rare=rare or expected=="eternal"
			for retired in range(1,5):
				Fishing.state.legend_pity=retired
				unchanged=unchanged and Fishing.choose_species("farm_lake",serial)==expected
		check(unchanged and ordinary and rare,"旧存档保底计数0至4均不影响256次加权抽取，普通鱼和传说鱼均可能出现")
		check(load("res://tests/marriage_requirement_fixture.gd").next_weighted_cast("crucian"),"选择实际普通鱼抽取的合法尝试夹具")
		Fishing.state.legend_pity=4
		check(Fishing.start("farm_lake") and Fishing.session.species=="crucian" and Fishing.state.legend_pity==4,"旧计数已满仍能实际遇到普通鱼，抛竿不再增长保底计数")
		Fishing.cancel()
		check(load("res://tests/marriage_requirement_fixture.gd").next_weighted_cast("eternal"),"用合法尝试元数据选择普通加权抽中的传说鱼")
		check(Fishing.start("farm_lake") and Fishing.session.species=="eternal" and pilot() and Inventory.count("fish_eternal")==1,"普通加权遇到永恒星鲤后仍须完成真实小游戏")
		check(Fishing.state.legend_pity==4,"钓获后旧计数仍仅作为兼容数据保留，不参与或改变概率")
		var saved: Dictionary=Fishing.snapshot()
		Fishing.restore(JSON.parse_string(JSON.stringify(saved)))
		check(Fishing.snapshot()==saved and Fishing.validate(Fishing.snapshot(),GameClock.day),"携带旧保底计数的已钓获存档能正常读取且不重发鱼")
		check(Fishing.state.legend_season==Calendar.season_serial(),"传说鱼成功记录捕获季节，不由领取时重置")
		check(not Fishing.eligible("eternal","farm_lake") and Catalog.sell_price("fish_eternal")==0,"永恒星鲤每季限一尾且不能卖钱或兑换钻石")
func controls_and_navigation() -> void:
	await reset()
	var points := {}
	for node in get_tree().get_nodes_in_group("interactables"):
		if "fish_point_id" in node: points[node.fish_point_id]=node
	check(points.size()>=3,"三个既有实体地图拥有真实岸边钓点")
	var target: Dictionary=FishingWorld.resolve_water(game,Vector2(1104,592))
	check(not target.is_empty() and target.object.fish_point_id=="farm_lake" and target.point==Vector2(976,464),"点击湖水解析为岸点而不是走进水里")
	game.auto_move.request(Vector2(1104,592));await Touch.finish(self,game,600)
	check(game.hud.fishing_panel.visible and Fishing.near_site("farm_lake"),"真实水面点击自动靠岸后打开钓鱼操作")
	var position: Vector2=game.player.position
	Touch.tap(self,game,Vector2(880,624));await frames(4)
	check(game.player.position==position and game.auto_move.target.is_empty(),"钓鱼界面触点不穿透到地图移动")
	game.hud.close_active_panel()
	GameState.set_control_mode("joystick",false);game.action_cooldown=0;game.interact()
	check(game.hud.fishing_panel.visible,"备用摇杆和桌面E沿相同岸点交互")
	game.hud.close_active_panel()
	for id in Fishing.sites:
		var site: Dictionary=Fishing.sites[id]
		if site.area=="mine_b": MineState.state.unlocked=["mine_a","mine_b"]
		await Touch.place(self,game,site.area,WorldTravel.entry(site.area))
		game.auto_move.navigation.rebuild()
		var route: PackedVector2Array=game.auto_move.navigation.path_to({"kind":"object","object":points[id],"point":Fishing.point(id)})
		check(not route.is_empty(),"真实地图岸点可达："+id)
		check(not game.auto_move.navigation.walkable(game.auto_move.navigation.cell(Fishing.point(id,true))),"钓点水面仍有真实阻挡："+id)
func framerate_integrator() -> void:
	await reset()
	var base := Fishing.snapshot()
	var results: Array=[]
	for fps in [30,60,120]:
		Fishing.restore(base);Inventory.items.fishing_bait=99;GameState.stamina=100
		check(Fishing.start("farm_lake"),"帧率积分夹具合法开始："+str(fps))
		for i in range(fps*4): Fishing.tick(1.0/float(fps),int(i/(fps/2))%2==0)
		results.append(Fishing.session.duplicate(true))
	for index in range(1,results.size()):
		check(results[0].phase==results[index].phase and absf(float(results[0].player)-float(results[index].player))<.000001 and absf(float(results[0].fish)-float(results[index].fish))<.000001 and absf(float(results[0].progress)-float(results[index].progress))<.000001,"30/60/120fps固定输入得到相同小游戏难度与进度")
	Fishing.cancel()
