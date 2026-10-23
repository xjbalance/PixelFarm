extends Node
## 独立隐藏支线；播种从农田提交点计数，不订阅可重复的展示信号。
signal changed
var data: Dictionary = {}
var state: Dictionary = {}
var committing: bool = false
var timer: float = 0

func defaults() -> Dictionary:
	return {"plants":0,"plant_serial":0,"letter_ready":false,"unlocked":false,"affection":0,"trust":0,"bond":0,
		"talk_day":0,"gift_day":0,"activity_day":0,"events":[],"quests":[],"memories":[],"visited":[],
		"dating":false,"greenhouse":false,"proposed":false,"married":false,"wedding_day":0,"ultimate":false,
		"diamonds":0,"ore":0,"mineral_counter":0,"order_day":0,"relic_claimed":false,
		"counters":{"plant":0,"activity":0,"puzzle":0},"quest_baseline":{"plant":0,"activity":0,"puzzle":0},
		"trials":[],"trial":{},"puzzle_step":0,"mechanism":0,"mechanism_moves":0,"cave":{},"post_events":[]}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/xiaojing.json"))
	state = defaults()

func commit_successful_plant(serial: int) -> void:
	if state.plants >= 999999 or serial != int(state.plant_serial)+1: return
	state.plant_serial = serial
	state.plants = mini(999999,int(state.plants)+1)
	Playtest.record("plant",{"plants":state.plants})
	if state.plants==520: Playtest.record("unlock",{"id":"plants520"})
	if state.unlocked: state.counters.plant += 1
	if not state.trial.is_empty():
		state.trial.plants += 1
	commit()

func on_farm_commit(action: String, cell: Vector2i, crop: String) -> void:
	var eligible: bool=not state.trial.is_empty() and state.trial.sown.has("%d,%d" % [cell.x,cell.y])
	StarTrials.on_farm(action,crop,eligible)
	StarStory.on_farm(action)
	LegendTrials.farm(action,cell,crop)
	River.farm(action,cell,crop)
	if action == "播种":
		commit_successful_plant(int(state.plant_serial)+1)
		if not state.trial.is_empty(): state.trial.sown["%d,%d" % [cell.x,cell.y]] = crop
	elif action == "收获" and not state.trial.is_empty():
		var id := "%d,%d" % [cell.x,cell.y]
		if state.trial.sown.has(id):
			state.trial.harvest += 1
			state.trial.outputs[crop] = int(state.trial.outputs.get(crop,0))+1
			state.trial.sown.erase(id)
	commit()

func on_gather(kind: String, amount: int) -> void:
	# v7 起农场普通石堆不再产出可兑换钻石的原矿；旧库存保留。
	if not state.trial.is_empty(): state.trial[kind] += amount
	commit()

func on_trade(coins: int, item: String, quantity: int) -> void:
	LegendTrials.trade(item,quantity,coins)
	if state.trial.is_empty(): return
	if coins < 0:
		state.trial.profit += coins
	elif state.trial.outputs.has(item):
		var eligible := mini(quantity,int(state.trial.outputs[item]))
		state.trial.profit += eligible*Catalog.sell_price(item)
		StarTrials.on_trade(item,eligible)
		state.trial.outputs[item] -= eligible
	commit()

func _process(delta: float) -> void:
	if GameState.modal or not GameClock.running: return
	timer += delta
	if timer < 0.5: return
	timer = 0
	check_night()
	if state.married and GameClock.day-state.wedding_day >= 520 and not state.ultimate:
		state.ultimate = true
		Events.notice.emit("小京在温室留下了一封新的信。")
		commit()

func check_night() -> void:
	if state.plants >= 520 and not state.letter_ready and not state.unlocked and GameClock.minutes >= 1200:
		state.letter_ready = true
		Events.notice.emit("信箱里多了一封没有邮戳的信。")
		commit()

func read_letter() -> bool:
	if not state.letter_ready or state.unlocked: return false
	state.unlocked = true
	Playtest.record("unlock",{"id":"xiaojing"})
	StarStory.event("act_seed520")
	state.letter_ready = false
	commit()
	return true

func nearby() -> bool:
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if player == null: return false
	for object in get_tree().get_nodes_in_group("xiaojing"):
		if object.is_visible_in_tree() and object.global_position.distance_to(player.global_position) <= 76: return true
	return false

func boost(affection: int, trust: int, bond: int, source: String = "legacy") -> void:
	var before := Vector3i(state.affection,state.trust,state.bond)
	state.affection = clampi(int(state.affection)+affection,0,100)
	state.trust = clampi(int(state.trust)+trust,0,100)
	state.bond = clampi(int(state.bond)+bond,0,100)
	var gain := Vector3i(state.affection,state.trust,state.bond)-before
	if gain!=Vector3i.ZERO: Playtest.record("relationship",{"source":source,"affection":gain.x,"trust":gain.y,"bond":gain.z})
	if before!=Vector3i(100,100,100) and Vector3i(state.affection,state.trust,state.bond)==Vector3i(100,100,100): Playtest.record("unlock",{"id":"relationship100"})

func talk() -> bool:
	if not state.unlocked or not nearby() or state.talk_day >= GameClock.day:
		Events.notice.emit("今天已经聊过了。她还要继续自己的工作，明天再交换见闻。")
		return false
	state.talk_day = GameClock.day
	boost(1,0,0,"daily_talk")
	commit()
	return true

func gift(item: String) -> bool:
	if not state.unlocked or not nearby() or state.gift_day>=GameClock.day or not StarStory.data.gifts.has(item): return false
	if not Inventory.exchange({item:1},{},0): return false
	var entry: Dictionary=StarStory.data.gifts[item]
	state.gift_day=GameClock.day
	LegendState.gift_gain(item,entry)
	if entry.taste=="不喜欢": StarStory.state.gift_mood_day=GameClock.day
	Events.notice.emit(entry.text)
	commit()
	return true

func visit_memory(id: String) -> bool:
	return StarStory.memory_action(id,0)

func current_quest() -> Dictionary:
	for quest in data.quests:
		if quest.id not in state.quests: return quest
	return {}

func quest_ready(quest: Dictionary) -> bool:
	if quest.is_empty() or quest.id in state.quests or not state.unlocked: return false
	if quest.previous != "" and quest.previous not in state.quests: return false
	for fact in quest.get("extra_facts",[]):
		if not StarStory.has(fact): return false
	for id in quest.conditions:
		var goal = quest.conditions[id]
		if id == "memory" and state.memories.size() < int(goal): return false
		if id == "locations" and state.visited.size() < int(goal): return false
		if id == "trial" and goal not in state.trials: return false
		if id in ["plant","activity","puzzle"] and int(state.counters[id])-int(state.quest_baseline[id]) < int(goal): return false
	return true

func finish_quest() -> bool:
	var quest := current_quest()
	if committing or not nearby() or not quest_ready(quest): return false
	committing = true
	if not Inventory.exchange(quest.materials,{},0):
		committing = false
		return false
	state.quests.append(quest.id)
	boost(int(quest.reward.affection),int(quest.reward.trust),int(quest.reward.bond),"quest:"+str(quest.id))
	Playtest.record("task",{"id":"xiaojing:"+str(quest.id)})
	state.quest_baseline = state.counters.duplicate(true)
	committing = false
	commit()
	return true

func available_event() -> Dictionary:
	for event in data.events:
		if event.id in state.events: continue
		if not StarStory.relationship_gate(event.id): return {}
		if state.affection >= int(event.threshold) and state.trust >= int(event.threshold) and state.bond >= int(event.threshold): return event
	return {}

func finish_event(id: String, accept_dating: bool = false) -> bool:
	var event := available_event()
	if not nearby() or event.is_empty() or event.id != id: return false
	if id == "secret" and not accept_dating: return false
	state.events.append(id)
	if id == "secret": state.dating = true
	if id in ["flower","promise"]: boost(0,0,3,"relationship_event:"+id)
	commit()
	return true

func activity() -> bool:
	if not nearby() or GameState.location != "village" or GameClock.minutes < 1080 or state.activity_day >= GameClock.day or not VillageProjects.has_project("arbor"): return false
	state.activity_day = GameClock.day
	state.counters.activity += 1
	boost(0,0,1,"tea_activity")
	commit()
	return true

func puzzle_input(symbol: int) -> bool:
	if not state.unlocked or symbol < 0 or symbol > 8: return false
	var hard: bool = state.trial.get("id","") == "mechanism"
	if hard: return mechanism_input(symbol)
	if symbol > 2 or not StarStory.near_point("seed_box"): return false
	var solution: Array = [0,2,1]
	if symbol != int(solution[int(state.puzzle_step)]):
		state.puzzle_step = 0
		commit()
		return false
	state.puzzle_step += 1
	if state.puzzle_step == solution.size():
		state.puzzle_step = 0
		state.counters.puzzle += 1
		River.memory_step("hearth","box")
		if hard: pass_trial("mechanism")
	commit()
	return true

func start_trial(id: String) -> bool:
	if LegendTrials.active() or not nearby() or Story.stage < 8 or state.quests.size() < 7 or id not in ["management","planning","cave","mechanism","joint"] or id in state.trials or not state.trial.is_empty(): return false
	if id == "joint" and state.trials.size() < 4: return false
	if id == "mechanism" and state.memories.size() < 7: return false
	if not StarTrials.begin(id): return false
	Playtest.record("trial_start",{"id":"basic:"+id})
	state.trial = {"id":id,"day":GameClock.day,"plants":0,"harvest":0,"profit":0,"wood":0,"stone":0,"sown":{},"outputs":{},"maps":[],"puzzles":int(state.counters.puzzle)}
	state.puzzle_step = 0
	state.mechanism = 0
	state.mechanism_moves = 0
	commit()
	return true

func check_trial() -> bool:
	if not nearby() or state.trial.is_empty(): return false
	var trial: Dictionary = state.trial
	var id: String = trial.id
	if id == "management" and GameClock.day-int(trial.day) <= 8 and trial.plants >= 24 and trial.harvest >= 24 and trial.profit >= 1800: return pass_trial(id)
	if id == "planning" and (GameClock.day-int(trial.day)<=3 if StarTrials.active("planning") else GameClock.day==int(trial.day)) and trial.wood >= 20 and trial.stone >= 12 and GameState.stamina >= 35: return pass_trial(id)
	if id == "joint" and state.memories.size() == 7 and trial.maps.size() == 3 and trial.harvest >= 6 and int(state.counters.puzzle)>int(trial.puzzles): return pass_trial(id)
	return false

func pass_trial(id: String) -> bool:
	if state.trial.get("id","") != id or id in state.trials or not StarTrials.complete(id): return false
	Playtest.record("trial_finish",{"id":"basic:"+id})
	state.trials.append(id)
	state.trial = {}
	StarTrials.settled(id)
	boost(1,1,1,"basic_trial:"+id)
	commit()
	return true

func record_location(location: String) -> void:
	if not state.trial.is_empty() and location not in state.trial.maps:
		state.trial.maps.append(location)
		commit()

func repair_greenhouse() -> bool:
	if not LegendState.state.legacy_vow: return LegendState.repair()
	if not nearby() or state.quests.size()!=12 or state.greenhouse: return false
	if not Inventory.exchange({"wood":80,"stone":60},{},-800): return false
	state.greenhouse = true
	LegendState.state.greenhouse=2
	StarStory.event("act_starlight")
	commit()
	return true

func base_marriage_ready() -> bool:
	return state.unlocked and not state.married and state.affection == 100 and state.trust == 100 and state.bond == 100 and state.events.size() == 5 and state.quests.size() == 12 and state.memories.size() == 7 and state.trials.size() == 5 and state.dating and state.greenhouse and state.diamonds >= 1314

func marriage_ready() -> bool:
	return base_marriage_ready() and StarStory.wedding_ready()

func confirm_wedding(confirm: bool) -> bool:
	if not confirm or committing or not marriage_ready(): return false
	committing = true
	state.diamonds -= 1314
	Playtest.record("diamonds",{"source":"wedding","delta":-1314})
	Playtest.record("wedding",{"id":"married"})
	state.proposed = true
	state.married = true
	state.wedding_day = GameClock.day
	StarStory.wedding_committed()
	committing = false
	commit()
	return true

func refine() -> bool:
	if not nearby() or not MineState.diamond_access() or state.ore < 5 or state.diamonds > 999997: return false
	if not Inventory.exchange({"stone":12},{},0): return false
	state.ore -= 5
	state.diamonds += 2
	Playtest.record("diamonds",{"source":"legacy_refine","delta":2})
	commit()
	return true

func hard_order() -> bool:
	return nearby() and MineState.complete_commission()

func claim_relic() -> bool:
	if not nearby() or not MineState.diamond_access() or state.memories.size()!=7 or state.relic_claimed: return false
	state.relic_claimed = true
	var gain: int=mini(18,999999-int(state.diamonds))
	state.diamonds += gain
	Playtest.record("diamonds",{"source":"memory_relic","delta":gain})
	commit()
	return true

func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)
	changed.emit()

func validate(saved: Variant, day: int) -> bool:
	if not saved is Dictionary: return false
	for key in defaults():
		if not saved.has(key): return false
	for key in ["plants","plant_serial","diamonds","ore","mineral_counter"]:
		if not FarmSaveSchema.whole(saved[key],0,999999): return false
	if saved.plants != saved.plant_serial: return false
	if saved.letter_ready and saved.unlocked: return false
	for key in ["affection","trust","bond"]:
		if not FarmSaveSchema.whole(saved[key],0,100): return false
	for key in ["talk_day","gift_day","activity_day","wedding_day","order_day"]:
		if not FarmSaveSchema.whole(saved[key],0,day): return false
	for key in ["letter_ready","unlocked","dating","greenhouse","proposed","married","ultimate","relic_claimed"]:
		if not saved[key] is bool: return false
	var ids := {"events":[],"quests":[],"memories":[],"visited":["farm","home","village"],"trials":["management","planning","cave","mechanism","joint"],"post_events":["separate_desks","field_trip","day520"]}
	for event in data.events: ids.events.append(event.id)
	for quest in data.quests: ids.quests.append(quest.id)
	for memory in data.memories: ids.memories.append(memory.id)
	for key in ids:
		if not saved[key] is Array: return false
		var unique := {}
		for id in saved[key]:
			if id not in ids[key] or unique.has(id): return false
			unique[id] = true
	for i in range(saved.quests.size()):
		if saved.quests[i] != data.quests[i].id: return false
	for i in range(saved.events.size()):
		if saved.events[i] != data.events[i].id: return false
	if (saved.unlocked or saved.letter_ready) and saved.plants < 520: return false
	if not saved.unlocked and (saved.quests.size()>0 or saved.events.size()>0 or saved.memories.size()>0 or saved.trials.size()>0 or saved.dating): return false
	for event in data.events:
		if event.id in saved.events and (saved.affection<int(event.threshold) or saved.trust<int(event.threshold) or saved.bond<int(event.threshold)): return false
	if saved.dating != ("secret" in saved.events): return false
	if saved.greenhouse and saved.quests.size()!=12: return false
	if saved.married and (not saved.proposed or not saved.greenhouse or not saved.dating or saved.events.size()!=5 or saved.trials.size()!=5 or saved.memories.size()!=7 or saved.wedding_day<1 or saved.affection!=100 or saved.trust!=100 or saved.bond!=100): return false
	if saved.proposed != saved.married: return false
	if saved.ultimate and (not saved.married or day-saved.wedding_day<520): return false
	for key in ["counters","quest_baseline"]:
		if not saved[key] is Dictionary or saved[key].size()!=3: return false
		for id in ["plant","activity","puzzle"]:
			if not FarmSaveSchema.whole(saved[key].get(id),0,999999): return false
	for id in saved.counters:
		if saved.quest_baseline[id]>saved.counters[id]: return false
	if not FarmSaveSchema.whole(saved.puzzle_step,0,2) or not FarmSaveSchema.whole(saved.mechanism,0,511) or not FarmSaveSchema.whole(saved.mechanism_moves,0,4): return false
	if not saved.trial is Dictionary or not saved.cave is Dictionary: return false
	if not saved.trial.is_empty():
		var t: Dictionary = saved.trial
		if t.get("id") not in ids.trials or t.id in saved.trials: return false
		for key in ["plants","harvest","wood","stone","puzzles"]:
			if not FarmSaveSchema.whole(t.get(key),0,999999): return false
		if not FarmSaveSchema.whole(t.get("day"),1,day) or not FarmSaveSchema.whole(t.get("profit"),-999999999,999999999): return false
		if not t.get("sown") is Dictionary or t.sown.size()>60 or not t.get("maps") is Array or not t.get("outputs") is Dictionary: return false
		for crop in t.outputs:
			if crop not in Catalog.crops or not FarmSaveSchema.whole(t.outputs[crop],0,999999): return false
		for cell in t.sown:
			if not cell is String or t.sown[cell] not in Catalog.crops: return false
			var parts: PackedStringArray = cell.split(",")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			if not Rect2i(17,16,10,6).has_point(Vector2i(int(parts[0]),int(parts[1]))): return false
		for loc in t.maps:
			if loc not in ["farm","home","village"]: return false
	return validate_cave(saved.cave)

func validate_cave(cave: Dictionary) -> bool:
	if cave.is_empty(): return true
	if not cave.get("hard") is bool: return false
	if not FarmSaveSchema.whole(cave.get("x"),0,8) or not FarmSaveSchema.whole(cave.get("y"),0,8) or not FarmSaveSchema.whole(cave.get("air"),0,60): return false
	if not cave.get("visited") is Array or not cave.get("mined") is Array: return false
	for cells in [cave.visited,cave.mined]:
		var unique := {}
		for cell in cells:
			if not FarmSaveSchema.whole(cell,0,80) or unique.has(cell): return false
			unique[cell] = true
	if cave_wall(int(cave.x),int(cave.y)): return false
	for id in cave.mined:
		if id not in [12,34,66,70] or id not in cave.visited: return false
	return true

func cave_wall(x: int, y: int) -> bool:
	return x <= 0 or y <= 0 or x >= 8 or y >= 8 or (x == 4 and y not in [3,7]) or (y == 4 and x in [1,3])

func start_cave(hard: bool = false) -> bool:
	Events.notice.emit("新勘探已迁至河湾村东北的实体矿道。旧路线盘仅可继续旧档未结束的一轮。")
	return false

func cave_move(direction: Vector2i) -> bool:
	if not nearby() or not MineState.state.legacy_board_claimable or state.cave.is_empty() or abs(direction.x)+abs(direction.y)!=1: return false
	var cave: Dictionary = state.cave
	var next := Vector2i(cave.x,cave.y)+direction
	if cave_wall(next.x,next.y) or cave.air <= 0: return false
	cave.x = next.x
	cave.y = next.y
	cave.air -= 1
	var id := next.y*9+next.x
	if id not in cave.visited: cave.visited.append(id)
	commit()
	return true

func cave_mine() -> bool:
	if not nearby() or not MineState.state.legacy_board_claimable or state.cave.is_empty() or state.cave.air<2: return false
	var cave: Dictionary = state.cave
	var id: int = int(cave.y)*9+int(cave.x)
	if id not in [12,34,66,70] or id in cave.mined: return false
	cave.mined.append(id)
	cave.air -= 2
	commit()
	return true

func leave_cave(abandon: bool = false) -> bool:
	if not nearby() or not MineState.state.legacy_board_claimable or state.cave.is_empty(): return false
	var cave: Dictionary = state.cave
	if not abandon and (cave.x != 1 or cave.y != 1): return false
	if not abandon and cave.mined.size() >= 3 and cave.air > 0:
		var gain: int=mini(3,999999-int(state.diamonds))
		state.diamonds += gain
		Playtest.record("diamonds",{"source":"legacy_board","delta":gain})
		state.ore = mini(999999,state.ore+cave.mined.size())
		if cave.hard and cave.mined.size()==4 and cave.visited.size()>=20 and cave.air>=4: pass_trial("cave")
	state.cave = {}
	MineState.state.legacy_board_claimable=false
	MineState.state.legacy_board_settled=true
	commit()
	return true

func post_event(id: String) -> bool:
	if not state.married or id in state.post_events or not StarStory.post_ready(id): return false
	if id not in ["separate_desks","field_trip","day520"]: return false
	if id == "day520":
		# 读档后立即阅读也按婚后经过日数判定，不等后台0.5秒轮询。
		if GameClock.day-int(state.wedding_day)<520: return false
		state.ultimate=true
	state.post_events.append(id)
	StarStory.post_finished(id)
	commit()
	return true

func mechanism_input(index: int) -> bool:
	if index < 0 or index > 8 or not MineState.at_star_lamp(index) or state.trial.get("id","") != "mechanism": return false
	var x := index%3
	var y := int(index/3)
	var mask := 1<<index
	for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var other: Vector2i = Vector2i(x,y)+offset
		if Rect2i(0,0,3,3).has_point(other): mask ^= 1<<(other.y*3+other.x)
	state.mechanism = int(state.mechanism)^mask
	state.mechanism_moves += 1
	if state.mechanism == 511:
		state.mechanism_moves = 0
		pass_trial("mechanism")
	elif state.mechanism_moves >= 5:
		Playtest.record("trial_fail",{"id":"basic:mechanism","reason":"five_moves"})
		state.mechanism = 0
		state.mechanism_moves = 0
		Events.notice.emit("五次尝试用尽，回路已复位。线索在收齐的记忆里。")
	commit()
	return true
