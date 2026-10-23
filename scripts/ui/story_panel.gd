extends PanelContainer
## 手记整合建设目标、真实地图和人物；共建交易仍由独立规则层校验。
var content: VBoxContainer
var title: Label
var page: int = 0
var map_location: String = "farm"
var at_board: bool = false
var tabs: Array[Button] = []

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = FarmUIStyle.label("那些没有寄出的信",25,FarmUIStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("四季历",func(): close_panel(); Events.interaction_requested.emit("calendar"),100))
	header.add_child(FarmUIStyle.button("矿道手记",func(): close_panel(); Events.interaction_requested.emit("mine:journal"),120))
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",10)
	column.add_child(navigation)
	var names := ["共建手记","河谷地图","村里的邻居","小小的记忆"]
	for i in range(names.size()):
		var button := FarmUIStyle.button(names[i],select_page.bind(i),180)
		navigation.add_child(button)
		tabs.append(button)
	var scroll := ScrollContainer.new()
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	Story.changed.connect(refresh)
	Letters.changed.connect(refresh)
	VillageProjects.changed.connect(refresh)
	Inventory.changed.connect(refresh)

func open_panel(construction: bool = false) -> void:
	if GameState.modal: return
	at_board = construction
	page = 0
	map_location = "village" if GameState.location == "village" else "farm"
	GameState.set_modal(true)
	show()
	refresh()

func close_panel() -> void:
	DiamondPayments.cancel(self)
	hide()
	GameState.set_modal(false)

func select_page(index: int) -> void:
	page = index
	refresh()

func text_row(text: String, font_size: int = 17, tint: Color = FarmUIStyle.CREAM) -> Label:
	var label := FarmUIStyle.label(text,font_size,tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func refresh() -> void:
	if not visible: return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for i in range(tabs.size()):
		tabs[i].add_theme_stylebox_override("normal",FarmUIStyle.box(FarmUIStyle.GREEN if i == page else FarmUIStyle.INK))
	match page:
		0: build_story()
		1: build_map()
		2: build_people()
		3: build_memories()

func build_story() -> void:
	text_row(Story.chapter().title,23,FarmUIStyle.GOLD)
	text_row(Story.chapter().goal)
	var requirements := Story.requirement_text()
	if requirements != "": text_row(requirements,16,Color("b7ce99"))
	text_row("公共设施 %d / 3   ·   %d 金   ·   明日%s" % [VillageProjects.built.size(),Inventory.coins,GameWeather.tomorrow()],16,Color("b7c6ab"))
	for id in VillageProjects.definitions:
		var definition: Dictionary = VillageProjects.definitions[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		content.add_child(row)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var built := VillageProjects.has_project(id)
		words.add_child(FarmUIStyle.label(("✓ " if built else "○ ")+definition.name+" · "+definition.owner,19,FarmUIStyle.GOLD))
		var detail := FarmUIStyle.label(definition.benefit,15)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(detail)
		var costs: Array[String] = []
		for item in definition.materials: costs.append("%s %d/%d" % [Catalog.item_name(item),Inventory.count(item),definition.materials[item]])
		words.add_child(FarmUIStyle.label("  ·  ".join(costs)+"  ·  %d 金" % definition.coins,14,Color("afc29e")))
		var button := FarmUIStyle.button("已建成" if built else "一起建造",func(): DiamondPayments.request(self,int(definition.coins),func(): VillageProjects.build(id); refresh()),138)
		button.disabled = built or not at_board or Story.stage < 6
		row.add_child(button)
	text_row("读过风车建设簿后，可在村中共建板交付材料。" if Story.stage < 6 else ("大家出手艺，你来备材料。建设完成立即生效并保存。" if at_board else "到广场南边的共建板交付材料；手记随时可查看。"),14,Color("b7c6ab"))


	text_row("剧情任务与线索",22,FarmUIStyle.GOLD)
	if Letters.legacy_review:
		text_row("旧版建设与奖励已保留。小屋信箱可回顾新故事，桥边、木作坊和茶屋可重访线索。",16)
	if Story.stage == 8:
		text_row("下一步优先："+Letters.DIRECTIONS.get(Letters.direction,"在风灯架商量")+"；三个方向的起步任务均开放。",17)
	for definition in Letters.definitions:
		if not Letters.conditions_met(definition.unlock) and definition.id not in Letters.completed: continue
		text_row(definition.title,19,FarmUIStyle.GOLD)
		text_row(definition.description+"\n"+Letters.progress(definition),16)

func build_map() -> void:
	var locations := HBoxContainer.new()
	content.add_child(locations)
	for id in ["farm","village"]:
		locations.add_child(FarmUIStyle.button(Story.NAMES[id],func(): map_location = id; refresh(),180))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	content.add_child(row)
	var map := FarmRiverMap.new()
	map.location = map_location
	row.add_child(map)
	var caption := FarmUIStyle.label("白点：你的位置\n金环：当前主线目标\n\n农场北面的路牌通往村庄；村庄南边可回农场。\n\n河东要修好旧桥才能通行。\n\n第 %d 天 · %s\n今日%s，明日%s" % [GameClock.day,GameClock.clock_text(),GameWeather.label(),GameWeather.tomorrow()],17)
	caption.custom_minimum_size.x = 250
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(caption)

func build_people() -> void:
	for id in Story.data.people:
		var definition: Dictionary = Story.data.people[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",20)
		content.add_child(row)
		var portrait := FarmPortrait.new()
		portrait.person = id
		row.add_child(portrait)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(FarmUIStyle.label(definition.name+" · "+definition.role,23,FarmUIStyle.GOLD))
		words.add_child(FarmUIStyle.label(definition.place,16,Color("b6c69e")))
		var about := FarmUIStyle.label(definition.about,18)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(about)
		var bond := "你们还在慢慢认识彼此。" if Story.stage < 5 else "共同修好的桥，让相聚少了一段绕路。"
		if Story.stage == 8: bond = "共同建成的村庄，已经有了你的位置。"
		words.add_child(FarmUIStyle.label(bond,16,Color("b6c69e")))

func build_memories() -> void:
	text_row("村庄的未来，也长在这些小事上。",21,FarmUIStyle.GOLD)
	for id in Story.SECRET_IDS:
		var entry: Dictionary = Story.data.scenes[id]
		text_row(entry.title if id in Story.seen else "尚未遇见的一件小事",20,FarmUIStyle.GOLD)
		text_row(entry.lines[0].text if id in Story.seen else {"well":"去井边看看旧刻痕。","ribbon":"过桥后，留意树上的蓝丝带。","post":"茶屋西南边的木牌夹着一张明信片。"}[id])
	if Story.stage == 8: text_row("风灯持续亮着。下一页："+Letters.DIRECTIONS.get(Letters.direction,"在风灯架商量新的方向"),18,Color("b6c69e"))
	for id in ["bridge_survey","repair_record","guestbook","cargo_note"]:
		text_row(Story.data.scenes[id].title if Letters.knows(id) else "待发现的线索",19,FarmUIStyle.GOLD)
		text_row(Story.data.scenes[id].lines[0].text if Letters.knows(id) else {"bridge_survey":"旧桥西侧的水位牌。","repair_record":"木作坊檐下的铁盒。","guestbook":"和阿禾谈茶屋留言册。","cargo_note":"河东风车旁的旧货箱。"}[id],16)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("story_map")):
		close_panel()
		get_viewport().set_input_as_handled()
