extends Node
## 仅保存玩家会话状态；作物、背包和时钟分别由各自模块负责。
signal changed
signal control_mode_changed
const MAX_STAMINA: int = 100
var stamina: int = MAX_STAMINA
var modal: bool = false
var restoring: bool = false
var selected: int = 0
var tools: Array[String] = ["hoe", "water", "hand", "carrot_seed", "potato_seed", "wheat_seed", "axe", "pickaxe", "fishing_rod"]
var tool_names: Array[String] = ["锄头", "水壶", "采收", "胡萝卜", "土豆", "小麦", "斧头", "镐", "鱼竿"]
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
		Events.notice.emit("体力不足啦，回小屋睡一觉吧。")
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
