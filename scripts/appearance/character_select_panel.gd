extends PanelContainer
## 选择只是预览。外观与新档提交由主场景在confirmed之后统一处理。
signal confirmed(gender: String)
signal cancelled

const GENDERS: Array[String]=["male","female"]
const APPEARANCE_SCRIPT: String="res://scripts/appearance/character_appearance.gd"
var game: Node
var selected_gender: String="male"
var preview_data: Dictionary={}
var cards: Dictionary={}
var images: Dictionary={}
var selection_labels: Dictionary={}
var confirm_button: Button
var back_button: Button
var companion_image: TextureRect
var companion_label: Label
var status_label: Label
var header: HBoxContainer
var footer: HBoxContainer
var subtitle: Label
var gender_row: HBoxContainer
var _opened: bool=false
var _finishing: bool=false
var _fingers: Dictionary={}
var _blocked: bool=false
var _mouse_held: bool=false
var _joy_latched: bool=false

class GestureGuard:
	extends Node
	var host: Node
	func _input(event: InputEvent) -> void:
		if is_instance_valid(host): host.observe_input(event)

func _ready() -> void:
	name="CharacterSelectPanel";set_meta("character_select",true)
	theme=FarmUIStyle.make_theme()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	header=HBoxContainer.new();column.add_child(header)
	FarmUIStyle.heading(header,"新的田园生活","house_1")
	back_button=FarmUIStyle.button("返回",close_panel,112);header.add_child(back_button)
	subtitle=FarmUIStyle.label("选择你的主角形象。可以反复预选，确认角色后再开始新的生活。",18)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(subtitle)
	gender_row=HBoxContainer.new();gender_row.add_theme_constant_override("separation",16)
	gender_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(gender_row)
	for gender in GENDERS: build_card(gender)
	footer=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	companion_image=TextureRect.new();companion_image.custom_minimum_size=Vector2(64,72)
	companion_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;companion_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	companion_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;companion_image.mouse_filter=Control.MOUSE_FILTER_IGNORE;footer.add_child(companion_image)
	var notes:=VBoxContainer.new();notes.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(notes)
	companion_label=FarmUIStyle.label("与你相遇的小京",18,FarmUIStyle.STAR);notes.add_child(companion_label)
	status_label=FarmUIStyle.label("",16,FarmUIStyle.MUTED);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notes.add_child(status_label)
	confirm_button=FarmUIStyle.button("确认角色并开始",confirm_selection,208);footer.add_child(confirm_button)
	# 后加入的输入节点先观察原生触点，阻止双指和混合设备误按最终确认。
	var guard:=GestureGuard.new();guard.host=self;add_child(guard)
	get_viewport().size_changed.connect(layout_panel)
	Events.location_changed.connect(func(_area: String):
		if _opened: close_panel()
	)

func setup(owner_game: Node=null) -> void:
	game=owner_game

func build_card(gender: String) -> void:
	var button:=FarmUIStyle.button("",select_gender.bind(gender),300)
	button.name="MaleChoice" if gender=="male" else "FemaleChoice"
	button.set_meta("character_gender",gender);button.set_meta("ui07_card",true)
	button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y=320;gender_row.add_child(button);cards[gender]=button
	var margin:=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	button.add_child(margin)
	var column:=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",8);margin.add_child(column)
	var title:=FarmUIStyle.label("主角男" if gender=="male" else "主角女",22,FarmUIStyle.TITLE)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(title)
	var picture:=TextureRect.new();picture.custom_minimum_size=Vector2(128,180)
	picture.size_flags_vertical=Control.SIZE_EXPAND_FILL;picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(picture);images[gender]=picture
	var description:=FarmUIStyle.label("棕发 · 绿马甲 · 工具袋" if gender=="male" else "编发 · 绿裙 · 浅色围裙",16)
	description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(description)
	var selected:=FarmUIStyle.label("",16,FarmUIStyle.MUTED)
	selected.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(selected);selection_labels[gender]=selected

func open_panel(initial_gender: String="male") -> bool:
	if _opened or GameState.modal or GameState.restoring: return false
	if is_instance_valid(game) and (game.backgrounded or game.closing): return false
	selected_gender=initial_gender if initial_gender in GENDERS else "male"
	_finishing=false;_opened=true;reset_gesture()
	if is_instance_valid(game) and is_instance_valid(game.touch_input):
		_fingers=game.touch_input.fingers.duplicate();_blocked=not _fingers.is_empty()
	add_to_group("modal_panels");GameState.set_modal(true);show()
	refresh_previews();layout_panel();call_deferred("layout_panel")
	return true

func select_gender(gender: String) -> bool:
	if not _opened or _finishing or gender not in GENDERS or _blocked: return false
	selected_gender=gender;refresh_previews();return true

func preview_paths(gender: String) -> Dictionary:
	if not ResourceLoader.exists(APPEARANCE_SCRIPT): return {}
	var resolver=load(APPEARANCE_SCRIPT)
	return resolver.preview_paths(gender)

func load_preview(path: String) -> Texture2D:
	return load(path) if path!="" and ResourceLoader.exists(path) else null

func refresh_previews() -> void:
	for gender in GENDERS:
		var paths: Dictionary=preview_paths(gender)
		images[gender].texture=load_preview(str(paths.get("player_standing","")))
		var chosen: bool=gender==selected_gender
		cards[gender].set_pressed_no_signal(chosen)
		cards[gender].add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if chosen else "secondary"))
		cards[gender].add_theme_stylebox_override("pressed",FarmUIStyle.surface("selected" if chosen else "pressed"))
		selection_labels[gender].text="已选择" if chosen else "点击选择"
		selection_labels[gender].add_theme_color_override("font_color",FarmUIStyle.TITLE if chosen else FarmUIStyle.MUTED)
	preview_data=preview_paths(selected_gender)
	companion_image.texture=load_preview(str(preview_data.get("companion_portrait","")))
	companion_label.text="与你相遇的小京 · "+("女性形象" if preview_data.get("xiaojing_gender","")=="female" else "男性形象")
	var ready: bool=images[selected_gender].texture!=null and companion_image.texture!=null
	status_label.text="小京会以对应形象登场，无需另作选择。" if ready else "角色图像暂未能加载，请重新打开后再试。"
	confirm_button.disabled=not ready
	confirm_button.text="确认男主角并开始" if selected_gender=="male" else "确认女主角并开始"

func confirm_selection() -> bool:
	if not _opened or _finishing or _blocked or not _fingers.is_empty() or _mouse_held or confirm_button.disabled: return false
	_finishing=true
	var chosen: String=selected_gender
	finish_view();confirmed.emit(chosen);return true

func close_panel() -> void:
	if not _opened or _finishing: return
	_finishing=true;finish_view();cancelled.emit()

func finish_view() -> void:
	_opened=false;reset_gesture();hide()
	if is_in_group("modal_panels"): remove_from_group("modal_panels")
	GameState.set_modal(false)

func layout_panel() -> void:
	if not is_node_ready(): return
	var parent:=get_parent_control()
	var available: Vector2=parent.size if is_instance_valid(parent) else get_viewport().get_visible_rect().size
	var extent: Vector2=(available-Vector2(24,24)).min(Vector2(1040,680))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);position=(available-extent)*.5;size=extent
	var target: float=UIMetrics.minimum_target()
	back_button.custom_minimum_size=Vector2(maxf(112,target),target)
	confirm_button.custom_minimum_size=Vector2(maxf(208,target),target)
	var reserved: float=maxf(target,48)+maxf(target,72)+48+36+get_theme_stylebox("panel").get_minimum_size().y
	var card_height: float=clampf(extent.y-reserved,260,320)
	for gender in GENDERS:
		images[gender].custom_minimum_size=Vector2(128,minf(180,card_height-128))
		cards[gender].custom_minimum_size=Vector2(maxf(260,target),card_height)

func reset_gesture() -> void:
	_fingers.clear();_blocked=false;_mouse_held=false;_joy_latched=false
	for button in cards.values():
		if is_instance_valid(button) and button.has_method("reset_touch"): button.reset_touch()
	for button in [confirm_button,back_button]:
		if is_instance_valid(button) and button.has_method("reset_touch"): button.reset_touch()

func consume_input() -> void: get_viewport().set_input_as_handled()

func observe_input(event: InputEvent) -> void:
	if not _opened or not is_visible_in_tree(): return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device<0:
		consume_input();return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _fingers.has(event.index) or _mouse_held: _blocked=true
			_fingers[event.index]=event.position
			if _fingers.size()>1 or event.canceled: _blocked=true
		else: _fingers.erase(event.index)
		if _blocked:
			for button in cards.values(): button.reset_touch()
			confirm_button.reset_touch();back_button.reset_touch()
			consume_input()
			if _fingers.is_empty() and not _mouse_held: _blocked=false
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_mouse_held=event.pressed
		if not _fingers.is_empty(): _blocked=true
		if _blocked:
			confirm_button.reset_touch();back_button.reset_touch();consume_input()
			if _fingers.is_empty() and not _mouse_held: _blocked=false
	elif event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_X:
		if absf(event.axis_value)<.25: _joy_latched=false
		elif absf(event.axis_value)>.6 and not _joy_latched:
			_joy_latched=true;select_gender("male" if event.axis_value<0 else "female");consume_input()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_DPAD_LEFT: select_gender("male");consume_input()
		elif event.button_index==JOY_BUTTON_DPAD_RIGHT: select_gender("female");consume_input()
		elif event.button_index==JOY_BUTTON_A: confirm_selection();consume_input()
		elif event.button_index==JOY_BUTTON_B: close_panel();consume_input()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		select_gender("male");consume_input()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		select_gender("female");consume_input()
	elif event.is_action_pressed("ui_accept"):
		confirm_selection();consume_input()
	elif event.is_action_pressed("ui_cancel"):
		close_panel();consume_input()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and _opened: reset_gesture()
