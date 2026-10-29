extends PanelContainer
var selected_recipe: String="carrot_stew"
var section: VBoxContainer
var content: VBoxContainer
var context: String="kitchen"
var page: String="recipes"
var quantity: int=1
var pending := Callable()
var message: String=""
var recipe_page: int=0
var recipe_filter: String="all"
var feedback: Label
var tab_bar: HBoxContainer
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("炉火与麦香 · 小屋厨房",24,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	feedback=FacilityLayout.text(column,"",16);feedback.hide()
	Events.notice.connect(func(text: String):
		if visible: feedback.text=text;feedback.show()
	)
	tab_bar=HBoxContainer.new();column.add_child(tab_bar)
	for row in [["recipes","料理与图鉴"],["processing","加工设备"],["queue","领取成品"]]:
		var id: String=row[0]
		var tab:=FarmUIStyle.button(row[1],func():
			if not pending.is_valid(): page=id;refresh()
		,200)
		tab.set_meta("facility_tab",id);tab_bar.add_child(tab)
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
	FacilityLayout.decorate(self,"kitchen")

func words(text: String, size: int=18) -> void:
	FacilityLayout.text(section if is_instance_valid(section) else content,text,size)
func button(text: String, callback: Callable) -> Button:
	var b := FarmUIStyle.button(text,callback,180);(section if is_instance_valid(section) else content).add_child(b);return b
func open_panel(id: String="kitchen") -> void:
	if GameState.modal or (not Kitchen.near_berry() if id=="berry" else not Kitchen.near_kitchen()): return
	recipe_page=0;recipe_filter="all";feedback.text="";feedback.hide()
	context=id;page="recipes";selected_recipe="carrot_stew";quantity=1;pending=Callable();message=""
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
	section=null
	if not visible: return
	FacilityLayout.tabs(tab_bar,page)
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
	match page:
		"processing": processing()
		"queue": jobs()
		_: recipes()
func recipes() -> void:
	var filters:=FacilityLayout.actions(content)
	for spec in [["all","全部"],["meals","家常与主食"],["baking","烘焙"],["drinks","茶与饮品"]]:
		var filter_id: String=spec[0]
		filters.add_child(FarmUIStyle.button(spec[1],func(): recipe_filter=filter_id;recipe_page=0;refresh(),130))
	filters.add_child(FarmUIStyle.button("−",func(): quantity=maxi(1,quantity-1);refresh(),48))
	filters.add_child(FarmUIStyle.label("%d 批" % quantity,18))
	filters.add_child(FarmUIStyle.button("+",func(): quantity=mini(8,quantity+1);refresh(),48))
	var ids: Array[String]=[]
	for id in Kitchen.data.recipes:
		if recipe_filter=="all" or Kitchen.data.recipes[id].get("category","meals")==recipe_filter: ids.append(id)
	var pages: int=maxi(1,ceili(ids.size()/6.0));recipe_page=clampi(recipe_page,0,pages-1)
	var shown:=ids.slice(recipe_page*6,mini(ids.size(),recipe_page*6+6))
	if selected_recipe not in shown and not shown.is_empty(): selected_recipe=shown[0]
	var navigation:=HBoxContainer.new();content.add_child(navigation)
	var prev:=FarmUIStyle.button("上一页",func(): recipe_page=maxi(0,recipe_page-1);refresh(),100);prev.disabled=recipe_page==0;navigation.add_child(prev)
	navigation.add_child(FarmUIStyle.label("配方 %d / %d 页" % [recipe_page+1,pages],16))
	var next:=FarmUIStyle.button("下一页",func(): recipe_page=mini(pages-1,recipe_page+1);refresh(),100);next.disabled=recipe_page==pages-1;navigation.add_child(next)
	var layout:=HBoxContainer.new();layout.add_theme_constant_override("separation",16);content.add_child(layout)
	var left:=ScrollContainer.new();left.set_script(preload("res://scripts/ui/touch_scroll.gd"));left.custom_minimum_size=Vector2(208,260);left.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(left)
	var choices:=VBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.add_child(choices)
	for id in shown:
		var recipe_id: String=id
		var selector:=FarmUIStyle.button(Kitchen.data.recipes[id].name,func():
			if not pending.is_valid(): selected_recipe=recipe_id;refresh()
		,180)
		selector.icon=ItemPresentation.texture(str(id));selector.expand_icon=true;selector.add_theme_constant_override("icon_max_width",28)
		selector.add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if id==selected_recipe else "secondary"));choices.add_child(selector)
	if not Kitchen.data.recipes.has(selected_recipe): selected_recipe=str(Kitchen.data.recipes.keys()[0])
	var recipe: Dictionary=Kitchen.data.recipes[selected_recipe]
	section=FacilityLayout.card(layout,"recipe_detail")
	var recipe_header:=HBoxContainer.new();recipe_header.add_theme_constant_override("separation",12);section.add_child(recipe_header)
	FacilityLayout.item_preview(recipe_header,selected_recipe,48)
	var recipe_heading:=VBoxContainer.new();recipe_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recipe_header.add_child(recipe_heading)
	FacilityLayout.text(recipe_heading,recipe.name,22)
	FacilityLayout.text(recipe_heading,("已掌握" if Kitchen.recipe_unlocked(selected_recipe) else "尚待领会")+" · 已做%d份 · 背包%d份" % [int(Kitchen.state.cooked.get(selected_recipe,0)),Inventory.count(selected_recipe)],16)
	words(recipe.hint,16)
	words("每批食材",21);words(cost(recipe.required),17)
	words(Kitchen.data.items[selected_recipe].description,16)
	var amount: int=quantity
	var id: String=selected_recipe
	var actions:=FacilityLayout.actions(section)
	var cook:=FarmUIStyle.button("制作%s ×%d" % [recipe.name,amount],func(): ask("制作%d批%s，消耗：%s？" % [amount,recipe.name,cost(Kitchen.scaled(recipe.required,amount))],func(): result(Kitchen.cook(id,amount))),200);actions.add_child(cook);cook.disabled=not Kitchen.recipe_unlocked(id) or Inventory.preview_exchange(Kitchen.scaled(recipe.required,amount),Kitchen.scaled(recipe.rewards,amount),0).is_empty()
	var eat:=FarmUIStyle.button("食用一份"+recipe.name,func(): result(Kitchen.consume(id)),200);actions.add_child(eat);eat.disabled=Inventory.count(id)<1
	section=null
	words("原湖岸鱼汤、鱼干继续使用原配方和物品；厨房不会复制另一个同名物品。",16)

func processing() -> void:
	words("农场工坊 · 十种实体设备",23)
	words("回到农场，打开菜单 → 建造 → 摆件 → 加工设备。预览不扣材料，确认后建成；点击实体设备开始加工。",17)
	words("旧订单继续按原完成日保留在“领取成品”；旧已建设备可免费安装一次实体设备。",16)
	var grid:=FarmUIStyle.section_grid(content)
	for id in HarvestCatalog.data().stations:
		section=FarmUIStyle.section(grid)
		var facility: Dictionary=HarvestCatalog.data().stations[id]
		words(facility.name,21)
		words(cost(facility.required)+" · %d金" % facility.coins,16)
		if id in Kitchen.state.built and id not in Workshop.state.legacy_installed: words("原设备已建成：首次实体安装免材料与金币。",17)
		words("加工过程中可以离开或移动；待领取成品保留在对应设备。",16)
	section=null
func jobs() -> void:
	if Kitchen.state.queue.is_empty(): words("加工设备里还没有待领取订单。")
	var grid:=FarmUIStyle.section_grid(content)
	for job in Kitchen.state.queue:
		section=FarmUIStyle.section(grid)
		words("#%d %s ×%d · %s" % [job.id,Kitchen.data.processing[job.recipe].name,job.batches,"已完成" if job.ready else "第%d天完成" % job.ready_day],20)
		var serial: int=job.id
		button("领取这一笔成品",func(): result(Kitchen.claim_job(serial))).disabled=not job.ready
	section=null
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
