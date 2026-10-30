extends CanvasLayer
signal movement(direction: Vector2)
signal bag_requested
signal save_requested
signal load_requested
signal sleep_requested(expected_day: int)
signal mute_requested
signal home_return_requested
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
var workshop_panel: PanelContainer
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
var guide_collapsed: bool = false
var toolbar: GridContainer
var cycle_button: Button
var top_cluster: HBoxContainer
var menu_button: Button
var hotbar_expanded: bool = true
var camera_return_button: Button
var atlas_panel: PanelContainer
var atlas_button: Button
var character_select_panel: PanelContainer
var home_return_button: Button

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
	safe.resized.connect(reflow_touch_controls)
	safe.resized.connect(reflow_panels)
	top_cluster.resized.connect(layout_header_dependents)
	update_safe_area()
	refresh()
	refresh_hotbar()
	refresh_controls()

func refresh_controls() -> void:
	joystick.reset()
	joystick.visible = GameState.control_mode == "joystick"

func build_top() -> void:
	var top := HBoxContainer.new()
	top_cluster=top
	place(top, Vector2(0,0), Vector2(1,0), Rect2(20,12,-40,60))
	safe.add_child(top)
	top.add_theme_constant_override("separation", 6)
	var brand := status_panel()
	brand.custom_minimum_size.x = 136
	top.add_child(brand)
	var names := VBoxContainer.new()
	brand.add_child(names)
	names.add_child(FarmUIStyle.label("像 素 世 界", 18, FarmUIStyle.TITLE))
	names.add_child(FarmUIStyle.label("Pixel World · "+str(ProjectSettings.get_setting("application/config/version")), 12, FarmUIStyle.MUTED))
	var time_panel := status_panel()
	top.add_child(time_panel)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation",6)
	time_panel.add_child(time_row)
	var time_icons := VBoxContainer.new()
	time_icons.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	time_icons.add_theme_constant_override("separation",4)
	time_icons.add_child(status_icon("date"));time_icons.add_child(status_icon("weather"))
	time_row.add_child(time_icons)
	clock_label = FarmUIStyle.label("第 1 天  ·  06:00", 16)
	time_row.add_child(clock_label)
	var energy := status_panel()
	energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(energy)
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation",6)
	energy.add_child(energy_row)
	energy_row.add_child(status_icon("stamina"))
	var energy_column := VBoxContainer.new()
	energy_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	energy_row.add_child(energy_column)
	stamina_label = FarmUIStyle.label("体力",15)
	energy_column.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(76,10)
	stamina_bar.show_percentage = false
	energy_column.add_child(stamina_bar)
	var purse := status_panel()
	top.add_child(purse)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation",6)
	purse.add_child(money_row)
	money_row.add_child(status_icon("coin"))
	money_label = FarmUIStyle.label("", 17, FarmUIStyle.TITLE)
	money_row.add_child(money_label)
	top.add_child(FarmUIStyle.button("背包 B", func(): bag_requested.emit(), 88))
	top.add_child(FarmUIStyle.button("委托 J",func(): progress_panel.open_panel("journal",false),88))
	top.add_child(FarmUIStyle.button("手记",func(): story_panel.open_panel(),88))
	menu_button = FarmUIStyle.button("菜单", func(): system_panel.open_panel(), 72)
	top.add_child(menu_button)
	atlas_button=FarmUIStyle.button("",func(): atlas_panel.open_panel(),48)
	atlas_button.name="MapButton";atlas_button.tooltip_text="展开河湾地图 · M"
	atlas_button.icon=load("res://assets/ui/map_fold.svg")
	atlas_button.expand_icon=true;atlas_button.add_theme_constant_override("icon_max_width",24)
	safe.add_child(atlas_button)
	home_return_button=FarmUIStyle.button("回家",func(): home_return_requested.emit(),80)
	home_return_button.name="HomeReturnButton";home_return_button.icon=load("res://assets/ui/home_return.svg")
	home_return_button.add_theme_constant_override("icon_max_width",18);home_return_button.add_theme_font_size_override("font_size",17)
	home_return_button.expand_icon=true
	for spec in [["normal","button"],["hover","hover"],["pressed","pressed"],["disabled","disabled"],["focus","focus"]]:
		var style:=FarmUIStyle.surface(spec[1]);style.content_margin_left=8;style.content_margin_right=8
		home_return_button.add_theme_stylebox_override(spec[0],style)
	safe.add_child(home_return_button)

func status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style:=FarmUIStyle.surface("paper")
	style.content_margin_left=10;style.content_margin_right=10
	style.content_margin_top=6;style.content_margin_bottom=6
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
	toolbar.columns=9
	place(toolbar, Vector2(0.5,1), Vector2(0.5,1), Rect2(-368,-112,736,88))
	toolbar.add_theme_constant_override("h_separation",6)
	toolbar.add_theme_constant_override("v_separation",8)
	safe.add_child(toolbar)
	for i in range(GameState.tools.size()):
		var button := FarmUIStyle.button("", GameState.select_tool.bind(i), 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		var icon := AtlasTexture.new()
		icon.atlas = load("res://assets/ui/tools.png")
		icon.region = Rect2(i*32,0,32,32)
		button.icon = tool_badge(load("res://assets/fishing/fishing_rod.png") if i==8 else icon)
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
	cycle_button=cycle
	place(cycle, Vector2(1,1), Vector2(1,1), Rect2(-142,-212,116,48))
	safe.add_child(cycle)

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
	place(guide, Vector2(0,0), Vector2(0,0), Rect2(20,94,304,144))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(guide)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",2)
	guide.add_child(content)
	guide_toggle=FarmUIStyle.button(guide_title(),toggle_guide,180)
	guide_toggle.icon=load("res://assets/ui/river/icon_task.png")
	guide_toggle.expand_icon=true
	guide_toggle.add_theme_constant_override("icon_max_width",18)
	guide_toggle.add_theme_font_size_override("font_size",14)
	guide_toggle.add_theme_stylebox_override("normal",FarmUIStyle.surface("secondary"))
	content.add_child(guide_toggle)
	progress_label = FarmUIStyle.label("农场起步 / 在屋前开垦一块地",14)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(progress_label)
	quest_label = FarmUIStyle.label("",13,FarmUIStyle.MUTED)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(quest_label)
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
	dialogue.minimum_size_changed.connect(func(): call_deferred("reflow_panels"))
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
	workshop_panel=PanelContainer.new();workshop_panel.set_script(preload("res://scripts/kitchen/workshop_panel.gd"))
	place(workshop_panel,Vector2(.5,.5),Vector2(.5,.5),Rect2(-460,-280,920,560));safe.add_child(workshop_panel)
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
	atlas_panel=PanelContainer.new()
	atlas_panel.set_script(preload("res://scripts/maps/atlas_panel.gd"))
	safe.add_child(atlas_panel)
	# 提示位于模态层上方，金币不足、奖励和保存反馈不会被遮罩盖住。
	safe.move_child(toast,-1)
	Events.modal_changed.connect(func(active: bool):
		call_deferred("reflow_panels")
		if active: place(toast,Vector2(0.5,1),Vector2(0.5,1),Rect2(-440,-70,880,56))
		else: place(toast,Vector2(0.5,0),Vector2(0.5,0),Rect2(-400,108,800,56))
	)

func reflow_panels() -> void:
	if not is_instance_valid(dialogue): return
	for panel in get_tree().get_nodes_in_group("modal_panels"):
		if not safe.is_ancestor_of(panel): continue
		if panel.get_meta("territory_editor",false):
			panel.controller.layout_panel();continue
		if panel.get_meta("home_editor",false):
			panel.controller.layout_panel();continue
		if panel.get_meta("parchment_atlas",false):
			panel.layout_panel();continue
		if panel.get_meta("character_select",false):
			panel.layout_panel();continue
		if panel.get_meta("journal_map_open",false):
			var extent: Vector2=(safe.size-Vector2(24,24)).min(Vector2(1440,900))
			place(panel,Vector2(.5,.5),Vector2(.5,.5),Rect2(-extent/2,extent));continue
		var kind: String="default"
		if panel==inventory_panel: kind="inventory"
		elif panel==system_panel: kind="system"
		elif panel==progress_panel: kind="journal"
		elif panel==story_panel: kind="story"
		elif panel==dialogue: kind="dialogue"
		elif panel==recovery_panel: kind="reading"
		elif panel==housing_panel: kind="housing"
		var extent:=UILayout.panel_size(safe.size,kind)
		var home_confirm: bool=panel.get_meta("home_confirmation",false) or (panel==system_panel and system_panel.sleep_mode and GameState.location=="home")
		if home_confirm:
			extent=Vector2(minf(620,safe.size.x-48),minf(float(panel.get_meta("home_confirmation_height",300+maxf(0,UIMetrics.minimum_target()-48)*2)),safe.size.y-48))
		# 只在对话换行宽度稳定后采纳最小高度，保证后出现的选项也完整显示。
		if panel!=dialogue and not home_confirm:
			extent=extent.max(panel.get_combined_minimum_size())
		elif panel==dialogue and absf(panel.size.x-extent.x)<1 and dialogue.body_label.size.x>300:
			extent.y=maxf(extent.y,panel.get_combined_minimum_size().y)
		extent=extent.min(safe.size-Vector2.ONE*UILayout.SAFE_EDGE*2)
		# 经典对话位于中央下方25px；高密度/多选项时保持在安全区内。
		var center_offset: float=clampf(25,0,maxf(0,(safe.size.y-extent.y)/2-UILayout.SAFE_EDGE)) if panel==dialogue else 0
		place(panel,Vector2(.5,.5),Vector2(.5,.5),Rect2(-extent/2+Vector2(0,center_offset),extent))

func bubble_style() -> StyleBoxTexture:
	var style:=FarmUIStyle.surface("paper")
	style.content_margin_left=12;style.content_margin_right=12
	style.content_margin_top=5;style.content_margin_bottom=5
	return style

func guide_title() -> String:
	if OS.get_name()=="Windows": return "任务手记 "+("+" if guide_collapsed else "-")
	return "任务手记 ▸" if guide_collapsed else "任务手记 ▾"

func toggle_guide() -> void:
	guide_collapsed=not guide_collapsed
	guide_toggle.text=guide_title()
	progress_label.visible=not guide_collapsed
	quest_label.visible=not guide_collapsed
	guide_panel.offset_bottom=guide_panel.offset_top+(64 if guide_collapsed else 144)

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
	call_deferred("reflow_panels")

func reflow_touch_controls() -> void:
	if not is_instance_valid(toolbar) or not is_instance_valid(cycle_button): return
	var target: float=UIMetrics.minimum_target()
	var width: float=maxf(74,target)
	# 同一窗口调整密度或安全区时，同步已有按钮触区，无需重建工具栏。
	for button in tool_buttons:
		button.custom_minimum_size=Vector2(width,maxf(88,target))
	for control in top_cluster.get_children():
		if control is Button:
			control.custom_minimum_size=Vector2(maxf(72 if control==menu_button else 88,target),target)
	var usable: float=safe.size.x-48
	var columns: int=mini(9,maxi(1,floori((usable+6)/(width+6))))
	toolbar.columns=columns
	var rows: int=ceili(9.0/columns)
	var bar_width: float=width*columns+6*(columns-1)
	var height: float=maxf(88,target)*rows+8*(rows-1)
	place(toolbar,Vector2(.5,1),Vector2(.5,1),Rect2(-bar_width/2,-height-24,bar_width,height))
	if target>74 or rows>1:
		var edge: float=maxf(116,target)
		var action_y: float=-height-40-edge
		place(action_button,Vector2(1,1),Vector2(1,1),Rect2(-edge-24,action_y,edge,edge))
		place(cycle_button,Vector2(1,1),Vector2(1,1),Rect2(-edge-24,action_y-14-target,edge,target))
		place(joystick,Vector2(0,1),Vector2(0,1),Rect2(24,-height-206,166,166))
		place(prompt_label,Vector2(.5,1),Vector2(.5,1),Rect2(-320,-height-68,640,44))
	else:
		place(action_button,Vector2(1,1),Vector2(1,1),Rect2(-142,-150,116,116))
		place(cycle_button,Vector2(1,1),Vector2(1,1),Rect2(-142,-212,116,48))
		place(joystick,Vector2(0,1),Vector2(0,1),Rect2(24,-194,166,166))
	var header_height: float=maxf(60,target)
	top_cluster.offset_bottom=12+header_height
	layout_header_dependents()

func layout_header_dependents() -> void:
	if not is_instance_valid(guide_panel) or not is_instance_valid(top_cluster): return
	var bottom: float=top_cluster.position.y+maxf(top_cluster.size.y,top_cluster.get_combined_minimum_size().y)
	guide_panel.offset_top=bottom+22
	guide_panel.offset_bottom=guide_panel.offset_top+(64 if guide_collapsed else 144)
	if is_instance_valid(atlas_button):
		var target: float=UIMetrics.minimum_target()
		atlas_button.custom_minimum_size=Vector2(target,target)
		place(atlas_button,Vector2(1,0),Vector2(1,0),Rect2(-target-12,bottom+8,target,target))
		if is_instance_valid(home_return_button):
			var width: float=maxf(80,target)
			home_return_button.custom_minimum_size=Vector2(width,target)
			place(home_return_button,Vector2(1,0),Vector2(1,0),Rect2(-width-target-20,bottom+8,width,target))
	position_camera_return(true)

func expand_hotbar() -> void:
	# 保留调用接口：经典九格工具栏始终可见，不修改玩家当前工具。
	hotbar_expanded=true
	for button in tool_buttons: button.show()
	reflow_touch_controls()

func collapse_hotbar() -> void:
	expand_hotbar()

func position_camera_return(force: bool = false) -> void:
	var owner_game:=get_parent()
	if not "camera_rig" in owner_game or not is_instance_valid(owner_game.camera_rig): return
	var button: Button=owner_game.camera_rig.return_button
	if not is_instance_valid(button) or (not force and button==camera_return_button): return
	camera_return_button=button
	var height: float=UIMetrics.minimum_target()
	var width: float=maxf(120,height)
	var top: float=top_cluster.position.y+maxf(top_cluster.size.y,top_cluster.get_combined_minimum_size().y)+8
	place(button,Vector2(1,0),Vector2(1,0),Rect2(-width-height-maxf(80,height)-28,top,width,height))

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
	guide_panel.visible=GameState.location not in ["home","mist_forest","lake_ruins","old_temple"] and GameState.location not in RanchLayout.AREAS
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
	var signature: Array=[GameState.selected,GameState.tools[5],Inventory.count("carrot_seed"),Inventory.count("potato_seed"),Inventory.count(GameState.tools[5])]
	if signature==toolbar_signature: return
	toolbar_signature=signature
	for i in range(tool_buttons.size()):
		var id: String = GameState.tools[i]
		if i==5: tool_buttons[i].icon=tool_badge(ItemPresentation.texture(id))
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
	prompt_label.text = "" if GameState.location=="home" and not nearby else text
	prompt_label.visible=not GameState.modal and not prompt_label.text.is_empty()
	action_button.text = "交互\nE" if nearby else "使用\nE"

func show_notice(text: String) -> void:
	toast.text = text
	toast_time = 4.0

func close_active_panel() -> bool:
	var current_game:=get_parent()
	if is_instance_valid(current_game.get("territory_editor")) and current_game.territory_editor.active:
		current_game.territory_editor.cancel();return true
	if is_instance_valid(character_select_panel) and character_select_panel.visible:
		character_select_panel.close_panel();return true
	if is_instance_valid(atlas_panel) and atlas_panel.visible:
		atlas_panel.close_panel();return true
	var owner_game:=get_parent()
	if "home_arrange" in owner_game and is_instance_valid(owner_game.home_arrange) and owner_game.home_arrange.active:
		owner_game.home_arrange.cancel();return true
	if "home_rest" in owner_game and is_instance_valid(owner_game.home_rest) and is_instance_valid(owner_game.home_rest.panel) and owner_game.home_rest.panel.visible:
		owner_game.home_rest.close_panel()
		return true
	# Android 系统返回键先关闭当前面板，游戏本身不意外退出。
	if dialogue.visible:
		dialogue.close_dialogue()
		return true
	for panel in [workshop_panel,world_development_panel,exploration_panel,housing_panel,festival_panel,social_panel,kitchen_panel,ecology_panel,fishing_panel,livestock_panel,recovery_panel,calendar_panel,aquaculture_panel,river_panel,abyss_panel,star_panel,mine_panel,xiaojing_panel,story_panel,progress_panel,system_panel,inventory_panel]:
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
	toast.visible = toast_time > 0 and not (is_instance_valid(workshop_panel) and workshop_panel.visible) and not (is_instance_valid(kitchen_panel) and kitchen_panel.visible)
	prompt_label.visible = not GameState.modal and not prompt_label.text.is_empty()
	position_camera_return()

func refresh_clock() -> void:
	var detail: String="%s · %s" % [Story.NAMES[GameState.location],GameWeather.label()]
	if GameState.location=="abyss": detail="%d层 · 空气%d/160" % [AbyssState.state.depth,AbyssState.state.air]
	clock_label.text="%s · %s\n%s" % [Calendar.label(),GameClock.clock_text(),detail]
	clock_label.add_theme_color_override("font_color",FarmUIStyle.DANGER if GameState.location=="abyss" and AbyssState.state.air<30 else FarmUIStyle.TEXT)
