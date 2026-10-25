extends PanelContainer
var context: String = "spring"
var content: VBoxContainer
var page: String = "activity"
var pending := Callable()
var question: String = ""
var exhibit: Dictionary = {}
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("河湾四季节庆",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var tabs := HBoxContainer.new();column.add_child(tabs)
	for entry in [["activity","参加活动"],["shop","节日摊位"],["history","四季记录"]]:
		var target: String=entry[0]
		tabs.add_child(FarmUIStyle.button(entry[1],func():
			if not pending.is_valid(): page=target;refresh()
		,220))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12);scroll.add_child(content)
func words(text: String, size: int = 18) -> void:
	var label := FarmUIStyle.label(text,size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(label)
func button(text: String, callback: Callable) -> Button:
	var control := FarmUIStyle.button(text,callback,180);content.add_child(control);return control
func open_panel(id: String = "spring") -> void:
	if GameState.modal or not Festival.near_board(id): return
	context=id;page="activity";pending=Callable();exhibit={}
	GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();question="";DiamondPayments.cancel(self);hide();GameState.set_modal(false)
func ask(text: String, callback: Callable) -> void:
	if pending.is_valid(): return
	question=text;pending=callback;refresh()
func accept() -> void:
	var callback := pending;pending=Callable();question=""
	if visible and Festival.near_board(context) and callback.is_valid(): callback.call()
	refresh()
func outcome(ok: bool) -> void:
	if not ok: Events.notice.emit("时间、现场条件或物品尚未满足；已完成的进度与材料仍保留。")
	refresh()
func refresh() -> void:
	if not visible: return
	for toggle in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(toggle): toggle.disabled=pending.is_valid()
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认这次操作",23);words(question,20)
		button("确认",accept);button("取消",func(): pending=Callable();question="";refresh());return
	var event: Dictionary=Festival.data.events[context]
	words(event.name+" · "+Calendar.label(),23)
	words("每年%s%d日 · %02d:%02d–%02d:%02d" % [Calendar.SEASON_NAMES[int(event.season)],event.season_day,int(event.opens)/60,int(event.opens)%60,int(event.closes)/60,int(event.closes)%60],16)
	for id in Festival.IDS:
		var run: Dictionary=Festival.run_for(id)
		if Festival.near_board(id) and not run.is_empty() and run.ready and not run.claimed:
			button("领取第%d年%s纪念" % [run.year,Festival.data.events[id].name],func(): outcome(Festival.claim(id)))
	match page:
		"shop": build_shop()
		"history": build_history()
		_: build_activity()
func build_activity() -> void:
	var event: Dictionary=Festival.data.events[context]
	words(event.title,21);words(event.description)
	words(Festival.progress(context),18)
	if not Festival.is_open(context):
		words("活动还未到开放时段。日历与睡眠照常进行；已完成的待领纪念可以之后在同处领取。",17)
		return
	var run: Dictionary=Festival.run_for(context)
	if not Festival.current_run(context):
		button("报名参加",func(): outcome(Festival.begin(context)))
		return
	if run.claimed: words("今年的活动已经收好。明年可以再次参加，不重复领取本年奖励。",17);return
	match context:
		"spring":
			words("赛事田在原农田的金色细框内。带至少两种种子，关闭面板后亲自播种、浇水；雨与既有引水设施照料也认可。",17)
			for cell in run.cells: words("预留格：%d,%d" % [cell[0],cell[1]],16)
			button("检查三格照料情况",func(): Festival.check_spring();refresh())
			button("重新选择三格空地",func(): ask("保留原作物与材料，不返还已用种子；重新预留三格空地再参加？",func(): outcome(Festival.restart_spring()))).disabled=run.ready
		"summer":
			words("先关闭面板到真实湖岸抛竿。钓鱼小游戏完成才算新钓获；失败、重复领取或读取旧鱼都不计。之后去村民身边用社交面板‘聊今天的节日’，再回这里。",17)
			if GameClock.minutes>=1200 and run.fish.size()>=2 and run.lantern=="":
				for choice in Festival.data.lanterns:
					button("点亮"+Festival.data.lanterns[choice].name,func(): outcome(Festival.watch_lantern(choice)))
			if not Festival.state.xiaojing_summer:
				button("与身边的小京一起看灯",func(): outcome(Festival.summer_xiaojing()))
				words("需要小京已解锁、好感50并真实在身边，两次湖泊钓获后20点点灯。首次共同观灯羁绊+1，后续年份只保留日常交流。",16)
		"autumn": build_exhibit()
		"winter":
			words("厨房基础暖锅：胡萝卜2、土豆1 → 暖锅蔬菜炖1。必须报名之后实际烹制；库存旧料理不计新做额度。到三位村民身边，通过社交面板送达。",17)
			for person in ["linya","zhou","ahe"]: words(("✓ " if person in run.delivered else "○ ")+Story.data.people[person].name,17)
func build_exhibit() -> void:
	var run: Dictionary=Festival.run_for("autumn")
	if run.ready:
		words("展篮评分%d。组合以实际本季新产、种类和份数计算，不为物品虚构品质。" % run.score,20);return
	words("本季生产记录从更新或本季第一笔真实产出开始；旧库存不补记。选3至6份，至少两类，每种最多2份。三类齐全评分更高，提交会实际消耗。",16)
	if Festival.state.production.season!=Calendar.season_serial(): words("本季还没有实际生产记录。先种植、养鱼、钓鱼或照料动物，再带新产物回来。");return
	for item in Festival.state.production.items:
		var available: int=mini(2,mini(Inventory.count(item),int(Festival.state.production.items[item])))
		if available<1: continue
		var chosen: int=int(exhibit.get(item,0))
		var row := HBoxContainer.new();content.add_child(row)
		row.add_child(FarmUIStyle.label("%s · 新产%d · 库存%d · 选%d" % [Catalog.item_name(item),Festival.state.production.items[item],Inventory.count(item),chosen],18))
		row.add_child(FarmUIStyle.button("−",func():
			var value: int=maxi(0,int(exhibit.get(item,0))-1)
			if value==0: exhibit.erase(item)
			else: exhibit[item]=value
			refresh()
		,64))
		row.add_child(FarmUIStyle.button("+",func(): exhibit[item]=mini(available,int(exhibit.get(item,0))+1);refresh(),64))
	button("确认交付所选展篮",func():
		var selection := exhibit.duplicate(true)
		var names: Array[String]=[]
		for item in selection: names.append("%s%d" % [Catalog.item_name(item),int(selection[item])])
		ask("交付"+"、".join(names)+"进行一次评比？物品会消耗，本年展篮不能重复提交。",func(): outcome(Festival.submit_autumn(selection)))
	)
func build_shop() -> void:
	words("限定摊位 · %d金 / 钻石%d" % [Inventory.coins,Xiaojing.state.diamonds],20)
	words("每个年份、每个节日有各自限购。加工品和料理保留原设施/食谱前置，不用节日绕过解锁。",16)
	if not Festival.is_open(context): words("摊位尚未开门或已经收摊。");return
	for offer in Festival.data.shops[context]:
		var item: String=offer.item
		var held: int=int(Festival.state.purchases.get(Festival.key(context),{}).get(item,0))
		words("%s · %s / 个 · 本年剩余%d" % [Catalog.item_name(item),DiamondPayments.text(int(offer.price)),int(offer.limit)-held],18)
		var cost: int=offer.price
		button("购买1个",func(): ask("购买"+Catalog.item_name(item)+"，花费"+DiamondPayments.text(cost)+"？",func(): DiamondPayments.request(self,cost,func(): outcome(Festival.shop(item,1))))).disabled=held>=int(offer.limit) or not Festival.shop_unlocked(offer)
func build_history() -> void:
	for id in Festival.IDS:
		var event: Dictionary=Festival.data.events[id]
		words(event.name+" · "+Festival.progress(id),20)
		words("每年"+Calendar.SEASON_NAMES[int(event.season)]+"24日 · "+event.title,16)
	words("已保存的年度纪念："+str(Festival.state.claims.size())+"份。奖励不产生钻石，不替代小京原有解锁、三属性、记忆、试炼、温室或婚礼条件。",16)
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
