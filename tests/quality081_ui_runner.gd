extends "res://tests/ui05_layout_runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const UI=preload("res://tests/story.gd")
var initial: Dictionary
var mill: String=""
var dryer: String=""
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock();GameClock.minutes=720
	mill=await Fixture.install(self,game,"station_mill");dryer=await Fixture.install(self,game,"station_drying_rack")
	initial=FarmSaveStore.snapshot(game)
	await workshop_interaction()
	await season_shop()
	await guidance()
	await layouts()
	UIMetrics.screen_provider=Callable()
	var file:=FileAccess.open("res://docs/quality081/ui-results.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checked,"failures":failed,"samples":samples,"issues":issues,"actual_window":DisplayServer.get_name()!="headless","android_device_tested":false},"\t"));file.close()
	print("QUALITY081 UI RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func reset_state() -> void:
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,initial),"界面测试恢复原生产状态")
	GameClock.running=false;await frames(5)
func workshop_interaction() -> void:
	await Fixture.approach(self,game,mill);Inventory.items.erase("wheat")
	var panel: PanelContainer=game.hud.workshop_panel;panel.open_panel(mill);await frames(5)
	check(panel.status.text.contains("小麦") and UI.find_button(panel,"开始加工").disabled,"缺料指明小麦并禁用开始")
	check(panel.remaining.text.contains("今天 12:45"),"预计完成时间按绝对游戏分钟显示")
	var writes: int=panel.progress_updates;var builds: int=panel.detail_builds;await frames(90)
	check(panel.progress_updates==writes and panel.detail_builds==builds,"暂停菜单90帧不重复写进度或重建详情")
	var id: int=panel.recipe_buttons.mill_flour.get_instance_id();Inventory.add("stone",1);await frames(4)
	check(panel.detail_builds==builds and panel.recipe_buttons.mill_flour.get_instance_id()==id,"无关库存变化不重建配方列表与当前详情")
	Inventory.add("wheat",6);await frames(4)
	check(not UI.find_button(panel,"开始加工").disabled and panel.recipe_buttons.mill_flour.get_meta("recipe_state")=="可制作","库存补齐后状态自动刷新")
	await capture_case("ui-mill-ready")
	await tap(UI.find_button(panel,"开始加工"));var before:=Inventory.items.duplicate()
	check(not panel.pending.is_empty(),"原生点击先进入投入确认")
	await tap(UI.find_button(panel,"取消"))
	check(panel.pending.is_empty() and Inventory.items==before,"取消不扣材料")
	await tap(UI.find_button(panel,"开始加工"));await tap(UI.find_button(panel,"确认开始"))
	check(Inventory.count("wheat")==5 and Workshop.state.jobs[mill].inputs=={"wheat":1},"原生确认只投入一次并保留实际账单")
	var input_shown: bool=false
	for item in labels(panel): input_shown=input_shown or item.text=="已投入 1"
	check(input_shown and UI.find_button(panel,"收取成品").disabled,"加工页显示本单已投入与未完成状态")
	await tap(panel.recipe_buttons.corn_feed)
	check(Workshop.state.jobs[mill].recipe=="mill_flour" and UI.find_button(panel,"开始加工")==null,"忙碌时浏览其他配方不修改当前工单")
	await capture_case("ui-processing");panel.close_panel()
	await Fixture.approach(self,game,dryer);panel.open_panel(dryer);await frames(5)
	var selected: String=panel.selected;var player_pos: Vector2=game.player.position;var camera_pos: Vector2=game.camera_rig.view_center
	var start: Vector2=panel.left_scroll.get_global_rect().position+Vector2(90,100)
	Touch.finger(self,start,true,710)
	var drag:=InputEventScreenDrag.new();drag.index=710;drag.position=start-Vector2(0,90);drag.relative=Vector2(0,-90);get_viewport().push_input(drag,true)
	Touch.finger(self,drag.position,false,710);await frames(5)
	check(panel.left_scroll.scroll_vertical>0 and panel.selected==selected and panel.pending.is_empty(),"列表拖动只滚动，不触发选项或制作")
	var scrolled: int=panel.left_scroll.scroll_vertical;var list_builds: int=panel.list_builds
	Inventory.add("wood",1);await frames(4)
	check(panel.left_scroll.scroll_vertical==scrolled and panel.list_builds==list_builds,"库存刷新保留配方滚动位置")
	check(game.player.position==player_pos and game.camera_rig.view_center==camera_pos,"配方滑动不传给地图移动或自由观察相机")
	var button: Button=panel.recipe_buttons.values()[-1];await tap(button)
	check(panel.selected==str(button.get_meta("recipe_id")),"滚动后实际命中配方，缓存按钮仍有效")
	panel.close_panel();Fixture.advance(45);await Fixture.approach(self,game,mill);panel.open_panel(mill);await frames(4)
	check(panel.status.text.contains("已完成") and not UI.find_button(panel,"收取成品").disabled,"时间到期明确显示收取操作")
	await capture_case("ui-output");await tap(UI.find_button(panel,"收取成品"));check(Inventory.count("flour")==1,"原生领取获得一次成品");panel.close_panel()
func season_shop() -> void:
	await reset_state();GameClock.day=85;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(3)
	await Touch.place(self,game,"farm",FarmLayout.point("shop")+Vector2(0,32));game.hud.inventory_panel.open_panel(true)
	var panel: PanelContainer=game.hud.inventory_panel;panel.quantity=3;panel.refresh();await frames(4)
	var before:=Inventory.items.duplicate();var coins: int=Inventory.coins
	var buy: Button
	for button in panel.find_children("*","Button",true,false):
		if button.get_meta("action_kind","")=="seed_buy" and button.get_meta("inventory_action","")=="carrot": buy=button;break
	check(buy!=null and buy.text.contains("提前备种"),"冬季原胡萝卜种子保留交易但显式提示备种")
	await tap(buy)
	check(not panel.pending_purchase.is_empty() and Inventory.items==before and Inventory.coins==coins,"跨季购买先确认，未确认不扣款")
	await capture_case("ui-seed-warning")
	var token: int=panel.pending_purchase.token;panel.change_category(1);panel.confirm_purchase(token)
	check(panel.pending_purchase.is_empty() and Inventory.items==before and Inventory.coins==coins,"切分类使旧备种确认失效")
	panel.change_category(0);panel.buy("carrot");token=int(panel.pending_purchase.token)
	await tap(UI.find_button(panel,"确认备种"));panel.confirm_purchase(token)
	check(Inventory.count("carrot_seed")==int(before.carrot_seed)+3 and Inventory.coins==coins-36,"确认后只购买三袋，旧确认不能重复扣款")
	panel.close_panel();Fixture.cooperative();panel.open_panel(true);panel.quantity=2;panel.buy("carrot");coins=Inventory.coins
	await tap(UI.find_button(panel,"确认备种"))
	check(Inventory.coins==coins-20,"原合作社八折向上取整规则继续生效")
	panel.crop_group=2;panel.crop_page=0;panel.content_key="";panel.refresh();panel.select_item("carrot_seed");await frames(4)
	check(panel.selected_detail.text.contains("当前季节不生长") and panel.selected_detail.text.contains("2个浇水生长日"),"种子详情包含实际季节、成长日与用途")
	check(not panel.selected_detail.text.contains("适合温室"),"未实现温室种植时不误标温室适种")
	await capture_case("ui-seed-catalogue");panel.close_panel()
func guidance() -> void:
	await reset_state();var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/quality081_v28.json"))
	var upgraded:=FarmSaveSchema.normalize(old);var complete: bool=true
	for id in GameTutorial.PRODUCTION_TOPICS: complete=complete and id in upgraded.tutorial.seen
	check(complete,"旧v28存档新增加工帮助默认已读，不重复打扰")
	game.tutorial.restore(GameTutorial.defaults());Inventory.items.wheat=1;Inventory.changed.emit();Inventory.changed.emit()
	check(game.tutorial.pending.count("wheat_milling")==1,"新玩家获得小麦只排一次轻提示")
	var hint: String=game.tutorial.inline_hint("workshop_first")
	check(hint!="" and game.tutorial.inline_hint("workshop_first")=="","首次磨坊说明内联显示且只显示一次")
	var saved: Dictionary=game.tutorial.snapshot();game.tutorial.restore(saved)
	check(game.tutorial.inline_hint("workshop_first")=="" and GameTutorial.help_text().contains("满包会保留成品"),"帮助已读可恢复，菜单仍可查阅全部说明")
	game.tutorial.restore(GameTutorial.defaults(true))
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32));Inventory.items.carrot=2;Inventory.items.potato=1
	var before:=Inventory.items.duplicate();game.backgrounded=true
	check(not Kitchen.cook("carrot_stew") and Inventory.items==before,"后台延迟厨房确认不扣料或额外制作")
	game.backgrounded=false
	game.tutorial.restore(GameTutorial.defaults())
	Inventory.items.carrot=4;Inventory.items.potato=2
	check(Kitchen.cook("carrot_stew") and Kitchen.cook("carrot_stew") and game.tutorial.pending.count("food_energy")==1,"首次真实做菜只排一次体力恢复说明")
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill);Inventory.items.wheat=2
	check(Workshop.start(mill,"mill_flour"),"新玩家实际开始一笔加工")
	Fixture.advance(45);Workshop.update_ready();GameClock.changed.emit()
	check(game.tutorial.pending.count("workshop_collect")==1,"首次真实完工只排一次收取提示")
	game.tutorial.restore(GameTutorial.defaults(true))
func layouts() -> void:
	await reset_state()
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4);prefix="quality081-"+str(extent)
		await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill)
		game.hud.workshop_panel.open_panel(mill);await capture_case("ui-workshop-%dx%d" % [extent.x,extent.y]);await audit(game.hud.workshop_panel,"加工");game.hud.close_active_panel()
		await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32));game.hud.kitchen_panel.open_panel();await capture_case("ui-kitchen-%dx%d" % [extent.x,extent.y]);await audit(game.hud.kitchen_panel,"厨房");game.hud.close_active_panel()
		game.hud.inventory_panel.open_panel(true);await audit(game.hud.inventory_panel,"种子商店");game.hud.close_active_panel()
	get_window().size=Vector2i(1280,720);UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(4)
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill);game.hud.workshop_panel.open_panel(mill);game.hud.workshop_panel.refresh();await frames(4)
	# Runtime density change is a desktop test injection; update the persistent header target as on Android creation.
	for button in game.hud.workshop_panel.find_children("*","Button",true,false): button.custom_minimum_size.y=maxf(button.custom_minimum_size.y,UIMetrics.minimum_target())
	game.hud.reflow_panels();prefix="quality081-480dpi-safe64";await audit(game.hud.workshop_panel,"加工")
	check(UIMetrics.drag_threshold()==24,"滚动阈值随DPI换算为24逻辑像素，不再固定为12设计像素")
	await capture_case("ui-dpi480");game.hud.close_active_panel()
func capture_case(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(5);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/quality081/"+id+".png")
