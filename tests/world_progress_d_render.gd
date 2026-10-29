extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	game.get_node("Audio").muted=true;GameClock.running=false;await frames(6)
	load("res://tests/star_runner.gd").fixture(game,true)
	GameClock.day=230;GameClock.minutes=1110;Calendar.restore(Calendar.snapshot());Letters.direction="trade"
	var state: Dictionary=WorldDevelopment.defaults(GameClock.day)
	state.dock=2;state.community=2;state.build_days={"dock":[225,227],"community":[225,225]}
	state.trade_day=227;state.trade_count=1;state.community_day=225;state.community_count=1;state.lamps={"west":225,"square":225,"river":225}
	state.parcels={"dock":{"direction":"trade","items":WorldDevelopment.data.branches.trade.dock.duplicate(true)},"community":{"direction":"trade","items":WorldDevelopment.data.branches.trade.community.duplicate(true)}}
	check(WorldDevelopment.validate(state,GameClock.day),"窗口已建二级工程夹具具有合法先前交接与日期")
	WorldDevelopment.restore(state);GameClock.changed.emit();await frames(5)
	GameState.set_control_mode("tap",false)
	var panel: PanelContainer=game.hud.world_development_panel
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		for context in ["board","dock","community"]:
			await Touch.place(self,game,"village",WorldDevelopment.anchor(context)+Vector2(0,16 if context=="board" else 32))
			panel.open_panel(context);await frames(4)
			check(panel.visible and game.hud.safe.get_global_rect().encloses(panel.get_global_rect()),"新建设/贸易/社区长面板安全区："+str(resolution)+" "+context)
			panel.close_panel()
	get_window().size=Vector2i(1280,720)
	await Touch.place(self,game,"village",Vector2(976,752));await frames(5)
	get_viewport().get_texture().get_image().save_png("res://builds/world-progress-d-dock.png")
	var roof := Vector2(1056,650)
	check(not game.touch_input.ui_at(game.player.get_canvas_transform()*roof),"选择未被UI遮挡的实际交易棚屋顶")
	Touch.tap(self,game,roof);await Touch.finish(self,game,600)
	check(panel.visible and panel.context=="dock" and WorldDevelopment.near("dock"),"点交易棚屋顶也会走到合法码头交互点")
	panel.close_panel()
	await Touch.place(self,game,"village",Vector2(672,784));await frames(6)
	get_viewport().get_texture().get_image().save_png("res://builds/world-progress-d-community.png")
	for day in [253,281,309,337]:
		GameClock.day=day;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(5)
		check(WorldDevelopment.state.dock==2 and WorldDevelopment.state.community==2,"实际渲染换季保留码头与社区等级："+str(day))
	WorldDevelopment.restore(WorldDevelopment.defaults(GameClock.day))
	Inventory.items.wood=100;Inventory.items.stone=100;Inventory.items.copper_bar=10
	await Touch.place(self,game,"village",WorldDevelopment.anchor("board")+Vector2(0,16))
	panel.open_panel("board");await frames(4)
	var build := find_button(panel,"建设河湾装卸码头")
	check(build!=null,"真实建设页提供码头施工入口")
	var coins: int=Inventory.coins
	if build: await touch_visible(panel,build)
	var cancel := find_button(panel,"取消")
	check(cancel!=null,"施工费用确认包含取消入口")
	if cancel: await touch_visible(panel,cancel)
	check(Inventory.coins==coins and WorldDevelopment.state.dock==0 and Inventory.count("wood")==100,"原生触点取消施工不扣金币木材或生成码头")
	build=find_button(panel,"建设河湾装卸码头")
	if build: await touch_visible(panel,build)
	var confirm := find_button(panel,"确认")
	check(confirm!=null and confirm.size.y>=48,"施工确认按钮满足48px触控目标")
	if confirm: await touch_visible(panel,confirm)
	check(WorldDevelopment.state.dock==1 and Inventory.coins==coins-240 and Inventory.count("wood")==82,"原生触点最终确认一次调用真实建设事务")
	var after: int=Inventory.coins
	panel.accept();panel.accept()
	check(Inventory.coins==after and WorldDevelopment.state.dock==1,"确认回调消费后重放不能重复扣费或连升")
	panel.close_panel()
	print("RENDER WORLD PROGRESS D RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==text: return child
		var result := find_button(child,text)
		if result: return result
	return null
func touch_visible(panel: PanelContainer, control: Button) -> void:
	var scroll := panel.content.get_parent() as ScrollContainer
	scroll.ensure_control_visible(control);await frames(4)
	load("res://tests/story.gd").touch(self,control);await frames(4)
