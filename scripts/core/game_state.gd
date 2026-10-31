extends Node
## 仅保存玩家会话状态；作物、背包和时钟分别由各自模块负责。
signal changed
signal control_mode_changed
signal preferences_changed
const MAX_STAMINA: int = 100
var stamina: int = MAX_STAMINA
var modal: bool = false
var restoring: bool = false
var tools: Array[String] = ["hoe", "water", "hand", "carrot_seed", "potato_seed", "wheat_seed", "axe", "pickaxe", "fishing_rod"]
var tool_names: Array[String] = ["锄头", "水壶", "采收", "胡萝卜", "土豆", "小麦", "斧头", "镐", "鱼竿"]
var preferences: Dictionary={}
var selected: int = 0:
	set(value):
		selected=posmod(value,tools.size())
		if not preferences.is_empty():
			preferences.active_item=tools[selected]
			if preferences.hotbar[int(preferences.hotbar_slot)]!=tools[selected] and tools[selected] in preferences.hotbar: preferences.hotbar_slot=preferences.hotbar.find(tools[selected])
var location: String = "farm"
var control_mode: String = "tap"
# 工具栏的明确选择优先用于下一次点击操作；之后恢复状态辅助。
var manual_tool: bool = false

func set_control_mode(mode: String, persist: bool = true) -> void:
	if mode not in ["tap", "joystick"] or mode == control_mode: return
	control_mode = mode
	control_mode_changed.emit()
	changed.emit()
	if persist: Events.progress_committed.emit()

func _ready() -> void:
	preferences=InteractionPreferences.defaults()
	# 世界标牌使用全局回退字体；Windows 英文系统也须能显示中文。
	if OS.get_name()=="Windows":
		var previous: Font=ThemeDB.get_default_theme().default_font
		var chinese: Font=load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc")
		if previous and previous!=chinese and previous not in chinese.fallbacks: chinese.fallbacks=chinese.fallbacks+[previous]
		ThemeDB.get_default_theme().default_font=chinese
		ThemeDB.fallback_font=chinese
	# 在运行时统一注册按键，避免平台键码与编辑器配置不一致。
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE], "bag": [KEY_B, KEY_TAB], "cycle_tool": [KEY_Q],
		"save_game": [KEY_F5], "load_game": [KEY_F9], "journal": [KEY_J], "story_map":[KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)

func snapshot_preferences() -> Dictionary:
	return preferences.duplicate(true)

func restore_preferences(raw: Dictionary) -> void:
	preferences=InteractionPreferences.normalize(raw,{"selected":selected,"workshop":{"selected_seed":tools[5]}})
	preferences_changed.emit()

func set_preference(key: String, value: Variant) -> void:
	if not preferences.has(key): return
	var candidate:=preferences.duplicate(true);candidate[key]=value
	candidate=InteractionPreferences.normalize(candidate,{"selected":selected,"workshop":{"selected_seed":tools[5]}})
	if candidate==preferences: return
	preferences=candidate;preferences_changed.emit();Events.progress_committed.emit()

func select_tool(index: int) -> void:
	selected = posmod(index, tools.size())
	manual_tool = true
	Events.tool_changed.emit()
	changed.emit()

func tool() -> String:
	return tools[selected]

func spend_energy(amount: int) -> bool:
	amount=Kitchen.energy_cost(amount)
	if stamina < amount:
		Events.notice.emit("体力不足：去屋东椅歇脚，或在背包吃食物。20:00后可睡。")
		return false
	stamina -= amount
	changed.emit()
	return true

func set_modal(active: bool) -> void:
	modal = active
	Events.modal_changed.emit(active)

func rest() -> void:
	stamina = max_stamina()
	changed.emit()

func max_stamina() -> int:
	return MAX_STAMINA+30 if FarmProgress.has_upgrade("bedding") else MAX_STAMINA
