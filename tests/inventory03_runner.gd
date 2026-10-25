extends "res://tests/runner.gd"
## 背包展示、选择和原生按钮只负责交互，不改变原物品/经济规则。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary
var panel: PanelContainer
var notices: Array[String]=[]

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	initial=FarmSaveStore.snapshot(game);panel=game.hud.inventory_panel
	Events.notice.connect(func(message: String): notices.append(message))
	await opening_and_updates()
	await use_safety()
	if "--baseline" not in OS.get_cmdline_user_args():
		await selection_and_tabs()
		await quantity_and_capacity()
		await hotbar_and_farming()
		await lifecycle()
	print("INVENTORY 03 RESULT: %d checks, %d failures" % [checked,failed])
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	GameState.set_control_mode("tap",false);game.tutorial.restore(GameTutorial.defaults(true))
	Inventory.items={"carrot_seed":8,"potato_seed":5,"wheat_seed":4,"carrot":20,"potato":10,"wood":12,"stone":11,"fish_feed":7,"fishing_bait":6,"fish_soup":4,"carrot_stew":3}
	GameState.stamina=10;Xiaojing.state.diamonds=1400
	await Touch.place(self,game,"farm",Vector2(656,480));notices.clear()

func stamp() -> Dictionary:
	return {"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina,"plants":Xiaojing.state.plants}

func find_button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and child.text==caption: return child
		var found:=find_button(child,caption)
		if found: return found
	return null

func reveal(control: Control) -> void:
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(2)

func touch_button(control: Button, index: int=151) -> void:
	if not is_instance_valid(control): check(false,"预期背包按钮存在");return
	await reveal(control)
	var at: Vector2=control.get_global_rect().get_center()
	Touch.finger(self,at,true,index);Touch.finger(self,at,false,index)
	await frames(2)

func row_ids() -> Array:
	var result: Array=[]
	for child in panel.rows.get_children(): result.append(child.get_instance_id())
	return result

func opening_and_updates() -> void:
	await fresh();panel.open_panel(false);await frames(4)
	check(panel.visible and GameState.modal,"背包打开后暂停地图操作")
	var first:=row_ids()
	Inventory.add("carrot",1);await frames(3)
	check(row_ids()==first,"单一物品数量变化局部更新，不重新分配全部背包行")
	var same:=row_ids()
	panel.refresh();panel.refresh();await frames(2)
	check(row_ids()==same,"无数据变化重复刷新保留原行与按钮身份")
	var time: float=GameClock.minutes;GameClock.running=true;GameClock._process(2);GameClock.running=false
	check(GameClock.minutes==time,"背包查看和滚动不推进游戏时钟")
	panel.close_panel();await frames(3)
	check(not panel.visible and not GameState.modal,"关闭背包恢复当前操作模式")

func use_safety() -> void:
	await fresh();panel.open_panel(false);await frames(4)
	var eat:=find_button(panel,"吃1个\n+8体力")
	check(eat!=null,"基础食物仍使用明确食用按钮")
	if not eat: return
	await reveal(eat)
	var at: Vector2=eat.get_global_rect().get_center()
	Touch.finger(self,at,true,152);Touch.finger(self,at,false,152)
	Touch.finger(self,at,false,152);Touch.finger(self,at,false,152)
	await frames(3)
	check(Inventory.count("carrot")==19 and GameState.stamina==18,"同次有效触点多次释放只扣一份食物并恢复一次")
	var more:=true
	for i in range(4):
		var current:=find_button(panel,"吃1个\n+8体力")
		await touch_button(current,160+i)
		more=more and Inventory.count("carrot")==18-i and GameState.stamina==26+8*i
	check(more,"四次独立快速食用按份结算，保留食物不按日限额的新规则")
	GameState.stamina=99;var count: int=Inventory.count("carrot")
	await touch_button(find_button(panel,"吃1个\n+8体力"))
	check(GameState.stamina==100 and Inventory.count("carrot")==count-1,"不足一份恢复也只扣一份且体力不超过上限")
	var before:=stamp();await touch_button(find_button(panel,"吃1个\n+8体力"))
	check(stamp()==before,"满体力再次食用不消耗物品")
	GameState.stamina=20
	var old:=find_button(panel,"吃1个\n+8体力")
	panel.close_panel();before=stamp()
	if is_instance_valid(old): old.pressed.emit()
	await frames(2)
	check(stamp()==before,"背包关闭后旧按钮回调不继续食用")
	panel.open_panel(false);await frames(4)
	var carrot:=find_button(panel,"吃1个\n+8体力")
	await reveal(carrot)
	before=stamp()
	if carrot:
		var a: Vector2=carrot.get_global_rect().get_center()
		Touch.finger(self,a,true,170);Touch.finger(self,a,true,171)
		Touch.finger(self,a,false,171);Touch.finger(self,a,false,170);await frames(3)
	check(GameState.stamina==int(before.stamina)+8 and Inventory.count("carrot")==int(before.items.carrot)-1,"同按钮只认主触点，两手指释放不会重复消费同次点击")
	var held:=find_button(panel,"吃1个\n+8体力");await reveal(held)
	before=stamp()
	if held:
		var a: Vector2=held.get_global_rect().get_center();Touch.finger(self,a,true,172)
		await frames(45)
		check(stamp()==before,"持续按住食用按钮不循环消费或反复恢复")
		Touch.finger(self,a,false,172);await frames(2)
		check(GameState.stamina==int(before.stamina)+8 and Inventory.count("carrot")==int(before.items.carrot)-1,"长按释放至多完成一次合法消费")
	panel.close_panel()

func selection_and_tabs() -> void:
	await fresh();panel.open_panel(false);await frames(4)
	check(panel.has_method("select_item"),"背包存在独立的只读选择入口")
	if not panel.has_method("select_item"): return
	var before:=stamp();panel.select_item("carrot_seed");await frames(2)
	check(panel.selected_item=="carrot_seed" and stamp()==before,"选择种子只查看，不装备或消耗")
	check(panel.selected_detail.text.contains(Catalog.item_name("carrot_seed")) and panel.selected_detail.text.contains("8"),"选择详情显示对应物品名称和实际数量")
	panel.select_item("carrot");await frames(2)
	check(panel.selected_item=="carrot" and panel.selected_detail.text.contains(Catalog.item_name("carrot")) and stamp()==before,"切换到收获物品立即更新详情，不消费食物")
	panel.select_item("invented_item");await frames(2)
	check(panel.selected_item!="invented_item" and stamp()==before,"未知物品不能成为有效使用目标")
	for caption in ["材料与矿物","鱼苗与湖鲜","生活与料理","种子与收获"]:
		await touch_button(find_button(panel,caption))
		check(stamp()==before,"切换原分类只重排显示，不改变物品总数："+caption)
	await touch_button(find_button(panel,"鱼苗与湖鲜"));panel.select_item("fish_feed");await frames(2)
	check(panel.selected_item=="fish_feed" and stamp()==before,"鱼饲料只查看照料用途，不从背包凭空投喂或扣除")
	await touch_button(find_button(panel,"生活与料理"));panel.select_item("fishing_bait");await frames(2)
	check(panel.selected_item=="fishing_bait" and stamp()==before,"鱼饵只查看钓鱼用途，不从背包直接抛竿或消耗")
	await touch_button(find_button(panel,"种子与收获"))
	panel.select_item("carrot");var count: int=Inventory.count("carrot")
	Inventory.remove("carrot",1);await frames(3)
	check(panel.selected_item=="carrot" and panel.selected_detail.text.contains(str(count-1)),"选中物品数量减少后详情即时同步")
	Inventory.remove("carrot",Inventory.count("carrot"));await frames(3)
	check(Inventory.count("carrot")==0 and not Inventory.items.has("carrot"),"数量为零按原规则删除库存键")
	check(panel.selected_item in ["","carrot"] and not panel.selected_detail.text.contains("-1"),"耗尽物品详情不显示负数量或悬空对象")
	var empty_food:=find_button(panel,"吃1个\n+8体力");before=stamp()
	await touch_button(empty_food)
	check(stamp()==before,"数量为零时原食用入口不能凭空恢复体力或变成负库存")
	before=stamp();panel.refresh();await frames(2)
	check(stamp()==before,"当前工程没有拆分拖拽玩法，重排刷新仍保持全部物品守恒")
	panel.close_panel();await frames(2)
	check(str(panel.selected_item)=="" and panel.pending_sale.is_empty(),"关闭背包清理临时选中和悬浮确认状态")

func quantity_and_capacity() -> void:
	await fresh()
	Inventory.items.wood=998;Inventory.items.stone=7
	check(Inventory.add("wood",1) and Inventory.count("wood")==999,"同ID堆叠仍以原999上限增加")
	var before:=stamp()
	check(not Inventory.add("wood",1) and stamp()==before,"达到999后拒绝溢出，不覆盖原堆叠")
	check(Inventory.add("stone",2) and Inventory.count("stone")==9 and Inventory.count("wood")==999,"不同ID独立堆叠，不错误合并材料")
	check(Inventory.remove("stone",9) and not Inventory.items.has("stone"),"用完一类物品后只删除其自身键")
	Inventory.items.carrot=999
	game.farm.plots={"20,18":{"crop":"carrot","days":Catalog.crops.carrot.growth_days,"watered":true}}
	before=stamp();notices.clear()
	check(not game.farm.use_tool(Vector2i(20,18),"hand") and stamp()==before,"背包同种作物满堆时收获失败保留成熟作物和体力")
	check(not notices.is_empty() and notices[-1].contains("满"),"背包已满有明确提示")
	Inventory.items.carrot=998
	check(game.farm.use_tool(Vector2i(20,18),"hand") and Inventory.count("carrot")==999 and game.farm.plots["20,18"].crop=="","腾出一格后原收获可正常入包一次")
	before=stamp()
	check(not game.farm.use_tool(Vector2i(20,18),"hand") and stamp()==before,"收获完成后重复领取不会复制物品")

func hotbar_and_farming() -> void:
	await fresh()
	check(game.hud.tool_buttons.size()==9 and GameState.tools[8]=="fishing_rod","保留原八工具及已存在第九格鱼竿，不删除既有操作")
	var at: Vector2=game.player.position;var diamonds: int=Xiaojing.state.diamonds
	var correct:=true
	for i in range(18):
		var index: int=i%9
		await touch_button(game.hud.tool_buttons[index],180+i)
		correct=correct and GameState.selected==index and game.player.position==at and game.auto_move.target.is_empty()
	check(correct,"连续18次原生快捷栏切换准确且不穿透地图")
	Inventory.remove("carrot_seed",2);await frames(3)
	check(game.hud.tool_buttons[3].text.contains("6"),"背包数量减少后快捷栏种子数量同步")
	Inventory.items.erase("carrot_seed");Inventory.changed.emit();await frames(3)
	check(game.hud.tool_buttons[3].text.contains("0"),"工具栏保留耗尽种子明确零数量")
	GameState.select_tool(3);GameState.stamina=100
	await Touch.place(self,game,"farm",Vector2(624,592))
	game.farm.plots={"20,18":{"crop":"","days":0,"watered":false}}
	var before:=stamp();Touch.tap(self,game,Vector2(656,592));await Touch.finish(self,game)
	check(stamp()==before and game.farm.plots["20,18"].crop=="","耗尽种子不能经快捷栏触发空播或扣体力")
	Inventory.items.carrot_seed=2;Inventory.changed.emit();GameState.select_tool(3)
	Touch.tap(self,game,Vector2(656,592));await Touch.finish(self,game)
	check(Inventory.count("carrot_seed")==1 and game.farm.plots["20,18"].crop=="carrot" and game.hud.tool_buttons[3].text.contains("1"),"快捷栏选择与任务02生效帧播种一致，种子只扣一份")
	check(Xiaojing.state.diamonds==diamonds,"快捷栏、查看和农活不修改1314婚礼钻石资源")

func lifecycle() -> void:
	await fresh()
	for mode in ["tap","joystick"]:
		GameState.set_control_mode(mode,false)
		panel.open_panel(false);await frames(3)
		var at: Vector2=game.player.position;var before:=stamp()
		Touch.tap(self,game,Vector2(656,592));await frames(3)
		check(game.player.position==at and game.auto_move.target.is_empty() and stamp()==before,"背包模态期间不误触农田或地图："+mode)
		panel.close_panel();await frames(2)
		check(GameState.control_mode==mode and not GameState.modal and game.hud.joystick.visible==(mode=="joystick"),"关闭背包恢复原操作方式："+mode)
	panel.open_panel(false);await frames(3)
	var old:=find_button(panel,"吃1个\n+8体力")
	var before:=stamp();game.change_location("home");await frames(3)
	if is_instance_valid(old): old.pressed.emit()
	await frames(2)
	check(stamp()==before,"场景变化后旧背包按钮不能重复产生消费效果")
	while game.hud.close_active_panel(): pass
