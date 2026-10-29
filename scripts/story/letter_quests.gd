extends Node
## 调查与任务独立于旧版 stage，旧建设和已发奖励保持原样。所有任务只结算一次。
signal changed
var definitions: Array = []
var facts: Dictionary = {}
var completed: Array[String] = []
var direction: String = ""
var legacy_review: bool = false
var elapsed: float = 0
var committing: bool = false
const DIRECTIONS := {"trade":"农业贸易","explore":"自然探索","life":"居民生活"}

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/letter_quests.json"))
	Events.farm_action.connect(func(kind: String): record({"翻土":"till","播种":"plant","浇水":"water","收获":"harvest"}.get(kind,"farm")))
	Events.resource_hit.connect(func(depleted: bool):
		if depleted: record("gather")
	)
	VillageProjects.built_project.connect(func(id: String): record("build:"+id))

func record(id: String, amount: int = 1) -> void:
	if amount < 1: return
	facts[id] = mini(999999,int(facts.get(id,0))+amount)
	if Story.stage >= 8 and id in ["plant","gather"]:
		facts["chapter2:"+id] = mini(999999,int(facts.get("chapter2:"+id,0))+amount)
	refresh()
	changed.emit()
	Events.progress_committed.emit()

func knows(id: String) -> bool:
	return int(facts.get(id,0)) > 0

func conditions_met(conditions: Array) -> bool:
	for condition in conditions:
		if condition.has("task") and condition.task not in completed: return false
		if condition.has("stage") and Story.stage < int(condition.stage): return false
		if condition.has("fact") and int(facts.get(condition.fact,0)) < int(condition.get("count",1)): return false
		if condition.has("build") and not VillageProjects.has_project(condition.build): return false
		if condition.has("minute") and GameClock.minutes < float(condition.minute): return false
		if condition.has("direction") and direction == "": return false
	return true

func refresh() -> void:
	if committing: return
	committing = true
	var updated := false
	for definition in definitions:
		if definition.id in completed or not conditions_met(definition.unlock): continue
		if not conditions_met(definition.completion): continue
		var reward: Dictionary = definition.reward
		if reward.get("settled_by","") == "" and not Inventory.exchange({},reward.get("items",{}),int(reward.get("coins",0))): continue
		completed.append(definition.id)
		Playtest.record("task",{"id":"letters:"+str(definition.id)})
		updated = true
	committing = false
	if updated:
		changed.emit()
		Events.progress_committed.emit()

func progress(definition: Dictionary) -> String:
	if definition.id in completed: return "已完成 · 奖励已结算"
	if not conditions_met(definition.unlock): return "尚未解锁"
	var parts: Array[String] = []
	for condition in definition.completion:
		if condition.has("fact"):
			parts.append("%s %d/%d" % [condition.get("label",condition.fact),mini(int(facts.get(condition.fact,0)),int(condition.get("count",1))),int(condition.get("count",1))])
		elif condition.has("build"): parts.append("%s %s" % [VillageProjects.definitions[condition.build].name,"✓" if VillageProjects.has_project(condition.build) else "○"])
		elif condition.has("direction"): parts.append(DIRECTIONS.get(direction,"尚未选择发展方向"))
		elif condition.has("minute"): parts.append("18:00 后" if GameClock.minutes < 1080 else "已到傍晚")
	return " · ".join(parts)

func next_task() -> Dictionary:
	# 第二章只调整推荐顺序，三个方向的任务全部可以完成。
	if Story.stage == 8 and direction != "":
		for definition in definitions:
			if definition.id == direction+"_start" and definition.id not in completed: return definition
	for definition in definitions:
		if definition.id not in completed and conditions_met(definition.unlock): return definition
	return {}

func can_finish(scene: Dictionary) -> bool:
	for id in scene.get("requires_facts",[]):
		if not knows(id): return false
	return true

func _process(delta: float) -> void:
	if GameState.modal: return
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if player and GameState.location == "village" and player.global_position.x > 950 and Story.stage >= 5 and not knows("east_bank"):
		record("east_bank")
	refresh()

func snapshot() -> Dictionary:
	return {"facts":facts.duplicate(true),"completed":completed.duplicate(),"direction":direction,"legacy_review":legacy_review}

func restore(saved: Dictionary) -> void:
	facts = saved.get("facts",{}).duplicate(true)
	completed.clear()
	for id in saved.get("completed",[]): completed.append(id)
	direction = saved.get("direction","")
	legacy_review = saved.get("legacy_review",false)
	changed.emit()

func migrate(story: Dictionary, journal: Array = []) -> Dictionary:
	# v3 的每个 stage 是已结算事务；只标记旧任务完成，绝不再发奖励或扣费。
	var result := {"facts":{},"completed":[],"direction":"","legacy_review":int(story.stage)>0}
	for action in journal:
		var action_id: String = {"翻土":"till","播种":"plant","浇水":"water","收获":"harvest"}.get(action,"")
		if action_id != "": result.facts[action_id] = 1
	var milestones := {"letter":1,"welcome":2,"harvest":3,"carpenter":4,"bridge":5,"mill":6,"supper":7,"festival":8}
	for id in milestones:
		if int(story.stage) >= int(milestones[id]): result.facts["scene:"+id] = 1
	for definition in definitions:
		if int(definition.get("legacy_stage",99)) <= int(story.stage): result.completed.append(definition.id)
	# 已走过的前置免补课，未做的调查仍可在地图中发现。
	if int(story.stage) >= 3:
		for id in ["plant","water","harvest"]: result.facts[id] = 1
	if int(story.stage) >= 4:
		for id in ["bridge_survey","repair_record"]: result.facts[id] = 1
	if int(story.stage) >= 5: result.facts.guestbook = 1
	if int(story.stage) >= 6: result.facts.east_bank = 1
	return result

func validate(saved: Variant) -> bool:
	if not saved is Dictionary or not saved.get("facts") is Dictionary or not saved.get("completed") is Array: return false
	if saved.get("direction") not in ["","trade","explore","life"] or not saved.get("legacy_review") is bool: return false
	var allowed := ["till","plant","water","harvest","gather","east_bank","farm","cargo_departure","cargo_name","chapter2:plant","chapter2:gather","talk:linya","talk:zhou","talk:ahe","build:well","build:cooperative","build:arbor"]
	for id in Story.data.scenes:
		allowed.append(id)
		allowed.append("scene:"+str(id))
	for id in saved.facts:
		if id not in allowed or not FarmSaveSchema.whole(saved.facts[id],1,999999): return false
	var ids: Array = []
	for definition in definitions: ids.append(definition.id)
	var unique := {}
	for id in saved.completed:
		if id not in ids or unique.has(id): return false
		unique[id] = true
	return true
