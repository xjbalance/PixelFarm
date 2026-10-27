extends PanelContainer
## 剧情支持逐字、头像和选择；退出不提交，完整读完后才变更故事。
var speaker_label: Label
var body_label: Label
var next_button: Button
var title_label: Label
var hint: Label
var portrait: Control
var choices_box: HBoxContainer
var lines: Array = []
var index: int = 0
var scene_id: String = ""
var options: Array = []
var selected_choice: String = ""
var revealed: float = 0
var legacy_speaker: String = ""
var social_button: Button
var social_person: String=""

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	add_child(content)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	title_label = FarmUIStyle.heading(title_row,"河湾里的故事","lantern")
	title_label.add_theme_font_size_override("font_size",16)
	title_label.add_theme_color_override("font_color",FarmUIStyle.MUTED)
	social_button=FarmUIStyle.button("近况与礼物",func():
		var person := social_person
		close_dialogue()
		if person!="": Events.interaction_requested.emit("social:"+person)
	,160)
	title_row.add_child(social_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	content.add_child(row)
	var portrait_frame:=PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel",FarmUIStyle.surface("secondary"))
	portrait_frame.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait_frame)
	portrait = FarmPortrait.new()
	portrait_frame.add_child(portrait)
	var words := FarmUIStyle.card(row)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",12)
	speaker_label = FarmUIStyle.label("",24,FarmUIStyle.TITLE)
	words.add_child(speaker_label)
	body_label = FarmUIStyle.label("",21)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(0,100)
	words.add_child(body_label)
	choices_box = HBoxContainer.new()
	choices_box.add_theme_constant_override("separation",12)
	content.add_child(choices_box)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	hint = FarmUIStyle.label("",16,FarmUIStyle.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(hint)
	actions.add_child(FarmUIStyle.button("稍后再聊",close_dialogue,120))
	next_button = FarmUIStyle.button("继续 →",advance,160)
	actions.add_child(next_button)
	Events.dialogue_requested.connect(open_dialogue)
	Events.story_dialogue_requested.connect(open_story)

func open_dialogue(speaker: String, dialogue: Array) -> void:
	if dialogue.is_empty() or GameState.modal: return
	scene_id = ""
	legacy_speaker = speaker
	options = []
	selected_choice = ""
	lines = dialogue.duplicate(true)
	index = 0
	title_label.text = "河湾日常"
	begin()

func open_story(id: String) -> void:
	if GameState.modal: return
	var scene := Story.scene_data(id)
	scene_id = id
	lines = scene.lines.duplicate(true)
	options = scene.get("choices",[]).duplicate(true)
	selected_choice = ""
	index = 0
	title_label.text = scene.title
	begin()

func begin() -> void:
	GameState.set_modal(true)
	show()
	refresh()

func refresh() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	social_person=""
	var nearest := INF
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	for person in get_tree().get_nodes_in_group("interactables"):
		if not "person_id" in person or not person.is_visible_in_tree() or player==null: continue
		var distance: float=person.global_position.distance_to(player.global_position)
		if distance<=76 and distance<nearest: nearest=distance;social_person=person.person_id
	social_button.visible=social_person!=""
	var line = lines[index]
	if line is Dictionary:
		speaker_label.text = line.who
		body_label.text = line.text
		portrait.person = line.get("portrait","letter")
	else:
		speaker_label.text = legacy_speaker
		body_label.text = str(line)
		portrait.person = "xiaojing" if legacy_speaker=="小京" else ("player" if legacy_speaker in ["你","主角"] else "linya")
	speaker_label.add_theme_color_override("font_color",FarmUIStyle.STAR if portrait.person=="xiaojing" else FarmUIStyle.TITLE)
	revealed = 0
	body_label.visible_characters = -1 if scene_id == "" else 0
	hint.text = "%02d / %02d   ·   E 继续 / 再按一次显示全文" % [index+1,lines.size()]
	next_button.text = "记下这句话" if index == lines.size()-1 else "继续 →"
	next_button.disabled = false
	choices_box.hide()

func show_choices() -> void:
	if index != lines.size()-1 or options.is_empty() or selected_choice != "": return
	next_button.disabled = true
	hint.text = "选择一句你想说的话 · 也可按数字键"
	if choices_box.get_child_count() == 0:
		for option in options:
			var button := FarmUIStyle.button(option.text,choose.bind(str(option.id)),100)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size",17)
			choices_box.add_child(button)
	choices_box.show()

func choose(id: String) -> void:
	if not visible or not choices_box.visible or selected_choice != "": return
	for option in options:
		if option.id == id:
			selected_choice = id
			lines.append({"who":"旁白","portrait":"letter","text":option.reply})
			index += 1
			refresh()
			return

func advance() -> void:
	if not visible: return
	if body_label.visible_characters >= 0 and body_label.visible_characters < body_label.get_total_character_count():
		body_label.visible_characters = -1
		show_choices()
		return
	if index == lines.size()-1 and not options.is_empty() and selected_choice == "":
		show_choices()
		return
	index += 1
	if index >= lines.size():
		var completed_id := scene_id
		var chosen := selected_choice
		close_dialogue()
		if completed_id != "": Story.complete(completed_id,chosen)
	else: refresh()

func close_dialogue() -> void:
	hide()
	GameState.set_modal(false)

func _process(delta: float) -> void:
	if not visible or body_label.visible_characters == -1: return
	revealed += delta * 40.0
	body_label.visible_characters = int(revealed)
	if body_label.visible_characters >= body_label.get_total_character_count():
		body_label.visible_characters = -1
		show_choices()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and choices_box.visible:
		var option_index: int = event.physical_keycode-KEY_1
		if option_index >= 0 and option_index < options.size():
			choose(options[option_index].id)
			get_viewport().set_input_as_handled()
