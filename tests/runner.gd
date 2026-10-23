extends Node
## 用真实主场景、物理帧与输入事件做集成验证；失败时返回非零退出码。
var failed: int = 0
var checked: int = 0
var game: Node

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failed += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int = 3) -> void:
	for _i in range(count):
		await get_tree().physics_frame

func run() -> void:
	get_window().size = Vector2i(1280,720)
	game = load("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled = false
	add_child(game)
	GameClock.running = false
	River.state.legacy_rules=true
	River.state.legacy_scene=true
	River.state.old_checkpoints=[5,15]
	await frames()
	GameWeather.enabled = false
	await phase_one()
	load("res://tests/phase_two.gd").run(self, game)
	await load("res://tests/phase_three.gd").run(self, game)
	await load("res://tests/phase_four.gd").run(self, game)
	await load("res://tests/expansion.gd").run(self, game)
	await load("res://tests/story.gd").run(self,game)
	await load("res://tests/story_v4.gd").run(self,game)
	await load("res://tests/xiaojing.gd").run(self,game)
	await load("res://tests/touch_navigation.gd").run(self,game)
	print("RESULT: %d checks, %d failures" % [checked, failed])
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(0.3).timeout
	game.queue_free()
	await frames()
	get_tree().quit(1 if failed else 0)

func phase_one() -> void:
	GameState.set_control_mode("joystick",false)
	check(game.world.get_node("Ground") is TileMapLayer, "地图使用 Godot 4.3 TileMapLayer")
	check(game.world.get_node("Ground").get_used_cells().size() == 48 * 32, "完整农场地图加载")
	var start: Vector2 = game.player.position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check(game.player.position.x > start.x + 15, "WASD 输入产生物理移动")
	# 玩家从小屋下方向上移动，不能穿入建筑。
	game.player.position = Vector2(630, 418)
	Input.action_press("move_up")
	await frames(40)
	Input.action_release("move_up")
	check(game.player.position.y > 396, "房屋实体碰撞阻挡玩家")
	# 池塘边缘也由真实 TileSet 碰撞阻挡。
	game.player.position = Vector2(937, 592)
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	check(game.player.position.x < 985, "池塘 TileSet 碰撞阻挡玩家")
	var cell := Vector2i(18,17)
	check(not game.farm.use_tool(Vector2i(2,2),"hoe"), "不可在农田外翻土")
	check(not game.farm.use_tool(cell,"carrot_seed"), "未翻土不能播种")
	check(game.farm.use_tool(cell,"hoe"), "翻土")
	var seeds: int = Inventory.count("carrot_seed")
	check(game.farm.use_tool(cell,"carrot_seed"), "播种")
	check(Inventory.count("carrot_seed") == seeds - 1, "种子正确扣除")
	check(not game.farm.use_tool(cell,"carrot_seed"), "不能覆盖已种作物")
	advance_day()
	check(int(game.farm.plots["18,17"]["days"]) == 0, "未浇水的作物不成长")
	check(game.farm.use_tool(cell,"water"), "浇水")
	check(not game.farm.use_tool(cell,"water"), "同一天重复浇水被拒绝")
	advance_day()
	check(int(game.farm.plots["18,17"]["days"]) == 1 and not game.farm.plots["18,17"]["watered"], "换日成长并清除浇水状态")
	check(not game.farm.use_tool(cell,"hand"), "未成熟不可收获")
	game.farm.use_tool(cell,"water")
	advance_day()
	check(game.farm.use_tool(cell,"hand"), "第二个生长日收获胡萝卜")
	check(Inventory.count("carrot") == 1, "收获进入背包")
	check(not game.farm.use_tool(cell,"hand"), "不能重复收获")
	GameState.stamina = 0
	check(not game.farm.use_tool(Vector2i(19,17),"hoe"), "体力不足阻止操作")
	GameState.rest()
	game.player.position = Vector2(430,490)
	game.action_cooldown = 0
	game.interact()
	check(GameState.modal and game.hud.dialogue.visible, "靠近 NPC 交互开启对话")
	start = game.player.position
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("move_right")
	check(game.player.position.distance_to(start) < 0.1, "对话暂停移动")
	game.hud.dialogue.advance()
	check(game.hud.dialogue.index == 1, "多句对话翻页")
	game.hud.dialogue.close_dialogue()
	check(not GameState.modal, "对话关闭后解除暂停")
	# 触点 4 持续移动，触点 7 同时按动作键，互不覆盖。
	game.player.position = Vector2(646,560)
	var plot_count: int = game.farm.plots.size()
	var joystick: Control = game.hud.joystick
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	touch.position = joystick.get_global_rect().get_center() + Vector2(45,0)
	get_viewport().push_input(touch, true)
	await frames(3)
	check(game.player.touch_direction.x > 0.5, "虚拟摇杆产生移动向量")
	var second := InputEventScreenTouch.new()
	second.index = 7
	second.pressed = true
	second.position = game.hud.action_button.get_global_rect().get_center()
	get_viewport().push_input(second, true)
	second = second.duplicate()
	second.pressed = false
	game.action_cooldown = 0
	get_viewport().push_input(second, true)
	check(game.farm.plots.size() == plot_count+1 and joystick.finger == 4, "第二触点完成翻土且不抢占摇杆")
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch, true)
	check(game.player.touch_direction == Vector2.ZERO, "松开摇杆立即停止")

func advance_day() -> void:
	GameClock.minutes=1200
	GameClock.next_day()
