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
var scrolling_trade_controls: bool=false
var crop_page: int=0
var crop_group: int=0
var sale_detail: Label
var sale_quantity_label: Label

func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	title=FarmUIStyle.heading(header,"背包","market")
	header.add_child(FarmUIStyle.button("关闭 ×",close_panel,100))
	balance=FarmUIStyle.label("",16);balance.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(balance)
	DiamondPayments.controls(column,refresh);payment_control=column.get_child(column.get_child_count()-1)
	var categories:=HBoxContainer.new();categories.add_theme_constant_override("separation",8);column.add_child(categories)
	for i in range(4):
		var button:=FarmUIStyle.button(["种子与收获","材料与矿物","鱼苗与湖鲜","生活与料理"][i],change_category.bind(i),160)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.toggle_mode=true;categories.add_child(button);category_buttons.append(button)
	var detail_card:=FarmUIStyle.card(column)
	selected_detail=FarmUIStyle.label("轻点物品图标或名称查看；使用与装备需点对应按钮。",16)
	selected_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selected_detail.custom_minimum_size.y=36;detail_card.add_child(selected_detail)
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
	crop_page=0;crop_group=0
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
	crop_page=0
	materials_tab=index==1;aquaculture_tab=index==2;life_tab=index==3;selected_item=""
	refresh();scroll.scroll_vertical=0

func change_quantity(amount: int) -> void:
	quantity=clampi(quantity+amount,1,99);refresh()

func category() -> String:
	return "life" if life_tab else ("fish" if aquaculture_tab else ("materials" if materials_tab else "crops"))

func refresh() -> void:
	if not visible: return
	# 高密度触控目标增大时，交易辅助区随内容滚动，保留至少一行物品视野。
	if UIMetrics.minimum_target()>64 and not scrolling_trade_controls:
		payment_control.reparent(rows);footer.reparent(rows);scrolling_trade_controls=true
	title.text="林芽的种子摊" if shop_mode else "随身背包"
	balance.text="%d 金 · 每种最多%d · 钻石%d" % [Inventory.coins,Inventory.MAX_STACK,Xiaojing.state.diamonds]
	footer.visible=shop_mode and pending_sale.is_empty();payment_control.visible=footer.visible;quantity_label.text=str(quantity)
	var current:=category()
	for i in range(category_buttons.size()): category_buttons[i].set_pressed_no_signal(current==["crops","materials","fish","life"][i])
	var key: String=("shop:" if shop_mode else "bag:")+current+str(crop_page)+":"+str(crop_group)+":"+str(Calendar.season())+(":sale:"+str(pending_sale.token) if not pending_sale.is_empty() else "")
	if key!=content_key:
		view_epoch+=1;content_key=key;row_views.clear()
		for child in rows.get_children():
			if scrolling_trade_controls and child in [payment_control,footer]: continue
			rows.remove_child(child);child.queue_free()
		if not pending_sale.is_empty(): build_sale()
		else:
			match current:
				"life": refresh_life()
				"fish": refresh_aquaculture()
				"materials": refresh_materials()
				_: build_crops()
	if scrolling_trade_controls:
		rows.move_child(payment_control,0);rows.move_child(footer,rows.get_child_count()-1)
	update_rows();update_selection();update_sale()

func make_row(key: String) -> Dictionary:
	var card:=FarmUIStyle.card(rows)
	var row:=HBoxContainer.new();row.custom_minimum_size.y=70;row.add_theme_constant_override("separation",10);card.add_child(row)
	var view: Dictionary={"row":row,"selectors":[],"actions":[]}
	row_views[key]=view;row_build_count+=1;return view

func add_selector(view: Dictionary,id: String,width: int=200) -> void:
	var token: int=view_epoch
	var button:=FarmUIStyle.button("",func():
		if visible and token==view_epoch: select_item(id)
	,width)
	button.toggle_mode=true;button.icon=ItemPresentation.texture(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
	button.add_theme_stylebox_override("normal",FarmUIStyle.surface("secondary"))
	button.add_theme_font_size_override("font_size",17);button.tooltip_text=ItemPresentation.description(id)
	button.set_meta("inventory_item",id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	view.row.add_child(button);view.selectors.append(button)

func add_action(view: Dictionary,caption: String,callback: Callable,item: String="",action: String="",width: int=132) -> Button:
	var button:=FarmUIStyle.button(caption,func(): pass,width)
	var token: int=view_epoch
	button.pressed.connect(func():
		if not visible or GameState.restoring or token!=view_epoch or not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled: return
		callback.call()
	)
	button.set_meta("inventory_action",item);button.set_meta("action_kind",action);button.set_meta("caption",caption)
	view.row.add_child(button);view.actions.append(button);return button

func crop_turn(amount: int) -> void:
	crop_page=maxi(0,crop_page+amount);content_key="";refresh();scroll.scroll_vertical=0

func build_crops() -> void:
	var available: Array[String]=[]
	for id in Catalog.crops:
		if id in ["carrot","potato","wheat"]: available.append(id);continue
		var row: Dictionary=HarvestCatalog.data().crops[id]
		if shop_mode:
			if not HarvestCatalog.seed_available(id): continue
		elif not Catalog.crop_grows(id) and Inventory.count(id)==0 and Inventory.count(id+"_seed")==0: continue
		if crop_group==1 and "flower" not in row.tags: continue
		available.append(id)
	var pages: int=maxi(1,ceili(available.size()/6.0));crop_page=clampi(crop_page,0,pages-1)
	var navigation:=HBoxContainer.new();rows.add_child(navigation)
	navigation.add_child(FarmUIStyle.button("上一页",crop_turn.bind(-1),90));navigation.get_child(0).disabled=crop_page==0
	navigation.add_child(FarmUIStyle.label("%s季 · %d/%d页" % [["春","夏","秋","冬"][Calendar.season()],crop_page+1,pages],17))
	var next:=FarmUIStyle.button("下一页",crop_turn.bind(1),90);next.disabled=crop_page>=pages-1;navigation.add_child(next)
	navigation.add_child(FarmUIStyle.button("全部 / 花卉",func(): crop_group=1-crop_group;crop_page=0;content_key="";refresh(),160))
	if shop_mode: FacilityLayout.text(rows,"当季种子 · 部分品种在种子合作社建成后供货；树苗见生活分类。",15)
	for id in available.slice(crop_page*6,mini(available.size(),crop_page*6+6)):
		var view:=make_row("crop:"+id)
		add_selector(view,id+"_seed",160);add_selector(view,id,150)
		if shop_mode:
			add_action(view,"",buy.bind(id),id,"seed_buy")
			add_action(view,"",buy_crop.bind(id),id,"crop_buy")
			add_action(view,"",request_sale.bind(id),id,"sell")
			add_action(view,"按数量出售",request_sale_quantity.bind(id),id,"sell_quantity",120)
		else:
			add_action(view,"装备种子",equip.bind(id),id+"_seed","equip")
			if Recovery.FOOD.has(id): add_action(view,"吃1个\n+%d体力" % Recovery.FOOD[id],use_item.bind(id),id,"eat",100)

func refresh_materials() -> void:
	for id in Catalog.materials:
		var view:=make_row(id);add_selector(view,id)
		if shop_mode:
			if DiamondPayments.good_unlocked(id): add_action(view,"",buy_material.bind(id),id,"material_buy",150)
			add_action(view,"",request_sale.bind(id),id,"sell",150)
			add_action(view,"按数量出售",request_sale_quantity.bind(id),id,"sell_quantity",120)
		else:
			# 仅木/石保持旧快捷工具入口，矿物按其实际用途查看，不再一律装备镐。
			if id in ["wood","stone"]: add_action(view,"装备斧头" if id=="wood" else "装备镐",equip_tool.bind("axe" if id=="wood" else "pickaxe"),id,"tool",150)

func refresh_aquaculture() -> void:
	for id in Catalog.aquaculture_items:
		var definition: Dictionary=Catalog.aquaculture_items[id]
		var view:=make_row(id);add_selector(view,id)
		if shop_mode:
			if fish_cost(id)>0: add_action(view,"",buy_fish.bind(id),id,"fish_buy")
			if Catalog.sell_price(id)>0:
				add_action(view,"",request_sale.bind(id),id,"sell")
				add_action(view,"按数量出售",request_sale_quantity.bind(id),id,"sell_quantity",120)
		elif definition.kind=="food": add_action(view,"食用1份\n恢复体力",use_item.bind(id),id,"eat")

func refresh_life() -> void:
	for id in Catalog.items:
		var definition: Dictionary=Catalog.items[id]
		if definition.get("category","") not in ["fishing","livestock","kitchen","festival","exploration"]: continue
		var view:=make_row(id);add_selector(view,id)
		if shop_mode and definition.get("kind","")=="sapling":
			var fruit: String=id.trim_suffix("_sapling")
			add_action(view,"购买树苗",func(): Workshop.buy_sapling(fruit,quantity);refresh(),id,"sapling_buy")
		elif shop_mode and Catalog.sell_price(id)>0:
			add_action(view,"",request_sale.bind(id),id,"sell")
			add_action(view,"按数量出售",request_sale_quantity.bind(id),id,"sell_quantity",120)
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
				"sell_quantity": button.disabled=Inventory.count(id)<=0
				"sapling_buy":
					button.disabled=not HarvestCatalog.unlocked(str(HarvestCatalog.data().orchard[id.trim_suffix("_sapling")].unlock))
					button.text="购入%d棵\n%d金 / 棵" % [quantity,ceili(int(Catalog.items[id].price)*(.8 if VillageProjects.has_project("cooperative") else 1.0))]
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
		for button in view.selectors:
			var selected: bool=str(button.get_meta("inventory_item"))==selected_item
			button.set_pressed_no_signal(selected)
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

func request_sale_quantity(item: String) -> void:
	request_sale(item,1)

func request_sale(item: String, amount: int=-1) -> void:
	if not visible or not shop_mode or Inventory.count(item)<=0 or Catalog.sell_price(item)<=0: return
	if not pending_sale.is_empty() or GameState.restoring: return
	var chosen: int=Inventory.count(item) if amount<0 else clampi(amount,1,Inventory.count(item))
	sale_serial+=1;pending_sale={"item":item,"amount":chosen,"total":Catalog.sell_price(item)*chosen,"token":sale_serial};refresh()
	scroll.scroll_vertical=0

func set_sale_quantity(amount: int) -> void:
	if not visible or not shop_mode or GameState.restoring or pending_sale.is_empty(): return
	var held: int=Inventory.count(str(pending_sale.item))
	if held<=0: return
	var chosen: int=clampi(amount,1,held)
	if chosen==int(pending_sale.amount): return
	# 每次改数量都是新确认，已经移除的旧确认按钮不能结算新数量。
	sale_serial+=1;pending_sale.amount=chosen;pending_sale.total=Catalog.sell_price(str(pending_sale.item))*chosen;pending_sale.token=sale_serial
	refresh()

func change_sale_quantity(delta: int) -> void:
	if pending_sale.is_empty(): return
	set_sale_quantity(int(pending_sale.amount)+delta)

func select_sale_all() -> void:
	if pending_sale.is_empty(): return
	set_sale_quantity(Inventory.count(str(pending_sale.item)))

func cancel_sale() -> void:
	pending_sale.clear();sale_serial+=1;refresh()

func build_sale() -> void:
	sale_detail=FarmUIStyle.label("",20,FarmUIStyle.TITLE)
	sale_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;FarmUIStyle.card(rows).add_child(sale_detail)
	var controls:=make_row("sale_quantity")
	controls.row.custom_minimum_size.y=UIMetrics.minimum_target()+8
	controls.row.add_child(FarmUIStyle.label("出售数量",18))
	var minus:=add_action(controls,"−",change_sale_quantity.bind(-1),"","sale_minus",48)
	minus.set_meta("sale_control","minus")
	sale_quantity_label=FarmUIStyle.label("",22,FarmUIStyle.TITLE);sale_quantity_label.custom_minimum_size.x=55;sale_quantity_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;controls.row.add_child(sale_quantity_label)
	var plus:=add_action(controls,"+",change_sale_quantity.bind(1),"","sale_plus",48)
	plus.set_meta("sale_control","plus")
	for amount in [1,5,10]:
		var preset:=add_action(controls,str(amount)+"个",set_sale_quantity.bind(amount),"","sale_preset",64)
		preset.set_meta("sale_control",str(amount));preset.set_meta("sale_amount",amount)
	var all:=add_action(controls,"全部",select_sale_all,"","sale_all",72)
	all.set_meta("sale_control","all")
	var view:=make_row("sale")
	add_action(view,"确认出售",confirm_sale.bind(int(pending_sale.token)),"","sale_confirm")
	add_action(view,"取消出售",cancel_sale,"","sale_cancel")

func update_sale() -> void:
	if pending_sale.is_empty() or not is_instance_valid(sale_detail): return
	var id: String=str(pending_sale.item);var held: int=Inventory.count(id);var amount: int=int(pending_sale.amount)
	sale_detail.text="%s · 持有%d个 · 单价%d金\n出售%d个，获得%d金币；保留%d个。\n%s" % [Catalog.item_name(id),held,Catalog.sell_price(id),amount,int(pending_sale.total),maxi(0,held-amount),"库存已变化，请重新选择数量。" if held<amount else "确认前不会扣除物品。出售后无法撤回，请留好委托与修缮材料。"]
	sale_quantity_label.text=str(amount)
	for view in row_views.values():
		for button in view.actions:
			match str(button.get_meta("action_kind")):
				"sale_minus": button.disabled=held<=0 or amount<=1
				"sale_plus": button.disabled=held<=0 or amount>=held
				"sale_preset": button.disabled=held<int(button.get_meta("sale_amount"))
				"sale_all": button.disabled=held<=0
				"sale_confirm": button.disabled=held<amount or amount<1

func confirm_sale(token: int) -> void:
	if not visible or not shop_mode or GameState.restoring or pending_sale.is_empty() or token!=int(pending_sale.token): return
	if Inventory.count(str(pending_sale.item))<int(pending_sale.amount):
		Events.notice.emit("库存已变化，请重新选择出售数量；物品已保留。")
		refresh();return
	var sale:=pending_sale.duplicate();pending_sale.clear();sale_serial+=1;FarmEconomy.sell(sale.item,int(sale.amount));refresh()

func equip(crop_id: String) -> void:
	if not visible or Inventory.count(crop_id+"_seed")<=0: return
	Workshop.select_seed(crop_id);close_panel()

func equip_tool(id: String) -> void:
	if not visible or id not in GameState.tools: return
	GameState.select_tool(GameState.tools.find(id));close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("bag")):
		close_panel();get_viewport().set_input_as_handled()
