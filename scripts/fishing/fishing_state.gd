extends Node
## 抛竿先提交成本与尝试序号，只有实际小游戏获胜才有鱼。进行中的小游戏不在读档时重放。
signal changed
const STEP: float = 1.0/120.0
const MAX_TOTAL: int = 11999988
var data: Dictionary = {}
var sites: Dictionary = {}
var state: Dictionary = {}
var session: Dictionary = {}
var game: Node
var busy: bool = false
var accumulator: float = 0

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/fishing/fishing.json")))
	sites=data.sites.duplicate(true)
	state=defaults()
	session=empty_session()
	GameClock.day_ending.connect(func(_reason: String): cancel())
	GameState.control_mode_changed.connect(cancel)
	Events.location_changed.connect(func(_id: String): cancel())

func defaults() -> Dictionary:
	return {"rod":1,"xp":0,"casts_day":0,"casts":0,"serial":0,"total":0,"counts":{},"collection":[],"achievements":[],"hook_charges":0,"pending":"","pending_day":0,"legend_pity":0,"legend_season":-1}

func empty_session() -> Dictionary:
	return {"phase":"idle","site":"","species":"","elapsed":0.0,"wait":0.0,"player":0.5,"fish":0.5,"progress":0.35,"band":0.25,"hooked":false,"message":""}

func bind(owner_game: Node) -> void:
	game=owner_game

func register_site(id: String, definition: Dictionary) -> bool:
	if sites.has(id) or id=="" or not definition.get("area") is String or not definition.get("habitat") is String: return false
	for key in ["shore","water"]:
		if not definition.get(key) is Array or definition[key].size()!=2: return false
		for axis in definition[key]:
			if not (axis is int or axis is float) or not is_finite(float(axis)): return false
	sites[id]=definition.duplicate(true)
	return true

func point(id: String, water: bool = false) -> Vector2:
	if not sites.has(id): return Vector2.INF
	var at: Array=sites[id].water if water else sites[id].shore
	var original:=Vector2(at[0],at[1])
	return FarmLayout.transform_point(original,"fishing_farm") if id=="farm_lake" else original

func near_site(id: String) -> bool:
	if not sites.has(id) or (id=="farm_lake" and not FarmLayout.active("fishing_farm")) or not is_instance_valid(game) or GameState.location!=sites[id].area or game.player.global_position.distance_to(point(id))>54: return false
	return game.auto_move!=null and game.auto_move.navigation.line_of_sight(game.player.global_position,point(id))

func site_has_water(id: String) -> bool:
	return id!="farm_lake" or FarmTerrain.effective_index(Vector2i((point(id,true)/32).floor())) in [5,6]

func active() -> bool:
	return session.phase in ["waiting","playing"]

func level() -> int:
	return mini(10,1+int(state.xp/60))

func rarity(species: String) -> String:
	return "传说" if species=="eternal" else str(Aquaculture.data.species.get(species,{}).get("rarity","未知"))

func daily_capacity(site_id: String = "") -> int:
	var lake: bool=(sites.has(site_id) and sites[site_id].habitat=="lake") or (site_id=="" and GameState.location=="farm")
	var ecology := get_node_or_null("/root/LakeEcology")
	if lake and ecology and ecology.has_method("fishing_capacity"):
		return clampi(int(ecology.fishing_capacity()),1,int(data.daily_casts))
	return int(data.daily_casts)

func remaining_casts(site_id: String = "") -> int:
	return maxi(0,daily_capacity(site_id)-(int(state.casts) if state.casts_day==GameClock.day else 0))

func fish_weight(species: String, site_id: String) -> int:
	var weight: float=data.species[species].weight
	var ecology := get_node_or_null("/root/LakeEcology")
	if sites[site_id].habitat=="lake" and species in ["golden","star","eternal"] and ecology and ecology.has_method("rare_factor"):
		weight*=clampf(float(ecology.rare_factor()),.5,1.5)
	return maxi(1,roundi(weight))

func ecology_health() -> int:
	var ecology := get_node_or_null("/root/LakeEcology")
	return int(ecology.state.health) if ecology and "state" in ecology else 0

func eligible(species: String, site_id: String) -> bool:
	if not data.species.has(species) or not sites.has(site_id): return false
	var fish: Dictionary=data.species[species]
	if int(state.rod)<int(fish.rod) or sites[site_id].habitat not in fish.habitats: return false
	if Calendar.season() not in fish.seasons: return false
	if not fish.weather.is_empty() and GameWeather.weather_id() not in fish.weather: return false
	if GameClock.minutes<float(fish.hours[0]) or GameClock.minutes>=float(fish.hours[1]): return false
	if species in ["golden","star"] and not Aquaculture.species_unlocked(species): return false
	if species=="eternal":
		return Xiaojing.state.unlocked and ecology_health()>=90 and GameWeather.is_meteor_night() and Aquaculture.state.xiaojing.stage==2 and int(state.legend_season)!=Calendar.season_serial()
	return true

func available_species(site_id: String) -> Array[String]:
	var result: Array[String]=[]
	for species in data.species:
		if eligible(species,site_id): result.append(species)
	return result

func choose_species(site_id: String, serial: int) -> String:
	var choices := available_species(site_id)
	if choices.is_empty(): return ""
	if "eternal" in choices and int(state.legend_pity)>=3: return "eternal"
	var total := 0
	for species in choices: total+=fish_weight(species,site_id)
	var hash_value: int=(serial*1103515245+GameClock.day*12345+int(sites[site_id].shore[0])*97)&0x7fffffff
	var roll: int=hash_value%total
	for species in choices:
		roll-=fish_weight(species,site_id)
		if roll<0: return species
	return choices[0]

func assistance() -> float:
	var kitchen := get_node_or_null("/root/Kitchen")
	return clampf(float(kitchen.fishing_assist()),0,.12) if kitchen and kitchen.has_method("fishing_assist") else 0.0

func start(site_id: String) -> bool:
	if busy or active() or state.pending!="" or GameClock.settling or not near_site(site_id): return false
	if not site_has_water(site_id):
		Events.notice.emit("浮标位置没有水。请先挖好水池，或把钓鱼点移到合适的岸边。")
		return false
	if game.backgrounded or game.player.action_time>0 or GameState.tool()!="fishing_rod": return false
	if remaining_casts(site_id)<=0:
		Events.notice.emit("今天的水面需要歇一歇。每个游戏日最多抛竿%d次。" % daily_capacity(site_id))
		return false
	if GameState.stamina<Kitchen.energy_cost(int(data.energy_per_cast)) or Inventory.count("fishing_bait")<1:
		Events.notice.emit("抛竿需要鱼饵1份、体力%d。可以在钓点用小麦制作鱼饵。" % data.energy_per_cast)
		return false
	var species := choose_species(site_id,int(state.serial)+1)
	if species=="": return false
	busy=true
	if not Inventory.exchange({"fishing_bait":1},{},0): busy=false; return false
	GameState.stamina-=Kitchen.energy_cost(int(data.energy_per_cast))
	GameState.changed.emit()
	if state.casts_day!=GameClock.day: state.casts_day=GameClock.day;state.casts=0
	state.casts+=1;state.serial+=1
	if eligible("eternal",site_id): state.legend_pity=mini(4,int(state.legend_pity)+1)
	var hooked: bool=state.hook_charges>0
	if hooked: state.hook_charges-=1
	session=empty_session()
	session.phase="waiting";session.site=site_id;session.species=species
	session.wait=1.5+float(int(state.serial)%17)/10.0
	session.hooked=hooked
	session.band=clampf(.25+float(state.rod)*.02-float(data.species[species].difficulty)*.02+(.035 if hooked else 0.0)+assistance(),.16,.48)
	var direction: Vector2=point(site_id,true)-game.player.global_position
	game.player.facing=Vector2(signf(direction.x),0) if absf(direction.x)>absf(direction.y) else Vector2(0,signf(direction.y))
	accumulator=0
	commit()
	return true

func tick(delta: float, holding: bool) -> void:
	if not active() or busy or not is_finite(delta) or delta<=0: return
	if not is_instance_valid(game) or game.backgrounded: return
	if not near_site(session.site): cancel();return
	# 同一控制信号以固定子步积分；30/60/120fps不会改变鱼速和进度速率。
	accumulator+=minf(delta,2.0)
	while accumulator+0.0000001>=STEP and active():
		accumulator-=STEP
		_step(STEP,holding)

func _step(delta: float, holding: bool) -> void:
	session.elapsed+=delta
	if session.phase=="waiting":
		if session.elapsed>=session.wait:
			session.phase="playing";session.elapsed=0.0
			changed.emit()
		return
	var difficulty: float=data.species[session.species].difficulty
	var phase: float=float(int(state.serial)%13)*.23
	session.fish=clampf(.5+.24*sin(session.elapsed*(.65+difficulty*.24)+phase)+.075*sin(session.elapsed*(1.4+difficulty*.2)),.08,.92)
	var half_band: float=float(session.band)*.5
	session.player=clampf(float(session.player)+(-.68 if holding else .45)*delta,half_band,1.0-half_band)
	if absf(float(session.player)-float(session.fish))<=float(session.band)*.5:
		session.progress=minf(1.0,float(session.progress)+(.20-difficulty*.012)*delta)
	else: session.progress=maxf(0.0,float(session.progress)-(.055+difficulty*.015)*delta)
	if session.progress>=1.0: land()
	elif session.progress<=0.0 or session.elapsed>=16.0:
		session.phase="escaped";session.message="鱼挣开了线。饵已用掉，下一次可以先观察它移动的方向。"
		changed.emit()

func land() -> void:
	if session.phase!="playing" or busy or float(session.progress)<1.0: return
	busy=true
	state.pending=session.species
	state.pending_day=GameClock.day
	session.phase="caught";session.message="钓到了"+data.species[session.species].name+"！"
	Events.fishing_landed.emit(session.site,session.species,int(state.serial),GameClock.day)
	busy=false
	if not claim():
		session.message+="背包已满，鱼暂留在水桶里。腾出空间后领取，不能重复抛竿。"
		commit()

func claim() -> bool:
	if busy or state.pending=="": return false
	var species: String=state.pending
	var item: String=data.species[species].item
	busy=true
	if not Inventory.exchange({},{item:1},0): busy=false;return false
	var caught_day: int=state.pending_day
	state.pending="";state.pending_day=0
	state.total+=1
	state.counts[species]=int(state.counts.get(species,0))+1
	state.xp+=int(data.species[species].xp)
	if species not in state.collection: state.collection.append(species)
	if species=="eternal": state.legend_pity=0;state.legend_season=Calendar.season_serial(caught_day)
	update_achievements()
	session.phase="landed";session.species=species;session.message="%s ×1 已放进背包。" % data.species[species].name
	Events.notice.emit(session.message)
	commit()
	return true

func update_achievements() -> void:
	var conditions := {"first":state.total>=1,"five":state.collection.size()>=5,"hundred":state.total>=100,"night":state.counts.has("star"),"eternal":state.counts.has("eternal")}
	for id in conditions:
		if conditions[id] and id not in state.achievements: state.achievements.append(id)

func cancel() -> void:
	if not active(): return
	session.phase="canceled";session.message="鱼线已收起。本次抛竿的鱼饵与体力已经使用。"
	accumulator=0
	changed.emit()

func upgrade_rod(expected_level: int = -1) -> bool:
	if busy or active() or not service_near() or state.rod>=3 or (expected_level!=-1 and state.rod!=expected_level): return false
	var upgrade: Dictionary=data.upgrades[str(int(state.rod)+1)]
	if state.xp<int(upgrade.xp): return false
	busy=true
	if not Inventory.exchange(upgrade.required,{},-int(upgrade.coins)): busy=false;return false
	state.rod+=1
	commit();return true

func service_near() -> bool:
	for id in sites:
		if near_site(id): return true
	return false

func buy_bait(quantity: int) -> bool:
	if busy or active() or not service_near() or quantity<1 or quantity>99: return false
	busy=true
	if not Inventory.exchange({},{"fishing_bait":quantity},-int(data.bait_price)*quantity): busy=false;return false
	commit();return true

func craft_bait(batches: int = 1) -> bool:
	if busy or active() or not service_near() or batches<1 or batches>99: return false
	busy=true
	if not Inventory.exchange({"wheat":batches},{"fishing_bait":batches*6},0): busy=false;return false
	commit();return true

func craft_hook() -> bool:
	if busy or active() or not service_near() or state.rod<2: return false
	busy=true
	if not Inventory.exchange(data.hook.required,{"fishing_hook":1},0): busy=false;return false
	commit();return true

func equip_hook() -> bool:
	if busy or active() or not service_near() or state.hook_charges>0: return false
	busy=true
	if not Inventory.exchange({"fishing_hook":1},{},0): busy=false;return false
	state.hook_charges=int(data.hook.charges)
	commit();return true

func breeding_fry(species: String, quantity: int = 1) -> bool:
	if busy or active() or not service_near() or species not in ["crucian","carp","grass","perch","golden","star"] or quantity<1 or quantity>99: return false
	if not Aquaculture.species_unlocked(species): return false
	var required := {"fish_"+species:quantity,"wheat":quantity}
	var rewards := {"fry_"+species:quantity*2}
	if species in ["golden","star"]:
		required={"fish_"+species:quantity,"crystal":quantity*(3 if species=="star" else 1)}
		if species=="star": required.star_alloy=quantity
		rewards={"fry_"+species:quantity}
	busy=true
	if not Inventory.exchange(required,rewards,0): busy=false;return false
	commit();return true

func commit() -> void:
	changed.emit()
	Events.progress_committed.emit()
	busy=false

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true)
	session=empty_session();accumulator=0;busy=false
	changed.emit()

func validate(raw: Variant, day: int) -> bool:
	if not raw is Dictionary or raw.size()!=defaults().size() or not whole(day,1,999999): return false
	for key in defaults():
		if not raw.has(key): return false
	if not whole(raw.rod,1,3) or not whole(raw.xp,0,MAX_TOTAL*24): return false
	if raw.rod>=2 and raw.xp<int(data.upgrades["2"].xp): return false
	if raw.rod>=3 and raw.xp<int(data.upgrades["3"].xp): return false
	if not whole(raw.casts_day,0,day) or not whole(raw.casts,0,int(data.daily_casts)): return false
	if (raw.casts_day==0)!=(raw.casts==0): return false
	var possible_casts: int=(int(raw.casts_day)-1)*int(data.daily_casts)+int(raw.casts) if raw.casts_day>0 else 0
	if not whole(raw.serial,int(raw.casts),possible_casts) or not whole(raw.total,0,int(raw.serial)): return false
	if not raw.counts is Dictionary or raw.counts.size()>data.species.size() or not raw.collection is Array or raw.collection.size()!=raw.counts.size(): return false
	var total := 0
	var xp := 0
	var seen := {}
	for species in raw.collection:
		if not species is String or not data.species.has(species) or seen.has(species) or not raw.counts.has(species): return false
		seen[species]=true
	for species in raw.counts:
		if not data.species.has(species) or not whole(raw.counts[species],1,MAX_TOTAL): return false
		total+=int(raw.counts[species]);xp+=int(raw.counts[species])*int(data.species[species].xp)
	if total!=raw.total or xp!=raw.xp: return false
	if not raw.achievements is Array or raw.achievements.size()>data.achievements.size(): return false
	seen.clear()
	for id in raw.achievements:
		if not data.achievements.has(id) or seen.has(id): return false
		seen[id]=true
	if not whole(raw.hook_charges,0,int(data.hook.charges)) or not raw.pending is String or (raw.pending!="" and not data.species.has(raw.pending)): return false
	if raw.hook_charges>0 and raw.rod<2: return false
	if not whole(raw.pending_day,0,day) or (raw.pending=="")!=(raw.pending_day==0): return false
	if raw.pending!="" and raw.total>=raw.serial: return false
	if not whole(raw.legend_pity,0,4) or not whole(raw.legend_season,-1,Calendar.season_serial(day)): return false
	return true

func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
