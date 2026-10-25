extends PanelContainer
var content: VBoxContainer
var context: String="kitchen"
var page: String="recipes"
var quantity: int=1
var pending := Callable()
var message: String=""
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("炉火与麦香 · 小屋厨房",24,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var tabs := HBoxContainer.new();column.add_child(tabs)
	for row in [["recipes","料理与图鉴"],["processing","加工设备"],["queue","领取成品"]]:
		var id: String=row[0]
		tabs.add_child(FarmUIStyle.button(row[1],func():
			if not pending.is_valid(): page=id;refresh()
		,200))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
func words(text: String, size: int=18) -> void:
	var label := FarmUIStyle.label(text,size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(label)
func button(text: String, callback: Callable) -> Button:
	var b := FarmUIStyle.button(text,callback,180);content.add_child(b);return b
func open_panel(id: String="kitchen") -> void:
	if GameState.modal or (not Kitchen.near_berry() if id=="berry" else not Kitchen.near_kitchen()): return
	context=id;page="recipes";quantity=1;pending=Callable();message=""
	GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();message="";DiamondPayments.cancel(self);hide();GameState.set_modal(false)
func ask(text: String, callback: Callable) -> void:
	if pending.is_valid(): return
	message=text;pending=callback;refresh()
func accept() -> void:
	var callback := pending;pending=Callable()
	if visible and callback.is_valid(): callback.call()
	refresh()
func result(ok: bool) -> void:
	if not ok: Events.notice.emit("地点、材料、设施、每日额度或背包空间不满足；进度已保留。")
	refresh()
func cost(items: Dictionary) -> String:
	var text: Array[String]=[]
	for id in items: text.append("%s%d（持有%d）" % [Catalog.item_name(id),int(items[id]),Inventory.count(id)])
	return "、".join(text)
func refresh() -> void:
	if not visible: return
	for node in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(node): node.disabled=pending.is_valid()
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认本次操作",23);words(message);button("确认",accept);button("取消",func(): pending=Callable();refresh());return
	if context=="berry":
		words("屋西的野莓丛",23)
		words("夏天多汁，冬天仍有藏在叶下的果实。每天可采一次，春夏秋两份、冬季一份；采摘消耗2体力。可以带回厨房熬酱。")
		button("采摘今天的野莓",func(): result(Kitchen.harvest_berries())).disabled=Kitchen.state.berry_day==GameClock.day
		return
	words("第%d天 · %d金 · 钻石%d · 体力%d/%d" % [GameClock.day,Inventory.coins,Xiaojing.state.diamonds,GameState.stamina,GameState.max_stamina()],16)
	if Kitchen.state.buff.id!="": words("当前增益：%s · 剩余%.0f秒有效游戏时间" % [{"speed":"移动+15%","thrift":"体力消耗75%（至少1）","mining":"采矿伤害+1","fishing":"钓鱼带宽+0.03"}[Kitchen.state.buff.id],Kitchen.state.buff.remaining],16)
	words("持有料理且体力未满时可以继续吃，每次消耗1份；满体力不消耗。已有增益不叠加、不覆盖或延长，菜单和后台暂停计时。",16)
	var row := HBoxContainer.new();content.add_child(row)
	row.add_child(FarmUIStyle.label("批数：%d" % quantity,20,FarmUIStyle.TEXT))
	row.add_child(FarmUIStyle.button("−",func(): quantity=maxi(1,quantity-1);refresh(),52));row.add_child(FarmUIStyle.button("+",func(): quantity=mini(8,quantity+1);refresh(),52))
	match page:
		"processing": processing()
		"queue": jobs()
		_: recipes()
func recipes() -> void:
	for id in Kitchen.data.recipes:
		var recipe: Dictionary=Kitchen.data.recipes[id]
		words(recipe.name+" · "+("已掌握" if Kitchen.recipe_unlocked(id) else "尚待领会"),21)
		words(recipe.hint+"\n每批："+cost(recipe.required)+"\n"+Kitchen.data.items[id].description,16)
		words("已做%d份 · 背包%d份" % [int(Kitchen.state.cooked.get(id,0)),Inventory.count(id)],16)
		var amount := quantity
		button("制作%s ×%d" % [recipe.name,amount],func(): ask("制作%d批%s，消耗：%s？" % [amount,recipe.name,cost(Kitchen.scaled(recipe.required,amount))],func(): result(Kitchen.cook(id,amount)))).disabled=not Kitchen.recipe_unlocked(id)
		button("食用一份"+recipe.name,func(): result(Kitchen.consume(id))).disabled=Inventory.count(id)<1
	words("原湖岸鱼汤、鱼干继续使用原配方和物品；厨房不会复制另一个同名物品。",16)
func processing() -> void:
	words("设备可同时保留四笔加工，每笔最多八批。材料下单时扣一次，次日或两日后领取；背包满则保留成品。")
	for id in Kitchen.data.facilities:
		var facility: Dictionary=Kitchen.data.facilities[id]
		words(facility.name+" · "+("已建成" if id in Kitchen.state.built else "待建"),21)
		words(facility.description,16)
		if id not in Kitchen.state.built:
			words(cost(facility.required)+" · "+DiamondPayments.text(int(facility.coins)),16)
			button("建造"+facility.name,func(): ask("建造"+facility.name+"，消耗"+cost(facility.required)+"与"+DiamondPayments.text(int(facility.coins))+"？",func(): DiamondPayments.request(self,int(facility.coins),func(): result(Kitchen.build(id)))))
		else:
			for recipe_id in Kitchen.data.processing:
				var recipe: Dictionary=Kitchen.data.processing[recipe_id]
				if recipe.facility!=id: continue
				var amount := quantity
				words("每批："+cost(recipe.required)+" · %d日后完成" % recipe.days,16)
				button("开始%s ×%d" % [recipe.name,amount],func(): ask("加工%d批，消耗%s；第%d天后领取？" % [amount,cost(Kitchen.scaled(recipe.required,amount)),GameClock.day+int(recipe.days)],func(): result(Kitchen.enqueue(recipe_id,amount))))
func jobs() -> void:
	if Kitchen.state.queue.is_empty(): words("加工设备里还没有待领取订单。")
	for job in Kitchen.state.queue:
		words("#%d %s ×%d · %s" % [job.id,Kitchen.data.processing[job.recipe].name,job.batches,"已完成" if job.ready else "第%d天完成" % job.ready_day],20)
		var serial: int=job.id
		button("领取这一笔成品",func(): result(Kitchen.claim_job(serial))).disabled=not job.ready
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
