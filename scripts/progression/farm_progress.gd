extends Node
## 设施和任务使用数据定义，运行状态独立存储；奖励只在整笔交易可提交时发放。
signal changed
signal upgrade_built(id: String)
var upgrades: Dictionary = {}
var quests: Dictionary = {}
var built: Array[String] = []
var quest_states: Dictionary = {}
var friendship: int = 0
var last_talk_day: int = 0

func _ready() -> void:
	upgrades = JSON.parse_string(FileAccess.get_file_as_string("res://resources/progression/upgrades.json"))
	quests = JSON.parse_string(FileAccess.get_file_as_string("res://resources/progression/quests.json"))

func has_upgrade(id: String) -> bool:
	return id in built

func build_upgrade(id: String) -> bool:
	if not upgrades.has(id) or has_upgrade(id):
		Events.notice.emit("这项设施已经建好了。")
		return false
	var definition: Dictionary = upgrades[id]
	if not Inventory.exchange(definition.materials,{},-int(definition.coins)):
		Events.notice.emit("金币或材料不足，先看看修缮清单吧。")
		return false
	built.append(id)
	upgrade_built.emit(id)
	GameState.changed.emit()
	changed.emit()
	Events.notice.emit("%s建好了！" % definition.name)
	Events.progress_committed.emit()
	return true

func quest_status(id: String) -> String:
	if not quests.has(id): return "locked"
	var previous: String = quests[id].previous
	if previous != "" and int(quest_states.get(previous,0)) != 2: return "locked"
	return ["available","active","completed"][int(quest_states.get(id,0))]

func accept(id: String) -> bool:
	if quest_status(id) != "available": return false
	quest_states[id] = 1
	changed.emit()
	Events.notice.emit("已接下委托：%s。材料备齐后回委托板提交。" % quests[id].title)
	Events.progress_committed.emit()
	return true

func ready_to_deliver(id: String) -> bool:
	if quest_status(id) != "active": return false
	for item in quests[id].requirements:
		if Inventory.count(item) < int(quests[id].requirements[item]): return false
	return true

func deliver(id: String) -> bool:
	if not ready_to_deliver(id):
		Events.notice.emit("委托尚未接取或材料还没备齐。")
		return false
	var quest: Dictionary = quests[id]
	if not Inventory.exchange(quest.requirements,quest.items,int(quest.coins)):
		Events.notice.emit("奖励暂时装不下，先整理种子背包或金币。")
		return false
	quest_states[id] = 2
	friendship = mini(100,friendship+int(quest.friendship))
	changed.emit()
	Events.notice.emit("完成「%s」！获得 %d 金，林芽好感 +%d。" % [quest.title,quest.coins,quest.friendship])
	Events.progress_committed.emit()
	return true

func talk() -> void:
	if last_talk_day >= GameClock.day: return
	last_talk_day = GameClock.day
	friendship = mini(100,friendship+2)
	changed.emit()
	Events.progress_committed.emit()

func next_quest_text() -> String:
	for id in quests:
		if quest_status(id) == "active":
			return "%s · %s" % [quests[id].title,"可以交付" if ready_to_deliver(id) else "收集物品中"]
		if quest_status(id) == "available": return "委托板 · " + str(quests[id].title)
	return "河谷委托已完成，谢谢你的照料。"

func relationship() -> String:
	if friendship >= 60: return "知心邻居"
	if friendship >= 25: return "熟悉的朋友"
	return "初识的邻居"

func snapshot() -> Dictionary:
	return {"built":built.duplicate(),"quests":quest_states.duplicate(),"friendship":friendship,"last_talk_day":last_talk_day}

func restore(data: Dictionary) -> void:
	built.clear()
	for id in data.get("built",[]): built.append(id)
	quest_states.clear()
	for id in data.get("quests",{}): quest_states[id] = int(data.quests[id])
	friendship = int(data.get("friendship",0))
	last_talk_day = int(data.get("last_talk_day",0))
	changed.emit()
