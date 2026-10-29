extends "res://tests/runner.gd"
## 实际窗口的湖岸绘制、触屏确认、安全区；不是Android真机。
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	game.get_node("Audio").muted=true;GameClock.running=false;await frames(6)
	Inventory.coins=100000;Inventory.items={"wood":999,"stone":999,"iron_bar":100,"crystal":100,"fry_crucian":20,"fish_feed":99}
	var panel: PanelContainer=game.hud.aquaculture_panel
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution
		await Touch.place(self,game,"farm",Vector2(880,560))
		var target := Vector2(944,580)
		check(game.touch_input.world_point(game.player.get_canvas_transform()*target).distance_to(target)<.01,"湖岸屏幕/相机坐标逆变换："+str(resolution))
		Touch.tap(self,game,target);await Touch.finish(self,game,500)
		check(panel.visible and Aquaculture.near_pen("pen_1"),"窗口原生触点实际靠近鱼栏："+str(resolution))
		for page in ["pen","shop","quests","craft"]:
			panel.page=page;panel.refresh();await frames(4)
			check(game.hud.safe.get_global_rect().encloses(panel.get_global_rect()),"鱼栏滚动页面适配安全区："+str(resolution)+" "+page)
		panel.close_panel()
	get_window().size=Vector2i(1280,720)
	await Touch.place(self,game,"farm",Vector2(912,592))
	panel.open_panel("pen_1")
	var before: int=Inventory.coins
	var build := find_button(panel,"建造鱼栏")
	check(build!=null,"真实鱼栏页面提供建造入口")
	if build: load("res://tests/story.gd").touch(self,build)
	await frames(4)
	var payment_locked := false
	for control in get_tree().get_nodes_in_group("payment_toggle"):
		if panel.is_ancestor_of(control): payment_locked=control.disabled
	check(payment_locked,"待确认交易锁定所显示的支付方式")
	var cancel := find_button(panel,"取消")
	check(cancel!=null,"建造确认界面提供取消按钮")
	if cancel: load("res://tests/story.gd").touch(self,cancel)
	check(Inventory.coins==before and not Aquaculture.pen("pen_1").built,"真实触点取消建造不扣材料或改变设施")
	build=find_button(panel,"建造鱼栏")
	if build: load("res://tests/story.gd").touch(self,build)
	await frames(4)
	var confirm := find_button(panel,"确认")
	check(confirm!=null,"建造确认界面有足够大的原生触点")
	if confirm:
		check(confirm.size.y>=48,"确认按钮触控高度至少48逻辑像素")
		load("res://tests/story.gd").touch(self,confirm)
	await frames(4)
	check(Aquaculture.pen("pen_1").built and Inventory.coins<before,"真实触点确认建造调用一次生产事务")
	var confirmed_coins: int=Inventory.coins
	panel.accept();panel.accept()
	check(Inventory.coins==confirmed_coins,"确认回调取出后再次触发不重复建造扣费")
	panel.close_panel();Aquaculture.stock("pen_1","crucian",4)
	for i in range(2): Aquaculture.feed("pen_1");GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
	await frames(5)
	await Touch.place(self,game,"farm",Vector2(880,624))
	Touch.tap(self,game,Vector2(992,592));await Touch.finish(self,game,500)
	check(panel.visible and panel.context=="pen_1","点水中成熟鱼的可视栏体仍走到湖岸打开收获")
	check(game.player.position.x<980,"成熟鱼交互不会把角色送进原水域碰撞")
	var food: int=Inventory.count("fish_feed")
	var feed := find_button(panel,"投喂一次 · 鱼饲料1份")
	check(feed!=null,"成熟鱼栏提供投喂操作")
	if feed: await touch_visible(panel,feed)
	check(Inventory.count("fish_feed")==food-1 and Aquaculture.pen("pen_1").last_feed_day==GameClock.day,"真实触点投喂只消耗一次饲料")
	var harvest := find_button(panel,"收获1尾成年鱼")
	check(harvest!=null,"成熟鱼栏提供保留种鱼的部分收获")
	if harvest: await touch_visible(panel,harvest)
	confirm=find_button(panel,"确认")
	if confirm: await touch_visible(panel,confirm)
	check(Aquaculture.pen("pen_1").adults==3 and Inventory.count("fish_crucian")==1,"真实触点确认收获一尾，三尾种鱼仍在栏内")
	panel.close_panel()
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-062-lake.png")
	panel.open_panel("pen_1");await frames(5)
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-062-panel.png")
	print("RENDER 062 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func find_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==caption: return child
		var result := find_button(child,caption)
		if result: return result
	return null

func touch_visible(panel: PanelContainer, button: Button) -> void:
	var scroll := panel.content.get_parent() as ScrollContainer
	scroll.ensure_control_visible(button)
	await frames(4)
	load("res://tests/story.gd").touch(self,button)
	await frames(4)
