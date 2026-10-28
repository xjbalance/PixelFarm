extends RefCounted
## 用完整章节、真实桥面碰撞、触屏选择和存档边界验证村庄共建流程。
static func run(test: Node,game: Node) -> void:
	Story.restore({})
	Letters.restore({})
	VillageProjects.restore({})
	FarmProgress.restore({})
	GameState.rest()
	GameClock.day = 3
	GameClock.minutes = 600
	game.world.resource_field.restore({})
	game.change_location("farm")
	Inventory.items = {"carrot_seed":12,"wheat_seed":6,"potato_seed":6}
	Inventory.coins = 120
	await story_flow(test,game)
	await village_benefits(test,game)
	await weather_and_tools(test,game)
	await save_and_ui(test,game)

static func finish(dialogue: Node,choice: String = "") -> void:
	for i in range(60):
		if not dialogue.visible: return
		if dialogue.choices_box.visible:
			dialogue.choose(choice)
		else: dialogue.advance()

static func touch(test: Node,control: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 11
	event.pressed = true
	event.position = control.get_global_rect().get_center()
	test.get_viewport().push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	test.get_viewport().push_input(event,true)

static func find_button(root: Node, caption: String) -> Button:
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree() and child.text==caption: return child
		var found:=find_button(child,caption)
		if found: return found
	return null

static func labeled_button(root: Node, label_text: String, caption: String, scope: Node=null) -> Button:
	if scope==null: scope=root
	for child in root.get_children():
		if child is Label and child.text.trim_prefix("✓ ").trim_prefix("○ ").begins_with(label_text):
			var ancestor: Node=child.get_parent()
			while ancestor and (ancestor==scope or scope.is_ancestor_of(ancestor)):
				var found:=find_button(ancestor,caption)
				if found: return found
				ancestor=ancestor.get_parent()
		var nested:=labeled_button(child,label_text,caption,scope)
		if nested: return nested
	return null

static func touch_button(test: Node, root: Node, caption: String, section: String="") -> void:
	# 纸卡、标题与图标可以改变节点层级；仍找到真实公开按钮并发原生触摸。
	var control: Button=find_button(root,caption) if section=="" else labeled_button(root,section,caption)
	if not is_instance_valid(control):
		push_error("UI测试未找到公开按钮："+caption+" / "+section)
		return
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await test.frames(3)
	touch(test,control)
	await test.frames(3)

static func story_flow(test: Node,game: Node) -> void:
	var panel: Node = game.hud.dialogue
	Story.request("mail")
	test.check(panel.visible and GameState.modal and panel.body_label.visible_characters == 0,"来信使用头像逐字对话并暂停玩法")
	panel.advance()
	test.check(panel.index == 0 and panel.body_label.visible_characters == -1,"第一次继续只显示当前句全文")
	panel.close_dialogue()
	test.check(Story.stage == 0 and Story.seen.is_empty(),"中途收起剧情不会提前推进主线")
	Story.request("mail")
	for _i in range(20):
		if panel.choices_box.visible: break
		panel.advance()
	await test.frames()
	touch(test,panel.choices_box.get_child(0))
	test.check(panel.selected_choice == "renew" and Story.stage == 0,"真实触屏选择记录回答，读完前不提交")
	finish(panel,"renew")
	test.check(Story.stage == 1 and Story.motive == "renew","读完回信选择后保存建设村庄的动机")
	test.check(not Story.complete("letter","home") and not Story.complete("bridge"),"重复序章和越级修桥均被拒绝")
	Story.request("linya")
	finish(panel)
	test.check(Story.stage == 2,"林芽对话开启农场供菜目标")
	Story.request("linya")
	test.check(panel.scene_id == "linya_daily","作物不足时提供日常提示，不提前交付")
	panel.close_dialogue()
	# 新序幕要求真实种植教学；不以直接发物品代替完成条件。
	game.farm.plots.erase("17,16")
	game.farm.use_tool(Vector2i(17,16),"hoe")
	game.farm.use_tool(Vector2i(17,16),"carrot_seed")
	game.farm.use_tool(Vector2i(17,16),"water")
	test.advance_day()
	game.farm.use_tool(Vector2i(17,16),"water")
	test.advance_day()
	game.farm.use_tool(Vector2i(17,16),"hand")
	Inventory.items.carrot = 3
	Story.request("linya")
	panel.close_dialogue()
	test.check(Inventory.count("carrot") == 3 and Inventory.coins == 120,"取消交付对话不扣物品、不发奖励")
	Story.request("linya")
	finish(panel)
	test.check(Story.stage == 3 and Inventory.count("carrot") == 0 and Inventory.coins == 170,"首笔供菜整笔结算三份作物与50金币")
	test.check(not Story.complete("harvest") and Inventory.coins == 170,"供菜奖励不可重复领取")
	game.player.position = Vector2(480,252)
	game.action_cooldown = 0
	game.interact()
	test.check(GameState.location == "village" and game.player.get_parent() == game.village.get_node("Actors"),"实际北侧路牌交互进入河湾村")
	test.check(game.village.ground is TileMapLayer and game.village.ground.get_used_cells().size() == 1120,"河湾村完整原生TileMapLayer加载")
	game.player.position = Vector2(806,480)
	await test.frames()
	Input.action_press("move_right")
	await test.frames(30)
	Input.action_release("move_right")
	test.check(game.player.position.x < 825,"断桥河面真实物理碰撞阻止提前过河")
	Story.request("bridge_survey")
	finish(panel)
	Story.request("repair_record")
	finish(panel)
	game.player.position = Vector2(488,524)
	game.action_cooldown = 0
	game.interact()
	finish(panel)
	test.check(Story.stage == 4,"靠近周砚完成修桥前的角色故事")
	Inventory.items.wood = 7
	Inventory.items.stone = 6
	test.check(not Story.complete("bridge") and Inventory.count("wood") == 7,"修桥材料不足不会部分扣除")
	Story.request("ahe")
	finish(panel)
	Inventory.items.wood = 8
	Story.request("bridge")
	finish(panel)
	await test.frames()
	test.check(Story.stage == 5 and game.village.bridge_open and Inventory.count("wood") == 0 and Inventory.count("stone") == 0,"修桥扣除材料，场景状态与章节同步")
	game.player.position = Vector2(806,480)
	Input.action_press("move_right")
	await test.frames(65)
	Input.action_release("move_right")
	test.check(game.player.position.x > 940,"修桥后真实移动可以穿过整个河面")
	Letters.record("east_bank")
	Story.request("mill")
	finish(panel)
	test.check(Story.stage == 6,"风车建设簿解锁三项村庄公共设施")
	Inventory.items.wheat = 2
	Inventory.items.carrot = 1
	Story.request("ahe")
	test.check(panel.scene_id == "ahe_daily" and not Story.complete("supper"),"公共设施未完成时，食材充足也不会跳过共建")
	panel.close_dialogue()
	Inventory.items.wood = 30
	Inventory.items.stone = 30
	Inventory.coins = 500
	test.check(not VillageProjects.build("well") and Inventory.coins == 500,"不能远程调用共建交付")
	game.player.position = Vector2(680,688)
	game.action_cooldown = 0
	game.interact()
	await test.frames()
	test.check(game.hud.story_panel.visible and game.hud.story_panel.at_board,"村中共建板打开可交付的建设手记")
	Inventory.items.stone = 1
	test.check(not VillageProjects.build("well") and Inventory.coins == 500 and Inventory.count("wood") == 30,"共建不足时材料金币全部保持不变")
	Inventory.items.stone = 30
	Inventory.changed.emit()
	await test.frames()
	await touch_button(test,game.hud.story_panel,"一起建造",str(VillageProjects.definitions.well.name))
	test.check(VillageProjects.has_project("well") and Inventory.coins == 460,"触屏按钮成功建设水井并准确收费")
	test.check(game.hud.story_panel.content.get_parent().finger == -1,"建设按钮刷新后正确释放长列表的触点")
	test.check(not VillageProjects.build("well") and Inventory.coins == 460,"已完成的村庄工程不能重复收费")
	test.check(VillageProjects.build("cooperative") and VillageProjects.build("arbor"),"共仓和茶座均可实际建设")
	test.check(Inventory.count("wood") == 12 and Inventory.count("stone") == 18 and Inventory.coins == 360,"三项工程按定义准确结算全部材料")
	game.hud.story_panel.close_panel()
	Story.request("ahe")
	finish(panel)
	test.check(Story.stage == 7 and Inventory.count("wheat") == 2 and Inventory.count("carrot") == 1,"全部工程建成后，生活对话推进主线，不再重复交付食材")
	test.check(not Story.complete("festival","memory"),"庆典不能在白天通过回调提前完成")
	Story.request("bench")
	finish(panel,"wait")
	test.check(GameClock.minutes == 1080,"长椅可等待到18点，不需要空等现实时间")
	test.check(game.village.villagers.linya.visible and game.village.villagers.ahe.station.distance_to(Vector2(713,510)) < 1 and not game.world.get_node("Actors/Linya").visible,"风灯之夜三位村民实际来到广场，农场不保留另一位林芽")
	Story.request("lantern")
	finish(panel,"trade")
	test.check(Story.stage == 8 and Story.lantern == "trade" and Inventory.coins == 480,"庆典结尾选择完成首章，村庄留下新的种子灯")
	test.check(not Story.complete("festival","memory") and Inventory.coins == 480,"结局不能重复领奖或覆写已做的选择")
	var after: Dictionary = Story.scene_data("zhou_daily")
	test.check("种子" in after.lines[1].text,"结局选择改变村民后续对白")
	for id in Story.SECRET_IDS:
		Story.request(id)
		finish(panel)
	test.check(Story.seen.has("well") and Story.seen.has("ribbon") and Story.seen.has("post"),"探索三段村庄往事并记录到手记")

static func village_benefits(test: Node,game: Node) -> void:
	var base: int = Catalog.crops.carrot.seed_price
	var price := FarmEconomy.seed_price("carrot")
	var coins: int = Inventory.coins
	test.check(price == ceili(base*.8) and FarmEconomy.buy("carrot",2) and Inventory.coins == coins-price*2,"种子共仓的八折福利作用于真实交易")
	game.farm.plots = {"20,18":{"crop":"carrot","days":0,"watered":false},"22,20":{"crop":"","days":0,"watered":false}}
	Story.request("well")
	finish(game.hud.dialogue,"draw")
	test.check(game.farm.plots["20,18"].watered and game.farm.plots["22,20"].watered,"修好的水井通过剧情交互浇透真实农田")
	game.farm.plots["20,18"].watered = false
	test.check(not VillageProjects.water_fields() and not game.farm.plots["20,18"].watered,"引水每日额度不能重复使用")
	GameState.stamina = 20
	Story.request("bench")
	finish(game.hud.dialogue,"tea")
	test.check(GameState.stamina == 60 and VillageProjects.tea_day == GameClock.day,"茶座剧情选择实际恢复40点体力")
	test.check(not VillageProjects.drink_tea() and GameState.stamina == 60,"热茶每日不能重复领取")
	test.advance_day()
	GameState.stamina = 50
	test.check(VillageProjects.drink_tea() and VillageProjects.water_fields(),"新一天恢复村庄设施每日额度")

static func weather_and_tools(test: Node,game: Node) -> void:
	GameWeather.enabled = true
	GameClock.day = 3
	game.farm.plots = {"20,18":{"crop":"carrot","days":0,"watered":false}}
	test.advance_day()
	test.check(GameWeather.is_rainy() and game.farm.plots["20,18"].days == 0 and game.farm.plots["20,18"].watered,"雨天在昨夜成长之后补水，不凭空多长一天")
	test.check(game.farm.use_tool(Vector2i(23,20),"hoe") and game.farm.plots["23,20"].watered,"雨天新翻土地即时接到雨水")
	test.advance_day()
	test.check(not GameWeather.is_rainy() and game.farm.plots["20,18"].days == 1 and not game.farm.plots["20,18"].watered,"雨后的成长正确结算，晴天恢复人工浇水")
	game.change_location("farm",Vector2(656,560))
	game.player.facing = Vector2.DOWN
	var key: String = game.farm.key(game.player.target_cell())
	game.farm.plots[key] = {"crop":"carrot","days":0,"watered":false}
	GameState.select_tool(3)
	Story.assisted_tools = true
	test.check(game.context_tool() == "water","操作辅助识别已种未浇水的作物")
	game.action_cooldown = 0
	game.interact()
	await test.frames(7)
	test.check(game.farm.plots[key].watered,"实际交互按键按情境执行浇水")
	game.farm.plots[key].days = 2
	test.check(game.context_tool() == "hand","操作辅助识别成熟作物")
	var carrots: int = Inventory.count("carrot")
	await test.frames(16) # 浇水动作结束后才能发起收获，断言与经济规则不变。
	game.action_cooldown = 0
	game.interact()
	await test.frames(7)
	test.check(Inventory.count("carrot") == carrots+1,"实际情境操作成功收获入包")
	Story.assisted_tools = false
	test.check(game.context_tool() == "carrot_seed","可关闭辅助，保留精确工具选择")
	Story.assisted_tools = true

static func save_and_ui(test: Node,game: Node) -> void:
	GameClock.day = 12
	game.world.resource_field.restore({})
	game.change_location("village",Vector2(1010,480))
	var saved := FarmSaveStore.snapshot(game)
	test.check(FarmSaveStore.valid(saved),"完整建设、选择、发现、福利额度和村庄位置可保存")
	Story.restore({})
	VillageProjects.restore({})
	test.check(not game.village.bridge_open,"重置故事时桥面同步关闭")
	test.check(FarmSaveStore.restore(game,saved),"新版剧情与村庄设施整份恢复")
	await test.frames()
	test.check(Story.stage == 8 and Story.lantern == "trade" and VillageProjects.all_built() and game.village.bridge_open and GameState.location == "village","读档恢复结局装饰、工程福利和实际桥面")
	for changes in [{"stage":9},{"seen":["letter"]},{"lantern":"unknown"},{"assisted_tools":1}]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.story.merge(changes,true)
		test.check(not FarmSaveStore.restore(game,invalid) and Story.stage == 8,"非法剧情存档整份拒绝，不破坏当前进度")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.village.built = ["well","well"]
	test.check(not FarmSaveStore.valid(invalid),"拒绝重复设施和跳过村庄共建的结局存档")
	invalid = saved.duplicate(true)
	invalid.village.tea_day = GameClock.day+1
	test.check(not FarmSaveStore.valid(invalid),"拒绝未来日期的每日茶座额度")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 2;legacy.erase("farm_layout");legacy.erase("appearance")
	legacy.location = "farm"
	legacy.player = [700,500]
	legacy.erase("story")
	legacy.erase("village")
	test.check(FarmSaveSchema.normalize(legacy).story.stage == 0 and FarmSaveSchema.normalize(legacy).coins == saved.coins,"0.2存档迁移保留经营数据，新剧情从来信开始")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		test.get_window().size = resolution
		await test.frames(3)
		game.hud.story_panel.open_panel()
		for page in range(4):
			game.hud.story_panel.select_page(page)
			await test.frames(3)
			test.check(game.hud.safe.get_global_rect().encloses(game.hud.story_panel.get_global_rect()),"共建/地图/人物/记忆页面适配 "+str(resolution)+" 页"+str(page))
		game.hud.story_panel.close_panel()
		game.hud.dialogue.open_story("festival")
		for _i in range(20):
			if game.hud.dialogue.choices_box.visible: break
			game.hud.dialogue.advance()
		await test.frames(3)
		test.check(game.hud.safe.get_global_rect().encloses(game.hud.dialogue.get_global_rect()),"头像与双选项对话完整显示 "+str(resolution))
		game.hud.dialogue.close_dialogue()
	test.get_window().size = Vector2i(1280,720)
	game.hud.story_panel.open_panel()
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	test.check(not GameState.modal and not game.hud.story_panel.visible,"Android返回键可关闭共建手记")
	# 测试手记中的原生多页长列表能通过实际屏幕拖动阅读。
	game.hud.story_panel.open_panel()
	game.hud.story_panel.select_page(2)
	await test.frames()
	var scroll := game.hud.story_panel.content.get_parent() as ScrollContainer
	var touch_event := InputEventScreenTouch.new()
	touch_event.index = 12
	touch_event.pressed = true
	touch_event.position = scroll.get_global_rect().position+Vector2(300,260)
	test.get_viewport().push_input(touch_event,true)
	for _i in range(8):
		var drag := InputEventScreenDrag.new()
		drag.index = 12
		drag.relative = Vector2(0,-18)
		touch_event.position += drag.relative
		drag.position = touch_event.position
		test.get_viewport().push_input(drag,true)
		await test.frames(1)
	touch_event.pressed = false
	test.get_viewport().push_input(touch_event,true)
	test.check(scroll.scroll_vertical > 0,"人物手记长列表可以用真实触屏拖动阅读")
	game.hud.story_panel.close_panel()
	# 无界面默认不播放常驻音乐；在此明确启动，验证真实播放对象的静音行为。
	game.get_node("Audio").music.play()
	game.get_node("Audio").rain.play()
	game.get_node("Audio").muted = true
	await test.frames()
	test.check(game.get_node("Audio").music.stream_paused and game.get_node("Audio").rain.stream_paused,"静音设置同时暂停配乐和雨声")
	GameWeather.enabled = false
