extends PanelContainer
## 网格触点预览与明确提交，不依赖复杂拖拽；关闭、读档、切换操作模式清空待确认。
var section: VBoxContainer
var content: VBoxContainer
var context: String="home"
var area: String="home"
var page: String="layout"
var selected_kind: String="chair"
var selected_id: String=""
var selected_cell := Vector2i(-1,-1)
var quantity: int=1
var pending := Callable()
var confirm_text: String=""
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("家园手作 · 一格一处生活",24,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title);header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var tabs := HBoxContainer.new();column.add_child(tabs)
	for entry in [["layout","布置与移动"],["catalog","家具与扩建"],["storage","柜中储物"]]:
		var target: String=entry[0]
		tabs.add_child(FarmUIStyle.button(entry[1],func():
			if not pending.is_valid(): page=target;refresh()
		,220))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
	GameState.control_mode_changed.connect(func():
		pending=Callable();confirm_text="";selected_cell=Vector2i(-1,-1);DiamondPayments.cancel(self);refresh()
	)
func words(text: String, size: int = 18) -> void:
	var control := FarmUIStyle.label(text,size);control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;(section if is_instance_valid(section) else content).add_child(control)
func button(text: String, action: Callable) -> Button:
	var control := FarmUIStyle.button(text,action,160);(section if is_instance_valid(section) else content).add_child(control);return control
func open_panel(id: String="home") -> void:
	if GameState.modal: return
	if id.begins_with("item:"):
		selected_id=id.trim_prefix("item:")
		if not Housing.near_item(selected_id): return
		var entry: Dictionary=Housing.placement(selected_id);area=entry.area;selected_kind=entry.kind
	else:
		area="farm" if id=="yard" else "home"
		if not Housing.near(area): return
		selected_id="";selected_kind="road" if area=="farm" else "chair"
	context=id;page="layout";quantity=1;selected_cell=Vector2i(-1,-1);pending=Callable();confirm_text=""
	GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();confirm_text="";selected_cell=Vector2i(-1,-1);lock_payment(false);DiamondPayments.cancel(self);hide();GameState.set_modal(false)
func lock_payment(locked: bool) -> void:
	for control in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(control): control.disabled=locked
func ask(text: String, action: Callable) -> void:
	if pending.is_valid(): return
	pending=action;confirm_text=text;refresh()
func accept() -> void:
	var action := pending;pending=Callable();confirm_text=""
	if visible and action.is_valid(): action.call()
	refresh()
func result(ok: bool) -> void:
	if not ok: Events.notice.emit("位置、数量、前置或材料不满足，原布局与物品已保留。")
	refresh()
func costs(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for item in required: parts.append("%s%d（有%d）" % [Catalog.item_name(item),int(required[item]),Inventory.count(item)])
	return "、".join(parts)
func refresh() -> void:
	section=null
	if not visible: return
	lock_payment(pending.is_valid())
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认本次操作",23);words(confirm_text,21)
		button("确认",accept);button("取消",func(): pending=Callable();confirm_text="";refresh());return
	words("%s · 储物%d/%d种 · %d金" % [{1:"基础小屋",2:"扩建小屋",3:"高级住宅"}[int(Housing.state.level)],Housing.state.storage.size(),Housing.slot_count(),Inventory.coins],18)
	if page=="catalog": show_catalog()
	elif page=="storage": show_storage()
	else: show_layout()
func show_layout() -> void:
	words("庭院布置" if area=="farm" else "小屋起居布置",23)
	words("选择家具，再点网格查看落点预览，最后确认放置。灰格不能放；床、门、故事木盒、厨房和穿行走廊都在保护区。已摆家具可移动或回收到家具库，不返还材料也不会复制。",16)
	if selected_id!="":
		var active: Dictionary=Housing.placement(selected_id)
		if active.is_empty(): selected_id=""
		else:
			words("正在移动："+Housing.data.furniture[active.kind].name)
			var id: String=selected_id
			if active.kind=="flower" and active.area=="farm":
				var age: int=Housing.flower_age(id)
				words("春铃花："+("尚未播种。春季庆典可获得花种，靠近这个花坛再播下。" if age<0 else "已照料%d / 3日。三个游戏日后采收，移动不改变成长日。" % mini(3,age)),16)
				button("播下春铃花种 · 消耗1种 / 1体力",func(): result(Housing.sow_flower(id))).disabled=age>=0 or not Housing.near_item(id)
				if age>=0:
					button("采收春铃花",func(): result(Housing.harvest_flower(id))).disabled=age<3 or not Housing.near_item(id)
					button("撤回花苗 · 返还1种",func(): ask("撤回这株花苗并返还1粒种子？现有成长日会清除。",func(): result(Housing.uproot_flower(id)))).disabled=not Housing.near_item(id)
					words("先采收或撤回花苗，再回收花坛；背包满时整笔保留。",16)
			button("回收这件家具",func(): ask("收回家具库，原材料不返还，稍后可以再次摆放。继续？",func():
				if Housing.recycle(id): selected_id="";selected_cell=Vector2i(-1,-1);refresh()
				else: result(false)
			))
			button("取消移动，改选库中家具",func(): selected_id="";selected_cell=Vector2i(-1,-1);refresh())
	if selected_id=="":
		for kind in Housing.data.furniture:
			var entry: Dictionary=Housing.data.furniture[kind]
			if entry.area!=area or int(Housing.state.owned.get(kind,0))<1: continue
			button(("✓ " if selected_kind==kind else "")+entry.name+" ×%d" % Housing.state.owned[kind],func(): selected_kind=kind;selected_cell=Vector2i(-1,-1);refresh())
	words("当前："+Housing.data.furniture[selected_kind].name+" · %d×%d格" % [Housing.data.furniture[selected_kind].size[0],Housing.data.furniture[selected_kind].size[1]],18)
	for rect in Housing.layout_rects(area):
		var grid := GridContainer.new();grid.columns=rect.size.x;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);content.add_child(grid)
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var cell := Vector2i(x,y)
				var permitted: bool=Housing.can_place(selected_kind,area,cell,selected_id)
				var control := FarmUIStyle.button(("预览 " if cell==selected_cell else "")+"%d,%d" % [x,y],func(): selected_cell=cell;refresh(),72)
				control.disabled=not permitted;grid.add_child(control)
	if selected_cell.x>=0:
		var footprint: Rect2i=Housing.footprint(selected_kind,selected_cell)
		words("预览：左上格%d,%d，占%d×%d格。%s" % [selected_cell.x,selected_cell.y,footprint.size.x,footprint.size.y,"实体家具会阻挡行走" if Housing.data.furniture[selected_kind].solid else "地面装饰可以走过"])
		var cell: Vector2i=selected_cell;var kind: String=selected_kind;var id: String=selected_id
		button("确认移动到此格" if id!="" else "确认放置到此格",func(): ask("将%s放到%d,%d？资源已在制作时扣除，本次只移动家具。" % [Housing.data.furniture[kind].name,cell.x,cell.y],func():
			var ok: bool=Housing.move(id,cell) if id!="" else Housing.place(kind,area,cell)
			if ok: selected_id="";selected_cell=Vector2i(-1,-1)
			result(ok)
		))
	for entry in Housing.state.placed:
		if entry.area!=area: continue
		var id: String=entry.id
		button("移动 / 回收 · "+Housing.data.furniture[entry.kind].name+"（%d,%d）" % [entry.cell[0],entry.cell[1]],func():
			if Housing.can_manage(area,id): selected_id=id;selected_kind=entry.kind;selected_cell=Vector2i(-1,-1);refresh()
			else: result(false)
		)
func show_catalog() -> void:
	if area=="home" and Housing.state.level<3:
		var expected: int=Housing.state.level
		var definition: Dictionary=Housing.data.levels[str(expected+1)]
		words(definition.name+"\n"+definition.description+"\n"+costs(definition.required)+"、"+DiamondPayments.text(int(definition.coins)))
		button("确认房屋扩建",func(): ask("扩建消耗"+costs(definition.required)+"与"+DiamondPayments.text(int(definition.coins))+"，原家具布局与床门不动。继续？",func(): DiamondPayments.request(self,int(definition.coins),func(): result(Housing.upgrade(expected)))))
	var grid:=FarmUIStyle.section_grid(content)
	for kind in Housing.data.furniture:
		var entry: Dictionary=Housing.data.furniture[kind]
		if entry.area not in [area,"style"]: continue
		if entry.area=="style" and area!="home": continue
		section=FarmUIStyle.section(grid)
		var icon := TextureRect.new();icon.texture=load("res://assets/housing/"+kind+".png");icon.custom_minimum_size=Vector2(48,48);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;section.add_child(icon)
		words(entry.name+" · 家具库%d\n%s\n%s、%s" % [Housing.state.owned.get(kind,0),entry.description,costs(entry.required),DiamondPayments.text(int(entry.coins))])
		if not Housing.unlocked(kind): words("需要住宅等级%d%s" % [entry.level,"且已结婚" if entry.get("married",false) else ""],16)
		button("制作一件 · "+entry.name,func(): ask("消耗"+costs(entry.required)+"与"+DiamondPayments.text(int(entry.coins))+"制作一件"+entry.name+"？",func(): DiamondPayments.request(self,int(entry.coins),func(): result(Housing.buy(kind))))).disabled=not Housing.unlocked(kind)
		if entry.area=="style":
			button("应用"+entry.name,func(): result(Housing.apply_style(kind))).disabled=not Housing.has_furniture(kind)
			button("还原原"+("墙纸" if kind=="wallpaper" else "地板"),func(): result(Housing.clear_style(kind))).disabled=Housing.state.appearance[kind]=="plain"
	section=null
func show_storage() -> void:
	if area!="home" or not Housing.near("home"): words("储物柜在屋内装修台旁办理，请回小屋。不能远程搬运。",18);return
	words("储物各物品仍最多999，容量按种类计数。取出满包时整笔取消，不会丢掉柜中物品。",16)
	var row := HBoxContainer.new();content.add_child(row);row.add_child(FarmUIStyle.label("数量%d" % quantity,18))
	for delta in [-10,-1,1,10]: row.add_child(FarmUIStyle.button(("+" if delta>0 else "")+str(delta),func(): quantity=clampi(quantity+delta,1,999);refresh(),64))
	for item in Housing.state.storage:
		var amount: int=mini(quantity,int(Housing.state.storage[item]))
		button("取出%s%d（柜中%d）" % [Catalog.item_name(item),amount,Housing.state.storage[item]],func(): result(Housing.withdraw(item,amount)))
	for item in Inventory.items:
		var amount: int=mini(quantity,int(Inventory.items[item]))
		button("存入%s%d（背包%d）" % [Catalog.item_name(item),amount,Inventory.items[item]],func(): result(Housing.deposit(item,amount)))
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
