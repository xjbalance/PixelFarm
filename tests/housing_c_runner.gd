extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
const Home=preload("res://tests/home05_runner.gd")
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6);original=FarmSaveStore.snapshot(game)
	await construction_and_rooms()
	await furniture_rules()
	await storage_rules()
	await appearances_and_spouse()
	await saving_and_controls()
	print("HOUSING C RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func reset() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,original);GameClock.running=false;GameWeather.enabled=false;GameState.set_control_mode("tap",false)
	Housing.restore(Housing.defaults());Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"wheat":999,"iron_bar":99,"crystal":99,"star_fragment":99,"carrot":99}
	await frames(5)
func at_home() -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("home",Housing.HOME+Vector2(32,0));await frames(4)
func at_yard() -> void:
	while game.hud.close_active_panel(): pass
	game.change_location("farm",Housing.YARD+Vector2(32,0));await frames(4)
func transaction() -> Dictionary:
	return {"housing":Housing.snapshot(),"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds}
func required_routes() -> bool:
	game.auto_move.navigation.invalidate();await frames(4);game.auto_move.navigation.rebuild()
	for point in get_tree().get_nodes_in_group("interactables"):
		if not point.is_visible_in_tree(): continue
		var important: bool=("home_action" in point and point.home_action in ["sleep","nap"]) or ("housing_id" in point and point.housing_id=="home") or ("kind" in point and point.kind in ["sleep","exit"]) or ("actor_id" in point and point.actor_id=="mail") or ("kitchen_id" in point and point.kitchen_id=="kitchen")
		if important and game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(): return false
	return true
func construction_and_rooms() -> void:
	await reset()
	var before := transaction()
	check(not Housing.upgrade() and transaction()==before,"远离周砚服务点不能远程升级住宅")
	await Home.visit_builder(self,game)
	Inventory.coins=0;before=transaction()
	check(not Housing.upgrade() and transaction()==before,"房屋扩建余额不足不部分扣材料")
	Inventory.coins=100000;Inventory.items.wood=0;before=transaction()
	check(not Housing.upgrade() and transaction()==before,"房屋扩建缺木材不扣其他资源")
	Inventory.items.wood=999
	check(await Home.finish_upgrade(self,game,1) and Housing.state.level==2 and Housing.slot_count()==4,"真实扩建二级住宅与储物容量")
	await frames(5)
	before=transaction()
	check(not Housing.upgrade(1) and transaction()==before,"旧一级确认不能重放成二级扣费")
	game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.path_to({"kind":"ground","point":Vector2(272,464)}).is_empty(),"二级新增侧间通过真实门洞可行走进入")
	game.auto_move.request(Vector2(272,464));await Touch.finish(self,game,500)
	check(game.player.global_position.distance_to(Vector2(272,464))<4,"实际自动行走能从原小屋走到新增侧间")
	await at_home()
	check(await Home.finish_upgrade(self,game,2) and Housing.state.level==3 and Housing.slot_count()==8,"高级住宅新增更大侧间与八种储物")
	await frames(5);game.auto_move.navigation.rebuild()
	check(not game.auto_move.navigation.path_to({"kind":"ground","point":Vector2(176,304)}).is_empty(),"三级新增空间真正可达而不是改名称")
	check(game.home.get_node("Floor").get_used_cells().size()==198,"原室内地板198格与旧地图内容保留")
	check(await required_routes(),"住宅三级仍能抵达原床、门、故事木盒、厨房和沙发")
	check(await Home.finish_upgrade(self,game,3) and Housing.state.level==4 and Housing.slot_count()==16,"第四级住宅真实施工后开放16种储物")
	await Home.visit_builder(self,game);before=transaction()
	check(not Housing.upgrade() and transaction()==before,"四级满级住宅不可继续扣材料")
func furniture_rules() -> void:
	await reset();check(await Home.finish_upgrade(self,game,1) and await Home.finish_upgrade(self,game,2),"家具夹具通过真实四日施工取得三级住宅");await frames(5)
	for kind in ["bed","table","chair","cabinet","rug","lamp","plant"]:
		check(Housing.buy(kind),"正常材料制作独立家具："+kind)
		check(Housing.place(kind,"home",Vector2i(12,10)),"按真实尺寸放置家具："+kind)
		await frames(4)
		var entry: Dictionary=Housing.state.placed[-1]
		var before := transaction()
		check(not Housing.place(kind,"home",Vector2i(13,12)) and transaction()==before,"放完库存不能再次凭空复制："+kind)
		check(await required_routes(),"摆放后必需床门厨房故事路线保持："+kind)
		check(Housing.move(entry.id,Vector2i(14,12)),"家具可以合法移动："+kind)
		await frames(4)
		check(Housing.recycle(entry.id) and Housing.state.placed.is_empty() and Housing.state.owned[kind]==1,"家具回收返回库存一次："+kind)
		await frames(4);before=transaction()
		check(not Housing.recycle(entry.id) and transaction()==before,"重复回收不复制库存："+kind)
	check(Housing.buy("chair") and Housing.place("chair","home",Vector2i(5,9)),"三级侧间可实际布置家具")
	await frames(4)
	check(Housing.buy("table"),"备一张桌用于碰撞保护测试")
	var before := transaction()
	check(not Housing.place("table","home",Vector2i(5,9)) and transaction()==before,"不能叠放覆盖已放家具")
	for cell in [Vector2i(24,10),Vector2i(20,17),Vector2i(22,8),Vector2i(26,13),Vector2i(12,15)]:
		before=transaction()
		check(not Housing.place("table","home",cell) and transaction()==before,"保护原床门木盒厨房与装修台格："+str(cell))
	await at_yard()
	for kind in ["road","flower","yard_lamp","water_basin"]:
		check(Housing.buy(kind) and Housing.place(kind,"farm",Vector2i(10,20)),"庭院道路花坛灯与小设施真实可摆："+kind)
		await frames(4)
		var entry: Dictionary=Housing.state.placed[-1]
		check(Housing.recycle(entry.id),"庭院设施可回收不毁农田："+kind);await frames(4)
	before=transaction()
	check(not Housing.place("road","farm",Vector2i(20,18)) and not Housing.place("road","farm",Vector2i(34,18)) and transaction()==before,"庭院装饰不能覆盖原农田或湖水")
func storage_rules() -> void:
	await reset();await at_home()
	var coins: int=Inventory.coins
	check(Housing.deposit("wood",12) and Inventory.count("wood")==987 and Housing.state.storage.wood==12,"储物原子转移真实材料")
	check(Housing.deposit("stone",8) and Housing.state.storage.size()==2,"基础小屋支持两种实际储物")
	var before := transaction()
	check(not Housing.deposit("wheat",1) and transaction()==before,"超过储物种类限制整笔不扣背包")
	check(await Home.finish_upgrade(self,game,1) and Housing.state.storage.wood==12 and Housing.state.storage.stone==8,"房屋升级保留已存物品")
	Inventory.items.wood=999;before=transaction()
	check(not Housing.withdraw("wood",1) and transaction()==before,"背包满时取物失败不丢柜中材料")
	Inventory.items.wood=900
	check(Housing.withdraw("wood",12) and Inventory.count("wood")==912 and not Housing.state.storage.has("wood"),"取物成功完整扣减柜存并进入背包")
	before=transaction()
	check(not Housing.withdraw("wood",1) and transaction()==before,"已取空物品不能重复领取")
	check(not Housing.deposit("diamonds",1),"储物不伪造独立钻石账户或未知物品")
func appearances_and_spouse() -> void:
	await reset();check(await Home.finish_upgrade(self,game,1),"样式夹具通过真实两日施工取得二级住宅");await frames(5)
	var floor: TileMapLayer=game.home.get_node("Floor")
	var atlas: TileSetAtlasSource=floor.tile_set.get_source(0)
	var original: String=atlas.texture.resource_path
	check(Housing.buy("wallpaper") and Housing.apply_style("wallpaper"),"墙纸制作后能实际应用样式")
	check(Housing.buy("floor") and Housing.apply_style("floor"),"地板制作后能实际应用样式")
	await frames(4)
	check(atlas.texture.resource_path!=original and floor.get_used_cells().size()==198,"地板仅更换纹理，不改原格数据")
	check(Housing.clear_style("floor") and Housing.clear_style("wallpaper"),"墙纸地板可以还原原样")
	await frames(4)
	check(atlas.texture.resource_path==original,"还原地板纹理正确")
	var before := transaction()
	check(not Housing.buy("spouse_desk") and transaction()==before,"未婚不能绕过婚姻解锁专属家具")
	load("res://tests/star_runner.gd").fixture(game,true)
	Inventory.items.crystal=2 # 婚姻夹具会重置背包；仍准备真实制作材料。
	await at_home()
	check(Housing.buy("spouse_desk") and Housing.place("spouse_desk","home",Vector2i(12,10)) and Housing.has_furniture("spouse_desk"),"已婚可主动摆放小京水样桌，不覆盖原布局")
	await frames(4)
func saving_and_controls() -> void:
	await reset();check(await Home.finish_upgrade(self,game,1) and await Home.finish_upgrade(self,game,2),"保存夹具通过真实四日施工取得三级住宅")
	Housing.buy("chair");Housing.place("chair","home",Vector2i(5,9));Housing.deposit("wood",12)
	await frames(5)
	var saved := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved),"布局与储物进入当前完整存档")
	var expected: Dictionary=AbyssSaveSchema.canonical(Housing.snapshot())
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))) and AbyssSaveSchema.canonical(Housing.snapshot())==expected,"JSON读档保留房型、布局ID、库存和储物")
	await frames(5)
	game.player.position=Vector2(356,464)
	var doorway := FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(doorway),"扩建门洞衔接处同样可以保存，不出现旧坐标范围空隙")
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(doorway))) and game.player.position.distance_to(Vector2(356,464))<1,"在门洞中重启恢复保留位置与房型")
	await frames(5)
	var bad := Housing.snapshot();bad.placed[0].cell=[24,10]
	check(not Housing.validate(bad,GameClock.day),"篡改布局至床位保护区被严格拒绝")
	bad=Housing.snapshot();bad.placed.append(bad.placed[0].duplicate(true))
	check(not Housing.validate(bad,GameClock.day),"重复家具ID整份拒绝")
	var target: Node2D
	for point in get_tree().get_nodes_in_group("housing_furniture"):
		if point.housing_id==Housing.state.placed[0].id: target=point;break
	check(target!=null,"已保存家具在实体地图重建可点击对象")
	if target:
		game.change_location("home",Vector2(272,464));await frames(5)
		check(not game.touch_input.ui_at(game.player.get_canvas_transform()*target.global_position),"屋内任务卡收起，新增侧间家具不被HUD遮住")
		Touch.tap(self,game,target.global_position);await Touch.finish(self,game,600)
		check(game.hud.housing_panel.visible and game.hud.housing_panel.selected_id==target.housing_id,"点击家具自动靠近打开移动回收界面")
		var position: Vector2=game.player.position
		Touch.tap(self,game,Vector2(560,500));await frames(4)
		check(game.player.position==position and game.auto_move.target.is_empty(),"装修模态面板拦截底层地图误触")
		game.hud.housing_panel.ask("fixture",func(): Housing.recycle(target.housing_id))
		GameState.set_control_mode("joystick",false)
		check(not game.hud.housing_panel.pending.is_valid(),"切操作模式立即清除装修待确认回调")
		game.hud.housing_panel.close_panel()
		game.action_cooldown=0;game.interact()
		check(game.hud.housing_panel.visible,"备用摇杆与桌面E沿用家具交互")
