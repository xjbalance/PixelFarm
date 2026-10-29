extends PanelContainer
## 手记整合建设目标、真实地图和人物；共建交易仍由独立规则层校验。
var content: VBoxContainer
var title: Label
var page: int = 0
var map_location: String = "farm"
var at_board: bool = false
var tabs: Array[Button] = []
var scroll: ScrollContainer
var payment_control: Control
var map_page: VBoxContainer
var map_canvas: FarmAtlasCanvas
var map_info: Label
var map_zoom: Label
var map_detail: Button
var map_selected: Dictionary={}
var map_applied: String=""
var map_started: bool=false
var header: HBoxContainer
var navigation: HBoxContainer

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	add_child(column)
	header = HBoxContainer.new()
	column.add_child(header)
	title = FarmUIStyle.label("那些没有寄出的信",25,FarmUIStyle.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("四季历",func(): close_panel(); Events.interaction_requested.emit("calendar"),100))
	header.add_child(FarmUIStyle.button("矿道手记",func(): close_panel(); Events.interaction_requested.emit("mine:journal"),120))
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	payment_control=column.get_child(column.get_child_count()-1)
	navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation",10)
	column.add_child(navigation)
	var names := ["共建手记","河谷地图","村里的邻居","小小的记忆"]
	for i in range(names.size()):
		var button := FarmUIStyle.button(names[i],select_page.bind(i),180)
		navigation.add_child(button)
		tabs.append(button)
	scroll = ScrollContainer.new()
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	build_map_page(column)
	Story.changed.connect(refresh)
	Letters.changed.connect(refresh)
	VillageProjects.changed.connect(refresh)
	Inventory.changed.connect(refresh)

func open_panel(construction: bool = false) -> void:
	if GameState.modal: return
	at_board = construction
	page = 0
	map_location = GameState.location
	map_started=false;clear_map_selection()
	GameState.set_modal(true)
	show()
	refresh()

func close_panel() -> void:
	DiamondPayments.cancel(self)
	map_canvas.reset_gesture()
	set_meta("journal_map_open",false)
	hide()
	GameState.set_modal(false)

func select_page(index: int) -> void:
	page = clampi(index,0,3)
	refresh()

func text_row(text: String, font_size: int = 17, tint: Color = FarmUIStyle.TEXT, target: VBoxContainer=null) -> Label:
	var label := FarmUIStyle.label(text,font_size,tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(target if is_instance_valid(target) else content).add_child(label)
	return label

func refresh() -> void:
	if not visible: return
	set_meta("journal_map_open",page==1)
	apply_touch_sizes()
	scroll.visible=page!=1;map_page.visible=page==1
	payment_control.visible=page!=1
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for i in range(tabs.size()):
		tabs[i].add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if i == page else "button"))
	match page:
		0: build_story()
		1: build_map()
		2: build_people()
		3: build_memories()
	var hud:=owner_hud()
	if is_instance_valid(hud): hud.call_deferred("reflow_panels")

func apply_touch_sizes() -> void:
	var target: float=UIMetrics.minimum_target()
	for control in header.get_children():
		if control is Button: control.custom_minimum_size.y=target
	for button in tabs: button.custom_minimum_size.y=target
	for control in map_page.find_children("*","Button",true,false):
		control.custom_minimum_size=Vector2(maxf(48 if control.text in ["−","+"] else 112,target),target)
	# 高密度按钮不挤成一条不可读的小地图；有安全区余量时向上扩展手记。
	var hud:=owner_hud()
	var minimum_height: float=150
	if target>64 and is_instance_valid(hud):
		var tools: Control=map_page.get_child(0)
		var footer: Control=map_page.get_child(2)
		var spacing: float=float(get_child(0).get_theme_constant("separation"))*2+float(map_page.get_theme_constant("separation"))*2
		var other: float=header.get_combined_minimum_size().y+navigation.get_combined_minimum_size().y+tools.get_combined_minimum_size().y+footer.get_combined_minimum_size().y+spacing+get_theme_stylebox("panel").get_minimum_size().y
		minimum_height=clampf(hud.safe.size.y-24-other,150,240)
	map_canvas.custom_minimum_size.y=minimum_height

func build_story() -> void:
	text_row(Story.chapter().title,23,FarmUIStyle.TITLE)
	text_row(Story.chapter().goal)
	var requirements := Story.requirement_text()
	if requirements != "": text_row(requirements,16,FarmUIStyle.MUTED)
	text_row("公共设施 %d / 3   ·   %d 金   ·   明日%s" % [VillageProjects.built.size(),Inventory.coins,GameWeather.tomorrow()],16,FarmUIStyle.MUTED)
	for id in VillageProjects.definitions:
		var definition: Dictionary = VillageProjects.definitions[id]
		var card:=FarmUIStyle.section(content)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		card.add_child(row)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var built := VillageProjects.has_project(id)
		words.add_child(FarmUIStyle.label(("✓ " if built else "○ ")+definition.name+" · "+definition.owner,19,FarmUIStyle.TITLE))
		var detail := FarmUIStyle.label(definition.benefit,15)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(detail)
		var costs: Array[String] = []
		for item in definition.materials: costs.append("%s %d/%d" % [Catalog.item_name(item),Inventory.count(item),definition.materials[item]])
		words.add_child(FarmUIStyle.label("  ·  ".join(costs)+"  ·  %d 金" % definition.coins,16,FarmUIStyle.MUTED))
		var button := FarmUIStyle.button("已建成" if built else "一起建造",func(): DiamondPayments.request(self,int(definition.coins),func(): VillageProjects.build(id); refresh()),138)
		button.disabled = built or not at_board or Story.stage < 6
		row.add_child(button)
	text_row("读过风车建设簿后，可在村中共建板交付材料。" if Story.stage < 6 else ("大家出手艺，你来备材料。建设完成立即生效并保存。" if at_board else "到广场南边的共建板交付材料；手记随时可查看。"),16,FarmUIStyle.MUTED)


	text_row("剧情任务与线索",22,FarmUIStyle.TITLE)
	if Letters.legacy_review:
		text_row("旧版建设与奖励已保留。小屋信箱可回顾新故事，桥边、木作坊和茶屋可重访线索。",16)
	if Story.stage == 8:
		text_row("下一步优先："+Letters.DIRECTIONS.get(Letters.direction,"在风灯架商量")+"；三个方向的起步任务均开放。",17)
	for definition in Letters.definitions:
		if not Letters.conditions_met(definition.unlock) and definition.id not in Letters.completed: continue
		var card:=FarmUIStyle.section(content)
		text_row(definition.title,19,FarmUIStyle.TITLE,card)
		text_row(definition.description+"\n"+Letters.progress(definition),16,FarmUIStyle.TEXT,card)

func build_map() -> void:
	var hud:=owner_hud()
	if not is_instance_valid(hud): return
	if not map_started:
		hud.toast_time=0;hud.toast.hide()
		map_canvas.setup(hud.get_parent());map_started=true;map_applied=""
	if map_location!=map_applied:
		if map_location=="world": map_canvas.show_world()
		else: map_canvas.show_region(map_location)
		map_applied=map_location
	map_canvas.refresh_state()
	update_map_zoom()

func owner_hud() -> CanvasLayer:
	var ancestor: Node=get_parent()
	while ancestor:
		if ancestor is CanvasLayer and "story_panel" in ancestor and ancestor.story_panel==self: return ancestor
		ancestor=ancestor.get_parent()
	return null

func build_map_page(column: VBoxContainer) -> void:
	# 地图独立于TouchScroll，拖动图纸不会同时滚动旧手记正文。
	map_page=VBoxContainer.new();map_page.name="JournalParchmentPage"
	map_page.add_theme_constant_override("separation",8);map_page.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(map_page);map_page.hide()
	var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",8);map_page.add_child(tools)
	tools.add_child(FarmUIStyle.button("世界总览",show_map_world,112))
	tools.add_child(FarmUIStyle.button("当前区域",show_map_current,112))
	tools.add_child(FarmUIStyle.button("定位人物",locate_map_player,112))
	var spacer:=Control.new();spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(spacer)
	tools.add_child(FarmUIStyle.button("−",func(): map_canvas.zoom_by(1.0/1.25),48))
	map_zoom=FarmUIStyle.label("100%",16);map_zoom.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;map_zoom.custom_minimum_size.x=52;tools.add_child(map_zoom)
	tools.add_child(FarmUIStyle.button("+",func(): map_canvas.zoom_by(1.25),48))
	tools.add_child(FarmUIStyle.button("展开地图",expand_map,112))
	map_canvas=FarmAtlasCanvas.new();map_canvas.name="JournalAtlasCanvas"
	map_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	map_page.add_child(map_canvas);map_canvas.custom_minimum_size=Vector2(100,150)
	map_canvas.view_changed.connect(update_map_zoom)
	map_canvas.place_selected.connect(func(info: Dictionary):
		map_selected=info.duplicate(true)
		map_info.text=str(info.get("name","地点"))+" · "+str(info.get("description",""))
		map_detail.disabled=not bool(info.get("discovered",false)) or str(info.get("region",""))==""
	)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",8);map_page.add_child(footer)
	map_info=FarmUIStyle.label("河湾图纸 · 拖动查看、双指或＋／−缩放，点击地点读说明。",15)
	map_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;map_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_info.custom_minimum_size=Vector2(100,44);footer.add_child(map_info)
	map_detail=FarmUIStyle.button("查看详图",show_map_selected,112);map_detail.disabled=true;footer.add_child(map_detail)

func update_map_zoom() -> void:
	if is_instance_valid(map_zoom): map_zoom.text="%d%%" % roundi(map_canvas.zoom*100)

func clear_map_selection() -> void:
	map_selected.clear();map_detail.disabled=true
	map_info.text="河湾图纸 · 拖动查看、双指或＋／−缩放，点击地点读说明。"

func show_map_world() -> void:
	map_location="world";map_applied=map_location;clear_map_selection();map_canvas.show_world()

func show_map_current() -> void:
	map_location=GameState.location;map_applied=map_location;clear_map_selection();map_canvas.show_region(map_location)

func locate_map_player() -> void:
	map_canvas.center_player()
	map_location=map_canvas.region_id if map_canvas.layer_id=="region" else "world";map_applied=map_location

func show_map_selected() -> void:
	if map_detail.disabled or map_selected.is_empty(): return
	map_location=str(map_selected.region);map_applied=map_location
	map_canvas.show_region(map_location);clear_map_selection()

func expand_map() -> void:
	var hud:=owner_hud()
	if not is_instance_valid(hud): return
	var old_board: bool=at_board
	var old_layer: String=map_canvas.layer_id;var old_region: String=map_canvas.region_id
	close_panel()
	if not hud.atlas_panel.open_panel():
		open_panel(old_board);select_page(1);return
	if old_layer=="region":
		hud.atlas_panel.map_canvas.show_region(old_region)
		hud.atlas_panel.title_label.text="河湾冒险图纸 · "+FarmAtlasData.title(old_region)
	else: hud.atlas_panel.show_world()

func build_people() -> void:
	var people: Array=Story.data.people.keys()
	if Xiaojing.state.unlocked: people.append("xiaojing")
	for id in people:
		var definition: Dictionary = Story.data.people[id] if id!="xiaojing" else {"name":"小京","role":"水样与温室记录者","place":"按季节、约定和自己的研究计划出行。","about":"小京会照看水样、整理温室记录，也会独自出门。靠近后可以查看四季近况与共同计划。"}
		var card:=FarmUIStyle.section(content)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",20)
		card.add_child(row)
		var portrait := FarmPortrait.new()
		portrait.person = id
		row.add_child(portrait)
		portrait.custom_minimum_size=Vector2(88,96)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(FarmUIStyle.label(definition.name+" · "+definition.role,23,FarmUIStyle.TITLE))
		var current: Dictionary=preload("res://scripts/seasons/life_schedule.gd").locate(id)
		words.add_child(FarmUIStyle.label("现在："+str(current.get("description",definition.place)),16,FarmUIStyle.MUTED))
		var about := FarmUIStyle.label(definition.about,18)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(about)
		if Social.near_person(id): words.add_child(FarmUIStyle.button("近况、礼物与个人计划",func(): close_panel();Events.interaction_requested.emit("social:"+id),240))
		var bond := "你们还在慢慢认识彼此。" if Story.stage < 5 else "共同修好的桥，让相聚少了一段绕路。"
		if Story.stage == 8: bond = "共同建成的村庄，已经有了你的位置。"
		words.add_child(FarmUIStyle.label(bond,16,FarmUIStyle.MUTED))

func build_memories() -> void:
	text_row("村庄的未来，也长在这些小事上。",21,FarmUIStyle.TITLE)
	for id in Story.SECRET_IDS:
		var entry: Dictionary = Story.data.scenes[id]
		var card:=FarmUIStyle.section(content)
		text_row(entry.title if id in Story.seen else "尚未遇见的一件小事",20,FarmUIStyle.TITLE,card)
		text_row(entry.lines[0].text if id in Story.seen else {"well":"去井边看看旧刻痕。","ribbon":"过桥后，留意树上的蓝丝带。","post":"茶屋西南边的木牌夹着一张明信片。"}[id],17,FarmUIStyle.TEXT,card)
	if Story.stage == 8: text_row("风灯持续亮着。下一页："+Letters.DIRECTIONS.get(Letters.direction,"在风灯架商量新的方向"),18,FarmUIStyle.MUTED)
	for id in ["bridge_survey","repair_record","guestbook","cargo_note"]:
		var card:=FarmUIStyle.section(content)
		text_row(Story.data.scenes[id].title if Letters.knows(id) else "待发现的线索",19,FarmUIStyle.TITLE,card)
		text_row(Story.data.scenes[id].lines[0].text if Letters.knows(id) else {"bridge_survey":"旧桥西侧的水位牌。","repair_record":"木作坊檐下的铁盒。","guestbook":"和阿禾谈茶屋留言册。","cargo_note":"河东风车旁的旧货箱。"}[id],16,FarmUIStyle.TEXT,card)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("story_map")):
		close_panel()
		get_viewport().set_input_as_handled()
