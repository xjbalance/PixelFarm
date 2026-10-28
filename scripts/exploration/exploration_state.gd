extends Node
## 三处可行走遗址的唯一状态；机关只提交状态，碰撞/导航由地图订阅更新。
signal changed
const AREAS := ["mist_forest","lake_ruins","old_temple"]
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false
func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/exploration/exploration.json")))
	state=defaults()
func defaults(_day: int = GameClock.day) -> Dictionary:
	return {"unlocked":["mist_forest"],"facts":[],"forest":{"step":0,"open":false},"lake":{"water":2,"flow":0,"open":false},"temple":{"mirror":0,"step":0,"open":false},"chests":[],"gathered":{},"samples":[],"crafted":[],"collection_reward":false}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit();Events.navigation_changed.emit()
func unlocked(area: String) -> bool: return area in state.unlocked
func entry(area: String) -> Vector2:
	if area not in AREAS: return Vector2.INF
	var at: Array=data.areas[area].entry
	return Vector2(at[0]*32+16,at[1]*32+16)
func point(id: String) -> Vector2:
	var definition: Dictionary=data.points.get(id,data.entrances.get(id,{}))
	if definition.is_empty(): return Vector2.INF
	if definition.has("position"):
		return FarmLayout.point("explore:"+id) if definition.get("area")=="farm" else Vector2(definition.position[0],definition.position[1])
	return Vector2(definition.cell[0]*32+16,definition.cell[1]*32+16)
func definition(id: String) -> Dictionary: return data.points.get(id,data.entrances.get(id,{}))
func near_id(id: String) -> bool:
	var record := definition(id)
	if record.is_empty() or (record.get("area")=="farm" and not FarmLayout.active("explore:"+id)) or not is_instance_valid(game) or GameState.location!=record.area or game.player.global_position.distance_to(point(id))>54 or not game.auto_move: return false
	for object in get_tree().get_nodes_in_group("interactables"):
		if "exploration_id" in object and object.exploration_id==id and object.is_visible_in_tree():
			return game.auto_move.navigation.line_of_sight(game.player.global_position,point(id),object)
	return false
func condition(id: String) -> bool:
	match id:
		"": return true
		"forest": return state.forest.open
		"lower_room": return state.lake.water<=1
		"lake_bridge": return state.lake.open
		"mirror": return state.temple.mirror==2
		"temple": return state.temple.open
	return false
func accessible(id: String) -> bool:
	return data.points.has(id) and condition(str(data.points[id].get("required","")))
func _commit(navigation: bool = false) -> void:
	changed.emit()
	if navigation: Events.navigation_changed.emit()
	Events.progress_committed.emit();busy=false
func inspect_entrance(area: String) -> bool:
	if busy or GameClock.settling or area not in AREAS or not near_id(data.areas[area].entrance): return false
	if unlocked(area): return false
	if area=="lake_ruins":
		if not LakeEcology.state.restored or "forest_archive" not in state.facts:
			Events.notice.emit("先恢复湖泊循环，再带森林排水副页来核对刻度。")
			return false
	elif area=="old_temple":
		if Story.stage<5 or MineState.state.tool<3 or "mine_c" not in MineState.state.unlocked or "forest_archive" not in state.facts or "lake_archive" not in state.facts:
			Events.notice.emit("需要森林与湖务档案，并掌握晶石洞窟、星纹镐的工艺。神庙不以小京关系为前置。")
			return false
	else: return false
	busy=true
	if area=="lake_ruins" and "drain_plate" not in state.facts: state.facts.append("drain_plate")
	state.unlocked.append(area);_commit()
	Events.notice.emit("刻线与档案吻合，安全检修通道已开放。")
	return true
func enter(area: String) -> bool:
	if busy or GameClock.settling or area not in AREAS or not near_id(data.areas[area].entrance) or not unlocked(area): return false
	return WorldTravel.change(game,area)
func exit_area() -> bool:
	var area: String=GameState.location
	if busy or area not in AREAS or not near_id(data.areas[area].exit): return false
	var at: Array=data.areas[area].return_position
	var destination: String=data.areas[area].return_area
	var point:=Vector2(at[0],at[1])
	if destination=="farm": point=FarmLayout.transform_point(point,"explore:"+str(data.areas[area].entrance))
	return WorldTravel.change(game,destination,point)
func read(id: String) -> bool:
	if busy or GameClock.settling or not near_id(id) or not accessible(id) or data.points[id].kind!="note" or id in state.facts: return false
	busy=true;state.facts.append(id);_commit();return true
func operate(id: String) -> bool:
	if busy or GameClock.settling or not near_id(id) or not accessible(id): return false
	var record: Dictionary=data.points[id]
	busy=true
	var correct := true
	match record.kind:
		"forest_rune":
			if state.forest.open or "forest_order" not in state.facts: busy=false;Events.notice.emit("先在入口北侧读四季刻痕。已打开的林径不会重复关闭。") ;return false
			correct=int(record.symbol)==int(state.forest.step)
			state.forest.step=int(state.forest.step)+1 if correct else 0
			if state.forest.step==4: state.forest.open=true
		"valve_north":
			if state.lake.open or state.lake.water!=2 or "lake_hint" not in state.facts: busy=false;return false
			state.lake.water=1;state.lake.flow=0
			if "lake_lower_opened" not in state.facts: state.facts.append("lake_lower_opened")
		"flow":
			if state.lake.open or state.lake.water!=1 or "lake_hint" not in state.facts: busy=false;return false
			state.lake.flow=1-int(state.lake.flow)
		"valve_south":
			if state.lake.open or state.lake.water!=1 or state.lake.flow!=1 or "lake_hint" not in state.facts: busy=false;Events.notice.emit("南闸仍顶着水，先按规程把中央水流转进旁渠。") ;return false
			state.lake.water=0;state.lake.open=true
		"mirror":
			if state.temple.open or "temple_hint" not in state.facts: busy=false;return false
			state.temple.mirror=(int(state.temple.mirror)+1)%3;state.temple.step=0
		"temple_rune":
			if state.temple.open or "temple_hint" not in state.facts or state.temple.mirror!=2: busy=false;Events.notice.emit("先让镜面朝西，光才会经过麦穗的定位线。") ;return false
			correct=int(record.symbol)==int(state.temple.step)
			state.temple.step=int(state.temple.step)+1 if correct else 0
			if state.temple.step==3: state.temple.open=true
		_: busy=false;return false
	_commit(true)
	Events.notice.emit("机关回应了刻线，实际通路已更新。" if correct else "次序没有接上，本轮刻线已熄灭。提示还在原处，可以重新尝试。")
	return correct
func reset_puzzle(area: String) -> bool:
	var hint: String={"mist_forest":"forest_order","lake_ruins":"lake_hint","old_temple":"temple_hint"}.get(area,"")
	if busy or GameClock.settling or hint=="" or not near_id(hint): return false
	if (area=="mist_forest" and state.forest.open) or (area=="lake_ruins" and state.lake.open) or (area=="old_temple" and state.temple.open): return false
	busy=true
	if area=="mist_forest": state.forest.step=0
	elif area=="lake_ruins": state.lake={"water":2,"flow":0,"open":false}
	else: state.temple={"mirror":0,"step":0,"open":false}
	_commit(true);return true
func claim_chest(id: String) -> bool:
	if busy or GameClock.settling or not near_id(id) or not accessible(id) or data.points[id].kind!="chest" or id in state.chests: return false
	busy=true
	if not Inventory.exchange({},data.points[id].reward,0): busy=false;Events.notice.emit("背包不足，箱内物品已完整保留。") ;return false
	state.chests.append(id);_commit();return true
func gather(id: String) -> bool:
	if busy or GameClock.settling or not near_id(id) or not accessible(id) or data.points[id].kind!="plant": return false
	var record: Dictionary=data.points[id]
	var previous: int=int(state.gathered.get(id,0))
	if previous>0 and GameClock.day-previous<int(record.interval): Events.notice.emit("采样架仍在恢复。请按记录间隔再来，不会因重进地图而刷新。") ;return false
	if GameState.stamina<Kitchen.energy_cost(2): return false
	var amount: int=int(record.count)
	if id=="forest_herbs" and Calendar.season()==3: amount=1
	busy=true
	if not Inventory.exchange({},{record.item:amount},0): busy=false;return false
	GameState.spend_energy(2);state.gathered[id]=GameClock.day
	if id=="forest_herbs" and Calendar.season() not in state.samples: state.samples.append(Calendar.season())
	_commit();return true
func craft(id: String) -> bool:
	if busy or GameClock.settling or not near_id("temple_archive") or "temple_archive" not in state.facts or not data.recipes.has(id) or id in state.crafted: return false
	busy=true
	var recipe: Dictionary=data.recipes[id]
	if not Inventory.exchange(recipe.required,recipe.reward,0): busy=false;return false
	state.crafted.append(id);_commit();return true
func claim_collection() -> bool:
	if busy or GameClock.settling or not near_id("temple_archive") or state.collection_reward or state.samples.size()!=4 or state.crafted.size()!=3: return false
	if "temple_archive" not in state.facts: return false
	busy=true
	if not Inventory.exchange({},{"ancient_token":2},0): busy=false;return false
	state.collection_reward=true;_commit();return true
func validate(raw: Variant, day: int) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults(day).keys()) or not FarmSaveSchema.whole(day,1,999999): return false
	if not AquacultureSaveSchema.unique(raw.unlocked,AREAS) or "mist_forest" not in raw.unlocked: return false
	var facts: Array=["drain_plate","lake_lower_opened","moon_reflection"];var chests: Array=[];var plants: Array=[]
	for id in data.points:
		if data.points[id].kind=="note": facts.append(id)
		elif data.points[id].kind=="chest": chests.append(id)
		elif data.points[id].kind=="plant": plants.append(id)
	if not AquacultureSaveSchema.unique(raw.facts,facts) or not AquacultureSaveSchema.unique(raw.chests,chests) or not AquacultureSaveSchema.unique(raw.samples,[0,1,2,3]) or not AquacultureSaveSchema.unique(raw.crafted,data.recipes.keys()): return false
	if not AquacultureSaveSchema.exact(raw.forest,["step","open"]) or not FarmSaveSchema.whole(raw.forest.step,0,4) or not raw.forest.open is bool or raw.forest.open!=(raw.forest.step==4): return false
	if raw.forest.step>0 and "forest_order" not in raw.facts: return false
	if not AquacultureSaveSchema.exact(raw.lake,["water","flow","open"]) or not FarmSaveSchema.whole(raw.lake.water,0,2) or not FarmSaveSchema.whole(raw.lake.flow,0,1) or not raw.lake.open is bool: return false
	if raw.lake.open!=(raw.lake.water==0) or (raw.lake.open and raw.lake.flow!=1) or (raw.lake.flow==1 and raw.lake.water==2): return false
	if raw.lake.water<2 and "lake_hint" not in raw.facts: return false
	if not AquacultureSaveSchema.exact(raw.temple,["mirror","step","open"]) or not FarmSaveSchema.whole(raw.temple.mirror,0,2) or not FarmSaveSchema.whole(raw.temple.step,0,3) or not raw.temple.open is bool or raw.temple.open!=(raw.temple.step==3): return false
	if raw.temple.step>0 and (raw.temple.mirror!=2 or "temple_hint" not in raw.facts): return false
	if raw.temple.mirror>0 and "temple_hint" not in raw.facts: return false
	if "forest_archive" in raw.facts and not raw.forest.open: return false
	if "lake_archive" in raw.facts and not raw.lake.open: return false
	if "temple_archive" in raw.facts and not raw.temple.open: return false
	if "lake_ruins" in raw.unlocked and ("forest_archive" not in raw.facts or "drain_plate" not in raw.facts): return false
	if "old_temple" in raw.unlocked and ("forest_archive" not in raw.facts or "lake_archive" not in raw.facts or "lake_ruins" not in raw.unlocked): return false
	if (raw.lake.water<2 or "lake_hint" in raw.facts) and "lake_ruins" not in raw.unlocked: return false
	if (raw.temple.mirror>0 or "temple_hint" in raw.facts) and "old_temple" not in raw.unlocked: return false
	if not raw.gathered is Dictionary or raw.gathered.size()>plants.size(): return false
	for id in raw.gathered:
		if id not in plants or not FarmSaveSchema.whole(raw.gathered[id],1,day): return false
	if raw.samples.size()>0 and not raw.gathered.has("forest_herbs"): return false
	if raw.gathered.has("forest_reeds") and not raw.forest.open: return false
	if (raw.gathered.has("temple_weave") or raw.gathered.has("temple_token")) and not raw.temple.open: return false
	if "drain_plate" in raw.facts and "lake_ruins" not in raw.unlocked: return false
	if not raw.crafted.is_empty() and "temple_archive" not in raw.facts: return false
	if not raw.collection_reward is bool or (raw.collection_reward and (raw.samples.size()!=4 or raw.crafted.size()!=3)): return false
	for id in raw.chests:
		var gate: String=data.points[id].get("required","")
		if gate=="forest" and not raw.forest.open: return false
		if gate=="lower_room" and "lake_lower_opened" not in raw.facts: return false
		if gate=="lake_bridge" and not raw.lake.open: return false
		if gate=="temple" and not raw.temple.open: return false
	return true

func observe_moon() -> bool:
	if busy or GameClock.settling or not LakeEcology.near() or not GameWeather.is_moon_night() or "moon_reflection" in state.facts: return false
	busy=true
	if not Inventory.exchange({},{"moon_note":1},0): busy=false;return false
	state.facts.append("moon_reflection");_commit()
	Events.notice.emit("月影已记下 · 获得湖面月影笺×1（唯一收藏）。")
	return true
