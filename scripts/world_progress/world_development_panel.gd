extends PanelContainer
var section: VBoxContainer
var content: VBoxContainer
var context: String = "board"
var pending := Callable()
var question: String = ""
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("河湾长期共建 · 岸边与归路",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12);scroll.add_child(content)
	FacilityLayout.decorate(self,"development","从一盏归路灯，到岸边的一张交货单。")

func open_panel(id: String = "board") -> void:
	if GameState.modal or id not in ["board","dock","community"] or not WorldDevelopment.near(id): return
	context=id;pending=Callable();question="";GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();question="";DiamondPayments.cancel(self);hide();GameState.set_modal(false)
func words(text: String, size: int = 18) -> void:
	FacilityLayout.text(section if is_instance_valid(section) else content,text,size)
func button(text: String, callback: Callable) -> Button:
	var control := FarmUIStyle.button(text,callback,180);(section if is_instance_valid(section) else content).add_child(control);return control
func outcome(ok: bool) -> void:
	if not ok: Events.notice.emit("现场条件、资源、新产记录或间隔还未满足；本次没有追加扣费。")
	refresh()
func ask(text: String, callback: Callable) -> void:
	if pending.is_valid(): return
	question=text;pending=callback;refresh()
func accept() -> void:
	var callback := pending;pending=Callable();question=""
	if visible and WorldDevelopment.near(context) and callback.is_valid(): callback.call()
	refresh()
func cost_text(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for item in required: parts.append("%s%d（持有%d）" % [Catalog.item_name(item),int(required[item]),Inventory.count(item)])
	return "、".join(parts)
func refresh() -> void:
	section=null
	if not visible: return
	for toggle in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(toggle): toggle.disabled=pending.is_valid()
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认这次交接",23);words(question,20)
		button("确认",accept);button("取消",func(): pending=Callable();question="";refresh());return
	words(Calendar.label()+" · %d金 / 钻石%d" % [Inventory.coins,Xiaojing.state.diamonds],16)
	words(WorldDevelopment.branch_line(),19)
	match context:
		"dock": build_trade()
		"community": build_community()
		_: build_projects()
func build_projects() -> void:
	words("两个方向都可以长期推进",22)
	if Story.stage!=8 or not VillageProjects.all_built():
		words("先完成河水带走的名字，并保留水井、共仓和茶座。新工程会接在大家已经建成的生活上。")
		return
	var grid:=FarmUIStyle.section_grid(content)
	for id in WorldDevelopment.TYPES:
		section=FarmUIStyle.section(grid)
		var level: int=WorldDevelopment.state[id]
		words(("东岸码头" if id=="dock" else "社区归路")+" · 已建%d/2阶段" % level,22)
		if level<2:
			var definition: Dictionary=WorldDevelopment.data.buildings[id][str(level+1)]
			words(definition.name+"\n"+definition.description)
			words(cost_text(definition.required)+"、"+DiamondPayments.text(int(definition.coins)),16)
			if level==1: words("先实际完成一次贸易交货。" if id=="dock" else "先实走三盏灯并完成一次傍晚值日交接。",16)
			button("建设"+definition.name,func(): ask("保留已有设施，消耗"+cost_text(definition.required)+"与"+DiamondPayments.text(int(definition.coins))+"建设？",func(): DiamondPayments.request(self,int(definition.coins),func(): outcome(WorldDevelopment.build(id,level)))) )
		if WorldDevelopment.state.parcels.has(id):
			words("首次建设补给已保留："+cost_text(WorldDevelopment.state.parcels[id].items),16)
			button("领取建设补给",func(): outcome(WorldDevelopment.claim_parcel(id)))
	section=null
	words("施工在这块牌前办理。贸易：河东岸976,720；值日：广场南侧672,720。都走原地图真实道路，不改变河流与旧桥通行规则。",16)
func build_trade() -> void:
	words("农渔货物装卸",22)
	if WorldDevelopment.state.dock<1: words("先到村庄发展牌建装卸码头。");return
	words("订单先登记，再实际生产本轮所需物品；最后带实物回码头交货。旧库存、读档和重复信号不替代新产证明。完成订单间隔三游戏日。",16)
	if WorldDevelopment.state.order.is_empty():
		var recommended: String=WorldDevelopment.data.branches[WorldDevelopment.branch_id()].recommended
		for id in WorldDevelopment.data.orders:
			var order: Dictionary=WorldDevelopment.data.orders[id]
			words(("推荐 · " if id==recommended else "")+order.name+" · 需要码头%d级" % order.level,20)
			words(order.description,17);words(cost_text(order.required)+"\n报酬%d金，另有发展方向小补给。" % order.coins,16)
			button("登记这张订单",func(): outcome(WorldDevelopment.accept_order(id))).disabled=not WorldDevelopment.order_unlocked(id)
	else:
		var active: Dictionary=WorldDevelopment.state.order
		var order: Dictionary=WorldDevelopment.data.orders[active.id]
		words(order.name,21)
		for item in order.required: words("%s · 本轮新产%d/%d · 库存%d" % [Catalog.item_name(item),int(active.credit.get(item,0)),int(order.required[item]),Inventory.count(item)],18)
		var reward: Dictionary=WorldDevelopment.trade_reward()
		words("本次报酬%d金；上次交货第%d天。" % [reward.coins,WorldDevelopment.state.trade_day],16)
		if not reward.items.is_empty(): words("补给："+cost_text(reward.items),16)
		button("核对实物并交货",func(): ask("实际交付"+cost_text(order.required)+"并领取所列报酬？",func(): outcome(WorldDevelopment.use_trade(active.id))))
		button("撤下订单，保留所有物品",func(): ask("取消本轮订单？已有物品不扣除，新产证明在下次接单时重新记录。",func(): outcome(WorldDevelopment.cancel_order())))
func build_community() -> void:
	words("归路灯与共餐桌",22)
	if WorldDevelopment.state.community<1: words("先到发展牌修三盏归路灯。");return
	words("18:00–22:00亲自走到三盏灯旁检查，每盏每天一次、各耗1体力。检查后回这里交接。巡灯与共餐共用每天一份额度。",17)
	for id in WorldDevelopment.LAMPS:
		var at: Array=WorldDevelopment.data.lamps[id]
		words(("✓ " if WorldDevelopment.state.lamps[id]==GameClock.day else "○ ")+{"west":"西侧归路灯","square":"广场北灯","river":"河岸灯"}[id]+" · %d,%d" % [at[0],at[1]],17)
	var entry: Dictionary=WorldDevelopment.data.community.lamps
	words(entry.name+" · "+cost_text(entry.required)+" · 回礼%d金与鱼饵1" % entry.coins,17)
	button("交接今日巡灯",func(): ask("交付所列材料并登记今日值日？当天只能交接一次。",func(): outcome(WorldDevelopment.daily_community("lamps"))))
	if WorldDevelopment.state.community>=2:
		var supper: Dictionary=WorldDevelopment.data.community.supper
		words("每周第六天18:00–22:00 · 共餐雨棚",22)
		words(supper.description,17);words(cost_text(supper.required)+" · 回礼%d金、胡萝卜种子2" % supper.coins,16)
		words("此刻桌旁村民%d位。若他们还在路上，先收起面板让大家走来，再回桌边。" % WorldDevelopment.gathered_people(),16)
		button("与桌旁村民交接共餐",func(): ask("交付晚餐并登记本周共餐？与今天巡灯共用日限。",func(): outcome(WorldDevelopment.daily_community("supper"))))
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
