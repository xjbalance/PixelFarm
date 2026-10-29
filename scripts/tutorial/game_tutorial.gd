class_name GameTutorial
extends Node
## 只保存已显示的稳定主题ID；不改变经济、日期或原主线教学。
## 老档没有此字段时视为已读，玩家随时可从菜单查阅全部说明。
const TOPICS := {
	"tap_move": "轻点地面自动行走；点人物或物件会靠近后交互。点新目标替换旧目标，菜单里可随时切换备用摇杆。",
	"farm_basics": "农田依次翻土、播种、浇水，成熟后收获。点田会按当前状态辅助选工具；工具栏手动选择优先于下一次点击。动作结束后才能继续走。",
	"sleep_hours": "一天从06:00到24:00，现实1秒约2游戏分钟。晚上20:00后可在床边确认睡觉，24:00会疲劳昏睡。白天休息不会让作物跨天。",
	"day_rest": "白天体力不足可去小屋东侧休息椅：每天3次，各花20游戏分钟恢复15体力。持有食物且体力未满就能继续吃，每次1份；已有料理增益不叠加或延长，茶座每日一次。",
	"fishing": "装备工具栏第9格鱼竿，点钓点水面自动靠岸。备好鱼饵再抛竿；鱼上钩后按住追鱼按钮让控制区上移，松开下移。",
	"fishpens": "湖岸鱼栏先建造，再投放同种鱼苗，每天喂食一次并维护水质。成长按游戏日结算；成熟后可留两尾种鱼，背包满时不会丢失收获。",
	"animals": "在畜舍购买动物后，每天喂食并抚摸。成年且吃饱的动物按天产物，每份只可领取一次；雨雪和冬季回暖舍，晴日可放牧。",
	"seasons": "每季28日、每年112日；手记四季历可看预报。雨天浇露天田，冬季胡萝卜与土豆休眠保留，小麦全年生长。天气也会改变鱼种和村民日程。",
	"wheat_milling": "收获的小麦可以磨成面粉。到农场建造模式放置磨坊，再用面粉在家中厨房制作面包。",
	"workshop_first": "先选配方并核对材料，确认后才投入。加工按游戏时间进行，离开设备后继续；完成后回到设备收取，满包会保留成品。",
	"workshop_collect": "工坊成品已经做好了。点击带暖金标识的设备收取；每笔只领取一次，背包满时不会丢失。",
	"food_energy": "做好的料理在背包中食用，每次消耗一份并恢复体力。满体力不会浪费食物，已有增益不叠加或续时。",
	"recipe_missing": "材料按“持有 / 需要”显示，缺少的数量会直接列出。补齐材料再开始；查看配方和取消确认都不会扣材料。"
}
const PRODUCTION_TOPICS: Array[String]=["wheat_milling","workshop_first","workshop_collect","food_energy","recipe_missing"]
var seen: Array[String] = []
var pending: Array[String] = []
var game: Node
var cooldown: float = 0
var check_time: float = 0
var visible_seconds: float = 0
var panel: PanelContainer
var body: Label

static func defaults(legacy: bool = false) -> Dictionary:
	var ids: Array[String] = []
	if legacy:
		for id in TOPICS: ids.append(id)
	return {"seen": ids}

static func normalize(raw: Variant, legacy: bool = false) -> Dictionary:
	if raw == null: return defaults(legacy)
	if not raw is Dictionary or not raw.get("seen") is Array or raw.seen.size() > TOPICS.size(): return {}
	var ids: Array[String] = []
	for id in raw.seen:
		if not id is String or not TOPICS.has(id) or id in ids: return {}
		ids.append(id)
	return {"seen": ids}

static func migrate_080(raw: Variant) -> Dictionary:
	var result:=normalize(raw,true)
	if result.is_empty(): return {}
	for id in PRODUCTION_TOPICS:
		if id not in result.seen: result.seen.append(id)
	return result

func snapshot() -> Dictionary:
	return {"seen": seen.duplicate()}

func restore(raw: Dictionary) -> void:
	var clean := normalize(raw)
	if clean.is_empty(): return
	seen.assign(clean.seen)
	pending.clear()
	cooldown = 0
	check_time = 0
	visible_seconds = 0
	if is_instance_valid(panel): panel.hide()
	if is_instance_valid(game) and "tap_move" not in seen: pending.append("tap_move")

func attach(owner_game: Node) -> void:
	game = owner_game
	build_card()
	Events.farm_committed.connect(func(_kind: String,_cell: Vector2i,_crop: String,_serial: int): offer("farm_basics"))
	Events.interaction_requested.connect(on_interaction)
	Events.tool_changed.connect(func():
		if GameState.tool() == "fishing_rod": offer("fishing")
	)
	Inventory.changed.connect(func():
		if Inventory.count("wheat")>0: offer("wheat_milling")
	)
	Events.dish_cooked.connect(func(_id: String,_batches: int,_total: int,_day: int): offer("food_energy"))
	Workshop.changed.connect(on_production_state)
	GameClock.changed.connect(on_production_state)
	# 首次进入的提示先排队，让旧信提示/开场对白完整显示。
	cooldown = 7
	offer("tap_move")

func build_card() -> void:
	panel = PanelContainer.new()
	panel.name = "TutorialHint"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = .5
	panel.anchor_right = .5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = 94
	panel.offset_bottom = 245
	game.hud.safe.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var title := FarmUIStyle.label("生活小提示",19,FarmUIStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(FarmUIStyle.button("知道了",hide_hint,90))
	body = FarmUIStyle.label("",17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	panel.hide()

func hide_hint() -> void:
	visible_seconds = 0
	if is_instance_valid(panel): panel.hide()

func offer(id: String) -> void:
	if not TOPICS.has(id) or id in seen or id in pending or GameState.restoring: return
	pending.append(id)

func inline_hint(id: String) -> String:
	if not TOPICS.has(id) or id in seen or GameState.restoring or (is_instance_valid(game) and game.backgrounded): return ""
	seen.append(id);pending.erase(id);Events.progress_committed.emit()
	return str(TOPICS[id])

func on_production_state() -> void:
	if "workshop_collect" in seen or "workshop_collect" in pending or GameState.restoring: return
	for job in Workshop.state.jobs.values():
		if Workshop.now_minutes()>=int(job.finish_at): offer("workshop_collect");return

func on_interaction(kind: String) -> void:
	if kind == "sleep": offer("sleep_hours")
	elif kind == "recovery": offer("day_rest")
	elif kind.begins_with("fish:"): offer("fishpens")
	elif kind.begins_with("fishing:"): offer("fishing")
	elif kind.begins_with("livestock:"): offer("animals")

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	if is_instance_valid(panel): panel.visible = visible_seconds > 0 and not GameState.modal and not game.backgrounded
	if GameState.restoring or GameState.modal or game.backgrounded: return
	visible_seconds = maxf(0,visible_seconds-delta)
	cooldown = maxf(0,cooldown-delta)
	check_time += delta
	if check_time >= 1:
		check_time = 0
		if GameState.stamina <= 25: offer("day_rest")
		if GameClock.minutes >= 1080: offer("sleep_hours")
		if GameClock.day > 1 or GameClock.minutes >= 420: offer("seasons")
	if cooldown > 0 or pending.is_empty() or game.hud.toast_time > 0: return
	if game.player.action_time > 0 or (is_instance_valid(game.auto_move) and not game.auto_move.target.is_empty()): return
	var id: String = pending.pop_front()
	if id in seen: return
	seen.append(id)
	cooldown = 40
	body.text = TOPICS[id]
	visible_seconds = 12
	panel.show()
	Events.progress_committed.emit()

static func help_text() -> String:
	var lines: Array[String] = []
	for id in TOPICS: lines.append(TOPICS[id])
	return "\n\n".join(lines)
