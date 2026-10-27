extends "res://tests/runner.gd"
## 真实输入与物理帧覆盖0.7.1的移动目标、重复工具、动态导航和生命周期。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(8)
	initial=FarmSaveStore.snapshot(game)
	await moving_press()
	await action_guard()
	await pointer_conflicts()
	if "--repro-only" not in OS.get_cmdline_user_args():
		await dynamic_paths()
		await lifecycle()
		await migration()
		await sale_safety()
	print("PALM 071 RESULT: %d checks, %d failures" % [checked,failed])
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func reset_world(at: Vector2 = Vector2(656,480)) -> void:
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameState.manual_tool=false
	GameState.set_control_mode("tap",false)
	for index in game.touch_input.fingers.keys(): Touch.finger(self,Vector2.ZERO,false,index)
	await Touch.place(self,game,"farm",at)
	game.action_cooldown=0

func moving_press() -> void:
	await reset_world(Vector2(656,480))
	var npc: Node2D=game.world.get_node("Actors/Linya")
	npc.position=Vector2(752,480);npc.route.clear()
	await frames(3)
	var screen: Vector2=game.player.get_canvas_transform()*(npc.position+Vector2(0,-20))
	Touch.finger(self,screen,true,81)
	npc.position=Vector2(848,480)
	Touch.finger(self,screen,false,81)
	check(game.auto_move.target.get("object")==npc,"NPC在按下后移走，释放仍保留原人物而不是地面意图")
	await Touch.finish(self,game,500)
	check(game.hud.dialogue.visible and game.player.position.distance_to(npc.position)<=54,"保留人物目标后沿实际新位置靠近并对话一次")
	game.hud.close_active_panel()

func action_guard() -> void:
	await reset_world(Vector2(624,592))
	game.player.facing=Vector2.RIGHT
	GameState.select_tool(GameState.tools.find("water"));GameState.manual_tool=false
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false},"19,17":{"crop":"carrot","days":0,"watered":false}}
	game.interact()
	await frames(7) # 单次农活在0.10秒生效帧后检查结果。
	check(game.farm.plots["20,18"].watered,"真实交互入口向右完成第一次浇水")
	await frames(4) # 总共11帧，仍处于原0.24秒动作内。
	game.farm.plots["20,18"].watered=false
	var energy: int=GameState.stamina
	game.interact()
	check(not game.farm.plots["20,18"].watered and GameState.stamina==energy,"动作尚未结束时再次按交互不重启工具或扣体力")
	await frames(12)
	game.interact()
	await frames(7)
	check(game.farm.plots["20,18"].watered,"动作结束后再次交互正常恢复，不残留锁定")
	game.hud.inventory_panel.open_panel(false)
	energy=GameState.stamina
	game.farm.plots["20,18"].watered=false
	game.interact()
	Touch.tap(self,game,Vector2(656,592));await frames(4)
	check(not game.farm.plots["20,18"].watered and GameState.stamina==energy and game.auto_move.target.is_empty(),"背包开启时直接操作与地图触点均不执行工具")
	game.hud.close_active_panel()

func pointer_conflicts() -> void:
	await reset_world()
	var point: Vector2=game.player.get_canvas_transform()*Vector2(784,496)
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.pressed=true
	get_viewport().push_input(mouse,true)
	Touch.finger(self,point,true,82)
	mouse=mouse.duplicate();mouse.pressed=false;get_viewport().push_input(mouse,true)
	check(game.auto_move.target.is_empty(),"鼠标按下期间触屏加入不会在鼠标释放时提交移动")
	Touch.finger(self,point,false,82)
	check(game.auto_move.target.is_empty(),"跨设备混合手势的最后释放也不会提交旧触点")
	Touch.finger(self,point,true,83)
	GameState.select_tool(1)
	Touch.finger(self,point,false,83)
	check(game.auto_move.target.is_empty(),"按住地面期间切换工具，释放不提交旧意图")

func dynamic_paths() -> void:
	await reset_world()
	var before: int=game.auto_move.execution_count
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false},"21,18":{"crop":"carrot","days":0,"watered":false}}
	GameState.manual_tool=false
	Touch.tap(self,game,Vector2(656,592));await Touch.finish(self,game)
	Touch.tap(self,game,Vector2(688,592));await Touch.finish(self,game)
	check(game.farm.plots["20,18"].watered and game.farm.plots["21,18"].watered and game.auto_move.execution_count==before+2,"连续点击两块农田等待动作结束，各执行一次且不偏格")
	await frames(20)
	check(game.player.action_time==0 and absf(game.player.sprite.position.x)<.01,"连续工具动作结束后脚底图像与锁定均复位")
	await reset_world()
	game.auto_move.request(Vector2(784,496));await frames(8)
	var block:=StaticBody2D.new();block.position=Vector2(720,496)
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(24,80);shape.shape=rectangle;block.add_child(shape);game.world.add_child(block)
	Events.navigation_changed.emit();await Touch.finish(self,game,500)
	check(game.player.position.distance_to(Vector2(784,496))<1.1,"行走期间加入动态静态障碍后重规划并抵达")
	block.queue_free();Events.navigation_changed.emit();await frames(4)
	var count: int=game.auto_move.navigation.rebuild_count
	game.auto_move.request(Vector2(816,496));await Touch.finish(self,game)
	game.auto_move.request(Vector2(848,496));await Touch.finish(self,game)
	check(game.auto_move.navigation.rebuild_count<=count+1,"连续无地图变更点击复用静态网格")

func lifecycle() -> void:
	await reset_world()
	game.auto_move.request(Vector2(880,496));await frames(6)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	var at: Vector2=game.player.position
	Input.action_press("move_right");await frames(8);Input.action_release("move_right")
	check(game.player.position==at and game.auto_move.target.is_empty(),"后台暂停期间新输入也不能移动或留下待交互")
	game.notification(NOTIFICATION_APPLICATION_RESUMED);await frames(3)
	check(game.player.auto_direction==Vector2.ZERO and not game.backgrounded,"恢复前台保持静止，需新触点才继续")
	game.auto_move.request(Vector2(656,592));await frames(3)
	GameClock.minutes=1439.9;GameClock.running=true;GameClock._process(.1);GameClock.running=false
	var day: int=GameClock.day;var stamina: int=GameState.stamina
	GameClock._process(0);GameClock._process(0)
	check(GameClock.minutes==360 and GameClock.day==day and GameState.stamina==stamina and game.auto_move.target.is_empty(),"午夜只结算一次并取消当前农田交互")
	load("res://tests/star_runner.gd").fixture(game,true)
	var abyss:=AbyssState.defaults();abyss.unlocked=true;AbyssState.restore(abyss)
	game.change_location("abyss");await frames(4)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	var proof:=AbyssState.snapshot()
	# 模拟后台迟到的一帧；不应产生探索记录、危险或氧气变化。
	AbyssState._process(1.0)
	check(AbyssState.snapshot()==proof,"后台深渊迟到帧不结算探索、预警或危险")
	game.notification(NOTIFICATION_APPLICATION_RESUMED)

func migration() -> void:
	await reset_world()
	game.tutorial.restore({"seen":["tap_move","farm_basics"]})
	var latest:=FarmSaveStore.snapshot(game)
	var old:=latest.duplicate(true);old.version=21;old.erase("tutorial");old.housing=load("res://tests/home05_runner.gd").legacy_housing(old.housing)
	var serialized: Dictionary=JSON.parse_string(JSON.stringify(old))
	var clean:=FarmSaveSchema.normalize(serialized)
	check(not clean.is_empty() and clean.version==FarmSaveStore.VERSION and clean.tutorial==GameTutorial.defaults(true),"实际v21档只增加教学已读，不给老玩家重新弹引导")
	var kept:=not clean.is_empty()
	for id in serialized:
		if id=="housing":
			for field in serialized.housing:
				if AbyssSaveSchema.canonical(clean.get("housing",{}).get(field))!=AbyssSaveSchema.canonical(serialized.housing[field]): kept=false
			continue
		if id!="version" and AbyssSaveSchema.canonical(clean.get(id))!=AbyssSaveSchema.canonical(serialized[id]):
			kept=false
			print("MIGRATION DIFFERENCE ",id," old ",serialized[id]," new ",clean.get(id))
	check(kept,"v21迁移逐字段保留农场、钱物、矿洞、婚姻和恢复次数")
	check(FarmSaveSchema.normalize(clean)==clean and not old.has("tutorial"),"v21迁移幂等且不改输入旧档")
	check(FarmSaveStore.restore(game,latest) and game.tutorial.snapshot()==latest.tutorial,"新教学已读状态存读档保持")
	var bad:=latest.duplicate(true);bad.tutorial={"seen":["tap_move","tap_move"]}
	check(not FarmSaveStore.valid(bad),"拒绝重复教学事件ID的损坏存档")
	bad=latest.duplicate(true);bad.version=FarmSaveStore.VERSION+1
	check(not FarmSaveStore.restore(game,bad),"未来存档版本被拒绝，当前运行数据保持")

func sale_safety() -> void:
	await reset_world()
	var panel: PanelContainer=game.hud.inventory_panel
	Inventory.items.carrot=5
	var coins: int=Inventory.coins
	panel.open_panel(true);panel.request_sale("carrot")
	var first: int=int(panel.pending_sale.token)
	check(Inventory.count("carrot")==5 and Inventory.coins==coins,"出售全部先展示数量金额，不立即转移物品")
	panel.close_panel();panel.confirm_sale(first)
	check(Inventory.count("carrot")==5 and Inventory.coins==coins,"关闭交易确认后迟到回调不出售物品")
	panel.open_panel(true);panel.request_sale("carrot")
	var second: int=int(panel.pending_sale.token)
	panel.confirm_sale(first)
	check(Inventory.count("carrot")==5,"上次确认不能确认新的一笔出售")
	panel.confirm_sale(second);panel.confirm_sale(second)
	check(Inventory.count("carrot")==0 and Inventory.coins==coins+5*Catalog.sell_price("carrot"),"最终确认出售只结算一次金币和物品")
	Inventory.items.carrot=2;panel.request_sale("carrot")
	var third: int=int(panel.pending_sale.token)
	Inventory.items.erase("carrot");var before: int=Inventory.coins
	panel.confirm_sale(third)
	check(Inventory.coins==before,"确认时库存不足仍由原经济事务拒绝，无凭空金币")
	panel.close_panel()
