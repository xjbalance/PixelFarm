extends Node
## 深化剧情独立保存；旧任务/关系/钻石仍由Xiaojing负责，不在回顾时重新领奖。
signal changed
var data: Dictionary = {}
var state: Dictionary = {}
var game: Node
var tick: float = 0

func defaults() -> Dictionary:
	return {"events":[],"facts":[],"choices":{},"assembly":0,"appointment":{},"repair_pending":false,
		"invited":[],"wedding_phase":0,"cooperate_day":0,"season_done":-1,"season_run":{},
		"post_run":"","post_steps":[],"challenge":{},"gift_mood_day":0,"legacy_import":false}

func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/star1314.json"))
	state=defaults()
	GameClock.day_advanced.connect(check_dates)

func bind(owner_game: Node) -> void:
	game=owner_game

func has(id: String) -> bool:
	return id in state.facts or id in state.events

func mark(id: String) -> void:
	if id not in state.facts: state.facts.append(id)

func event(id: String) -> void:
	if id not in state.events: state.events.append(id)

func near_point(id: String) -> bool:
	if GameState.location=="greenhouse":
		return StarCeremony.near({"greenhouse":"archive","desk_left":"ceremony_left","desk_right":"ceremony_right"}.get(id,id))
	if not data.points.has(id) or not is_instance_valid(game): return false
	var entry: Dictionary=data.points[id]
	var at := Vector2(entry.position[0],entry.position[1])
	return GameState.location==entry.area and game.player.global_position.distance_to(at)<=64 and game.auto_move.navigation.line_of_sight(game.player.global_position,at)

func near_person(id: String) -> bool:
	if not is_instance_valid(game): return false
	for object in get_tree().get_nodes_in_group("interactables"):
		if "person_id" in object and object.person_id==id and object.is_visible_in_tree() and object.global_position.distance_to(game.player.global_position)<=64: return true
	return false

func near_memory(id: String) -> bool:
	if not is_instance_valid(game): return false
	for memory in Xiaojing.data.memories:
		if memory.id==id and GameState.location==memory.location:
			var at := Vector2(memory.position[0],memory.position[1])
			if game.player.global_position.distance_to(at)<=64 and game.auto_move.navigation.line_of_sight(game.player.global_position,at): return true
	for key in MineState.placements:
		var entry: Dictionary=MineState.placements[key]
		if entry.get("memory","")==id and MineState.near_id(key): return true
	return false

func memory_action(id: String, option: int) -> bool:
	if not Xiaojing.state.unlocked or not near_memory(id): return false
	if not River.memory_ready(id):
		Events.notice.emit(River.data.memories[id].hint)
		return false
	if option!=0:
		Events.notice.emit("和另一张记录对不上。先留下空白，重新比较也来得及。")
		return false
	if id not in Xiaojing.state.memories:
		Xiaojing.state.memories.append(id)
		Playtest.record("task",{"id":"memory:"+id})
	if id not in River.state.memory_seen: River.state.memory_seen.append(id)
	Events.notice.emit(River.data.memories[id].text)
	if GameState.location in ["farm","home","village"] and GameState.location not in Xiaojing.state.visited: Xiaojing.state.visited.append(GameState.location)
	mark("memory:"+id)
	if id=="pond": post_observation("sample_pond")
	Xiaojing.commit()
	commit()
	return true

func inspect_greenhouse() -> bool:
	if not Xiaojing.state.unlocked or not near_point("greenhouse"): return false
	mark("greenhouse_survey")
	event("act_greenhouse")
	commit()
	return true

func repair_vent() -> bool:
	if not near_point("greenhouse") or not has("greenhouse_survey") or has("vent_repaired"): return false
	if not Inventory.exchange({"wood":2,"stone":2},{},0): return false
	mark("vent_repaired")
	commit()
	return true

func assemble(memory: String) -> bool:
	if not near_point("greenhouse") or Xiaojing.state.memories.size()!=7 or has("history_solved"): return false
	var solution := ["window","bridge","post"]
	if memory!=solution[int(state.assembly)]:
		state.assembly=0
		Events.notice.emit("日期不连贯。先育苗，再安置，最后才是停用的决定；可以重新摆。")
		commit()
		return false
	state.assembly+=1
	if state.assembly==3:
		state.assembly=0
		mark("history_solved")
		event("act_memories")
		Xiaojing.boost(0,2,2,"memory_assembly")
		Xiaojing.changed.emit()
	commit()
	return true

func choose(topic: String, value: String) -> bool:
	if topic not in data.choices or value not in data.choices[topic] or state.choices.has(topic): return false
	if topic=="tables" and (not Xiaojing.nearby() or "tea_together" not in Xiaojing.state.quests): return false
	if topic=="closure" and (not near_point("greenhouse") or not has("history_solved")): return false
	state.choices[topic]=value
	commit()
	return true

func season_index() -> int:
	return Calendar.season()

func season_serial() -> int:
	return Calendar.season_serial()

func daily_text() -> String:
	var s: Dictionary=Xiaojing.state
	var group: String="married" if s.married else ("dating" if s.dating else "early")
	var lines: Array=data.daily[group]
	var index: int=posmod(GameClock.day-int(s.wedding_day) if s.married else GameClock.day,lines.size())
	var result: String=lines[index]+"\n"+SeasonalDialogue.line("xiaojing")+"\n"+data.weather["rain" if GameWeather.is_rainy() else "clear"]+"\n"+data.season_lines[season_index()]
	if s.married and GameClock.day-int(s.wedding_day)==520: result="今天正好是婚后经过的第520天。我把那封回信放在温室档案桌了。\n"+result
	elif s.married and GameClock.day>int(s.wedding_day) and (GameClock.day-int(s.wedding_day))%112==0: result="又走完一个四季。想从今年没做成的小事开始聊吗？\n"+result
	elif Social.is_birthday("xiaojing"): result="今天是我的生日。我想早一点收工，去看看上次留的种子。\n"+result
	if state.gift_mood_day==GameClock.day: result+="\n那份石料我放进了公用箱。礼物不用勉强，先问问就好。"
	if LegendState.state.choice!="": result+="\n"+{"water_first":"先留好居民的清水，温室的种源慢慢补；我把检修日写在井边。","open_records":"今天又有人来查旧档案。我留了空页，不替后来的人写结论。"}[LegendState.state.choice]
	if state.repair_pending: result+="\n上次没等到你，我有点失落。愿意的话，先说说发生了什么，再约一个能做到的时间。"
	for key in ["tables","closure"]:
		if state.choices.has(key): result+="\n"+str(data.choices[key][state.choices[key]])
	return result

func book_appointment() -> bool:
	if not Xiaojing.nearby() or not Xiaojing.state.dating or not state.appointment.is_empty() or state.repair_pending or not VillageProjects.has_project("arbor"): return false
	state.appointment={"day":GameClock.day+1,"status":"booked"}
	commit()
	return true

func check_dates() -> void:
	if state.appointment.get("status","")=="booked" and (GameClock.day>int(state.appointment.day) or (GameClock.day==int(state.appointment.day) and GameClock.minutes>=1200)):
		state.appointment.status="missed"
		state.repair_pending=true
		commit()

func attend_appointment() -> bool:
	check_dates()
	if state.appointment.get("status","")!="booked" or GameClock.day!=int(state.appointment.day) or GameClock.minutes<1080 or GameClock.minutes>=1200 or not Xiaojing.nearby() or GameState.location!="village": return false
	state.appointment={}
	if River.state.post=="outing" and "tea" not in River.state.post_steps: River.state.post_steps.append("tea")
	event("kept_appointment")
	Xiaojing.boost(0,1,1,"kept_appointment")
	Xiaojing.changed.emit()
	commit()
	return true

func repair_relationship() -> bool:
	if not Xiaojing.nearby() or not state.repair_pending: return false
	state.repair_pending=false
	state.appointment={}
	event("repaired_promise")
	# 不返还礼物、不重复加属性；错误不会造成永久锁婚。
	commit()
	return true

func relationship_gate(id: String) -> bool:
	if id in Xiaojing.state.events: return true
	match id:
		"flower": return "flowers" in Xiaojing.state.quests
		"secret": return has("history_solved") and state.choices.has("tables")
		"promise": return "cave" in Xiaojing.state.trials and not state.repair_pending
		"stars": return Xiaojing.state.greenhouse and has("history_solved")
	return true

func proposal_ready() -> bool:
	return LegendState.marriage_gate() and Xiaojing.base_marriage_ready() and has("history_solved") and state.choices.has("tables") and state.choices.has("closure") and not state.repair_pending

func propose(choice: String) -> bool:
	if not Xiaojing.nearby() or has("proposal") or choice not in ["share_home","keep_journeys"]: return false
	if not Xiaojing.marriage_goals_ready():
		Events.notice.emit(Xiaojing.marriage_goals_missing_text());return false
	if not proposal_ready(): return false
	state.choices.future=choice
	event("proposal")
	commit()
	return true

func invite(id: String) -> bool:
	if not has("proposal") or id not in ["linya","zhou","ahe"] or id in state.invited or not near_person(id): return false
	state.invited.append(id)
	commit()
	return true

func start_ceremony() -> bool:
	if near_point("greenhouse") and not Xiaojing.state.married and not Xiaojing.marriage_goals_ready():
		Events.notice.emit(Xiaojing.marriage_goals_missing_text());return false
	if not near_point("greenhouse") or not proposal_ready() or not has("proposal") or state.invited.size()!=3 or state.wedding_phase!=0: return false
	state.wedding_phase=1
	commit()
	if not River.state.legacy_scene:
		game.hud.close_active_panel()
		StarCeremony.enter()
	return true

func place_wedding_table() -> bool:
	if state.wedding_phase!=1 or not near_point("desk_left"): return false
	state.wedding_phase=2
	commit()
	return true

func wedding_ready() -> bool:
	return Xiaojing.marriage_goals_ready() and StarCeremony.ready() and LegendState.marriage_gate() and has("proposal") and state.invited.size()==3 and state.wedding_phase==2 and near_point("desk_right") and not state.repair_pending

func wedding_committed() -> void:
	LegendState.wedding_committed()
	state.wedding_phase=3
	event("act_star1314")
	event("wedding")
	commit()

func finish_ceremony() -> bool:
	if not River.state.legacy_scene and (River.state.wedding_step<3 or not StarCeremony.near("vows")): return false
	if not Xiaojing.state.married or state.wedding_phase!=3 or not (near_point("greenhouse") or near_point("desk_right") or StarCeremony.near("vows")): return false
	state.wedding_phase=4
	commit()
	return true

func start_post(id: String) -> bool:
	if not Xiaojing.state.married or not near_point("greenhouse") or id not in ["separate_desks","field_trip"] or id in Xiaojing.state.post_events or state.post_run!="": return false
	state.post_run=id
	state.post_steps=[]
	commit()
	return true

func post_observation(id: String) -> void:
	if state.post_run=="" or id not in data.post_events[state.post_run].goals or id in state.post_steps: return
	state.post_steps.append(id)

func work_desk(id: String) -> bool:
	if id not in ["desk_left","desk_right"] or not near_point(id) or state.post_run!="separate_desks": return false
	post_observation(id)
	commit()
	return true

func post_ready(id: String) -> bool:
	if id=="day520": return Xiaojing.state.married and GameClock.day-int(Xiaojing.state.wedding_day)>=520 and (near_point("greenhouse") or Xiaojing.nearby())
	if state.post_run!=id or not near_point("greenhouse"): return false
	for goal in data.post_events[id].goals:
		if goal not in state.post_steps: return false
	return true

func post_finished(id: String) -> void:
	if id==state.post_run:
		state.post_run=""
		state.post_steps=[]
	Playtest.record("task",{"id":"post:"+id})
	commit()

func cooperate() -> bool:
	if not Xiaojing.state.married or not near_point("greenhouse") or state.cooperate_day>=GameClock.day or "separate_desks" not in Xiaojing.state.post_events: return false
	var count := 0
	var keys: Array=game.farm.plots.keys()
	keys.sort()
	for key in keys:
		var plot: Dictionary=game.farm.plots[key]
		if str(plot.crop)=="" or plot.watered: continue
		plot.watered=true
		count+=1
		if count==6: break
	if count==0: return false
	state.cooperate_day=GameClock.day
	game.farm.changed.emit()
	game.farm.queue_redraw()
	Events.notice.emit("你检查窗闩，小京照料了%d格缺水作物。今天的协作已完成。" % count)
	commit()
	return true

func start_season() -> bool:
	if not Xiaojing.state.married or not near_point("greenhouse") or state.season_done==season_serial(): return false
	if not state.season_run.is_empty() and int(state.season_run.season)==season_serial(): return false
	state.season_run={"season":season_serial(),"plant":0,"water":0,"harvest":0,"lamp":false}
	commit()
	return true

func finish_season() -> bool:
	if not near_point("greenhouse") or state.season_run.is_empty() or int(state.season_run.season)!=season_serial(): return false
	var s: Dictionary=state.season_run
	var ready: bool=[s.plant>=3,s.water>=6,s.harvest>=3,s.lamp][season_index()]
	if not ready or not Inventory.exchange({},{"wheat_seed":2},0): return false
	state.season_done=season_serial()
	state.season_run={}
	Xiaojing.boost(0,0,1,"season_activity")
	Xiaojing.changed.emit()
	commit()
	return true

func on_farm(action: String) -> void:
	var id: String={"播种":"plant","浇水":"water","收获":"harvest"}.get(action,"")
	if id!="" and not state.season_run.is_empty() and int(state.season_run.season)==season_serial(): state.season_run[id]=mini(999999,int(state.season_run[id])+1)

func winter_lamp() -> bool:
	if not near_point("desk_right") or season_index()!=3 or state.season_run.is_empty(): return false
	state.season_run.lamp=true
	commit()
	return true

func _process(delta: float) -> void:
	if GameState.modal or not GameClock.running: return
	tick+=delta
	if tick<0.5: return
	tick=0
	check_dates()

func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(saved: Dictionary) -> void:
	state=saved.duplicate(true)
	changed.emit()

func migrate(old: Dictionary) -> Dictionary:
	var result := defaults()
	result.legacy_import=true
	if old.get("unlocked",false): result.events.append("act_seed520")
	if "route_notes" in old.get("quests",[]): result.facts.append_array(["greenhouse_survey","vent_repaired"]); result.events.append("act_greenhouse")
	if old.get("memories",[]).size()==7:
		result.facts.append("history_solved")
		result.events.append("act_memories")
		result.choices.closure="water"
	if "tea_together" in old.get("quests",[]): result.choices.tables="separate"
	if "cave" in old.get("trials",[]): result.events.append("act_valley")
	if old.get("greenhouse",false): result.events.append("act_starlight")
	if old.get("married",false):
		result.events.append_array(["proposal","wedding","act_star1314"])
		result.invited=["linya","zhou","ahe"]
		result.wedding_phase=4
		result.choices.future="share_home"
	return result
