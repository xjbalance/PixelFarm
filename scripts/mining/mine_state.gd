extends Node
## 采矿、工具、队列和一次性世界事务；输入层不能绕过距离/前置/容量校验。
signal changed
const AREAS := ["mine_a","mine_b","mine_c"]
var data: Dictionary = {}
var layouts: Dictionary = {}
var placements: Dictionary = {}
var services: Dictionary = {}
var state: Dictionary = {}
var game: Node
var walk_timer: float = 0

func defaults() -> Dictionary:
	return {"unlocked":[],"tool":1,"furnace":false,"queue":[],"job_serial":0,
		"ores":{},"chests":[],"track_repaired":false,"track_switch":0,"water_step":0,"water_lowered":false,
		"hardened":false,"resonance_step":0,"resonance_open":false,"survey":0,"diamond_counter":0,
		"legacy_board_claimable":false,"legacy_board_settled":false,"legacy_trials":[],"linked_memories":[],
		"expedition":{},"exploration_events":[],"commission_mines":[]}

func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://resources/mining/mining.json"))
	layouts=JSON.parse_string(FileAccess.get_file_as_string("res://resources/mining/maps.json"))
	for area in layouts:
		for entry in layouts[area].objects:
			var record: Dictionary=entry.duplicate(true)
			record.area=area
			placements[entry.id]=record
	services={
		"transport":{"area":"village","cell":[37,12],"title":"风车东侧的旧运输单"},
		"entrance":{"area":"village","cell":[36,6],"title":"封闭矿道入口"},
		"forge":{"area":"village","cell":[16,13],"title":"周砚的矿物工台"},
		"discussion":{"area":"village","cell":[23,21],"title":"矿道开放告示板"}}
	state=defaults()
	GameClock.day_advanced.connect(advance_day)
	Events.location_changed.connect(func(area: String):
		if not state.expedition.is_empty() and area in AREAS and area not in state.expedition.areas:
			state.expedition.areas.append(area)
	)

func bind(owner_game: Node) -> void:
	game=owner_game

func point(entry: Dictionary) -> Vector2:
	return Vector2(entry.cell[0]*32+16,entry.cell[1]*32+16)

func near_point(area: String, at: Vector2, distance: float = 60) -> bool:
	if not is_instance_valid(game) or GameState.location!=area: return false
	return game.player.global_position.distance_to(at)<=distance

func near_id(id: String) -> bool:
	if not placements.has(id): return false
	var entry: Dictionary=placements[id]
	if not near_point(entry.area,point(entry)): return false
	var object: Node2D=game.mine_maps[entry.area].objects[id]
	return game.auto_move.navigation.line_of_sight(game.player.global_position,point(entry),object)

func near_service(id: String) -> bool:
	return services.has(id) and near_point(services[id].area,point(services[id]))

func unlock(area: String) -> void:
	if area not in AREAS or area in state.unlocked: return
	state.unlocked.append(area)
	commit()

func diamond_access() -> bool:
	return "mine_c" in state.unlocked and state.tool==3 and state.resonance_open

func gate_open(id: String) -> bool:
	match id:
		"rail": return state.track_repaired and state.track_switch==1
		"water": return state.water_lowered
		"hardened": return state.hardened
		"resonance": return state.resonance_open
	return false

func ore_state(id: String) -> Dictionary:
	if state.ores.has(id): return state.ores[id]
	return {"hp":int(data.ores[placements[id].ore].hits),"ready_day":0}

func mine(id: String) -> bool:
	if not placements.has(id) or placements[id].kind!="ore" or GameState.modal or not near_id(id): return false
	var entry: Dictionary=placements[id]
	if entry.area not in state.unlocked: return false
	var definition: Dictionary=data.ores[entry.ore]
	var ore: Dictionary=ore_state(id)
	if ore.hp==0: return false
	if int(state.tool)<int(definition.level):
		Events.notice.emit("需要"+{2:"强化镐",3:"星纹镐"}.get(int(definition.level),"普通镐")+"才能采集。")
		return false
	var object: Node2D=game.mine_maps[entry.area].objects[id]
	if not game.auto_move.navigation.line_of_sight(game.player.global_position,object.global_position,object): return false
	var damage: int=(2 if int(state.tool)>int(definition.level) else 1)+Kitchen.mining_power()
	var final_hit: bool=int(ore.hp)<=damage
	var rewards := {}
	var diamonds := 0
	if final_hit:
		if definition.item=="diamond":
			# 保底1，每第四条矿脉多1；不在点击时抽随机数，读档不能重掷。
			diamonds=int(definition.amount)+(1 if (int(state.diamond_counter)+1)%4==0 else 0)
		else: rewards[definition.item]=int(definition.amount)
		if Inventory.preview_exchange({},rewards,0).is_empty() or int(Xiaojing.state.diamonds)+diamonds>999999:
			Events.notice.emit("矿物背包已满，矿脉仍保留，整理后再采。")
			return false
	if not GameState.spend_energy(int(definition.energy)): return false
	ore.hp=maxi(0,int(ore.hp)-damage)
	if final_hit:
		Inventory.exchange({},rewards,0)
		Xiaojing.state.diamonds+=diamonds
		if diamonds>0: Playtest.record("diamonds",{"source":"mine_ore","id":id,"delta":diamonds})
		if diamonds>0: state.diamond_counter+=1
		if entry.ore in ["starlight","diamond"] and id not in state.commission_mines: state.commission_mines.append(id)
		ore.ready_day=GameClock.day+int(definition.regrow) if int(definition.regrow)>0 else 0
		if entry.ore=="copper": ChapterTwo.record("copper_mined")
		if not state.expedition.is_empty() and id not in state.expedition.mined: state.expedition.mined.append(id)
		Events.notice.emit("获得%s ×%d" % [definition.name,diamonds if diamonds>0 else int(definition.amount)])
	state.ores[id]=ore
	if not state.expedition.is_empty(): state.expedition.energy+=int(definition.energy)
	Events.farm_effect.emit(object.global_position,"采矿")
	Events.resource_hit.emit(final_hit)
	Xiaojing.changed.emit()
	commit(final_hit)
	return true

func advance_day() -> void:
	var updated := false
	for id in state.ores:
		var ore: Dictionary=state.ores[id]
		if ore.hp!=0 or ore.ready_day==0 or GameClock.day<int(ore.ready_day): continue
		var entry: Dictionary=placements[id]
		if near_point(entry.area,point(entry),40): continue
		ore.hp=int(data.ores[entry.ore].hits)
		ore.ready_day=0
		updated=true
	if updated: commit(true)
	else: changed.emit()

func repair_track(id: String) -> bool:
	if id not in ["rail_west","rail_east"] or not near_id(id) or state.track_repaired: return false
	if not Inventory.exchange({"wood":6,"stone":4,"copper_ore":2},{},0): return false
	state.track_repaired=true
	commit()
	return true

func operate(id: String) -> bool:
	if not near_id(id): return false
	var entry: Dictionary=placements[id]
	match entry.kind:
		"rail":
			if not state.track_repaired: return false
			# 不能在玩家站在道岔门内时合上碰撞。
			if state.track_switch==1 and GameState.location=="mine_a":
				if Rect2(24*32-12,17*32-12,64+24,96+24).has_point(game.player.global_position):
					Events.notice.emit("先离开道岔，再扳动手柄。")
					return false
			state.track_switch=1-int(state.track_switch)
			if state.track_switch==1: ChapterTwo.record("rail_open")
		"valve":
			if state.water_lowered: Events.notice.emit("水位已稳定，石桥可以通行。"); return false
			if int(entry.symbol)!=int(state.water_step):
				state.water_step=0
				Events.notice.emit("指针回零。先确认上游，再松下游。")
				commit()
				return false
			state.water_step+=1
			if state.water_step==2:
				state.water_step=0
				state.water_lowered=true
				ChapterTwo.record("water_lowered")
		"hardened":
			if state.hardened or not state.water_lowered: return false
			if state.tool<2: Events.notice.emit("强化镐才能清理这段铁锈岩层。回周砚工台升级。") ; return false
			if not GameState.spend_energy(4): return false
			state.hardened=true
			ChapterTwo.record("hardened")
		"resonator":
			if state.resonance_open: return false
			var solution := [1,0,2]
			if int(entry.symbol)!=int(solution[int(state.resonance_step)]):
				state.resonance_step=0
				Events.notice.emit("回声散开了。按麦穗、河沙、白石的颜色重新来。")
				commit()
				return false
			state.resonance_step+=1
			if state.resonance_step==3:
				state.resonance_step=0
				state.resonance_open=true
				ChapterTwo.record("resonance_open")
		_: return false
	commit(true)
	return true

func claim_chest(id: String) -> bool:
	if not near_id(id) or placements[id].kind!="chest" or id in state.chests: return false
	var entry: Dictionary=placements[id]
	if int(Xiaojing.state.diamonds)+int(entry.diamonds)>999999: return false
	if not Inventory.exchange({},entry.items,0):
		Events.notice.emit("背包已满，箱子没有消失。")
		return false
	state.chests.append(id)
	Xiaojing.state.diamonds+=int(entry.diamonds)
	if entry.diamonds>0: Playtest.record("diamonds",{"source":"mine_chest","id":id,"delta":int(entry.diamonds)})
	Xiaojing.changed.emit()
	commit()
	return true

func build_furnace() -> bool:
	if state.furnace or not near_service("forge") or "repair" not in ChapterTwo.completed: return false
	if not Inventory.exchange(data.furnace.required,{},-int(data.furnace.coins)): return false
	state.furnace=true
	commit()
	return true

func upgrade_tool() -> bool:
	if state.tool>=3 or not near_service("forge") or not state.furnace: return false
	var upgrade: Dictionary=data.upgrades[str(int(state.tool)+1)]
	if not Inventory.exchange(upgrade.required,{},-int(upgrade.coins)): return false
	state.tool+=1
	commit(true)
	return true

func enqueue(recipe_id: String, batches: int = 1) -> bool:
	if not near_service("forge") or not state.furnace or not data.recipes.has(recipe_id) or batches<1 or batches>5 or state.queue.size()>=4: return false
	var recipe: Dictionary=data.recipes[recipe_id]
	if int(state.tool)<int(recipe.level) or (int(recipe.diamonds)>0 and not diamond_access()): return false
	var required := {}
	for id in recipe.required: required[id]=int(recipe.required[id])*batches
	if not Inventory.exchange(required,{},0): return false
	state.job_serial+=1
	state.queue.append({"id":int(state.job_serial),"recipe":recipe_id,"batches":batches,"ready_day":GameClock.day+int(recipe.days)})
	StarTrials.on_enqueue(state.queue.back(),required)
	LegendTrials.enqueue(state.queue.back(),required)
	River.enqueue(state.queue.back())
	commit()
	return true

func claim_job(job_id: int) -> bool:
	if not near_service("forge"): return false
	for i in range(state.queue.size()):
		var job: Dictionary=state.queue[i]
		if int(job.id)!=job_id or GameClock.day<int(job.ready_day): continue
		var recipe: Dictionary=data.recipes[job.recipe]
		var output := {}
		for id in recipe.output: output[id]=int(recipe.output[id])*int(job.batches)
		var diamonds: int=int(recipe.diamonds)*int(job.batches)
		if Xiaojing.state.diamonds+diamonds>999999 or not Inventory.exchange({},output,0): return false
		StarTrials.on_claim(job)
		LegendTrials.claim(job)
		River.claim(job)
		state.queue.remove_at(i)
		Xiaojing.state.diamonds+=diamonds
		if diamonds>0: Playtest.record("diamonds",{"source":"processing","id":job.recipe,"delta":diamonds})
		Xiaojing.changed.emit()
		commit()
		return true
	return false

func new_survey() -> bool:
	if not near_service("entrance") or not diamond_access(): return false
	for id in placements:
		if placements[id].get("ore","") in ["starlight","diamond"] and ore_state(id).hp>0:
			Events.notice.emit("这一轮高级矿脉还没采完。先完成探索，补给不会提前消耗。")
			return false
	if not Inventory.exchange(data.survey.required,{},0): return false
	state.survey+=1
	# 勘探消耗换取新的高级矿脉，不刷新宝箱、剧情、机关或基础矿物。
	for id in placements:
		if placements[id].get("ore","") in ["starlight","diamond"]: state.ores.erase(id)
	commit(true)
	return true

func complete_commission() -> bool:
	if not diamond_access() or not (near_service("forge") or Xiaojing.nearby()): return false
	var definition: Dictionary=data.commission
	if state.commission_mines.size()<3 or (Xiaojing.state.order_day>0 and GameClock.day-int(Xiaojing.state.order_day)<int(definition.period)):
		Events.notice.emit("考察委托需本轮新采三处高级矿脉，且距上次至少三日。")
		return false
	if Xiaojing.state.diamonds+int(definition.diamonds)>999999 or not Inventory.exchange(definition.required,{},0): return false
	state.commission_mines=[]
	Xiaojing.state.order_day=GameClock.day
	Xiaojing.state.diamonds+=int(definition.diamonds)
	Playtest.record("diamonds",{"source":"commission","delta":int(definition.diamonds)})
	Xiaojing.changed.emit()
	commit()
	return true

func start_expedition() -> bool:
	if not near_service("entrance") or "mine_b" not in state.unlocked or Xiaojing.state.trial.get("id","")!="cave" or not state.expedition.is_empty(): return false
	if not Inventory.exchange({"wheat":2},{},0): return false
	Playtest.record("trial_start",{"id":"basic:cave_expedition"})
	state.expedition={"day":GameClock.day,"visited":[],"mined":[],"energy":0,"areas":[]}
	commit()
	return true

func finish_expedition() -> bool:
	if state.expedition.is_empty(): return false
	var e: Dictionary=state.expedition
	var success: bool=GameClock.day==int(e.day) and e.visited.size()>=20 and e.mined.size()>=4 and "mine_b" in e.areas and GameState.stamina>=20 and int(e.energy)<=90 and StarTrials.complete("cave")
	state.expedition={}
	if success: Xiaojing.pass_trial("cave")
	else:
		Playtest.record("trial_fail",{"id":"basic:cave_expedition","reason":"route_or_energy"})
		Events.notice.emit("考察记录已收好。试炼需同日探索20格、采四处矿、到地下水脉并保留20体力；可重新出发。")
	commit()
	return success

func _process(delta: float) -> void:
	if GameState.modal or GameState.location not in AREAS or not is_instance_valid(game): return
	walk_timer+=delta
	if walk_timer<0.15: return
	walk_timer=0
	if not state.expedition.is_empty():
		var cell: Vector2i=Vector2i((game.player.global_position/32).floor())
		var id := "%s:%d,%d" % [GameState.location,cell.x,cell.y]
		StarTrials.walk(GameState.location,cell)
		if id not in state.expedition.visited: state.expedition.visited.append(id)
		if GameState.location not in state.expedition.areas: state.expedition.areas.append(GameState.location)

func memory_at(id: String) -> bool:
	if not placements.has(id) or placements[id].kind!="memory" or not near_id(id) or not Xiaojing.state.unlocked: return false
	var memory: String=placements[id].memory
	if memory not in Xiaojing.state.memories: Xiaojing.state.memories.append(memory)
	if memory not in state.linked_memories: state.linked_memories.append(memory)
	if Xiaojing.state.affection>=20 and id not in state.exploration_events:
		state.exploration_events.append(id)
		Xiaojing.boost(1,1,1,"mine_memory:"+id)
	Xiaojing.commit()
	commit()
	return true

func at_star_lamp(index: int) -> bool:
	return near_id("star_"+str(index)) and GameState.location=="mine_c"

func commit(navigation: bool = false) -> void:
	changed.emit()
	if navigation: Events.navigation_changed.emit()
	Events.progress_committed.emit()

func snapshot() -> Dictionary:
	return state.duplicate(true)

func migrate(old_xiaojing: Dictionary) -> Dictionary:
	var result := defaults()
	result.legacy_board_claimable=not old_xiaojing.get("cave",{}).is_empty()
	result.legacy_trials=old_xiaojing.get("trials",[]).duplicate()
	return result

func restore(saved: Dictionary) -> void:
	state=saved.duplicate(true)
	changed.emit()
	Events.navigation_changed.emit()

func validate(saved: Variant, day: int) -> bool:
	return MiningSaveSchema.validate(saved,day)
