class_name DiamondPayments
extends RefCounted
## 选择货币只影响明确确认的一笔支出；任务/采矿奖励仍用原事务。
const GOLD_PER_DIAMOND: int = 100
const GOODS := {"wood":1,"stone":1,"copper_ore":1,"iron_ore":2,"crystal":3,"starlight_ore":8,"copper_bar":2,"iron_bar":4,"star_alloy":10,"ancient_shard":6,"star_fragment":10}
static var selected: bool = false
static func price(gold: int) -> int:
	return ceili(float(gold)/GOLD_PER_DIAMOND)
static func text(gold: int) -> String:
	return "%d 钻石" % price(gold) if selected else "%d 金" % gold
static func controls(column: Control, refresh: Callable) -> void:
	var toggle := FarmUIStyle.button("支付方式："+("钻石" if selected else "金币")+"（点击切换）",func(): selected=not selected; sync(); refresh.call(),240)
	toggle.add_to_group("payment_toggle")
	column.add_child(toggle)
static func sync() -> void:
	for node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("payment_toggle"):
		node.text="支付方式："+("钻石" if selected else "金币")+"（点击切换）"
static func preview(required: Dictionary, rewards: Dictionary, gold: int) -> Dictionary:
	var prior: bool=Inventory.diamond_payment
	Inventory.diamond_payment=selected
	var result: Dictionary=Inventory.preview_exchange(required,rewards,-gold)
	Inventory.diamond_payment=prior
	return result
static func perform(callback: Callable) -> void:
	var prior: bool=Inventory.diamond_payment
	Inventory.diamond_payment=selected
	callback.call()
	Inventory.diamond_payment=prior
static func request(panel: Control, gold: int, callback: Callable, force_diamond: bool = false) -> void:
	if not selected and not force_diamond:
		callback.call()
		return
	for child in panel.get_children():
		if child is ConfirmationDialog and child.visible: return
	var dialog := ConfirmationDialog.new()
	dialog.theme=FarmUIStyle.make_theme()
	var frame:=FarmUIStyle.surface("paper")
	frame.expand_margin_top=28
	dialog.theme.set_stylebox("embedded_border","Window",frame)
	dialog.theme.set_stylebox("panel","AcceptDialog",FarmUIStyle.surface("paper"))
	dialog.theme.set_color("title_color","Window",FarmUIStyle.TITLE)
	dialog.get_label().add_theme_color_override("font_color",FarmUIStyle.TEXT)
	dialog.get_ok_button().add_theme_stylebox_override("normal",FarmUIStyle.surface("danger"))
	dialog.get_cancel_button().add_theme_stylebox_override("normal",FarmUIStyle.surface("secondary"))
	dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().custom_minimum_size.x=600
	for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		button.set_script(preload("res://scripts/ui/touch_button.gd"))
	dialog.title="确认钻石支付"
	dialog.dialog_text="将花费%d颗钻石（当前%d）。材料与解锁条件仍需满足。\n婚礼需要持有1314颗；消费后不足时须继续收集。取消不会扣款。" % [price(gold),Xiaojing.state.diamonds]
	dialog.ok_button_text="确认支付"
	dialog.cancel_button_text="取消"
	var touch: float=maxf(52,UIMetrics.minimum_target())
	dialog.get_ok_button().custom_minimum_size=Vector2(touch,touch)
	dialog.get_cancel_button().custom_minimum_size=Vector2(touch,touch)
	panel.add_child(dialog)
	var currency: bool=true # 此次报价冻结为钻石，其他面板的选择不会改变它。
	dialog.confirmed.connect(func():
		if panel.is_visible_in_tree():
			var prior: bool=Inventory.diamond_payment
			Inventory.diamond_payment=currency
			callback.call()
			Inventory.diamond_payment=prior
		dialog.queue_free()
	,CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free,CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(680,250))
static func cancel(panel: Control) -> void:
	for child in panel.get_children():
		if child is ConfirmationDialog:
			child.hide()
			child.queue_free()
static func good_unlocked(id: String) -> bool:
	if id=="ancient_shard": return AbyssState.state.max_clear>=60
	if id=="star_fragment": return AbyssState.state.max_clear>=80
	if id in ["wood","stone"]: return true
	if id in ["copper_ore","copper_bar"]: return "mine_a" in MineState.state.unlocked
	if id in ["iron_ore","iron_bar","crystal"]: return "mine_b" in MineState.state.unlocked
	return MineState.diamond_access()
static func buy_good(id: String, quantity: int) -> bool:
	if not GOODS.has(id) or not good_unlocked(id) or quantity<1 or quantity>99 or not Inventory.diamond_payment: return false
	# 矿物商品只收钻石，不能用金币购买可精炼钻石的原料。
	if not Inventory.exchange({},{id:quantity},-int(GOODS[id])*quantity*GOLD_PER_DIAMOND):
		Events.notice.emit("钻石不足或背包已满，没有扣款。")
		return false
	Events.progress_committed.emit()
	return true

static func buy_crop(id: String, quantity: int) -> bool:
	if not Catalog.crops.has(id) or quantity<1 or quantity>99 or not Inventory.diamond_payment: return false
	var gold: int=Catalog.sell_price(id)*3*quantity
	if not Inventory.exchange({},{id:quantity},-gold):
		Events.notice.emit("钻石不足或背包已满，没有扣款。")
		return false
	Events.progress_committed.emit()
	return true
