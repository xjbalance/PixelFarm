extends RefCounted

static func run(test: Node, game: Node) -> void:
	GameState.set_control_mode("joystick",false)
	# 用真实 Viewport 布局计算验证横屏比例，不靠截图主观判断是否越界。
	var original: Vector2i = test.get_window().size
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		test.get_window().size = resolution
		await test.frames(4)
		await load("res://tests/touch_navigation.gd").expand_hotbar(test,game)
		var bounds: Rect2 = game.hud.safe.get_global_rect()
		var controls: Array = [game.hud.joystick,game.hud.action_button]
		controls.append_array(game.hud.tool_buttons)
		var inside: bool = true
		for control in controls:
			inside = inside and bounds.encloses(control.get_global_rect())
		test.check(inside, "%s 横屏比例下摇杆、工具栏、交互按钮完整可见" % str(resolution))
		test.check(not game.hud.joystick.get_global_rect().intersects(game.hud.tool_buttons[0].get_global_rect()) and not game.hud.action_button.get_global_rect().intersects(game.hud.tool_buttons[-1].get_global_rect()), "触屏控制区不互相重叠")
		game.hud.inventory_panel.open_panel(true)
		await test.frames()
		test.check(bounds.encloses(game.hud.inventory_panel.get_global_rect()), "商店界面保持在可视区域")
		game.hud.inventory_panel.close_panel()
	test.get_window().size = original
	await test.frames(4)
	game.hud.apply_safe_area(Rect2(64,0,1216,696),Vector2(1280,720))
	await test.frames(3)
	var viewport: Vector2 = test.get_viewport().get_visible_rect().size
	test.check(game.hud.joystick.get_global_rect().position.x >= viewport.x * 64.0 / 1280.0 and game.hud.action_button.get_global_rect().end.y <= viewport.y * 696.0 / 720.0, "模拟刘海和导航区正确缩进触屏控件")
	game.hud.update_safe_area()
	await test.frames(3)
	var joystick: Control = game.hud.joystick
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = joystick.get_global_rect().get_center()+Vector2(35,0)
	test.get_viewport().push_input(touch,true)
	test.check(joystick.finger == 3, "摇杆持有触点")
	game.hud.inventory_panel.open_panel(false)
	test.check(joystick.finger == -1 and game.player.touch_direction == Vector2.ZERO, "打开背包自动释放摇杆，避免卡住移动")
	var selected: int = GameState.selected
	var click := InputEventScreenTouch.new()
	click.pressed = true
	click.index = 8
	click.position = game.hud.tool_buttons[0].get_global_rect().get_center()
	test.get_viewport().push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	test.get_viewport().push_input(click,true)
	test.check(GameState.selected == selected, "模态界面阻止触摸穿透到底层工具栏")
	game.hud.inventory_panel.close_panel()
	game.player.touch_direction = Vector2.RIGHT
	game.player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	test.check(game.player.touch_direction == Vector2.ZERO, "切到后台释放移动输入")
	GameClock.running = true
	Input.action_press("move_left")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	test.check(not GameClock.running and not Input.is_action_pressed("move_left"), "Android 进入后台暂停时钟并清理按键")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	test.check(GameClock.running, "重复生命周期通知不会导致恢复后时间卡住")
	GameClock.running = false
