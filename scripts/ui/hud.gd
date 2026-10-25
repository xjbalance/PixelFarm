extends CanvasLayer
signal movement(direction: Vector2)
signal bag_requested
signal save_requested
signal load_requested
signal sleep_requested(expected_day: int)
signal mute_requested
var root: Control
var safe: Control
var clock_label: Label
var money_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var tool_buttons: Array[Button] = []
var prompt_label: Label
var toast: Label
var toast_time: float = 0.0
var dialogue: PanelContainer
var joystick: Control
var action_button: Button
var guide_panel: PanelContainer
var progress_label: Label
var inventory_panel: PanelContainer
var system_panel: PanelContainer
var progress_panel: PanelContainer
var story_panel: PanelContainer
var river_panel: PanelContainer
var abyss_panel: PanelContainer
var star_panel: PanelContainer
var world_development_panel: PanelContainer
var exploration_panel: PanelContainer
var housing_panel: PanelContainer
var festival_panel: PanelContainer
var social_panel: PanelContainer
var kitchen_panel: PanelContainer
var ecology_panel: PanelContainer
var fishing_panel: PanelContainer
var livestock_panel: PanelContainer
var recovery_panel: PanelContainer
var calendar_panel: PanelContainer
var aquaculture_panel: PanelContainer
var mine_panel: PanelContainer
var xiaojing_panel: PanelContainer
var quest_label: Label
var scrim: ColorRect
var completed: Dictionary = {}
var toolbar_style_selection: int = -1
var toolbar_signature: Array = []

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = FarmUIStyle.make_theme()
	add_child(root)
	safe = Control.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	build_top()
	build_controls()
	build_feedback()
	Events.notice.connect(show_notice)
	Events.farm_action.connect(on_farm_action)
	Events.tool_changed.connect(refresh_hotbar)
	GameState.changed.connect(refresh)
	GameState.control_mode_changed.connect(refresh_controls)
	Inventory.changed.connect(refresh)
	Inventory.changed.connect(refresh_hotbar)
	FarmProgress.changed.connect(refresh)
	GameClock.changed.connect(refresh)
	Story.changed.connect(refresh)
	Letters.changed.connect(refresh)
	ChapterTwo.changed.connect(refresh)
	AbyssState.changed.connect(refresh_clock)
	AbyssState.air_changed.connect(refresh_clock)
	VillageProjects.changed.connect(refresh)
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()
	refresh()
	refresh_hotbar()
	refresh_controls()

func refresh_controls() -> void:
	joystick.reset()
	joystick.visible = GameState.control_mode == "joystick"

func build_top() -> void:
	var top := HBoxContainer.new()
	place(top, Vector2(0,0), Vector2(1,0), Rect2(20,14,-40,64))
	safe.add_child(top)
	top.add_theme_constant_override("separation", 8)
	var brand := PanelContainer.new()
	brand.custom_minimum_size.x = 168
	top.add_child(brand)
	var names := VBoxContainer.new()
	brand.add_child(names)
	names.add_child(FarmUIStyle.label("像 素 世 界", 21, FarmUIStyle.TITLE))
	names.add_child(FarmUIStyle.label("Pixel World · 0.7.1", 12, FarmUIStyle.MUTED))
	var time_panel := PanelContainer.new()
	top.add_child(time_panel)
	clock_label = FarmUIStyle.label("第 1 天  ·  06:00", 17)
	time_panel.add_child(clock_label)
	var energy := PanelContainer.new()
	energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(energy)
	var energy_column := VBoxContainer.new()
	energy.add_child(energy_column)
	stamina_label = FarmUIStyle.label("体力",14)
	energy_column.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(100,12)
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", FarmUIStyle.box(Color("162f2b"), Color("162f2b"), 4))
	stamina_bar.add_theme_stylebox_override("fill", FarmUIStyle.box(Color("b4c47b"), Color("b4c47b"), 4))
	energy_column.add_child(stamina_bar)
	var purse := PanelContainer.new()
	purse.custom_minimum_size.x = 110
	top.add_child(purse)
	money_label = FarmUIStyle.label("", 20, FarmUIStyle.TITLE)
	purse.add_child(money_label)
	top.add_child(FarmUIStyle.button("背包 B", func(): bag_requested.emit(), 88))
	top.add_child(FarmUIStyle.button("委托 J",func(): progress_panel.open_panel("journal",false),88))
	top.add_child(FarmUIStyle.button("手记 M",func(): story_panel.open_panel(),88))
	top.add_child(FarmUIStyle.button("菜单", func(): system_panel.open_panel(), 72))

func build_controls() -> void:
	joystick = Control.new()
	joystick.set_script(preload("res://scripts/ui/virtual_joystick.gd"))
	place(joystick, Vector2(0,1), Vector2(0,1), Rect2(24,-194,166,166))
	safe.add_child(joystick)
	joystick.direction_changed.connect(func(direction: Vector2): movement.emit(direction))
	var toolbar := HBoxContainer.new()
	place(toolbar, Vector2(0.5,1), Vector2(0.5,1), Rect2(-368,-112,736,88))
	toolbar.add_theme_constant_override("separation", 6)
	safe.add_child(toolbar)
	for i in range(GameState.tools.size()):
		var button := FarmUIStyle.button("", GameState.select_tool.bind(i), 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		var icon := AtlasTexture.new()
		icon.atlas = load("res://assets/ui/tools.png")
		icon.region = Rect2(i*32,0,32,32)
		button.icon = load("res://assets/fishing/fishing_rod.png") if i==8 else icon
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width",26)
		toolbar.add_child(button)
		tool_buttons.append(button)
	action_button = FarmUIStyle.button("使用\nE", func(): Events.action_requested.emit(), 98)
	place(action_button, Vector2(1,1), Vector2(1,1), Rect2(-142,-150,116,116))
	action_button.add_theme_font_size_override("font_size", 23)
	action_button.add_theme_stylebox_override("normal", FarmUIStyle.surface("nature"))
	safe.add_child(action_button)
	var cycle := FarmUIStyle.button("换工具  Q", func(): GameState.select_tool(GameState.selected + 1), 116)
	place(cycle, Vector2(1,1), Vector2(1,1), Rect2(-142,-212,116,48))
	safe.add_child(cycle)

func build_feedback() -> void:
	var guide := PanelContainer.new()
	guide_panel=guide
	place(guide, Vector2(0,0), Vector2(0,0), Rect2(20,94,304,144))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(guide)
	var content := VBoxContainer.new()
	guide.add_child(content)
	content.add_child(FarmUIStyle.label("那些没有寄出的信",16,FarmUIStyle.TITLE))
	progress_label = FarmUIStyle.label("农场起步 / 在屋前开垦一块地",12)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(progress_label)
	quest_label = FarmUIStyle.label("",15,FarmUIStyle.MUTED)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(quest_label)
	prompt_label = FarmUIStyle.label("",17)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(prompt_label,Vector2(0.5,1),Vector2(0.5,1),Rect2(-320,-150,640,30))
	safe.add_child(prompt_label)
	toast = FarmUIStyle.label("",18,FarmUIStyle.TITLE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",Color("162b26"))
	toast.add_theme_constant_override("shadow_offset_x",2)
	toast.add_theme_constant_override("shadow_offset_y",2)
	place(toast,Vector2(0.5,0),Vector2(0.5,0),Rect2(-400,108,800,40))
	safe.add_child(toast)
	scrim = ColorRect.new()
	scrim.color = Color(0.04,0.10,0.08,0.42)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.hide()
	safe.add_child(scrim)
	Events.modal_changed.connect(func(active: bool): scrim.visible = active)
	dialogue = PanelContainer.new()
	dialogue.set_script(preload("res://scripts/ui/dialogue_panel.gd"))
	place(dialogue,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-480,-145,960,340))
	safe.add_child(dialogue)
	inventory_panel = PanelContainer.new()
	inventory_panel.set_script(preload("res://scripts/ui/inventory_panel.gd"))
	place(inventory_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-430,-265,860,530))
	safe.add_child(inventory_panel)
	system_panel = PanelContainer.new()
	system_panel.set_script(preload("res://scripts/ui/system_panel.gd"))
	place(system_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-310,-270,620,540))
	safe.add_child(system_panel)
	system_panel.save_requested.connect(func(): save_requested.emit())
	system_panel.load_requested.connect(func(): load_requested.emit())
	system_panel.sleep_requested.connect(func(expected_day: int): sleep_requested.emit(expected_day))
	system_panel.mute_requested.connect(func(): mute_requested.emit())
	progress_panel = PanelContainer.new()
	progress_panel.set_script(preload("res://scripts/ui/progress_panel.gd"))
	place(progress_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-450,-270,900,540))
	safe.add_child(progress_panel)
	story_panel = PanelContainer.new()
	story_panel.set_script(preload("res://scripts/ui/story_panel.gd"))
	place(story_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-480,-280,960,560))
	safe.add_child(story_panel)
	xiaojing_panel = PanelContainer.new()
	xiaojing_panel.set_script(preload("res://scripts/ui/xiaojing_panel.gd"))
	place(xiaojing_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(xiaojing_panel)
	mine_panel=PanelContainer.new()
	mine_panel.set_script(preload("res://scripts/ui/mine_panel.gd"))
	place(mine_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(mine_panel)
	star_panel=PanelContainer.new()
	star_panel.set_script(preload("res://scripts/star/star_panel.gd"))
	place(star_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(star_panel)
	abyss_panel=PanelContainer.new()
	abyss_panel.set_script(preload("res://scripts/abyss/abyss_panel.gd"))
	place(abyss_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(abyss_panel)
	river_panel=PanelContainer.new()
	river_panel.set_script(preload("res://scripts/river/river_panel.gd"))
	place(river_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(river_panel)
	aquaculture_panel=PanelContainer.new()
	aquaculture_panel.set_script(preload("res://scripts/aquaculture/aquaculture_panel.gd"))
	place(aquaculture_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(aquaculture_panel)
	calendar_panel=PanelContainer.new()
	calendar_panel.set_script(preload("res://scripts/seasons/calendar_panel.gd"))
	place(calendar_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(calendar_panel)
	recovery_panel=PanelContainer.new()
	recovery_panel.set_script(preload("res://scripts/recovery/recovery_panel.gd"))
	place(recovery_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-430,-250,860,500))
	safe.add_child(recovery_panel)
	fishing_panel=PanelContainer.new()
	fishing_panel.set_script(preload("res://scripts/fishing/fishing_panel.gd"))
	place(fishing_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(fishing_panel)
	livestock_panel=PanelContainer.new()
	livestock_panel.set_script(preload("res://scripts/livestock/livestock_panel.gd"))
	place(livestock_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(livestock_panel)
	ecology_panel=PanelContainer.new()
	ecology_panel.set_script(preload("res://scripts/ecology/ecology_panel.gd"))
	place(ecology_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(ecology_panel)
	kitchen_panel=PanelContainer.new()
	kitchen_panel.set_script(preload("res://scripts/kitchen/kitchen_panel.gd"))
	place(kitchen_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(kitchen_panel)
	festival_panel=PanelContainer.new()
	festival_panel.set_script(preload("res://scripts/festivals/festival_panel.gd"))
	place(festival_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(festival_panel)
	social_panel=PanelContainer.new()
	social_panel.set_script(preload("res://scripts/social/social_panel.gd"))
	place(social_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(social_panel)
	housing_panel=PanelContainer.new()
	housing_panel.set_script(preload("res://scripts/housing/housing_panel.gd"))
	place(housing_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-470,-290,940,580))
	safe.add_child(housing_panel)
	exploration_panel=PanelContainer.new()
	exploration_panel.set_script(preload("res://scripts/exploration/exploration_panel.gd"))
	place(exploration_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(exploration_panel)
	world_development_panel=PanelContainer.new()
	world_development_panel.set_script(preload("res://scripts/world_progress/world_development_panel.gd"))
	place(world_development_panel,Vector2(0.5,0.5),Vector2(0.5,0.5),Rect2(-460,-280,920,560))
	safe.add_child(world_development_panel)
	# 提示位于模态层上方，金币不足、奖励和保存反馈不会被遮罩盖住。
	safe.move_child(toast,-1)
	Events.modal_changed.connect(func(active: bool):
		if active: place(toast,Vector2(0.5,1),Vector2(0.5,1),Rect2(-440,-65,880,40))
		else: place(toast,Vector2(0.5,0),Vector2(0.5,0),Rect2(-400,108,800,40))
	)

func place(node: Control, start: Vector2, end: Vector2, offsets: Rect2) -> void:
	node.anchor_left = start.x
	node.anchor_top = start.y
	node.anchor_right = end.x
	node.anchor_bottom = end.y
	node.offset_left = offsets.position.x
	node.offset_top = offsets.position.y
	node.offset_right = offsets.position.x + offsets.size.x
	node.offset_bottom = offsets.position.y + offsets.size.y

func update_safe_area() -> void:
	# Android 返回物理像素安全区；换算到画布坐标，避开刘海和导航区域。
	safe.offset_left = 0
	safe.offset_top = 0
	safe.offset_right = 0
	safe.offset_bottom = 0
	if OS.get_name() == "Android":
		var area := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		apply_safe_area(Rect2(area),screen)

func apply_safe_area(area: Rect2, screen: Vector2) -> void:
	var viewport := get_viewport().get_visible_rect().size
	if screen.x > 0 and screen.y > 0 and area.size.x > 0 and area.size.y > 0:
		var ratio := viewport / screen
		safe.offset_left = area.position.x * ratio.x
		safe.offset_top = area.position.y * ratio.y
		safe.offset_right = -(screen.x - area.end.x) * ratio.x
		safe.offset_bottom = -(screen.y - area.end.y) * ratio.y

func refresh() -> void:
	# 起居侧间需要完整点选空间，农场任务卡在屋内收起。
	guide_panel.visible=GameState.location not in ["home","mist_forest","lake_ruins","old_temple"]
	refresh_clock()
	money_label.text = "%d 金" % Inventory.coins
	stamina_label.text = "体力  %d / %d" % [GameState.stamina,GameState.max_stamina()]
	stamina_bar.max_value = GameState.max_stamina()
	stamina_bar.value = GameState.stamina
	quest_label.text = Story.chapter().title+"\n"+Story.chapter().goal
	if Story.stage == 8:
		var next := Letters.next_task()
		quest_label.text = "下一页 · "+Letters.DIRECTIONS.get(Letters.direction,"到风灯架商量发展方向")
		if not next.is_empty(): quest_label.text += "\n"+str(next.title)
	if Story.stage==8 and not ChapterTwo.current().is_empty():
		quest_label.text="山谷深处的回声\n"+str(ChapterTwo.current().title)

func refresh_hotbar() -> void:
	# 工具和库存变化驱动；时钟/体力/剧情刷新无需重复设置九个相同按钮。
	var signature: Array=[GameState.selected,Inventory.count("carrot_seed"),Inventory.count("potato_seed"),Inventory.count("wheat_seed")]
	if signature==toolbar_signature: return
	toolbar_signature=signature
	for i in range(tool_buttons.size()):
		var id: String = GameState.tools[i]
		var amount := str(Inventory.count(id)) if id.ends_with("_seed") else str(i + 1)
		var empty_seed: bool=id.ends_with("_seed") and Inventory.count(id)==0
		if empty_seed: amount="0 已用完"
		var caption: String="%s\n%s" % [GameState.tool_names[i],amount]
		if tool_buttons[i].text!=caption: tool_buttons[i].text=caption
		tool_buttons[i].tooltip_text="%s · 快捷键%d%s" % [GameState.tool_names[i],i+1," · 种子已用完，请到种子摊补充" if empty_seed else ""]
		if toolbar_style_selection != GameState.selected:
			var style := FarmUIStyle.surface("selected" if i == GameState.selected else "button")
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 5
			style.content_margin_bottom = 5
			tool_buttons[i].add_theme_stylebox_override("normal",style)
	toolbar_style_selection = GameState.selected

func set_prompt(text: String, nearby: bool) -> void:
	prompt_label.text = text
	action_button.text = "交互\nE" if nearby else "使用\nE"

func show_notice(text: String) -> void:
	toast.text = text
	toast_time = 4.0

func close_active_panel() -> bool:
	# Android 系统返回键先关闭当前面板，游戏本身不意外退出。
	if dialogue.visible:
		dialogue.close_dialogue()
		return true
	for panel in [world_development_panel,exploration_panel,housing_panel,festival_panel,social_panel,kitchen_panel,ecology_panel,fishing_panel,livestock_panel,recovery_panel,calendar_panel,aquaculture_panel,river_panel,abyss_panel,star_panel,mine_panel,xiaojing_panel,story_panel,progress_panel,system_panel,inventory_panel]:
		if panel.visible:
			panel.close_panel()
			return true
	return false

func on_farm_action(kind: String) -> void:
	completed[kind] = true
	refresh_farm_guide()

func refresh_farm_guide() -> void:
	var next := "在屋前开垦一块地"
	if completed.has("翻土"): next = "选种子，播在翻好的土地上"
	if completed.has("播种"): next = "换水壶，为种子浇水"
	if completed.has("浇水"): next = "白天可歇椅恢复，20:00后回屋睡觉"
	if completed.has("收获"): next = "第一份收获！去种子摊看看吧"
	progress_label.text = "农场手记  /  " + next

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0

func refresh_clock() -> void:
	var detail: String="%s · %s" % [Story.NAMES[GameState.location],GameWeather.label()]
	if GameState.location=="abyss": detail="%d层 · 空气%d/160" % [AbyssState.state.depth,AbyssState.state.air]
	clock_label.text="%s · %s\n%s" % [Calendar.label(),GameClock.clock_text(),detail]
	clock_label.add_theme_color_override("font_color",Color("efb895") if GameState.location=="abyss" and AbyssState.state.air<30 else FarmUIStyle.TEXT)
