extends "res://tests/runner.gd"
## 三张设计地图从实体入口实走机关。主线矿洞前置用既有完整流程验证过的夹具隔离。
const Touch=preload("res://tests/touch_navigation.gd")
var original: Dictionary
var forest_checkpoint: Dictionary
var lake_checkpoint: Dictionary
var final_checkpoint: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(7)
	original=FarmSaveStore.snapshot(game)
	Inventory.coins=10000;Inventory.items={"wood":100,"stone":100,"wheat":50,"fishing_bait":20};GameState.rest()
	await setup_and_forest()
	await lake_flow()
	await temple_flow()
	await physical_barriers()
	await persistent_safety()
	await collection_and_gathering()
	print("EXPLORATION D RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func object(id: String) -> Node2D:
	for candidate in get_tree().get_nodes_in_group("interactables"):
		if "exploration_id" in candidate and candidate.exploration_id==id: return candidate
	return null
func transaction() -> Dictionary:
	return {"exploration":Exploration.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina}
func walk(id: String, maximum: int = 2400) -> bool:
	while game.hud.close_active_panel(): pass
	var target := object(id)
	if target==null: return false
	game.auto_move.request(target.global_position)
	await Touch.finish(self,game,maximum)
	while game.hud.close_active_panel(): pass
	return Exploration.near_id(id)
func route(id: String) -> bool:
	game.auto_move.navigation.rebuild()
	var target := object(id)
	if target==null: return false
	return not game.auto_move.navigation.path_to({"kind":"object","object":target,"point":target.global_position}).is_empty()
func world_sync() -> void:
	await frames(5);game.auto_move.navigation.rebuild()
func read(id: String) -> bool:
	if not await walk(id): return false
	return Exploration.read(id)
func operate(id: String) -> bool:
	if not await walk(id): return false
	var ok: bool=Exploration.operate(id);await world_sync();return ok
func setup_and_forest() -> void:
	for area in Exploration.AREAS:
		check(game.mine_maps.has(area) and game.mine_maps[area].ground.get_used_cells().size()==1120,"实体地图完整40×28格："+area)
		var atlas: TileSetAtlasSource=game.mine_maps[area].ground.tile_set.get_source(0)
		check(atlas.get_tile_data(Vector2i(1,0),0).get_collision_polygons_count(0)==1 and atlas.get_tile_data(Vector2i(2,0),0).get_collision_polygons_count(0)==1,"岩壁/树墙与水格都有真实物理碰撞："+area)
	check(Exploration.unlocked("mist_forest") and not Exploration.unlocked("lake_ruins") and not Exploration.unlocked("old_temple"),"初始森林开放，其余遗址有实际前置")
	game.change_location("lake_ruins");await frames(4)
	check(GameState.location=="farm","直接地图跳转不能绕过湖底前置")
	game.change_location("farm",Vector2(288,352));await world_sync()
	check(await walk("forest_entry") and Exploration.enter("mist_forest"),"从农场真实林径门牌进入森林")
	await world_sync()
	check(GameState.location=="mist_forest" and game.player.get_parent()==game.mine_maps.mist_forest.actors,"原玩家真正走在森林地图而非菜单路线盘")
	check(route("forest_exit") and route("forest_order") and route("forest_spring") and route("forest_winter"),"森林闭径时出口、提示与首末石桩均可达")
	check(not route("forest_archive"),"缠枝未开时后方档案不可隔墙到达")
	check(await walk("forest_spring"),"实际走近第一石桩")
	var before := transaction()
	check(not Exploration.operate("forest_spring") and transaction()==before,"没读现场刻痕不能盲点领通路")
	check(await read("forest_order"),"实地读完四季刻痕获得固定顺序线索")
	check(not await operate("forest_winter") and Exploration.state.forest.step==0,"错误季节次序不奖励，可从零重试")
	check(await operate("forest_spring") and await operate("forest_summer") and Exploration.state.forest.step==2,"走到分散的前两处石桩实际点亮")
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and Exploration.state.forest.step==2,"机关中途保存恢复保留正确两步进度")
	await world_sync()
	check(await operate("forest_autumn") and await operate("forest_winter") and Exploration.state.forest.open,"实走四季机关打开隐藏林径")
	check(route("forest_archive") and route("forest_cache"),"林径开启后真实碰撞/导航让档案与宝箱可达")
	check(await read("forest_archive"),"沿新林径实际找到洪水排水副页")
	check(await walk("forest_cache"),"实际走进织布匣合法位置")
	Inventory.items.rare_fiber=999;before=transaction()
	check(not Exploration.claim_chest("forest_cache") and transaction()==before,"背包满时箱内整批物品不丢失")
	Inventory.items.erase("rare_fiber")
	check(Exploration.claim_chest("forest_cache") and Inventory.count("rare_fiber")==2,"隐藏宝箱真实入包且标记领取")
	before=transaction()
	check(not Exploration.claim_chest("forest_cache") and transaction()==before,"重复开箱不能刷稀有材料")
	check(await walk("pond_cache") and Exploration.claim_chest("pond_cache"),"可选岔路通往独立林池宝箱")
	check(await walk("forest_herbs") and Exploration.gather("forest_herbs"),"森林特殊植物实际采样并记录本季")
	before=transaction()
	check(not Exploration.gather("forest_herbs") and transaction()==before,"重新交互不能越过植物恢复间隔")
	check(Fishing.sites.has("forest_pool"),"森林实体林池注册共享鱼种钓点")
	GameState.select_tool(GameState.tools.find("fishing_rod"))
	var resolved: Dictionary=FishingWorld.resolve_water(game,Fishing.point("forest_pool",true))
	check(not resolved.is_empty() and resolved.object.fish_point_id=="forest_pool","点击森林真实水格解析到正确岸边钓点")
	check(game.mine_maps.mist_forest.is_fishing_water(Vector2i(32,21)),"林池水格实际不可行走而非地面贴图")
	forest_checkpoint=FarmSaveStore.snapshot(game)
	check(await walk("forest_exit") and Exploration.exit_area(),"森林出口随时沿实体通道返回农场")
	await world_sync()
func lake_flow() -> void:
	check(await walk("lake_entry"),"从原农场东岸实走到排水检修口")
	var before := transaction()
	check(not Exploration.inspect_entrance("lake_ruins") and transaction()==before,"仅有森林档案不能绕过湖泊生态修复")
	# 三日实际生态修复已由ecology_b_runner验证；此处隔离遗址开门前置。
	var ecology := LakeEcology.defaults(GameClock.day);ecology.plants=3;ecology.cycle=true;ecology.restored=true;ecology.health=95
	LakeEcology.restore(ecology)
	check(Exploration.inspect_entrance("lake_ruins") and Exploration.unlocked("lake_ruins") and "drain_plate" in Exploration.state.facts,"现场按档案核对排水刻度开放封闭检修廊")
	check(Exploration.enter("lake_ruins"),"从地表检修口进入真实干燥拱廊")
	await world_sync()
	check(GameState.location=="lake_ruins" and not route("lake_south") and not route("lake_archive"),"初始积水阻挡南室与东档案，未在湖底普通行走")
	check(route("lake_exit") and route("lake_hint") and route("lake_north"),"封闭廊的提示、退水控制与出口保持可达")
	check(await read("lake_hint") and await operate("lake_north"),"按现场规程开启北室退水阀")
	check(Exploration.state.lake.water==1 and route("lake_south") and not route("lake_archive"),"第一次退水真正露出南室，主水渠仍挡东侧")
	check(await walk("lake_cache") and Exploration.claim_chest("lake_cache"),"退水后可以实走到原积水区域取检修箱")
	check(await walk("lake_hint") and Exploration.reset_puzzle("lake_ruins"),"入口控制可安全重置未完成水位，不把玩家困在淹没房")
	await world_sync()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)) and not route("lake_south"),"已取南室箱后重置水位仍可合法保存，关闭碰撞生效")
	check(await operate("lake_north"),"重置后能够重新退水，不永久锁死")
	check(not await operate("lake_south") and not Exploration.state.lake.open,"未分流时南阀反馈失败，不靠错误顺序开桥")
	check(await operate("lake_flow") and Exploration.state.lake.flow==1,"中央实物分流杆将水导进旁渠")
	check(await operate("lake_south") and Exploration.state.lake.open and Exploration.state.lake.water==0,"南阀完成后石桥真实露出")
	check(route("lake_archive") and route("lake_archive_cache"),"开桥及时刷新物理导航，让东室档案可达")
	check(await read("lake_archive") and await walk("lake_archive_cache") and Exploration.claim_chest("lake_archive_cache"),"穿过石桥实际取得湖务原件与编目匣")
	check(game.mine_maps.lake_ruins.is_fishing_water(Vector2i(25,16)) and not game.mine_maps.lake_ruins.is_fishing_water(Vector2i(25,13)),"石桥只露出指定通路，旁边地下水渠仍不可行走")
	check(Fishing.sites.has("ruins_channel"),"封闭水渠提供实际隐藏区域钓鱼岸点")
	lake_checkpoint=FarmSaveStore.snapshot(game)
	check(await walk("lake_exit") and Exploration.exit_area(),"排水廊出口能沿原路返回湖岸")
	await world_sync()
func temple_flow() -> void:
	# 既有主线矿区完整操作由原mining/river测试验证，保留本轮已取的探索物品。
	var held := Inventory.items.duplicate(true)
	load("res://tests/star_runner.gd").fixture(game,false)
	for item in ["forest_herb","rare_fiber","ancient_token","crystal","starlight_ore"]:
		if held.has(item): Inventory.items[item]=held[item]
	Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	game.change_location("village");await world_sync()
	check(await walk("temple_entry") and Exploration.inspect_entrance("old_temple"),"实走旧桥东岸，矿洞工艺与两份档案共同开放神庙")
	check(Exploration.enter("old_temple"),"从村东石门进入实体归航庭")
	await world_sync()
	check(route("temple_exit") and route("temple_hint") and route("temple_mirror") and not route("temple_water"),"镜门关闭时基础控制与出口可达，后方符台不可穿墙")
	check(await read("temple_hint"),"读真实光谱图获镜面方向与归航次序")
	check(not await operate("temple_grain"),"镜面未校正时不能只点符台跳过第一机关")
	check(await operate("temple_mirror") and Exploration.state.temple.mirror==1 and not route("temple_water"),"镜面朝顶有可见状态但未打开错误光路")
	check(await operate("temple_mirror") and Exploration.state.temple.mirror==2 and route("temple_water"),"镜面朝西实际打开通往中庭的光门")
	check(not await operate("temple_water") and Exploration.state.temple.step==0,"归航符台错序可重新开始而无奖励")
	check(await walk("temple_hint") and Exploration.reset_puzzle("old_temple"),"入口回路可安全重新校镜，不锁住出口")
	await world_sync()
	check(route("temple_exit") and not route("temple_water"),"重置光门后仍留在安全侧且碰撞重新关闭")
	await operate("temple_mirror");await operate("temple_mirror")
	check(await operate("temple_grain") and await operate("temple_water") and await operate("temple_star") and Exploration.state.temple.open,"真实走过三处分散符台完成多步骤终室机关")
	check(route("temple_archive") and route("temple_cache"),"最终石门打开后深处档案与奖励真实可达")
	check(await read("temple_archive") and await walk("temple_cache") and Exploration.claim_chest("temple_cache"),"实地归航档案承接星辉矿道用途并领取唯一资源")
	check(Xiaojing.state.diamonds==1400,"探索箱与机关没有直接生产钻石")
	check(await walk("temple_token") and Exploration.gather("temple_token"),"稀有水纹片有有间隔的实地可重复维护来源")
	var before := transaction()
	check(not Exploration.gather("temple_token") and transaction()==before,"重复维护台不能无限复制稀有材料")
	check(await walk("temple_archive"),"回到实际档案桌制作收藏封记")
	for id in Exploration.data.recipes:
		check(Exploration.craft(id) and Inventory.count(id)==1,"探索材料可真实制成独立收藏："+id)
		before=transaction()
		check(not Exploration.craft(id) and transaction()==before,"收藏手作只结算一次，不重复扣料："+id)
	final_checkpoint=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(final_checkpoint),"三地图、机关、档案、宝箱与手作完整进度可保存")
func persistent_safety() -> void:
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(final_checkpoint))),"完成档经JSON可恢复新区域位置与全部进度")
	await world_sync()
	var expected: Dictionary=AbyssSaveSchema.canonical(final_checkpoint.exploration)
	check(AbyssSaveSchema.canonical(Exploration.snapshot())==expected and GameState.location=="old_temple","读档不重置机关档案或奖励标记")
	var before := transaction()
	check(not Exploration.claim_chest("temple_cache") and transaction()==before,"读档不会重新开放已取宝箱")
	var bad := final_checkpoint.duplicate(true);bad.exploration.chests.append("invented_box")
	check(not FarmSaveStore.valid(bad),"未知奖励ID不能进入存档")
	bad=final_checkpoint.duplicate(true);bad.exploration.temple.step=1.5
	check(not FarmSaveStore.valid(bad),"小数机关步骤整档拒绝")
	bad=final_checkpoint.duplicate(true);bad.ecology.restored=false
	check(not FarmSaveStore.valid(bad),"未恢复生态的伪造湖底解锁档被纯快照校验拒绝")
	var old := original.duplicate(true);old.version=18;old.erase("farm_layout");old.erase("appearance");old.erase("territory");old.erase("exploration");old.housing=load("res://tests/home05_runner.gd").legacy_housing(old.housing)
	var migrated := FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.exploration.unlocked==["mist_forest"] and migrated.xiaojing==old.xiaojing and migrated.items==old.items,"旧v18只补初始森林，不清空任何旧物品关系或凭空解锁地图")
	if not migrated.is_empty(): check(FarmSaveSchema.normalize(migrated)==migrated,"探索迁移幂等，不重复发奖")
func collection_and_gathering() -> void:
	check(FarmSaveStore.restore(game,final_checkpoint),"额外收藏流程从真实通关检查点继续")
	await world_sync()
	check(not Exploration.claim_collection(),"未实际四季采样时不能只靠数值领完整册子")
	for row in [[225,0],[253,1],[281,2],[309,3]]:
		GameClock.day=row[0];GameClock.minutes=600;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
		game.change_location("mist_forest");await world_sync()
		check(await walk("forest_herbs"),"实际重返林地进行季节采样："+str(row[1]))
		var held: int=Inventory.count("forest_herb")
		check(Exploration.gather("forest_herbs") and Inventory.count("forest_herb")==held+(1 if row[1]==3 else 2),"季节采样有实际产物，冬季减量："+str(row[1]))
	game.change_location("old_temple");await world_sync();check(await walk("temple_archive"),"四季样本带回实物档案桌")
	var tokens: int=Inventory.count("ancient_token")
	check(Exploration.claim_collection() and Inventory.count("ancient_token")==tokens+2,"四季采样与三种手作组成可玩的长期收藏结算")
	var before := transaction()
	check(not Exploration.claim_collection() and transaction()==before,"长期收藏完成标志保存且不重复领奖")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"长期日期与采样进度保持存档兼容")

func physical_barriers() -> void:
	check(FarmSaveStore.restore(game,final_checkpoint),"物理隔墙检查从真实完成状态恢复")
	game.change_location("mist_forest",Vector2(80,336));await world_sync()
	var collider: CircleShape2D=game.player.get_node("CollisionShape2D").shape
	Input.action_press("move_left");await frames(40);Input.action_release("move_left");await frames(3)
	check(game.player.global_position.x>=64+collider.radius-.5,"真实键盘移动受森林树墙阻挡，不能穿墙")
	game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.walkable(Vector2i(0,0)),"新地图边界墙进入AStar不可通行格")
	var before_position: Vector2=game.player.global_position
	game.auto_move.request(Vector2(16,16));await Touch.finish(self,game,180)
	check(game.auto_move.state==game.auto_move.State.FAILED and game.player.global_position==before_position,"点击新地图岩壁有限失败，不反复卡住寻路")
	var target := Exploration.point("forest_reeds")
	game.player.global_position=target+Vector2(-40,0);await frames(4)
	check(Exploration.near_id("forest_reeds"),"无墙时采样位置是合法近距")
	var blocker := StaticBody2D.new();blocker.position=target+Vector2(-20,0);blocker.collision_layer=1
	var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=Vector2(4,36);shape.shape=rectangle;blocker.add_child(shape)
	game.mine_maps.mist_forest.actors.add_child(blocker);await frames(4)
	var before := transaction()
	check(not Exploration.near_id("forest_reeds") and not Exploration.gather("forest_reeds") and transaction()==before,"生产层也拒绝隔薄墙采样，不能靠54px距离绕过实体障碍")
	blocker.queue_free();await frames(4)
	check(Exploration.near_id("forest_reeds"),"临时障碍解除后合法交互恢复")
	Kitchen.state.buff={"id":"thrift","remaining":90.0};GameState.stamina=1
	var fiber: int=Inventory.count("rare_fiber")
	check(Exploration.gather("forest_reeds") and GameState.stamina==0 and Inventory.count("rare_fiber")==fiber+1,"探索采样遵循厨房节能增益，1体力可支付折后2点动作")
