extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
const UI=preload("res://tests/story.gd")
func run() -> void:
	get_window().size=Vector2i(1280,720)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock()
	game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(4)
	var device: String=await Fixture.install(self,game,"station_mill")
	check(device!="" and await Fixture.approach(self,game,device),"高DPI下正常建造并靠近设备")
	Inventory.items.wheat=5
	game.hud.workshop_panel.open_panel(device);await frames(5);game.hud.reflow_panels();await frames(3)
	var panel: PanelContainer=game.hud.workshop_panel
	var safe: Rect2=game.hud.safe.get_global_rect()
	var start: Button=UI.find_button(panel,"开始加工");var close: Button=UI.find_button(panel,"收起 ×")
	check(UIMetrics.minimum_target()==96 and safe.grow(1).encloses(panel.get_global_rect()),"480DPI按物理缩放换算96逻辑触区且面板在模拟安全区内")
	check(start!=null and close!=null and start.size.y>=96 and close.size.y>=96 and safe.grow(1).encloses(start.get_global_rect()) and safe.grow(1).encloses(close.get_global_rect()),"高DPI开始与关闭按钮完整可见且触区足够")
	var position: Vector2=game.player.position
	Touch.finger(self,Vector2(30,360),true,81);Touch.finger(self,Vector2(30,360),false,81);await frames(6)
	check(game.player.position==position and game.auto_move.state==game.auto_move.State.IDLE,"安全区外和面板外触摸均不穿透到地图")
	if start: UI.touch(self,start)
	await frames(4)
	check(not panel.pending.is_empty() and Inventory.count("wheat")==5,"原生触摸只进入加工确认，不提前扣料")
	await shot("dpi-480-confirm")
	var confirm: Button=UI.find_button(panel,"确认开始")
	if confirm:
		var at:=confirm.get_global_rect().get_center()
		Touch.finger(self,at,true,82);Touch.finger(self,at,true,83);Touch.finger(self,at,false,83);Touch.finger(self,at,false,82)
	await frames(5)
	check(Inventory.count("wheat")==4 and Workshop.state.jobs.size()==1 and Workshop.state.next_job==2,"双触点确认只创建一笔加工且不重复扣料")
	await shot("dpi-480-processing")
	close=UI.find_button(panel,"收起 ×");if close: UI.touch(self,close)
	await frames(5);check(not GameState.modal and not panel.visible,"真实关闭按钮恢复地图操作")
	Inventory.items.strawberry_seed=3;game.hud.inventory_panel.open_panel(false);await frames(5)
	var equip: Button
	for b in game.hud.inventory_panel.find_children("*","Button",true,false):
		if b.get_meta("inventory_action","")=="strawberry_seed" and b.get_meta("action_kind","")=="equip": equip=b;break
	check(equip!=null,"背包存在新种子的实际装备按钮")
	if equip:
		game.hud.inventory_panel.scroll.ensure_control_visible(equip);await frames(5);UI.touch(self,equip)
	await frames(5)
	check(not GameState.modal and GameState.tool()=="strawberry_seed","高DPI原生触摸能装备草莓种子")
	game.farm.use_tool(Vector2i(18,17),"hoe");game.player.action_time=0
	await Touch.place(self,game,"farm",Vector2(592,592));GameState.manual_tool=true
	Touch.tap(self,game,Vector2(592,560));await Touch.finish(self,game);await frames(30)
	check(game.farm.plot_at(Vector2i(18,17)).get("crop","")=="strawberry" and Inventory.count("strawberry_seed")==2,"新种子通过真实点击移动与生效帧播种，坐标正确")
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
	Inventory.items.flour=4;Inventory.items.egg=2;Inventory.items.milk=1
	game.hud.kitchen_panel.open_panel();game.hud.kitchen_panel.recipe_page=1;game.hud.kitchen_panel.selected_recipe="cake";game.hud.kitchen_panel.refresh();await frames(5);game.hud.reflow_panels();await frames(3)
	check(safe.grow(1).encloses(game.hud.kitchen_panel.get_global_rect()),"高DPI厨房仍保持在横屏安全区")
	var cook: Button=UI.find_button(game.hud.kitchen_panel,"制作田园蛋糕 ×1")
	if cook:
		for scroll in game.hud.kitchen_panel.find_children("*","ScrollContainer",true,false):
			if scroll.is_ancestor_of(cook): scroll.ensure_control_visible(cook)
		await frames(5);UI.touch(self,cook)
	await frames(4)
	check(game.hud.kitchen_panel.pending.is_valid() and Inventory.count("cake")==0,"厨房滚动后制作按钮能真实命中，确认前不产出")
	await shot("dpi-480-kitchen")
	game.hud.close_active_panel();UIMetrics.screen_provider=Callable()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"触控测试后作物、订单与九格状态可正常保存")
	print("HARVEST TOUCH RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/harvest-workshop/"+id+".png")
