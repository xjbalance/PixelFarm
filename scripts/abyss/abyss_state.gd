extends Node
## 独立深渊进度；只加载当前楼层，所有采矿/机关/箱子均有稳定ID。
signal changed
signal air_changed
var data: Array=[]
var config: Dictionary={}
var state: Dictionary={}
var game: Node
var tick: float=0
var seen_cache: Dictionary={}
func defaults() -> Dictionary:
	return {"unlocked":false,"depth":1,"max_clear":0,"checkpoint":1,"gear":1,"air":160,"rations":0,"rescues":0,"survey":0,"gates":[],"steps":{},"notes":[],"chests":[],"ores":{},"seen":[],"hazards":[],"camp_day":0,"run":0,"survey_day":0,"extra":{},"shortcuts":[],"bosses":[],"warnings":{},"diamond_counter":0,"safety":[],"ore_days":{}}
func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/abyss/floors.json")))
	config=JSON.parse_string(FileAccess.get_file_as_string("res://resources/abyss/legend.json"))
	state=defaults()
	GameClock.day_advanced.connect(advance_day)
func layout(depth: int = -1) -> Dictionary:
	return data[int(state.depth if depth<0 else depth)-1]
func can_unlock() -> bool:
	return "discussion" in ChapterTwo.completed and MineState.diamond_access()
func unlock() -> bool:
	if state.unlocked or not can_unlock() or not near("entrance"): return false
	state.unlocked=true
	commit()
	return true
func point(cell: Array) -> Vector2:
	return Vector2(cell[0]*32+16,cell[1]*32+16)
func near(id: String) -> bool:
	if not is_instance_valid(game): return false
	if id=="entrance": return GameState.location=="mine_c" and game.player.global_position.distance_to(Vector2(208,688))<=64
	if GameState.location!="abyss" or not game.mine_maps.abyss.objects.has(id): return false
	var node: Node2D=game.mine_maps.abyss.objects[id]
	return game.player.global_position.distance_to(node.global_position)<=60 and game.auto_move.navigation.line_of_sight(game.player.global_position,node.global_position,node)
func enter(depth: int = -1) -> bool:
	if not state.unlocked or not near("entrance"): return false
	var target: int=int(state.checkpoint) if depth<0 else depth
	if target not in checkpoints() or target>maxi(1,int(state.max_clear)) or target>config.implemented: return false
	state.depth=target
	state.air=160
	state.rations=0
	state.run+=1
	Playtest.record("mine_enter",{"source":"abyss","depth":target,"value":state.run})
	game.mine_maps.abyss.rebuild()
	game.change_location("abyss",point(layout().entry))
	commit()
	return true
func descend() -> bool:
	if not near("down") or int(state.depth) not in state.gates: return false
	var depth: int=state.depth
	if depth==100 and not River.has("star_core"): return false
	var newly: bool=int(state.max_clear)<depth
	state.max_clear=maxi(int(state.max_clear),depth)
	if newly: Playtest.record("task",{"id":"abyss:"+str(depth),"depth":depth})
	if depth%10==0: state.checkpoint=depth
	AbyssRules.clear_depth(depth)
	LegendState.visit_depth(depth)
	if depth==int(config.implemented):
		if newly: commit()
		Events.notice.emit("星河归航台已接通。百层档案保留了每一班人的名字，升降机仍为回程留着。")
		return newly
	if int(state.gear)<int(layout(depth+1).gear):
		commit()
		Events.notice.emit("深处需要升级勘探护具。检查点已保存，返回周砚工台升级后继续。")
		return false
	state.depth=depth+1
	game.mine_maps.abyss.rebuild()
	game.change_location("abyss",point(layout().entry))
	commit()
	return true
func leave() -> bool:
	if not near("up"): return false
	Playtest.record("mine_exit",{"source":"abyss","depth":state.depth})
	game.change_location("mine_c",Vector2(240,688))
	commit()
	return true
func read_note() -> bool:
	if not near("note"): return false
	var d: int=state.depth
	if d not in state.notes: state.notes.append(d)
	LegendState.observe_evidence(d)
	River.observe_depth(d)
	commit()
	return true
func operate(symbol: int) -> bool:
	if symbol<0 or symbol>=layout().controls.size() or not near("lever_"+str(symbol)) or int(state.depth) in state.gates: return false
	var d: int=state.depth
	if d not in state.notes or (d==20 and 10 not in state.notes):
		Events.notice.emit("先读本层刻痕；最终水闸还需要第10层水位账。没有凭空尝试机关。")
		return false
	if not AbyssRules.ready():
		Events.notice.emit("本轮辅助台或前一区域档案尚未核对。先按现场刻痕操作。")
		return false
	var solution: Array=layout().solution
	var step: int=state.steps.get(str(d),0)
	if symbol!=int(solution[step]):
		state.steps[str(d)]=0
		Events.notice.emit("回路不连贯，机关安全复位。重新对照风、水、灯与人的先后。")
		commit()
		return false
	step+=1
	if step==solution.size():
		state.steps.erase(str(d))
		if AbyssRules.finish_round():
			state.gates.append(d)
			Events.navigation_changed.emit()
	else: state.steps[str(d)]=step
	commit()
	return true
func mine(index: int) -> bool:
	if not near("ore_"+str(index)) or index not in [0,1] or int(MineState.state.tool)<3: return false
	var id := "%d:%d" % [state.depth,index]
	var hp: int=state.ores.get(id,3)
	if hp==0: return false
	var damage: int=1+Kitchen.mining_power()
	var final_hit: bool=hp<=damage
	var deep: bool=state.depth>=16
	var item: String=layout().ore_items[index]
	var diamonds: int=(1+(1 if (int(state.diamond_counter)+1)%4==0 else 0)) if item=="diamond" and final_hit else 0
	var reward: Dictionary={item:2} if final_hit and item!="diamond" else {}
	if Xiaojing.state.diamonds+diamonds>999999: return false
	if Inventory.preview_exchange({},reward,0).is_empty() or GameState.stamina<Kitchen.energy_cost(3) or state.air<2: return false
	if not GameState.spend_energy(3): return false
	Inventory.exchange({},reward,0)
	if diamonds>0:
		Xiaojing.state.diamonds+=diamonds
		Playtest.record("diamonds",{"source":"abyss_ore","depth":state.depth,"delta":diamonds})
		state.diamond_counter+=1
		Xiaojing.changed.emit()
	state.air-=2
	state.ores[id]=maxi(0,hp-damage)
	if final_hit and state.depth>20: state.ore_days[id]=GameClock.day+3
	Events.resource_hit.emit(final_hit)
	commit()
	if final_hit: Events.navigation_changed.emit()
	return true
func chest() -> bool:
	var d: int=state.depth
	if not near("chest") or d in state.chests: return false
	var diamonds: int=2 if d%4==0 else 0
	if Xiaojing.state.diamonds+diamonds>999999 or not Inventory.exchange({},{"crystal":2},0): return false
	state.chests.append(d)
	Xiaojing.state.diamonds+=diamonds
	if diamonds>0: Playtest.record("diamonds",{"source":"abyss_chest","depth":state.depth,"delta":diamonds})
	Xiaojing.changed.emit()
	commit()
	return true
func ration() -> bool:
	if GameState.location!="abyss" or state.rations>=3 or state.air>=160 or not Inventory.exchange({"wheat":3,"potato":1},{},0): return false
	state.rations+=1
	state.air=mini(160,int(state.air)+36)
	commit()
	return true
func camp() -> bool:
	if not near("up") or int(state.depth) not in checkpoints() or state.camp_day==GameClock.day: return false
	if not Inventory.exchange({"wheat":2,"wood":2},{},0): return false
	state.air=160
	state.camp_day=GameClock.day
	GameState.stamina=mini(GameState.max_stamina(),int(GameState.stamina)+40)
	GameState.changed.emit()
	commit()
	return true
func upgrade() -> bool:
	if not MineState.near_service("forge") or state.gear>=7: return false
	var recipe: Dictionary=config.gear[str(int(state.gear)+1)]
	if state.max_clear<int(recipe.depth) or not Inventory.exchange(recipe.required,{},-int(recipe.coins)): return false
	state.gear+=1
	commit()
	return true
func survey() -> bool:
	if not near("entrance") or state.max_clear<20: return false
	if state.survey_day>0 and GameClock.day-int(state.survey_day)<3: return false
	for depth in range(16,21):
		for index in range(2):
			if int(state.ores.get("%d:%d" % [depth,index],3))>0: return false
	if not Inventory.exchange({"wheat":6,"wood":6,"iron_bar":2},{},0): return false
	state.survey+=1
	state.survey_day=GameClock.day
	for depth in range(16,21):
		for index in range(2): state.ores.erase("%d:%d" % [depth,index])
	# 只刷新实际采尽的高级节点；故事、箱子和已取得的记忆永不重置。
	state.seen=[]
	seen_cache.clear()
	state.hazards=[]
	commit()
	return true
func rescue(reason: String = "air") -> void:
	if GameState.location!="abyss": return
	state.rescues+=1
	Playtest.record("rescue",{"source":"abyss","depth":state.depth,"reason":reason})
	Playtest.record("mine_exit",{"source":"abyss","depth":state.depth,"reason":reason})
	state.air=160
	game.change_location("mine_c",Vector2(240,688))
	Events.notice.emit("安全绳把你带回升降机。已完成层和检查点保留，可补给后重试。")
	commit()
func _process(delta: float) -> void:
	if GameState.location!="abyss" or GameState.modal or not is_instance_valid(game): return
	tick+=delta
	if tick<.15: return
	tick=0
	var cell: Vector2i=Vector2i((game.player.global_position/32).floor())
	var id := "%d:%d,%d" % [state.depth,cell.x,cell.y]
	if not seen_cache.has(id):
		seen_cache[id]=true
		state.seen.append(id)
		if state.seen.size()%maxi(4,3+int(state.gear))==0:
			state.air=maxi(0,int(state.air)-1)
			air_changed.emit()

	AbyssRules.hazard_at(cell)
	if state.air==0: rescue()
func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(saved: Dictionary) -> void:
	state=saved.duplicate(true)
	seen_cache.clear()
	for id in state.seen: seen_cache[id]=true
	if is_instance_valid(game): game.mine_maps.abyss.rebuild()
	changed.emit()

func checkpoints() -> Array:
	var result: Array=[1]
	for depth in range(10,101,10): result.append(depth)
	# v9已经取得的5/15层检查点保留入口，不再生成新的五层检查点。
	for depth in River.state.old_checkpoints:
		if depth not in result: result.append(depth)
	result.sort()
	return result

func advance_day() -> void:
	var renewed := false
	for id in state.ore_days.keys():
		if GameClock.day<int(state.ore_days[id]) or int(state.ores.get(id,3))!=0: continue
		var parts: PackedStringArray=str(id).split(":")
		if GameState.location=="abyss" and int(state.depth)==int(parts[0]) and near("ore_"+parts[1]): continue
		state.ores[id]=3
		state.ore_days.erase(id)
		renewed=true
	if renewed:
		commit()
		Events.navigation_changed.emit()
