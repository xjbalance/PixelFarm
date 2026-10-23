extends Node
## 村庄共建使用独立数据与事务；设施外观、福利和存档订阅同一状态。
signal changed
signal built_project(id: String)
signal irrigation_requested
var definitions: Dictionary = {}
var built: Array[String] = []
var water_day: int = 0
var tea_day: int = 0

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/village_projects.json"))

func has_project(id: String) -> bool:
	return id in built

func all_built() -> bool:
	return built.size() == definitions.size()

func build(id: String) -> bool:
	if Story.stage < 6 or not definitions.has(id) or has_project(id): return false
	# 只能在村里的共建板旁交付；地图手记可远程查看，不可远程施工。
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if GameState.location != "village" or player == null or player.global_position.distance_to(Vector2(680,650)) > 76: return false
	var definition: Dictionary = definitions[id]
	if not Inventory.exchange(definition.materials,{},-int(definition.coins)):
		Events.notice.emit("材料或金币还没备齐，已保留你带来的所有物品。")
		return false
	built.append(id)
	Playtest.record("task",{"id":"village:"+id})
	built_project.emit(id)
	changed.emit()
	Story.changed.emit()
	Events.notice.emit(definition.after)
	Events.progress_committed.emit()
	return true

func water_fields() -> bool:
	if not has_project("well") or water_day >= GameClock.day: return false
	water_day = GameClock.day
	irrigation_requested.emit()
	changed.emit()
	Events.notice.emit("清水顺着修好的沟渠流向农场。现有农田都浇透了。")
	Events.progress_committed.emit()
	return true

func drink_tea() -> bool:
	if not has_project("arbor") or tea_day >= GameClock.day: return false
	if GameState.stamina >= GameState.max_stamina():
		Events.notice.emit("你现在精神很好，热茶留到累了再喝吧。")
		return false
	tea_day = GameClock.day
	GameState.stamina = mini(GameState.max_stamina(),GameState.stamina+40)
	GameState.changed.emit()
	changed.emit()
	Events.notice.emit("一杯热茶，一会儿树荫。体力恢复 40 点。")
	Events.progress_committed.emit()
	return true

func snapshot() -> Dictionary:
	return {"built":built.duplicate(),"water_day":water_day,"tea_day":tea_day}

func restore(saved: Dictionary) -> void:
	built.clear()
	for id in saved.get("built",[]): built.append(id)
	water_day = int(saved.get("water_day",0))
	tea_day = int(saved.get("tea_day",0))
	changed.emit()

func validate(saved: Variant,day: Variant,stage: int) -> bool:
	if not saved is Dictionary or not FarmSaveSchema.whole(day,1,999999): return false
	if not saved.get("built") is Array or saved.built.size() > definitions.size(): return false
	var unique := {}
	for id in saved.built:
		if not id is String or not definitions.has(id) or unique.has(id) or stage < 6: return false
		unique[id] = true
	if stage >= 7 and unique.size() != definitions.size(): return false
	if not FarmSaveSchema.whole(saved.get("water_day"),0,int(day)) or not FarmSaveSchema.whole(saved.get("tea_day"),0,int(day)): return false
	return (saved.water_day == 0 or unique.has("well")) and (saved.tea_day == 0 or unique.has("arbor"))
