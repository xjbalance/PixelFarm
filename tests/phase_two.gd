extends RefCounted

static func run(test: Node, game: Node) -> void:
	var coins: int = Inventory.coins
	var seeds: int = Inventory.count("potato_seed")
	test.check(not FarmEconomy.buy("potato",-3), "负购买数量被拒绝")
	test.check(not FarmEconomy.buy("potato",100), "超出购买上限被拒绝")
	test.check(not FarmEconomy.buy("missing",1), "未知商品被拒绝")
	test.check(not FarmEconomy.buy("potato",99), "金币不足交易被拒绝")
	test.check(Inventory.coins == coins and Inventory.count("potato_seed") == seeds, "失败交易不改变金币或物品")
	test.check(FarmEconomy.buy("potato",2), "批量购买土豆种子")
	test.check(Inventory.coins == coins - 36 and Inventory.count("potato_seed") == seeds + 2, "种子购买金额和数量正确")
	test.check(not FarmEconomy.sell("potato",1), "不能出售未持有的作物")
	Inventory.items["wheat_seed"] = 999
	coins = Inventory.coins
	test.check(not FarmEconomy.buy("wheat",1) and Inventory.coins == coins, "背包堆叠已满不扣金币")
	Inventory.items["wheat_seed"] = 6
	for crop_id in ["potato","wheat"]:
		var cell := Vector2i(22 if crop_id == "potato" else 23,18)
		test.check(game.farm.use_tool(cell,"hoe") and game.farm.use_tool(cell,crop_id+"_seed"), crop_id + " 可种植")
		for _day in range(Catalog.crops[crop_id].growth_days):
			game.farm.use_tool(cell,"water")
			test.advance_day()
		test.check(game.farm.use_tool(cell,"hand"), crop_id + " 按各自周期成熟可收获")
		coins = Inventory.coins
		test.check(FarmEconomy.sell(crop_id,1), crop_id + " 可出售")
		test.check(Inventory.count(crop_id) == 0 and Inventory.coins == coins + Catalog.crops[crop_id].sell_price, crop_id + " 出售结算正确")
	game.hud.inventory_panel.open_panel(true)
	test.check(GameState.modal and game.hud.inventory_panel.visible, "商店开启暂停输入和时钟")
	var time: float = GameClock.minutes
	GameClock.running = true
	GameClock._process(10.0)
	test.check(GameClock.minutes == time, "模态交易界面不消耗游戏时间")
	game.hud.inventory_panel.close_panel()
	GameClock.minutes = 1439
	var day: int = GameClock.day
	GameClock._process(1.0)
	test.check(GameClock.day == day + 1 and GameClock.minutes == 360 and GameState.stamina == ceili(GameState.max_stamina()*.6), "午夜自动换日并按新规则恢复60%体力")
	GameClock.running = false
