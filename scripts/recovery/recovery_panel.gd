extends PanelContainer
var content: VBoxContainer
var pending_day: int=-1
var pending_used: int=-1
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("歇一歇，再出发",24,FarmUIStyle.GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
func words(text: String) -> void:
	var label := FarmUIStyle.label(text,19);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(label)
func button(text: String, callback: Callable) -> Button:
	var b := FarmUIStyle.button(text,callback,180);content.add_child(b);return b
func open_panel() -> void:
	if GameState.modal: return
	pending_day=-1;GameState.set_modal(true);show();refresh()
func refresh() -> void:
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	words("体力 %d / %d · 今天休息%d/3" % [GameState.stamina,GameState.max_stamina(),Recovery.snapshot().rests])
	if pending_day>=0:
		words("坐20游戏分钟，恢复15体力，使用今天的一次休息机会？日期、作物、矿石与鱼群不会跨天结算。")
		button("确认休息",func():
			var day := pending_day;var used := pending_used;pending_day=-1
			Recovery.rest(day,used);refresh()
		)
		button("取消",func(): pending_day=-1;refresh());return
	words("农场屋东的木椅可以白天歇脚。每天最多三次，午夜前需要留够20分钟；满体力不会浪费次数。")
	button("坐一会儿 · 20分钟 / +15体力",func(): pending_day=GameClock.day;pending_used=int(Recovery.snapshot().rests);refresh()).disabled=not Recovery.can_rest()
	for item in Recovery.FOOD:
		button("吃%s ×1 · +%d体力（持有%d）" % [Catalog.item_name(item),Recovery.FOOD[item],Inventory.count(item)],func():
			if not Recovery.eat_crop(item): Events.notice.emit("缺少食物、体力已满或暂时不能食用，物品未消耗。")
			refresh()
		).disabled=Inventory.count(item)==0
	words("持有食物且体力未满时可以继续吃，每次消耗1份并恢复至多到体力上限。料理的已有增益不叠加或延长。建成公共茶座后，每天热茶恢复40体力；鱼干恢复18、鱼汤恢复30。20:00后睡眠全恢复，24:00疲劳醒来恢复六成。")
func close_panel() -> void:
	pending_day=-1;hide();GameState.set_modal(false)
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
