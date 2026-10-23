extends PanelContainer
## 背包与摊位共用数据视图；只在摊位允许交易。
var shop_mode: bool = false
var title: Label
var balance: Label
var rows: VBoxContainer
var footer: HBoxContainer
var quantity: int = 1
var quantity_label: Label
var materials_tab: bool = false

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = FarmUIStyle.label("背包",26,FarmUIStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("关闭 ×",close_panel,100))
	balance = FarmUIStyle.label("",16)
	column.add_child(balance)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation",10)
	column.add_child(categories)
	categories.add_child(FarmUIStyle.button("种子与收获",func(): materials_tab = false; refresh(),180))
	categories.add_child(FarmUIStyle.button("木材与石料",func(): materials_tab = true; refresh(),180))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	column.add_child(rows)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)
	footer.add_child(FarmUIStyle.label("每次购买",16))
	footer.add_child(FarmUIStyle.button("−",func(): change_quantity(-1),48))
	quantity_label = FarmUIStyle.label("1",20,FarmUIStyle.GOLD)
	quantity_label.custom_minimum_size.x = 35
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(quantity_label)
	footer.add_child(FarmUIStyle.button("+",func(): change_quantity(1),48))
	footer.add_child(FarmUIStyle.label("浇水后睡觉，作物才会成长。",15))
	Inventory.changed.connect(refresh)

func open_panel(as_shop: bool) -> void:
	if GameState.modal: return
	shop_mode = as_shop
	materials_tab = false
	quantity = 1
	GameState.set_modal(true)
	show()
	refresh()

func close_panel() -> void:
	hide()
	GameState.set_modal(false)

func change_quantity(amount: int) -> void:
	quantity = clampi(quantity + amount,1,99)
	refresh()

func refresh() -> void:
	if not visible: return
	title.text = "林芽的种子摊" if shop_mode else "随身背包"
	balance.text = "%d 金  ·  每种物品最多堆叠 999 个  ·  工具不消耗" % Inventory.coins
	footer.visible = shop_mode and not materials_tab
	quantity_label.text = str(quantity)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if materials_tab:
		refresh_materials()
		return
	for crop_id in Catalog.crops:
		var crop: CropDefinition = Catalog.crops[crop_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		row.custom_minimum_size.y = 76
		rows.add_child(row)
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/crops/crops.png")
		atlas.region = Rect2(96,crop.atlas_row*40,32,40)
		icon.texture = atlas
		icon.custom_minimum_size = Vector2(48,60)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		detail.add_child(FarmUIStyle.label("%s  ·  %d 天成熟" % [crop.display_name,crop.growth_days],20,FarmUIStyle.GOLD))
		detail.add_child(FarmUIStyle.label("种子 %d    收获 %d" % [Inventory.count(crop_id+"_seed"),Inventory.count(crop_id)],16))
		if shop_mode:
			row.add_child(FarmUIStyle.button("买 %d 袋\n%d 金" % [quantity,FarmEconomy.seed_price(crop_id)*quantity],buy.bind(crop_id),132))
			var sell_button := FarmUIStyle.button("出售全部\n%d 金 / 个" % crop.sell_price,sell.bind(crop_id),132)
			sell_button.disabled = Inventory.count(crop_id) == 0
			row.add_child(sell_button)
		else:
			row.add_child(FarmUIStyle.button("装备种子",equip.bind(crop_id),132))

func refresh_materials() -> void:
	for id in Catalog.materials:
		var definition: Dictionary = Catalog.materials[id]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 86
		row.add_theme_constant_override("separation",18)
		rows.add_child(row)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		detail.add_child(FarmUIStyle.label("%s ×%d" % [definition.name,Inventory.count(id)],22,FarmUIStyle.GOLD))
		var description := FarmUIStyle.label(definition.description,16)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(description)
		if shop_mode:
			var button := FarmUIStyle.button("出售全部\n%d 金 / 个" % definition.sell_price,sell.bind(id),150)
			button.disabled = Inventory.count(id) == 0
			row.add_child(button)
		else:
			row.add_child(FarmUIStyle.button("装备斧头" if id == "wood" else "装备镐",equip_tool.bind("axe" if id == "wood" else "pickaxe"),150))
	var tip := FarmUIStyle.label("树木每 3 天、石堆每 2 天恢复。修缮和委托也需要材料，记得留一些。",16,Color("c9d6a1"))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(tip)

func equip_tool(id: String) -> void:
	GameState.select_tool(GameState.tools.find(id))
	close_panel()

func buy(crop_id: String) -> void:
	FarmEconomy.buy(crop_id,quantity)

func sell(crop_id: String) -> void:
	FarmEconomy.sell(crop_id,Inventory.count(crop_id))

func equip(crop_id: String) -> void:
	GameState.select_tool(GameState.tools.find(crop_id+"_seed"))
	close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("bag")):
		close_panel()
		get_viewport().set_input_as_handled()
