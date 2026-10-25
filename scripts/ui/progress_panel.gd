extends PanelContainer
## 分页展示可扩展的数据定义，固定触屏操作区；手记只追踪，委托板负责交付。
var mode: String = "journal"
var at_board: bool = false
var selected_id: String = ""
var title: Label
var subtitle: Label
var tabs: HBoxContainer
var heading: Label
var description: Label
var costs: VBoxContainer
var reward: Label
var action_button: Button
var hint: Label

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = FarmUIStyle.label("",26,FarmUIStyle.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("鱼栏图纸",func(): close_panel(); Events.interaction_requested.emit("fish:guide"),150))
	header.add_child(FarmUIStyle.button("关闭 ×",close_panel,100))
	subtitle = FarmUIStyle.label("",17)
	column.add_child(subtitle)
	DiamondPayments.controls(column,refresh)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	column.add_child(tabs)
	heading = FarmUIStyle.label("",23,FarmUIStyle.TITLE)
	column.add_child(heading)
	description = FarmUIStyle.label("",18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 55
	column.add_child(description)
	costs = VBoxContainer.new()
	costs.add_theme_constant_override("separation",6)
	costs.custom_minimum_size.y = 92
	column.add_child(costs)
	reward = FarmUIStyle.label("",17,FarmUIStyle.SUCCESS)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reward)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	action_button = FarmUIStyle.button("",perform_action,160)
	column.add_child(action_button)
	hint = FarmUIStyle.label("",16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	FarmProgress.changed.connect(refresh)
	Inventory.changed.connect(refresh)

func open_panel(requested_mode: String, editable: bool) -> void:
	if GameState.modal: return
	mode = requested_mode
	at_board = editable
	var definitions: Dictionary = FarmProgress.upgrades if mode == "workshop" else FarmProgress.quests
	selected_id = str(definitions.keys()[0])
	for id in definitions:
		if (mode == "workshop" and not FarmProgress.has_upgrade(id)) or (mode != "workshop" and FarmProgress.quest_status(id) in ["active","available"]):
			selected_id = id
			break
	GameState.set_modal(true)
	show()
	refresh()

func close_panel() -> void:
	DiamondPayments.cancel(self)
	hide()
	GameState.set_modal(false)

func select(id: String) -> void:
	selected_id = id
	refresh()

func refresh() -> void:
	if not visible: return
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	for child in costs.get_children():
		costs.remove_child(child)
		child.queue_free()
	var definitions: Dictionary = FarmProgress.upgrades if mode == "workshop" else FarmProgress.quests
	for id in definitions:
		var name_text: String = definitions[id].name if mode == "workshop" else definitions[id].title
		var done: bool = FarmProgress.has_upgrade(id) if mode == "workshop" else FarmProgress.quest_status(id) == "completed"
		var button := FarmUIStyle.button(("✓ " if done else "")+name_text,select.bind(id),160)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == selected_id: button.add_theme_stylebox_override("normal",FarmUIStyle.surface("selected"))
		tabs.add_child(button)
	if mode == "workshop": refresh_upgrade()
	else: refresh_quest()

func add_cost(id: String, amount: int) -> void:
	var held: int = Inventory.coins if id == "coins" else Inventory.count(id)
	var name_text: String = "金币" if id == "coins" else Catalog.item_name(id)
	costs.add_child(FarmUIStyle.label("%s  ·  需要 %d / 持有 %d" % [name_text,amount,held],18,FarmUIStyle.SUCCESS if held >= amount else FarmUIStyle.DANGER))

func refresh_upgrade() -> void:
	var definition: Dictionary = FarmProgress.upgrades[selected_id]
	var done: bool = FarmProgress.has_upgrade(selected_id)
	title.text = "河谷修缮台"
	subtitle.text = "已修缮 %d / %d 项  ·  木材 %d  ·  石料 %d" % [FarmProgress.built.size(),FarmProgress.upgrades.size(),Inventory.count("wood"),Inventory.count("stone")]
	heading.text = definition.name
	description.text = definition.description
	add_cost("coins",int(definition.coins))
	for id in definition.materials: add_cost(id,int(definition.materials[id]))
	reward.text = "永久生效，离开农场或重新读档后仍然保留。"
	action_button.text = "已建成" if done else "交付材料并修缮"
	action_button.disabled = done or DiamondPayments.preview(definition.materials,{},int(definition.coins)).is_empty()
	hint.text = "修缮将扣除材料与"+DiamondPayments.text(int(definition.coins))+"。钻石支付需再次确认。"

func refresh_quest() -> void:
	var definition: Dictionary = FarmProgress.quests[selected_id]
	var status: String = FarmProgress.quest_status(selected_id)
	title.text = "河谷委托板" if at_board else "委托手记"
	subtitle.text = "林芽  ·  %s  ·  好感 %d / 100" % [FarmProgress.relationship(),FarmProgress.friendship]
	heading.text = "%s · %s" % [definition.title,{"locked":"尚未解锁","available":"可以接取","active":"进行中","completed":"已完成"}[status]]
	description.text = definition.description
	for id in definition.requirements: add_cost(id,int(definition.requirements[id]))
	var rewards := "%d 金 · 好感 +%d" % [definition.coins,definition.friendship]
	for id in definition.items: rewards += " · %s ×%d" % [Catalog.item_name(id),definition.items[id]]
	reward.text = "奖励："+rewards
	action_button.disabled = not at_board or status in ["locked","completed"] or (status == "active" and not FarmProgress.ready_to_deliver(selected_id))
	action_button.text = "前往委托板办理" if not at_board else {"locked":"先完成上一份委托","available":"接下这份委托","active":"交付物品并领取奖励","completed":"已领取奖励"}[status]
	hint.text = "委托板在小屋东侧。交付会消耗所需物品，奖励只领取一次。"

func perform_action() -> void:
	if mode == "workshop":
		var id := selected_id
		DiamondPayments.request(self,int(FarmProgress.upgrades[id].coins),func(): FarmProgress.build_upgrade(id); refresh())
	elif at_board:
		if FarmProgress.quest_status(selected_id) == "available": FarmProgress.accept(selected_id)
		else: FarmProgress.deliver(selected_id)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("journal")):
		close_panel()
		get_viewport().set_input_as_handled()
