extends Node
## 传说层新增目标独立于旧任务/婚姻，不擦掉任何旧结算。
signal changed
var state: Dictionary={}
var data: Dictionary={}
func defaults() -> Dictionary:
	return {"legacy_vow":false,"greenhouse":0,"deduction":0,"review":false,"evidence":[],"trials":[],"contract":{},"gifts":[],"survey_day":0,"choice":""}
func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://resources/abyss/legend.json"))
	state=defaults()
func migrate(x: Dictionary, star: Dictionary) -> Dictionary:
	var s := defaults()
	# 已经求婚/结婚的v8玩家沿用确认过的婚约；其他进度保留并接入新增目标。
	s.legacy_vow=x.get("married",false) or "proposal" in star.get("events",[])
	s.greenhouse=5 if x.get("married",false) else (2 if x.get("greenhouse",false) else 0)
	if star.get("wedding_phase",0)>0: s.legacy_vow=true
	return s
func marriage_gate() -> bool:
	return state.legacy_vow or (state.greenhouse>=4 and state.deduction==3 and state.trials.size()==5 and AbyssState.state.max_clear>=(20 if River.state.legacy_rules else 100) and StarStory.has("kept_appointment") and not StarStory.state.repair_pending)
func observe_evidence(depth: int) -> void:
	if depth in [10,12,20] and depth not in state.evidence: state.evidence.append(depth)
	if state.review: state.review=false
	if Xiaojing.state.unlocked and state.survey_day<GameClock.day:
		state.survey_day=GameClock.day
		Xiaojing.boost(0,1,0,"field_research")
		Xiaojing.changed.emit()
	LegendTrials.observed(depth)
	commit()
func infer(memory: String, record: int) -> bool:
	if not StarStory.near_point("greenhouse") or Xiaojing.state.memories.size()!=7 or state.review or state.deduction>=3: return false
	for id in [10,12,20]:
		if id not in state.evidence: return false
	var solution := [["bridge",10],["pond",12],["post",20]]
	var required: Array=solution[int(state.deduction)]
	if memory!=required[0] or record!=required[1]:
		state.deduction=0
		state.review=true
		Events.notice.emit("证据和结论接不上。回到深渊记录处复核一份原件，再回来推理；不靠乱按结算。")
		commit()
		return false
	state.deduction+=1
	if state.deduction==3:
		StarStory.mark("history_solved")
		Xiaojing.boost(0,3,2,"deduction")
		Xiaojing.changed.emit()
	commit()
	return true
func repair() -> bool:
	if not StarStory.near_point("greenhouse") or not Xiaojing.state.unlocked or state.greenhouse>=4: return false
	var stage: int=state.greenhouse
	if stage==0 and not StarStory.has("vent_repaired"): return false
	if stage==1 and Xiaojing.state.quests.size()!=12: return false
	if stage==2 and (state.choice=="" or 12 not in state.evidence or not VillageProjects.has_project("well") or AbyssState.state.max_clear<12): return false
	if stage==3 and (state.deduction!=3 or "planning" not in state.trials or AbyssState.state.max_clear<20 or not MineState.state.furnace): return false
	var step: Dictionary=data.greenhouse[stage]
	var rewards: Dictionary={}
	if stage==2: rewards={"wheat_seed":4} if state.choice=="water_first" else {"copper_ore":4}
	if not Inventory.exchange(step.required,rewards,-int(step.coins)): return false
	state.greenhouse+=1
	Playtest.record("task",{"id":"greenhouse:"+str(state.greenhouse)})
	if state.greenhouse==4:
		Xiaojing.state.greenhouse=true
		StarStory.event("act_starlight")
		Xiaojing.changed.emit()
	commit()
	return true
func wedding_committed() -> void:
	state.greenhouse=5
	commit()
func visit_depth(depth: int) -> void:
	LegendTrials.visited(depth)
func gift_gain(item: String, entry: Dictionary) -> void:
	# 喜好影响好感，信任来自证据/行动，羁绊来自共同活动。连续同礼不再刷三维。
	var repeated: bool=item in state.gifts.slice(maxi(0,state.gifts.size()-3))
	if not repeated: Xiaojing.boost(int(entry.affection),0,0,"gift:"+item)
	else: Events.notice.emit("这份样本已经有了。不必反复送同一种，我们可以去完成各自的计划。")
	state.gifts.append(item)
	if state.gifts.size()>6: state.gifts.pop_front()
	commit()
func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(saved: Dictionary) -> void:
	state=saved.duplicate(true)
	changed.emit()

func choose(value: String) -> bool:
	if not StarStory.near_point("greenhouse") or state.deduction!=3 or state.choice!="" or value not in ["water_first","open_records"]: return false
	state.choice=value
	commit()
	return true
