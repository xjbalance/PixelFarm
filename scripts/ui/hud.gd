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
var guide_toggle: Button
var guide_collapsed: bool = true
var toolbar: GridContainer
var cycle_button: Button
var top_cluster: HBoxContainer
var top_right: HBoxContainer
var date_label: Label
var weather_label: Label
var tool_name_label: Label
var hotbar_expanded: bool = false
var camera_return_button: Button
var menu_button: Button

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
	Events.modal_changed.connect(func(active: bool):
		if active: collapse_hotbar()
	)
	Events.location_changed.connect(func(_id: String): collapse_hotbar())
	Events.notice.connect(show_notice)
	Events.farm_action.connect(on_farm_action)
	Events.tool_changed.connect(on_tool_changed)
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
	safe.resized.connect(reflow_touch_controls)
	update_safe_area()
	refresh()
	refresh_hotbar()
	refresh_controls()

func refresh_controls() -> void:
	joystick.reset()
	joystick.visible = GameState.control_mode == "joystick"
	if is_instance_valid(toolbar): collapse_hotbar()

func build_top() -> void:
	# 状态只占两个角落，不再让一条全宽HBox挡住地图顶边。
	top_cluster=HBoxContainer.new();top_cluster.mouse_filter=Control.MOUSE_FILTER_IGNORE
	top_cluster.add_theme_constant_override("separation",4)
	place(top_cluster,Vector2.ZERO,Vector2.ZERO,Rect2(12,12,260,48));safe.add_child(top_cluster)
	var calendar_panel:=status_panel();top_cluster.add_child(calendar_panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",0);calendar_panel.add_child(column)
	var day_row:=HBoxContainer.new();day_row.add_theme_constant_override("separation",4);column.add_child(day_row)
	day_row.add_child(status_icon("date"));date_label=FarmUIStyle.label("春1日",15);day_row.add_child(date_label)
	var weather_row:=HBoxContainer.new();weather_row.add_theme_constant_override("separation",4);column.add_child(weather_row)
	weather_row.add_child(status_icon("weather"));weather_label=FarmUIStyle.label("晴朗",14,FarmUIStyle.MUTED);weather_row.add_child(weather_label)
	var energy:=status_panel();top_cluster.add_child(energy)
	var energy_column:=VBoxContainer.new();energy_column.add_theme_constant_override("separation",1);energy.add_child(energy_column)
	var energy_row:=HBoxContainer.new();energy_row.add_theme_constant_override("separation",4);energy_column.add_child(energy_row)
	energy_row.add_child(status_icon("stamina"));stamina_label=FarmUIStyle.label("100 / 100",14);energy_row.add_child(stamina_label)
	stamina_bar=ProgressBar.new();stamina_bar.custom_minimum_size=Vector2(84,7);stamina_bar.show_percentage=false
	energy_column.add_child(stamina_bar)
	top_right=HBoxContainer.new();top_right.mouse_filter=Control.MOUSE_FILTER_IGNORE
	top_right.alignment=BoxContainer.ALIGNMENT_END
	top_right.add_theme_constant_override("separation",4)
	place(top_right,Vector2(1,0),Vector2(1,0),Rect2(-264,12,252,48));safe.add_child(top_right)
	var time_panel:=status_panel();top_right.add_child(time_panel)
	clock_label=FarmUIStyle.label("06:00",16);time_panel.add_child(clock_label)
	var purse:=status_panel();top_right.add_child(purse)
	var money_row:=HBoxContainer.new();money_row.add_theme_constant_override("separation",4);purse.add_child(money_row)
	money_row.add_child(status_icon("coin"));money_label=FarmUIStyle.label("0",15,FarmUIStyle.TITLE);money_row.add_child(money_label)
	var menu:=FarmUIStyle.button("菜单",func(): system_panel.open_panel(),48)
	menu_button=menu
	menu.add_theme_font_size_override("font_size",14)
	var menu_style:=FarmUIStyle.surface("button");menu_style.content_margin_left=6;menu_style.content_margin_right=6
	menu.add_theme_stylebox_override("normal",menu_style);top_right.add_child(menu)

func status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style:=FarmUIStyle.surface("paper")
	style.content_margin_left=6;style.content_margin_right=6
	style.content_margin_top=4;style.content_margin_bottom=4
	panel.add_theme_stylebox_override("panel",style)
	return panel

func status_icon(id: String) -> TextureRect:
	var icon:=TextureRect.new()
	icon.texture=load("res://assets/ui/river/icon_"+id+".png")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(16,16)
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return icon

func build_controls() -> void:
	joystick = Control.new()
	joystick.set_script(preload("res://scripts/ui/virtual_joystick.gd"))
	place(joystick, Vector2(0,1), Vector2(0,1), Rect2(24,-194,166,166))
	safe.add_child(joystick)
	joystick.direction_changed.connect(func(direction: Vector2): movement.emit(direction))
	toolbar = GridContainer.new()
	toolbar.columns=3
	place(toolbar, Vector2(0.5,1), Vector2(0.5,1), Rect2(-368,-112,736,88))
	toolbar.add_theme_constant_override("h_separation",4)
	toolbar.add_theme_constant_override("v_separation",4)
	safe.add_child(toolbar)
	for i in range(GameState.tools.size()):
		var button := FarmUIStyle.button("", GameState.select_tool.bind(i), 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		var icon := AtlasTexture.new()
		icon.atlas = load("res://assets/ui/tools.png")
		icon.region = Rect2(i*32,0,32,32)
		button.icon = tool_badge(load("res://assets/fishing/fishing_rod.png") if i==8 else icon)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",UILayout.TOOL_ICON)
		toolbar.add_child(button)
		tool_buttons.append(button)
	action_button = FarmUIStyle.button("使用\nE", func(): Events.action_requested.emit(), 98)
	place(action_button, Vector2(1,1), Vector2(1,1), Rect2(-142,-150,116,116))
	action_button.add_theme_font_size_override("font_size", 23)
	action_button.add_theme_stylebox_override("normal", FarmUIStyle.surface("nature"))
	safe.add_child(action_button)
	var cycle := FarmUIStyle.button("＋",toggle_hotbar,48)
	cycle_button=cycle
	place(cycle, Vector2(1,1), Vector2(1,1), Rect2(-142,-212,116,48))
	safe.add_child(cycle)
	tool_name_label=FarmUIStyle.label("",12,FarmUIStyle.TEXT)
	tool_name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tool_name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var name_style:=FarmUIStyle.surface("paper")
	name_style.content_margin_left=4;name_style.content_margin_right=4
	name_style.content_margin_top=0;name_style.content_margin_bottom=0
	tool_name_label.add_theme_stylebox_override("normal",name_style)
	safe.add_child(tool_name_label)

func tool_badge(source: Texture2D) -> Texture2D:
	# 原工具贴图保持不变，只在一次性显示纹理中衬深色底，提高浅色工具对比。
	var original: Image=source.atlas.get_image() if source is AtlasTexture else source.get_image()
	if original.is_compressed(): original.decompress()
	if source is AtlasTexture: original=original.get_region(Rect2i(source.region))
	if original.get_format()!=Image.FORMAT_RGBA8: original.convert(Image.FORMAT_RGBA8)
	var badge:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	badge.fill(Color("425b4b"))
	for point in range(32):
		for edge in [Vector2i(point,0),Vector2i(point,31),Vector2i(0,point),Vector2i(31,point)]: badge.set_pixelv(edge,Color("81765c"))
	badge.blend_rect(original,Rect2i(0,0,32,32),Vector2i.ZERO)
	return ImageTexture.create_from_image(badge)

func build_feedback() -> void:
	var guide := PanelContainer.new()
	guide_panel=guide
	guide.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var guide_style:=FarmUIStyle.surface("paper")
	guide_style.content_margin_left=4;guide_style.content_margin_right=4
	guide_style.content_margin_top=4;guide_style.content_margin_bottom=4
	guide.add_theme_stylebox_override("panel",guide_style)
	place(guide, Vector2(0,0), Vector2(0,0), Rect2(20,94,304,144))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(guide)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",2)
	guide.add_child(content)
	guide_toggle=FarmUIStyle.button("任务 ▸",toggle_guide,120)
	guide_toggle.icon=load("res://assets/ui/river/icon_task.png")
	guide_toggle.expand_icon=true
	guide_toggle.add_theme_constant_override("icon_max_width",16)
	guide_toggle.add_theme_font_size_override("font_size",14)
	guide_toggle.add_theme_stylebox_override("normal",FarmUIStyle.surface("secondary"))
	content.add_child(guide_toggle)
	progress_label = FarmUIStyle.label("农场起步 / 在屋前开垦一块地",14)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(progress_label)
	quest_label = FarmUIStyle.label("",13,FarmUIStyle.MUTED)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(quest_label)
	progress_label.hide();quest_label.hide()
	prompt_label = FarmUIStyle.label("",15)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	prompt_label.max_lines_visible=2
	prompt_label.add_theme_stylebox_override("normal",bubble_style())
	place(prompt_label,Vector2(0.5,1),Vector2(0.5,1),Rect2(-320,-178,640,52))
	safe.add_child(prompt_label)
	toast = FarmUIStyle.label("",16,FarmUIStyle.TITLE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.max_lines_visible=2
	toast.add_theme_stylebox_override("normal",bubble_style())
	place(toast,Vector2(0.5,0),Vector2(0.5,0),Rect2(-400,108,800,56))
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
	system_panel.bag_requested.connect(func(): bag_requested.emit())
	system_panel.journal_requested.connect(func(): progress_panel.open_panel("journal",false))
	system_panel.story_requested.connect(func(): story_panel.open_panel())
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
		if active: place(toast,Vector2(0.5,1),Vector2(0.5,1),Rect2(-440,-70,880,56))
		else: place(toast,Vector2(0.5,0),Vector2(0.5,0),Rect2(-400,108,800,56))
	)

func bubble_style() -> StyleBoxTexture:
	var style:=FarmUIStyle.surface("paper")
	style.content_margin_left=12;style.content_margin_right=12
	style.content_margin_top=5;style.content_margin_bottom=5
	return style

func toggle_guide() -> void:
	guide_collapsed=not guide_collapsed
	guide_toggle.text="任务 ▸" if guide_collapsed else "任务手记 ▾"
	progress_label.visible=not guide_collapsed
	quest_label.visible=not guide_collapsed
	reflow_touch_controls()

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
	call_deferred("reflow_touch_controls")

func reflow_touch_controls() -> void:
	if not is_instance_valid(toolbar) or not is_instance_valid(cycle_button): return
	var edge: float=UILayout.SAFE_EDGE
	var slot: float=UILayout.slot_size()
	var grid_width: float=slot*3+8
	var grid_height: float=slot*3+8 if hotbar_expanded else slot
	for button in tool_buttons: button.custom_minimum_size=Vector2(slot,slot)
	toolbar.columns=3
	place(toolbar,Vector2(1,1),Vector2(1,1),Rect2(-edge-slot-4-grid_width,-edge-grid_height,grid_width,grid_height))
	place(cycle_button,Vector2(1,1),Vector2(1,1),Rect2(-edge-slot,-edge-slot,slot,slot))
	cycle_button.custom_minimum_size=Vector2(slot,slot)
	var action_edge: float=maxf(64,slot)
	place(action_button,Vector2(1,1),Vector2(1,1),Rect2(-edge-slot-4-grid_width-8-action_edge,-edge-action_edge,action_edge,action_edge))
	action_button.custom_minimum_size=Vector2(action_edge,action_edge)
	action_button.add_theme_font_size_override("font_size",16)
	place(tool_name_label,Vector2(1,1),Vector2(1,1),Rect2(-edge-slot-4-grid_width,-edge-grid_height-24,grid_width,20))
	place(joystick,Vector2(0,1),Vector2(0,1),Rect2(edge,-edge-166,166,166))
	place(prompt_label,Vector2(.5,1),Vector2(.5,1),Rect2(-200,-edge-slot-68,400,40))
	var header_height: float=maxf(48,slot)
	menu_button.custom_minimum_size=Vector2(slot,slot)
	place(top_cluster,Vector2.ZERO,Vector2.ZERO,Rect2(edge,edge,228,header_height))
	var right_width: float=maxf(248,200+slot)
	place(top_right,Vector2(1,0),Vector2(1,0),Rect2(-edge-right_width,edge,right_width,header_height))
	var guide_height: float=slot+8 if guide_collapsed else maxf(156,slot+88)
	place(guide_panel,Vector2(0,1),Vector2(0,1),Rect2(edge,-edge-guide_height,124 if guide_collapsed else 304,guide_height))
	guide_toggle.custom_minimum_size=Vector2(100,slot)
	if GameState.control_mode=="joystick":
		guide_panel.offset_top-=178;guide_panel.offset_bottom-=178
	position_camera_return(true)

func toggle_hotbar() -> void:
	if hotbar_expanded: collapse_hotbar()
	else: expand_hotbar()

func expand_hotbar() -> void:
	hotbar_expanded=true
	arrange_hotbar()

func collapse_hotbar() -> void:
	hotbar_expanded=false
	arrange_hotbar()

func arrange_hotbar() -> void:
	if not is_instance_valid(toolbar): return
	var order: Array[int]=[]
	if hotbar_expanded:
		for i in range(tool_buttons.size()): order.append(i)
	else:
		order=[posmod(GameState.selected-1,tool_buttons.size()),GameState.selected,posmod(GameState.selected+1,tool_buttons.size())]
	for i in range(tool_buttons.size()): tool_buttons[i].visible=i in order
	for place_index in range(order.size()): toolbar.move_child(tool_buttons[order[place_index]],place_index)
	cycle_button.text="−" if hotbar_expanded else "＋"
	cycle_button.tooltip_text="收起工具" if hotbar_expanded else "展开全部九个工具（1—9 / Q仍可切换）"
	if is_instance_valid(tool_name_label): tool_name_label.text=GameState.tool_names[GameState.selected]+(" · 已用完" if GameState.tool().ends_with("_seed") and Inventory.count(GameState.tool())==0 else "")
	reflow_touch_controls()

func on_tool_changed() -> void:
	collapse_hotbar()
	refresh_hotbar()

func position_camera_return(force: bool = false) -> void:
	var owner_game:=get_parent()
	if not "camera_rig" in owner_game or not is_instance_valid(owner_game.camera_rig): return
	var button: Button=owner_game.camera_rig.return_button
	if not is_instance_valid(button) or (not force and button==camera_return_button): return
	camera_return_button=button
	var slot: float=UILayout.slot_size()
	button.text="回中";button.custom_minimum_size=Vector2(slot,slot)
	button.add_theme_font_size_override("font_size",14)
	var style:=FarmUIStyle.surface("secondary");style.content_margin_left=4;style.content_margin_right=4
	button.add_theme_stylebox_override("normal",style)
	var height: float=slot*3+8 if hotbar_expanded else slot
	place(button,Vector2(1,1),Vector2(1,1),Rect2(-UILayout.SAFE_EDGE-slot,-UILayout.SAFE_EDGE-height-8-slot,slot,slot))

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
	stamina_label.text = "%d / %d" % [GameState.stamina,GameState.max_stamina()]
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
		if empty_seed: amount="0"
		var caption: String=amount
		if tool_buttons[i].text!=caption: tool_buttons[i].text=caption
		tool_buttons[i].tooltip_text="%s · 快捷键%d%s" % [GameState.tool_names[i],i+1," · 种子已用完，请到种子摊补充" if empty_seed else ""]
		if toolbar_style_selection != GameState.selected:
			var style := FarmUIStyle.surface("selected" if i == GameState.selected else "button")
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			tool_buttons[i].add_theme_stylebox_override("normal",style)
	toolbar_style_selection = GameState.selected
	arrange_hotbar()

func set_prompt(text: String, nearby: bool) -> void:
	prompt_label.text = text
	prompt_label.visible=not text.is_empty() and not text.begins_with("对准脚前亮框")
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
	prompt_label.visible = not GameState.modal and not prompt_label.text.is_empty() and not prompt_label.text.begins_with("对准脚前亮框")
	position_camera_return()

func refresh_clock() -> void:
	clock_label.text=GameClock.clock_text()
	clock_label.tooltip_text=Calendar.label()+" · "+Story.NAMES[GameState.location]
	date_label.text="%s%d日" % [Calendar.SEASON_NAMES[Calendar.season()],Calendar.day_of_season()]
	date_label.tooltip_text=Calendar.label()
	weather_label.text=GameWeather.label()
	weather_label.tooltip_text=Story.NAMES[GameState.location]+" · "+GameWeather.label()
	clock_label.add_theme_color_override("font_color",FarmUIStyle.DANGER if GameState.location=="abyss" and AbyssState.state.air<30 else FarmUIStyle.TEXT)
