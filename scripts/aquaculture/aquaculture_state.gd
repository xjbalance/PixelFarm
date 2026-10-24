extends Node
## 湖岸事务与统一日结算。UI 只能请求动作，不能直接发鱼或加成长。
signal changed
const SITES := {"pen_1":Vector2(944,592),"pen_2":Vector2(1104,752),"pen_3":Vector2(1264,592),"pen_4":Vector2(1104,432)}
var data: Dictionary = {}
var state: Dictionary = {}
var game: Node
var busy: bool = false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/aquaculture/fish.json")))
	state=defaults()
	GameClock.day_advanced.connect(settle_day)

func defaults(day: int = 1) -> Dictionary:
	return AquacultureSaveSchema.defaults(day)

func bind(owner_game: Node) -> void:
	game=owner_game

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true)
	busy=false
	changed.emit()
	Events.navigation_changed.emit()

func pen(id: String) -> Dictionary:
	return state.pens.get(id,{})

func summary(id: String) -> Dictionary:
	var p := pen(id)
	if p.is_empty(): return {}
	var fry := 0
	var oldest := 0
	for c in p.cohorts:
		fry+=int(c.count)
		oldest=maxi(oldest,int(c.age))
	return {"fry":fry,"total":fry+int(p.adults),"capacity":AquacultureSaveSchema.CAPACITY[int(p.level)],
		"growth":float(oldest)/4.0,"mature":p.adults>0,"feed_needed":ceili(float(fry+int(p.adults))/8)}

func near_pen(id: String) -> bool:
	return SITES.has(id) and is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(SITES[id])<=54

func near_lake() -> bool:
	for id in SITES:
		if near_pen(id): return true
	return false

func near_shop() -> bool:
	if not is_instance_valid(game) or GameState.location!="farm": return false
	for object in get_tree().get_nodes_in_group("interactables"):
		if "kind" in object and object.kind=="shop" and object.is_visible_in_tree() and game.player.global_position.distance_to(object.global_position)<=60: return true
	return false

func highest_level() -> int:
	var result := 0
	for p in state.pens.values(): result=maxi(result,int(p.level))
	return result

func available(id: String) -> bool:
	if not SITES.has(id): return false
	if id in ["pen_1","pen_2"]: return true
	return highest_level()>=(2 if id=="pen_3" else 3)

func species_unlocked(id: String) -> bool:
	if not data.species.has(id): return false
	if id=="golden":
		var common := 0
		for known in state.collection:
			if known in ["crucian","carp","grass","perch"]: common+=1
		return common>=3 and "mine_b" in MineState.state.unlocked and highest_level()>=2
	if id=="star": return "research" in state.quests and "mine_c" in MineState.state.unlocked and highest_level()>=3
	return true

func _exchange(required: Dictionary, rewards: Dictionary, coins: int) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins):
		busy=false
		Events.notice.emit("材料、余额或背包空间不足；鱼群和物品都没有变化。")
		return false
	return true

func commit(navigation: bool = false) -> void:
	# 持有事务锁直到全部展示信号结束，防止同步重入重复扣物。
	changed.emit()
	if navigation: Events.navigation_changed.emit()
	Events.progress_committed.emit()
	busy=false

func build(id: String) -> bool:
	if busy or not near_pen(id) or not available(id) or pen(id).built: return false
	var cost: Dictionary=data.levels["1"]
	if not _exchange(cost.required,{},-int(cost.coins)): return false
	var p := pen(id)
	p.built=true
	p.level=1
	LakeEcology.facility_added()
	p.last_settled_day=GameClock.day
	Events.notice.emit("木桩和护网安好了。先投少量鱼苗，记得留出长大的空间。")
	commit(true)
	return true

func upgrade(id: String) -> bool:
	if busy or not near_pen(id) or not pen(id).built or pen(id).level>=3: return false
	var p := pen(id)
	var next_level: int=int(p.level)+1
	var cost: Dictionary=data.levels[str(next_level)]
	if not _exchange(cost.required,{},-int(cost.coins)): return false
	p.level=next_level
	Events.notice.emit("鱼栏已升级，原来的鱼群和成长进度全部保留。")
	commit(true)
	return true

func stock(id: String, species: String, quantity: int) -> bool:
	if busy or not near_pen(id) or quantity<1 or quantity>32 or not species_unlocked(species): return false
	var p := pen(id)
	if not p.built or int(p.level)<int(data.species[species].level) or (p.species!="" and p.species!=species): return false
	if int(summary(id).total)+quantity>int(summary(id).capacity):
		Events.notice.emit("鱼栏容量不足。请减少投放数量，或先升级鱼栏。")
		return false
	var required := {"fry_"+species:quantity}
	var coverage: int=int(p.fed_count)
	if p.last_feed_day==GameClock.day:
		var new_total: int=int(summary(id).total)+quantity
		var extra_feed: int=maxi(0,ceili(float(new_total)/8)-ceili(float(coverage)/8))
		if extra_feed>0: required["fish_feed"]=extra_feed
		coverage=maxi(coverage,new_total)
	if not _exchange(required,{},0): return false
	if p.last_feed_day==GameClock.day: p.fed_count=coverage
	p.species=species
	_add_cohort(p,quantity,0)
	commit()
	return true

func _add_cohort(p: Dictionary, quantity: int, age: int) -> void:
	for cohort in p.cohorts:
		if int(cohort.age)==age:
			cohort.count+=quantity
			return
	p.cohorts.append({"count":quantity,"age":age})

func feed(id: String) -> bool:
	if busy or not near_pen(id) or summary(id).total==0 or pen(id).last_feed_day>=GameClock.day: return false
	var needed: int=int(summary(id).feed_needed)
	if not _exchange({"fish_feed":needed},{},0): return false
	pen(id).last_feed_day=GameClock.day
	pen(id).fed_count=int(summary(id).total)
	_record_care(id)
	Events.notice.emit("今天的饲料已经投好，成长会在次日统一结算。")
	commit()
	return true

func feed_reserve(id: String, quantity: int) -> bool:
	if busy or not near_pen(id) or pen(id).level!=3 or quantity<1 or quantity>999 or int(pen(id).feed_stock)+quantity>999: return false
	if not _exchange({"fish_feed":quantity},{},0): return false
	pen(id).feed_stock+=quantity
	commit()
	return true

func maintain(id: String) -> bool:
	if busy or GameClock.settling or not near_pen(id) or not pen(id).built or pen(id).last_maintain_day>=GameClock.day: return false
	var p := pen(id)
	var pristine: bool=int(p.water)>=100 and int(p.health)>=100
	busy=true
	if not pristine and not GameState.spend_energy(2): busy=false; return false
	if pristine: Events.notice.emit("网面与水样已经检查，水质良好，无需清理，也不消耗体力。")
	p.water=mini(100,int(p.water)+22)
	p.health=mini(100,int(p.health)+6)
	p.last_maintain_day=GameClock.day
	_record_care(id)
	commit()
	return true

func harvest(id: String, quantity: int) -> bool:
	if busy or not near_pen(id) or quantity<1 or quantity>int(pen(id).adults): return false
	var p := pen(id)
	var species: String=p.species
	if not _exchange({},{"fish_"+species:quantity},0): return false
	p.adults-=quantity
	if species not in state.collection: state.collection.append(species)
	state.harvested[species]=mini(999999,int(state.harvested.get(species,0))+quantity)
	if state.xiaojing.stage==1 and state.xiaojing.pen==id:
		state.xiaojing.harvested=mini(999999,int(state.xiaojing.harvested)+quantity)
	if summary(id).total==0:
		p.species=""
		p.breeding=0
	Events.notice.emit("收获%s ×%d；留下的种鱼与幼鱼仍在栏中。" % [data.species[species].name,quantity])
	commit()
	return true

func buy(id: String, quantity: int) -> bool:
	if busy or not (near_lake() or near_shop()) or quantity<1 or quantity>99: return false
	var cost := 0
	if id=="fish_feed": cost=4
	elif id.begins_with("fry_"):
		var species := id.trim_prefix("fry_")
		if not species_unlocked(species) or species in ["golden","star"]: return false
		cost=int(data.species[species].fry_price)
	else: return false
	if not _exchange({},{id:quantity},-cost*quantity): return false
	commit()
	return true

func collect_rare(species: String) -> bool:
	if busy or not near_lake() or species not in ["golden","star"] or not species_unlocked(species): return false
	var definition: Dictionary=data.species[species]
	if not _exchange(definition.rare_cost,{"fry_"+species:1},-int(definition.rare_coins)): return false
	commit()
	return true

func process(recipe: String, batches: int = 1) -> bool:
	if busy or not near_lake() or not data.recipes.has(recipe) or batches<1 or batches>99: return false
	var entry: Dictionary=data.recipes[recipe]
	if highest_level()<int(entry.level): return false
	var required := {}
	var rewards := {}
	for item in entry.required: required[item]=int(entry.required[item])*batches
	for item in entry.rewards: rewards[item]=int(entry.rewards[item])*batches
	if not _exchange(required,rewards,0): return false
	state.processed[recipe]=mini(999999,int(state.processed.get(recipe,0))+batches)
	commit()
	return true

func consume_food(item: String) -> bool:
	if busy or GameClock.settling or item not in ["dried_fish","fish_soup"] or state.meal_day>=GameClock.day or GameState.stamina>=GameState.max_stamina(): return false
	if not _exchange({item:1},{},0): return false
	state.meal_day=GameClock.day
	GameState.stamina=mini(GameState.max_stamina(),int(GameState.stamina)+int(data.items[item].energy))
	GameState.changed.emit()
	commit()
	return true

func settle_day() -> void:
	var today: int=GameClock.day
	if busy or today<=int(state.last_settled_day): return
	busy=true
	# 仅真实日事件推进一次；读档、场景切换和离线时长不补算。
	for id in SITES:
		var p := pen(id)
		if today<=int(p.last_settled_day): continue
		p.last_settled_day=today
		if not p.built or summary(id).total==0: continue
		var yesterday: int=today-1
		var info := summary(id)
		var fed: bool=int(p.last_feed_day)==yesterday
		if not fed and p.level==3 and p.feed_stock>=info.feed_needed:
			p.feed_stock-=int(info.feed_needed)
			p.last_feed_day=yesterday
			p.fed_count=int(info.total)
			fed=true
		var definition: Dictionary=data.species[p.species]
		var season: int=Calendar.season(yesterday)
		var comfortable: bool=season in definition.seasons
		var good: bool=int(p.water)>=int(definition.water) and p.health>=60
		var growth: int=(4 if comfortable else 3) if fed and good else (2 if fed else 1)
		if LakeEcology.state.health<35: growth=mini(growth,2)
		elif LakeEcology.state.health>=90 and fed and good: growth+=1
		var survivors: Array=[]
		for c in p.cohorts:
			c.age+=growth
			if int(c.age)>=int(definition.growth_days)*4: p.adults+=int(c.count)
			else: survivors.append(c)
		p.cohorts=survivors
		var rare_ok: bool=p.species not in ["golden","star"] or (comfortable and p.health>=90)
		if fed and good and rare_ok and int(p.adults)>=int(definition.min_adults) and int(info.total)<int(info.capacity):
			p.breeding+=1
			if p.breeding>=int(definition.breed_days):
				_add_cohort(p,mini(int(definition.offspring),int(info.capacity)-int(info.total)),0)
				p.breeding=0
		# 不满足条件时保留繁殖进度，满栏不堆叠多次奖励。
		var crowded: bool=float(info.total)/maxi(1,int(info.capacity))>.8
		var change: int=-2-(2 if crowded else 0)+(1 if p.level==2 else (3 if p.level==3 else 0))
		change+=GameWeather.lake_water_delta(yesterday)
		p.water=clampi(int(p.water)+change,0,100)
		p.health=clampi(int(p.health)+(2 if fed and good else -2),0,100)
	state.last_settled_day=today
	commit()

func quest_ready(id: String) -> bool:
	if id=="intro": return id not in state.quests and highest_level()>=1 and total_harvested()>=2
	if id=="fresh": return "intro" in state.quests and (state.order_day==0 or GameClock.day-int(state.order_day)>=3) and int(state.harvested.get("carp",0))-int(state.order_baseline)>=4 and Inventory.count("fish_carp")>=4
	if id=="research": return id not in state.quests and "intro" in state.quests and "golden" in state.collection and Inventory.count("fish_golden")>=1
	return false

func quest_status(id: String) -> String:
	match id:
		"intro": return "周砚：建一座鱼栏，亲自养成并收获2尾鱼（%d/2）。奖励40金、鲤鱼苗2、饲料4。" % mini(2,total_harvested())
		"fresh": return "阿禾：每3日可交一单；本轮新收获鲤鱼%d/4，交鲤鱼4，领取132金。" % mini(4,maxi(0,int(state.harvested.get("carp",0))-int(state.order_baseline)))
		"research": return "林芽：收获金鳞鱼并提交1尾，记录鳞片与水质。奖励120金、饲料8，开放星辉鱼研究。"
	return ""

func total_harvested() -> int:
	var result := 0
	for amount in state.harvested.values(): result+=int(amount)
	return result

func claim_quest(id: String) -> bool:
	if busy or not near_lake() or not quest_ready(id): return false
	var required := {}
	var rewards := {}
	var coins := 0
	match id:
		"intro": rewards={"fry_carp":2,"fish_feed":4}; coins=40
		"fresh": required={"fish_carp":4}; coins=132
		"research": required={"fish_golden":1}; rewards={"fish_feed":8}; coins=120
		_: return false
	if not _exchange(required,rewards,coins): return false
	if id=="fresh":
		state.order_day=GameClock.day
		state.order_count=mini(999999,int(state.order_count)+1)
		state.order_baseline=int(state.harvested.get("carp",0))
	else: state.quests.append(id)
	commit()
	return true

func invite_xiaojing(id: String = "pen_2") -> bool:
	if busy or GameClock.settling or not near_pen(id) or summary(id).total<1 or state.xiaojing.stage!=0: return false
	if not Xiaojing.state.unlocked or Xiaojing.state.affection<50 or Xiaojing.state.trust<40: return false
	busy=true
	state.xiaojing={"stage":1,"invited_day":GameClock.day,"care_days":[],"pen":id,"harvested":0}
	Events.notice.emit("小京：我想比较三天的水样。你照看鱼，我记下水草和光线；留两尾收获给我们辨认吧。")
	commit()
	return true

func _record_care(id: String) -> void:
	var x: Dictionary=state.xiaojing
	if x.stage!=1 or x.pen!=id or x.care_days.size()>=3 or GameClock.day in x.care_days or not xiaojing_present(id): return
	if pen(id).last_feed_day==GameClock.day and pen(id).last_maintain_day==GameClock.day and summary(id).total>0:
		x.care_days.append(GameClock.day)

func complete_xiaojing() -> bool:
	var x: Dictionary=state.xiaojing
	if busy or GameClock.settling or x.stage!=1 or not near_pen(x.pen) or x.care_days.size()<3 or x.harvested<2: return false
	if not Xiaojing.state.unlocked or Xiaojing.state.affection<50 or Xiaojing.state.trust<40 or not xiaojing_present(x.pen): return false
	busy=true
	x.stage=2
	Xiaojing.boost(0,0,3,"lake_care")
	Xiaojing.changed.emit()
	Events.notice.emit("小京把水样收进自己的行囊：温室旧水道里也有这样的星斑。先把金鳞鱼的记录做完，等晶石洞窟开放，我们再试着培育它。羁绊+3。")
	commit()
	return true

func companion_position() -> Vector2:
	return {"pen_1":Vector2(944,560),"pen_2":Vector2(1072,752),"pen_3":Vector2(1264,624),"pen_4":Vector2(1136,432)}.get(state.xiaojing.pen,Vector2(1072,752))

func xiaojing_present(id: String) -> bool:
	if GameClock.minutes<540 or GameClock.minutes>=1080 or not near_pen(id): return false
	for person in get_tree().get_nodes_in_group("xiaojing"):
		if person.is_visible_in_tree() and person.global_position.distance_to(SITES[id])<=76: return true
	return false

func observe_xiaojing() -> bool:
	var x: Dictionary=state.xiaojing
	if busy or GameClock.settling or x.stage!=1 or not xiaojing_present(x.pen): return false
	var before: int=x.care_days.size()
	busy=true
	_record_care(x.pen)
	if x.care_days.size()==before: busy=false; return false
	commit()
	return true
