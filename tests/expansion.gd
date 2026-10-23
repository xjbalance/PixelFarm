extends RefCounted
## 扩展玩法走真实场景和交易入口，重点验证不可重复领取、失败无副作用和旧档迁移。
static func run(test: Node, game: Node) -> void:
	await gathering(test,game)
	await upgrades_and_quests(test,game)
	await save_compatibility(test,game)
	await interface(test,game)

static func gathering(test: Node, game: Node) -> void:
	game.change_location("farm")
	FarmProgress.restore({})
	game.world.resource_field.restore({})
	var field: Node2D = game.world.resource_field
	Inventory.items["wood"] = 1
	Inventory.items["stone"] = 1
	GameState.rest()
	var energy: int = GameState.stamina
	test.check(not field.hit("tree_7_20","pickaxe") and GameState.stamina == energy and field.state.tree_7_20.hp == 3,"错误采集工具不消耗体力或耐久")
	test.check(field.find_target(Vector2(224,680),Vector2.DOWN) == null,"采集目标必须在玩家面前")
	test.check(field.find_target(Vector2(224,710),Vector2.UP) == null,"不能远距离采集")
	game.player.position = Vector2(224,680)
	game.player.facing = Vector2.UP
	GameState.select_tool(6)
	await test.frames()
	for _hit in range(3):
		game.action_cooldown = 0
		Events.action_requested.emit()
	await test.frames()
	test.check(field.state.tree_7_20.hp == 0 and Inventory.count("wood") == 5,"交互键连续砍树三次，获得四份木材")
	test.check(GameState.stamina == energy-9,"砍树准确扣除每次体力")
	test.check(field.objects.tree_7_20.collider.disabled,"树木采完解除碰撞")
	test.check(not field.hit("tree_7_20","axe") and Inventory.count("wood") == 5,"枯竭的树不会重复掉落")
	Input.action_press("move_up")
	await test.frames(32)
	Input.action_release("move_up")
	test.check(game.player.position.y < 625,"角色能够走过采完的树桩")
	test.advance_day()
	test.advance_day()
	test.check(field.state.tree_7_20.hp == 0,"树木未到再生日期不恢复")
	game.player.position = Vector2(224,640)
	await test.frames()
	test.advance_day()
	test.check(field.state.tree_7_20.hp == 0,"再生时不在玩家身上生成碰撞体")
	game.player.position = Vector2(224,700)
	await test.frames()
	test.advance_day()
	await test.frames()
	test.check(field.state.tree_7_20.hp == 3 and not field.objects.tree_7_20.collider.disabled,"位置安全后换日恢复树木和碰撞")
	test.check(field.hit("rock_11_19","pickaxe") and field.state.rock_11_19.hp == 1,"采石保留剩余耐久")
	var snapshot: Dictionary = field.state.duplicate(true)
	field.restore({})
	field.restore(snapshot)
	test.check(field.state.rock_11_19.hp == 1,"采集进度可恢复")
	test.check(field.hit("rock_11_19","pickaxe") and Inventory.count("stone") == 4,"两次采石获得三份石料")
	test.advance_day()
	test.check(field.state.rock_11_19.hp == 0,"石堆在首日仍枯竭")
	test.advance_day()
	test.check(field.state.rock_11_19.hp == 2,"石堆第二天再生")
	Inventory.items["wood"] = Inventory.MAX_STACK
	field.hit("tree_7_20","axe")
	field.hit("tree_7_20","axe")
	energy = GameState.stamina
	test.check(not field.hit("tree_7_20","axe") and field.state.tree_7_20.hp == 1 and GameState.stamina == energy,"背包容纳不下整份掉落时不破坏资源或扣体力")
	Inventory.items["wood"] = 5
	GameState.stamina = 0
	test.check(not field.hit("tree_7_20","axe") and field.state.tree_7_20.hp == 1,"体力耗尽不能采集")
	GameState.rest()
	var coins: int = Inventory.coins
	test.check(FarmEconomy.sell("wood",2) and Inventory.count("wood") == 3 and Inventory.coins == coins+8,"木材可在经济系统按单价出售")

static func upgrades_and_quests(test: Node, game: Node) -> void:
	FarmProgress.restore({})
	Inventory.items = {"carrot_seed":12,"potato_seed":6,"wheat_seed":6}
	Inventory.coins = 100
	test.check(not FarmProgress.build_upgrade("toolrack") and Inventory.coins == 100 and FarmProgress.built.is_empty(),"修缮材料不足不扣金币且不改变设施")
	Inventory.items["wood"] = 50
	Inventory.items["stone"] = 40
	Inventory.coins = 1000
	test.check(FarmProgress.build_upgrade("toolrack"),"修建精制工具架")
	test.check(Inventory.coins == 880 and Inventory.count("wood") == 42 and Inventory.count("stone") == 31,"设施一次性准确扣除多种材料与金币")
	test.check(not FarmProgress.build_upgrade("toolrack") and Inventory.coins == 880,"已建设施不能重复扣费")
	game.world.resource_field.restore({})
	var stones: int = Inventory.count("stone")
	test.check(game.world.resource_field.hit("rock_11_19","pickaxe") and Inventory.count("stone") == stones+3,"工具架使镐一次采完石堆")
	GameState.stamina = 60
	test.check(FarmProgress.build_upgrade("bedding") and GameState.max_stamina() == 130 and GameState.stamina == 60,"修缮卧室提高上限，不凭空恢复当前体力")
	GameState.rest()
	test.check(GameState.stamina == 130 and game.hud.stamina_bar.max_value == 130,"休息与 HUD 使用新的体力上限")
	game.farm.plots = {"17,16":{"crop":"carrot","days":0,"watered":false},"21,16":{"crop":"carrot","days":0,"watered":false}}
	test.check(FarmProgress.build_upgrade("irrigation"),"修建田边引水渠")
	test.check(game.farm.plots["17,16"].watered and not game.farm.plots["21,16"].watered,"引水渠只覆盖西北 4×3 格")
	test.advance_day()
	test.check(game.farm.plots["17,16"].days == 1 and game.farm.plots["17,16"].watered and game.farm.plots["21,16"].days == 0,"成长结算后引水渠自动补水，未覆盖作物仍须浇水")
	test.check(game.farm.use_tool(Vector2i(18,16),"hoe") and game.farm.plots["18,16"].watered,"覆盖区新开垦农田立即供水")
	FarmProgress.friendship = 0
	FarmProgress.last_talk_day = 0
	FarmProgress.quest_states.clear()
	test.check(not FarmProgress.accept("river_path"),"后续委托不能跳过前置直接接取")
	test.check(FarmProgress.accept("first_gift") and not FarmProgress.accept("first_gift"),"第一份委托可接取且不能重复接取")
	var coins: int = Inventory.coins
	test.check(not FarmProgress.deliver("first_gift") and Inventory.coins == coins,"缺少交付物品时不发奖励")
	Inventory.items["carrot"] = 3
	Inventory.items["potato_seed"] = 999
	test.check(not FarmProgress.deliver("first_gift") and Inventory.count("carrot") == 3 and FarmProgress.quest_status("first_gift") == "active","奖励种子装不下时不扣交付物品，不完成任务")
	Inventory.items["potato_seed"] = 996
	test.check(FarmProgress.deliver("first_gift") and Inventory.coins == coins+80 and Inventory.count("carrot") == 0 and Inventory.count("potato_seed") == 999,"委托交付和奖励整笔结算")
	test.check(FarmProgress.friendship == 15 and not FarmProgress.deliver("first_gift") and Inventory.coins == coins+80,"好感奖励生效，不能重复领奖")
	FarmProgress.talk()
	FarmProgress.talk()
	test.check(FarmProgress.friendship == 17,"同一天重复交谈只增加一次好感")
	test.advance_day()
	FarmProgress.talk()
	test.check(FarmProgress.friendship == 19,"新一天可以再次获得交谈好感")
	test.check(FarmProgress.accept("river_path") and FarmProgress.deliver("river_path"),"前置完成后可交付木材和石料委托")
	Inventory.items["potato"] = 3
	Inventory.items["wheat"] = 4
	test.check(FarmProgress.accept("valley_table") and FarmProgress.deliver("valley_table"),"第三份农产品委托可完成")
	test.check(FarmProgress.friendship == 64 and FarmProgress.relationship() == "知心邻居","完整任务链带来持续的关系进展")
	var items: Dictionary = Inventory.items.duplicate()
	coins = Inventory.coins
	test.check(not Inventory.exchange({"wood":1},{"missing":2},1) and items == Inventory.items and coins == Inventory.coins,"非法交易奖励不导致部分扣费")
	Inventory.coins = Inventory.MAX_COINS
	test.check(not FarmEconomy.sell("wood",1) and Inventory.items == items,"金币到达上限时拒绝整笔出售")
	Inventory.coins = coins

static func save_compatibility(test: Node, game: Node) -> void:
	game.player.position = Vector2(700,500)
	var data := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.valid(data) and data.version == FarmSaveStore.VERSION,"包含材料、设施、好感与采集状态的新存档有效")
	var original: Dictionary = data.duplicate(true)
	FarmProgress.restore({})
	game.world.resource_field.restore({})
	Inventory.items.clear()
	test.check(FarmSaveStore.restore(game,data),"新版本完整状态可恢复")
	await test.frames()
	test.check(FarmProgress.built.size() == 3 and FarmProgress.quest_status("valley_table") == "completed" and FarmProgress.friendship == 64,"恢复设施、完整任务链和好感")
	test.check(game.world.resource_field.state == original.resources and Inventory.items == original.items,"恢复采集物与材料库存")
	for mutation in [
		{"progress":{"built":["unknown"],"quests":{},"friendship":0,"last_talk_day":0}},
		{"progress":{"built":["toolrack","toolrack"],"quests":{},"friendship":0,"last_talk_day":0}},
		{"progress":{"built":[],"quests":{"river_path":2},"friendship":0,"last_talk_day":0}},
		{"progress":{"built":[],"quests":{},"friendship":101,"last_talk_day":0}},
		{"resources":{"tree_7_20":{"hp":-1,"ready_day":0}}},
		{"resources":{"tree_7_20":{"hp":0,"ready_day":0}}},
		{"resources":{"tree_bad":{"hp":1,"ready_day":0}}}
	]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.merge(mutation,true)
		test.check(not FarmSaveStore.restore(game,invalid) and FarmProgress.friendship == 64,"拒绝非法扩展存档且保持当前进度："+str(mutation.keys()))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json"))
	test.check(FarmSaveStore.restore(game,legacy),"0.1.0 的版本 1 存档能够迁移")
	await test.frames()
	test.check(Inventory.coins == 321 and Inventory.count("carrot") == 3 and GameClock.day == 5 and GameState.stamina == 73,"迁移保留原有金币、背包、日期和体力")
	test.check(FarmProgress.built.is_empty() and FarmProgress.quest_states.is_empty() and game.world.resource_field.state.tree_7_20.hp == 3,"旧存档新增系统采用安全初始值")
	test.check(legacy.version == 1 and not legacy.has("progress"),"迁移不会修改传入的旧存档数据")
	test.check(FarmSaveStore.snapshot(game).version == FarmSaveStore.VERSION,"旧存档下一次保存写入新版本")

static func interface(test: Node, game: Node) -> void:
	game.player.position = Vector2(968,468)
	game.action_cooldown = 0
	game.interact()
	test.check(game.hud.progress_panel.visible and game.hud.progress_panel.at_board,"走到委托板交互打开可办理委托的面板")
	var button: Button = game.hud.progress_panel.action_button
	await test.frames()
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.pressed = true
	touch.position = button.get_global_rect().get_center()
	test.get_viewport().push_input(touch,true)
	touch = touch.duplicate()
	touch.pressed = false
	test.get_viewport().push_input(touch,true)
	test.check(FarmProgress.quest_status("first_gift") == "active","触屏按钮真正接取委托")
	game.hud.progress_panel.close_panel()
	game.hud.progress_panel.open_panel("journal",false)
	test.check(game.hud.progress_panel.action_button.disabled,"远程手记只追踪，不能远程提交")
	game.hud.progress_panel.perform_action()
	test.check(FarmProgress.quest_status("first_gift") == "active","只读手记不能通过操作回调领取奖励")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	test.check(not GameState.modal and not game.hud.progress_panel.visible and not game.get_tree().quit_on_go_back,"Android 返回键关闭当前界面，不退出游戏")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	test.check(GameState.modal and game.hud.system_panel.visible,"游戏内按 Android 返回键打开暂停菜单")
	game.hud.system_panel.close_panel()
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		test.get_window().size = resolution
		await test.frames()
		game.hud.progress_panel.open_panel("workshop",true)
		await test.frames()
		var bounds: Rect2 = game.hud.safe.get_global_rect()
		test.check(bounds.encloses(game.hud.progress_panel.get_global_rect()),"新增修缮面板适配横屏 "+str(resolution))
		game.hud.progress_panel.close_panel()
	test.get_window().size = Vector2i(1280,720)
	game.hud.inventory_panel.open_panel(false)
	game.hud.inventory_panel.materials_tab = true
	game.hud.inventory_panel.refresh()
	game.hud.inventory_panel.equip_tool("pickaxe")
	test.check(GameState.tool() == "pickaxe" and not GameState.modal,"背包材料页可以装备采集工具并恢复操作")
