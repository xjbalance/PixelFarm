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
var tab_bar: HBoxContainer
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("家园手作 · 一格一处生活",24,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title);header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	tab_bar=HBoxContainer.new();column.add_child(tab_bar)
	for entry in [["layout","布置与移动"],["catalog","家具与扩建"],["storage","柜中储物"],["upgrade","住宅成长"]]:
		var target: String=entry[0]
		var tab:=FarmUIStyle.button(entry[1],func():
			if not pending.is_valid(): page=target;refresh()
		,180)
		tab.set_meta("facility_tab",target);tab_bar.add_child(tab)
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
	GameState.control_mode_changed.connect(func():
		pending=Callable();confirm_text="";selected_cell=Vector2i(-1,-1);DiamondPayments.cancel(self);refresh()
	)
	FacilityLayout.decorate(self,"housing","安排家具与收纳，让家更像自己的样子。")

func words(text: String, size: int = 18) -> void:
	FacilityLayout.text(section if is_instance_valid(section) else content,text,size)
func button(text: String, action: Callable) -> Button:
	var control := FarmUIStyle.button(text,action,160);(section if is_instance_valid(section) else content).add_child(control);return control
func open_panel(id: String="home") -> void:
	if GameState.modal: return
	if id in ["upgrade","builder"]:
		area="home";selected_id="";selected_kind="chair"
	elif id=="territory_storage":
		if not Housing.near_storage(): return
		area="home";selected_id="";selected_kind="chair"
	elif id in ["room","arrange"]:
		if not Housing.can_arrange(): return
		area="home";selected_id="";selected_kind="chair"
	elif id.begins_with("item:"):
		selected_id=id.trim_prefix("item:")
		if not Housing.near_item(selected_id): return
		var entry: Dictionary=Housing.placement(selected_id);area=entry.area;selected_kind=entry.kind
	else:
		area="farm" if id=="yard" else "home"
		if not Housing.near(area): return
		selected_id="";selected_kind="road" if area=="farm" else "chair"
	context=id;page="storage" if id=="territory_storage" else ("upgrade" if id in ["upgrade","builder"] else "layout");quantity=1;selected_cell=Vector2i(-1,-1);pending=Callable();confirm_text=""
	tab_bar.visible=id!="territory_storage"
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
	FacilityLayout.tabs(tab_bar,page)
	lock_payment(pending.is_valid())
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认本次操作",23);words(confirm_text,21)
		button("确认",accept);button("取消",func(): pending=Callable();confirm_text="";refresh());return
	words("%s · 储物%d/%d种 · %d金" % [Housing.level_name(),Housing.state.storage.size(),Housing.slot_count(),Inventory.coins],18)
	if page=="catalog": show_catalog()
	elif page=="storage": show_storage()
	elif page=="upgrade": show_upgrade()
	else: show_layout()
func show_layout() -> void:
	if area=="home": show_home_layout()
	else: show_farm_layout()
func _open_farm_editor() -> void:
	if not visible or not is_instance_valid(Housing.game) or GameState.location!="farm": return
	close_panel();Housing.game.territory_editor.open()
func show_farm_layout() -> void:
	words("农场庭院 · 直接在地图中布置",23)
	words("进入农场DIY，点选原有家具预览新位置，再确认移动或收纳。房门和必要通路需要留空，原物品和成长进度会保留。",17)
	button("进入农场DIY",_open_farm_editor).set_meta("farm_diy_entry",true)
	words("恢复库中家具：在DIY的「原物 → 已收纳」选择，再点地图预览放置。移动和恢复不重复制作，也不复制储物内容。",16)
	if selected_id!="":
		var item: Dictionary=Housing.placement(selected_id)
		if item.is_empty(): selected_id=""
		else:
			var id: String=selected_id
			words("当前家具 · "+str(Housing.data.furniture[item.kind].name),21)
			if item.kind=="flower":
				var age: int=Housing.flower_age(id)
				words("春铃花："+("尚未播种，靠近花坛可播下花种。" if age<0 else "已照料%d / 3日，移动不改变成长日。" % mini(3,age)),16)
				button("播下春铃花种 · 消耗1种 / 1体力",func(): result(Housing.sow_flower(id))).disabled=age>=0 or not Housing.near_item(id)
				if age>=0:
					button("采收春铃花",func(): result(Housing.harvest_flower(id))).disabled=age<3 or not Housing.near_item(id)
					button("撤回花苗 · 返还1种",func(): ask("撤回这株花苗并返还1粒种子？现有成长日会清除。",func(): result(Housing.uproot_flower(id)))).disabled=not Housing.near_item(id)
					words("有花苗的花坛仍可全场移动；先采收或撤回花苗，再收纳花坛。",16)
			var recycle:=button("收回家具库",func(): ask("收回家具库，原材料不返还，稍后可以再次摆放。继续？",func():
				if Housing.recycle(id): selected_id="";refresh()
				else: result(false)
			))
			recycle.disabled=Housing.state.flowers.has(id) or not Housing.can_manage("farm",id)
	var any_owned: bool=false
	for kind in Housing.data.furniture:
		var item: Dictionary=Housing.data.furniture[kind]
		if item.area!="farm" or int(Housing.state.owned.get(kind,0))<1: continue
		if not any_owned: words("庭院家具库",21);any_owned=true
		words("%s ×%d" % [item.name,Housing.state.owned[kind]],17)
	var any_placed: bool=false
	for item in Housing.state.placed:
		if item.area!="farm": continue
		if not any_placed: words("已布置的庭院家具",21);any_placed=true
		words("%s · %d,%d%s" % [Housing.data.furniture[item.kind].name,item.cell[0],item.cell[1]," · 花苗成长中" if Housing.state.flowers.has(item.id) else ""],17)
func _room_editor() -> Node:
	return Housing.game.home_arrange
func _edit_builtin(id: String) -> void:
	if not visible or not Housing.can_arrange(): return
	close_panel();_room_editor().start_builtin(id)
func _edit_item(id: String) -> void:
	if not visible or not Housing.can_arrange(): return
	close_panel();_room_editor().start_item(id)
func _edit_owned(kind: String) -> void:
	if not visible or not Housing.can_arrange(): return
	close_panel();_room_editor().start_owned(kind)
func show_home_layout() -> void:
	words("自己安排家的样子",23)
	words("进入房间布置后，点选或拖动家具预览新位置，再确认摆放。床、沙发、厨房与收纳会跟着移动，门口和必要通路需要留空。",17)
	button("直接在房间里布置",func():
		if not visible: return
		close_panel();_room_editor().start_blank()
	).set_meta("home_arrange_entry",true)
	words("家里的家具",21)
	for item in Housing.builtin_layout():
		var id: String=item.id
		var control:=button("移动"+str(item.name)+(" · 待安放" if item.stored else ""),_edit_builtin.bind(id))
		control.set_meta("home_builtin_id",id)
		control.tooltip_text="只移动家具，不扣材料。" if id not in HomeLayout.ESSENTIAL else "移动后功能仍可使用；请为它留出能走近的位置。"
	var owned_any:=false
	for kind in Housing.data.furniture:
		if Housing.data.furniture[kind].area!="home" or int(Housing.state.owned.get(kind,0))<1: continue
		if not owned_any: words("家具库",21);owned_any=true
		button("摆放"+str(Housing.data.furniture[kind].name)+" ×%d" % int(Housing.state.owned[kind]),_edit_owned.bind(str(kind)))
	if not Housing.state.placed.is_empty(): words("已摆放的自制家具",21)
	for entry in Housing.state.placed:
		if entry.area!="home": continue
		var id: String=entry.id
		button("移动"+str(Housing.data.furniture[entry.kind].name),_edit_item.bind(id)).set_meta("home_custom_id",id)
		button("收回家具库 · "+str(Housing.data.furniture[entry.kind].name),func(): ask("收回家具库，之后可以重新摆放，不返还制作材料。继续？",func(): result(Housing.recycle(id))))
	for entry in Housing.state.get("recovered",[]):
		var id: String=entry.id
		button("取回暂存家具 · "+str(Housing.data.furniture[entry.kind].name),func(): result(Housing.recover_furniture(id)))

func show_catalog() -> void:
	if area=="home": button("查看住宅成长与施工进度",func(): page="upgrade";refresh())
	var grid:=FarmUIStyle.section_grid(content)
	for kind in Housing.data.furniture:
		var entry: Dictionary=Housing.data.furniture[kind]
		if entry.area not in [area,"style"]: continue
		if entry.area=="style" and area!="home": continue
		section=FarmUIStyle.section(grid)
		var icon := TextureRect.new();var preferred: String="res://assets/housing/interior/placeable_"+str(kind)+".png";icon.texture=load(preferred if entry.area=="home" and ResourceLoader.exists(preferred) else "res://assets/housing/"+str(kind)+".png")
		var replacement:=SchemeCAssets.furniture_texture(str(kind))
		if replacement: icon.texture=replacement
		icon.custom_minimum_size=Vector2(48,48);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;section.add_child(icon)
		words(entry.name+" · 家具库%d\n%s\n%s、%s" % [Housing.state.owned.get(kind,0),entry.description,costs(entry.required),DiamondPayments.text(int(entry.coins))])
		if not Housing.unlocked(kind): words("需要住宅等级%d%s" % [entry.level,"且已结婚" if entry.get("married",false) else ""],16)
		button("制作一件 · "+entry.name,func(): ask("消耗"+costs(entry.required)+"与"+DiamondPayments.text(int(entry.coins))+"制作一件"+entry.name+"？",func(): DiamondPayments.request(self,int(entry.coins),func(): result(Housing.buy(kind))))).disabled=not Housing.unlocked(kind)
		if entry.area=="style":
			button("应用"+entry.name,func(): result(Housing.apply_style(kind))).disabled=not Housing.has_furniture(kind)
			button("还原原"+("墙纸" if kind=="wallpaper" else "地板"),func(): result(Housing.clear_style(kind))).disabled=Housing.state.appearance[kind]=="plain"
	section=null
func show_storage() -> void:
	if area!="home" or not Housing.near_storage(): words("请靠近屋内储物柜或自己放置的共享收纳箱。不能远程搬运。",18);return
	if context=="territory_storage": words("共享住宅收纳：所有箱子使用同一份物品和原住宅容量，移动或拆除箱子不会复制或删除柜内内容。",17)
	words("储物各物品仍最多999，容量按种类计数。取出满包时整笔取消，不会丢掉柜中物品。",16)
	var row := HBoxContainer.new();content.add_child(row);row.add_child(FarmUIStyle.label("数量%d" % quantity,18))
	for delta in [-10,-1,1,10]: row.add_child(FarmUIStyle.button(("+" if delta>0 else "")+str(delta),func(): quantity=clampi(quantity+delta,1,999);refresh(),64))
	for item in Housing.state.storage:
		var amount: int=mini(quantity,int(Housing.state.storage[item]))
		button("取出%s%d（柜中%d）" % [Catalog.item_name(item),amount,Housing.state.storage[item]],func(): result(Housing.withdraw(item,amount)))
	for item in Inventory.items:
		var amount: int=mini(quantity,int(Inventory.items[item]))
		button("存入%s%d（背包%d）" % [Catalog.item_name(item),amount,Inventory.items[item]],func(): result(Housing.deposit(item,amount)))
func show_upgrade() -> void:
	words("周砚的住宅改建 · "+Housing.level_name(),23)
	var job: Dictionary=Housing.state.get("construction",{})
	if not job.is_empty():
		words("正在施工 → "+Housing.level_name(int(job.target_level)),22)
		words("第%d天开工，第%d天早晨完工；还需%d个游戏日。" % [int(job.started_day),int(job.ready_day),maxi(0,int(job.ready_day)-GameClock.day)])
		words("施工期间继续使用当前住宅，床、沙发、厨房与储物照常开放。材料已支付，不会再扣除。",17)
		return
	if Housing.state.level>=4:
		words("星光庄园已落成",23)
		words("四个住宅阶段已完成。原家具、柜中物品与厨房配方仍在，可以继续安排自己的生活空间。")
		return
	var expected: int=int(Housing.state.level)
	var target: int=expected+1
	var entry: Dictionary=Housing.data.levels[str(target)]
	words("下一阶段 · "+entry.name,22)
	words(entry.description,18)
	var preview:=Control.new();preview.set_script(preload("res://scripts/housing/home_upgrade_preview.gd"));preview.level=target;content.add_child(preview)
	words("空间布局示意 · 床、厨房与入口继续可用；已有家具优先保留原位",16)
	for item in entry.required:
		var amount: int=int(entry.required[item]);var held: int=Inventory.count(item)
		var line:=FarmUIStyle.label("%s  %d / %d" % [Catalog.item_name(item),held,amount],18,FarmUIStyle.SUCCESS if held>=amount else FarmUIStyle.DANGER);content.add_child(line)
	words("金币  %d / %d · 施工2个游戏日" % [Inventory.coins,int(entry.coins)],18)
	var allowed: bool=Housing.near_builder() and Inventory.coins>=int(entry.coins)
	for item in entry.required: allowed=allowed and Inventory.count(item)>=int(entry.required[item])
	button("请周砚开始改建",func(): ask("升级为%s，支付%s及%d金币；第%d天早晨完工。施工中可照常回家，确认前不会扣费。" % [entry.name,costs(entry.required),int(entry.coins),GameClock.day+2],func(): result(Housing.upgrade(expected)))).disabled=not allowed
	words("请到周砚的工台旁办理；屋内仅查看图纸。" if not Housing.near_builder() else "确认后只扣除一次材料和金币，完成时不额外发放资源。",16)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
