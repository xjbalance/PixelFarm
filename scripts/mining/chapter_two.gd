extends Node
## 第二章事实来自读完调查、实际机关与人物交谈；任务奖励与完成标志一起提交。
signal changed
var definitions: Array = []
var facts: Array[String] = []
var completed: Array[String] = []
var policy: String = ""
var committing: bool = false
const TALKS := {
	"linya":"矿物订单可以接，但我想先把农产品的车位写进去。别让一条新路挤掉另一条旧路。",
	"zhou":"父亲的签名旁还有两个人。他没有独自扛起那一天，也不该由我独自证明什么。水闸和支架，我们一起检查。",
	"ahe":"那夜有人留下开闸，有人用空车接人。口述记录里没有英雄的座次，只有每个人回来的时间。开放以后，也要把名字记全。"
}

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://resources/mining/chapter_two.json"))

func defaults() -> Dictionary:
	return {"facts":[],"completed":[],"policy":""}

func current() -> Dictionary:
	for quest in definitions:
		if quest.id not in completed: return quest
	return {}

func knows(id: String) -> bool:
	return id in facts

func record(id: String) -> void:
	if Story.stage < 8 or id in facts: return
	# 人物最后一轮讨论不能提前刷完；重访时还会提供交谈入口。
	if id.begins_with("talk:") and completed.size()<6: return
	facts.append(id)
	refresh()
	changed.emit()
	Events.progress_committed.emit()

func refresh() -> void:
	if committing or Story.stage < 8: return
	committing=true
	var updated := false
	for quest in definitions:
		if quest.id in completed: continue
		var ready := true
		for id in quest.conditions:
			if id not in facts: ready=false
		if not ready: break
		var items: Dictionary=quest.reward.get("items",{}).duplicate(true)
		# 第一章选择影响供给与对白，三个方向不会锁其他内容。
		if quest.id=="discussion":
			items.merge({"trade":{"copper_ore":6},"explore":{"crystal":3},"life":{"wheat":6}}.get(Letters.direction,{"wheat":3}),true)
		if quest.id=="echo_departure": items.merge({"trade":{"iron_bar":2},"explore":{"star_fragment":2},"life":{"wheat_seed":6}}.get(Letters.direction,{"wheat_seed":2}),true)
		if not Inventory.exchange({},items,int(quest.reward.get("coins",0))):
			Events.notice.emit("背包或金币已满，整理后在矿道手记领取任务奖励。")
			break
		completed.append(quest.id)
		Playtest.record("task",{"id":"chapter2:"+str(quest.id)})
		updated=true
		if quest.id=="entrance": MineState.unlock("mine_a")
		if quest.id=="records": MineState.unlock("mine_b")
		if quest.id=="water": MineState.unlock("mine_c")
		Events.notice.emit("山谷深处的回声 · "+quest.title+" 已记录")
	committing=false
	if updated:
		changed.emit()
		Events.progress_committed.emit()

func progress(quest: Dictionary) -> String:
	if quest.id in completed: return "已完成 · 奖励已结算"
	var count := 0
	for id in quest.conditions:
		if id in facts: count+=1
	return "%d / %d 项线索或行动" % [count,quest.conditions.size()]

func branch_line() -> String:
	return {"trade":"先为农产品保留运输车位，再商量矿物订单。","explore":"先留下水位和晶石的测量基线，再决定开采范围。","life":"先划定居民用水与值班轮换，再接新的生意。"}.get(Letters.direction,"先把每个人的需要听完，再决定矿道如何开放。")

func finish_discussion(choice: String) -> bool:
	if completed.size()!=7 or policy!="" or choice not in ["rotation","reserve","study"] or not MineState.near_service("discussion"): return false
	policy=choice
	record("discussion")
	return true

func snapshot() -> Dictionary:
	return {"facts":facts.duplicate(),"completed":completed.duplicate(),"policy":policy}

func restore(saved: Dictionary) -> void:
	facts.assign(saved.facts)
	completed.assign(saved.completed)
	policy=saved.policy
	changed.emit()

func validate(saved: Variant) -> bool:
	if not saved is Dictionary or not saved.get("facts") is Array or not saved.get("completed") is Array: return false
	if saved.get("policy") not in ["","rotation","reserve","study"]: return false
	var allowed: Array = []
	for quest in definitions: allowed.append_array(quest.conditions)
	allowed.append_array(["rail_hint","water_hint","resonance_hint","star_hint"])
	var seen := {}
	for id in saved.facts:
		if id not in allowed or seen.has(id): return false
		seen[id]=true
	if saved.completed.size()>definitions.size(): return false
	for i in range(saved.completed.size()):
		if saved.completed[i]!=definitions[i].id: return false
		for id in definitions[i].conditions:
			if id not in saved.facts: return false
	return (saved.policy!="") == ("discussion" in saved.facts)

func allowed_facts() -> Array:
	var result: Array=[]
	for q in definitions: result.append_array(q.conditions)
	return result
