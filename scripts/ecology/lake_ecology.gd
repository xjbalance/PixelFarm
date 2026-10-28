extends Node
## 全湖生态与原鱼栏分开；所有下降都可通过管理密度、清淤与修复恢复。
signal changed
const SHORE := Vector2(912,688)
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false
func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/ecology/config.json")))
	state=defaults(GameClock.day);GameClock.day_advanced.connect(settle_day)
func defaults(day: int = GameClock.day) -> Dictionary:
	return {"health":70,"restored":false,"plants":0,"cycle":false,"debris":0,"clean_day":0,"plant_day":0,"last_settled_day":day,"meteor_seen":false,"xiaojing_seen":false}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit()
func shore_point() -> Vector2: return FarmLayout.point("ecology")
func near() -> bool:
	return FarmLayout.active("ecology") and is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(shore_point())<=54
func commit() -> void:
	changed.emit();Events.progress_committed.emit();busy=false
func clean() -> bool:
	if busy or GameClock.settling or not near() or state.clean_day>=GameClock.day or (state.health==100 and state.debris==0): return false
	busy=true
	if not GameState.spend_energy(int(data.clean_energy)): busy=false;return false
	state.clean_day=GameClock.day;state.debris=maxi(0,int(state.debris)-1);state.health=mini(100,int(state.health)+int(data.clean_health));commit();return true
func plant() -> bool:
	if busy or GameClock.settling or not near() or state.plant_day>=GameClock.day or state.plants>=data.max_plants or GameState.stamina<Kitchen.energy_cost(int(data.plant_energy)): return false
	busy=true
	if not Inventory.exchange(data.plants_required,{},0): busy=false;return false
	GameState.spend_energy(int(data.plant_energy));state.plant_day=GameClock.day;state.plants+=1;state.health=mini(100,int(state.health)+int(data.plant_health));commit();return true
func repair_cycle() -> bool:
	if busy or GameClock.settling or not near() or state.cycle or state.plants<int(data.restoration_plants): return false
	busy=true
	if not Inventory.exchange(data.cycle_required,{},-int(data.cycle_coins)): busy=false;return false
	state.cycle=true;state.health=mini(100,int(state.health)+6);commit();return true
func complete_restoration() -> bool:
	if busy or GameClock.settling or not near() or state.restored or not state.cycle or state.plants<data.restoration_plants or state.health<data.restoration_health or state.debris>0: return false
	busy=true
	if not Inventory.exchange({},data.reward_items,int(data.reward_coins)): busy=false;return false
	state.restored=true;commit();Events.notice.emit("阿禾把湖水记录贴进留言册：新的水草留住了泥沙，旧循环口又通了。湖泊恢复记录与奖励已保存。")
	return true
func observe_meteor() -> bool:
	if busy or not near() or not GameWeather.is_meteor_night() or state.meteor_seen: return false
	busy=true;state.meteor_seen=true;commit();Events.notice.emit("湖面映出一道指向东岸石阶的星痕。你把方向抄在水样册里，遗迹调查多了一条实际观测。")
	return true
func xiaojing_after() -> bool:
	if busy or not near() or not state.restored or state.xiaojing_seen or Aquaculture.state.xiaojing.stage<2 or not Xiaojing.state.unlocked or not companion_present(): return false
	busy=true;state.xiaojing_seen=true;Xiaojing.boost(0,1,1,"lake_restored");commit()
	Events.notice.emit("小京把新旧水样并排放下：不是湖水记得谁，是有人愿意把这里照料好。小京在温室笔记里画下一尾长尾星鲤；信任与羁绊各+1，只记录一次。")
	return true
func companion_present() -> bool:
	if GameClock.minutes<540 or GameClock.minutes>=1080: return false
	for person in get_tree().get_nodes_in_group("xiaojing"):
		if person.is_visible_in_tree() and person.global_position.distance_to(shore_point())<=80: return true
	return false
func fishing_capacity() -> int: return 8 if state.health<40 else 12
func rare_factor() -> float: return clampf(1.0+(float(state.health)-70)/60.0,.5,1.5)
func facility_added() -> void:
	var count := 0
	for p in Aquaculture.state.pens.values():
		if p.built: count+=1
	if count>2: state.health=maxi(0,int(state.health)-3);changed.emit()
func settle_day() -> void:
	if busy or GameClock.day<=state.last_settled_day: return
	busy=true
	var crowd := 0;var pollution := 0
	for id in Aquaculture.SITES:
		var p: Dictionary=Aquaculture.pen(id);var s: Dictionary=Aquaculture.summary(id)
		if not p.built or s.total==0: continue
		if float(s.total)/int(s.capacity)>.8: crowd+=1
		if p.water<40: pollution+=1
	var loss: int=mini(6,crowd*2)+mini(2,pollution)
	var improvement: int=(1 if state.plants>=3 else 0)+(2 if state.cycle else 0)
	if GameWeather.weather_id(GameClock.day-1)=="storm": state.debris=mini(3,int(state.debris)+1)
	loss+=int(state.debris)
	state.health=clampi(int(state.health)+improvement-loss,0,100)
	state.last_settled_day=GameClock.day;commit()
func validate(raw: Variant, day: int) -> bool:
	if not raw is Dictionary or raw.size()!=defaults().size(): return false
	for key in ["restored","cycle","meteor_seen","xiaojing_seen"]:
		if not raw.get(key) is bool: return false
	for key in ["clean_day","plant_day"]:
		if not FarmSaveSchema.whole(raw.get(key),0,day): return false
	if not FarmSaveSchema.whole(raw.get("health"),0,100) or not FarmSaveSchema.whole(raw.get("plants"),0,6) or not FarmSaveSchema.whole(raw.get("debris"),0,3) or not FarmSaveSchema.whole(raw.get("last_settled_day"),1,day): return false
	if raw.cycle and raw.plants<3: return false
	if raw.restored and not raw.cycle: return false
	return not raw.xiaojing_seen or raw.restored
