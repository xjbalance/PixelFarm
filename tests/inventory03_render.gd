extends "res://tests/runner.gd"
## Linux真实窗口与原生触点；记录背包布局和选中反馈，不代表Android真机。
const Touch=preload("res://tests/touch_navigation.gd")
var panel: PanelContainer
var prefix: String=""

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true));panel=game.hud.inventory_panel
	Inventory.items={"carrot_seed":8,"carrot":20,"potato_seed":6,"potato":12,"wood":12,"stone":11,"fish_feed":8,"fishing_bait":7,"fish_soup":4,"potato_bread":3}
	Xiaojing.state.diamonds=1400;Inventory.coins=12345
	for spec in [[Vector2i(1280,720),false],[Vector2i(1600,720),false],[Vector2i(1280,960),false],[Vector2i(1280,720),true]]:
		get_window().size=spec[0];await frames(5);game.hud.update_safe_area()
		if spec[1]: game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720))
		await frames(4);prefix=str(spec[0])+(" safe64" if spec[1] else "")
		await bag_layout()
	game.hud.update_safe_area()
	print("INVENTORY 03 RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func buttons(root: Node) -> Array[Button]:
	var out: Array[Button]=[]
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree(): out.append(child)
		out.append_array(buttons(child))
	return out

func find_button(caption: String) -> Button:
	for button in buttons(panel):
		if button.text==caption: return button
	return null

func reveal(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(2)

func tap(button: Button,index: int=220) -> void:
	if not button: check(false,prefix+"预期按钮存在");return
	await reveal(button)
	var at: Vector2=button.get_global_rect().get_center()
	Touch.finger(self,at,true,index);Touch.finger(self,at,false,index);await frames(2)

func selectors() -> Array[Button]:
	var result: Array[Button]=[]
	for button in buttons(panel):
		if button.has_meta("inventory_item"): result.append(button)
	return result

func stamp() -> Dictionary:
	return {"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina}

func bag_layout() -> void:
	GameState.set_control_mode("tap",false)
	game.change_location("farm",Vector2(656,480));await frames(4)
	panel.open_panel(false);await frames(4)
	check(panel.visible and GameState.modal and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),prefix+"背包完整处于安全区")
	for category in ["种子与收获","材料与矿物","鱼苗与湖鲜","生活与料理"]:
		await tap(find_button(category));await frames(3)
		var size_ok:=true;var reachable:=true
		for button in buttons(panel):
			size_ok=size_ok and button.size.x>=48 and button.size.y>=48
			await reveal(button)
			reachable=reachable and panel.get_global_rect().grow(.5).encloses(button.get_global_rect()) and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect())
			if button.has_method("contains_touch"): reachable=reachable and button.contains_touch(button.get_global_rect().get_center())
		check(size_ok,prefix+"主要按钮至少48×48："+category)
		check(reachable,prefix+"全部按钮可滚入合法触区而不裁剪："+category)
		var picks:=selectors()
		check(picks.size()>=2,prefix+"物品有独立查看入口："+category)
		if picks.size()>=2:
			var before:=stamp()
			var chosen: String=str(picks[0].get_meta("inventory_item"))
			await tap(picks[0])
			check(panel.selected_item==chosen and picks[0].button_pressed and stamp()==before,prefix+"原生图标/名称点击选中A且不消耗："+category)
			var next: String=str(picks[1].get_meta("inventory_item"))
			await tap(picks[1])
			var highlighted:=0
			for selector in selectors():
				if selector.button_pressed: highlighted+=1
			check(panel.selected_item==next and highlighted==1 and stamp()==before,prefix+"选择B立即切换且仅一个高亮："+category)
			check(panel.selected_detail.text.contains(Catalog.item_name(next)) and panel.selected_detail.text.contains(str(Inventory.count(next))),prefix+"详情名称与真实数量对应所选项："+category)
			if get_window().size==Vector2i(1280,720): await capture(category)
		var player_at: Vector2=game.player.position;var serial: int=game.auto_move.execution_count
		var blank: Vector2=panel.get_global_rect().position+Vector2(24,24)
		Touch.finger(self,blank,true,221);Touch.finger(self,blank,false,221);await frames(2)
		check(game.player.position==player_at and game.auto_move.execution_count==serial and game.auto_move.target.is_empty(),prefix+"分类查看触点不穿透农田地图："+category)
	await tap(find_button("生活与料理"));await frames(3)
	var scroll: ScrollContainer=panel.rows.get_parent()
	scroll.scroll_vertical=0;await frames(2)
	var point: Vector2=scroll.get_global_rect().position+Vector2(220,minf(130,scroll.size.y-12))
	var before:=stamp();Touch.finger(self,point,true,222)
	for i in range(6):
		var drag:=InputEventScreenDrag.new();drag.index=222;drag.position=point+Vector2(0,-20*(i+1));drag.relative=Vector2(0,-20)
		get_viewport().push_input(drag,true);await frames(1)
	Touch.finger(self,point+Vector2(0,-120),false,222);await frames(2)
	check(scroll.scroll_vertical>0 and stamp()==before,prefix+"真实拖动浏览只滚动，不消费食物或复制物品")
	var offset: int=scroll.scroll_vertical
	Inventory.add("fishing_bait",1);await frames(4)
	check(absi(scroll.scroll_vertical-offset)<=1,prefix+"数量局部更新保留当前滚动位置")
	await tap(find_button("关闭 ×"));await frames(2)
	check(not panel.visible and not GameState.modal and str(panel.selected_item)=="",prefix+"关闭后没有旧选中或悬浮菜单")
	var legal:=true
	for i in range(game.hud.tool_buttons.size()):
		var button: Button=game.hud.tool_buttons[i]
		legal=legal and button.size.x>=48 and button.size.y>=48 and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect())
	check(legal and game.hud.tool_buttons.size()==9,prefix+"九格既有快捷栏可见且保持合法触点尺寸")
	await tap(game.hud.tool_buttons[3]);await frames(2)
	var style: StyleBoxFlat=game.hud.tool_buttons[3].get_theme_stylebox("normal")
	check(GameState.selected==3 and style.border_color==FarmUIStyle.GOLD,prefix+"快捷工具原生选择与高亮对应")

func capture(category: String) -> void:
	await RenderingServer.frame_post_draw
	var names: Dictionary={"种子与收获":"crops","材料与矿物":"materials","鱼苗与湖鲜":"fish","生活与料理":"life"}
	var suffix: String="safe" if prefix.contains("safe64") else "wide"
	get_viewport().get_texture().get_image().save_png("res://builds/inventory03-"+str(names[category])+"-"+suffix+".png")
