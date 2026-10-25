extends PanelContainer
var content: VBoxContainer
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("河湾四季历 · 天气与世界记录",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12);scroll.add_child(content)
func words(text: String) -> void:
	var label := FarmUIStyle.label(text,18);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(label)
func open_panel() -> void:
	if GameState.modal: return
	GameState.set_modal(true);show()
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	words(Calendar.label()+" · 绝对第%d天 · %s" % [GameClock.day,GameClock.clock_text()])
	words("每季28日，每年112日。日期一直连续累计，婚后纪念日仍按结婚后经过的天数计算。")
	words("今日："+GameWeather.label()+"\n"+GameWeather.description())
	words("四季节日：春24日播种庆典、夏24日湖畔灯会、秋24日丰收评比、冬24日冬日集市。各有实际活动与时间窗口，午夜仍正常结算。")
	if Festival.active_id()!="": words("今天的活动："+str(Festival.data.events[Festival.active_id()].name))
	words("特殊月夜：每季15日晴朗或薄云时，20:00后可在湖岸水样台记录满月；雨雪雾夜不会伪造可见月影。")
	words("未来七日预报")
	for offset in range(1,8): words(Calendar.label(GameClock.day+offset)+" · "+GameWeather.label(GameClock.day+offset))
	words("作物农时：胡萝卜、土豆适合春夏秋；小麦全年。冬季已种的不耐寒作物休眠，转暖后从原进度继续，不会被清空。雪不等于浇水。")
	words("湖泊：雨雪对鱼栏水质有小幅影响，鱼的季节适应性仍以鱼谱为准。20:00后可睡，24:00疲劳昏睡，查看日历不快进时间。")
	words("村庄留下的改变")
	var actual: Dictionary=WorldChanges.features()
	for id in WorldChanges.LABELS:
		if actual[id]: words("✓ "+WorldChanges.LABELS[id])
	if not actual.values().has(true): words("记录还空着。建成设施、走完村民的故事后，这里会记下改变。")
func close_panel() -> void:
	hide();GameState.set_modal(false)
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
