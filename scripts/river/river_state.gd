extends Node
## 0.6.0章节/记忆与独立婚礼的补充事务；旧状态仍由原系统拥有。
signal changed
var state: Dictionary={}
var data: Dictionary={}
func defaults() -> Dictionary:
	return {"legacy_rules":false,"legacy_scene":false,"old_checkpoints":[],"old_contract":"","facts":[],"memory_steps":{},"memory_seen":[],"jobs":[],"crafted":{},"crop_count":0,"sown":{},"policy":"","weekly_day":0,"wedding_step":0,"venue_used":false,"post":"","post_steps":[],"post_done":[],"festival":-1,"ending_day":0,"ending_until":0.0}
func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://resources/river/river.json"))
	state=defaults()
func migrate(raw: Dictionary) -> Dictionary:
	var s := defaults()
	var old: Dictionary=raw.xiaojing
	s.legacy_scene=old.married or "proposal" in raw.star_story.events
	s.wedding_step=3 if old.married else 0
	s.memory_seen=old.memories.duplicate()
	for cp in [5,15]:
		if raw.abyss.max_clear>=cp: s.old_checkpoints.append(cp)
	s.old_contract=str(raw.legend.contract.get("id",""))
	return s
func has(id: String) -> bool: return id in state.facts
func record(id: String) -> void:
	if id not in state.facts: state.facts.append(id)
	if id in ChapterTwo.allowed_facts(): ChapterTwo.record(id)
	commit()
func observe_depth(depth: int) -> void:
	if depth in [20,40,60,80,100]: record("river"+str(depth))
	if state.post=="outing" and depth>=40 and "water" not in state.post_steps: state.post_steps.append("water"); commit()
func needs_talk(person: String) -> bool:
	if person=="ahe" and Xiaojing.state.unlocked and not memory_ready("post"): return true
	var previous: String={"linya":"backwater","zhou":"prism","ahe":"prototype"}.get(person,"")
	return previous!="" and previous in ChapterTwo.completed and not has("talk2:"+person)
func talk(person: String) -> bool:
	if not StarStory.near_person(person) or not needs_talk(person): return false
	var previous: String={"linya":"backwater","zhou":"prism","ahe":"prototype"}.get(person,"")
	if previous in ChapterTwo.completed: record("talk2:"+person)
	if person=="ahe" and Xiaojing.state.unlocked: memory_step("post","witness")
	return true
func farm(action: String, cell: Vector2i, crop: String) -> void:
	var key := "%d,%d" % [cell.x,cell.y]
	if action=="播种": state.sown[key]=crop
	elif action=="收获" and state.sown.get(key,"")==crop:
		state.sown.erase(key)
		if "backwater" in ChapterTwo.completed: state.crop_count=mini(999999,int(state.crop_count)+1)
		if state.crop_count>=6 and "backwater" in ChapterTwo.completed: record("new_crop6")
		if state.post=="seed_collab" and crop=="wheat" and "wheat" not in state.post_steps: state.post_steps.append("wheat")
		if state.post=="seed_collab" and crop=="potato" and "potato" not in state.post_steps: state.post_steps.append("potato")
func enqueue(job: Dictionary) -> void:
	if "prism" in ChapterTwo.completed and int(job.id) not in state.jobs: state.jobs.append(int(job.id))
func claim(job: Dictionary) -> void:
	if int(job.id) not in state.jobs: return
	state.jobs.erase(int(job.id))
	state.crafted[job.recipe]=int(state.crafted.get(job.recipe,0))+int(job.batches)
func prototype() -> bool:
	if not MineState.near_service("forge") or "testimony" not in ChapterTwo.completed or has("prototype") or int(state.crafted.get("iron_bar",0))<2: return false
	if not Inventory.exchange({"iron_bar":2,"crystal":2,"wood":4},{},0): return false
	record("prototype")
	return true
func choose_policy(value: String) -> bool:
	if not MineState.near_service("discussion") or "public_ledger" not in ChapterTwo.completed or state.policy!="" or value not in ["water","rotation","commons"]: return false
	state.policy=value
	record("closing_choice")
	return true
func end_chapter() -> bool:
	if not MineState.near_service("discussion") or "council_final" not in ChapterTwo.completed or has("closing_scene"): return false
	state.ending_day=GameClock.day
	state.ending_until=minf(1439,GameClock.minutes+40)
	record("closing_scene")
	StarStory.game.village.refresh_gathering()
	StarStory.game.world.refresh_linya()
	return true
func weekly() -> bool:
	if not MineState.near_service("discussion") or not has("closing_scene") or (state.weekly_day>0 and GameClock.day-int(state.weekly_day)<7): return false
	var reward: Dictionary={"water":{"wheat_seed":4},"rotation":{"iron_ore":4},"commons":{"crystal":2}}[state.policy]
	if not Inventory.exchange({"wheat":4,"wood":4},reward,20): return false
	state.weekly_day=GameClock.day
	commit()
	return true
func core(choice: String) -> bool:
	if not AbyssState.near("core") or 100 not in AbyssState.state.gates or has("star_core") or choice not in ["water","records"]: return false
	if not Inventory.exchange({},{"star_fragment":4},0): return false
	record("star_core")
	Events.notice.emit("归航台为地面留下水与灯。没有谁必须留在黑暗里，才能让别人回家。")
	return true
func memory_step(id: String, step: String) -> void:
	if not Xiaojing.state.unlocked or id not in memory_ids(): return
	if not state.memory_steps.has(id): state.memory_steps[id]=[]
	if step not in state.memory_steps[id]: state.memory_steps[id].append(step)
	commit()
func memory_ready(id: String) -> bool:
	if state.legacy_rules or id in state.memory_seen or id in Xiaojing.state.memories: return true
	var steps: Array=state.memory_steps.get(id,[])
	for step in data.memories[id].steps:
		if step not in steps: return false
	return true
func memory_ids() -> Array: return ["window","pond","bridge","mill","post","hearth","orchard"]
func begin_post(id: String) -> bool:
	if not Xiaojing.state.married or not StarStory.near_point("greenhouse") or state.post!="" or id in state.post_done or id not in ["seed_collab","outing"]: return false
	state.post=id;state.post_steps=[];commit();return true
func finish_post() -> bool:
	if not StarStory.near_point("greenhouse") or state.post=="": return false
	var goals: Array=["wheat","potato"] if state.post=="seed_collab" else ["water","tea"]
	for id in goals:
		if id not in state.post_steps: return false
	if not Inventory.exchange({},{"wheat_seed":4},0): return false
	state.post_done.append(state.post);state.post="";state.post_steps=[];commit();return true
func festival() -> bool:
	var season: int=int((GameClock.day-1)/28)
	if not Xiaojing.state.married or not Xiaojing.nearby() or (GameClock.day-1)%28!=27 or GameClock.minutes<1080 or state.festival==season: return false
	state.festival=season
	Xiaojing.boost(0,0,1,"festival");Xiaojing.changed.emit();commit();return true
func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(saved: Dictionary) -> void:
	state=saved.duplicate(true);changed.emit()

func gathering() -> bool:
	return has("closing_scene") and state.ending_day==GameClock.day and GameClock.minutes<state.ending_until
