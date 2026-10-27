extends "res://tests/runner.gd"
## 真实商店面板及原交易事务：不改物品售价、堆叠或存档字段。
const Touch=preload("res://tests/touch_navigation.gd")
var panel: PanelContainer
var initial: Dictionary
var trade_signals: int=0
var window_test: bool=false

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	panel=game.hud.inventory_panel;initial=FarmSaveStore.snapshot(game)
	Inventory.changed.connect(func(): trade_signals+=1)
	window_test=window_test or "--window" in OS.get_cmdline_user_args()
	if window_test: await window_checks()
	else: await state_checks()
	print("SALE QUANTITY %s RESULT: %d checks, %d failures" % ["WINDOW" if window_test else "STATE",checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh() -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Inventory.items={"carrot":20,"carrot_seed":8,"wood":25,"fish_crucian":12,"milk":15};Inventory.coins=1000;Xiaojing.state.diamonds=1400
	await Touch.place(self,game,"farm",Vector2(656,480));trade_signals=0

func stamp() -> Dictionary:
	return {"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina,"plants":Xiaojing.state.plants}

func buttons(root: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(buttons(child))
	return result

func button_for(action: String, item: String="") -> Button:
	for control in buttons(panel):
		if control.get_meta("action_kind","")==action and (item=="" or control.get_meta("inventory_action","")==item): return control
	return null

func preset(amount: String) -> Button:
	for control in buttons(panel):
		if control.get_meta("sale_control","")==amount: return control
	return null

func state_checks() -> void:
	await fresh();panel.open_panel(true);await frames(3)
	check(button_for("sell","carrot")!=null and button_for("sell_quantity","carrot")!=null,"作物同时保留出售全部与按数量出售入口")
	var before:=stamp();panel.request_sale_quantity("carrot")
	check(int(panel.pending_sale.amount)==1 and stamp()==before,"按数量入口默认一件，查看确认不扣物品")
	check(panel.sale_detail.text.contains("持有20个") and panel.sale_detail.text.contains("单价") and panel.sale_detail.text.contains("保留19个"),"出售页列出持有、单价、选定数量、总金额和保留数量")
	check(not panel.footer.visible and not panel.payment_control.visible,"出售确认期间隐藏无关的购买数量和支付方式")
	var stale: int=int(panel.pending_sale.token);var old_confirm:=button_for("sale_confirm")
	panel.set_sale_quantity(5)
	check(int(panel.pending_sale.amount)==5 and int(panel.pending_sale.total)==5*Catalog.sell_price("carrot") and stamp()==before,"选择五件只更新展示，金额采用原单价")
	panel.confirm_sale(stale)
	if is_instance_valid(old_confirm): old_confirm.pressed.emit()
	check(stamp()==before,"修改数量后旧确认token与旧按钮均不能卖出")
	var token: int=int(panel.pending_sale.token);panel.confirm_sale(token);panel.confirm_sale(token)
	check(Inventory.count("carrot")==15 and Inventory.coins==int(before.coins)+5*Catalog.sell_price("carrot"),"确认卖五件只扣五件且只结算一次")
	check(trade_signals==1 and Xiaojing.state.diamonds==1400 and Xiaojing.state.plants==before.plants,"单次出售只发一次库存变化，不改钻石和成功播种次数")
	check(panel.pending_sale.is_empty() and panel.footer.visible,"完成出售清理临时确认并恢复购买控件")
	panel.request_sale_quantity("carrot");panel.set_sale_quantity(10);panel.change_sale_quantity(-1)
	check(int(panel.pending_sale.amount)==9,"减一按钮支持九件等任意中间数量")
	panel.change_sale_quantity(1);check(int(panel.pending_sale.amount)==10,"加一按钮准确恢复十件")
	panel.set_sale_quantity(0);panel.change_sale_quantity(-10)
	check(int(panel.pending_sale.amount)==1 and preset("minus").disabled,"数量下限为一且不能减成负数或零")
	panel.set_sale_quantity(999999)
	check(int(panel.pending_sale.amount)==15 and preset("plus").disabled,"数量上限为当前持有，不能超卖")
	before=stamp();panel.cancel_sale();check(stamp()==before and panel.pending_sale.is_empty(),"取消自选数量出售保留所有资源")
	panel.request_sale("carrot");check(int(panel.pending_sale.amount)==15,"原出售全部入口仍选择全部当前库存")
	Inventory.add("carrot",2)
	check(int(panel.pending_sale.amount)==15,"确认期间新增物品不擅自增加已选出售数量")
	panel.cancel_sale();panel.request_sale_quantity("carrot");panel.set_sale_quantity(10)
	token=int(panel.pending_sale.token);Inventory.remove("carrot",12);before=stamp()
	check(button_for("sale_confirm").disabled and panel.sale_detail.text.contains("库存已变化"),"库存减少不足时清楚提示且禁用确认")
	panel.confirm_sale(token);check(stamp()==before,"库存变少后迟到确认不产生金币或额外扣物")
	panel.set_sale_quantity(1);token=int(panel.pending_sale.token);panel.confirm_sale(token)
	check(Inventory.count("carrot")==4 and Inventory.coins==int(before.coins)+Catalog.sell_price("carrot"),"库存变化后重新选择合法数量可正常成交")
	for pair in [[1,"wood"],[2,"fish_crucian"],[3,"milk"]]:
		panel.change_category(pair[0]);await frames(2)
		var id: String=pair[1];check(button_for("sell_quantity",id)!=null,"材料、鱼类和生活物品都有数量出售入口："+id)
		var held: int=Inventory.count(id);var money: int=Inventory.coins
		panel.request_sale_quantity(id);panel.set_sale_quantity(3);panel.confirm_sale(int(panel.pending_sale.token))
		check(Inventory.count(id)==held-3 and Inventory.coins==money+3*Catalog.sell_price(id),"各类别按实际ID和原价售出三件："+id)
	panel.change_category(0);Inventory.items.carrot=Inventory.MAX_STACK
	panel.request_sale_quantity("carrot");panel.select_sale_all()
	check(int(panel.pending_sale.amount)==Inventory.MAX_STACK,"全部快捷选择支持原999堆叠上限")
	token=int(panel.pending_sale.token);before=stamp();panel.close_panel();panel.confirm_sale(token)
	check(stamp()==before and panel.pending_sale.is_empty(),"关闭后迟到确认无效")
	panel.open_panel(true);panel.request_sale_quantity("carrot");token=int(panel.pending_sale.token);panel.change_category(1);before=stamp();panel.confirm_sale(token)
	check(stamp()==before and panel.pending_sale.is_empty(),"切换分类取消旧出售意图")
	panel.request_sale_quantity("wood");token=int(panel.pending_sale.token);game.change_location("home",Vector2(640,500));await frames(3);before=stamp();panel.confirm_sale(token)
	check(not panel.visible and panel.pending_sale.is_empty() and stamp()==before,"切换场景清理出售确认且不重复领取金币")
	panel.open_panel(false);before=stamp();panel.request_sale_quantity("wood")
	check(panel.pending_sale.is_empty() and stamp()==before,"背包查看模式不能误出售")
	panel.close_panel();panel.open_panel(true);before=stamp();panel.request_sale_quantity("not_an_item");panel.request_sale_quantity("potato")
	check(panel.pending_sale.is_empty() and stamp()==before,"无效ID和零库存不进入出售确认")
	panel.request_sale_quantity("wood");panel.set_sale_quantity(5);token=int(panel.pending_sale.token);Inventory.coins=Inventory.MAX_COINS;before=stamp();panel.confirm_sale(token)
	check(stamp()==before,"金币到上限整笔出售失败，物品仍保留")
	Inventory.coins=1000;panel.request_sale_quantity("wood");before=stamp();GameState.restoring=true;panel.confirm_sale(int(panel.pending_sale.token));panel.set_sale_quantity(8);GameState.restoring=false
	check(stamp()==before and int(panel.pending_sale.amount)==1,"读取存档期间不能出售或调整旧出售任务")
	panel.cancel_sale();var snapshot:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(snapshot) and not snapshot.has("pending_sale") and not snapshot.has("sale_quantity"),"出售数量和确认状态不新增持久化字段")
	check(FarmSaveStore.restore(game,snapshot) and Inventory.items==snapshot.items and Inventory.coins==int(snapshot.coins),"保存恢复后已卖数量和所得金币保持，不重放出售")

func tap(control: Button, index: int=340) -> void:
	if not is_instance_valid(control): check(false,"预期出售按钮存在");return
	if panel.scroll.is_ancestor_of(control): panel.scroll.ensure_control_visible(control)
	await frames(3)
	var at: Vector2=control.get_global_rect().get_center()
	Touch.finger(self,at,true,index);Touch.finger(self,at,false,index);await frames(3)

func window_checks() -> void:
	await fresh()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=dimensions;await frames(5);game.hud.update_safe_area();await frames(4)
		Inventory.items.carrot=20;Inventory.changed.emit();panel.open_panel(true);await frames(4)
		var before:=stamp();var at: Vector2=game.player.global_position;var executions: int=game.auto_move.execution_count
		await tap(button_for("sell_quantity","carrot"))
		check(not panel.pending_sale.is_empty() and int(panel.pending_sale.amount)==1 and stamp()==before,"原生触控打开数量出售且不扣物："+str(dimensions))
		await tap(preset("5"));await tap(preset("plus"));await tap(preset("minus"))
		check(int(panel.pending_sale.amount)==5 and stamp()==before,"原生5个与加减按钮准确选择五件："+str(dimensions))
		var all_visible:=true
		for control in buttons(panel):
			if panel.scroll.is_ancestor_of(control): panel.scroll.ensure_control_visible(control)
			await frames(2)
			all_visible=all_visible and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect()) and control.contains_touch(control.get_global_rect().get_center()) and control.size.x>=UIMetrics.minimum_target() and control.size.y>=UIMetrics.minimum_target()
		check(all_visible,"数量页按钮在安全区内可滚入且保持触控下限："+str(dimensions))
		check(game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),"出售面板完整位于横屏安全区："+str(dimensions))
		await tap(button_for("sale_confirm"));Touch.finger(self,Vector2.ZERO,false,340);await frames(3)
		check(Inventory.count("carrot")==15 and Inventory.coins==int(before.coins)+5*Catalog.sell_price("carrot"),"原生确认只卖五件并保留十五件："+str(dimensions))
		check(game.player.global_position==at and game.auto_move.execution_count==executions and game.auto_move.target.is_empty(),"出售点击不穿透到底层移动或农活："+str(dimensions))
		await tap(button_for("sell_quantity","carrot"));await tap(preset("10"));before=stamp()
		if dimensions==Vector2i(1280,720): await capture("sale-quantity-1280")
		await tap(button_for("sale_cancel"));check(stamp()==before,"原生数量选择后取消不结算："+str(dimensions))
		panel.close_panel();await frames(3)
		check(not GameState.modal,"关闭出售面板恢复地图操作："+str(dimensions))

func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://builds/"+name+".png")
