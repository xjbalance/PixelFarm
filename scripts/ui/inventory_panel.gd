extends PanelContainer
## 原背包/商店接口保留；选择只读，使用仍交给原状态事务。
var shop_mode: bool=false
var title: Label
var balance: Label
var rows: VBoxContainer
var footer: HBoxContainer
var quantity: int=1
var quantity_label: Label
var materials_tab: bool=false
var aquaculture_tab: bool=false
var life_tab: bool=false
var pending_sale: Dictionary={}
var sale_serial: int=0
var selected_item: String=""
var selected_detail: Label
var row_views: Dictionary={}
var category_buttons: Array[Button]=[]
var scroll: ScrollContainer
var payment_control: Control
var content_key: String=""
var view_epoch: int=0
var row_build_count: int=0

func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	title=FarmUIStyle.label("背包",26,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("关闭 ×",close_panel,100))
	balance=FarmUIStyle.label("",16);balance.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(balance)
	DiamondPayments.controls(column,refresh);payment_control=column.get_child(column.get_child_count()-1)
	var categories:=HBoxContainer.new();categories.add_theme_constant_override("separation",8);column.add_child(categories)
	for i in range(4):
		var button:=FarmUIStyle.button(["种子与收获","材料与矿物","鱼苗与湖鲜","生活与料理"][i],change_category.bind(i),160)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.toggle_mode=true;categories.add_child(button);category_buttons.append(button)
	selected_detail=FarmUIStyle.label("轻点物品图标或名称查看；使用与装备需点对应按钮。",16)
	selected_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selected_detail.custom_minimum_size.y=46;column.add_child(selected_detail)
	rows=VBoxContainer.new();rows.add_theme_constant_override("separation",10)
	scroll=ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	footer=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	footer.add_child(FarmUIStyle.label("每次购买",16));footer.add_child(FarmUIStyle.button("−",func(): change_quantity(-1),48))
	quantity_label=FarmUIStyle.label("1",20,FarmUIStyle.TITLE);quantity_label.custom_minimum_size.x=35;quantity_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;footer.add_child(quantity_label)
	footer.add_child(FarmUIStyle.button("+",func(): change_quantity(1),48));footer.add_child(FarmUIStyle.label("每种最多999 · 交易前核对数量",15))
	Inventory.changed.connect(refresh);GameState.changed.connect(refresh);Xiaojing.changed.connect(refresh)
	Events.location_changed.connect(func(_id: String):
		if visible: close_panel()
	)

func open_panel(as_shop: bool) -> void:
	if GameState.modal: return
	pending_sale.clear();sale_serial+=1;view_epoch+=1;content_key="";selected_item=""
	shop_mode=as_shop;materials_tab=false;aquaculture_tab=false;life_tab=false;quantity=1
	GameState.set_modal(true);show();refresh();scroll.scroll_vertical=0

func close_panel() -> void:
	DiamondPayments.cancel(self);pending_sale.clear();sale_serial+=1;view_epoch+=1;content_key="";selected_item=""
	selected_detail.text="轻点物品图标或名称查看；使用与装备需点对应按钮。"
	for view in row_views.values():
		for button in view.selectors: button.set_pressed_no_signal(false)
	hide();GameState.set_modal(false)

func change_category(index: int) -> void:
	if not visible: return
	DiamondPayments.cancel(self);pending_sale.clear();sale_serial+=1
	materials_tab=index==1;aquaculture_tab=index==2;life_tab=index==3;selected_item=""
	refresh();scroll.scroll_vertical=0

func change_quantity(amount: int) -> void:
	quantity=clampi(quantity+amount,1,99);refresh()

func category() -> String:
	return "life" if life_tab else ("fish" if aquaculture_tab else ("materials" if materials_tab else "crops"))

func refresh() -> void:
	if not visible: return
	title.text="林芽的种子摊" if shop_mode else "随身背包"
	balance.text="%d 金 · 每种最多%d · 钻石%d" % [Inventory.coins,Inventory.MAX_STACK,Xiaojing.state.diamonds]
	footer.visible=shop_mode;payment_control.visible=shop_mode;quantity_label.text=str(quantity)
	var current:=category()
	for i in range(category_buttons.size()): category_buttons[i].set_pressed_no_signal(current==["crops","materials","fish","life"][i])
	var key: String=("shop:" if shop_mode else "bag:")+current+(":sale:"+str(pending_sale.token) if not pending_sale.is_empty() else "")
	if key!=content_key:
		view_epoch+=1;content_key=key;row_views.clear()
		for child in rows.get_children(): rows.remove_child(child);child.queue_free()
		if not pending_sale.is_empty(): build_sale()
		else:
			match current:
				"life": refresh_life()
				"fish": refresh_aquaculture()
				"materials": refresh_materials()
				_: build_crops()
	update_rows();update_selection()

func make_row(key: String) -> Dictionary:
	var row:=HBoxContainer.new();row.custom_minimum_size.y=78;row.add_theme_constant_override("separation",10);rows.add_child(row)
	var view: Dictionary={"row":row,"selectors":[],"actions":[]}
	row_views[key]=view;row_build_count+=1;return view

func add_selector(view: Dictionary,id: String,width: int=200) -> void:
	var token: int=view_epoch
	var button:=FarmUIStyle.button("",func():
		if visible and token==view_epoch: select_item(id)
	,width)
	button.toggle_mode=true;button.icon=ItemPresentation.texture(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
	button.add_theme_font_size_override("font_size",17);button.tooltip_text=ItemPresentation.description(id)
	button.set_meta("inventory_item",id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	view.row.add_child(button);view.selectors.append(button)

func add_action(view: Dictionary,caption: String,callback: Callable,item: String="",action: String="",width: int=132) -> Button:
	var button:=FarmUIStyle.button(caption,func(): pass,width)
	var token: int=view_epoch
	button.pressed.connect(func():
		if not visible or GameState.restoring or token!=view_epoch or not is_instance_valid(button) or button.disabled: return
		callback.call()
	)
	button.set_meta("inventory_action",item);button.set_meta("action_kind",action);button.set_meta("caption",caption)
	view.row.add_child(button);view.actions.append(button);return button

func build_crops() -> void:
	for id in Catalog.crops:
		var view:=make_row("crop:"+id)
		add_selector(view,id+"_seed",160);add_selector(view,id,150)
		if shop_mode:
			add_action(view,"",buy.bind(id),id,"seed_buy")
			add_action(view,"",buy_crop.bind(id),id,"crop_buy")
			add_action(view,"",request_sale.bind(id),id,"sell")
		else:
			add_action(view,"装备种子",equip.bind(id),id+"_seed","equip")
			add_action(view,"吃1个\n+%d体力" % Recovery.FOOD[id],use_item.bind(id),id,"eat",100)

func refresh_materials() -> void:
	for id in Catalog.materials:
		var view:=make_row(id);add_selector(view,id)
		if shop_mode:
			if DiamondPayments.good_unlocked(id): add_action(view,"",buy_material.bind(id),id,"material_buy",150)
			add_action(view,"",request_sale.bind(id),id,"sell",150)
		else:
			# 仅木/石保持旧快捷工具入口，矿物按其实际用途查看，不再一律装备镐。
			if id in ["wood","stone"]: add_action(view,"装备斧头" if id=="wood" else "装备镐",equip_tool.bind("axe" if id=="wood" else "pickaxe"),id,"tool",150)

func refresh_aquaculture() -> void:
	for id in Catalog.aquaculture_items:
		var definition: Dictionary=Catalog.aquaculture_items[id]
		var view:=make_row(id);add_selector(view,id)
		if shop_mode:
			if fish_cost(id)>0: add_action(view,"",buy_fish.bind(id),id,"fish_buy")
			if Catalog.sell_price(id)>0: add_action(view,"",request_sale.bind(id),id,"sell")
		elif definition.kind=="food": add_action(view,"食用1份\n恢复体力",use_item.bind(id),id,"eat")

func refresh_life() -> void:
	for id in Catalog.items:
		var definition: Dictionary=Catalog.items[id]
		if definition.get("category","") not in ["fishing","livestock","kitchen","festival","exploration"]: continue
		var view:=make_row(id);add_selector(view,id)
		if shop_mode and Catalog.sell_price(id)>0: add_action(view,"",request_sale.bind(id),id,"sell")
		elif not shop_mode and definition.get("category")=="kitchen" and definition.get("kind")=="food": add_action(view,"食用1份\n恢复体力",use_item.bind(id),id,"eat")

func update_rows() -> void:
	for view in row_views.values():
		for button in view.selectors:
			var id: String=button.get_meta("inventory_item")
			var text: String="%s\n×%d" % [Catalog.item_name(id),Inventory.count(id)]
			if button.text!=text: button.text=text
		for button in view.actions:
			var id: String=button.get_meta("inventory_action")
			var kind: String=button.get_meta("action_kind")
			button.disabled=false
			match kind:
				"eat": button.disabled=Inventory.count(id)<=0 or GameState.stamina>=GameState.max_stamina()
				"equip": button.disabled=Inventory.count(id)<=0
				"sell":
					button.text="出售全部\n%d 金 / 个" % Catalog.sell_price(id);button.disabled=Inventory.count(id)<=0
				"seed_buy": button.text="买 %d 袋\n%s" % [quantity,DiamondPayments.text(FarmEconomy.seed_price(id)*quantity)]
				"crop_buy": button.text="购收获%d个\n%d钻石" % [quantity,DiamondPayments.price(Catalog.sell_price(id)*3*quantity)]
				"material_buy": button.text="钻石购入%d个\n%d钻石" % [quantity,int(DiamondPayments.GOODS[id])*quantity]
				"fish_buy": button.text="购买%d份\n%s" % [quantity,DiamondPayments.text(fish_cost(id)*quantity)]

func select_item(id: String) -> void:
	if not visible or not Catalog.is_item(id): return
	var present:=false
	for view in row_views.values():
		for button in view.selectors:
			if button.get_meta("inventory_item")==id: present=true
	if not present: return
	selected_item=id;update_selection()

func update_selection() -> void:
	for view in row_views.values():
		for button in view.selectors: button.set_pressed_no_signal(str(button.get_meta("inventory_item"))==selected_item)
	selected_detail.text="%s ×%d · %s" % [Catalog.item_name(selected_item),Inventory.count(selected_item),ItemPresentation.description(selected_item)] if selected_item!="" else "轻点物品图标或名称查看；使用与装备需点对应按钮。"

func use_item(id: String) -> void:
	if not visible or shop_mode or GameState.restoring or not Catalog.is_item(id): return
	var ok:=false
	if Recovery.FOOD.has(id): ok=Recovery.eat_crop(id)
	elif id in ["dried_fish","fish_soup"]: ok=Aquaculture.consume_food(id)
	elif Catalog.items[id].get("category")=="kitchen" and Catalog.items[id].get("kind")=="food": ok=Kitchen.consume(id)
	if not ok: Events.notice.emit("缺少食物、体力已满或暂时不能食用，物品已保留。")
	refresh()

func fish_cost(id: String) -> int:
	var definition: Dictionary=Catalog.aquaculture_items[id]
	if id=="fish_feed": return int(definition.price)
	return int(Aquaculture.data.species[definition.species].fry_price) if definition.kind=="fry" else 0

func buy(crop_id: String) -> void:
	if not visible or not shop_mode: return
	var amount:=quantity;DiamondPayments.request(self,FarmEconomy.seed_price(crop_id)*amount,func(): FarmEconomy.buy(crop_id,amount);refresh())

func buy_crop(id: String) -> void:
	var amount:=quantity;DiamondPayments.request(self,Catalog.sell_price(id)*3*amount,func(): DiamondPayments.buy_crop(id,amount);refresh(),true)

func buy_material(id: String) -> void:
	var amount:=quantity;DiamondPayments.request(self,int(DiamondPayments.GOODS[id])*amount*100,func(): DiamondPayments.buy_good(id,amount);refresh(),true)

func buy_fish(id: String) -> void:
	var amount:=quantity;DiamondPayments.request(self,fish_cost(id)*amount,func(): Aquaculture.buy(id,amount);refresh())

func sell(crop_id: String) -> void:
	FarmEconomy.sell(crop_id,Inventory.count(crop_id))

func request_sale(item: String) -> void:
	if not visible or not shop_mode or Inventory.count(item)<=0 or Catalog.sell_price(item)<=0: return
	sale_serial+=1;pending_sale={"item":item,"amount":Inventory.count(item),"total":Catalog.sell_price(item)*Inventory.count(item),"token":sale_serial};refresh()

func build_sale() -> void:
	var view:=make_row("sale")
	var detail:=FarmUIStyle.label("出售%s ×%d，获得%d金币？\n出售后无法撤回，请先留好委托和修缮所需材料。" % [Catalog.item_name(pending_sale.item),pending_sale.amount,pending_sale.total],20,FarmUIStyle.TITLE)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(detail)
	add_action(view,"确认出售",confirm_sale.bind(int(pending_sale.token)))
	add_action(view,"取消出售",func(): pending_sale.clear();sale_serial+=1;refresh())

func confirm_sale(token: int) -> void:
	if not visible or not shop_mode or pending_sale.is_empty() or token!=int(pending_sale.token): return
	var sale:=pending_sale.duplicate();pending_sale.clear();sale_serial+=1;FarmEconomy.sell(sale.item,int(sale.amount));refresh()

func equip(crop_id: String) -> void:
	if not visible or Inventory.count(crop_id+"_seed")<=0: return
	GameState.select_tool(GameState.tools.find(crop_id+"_seed"));close_panel()

func equip_tool(id: String) -> void:
	if not visible or id not in GameState.tools: return
	GameState.select_tool(GameState.tools.find(id));close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("bag")):
		close_panel();get_viewport().set_input_as_handled()
