extends "res://tests/runner.gd"
## Xvfb/真实桌面窗口、原生触点和横屏安全区；不代表Android真机验收。
const Touch = preload("res://tests/touch_navigation.gd")
const StoryTouch = preload("res://tests/story.gd")
var prefix: String = ""

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(6)
	load("res://tests/star_runner.gd").fixture(game,false)
	game.tutorial.restore(GameTutorial.defaults(true))
	Inventory.coins=100000
	Inventory.items={"wood":200,"stone":200,"iron_bar":100,"crystal":100,"carrot":8,"potato":8,"wheat":8,"fish_feed":30,"fry_crucian":8,"fishing_bait":30}
	GameState.set_control_mode("tap",false)
	var abyss: Dictionary=AbyssState.defaults();abyss.unlocked=true;abyss.max_clear=100;abyss.gear=7;abyss.checkpoint=100;abyss.bosses=[20,40,60,80,100]
	for depth in range(1,101): abyss.gates.append(depth);abyss.notes.append(depth)
	AbyssState.restore(abyss)
	for spec in [[Vector2i(1280,720),false],[Vector2i(1600,720),false],[Vector2i(1280,960),false],[Vector2i(1280,720),true]]:
		get_window().size=spec[0];await frames(5)
		game.hud.update_safe_area()
		if spec[1]: game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720))
		await frames(3)
		prefix=str(spec[0])+("+左右各64安全区" if spec[1] else "")
		await toolbar()
		await panels()
	game.hud.update_safe_area()
	print("PALM UI RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func buttons(parent: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(buttons(child))
	return result

func find_button(parent: Node,caption: String) -> Button:
	for control in buttons(parent):
		if control.text.begins_with(caption): return control
	return null

func scroll_for(control: Control) -> ScrollContainer:
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: return ancestor
		ancestor=ancestor.get_parent()
	return null

func reveal(control: Control) -> void:
	var scroll := scroll_for(control)
	if scroll: scroll.ensure_control_visible(control)
	await frames(2)

func tap_button(control: Button) -> void:
	if not is_instance_valid(control): return
	await reveal(control)
	StoryTouch.touch(self,control)
	await frames(3)

func at(area: String,point: Vector2) -> void:
	while game.hud.close_active_panel(): pass
	game.auto_move.cancel();game.change_location(area,point)
	game.player.action_time=0;game.player.touch_direction=Vector2.ZERO
	await frames(4)

func audit_panel(panel: Control,name_text: String) -> void:
	await frames(4)
	check(panel.visible and GameState.modal and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),prefix+" · "+name_text+"完整位于安全区")
	var dimensions_ok := true
	var reachable := true
	var bad: Array[String]=[]
	var controls: Array[Button]=buttons(panel)
	for control in controls:
		if control.size.y<48 or control.size.x<48: dimensions_ok=false;bad.append("尺寸:"+control.text)
		await reveal(control)
		var rect: Rect2=control.get_global_rect()
		if not panel.get_global_rect().grow(.5).encloses(rect) or not game.hud.safe.get_global_rect().grow(.5).encloses(rect): reachable=false;bad.append("边界:"+control.text)
		if control.has_method("contains_touch") and not control.contains_touch(rect.get_center()): reachable=false;bad.append("裁剪:"+control.text)
	check(not controls.is_empty() and dimensions_ok,prefix+" · "+name_text+"主要按钮至少48×48")
	check(reachable,prefix+" · "+name_text+"按钮可滚入可触达区域"+("："+"、".join(bad) if not bad.is_empty() else ""))
	var position: Vector2=game.player.global_position
	var serial: int=game.auto_move.execution_count
	var p: Vector2=panel.get_global_rect().position+Vector2(24,24)
	Touch.finger(self,p,true,101);Touch.finger(self,p,false,101);await frames(2)
	check(game.player.global_position==position and game.auto_move.target.is_empty() and game.auto_move.execution_count==serial,prefix+" · "+name_text+"原生UI触点不穿透到地图")

func toolbar() -> void:
	await at("farm",Vector2(624,624))
	var legal := true
	var clicked := true
	var before: Vector2=game.player.global_position
	for i in range(game.hud.tool_buttons.size()):
		await Touch.expand_hotbar(self,game)
		var control: Button=game.hud.tool_buttons[i]
		legal=legal and control.size.y>=48 and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect())
		StoryTouch.touch(self,control);await frames(1)
		clicked=clicked and GameState.selected==i and game.auto_move.target.is_empty() and game.player.global_position==before
	check(legal,prefix+" · 九工具按钮完整可见且高度适合触屏")
	check(clicked,prefix+" · 九工具原生点击准确选择且无地图移动")

func panels() -> void:
	game.hud.inventory_panel.open_panel(false);await audit_panel(game.hud.inventory_panel,"背包")
	game.hud.inventory_panel.close_panel()
	game.hud.progress_panel.open_panel("journal",false);await audit_panel(game.hud.progress_panel,"委托日志")
	game.hud.progress_panel.close_panel()
	game.hud.story_panel.open_panel();game.hud.story_panel.select_page(2);await audit_panel(game.hud.story_panel,"村民手记")
	game.hud.story_panel.close_panel()
	game.hud.dialogue.open_dialogue("林芽",["湖里的鱼和田里的麦子都需要留些余地。今天慢慢来，明天还会有新的收获。"])
	await audit_panel(game.hud.dialogue,"NPC对话")
	var close: Button=find_button(game.hud.dialogue,"稍后再聊")
	await tap_button(close);check(not GameState.modal,prefix+" · 对话可以用原生触点安全关闭")
	await at("farm",Fishing.point("farm_lake")+Vector2(-32,0))
	GameState.select_tool(GameState.tools.find("fishing_rod"))
	game.hud.fishing_panel.open_panel("farm_lake");await audit_panel(game.hud.fishing_panel,"钓鱼与补给")
	var cast: Button=find_button(game.hud.fishing_panel,"向水面抛竿")
	await tap_button(cast)
	check(Fishing.active() and is_instance_valid(game.hud.fishing_panel.hold),prefix+" · 原生按钮开始真实钓鱼小游戏")
	if is_instance_valid(game.hud.fishing_panel.hold):
		await reveal(game.hud.fishing_panel.hold)
		var hold: Control=game.hud.fishing_panel.hold
		var point: Vector2=hold.get_global_rect().get_center()
		Touch.finger(self,point,true,102)
		check(hold.size.y>=48 and game.hud.safe.get_global_rect().encloses(hold.get_global_rect()) and hold.held,prefix+" · 追鱼长按区可达且原生触点响应")
		Touch.finger(self,point,false,102)
	game.hud.fishing_panel.close_panel()
	await at("home",Housing.HOME+Vector2(32,0))
	game.hud.housing_panel.open_panel("home");await audit_panel(game.hud.housing_panel,"家具网格")
	game.hud.housing_panel.page="catalog";game.hud.housing_panel.refresh();await frames(3)
	var buy_chair: Button=find_button(game.hud.housing_panel,"制作一件 · 靠背椅")
	var furniture_before: Dictionary=Housing.snapshot()
	var money_before: int=Inventory.coins
	var materials_before: Dictionary=Inventory.items.duplicate(true)
	await tap_button(buy_chair);await audit_panel(game.hud.housing_panel,"家具制作确认")
	var cancel_chair: Button=find_button(game.hud.housing_panel,"取消")
	await tap_button(cancel_chair)
	check(Housing.snapshot()==furniture_before and Inventory.coins==money_before and Inventory.items==materials_before and not game.hud.housing_panel.pending.is_valid(),prefix+" · 家具确认可真实取消且不扣材料金币")
	game.hud.housing_panel.close_panel()
	await at("farm",Vector2(480,480))
	game.hud.inventory_panel.open_panel(true);await audit_panel(game.hud.inventory_panel,"种子商店")
	await sale_confirmation()
	game.hud.inventory_panel.close_panel()
	await at("farm",Vector2(912,592))
	game.hud.aquaculture_panel.open_panel("pen_1");await audit_panel(game.hud.aquaculture_panel,"湖泊鱼栏")
	game.hud.aquaculture_panel.close_panel()
	await at("farm",Livestock.SITES.coop+Vector2(0,32))
	game.hud.livestock_panel.open_panel("coop");await audit_panel(game.hud.livestock_panel,"畜舍管理")
	game.hud.livestock_panel.close_panel()
	AbyssState.state.depth=100
	await at("abyss",AbyssState.point(AbyssState.layout().controls[1]))
	game.hud.abyss_panel.open_panel("up");await audit_panel(game.hud.abyss_panel,"第100层矿洞")
	game.hud.abyss_panel.close_panel()
	await wedding()
	await menu_help()

func wedding() -> void:
	load("res://tests/marriage_requirement_fixture.gd").satisfy(game)
	Xiaojing.state.proposed=true
	LegendState.state.greenhouse=4 # 已完成四段修复，允许正常进入独立礼堂。
	if "proposal" not in StarStory.state.events: StarStory.state.events.append("proposal")
	StarStory.state.invited=["linya","zhou","ahe"];StarStory.state.wedding_phase=2
	River.state.venue_used=true
	await at("greenhouse",Vector2(760,556))
	check(Xiaojing.marriage_ready() and Xiaojing.state.diamonds>=1314,prefix+" · 婚礼确认夹具确实满足全部前置")
	game.hud.river_panel.open_panel("ceremony_right");await audit_panel(game.hud.river_panel,"1314钻石婚礼确认")
	var before: int=Xiaojing.state.diamonds
	var inventory: Dictionary=Inventory.items.duplicate(true)
	var cancel: Button=find_button(game.hud.river_panel,"取消，继续准备")
	await tap_button(cancel)
	check(not GameState.modal and not Xiaojing.state.married and Xiaojing.state.diamonds==before and Inventory.items==inventory,prefix+" · 原生触点取消婚礼不扣1314钻石、不改变资源婚姻")

func menu_help() -> void:
	game.hud.system_panel.open_panel();await audit_panel(game.hud.system_panel,"设置菜单")
	var help: Button=find_button(game.hud.system_panel,"操作与生活指南")
	await tap_button(help);await audit_panel(game.hud.system_panel,"可滚动生活指南")
	var back: Button=find_button(game.hud.system_panel,"返回设置")
	check(back!=null and game.hud.system_panel.body.text.contains("每天3次"),prefix+" · 菜单展示真实恢复与玩法说明")
	if back:
		var scroll: ScrollContainer=scroll_for(back)
		if scroll:
			scroll.scroll_vertical=0;await frames(2)
			var start: Vector2=scroll.get_global_rect().position+Vector2(200,minf(260,scroll.size.y-30))
			Touch.finger(self,start,true,103)
			for i in range(8):
				var drag := InputEventScreenDrag.new();drag.index=103;drag.position=start+Vector2(0,-i*22-22);drag.relative=Vector2(0,-22);get_viewport().push_input(drag,true);await frames(1)
			Touch.finger(self,start+Vector2(0,-176),false,103)
			check(scroll.scroll_vertical>0,prefix+" · 生活指南支持真实触屏拖动滚动")
		await tap_button(back)
		check(find_button(game.hud.system_panel,"操作与生活指南")!=null and GameState.modal,prefix+" · 滚动后的返回设置可真实点击")
	game.hud.system_panel.close_panel()

func sale_confirmation() -> void:
	var panel: PanelContainer=game.hud.inventory_panel
	var saved_items: Dictionary=Inventory.items.duplicate(true)
	var coins: int=Inventory.coins
	Inventory.items.carrot=5
	var offered_items: Dictionary=Inventory.items.duplicate(true)
	panel.refresh();await frames(3)
	panel.select_item("carrot");await frames(2)
	var sale: Button=find_button(panel,"出售全部")
	await tap_button(sale)
	check(panel.pending_sale.get("item","")=="carrot" and Inventory.items==offered_items and Inventory.coins==coins,prefix+" · 原生出售点击仅打开确认，尚未移除五个胡萝卜")
	await audit_panel(panel,"出售不可撤回确认")
	await tap_button(find_button(panel,"取消出售"))
	check(panel.pending_sale.is_empty() and Inventory.items==offered_items and Inventory.coins==coins,prefix+" · 原生取消出售保留全部作物金币")
	panel.select_item("carrot");await frames(2)
	await tap_button(find_button(panel,"出售全部"))
	await tap_button(find_button(panel,"确认出售"))
	check(panel.pending_sale.is_empty() and Inventory.count("carrot")==0 and Inventory.coins==coins+5*Catalog.sell_price("carrot"),prefix+" · 原生确认出售只扣五个胡萝卜并按原价结算一次")
	Inventory.items=saved_items;Inventory.coins=coins;Inventory.changed.emit()
