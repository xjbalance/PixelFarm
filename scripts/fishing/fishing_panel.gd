extends PanelContainer
## 岸边抛竿、实操小游戏和供给。确认回调取出一次，关闭时收线。
var context: String = "farm_lake"
var page: String = "cast"
var content: VBoxContainer
var pending := Callable()
var question: String = ""
var hold: Control
var track: Control
var live_status: Label
var display_mode: String = ""
var navigation_buttons: Array[Button] = []
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("河湾垂钓 · 把鱼线交给手心",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收线离开 ×",close_panel,140))
	DiamondPayments.controls(column,refresh)
	var tabs := HBoxContainer.new();column.add_child(tabs)
	for entry in [["cast","抛竿与收获"],["gear","鱼竿与补给"],["book","垂钓图鉴"]]:
		var destination: String=entry[0]
		var tab := FarmUIStyle.button(entry[1],func():
			if not Fishing.active() and not pending.is_valid(): page=destination;refresh()
		,220)
		tabs.add_child(tab);navigation_buttons.append(tab)
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12);scroll.add_child(content)
	Fishing.changed.connect(refresh)
func open_panel(site_id: String = "farm_lake") -> void:
	if GameState.modal or not Fishing.near_site(site_id): return
	context=site_id;page="cast";pending=Callable();display_mode=""
	GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();question="";Fishing.cancel();DiamondPayments.cancel(self)
	if is_instance_valid(hold): hold.reset()
	hide();GameState.set_modal(false)
func words(text: String,size: int = 18) -> Label:
	var label := FarmUIStyle.label(text,size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(label);return label
func button(text: String,callback: Callable) -> Button:
	var control := FarmUIStyle.button(text,callback,180);content.add_child(control);return control
func feedback(ok: bool) -> void:
	if not ok: Events.notice.emit("条件、背包空间或材料尚未满足，没有追加扣费。")
	refresh()
func ask(text: String,callback: Callable) -> void:
	if pending.is_valid() or Fishing.active(): return
	question=text;pending=callback;refresh()
func accept() -> void:
	var callback := pending;pending=Callable();question=""
	if visible and Fishing.near_site(context) and callback.is_valid(): callback.call()
	refresh()
func refresh() -> void:
	if not visible: return
	var active: bool=Fishing.active()
	for control in navigation_buttons: control.disabled=active or pending.is_valid()
	for control in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(control): control.disabled=active or pending.is_valid()
	if active and display_mode=="active": update_live();return
	display_mode="active" if active else "service"
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	hold=null;track=null;live_status=null
	if pending.is_valid():
		words("确认这次操作",23);words(question,21)
		button("确认",accept);button("取消",func(): pending=Callable();question="";refresh());return
	if active:
		live_status=words("",21)
		words("按住下方按钮让绿色控制区上移，松开会下移；让鱼留在绿色区域，右侧进度满即成功。电脑也可按住空格。离开界面会结束本次，饵与体力不返还。",17)
		var row := HBoxContainer.new();content.add_child(row)
		track=Control.new();track.set_script(preload("res://scripts/fishing/fishing_track.gd"));track.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(track)
		var operation := VBoxContainer.new();operation.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(operation)
		hold=Control.new();hold.set_script(preload("res://scripts/fishing/fishing_hold.gd"));operation.add_child(hold)
		operation.add_child(FarmUIStyle.label("按住 ↑\n松开 ↓\n先跟住鱼，别急着一直按。",19,FarmUIStyle.MUTED))
		update_live();return
	words(Fishing.sites[context].name+" · "+Calendar.label(),21)
	words("鱼竿%d级 · 垂钓等级%d · 经验%d · 今天还可抛竿%d次\n鱼饵%d份 · 稳流鱼钩剩%d次 · 体力%d" % [Fishing.state.rod,Fishing.level(),Fishing.state.xp,Fishing.remaining_casts(context),Inventory.count("fishing_bait"),Fishing.state.hook_charges,GameState.stamina],17)
	if Fishing.state.pending!="":
		words("水桶里有一尾"+Fishing.data.species[Fishing.state.pending].name+"。背包满时会保留，领取后才可以继续抛竿。")
		button("领取水桶中的鱼",func(): feedback(Fishing.claim()))
	if Fishing.session.message!="": words(Fishing.session.message,18)
	match page:
		"gear": build_gear()
		"book": build_book()
		_: build_cast()
func update_live() -> void:
	if not is_instance_valid(live_status): return
	live_status.text="鱼饵已入水，等浮标传来动静……" if Fishing.session.phase=="waiting" else "上钩了！保持控制 · 进度%d%%" % int(float(Fishing.session.progress)*100)
func build_cast() -> void:
	words("每次抛竿消耗鱼饵1、体力3，全域每天至多12次。湖泊生态恶化时可用次数减少，本钓点当前上限%d次。每次最多钓得一尾；鱼种受地点、鱼竿、季节、天气和时段影响。" % Fishing.daily_capacity(context))
	if GameState.tool()!="fishing_rod":
		button("装备鱼竿",func():
			var index := GameState.tools.find("fishing_rod")
			if index>=0: GameState.select_tool(index)
			refresh()
		)
	else: button("向水面抛竿",func(): feedback(Fishing.start(context))).disabled=Fishing.remaining_casts(context)<=0 or Fishing.state.pending!=""
	var possible: Array[String]=Fishing.available_species(context)
	var names: Array[String]=[]
	for species in possible: names.append(Fishing.data.species[species].name)
	words("此时可能遇到："+"、".join(names),16)
	words("钓获鱼类可出售、料理，或在补给页用亲鱼培育同种鱼苗；珍稀鱼仍遵守原养殖研究和矿区前置。",16)
func cost_text(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for id in required: parts.append("%s%d（持有%d）" % [Catalog.item_name(id),int(required[id]),Inventory.count(id)])
	return "、".join(parts)
func build_gear() -> void:
	for amount in [1,5,20]:
		var cost: int=amount*int(Fishing.data.bait_price)
		button("购买鱼饵%d份 · %s" % [amount,DiamondPayments.text(cost)],func(): ask("购买%d份鱼饵，花费%s？" % [amount,DiamondPayments.text(cost)],func(): DiamondPayments.request(self,cost,func(): feedback(Fishing.buy_bait(amount)))))
	button("小麦1 → 鱼饵6",func(): ask("将一份小麦制作成六份鱼饵？",func(): feedback(Fishing.craft_bait(1))))
	if Fishing.state.rod<3:
		var expected: int=Fishing.state.rod
		var upgrade: Dictionary=Fishing.data.upgrades[str(expected+1)]
		words(upgrade.name+" · 需要垂钓经验%d\n%s、%s" % [upgrade.xp,cost_text(upgrade.required),DiamondPayments.text(int(upgrade.coins))])
		button("升级鱼竿",func(): ask("交付上述材料升级为"+upgrade.name+"？",func(): DiamondPayments.request(self,int(upgrade.coins),func(): feedback(Fishing.upgrade_rod(expected)))))
	else: words("星纹鱼竿已经准备好了。高阶鱼依然需要正确的地点与时机。")
	words("稳流鱼钩："+cost_text(Fishing.data.hook.required)+"。需要二级竿，装上后辅助30次抛竿，取消也消耗本次耐久。",16)
	button("制作稳流鱼钩",func(): ask("按所列材料制作一枚稳流鱼钩？",func(): feedback(Fishing.craft_hook())))
	button("装上鱼钩（持有%d）" % Inventory.count("fishing_hook"),func(): feedback(Fishing.equip_hook()))
	words("亲鱼培育：普通鱼1+小麦1→同种鱼苗2；金鳞鱼1+晶石1→鱼苗1；星辉鱼1+晶石3+星纹合金1→鱼苗1。稀有培育沿用原鱼栏解锁条件。",16)
	for species in ["crucian","carp","grass","perch","golden","star"]:
		if Inventory.count("fish_"+species)>0:
			button("用"+Fishing.data.species[species].name+"培育鱼苗",func(): ask("使用一尾亲鱼与上方所列材料培育同种鱼苗？",func(): feedback(Fishing.breeding_fry(species,1))))
func build_book() -> void:
	words("垂钓记录 · 只计亲自完成的钓获",22)
	for species in Fishing.data.species:
		var definition: Dictionary=Fishing.data.species[species]
		words("%s · %s · 钓获%d尾 · 需要鱼竿%d级" % [definition.name,Fishing.rarity(species),int(Fishing.state.counts.get(species,0)),definition.rod],20)
		var seasons: Array[String]=[]
		for season in definition.seasons: seasons.append(Calendar.SEASON_NAMES[int(season)])
		words("季节："+"、".join(seasons)+" · 时段%02d:00–%02d:00" % [int(definition.hours[0])/60,int(definition.hours[1])/60],16)
		if species=="eternal": words("生态健康度90、流星夜20:00后、完成小京湖畔共同照料、星纹竿。符合条件第4次抛竿保底遇到，仍需完成实操；每季最多捕一尾，不出售。",16)
		elif species in ["golden","star"]: words("需要原养殖鱼谱已开放该鱼，并遇到合适天气；旧研究条件不会被钓鱼跳过。",16)
	words("成就",22)
	for id in Fishing.data.achievements: words(("✓ " if id in Fishing.state.achievements else "○ ")+Fishing.data.achievements[id],17)
func _process(delta: float) -> void:
	if not visible or not Fishing.active(): return
	var holding: bool=(is_instance_valid(hold) and hold.held) or Input.is_physical_key_pressed(KEY_SPACE)
	Fishing.tick(delta,holding)
	if is_instance_valid(track): track.queue_redraw()
	update_live()
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.physical_keycode==KEY_SPACE: get_viewport().set_input_as_handled()
