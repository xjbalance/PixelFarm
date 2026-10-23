extends PanelContainer
signal save_requested
signal load_requested
signal sleep_requested
signal mute_requested
var title: Label
var body: Label
var actions: VBoxContainer
var sleep_mode: bool = false

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	add_child(column)
	title = FarmUIStyle.label("像素世界 · 0.4.0",26,FarmUIStyle.GOLD)
	column.add_child(title)
	body = FarmUIStyle.label("",17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	column.add_child(actions)

func open_panel(for_sleep: bool = false) -> void:
	if GameState.modal: return
	sleep_mode = for_sleep
	GameState.set_modal(true)
	show()
	title.text = "让今天好好结束" if for_sleep else "像素世界 · 0.4.0"
	body.text = "睡到明天早上 06:00，恢复全部体力。\n今天浇过水的作物将成长一天。" if for_sleep else "移动：WASD / 方向键 / 左侧摇杆\n操作：E / 右侧按钮；换工具：Q / 1—8\n背包 B · 委托 J · 保存 F5 · 读取 F9\n主线：那些没有寄出的信\n第一章：河水带走的名字\n小屋东侧有修缮台和委托板。"
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	if for_sleep:
		actions.add_child(FarmUIStyle.button("休息到明天",func(): close_panel(); sleep_requested.emit()))
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		actions.add_child(row)
		row.add_child(FarmUIStyle.button("保存进度",func(): close_panel(); save_requested.emit(),150))
		row.add_child(FarmUIStyle.button("读取进度",func(): close_panel(); load_requested.emit(),150))
		actions.add_child(FarmUIStyle.button("音乐与环境声 开 / 关",func(): mute_requested.emit()))
		var assist := FarmUIStyle.button("操作辅助："+("开" if Story.assisted_tools else "关"),func():
			Story.assisted_tools = not Story.assisted_tools
			Story.changed.emit()
			Events.progress_committed.emit()
			close_panel()
			open_panel()
		)
		actions.add_child(assist)
	if for_sleep: body.text += "\n明天的河湾村："+GameWeather.tomorrow()+"。"
	actions.add_child(FarmUIStyle.button("继续农场生活",close_panel))

func close_panel() -> void:
	hide()
	GameState.set_modal(false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
