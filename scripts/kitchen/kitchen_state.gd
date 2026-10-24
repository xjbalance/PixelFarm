extends Node
## 厨房、加工与一份料理增益；库存交换和唯一队列结算均在此层验证。
signal changed
const ANCHOR := Vector2(848,432)
const BERRY := Vector2(240,560)
const FACILITIES := ["mill","cheese_table","smoker","jam_pot"]
const RECIPES := ["carrot_stew","potato_bread","egg_meal","milk_porridge","fish_feast"]
const PROCESSING := ["flour","cheese","smoked_fish","berry_jam"]
const BUFF_SECONDS := {"speed":120.0,"thrift":90.0,"mining":90.0,"fishing":120.0}
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/kitchen/kitchen.json")))
	state=defaults(GameClock.day)
	GameClock.day_advanced.connect(settle_day)

func defaults(day: int = GameClock.day) -> Dictionary:
	return {"built":[],"queue":[],"next_job":1,"claimed":[],"cooked":{},"collected":{},"berry_day":0,"buff":{"id":"","remaining":0.0},"last_settled_day":day}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit()

func near_kitchen() -> bool:
	return is_instance_valid(game) and GameState.location=="home" and game.player.global_position.distance_to(ANCHOR)<=54

func near_berry() -> bool:
	return is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(BERRY)<=54

func _exchange(required: Dictionary, rewards: Dictionary, coins: int = 0) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins):
		busy=false
		Events.notice.emit("材料、余额或背包空间不足；本次没有扣除物品。")
		return false
	return true

func _commit() -> void:
	changed.emit();Events.progress_committed.emit();busy=false

func build(id: String) -> bool:
	if busy or not near_kitchen() or id not in FACILITIES or id in state.built: return false
	var definition: Dictionary=data.facilities[id]
	if not _exchange(definition.required,{},-int(definition.coins)): return false
	state.built.append(id);_commit();return true

func recipe_unlocked(id: String) -> bool:
	if id not in RECIPES: return false
	var recipe: Dictionary=data.recipes[id]
	if recipe.facility!="" and recipe.facility not in state.built: return false
	if recipe.unlock=="basic": return true
	if recipe.unlock=="fishing":
		var fishing := get_node_or_null("/root/Fishing")
		return fishing!=null and int(fishing.state.total)>0
	var livestock := get_node_or_null("/root/Livestock")
	if livestock==null: return false
	for animal in livestock.state.animals:
		if animal.species==recipe.unlock and animal.product_day>0: return true
	return false

func scaled(items: Dictionary, batches: int) -> Dictionary:
	var result := {}
	for item in items: result[item]=int(items[item])*batches
	return result

func cook(id: String, batches: int = 1) -> bool:
	if busy or not near_kitchen() or batches<1 or batches>8 or not recipe_unlocked(id): return false
	var recipe: Dictionary=data.recipes[id]
	if not _exchange(scaled(recipe.required,batches),scaled(recipe.rewards,batches)): return false
	state.cooked[id]=mini(999999,int(state.cooked.get(id,0))+batches)
	Events.dish_cooked.emit(id,batches,int(state.cooked[id]),GameClock.day)
	Events.notice.emit("做好了%s ×%d，食用与鱼汤共享每天一份料理额度。" % [recipe.name,batches])
	_commit();return true

func enqueue(id: String, batches: int = 1) -> bool:
	if busy or not near_kitchen() or id not in PROCESSING or batches<1 or batches>8 or state.queue.size()>=4 or state.next_job>=999999: return false
	var recipe: Dictionary=data.processing[id]
	if recipe.facility not in state.built: return false
	if GameClock.day+int(recipe.days)>999999: return false
	if not _exchange(scaled(recipe.required,batches),{}): return false
	state.queue.append({"id":int(state.next_job),"recipe":id,"batches":batches,"started":GameClock.day,"ready_day":GameClock.day+int(recipe.days),"ready":false})
	state.next_job+=1
	Events.notice.emit("加工已开始。到第%d天后回厨房领取，满包时成品会留在设备内。" % [GameClock.day+int(recipe.days)])
	_commit();return true

func settle_day() -> void:
	if busy or GameClock.day<=int(state.last_settled_day): return
	busy=true
	for job in state.queue:
		if int(job.ready_day)<=GameClock.day: job.ready=true
	state.last_settled_day=GameClock.day
	_commit()

func claim_job(id: int) -> bool:
	if busy or not near_kitchen(): return false
	var index := -1
	for i in range(state.queue.size()):
		if int(state.queue[i].id)==id: index=i;break
	if index<0: return false
	var job: Dictionary=state.queue[index]
	if not job.ready or int(job.ready_day)>GameClock.day: return false
	var rewards := scaled(data.processing[job.recipe].rewards,int(job.batches))
	if not _exchange({},rewards): return false
	state.collected[job.recipe]=mini(999999,int(state.collected.get(job.recipe,0))+int(job.batches))
	state.claimed.append(id)
	if state.claimed.size()>128: state.claimed.pop_front()
	Events.processing_claimed.emit("kitchen",job.recipe,id,int(job.batches))
	state.queue.remove_at(index)
	_commit();return true

func harvest_berries() -> bool:
	if busy or GameClock.settling or not near_berry() or int(state.berry_day)>=GameClock.day: return false
	var cost := energy_cost(2)
	if GameState.stamina<cost: return false
	var amount := 1 if Calendar.season()==3 else 2
	if not _exchange({},{"wild_berry":amount}): return false
	GameState.stamina-=cost;state.berry_day=GameClock.day
	GameState.changed.emit()
	Events.berry_gathered.emit(GameClock.day,amount)
	Events.notice.emit("采到野莓%d份。冬季枝上只留一份，明天再来看看。" % amount)
	_commit();return true

func consume(id: String) -> bool:
	if busy or GameClock.settling or not data.items.has(id) or data.items[id].kind!="food" or int(Aquaculture.state.meal_day)>=GameClock.day: return false
	var item: Dictionary=data.items[id]
	if GameState.stamina>=GameState.max_stamina(): return false
	if state.buff.id!="" and float(state.buff.remaining)>0: return false
	if not _exchange({id:1},{}): return false
	Aquaculture.state.meal_day=GameClock.day
	GameState.stamina=mini(GameState.max_stamina(),GameState.stamina+int(item.energy))
	state.buff={"id":str(item.buff),"remaining":float(item.seconds)}
	GameState.changed.emit();Aquaculture.changed.emit()
	_commit();return true

func _process(delta: float) -> void:
	if busy or state.is_empty() or state.buff.id=="" or GameState.modal or not GameClock.running: return
	if is_instance_valid(game) and game.backgrounded: return
	state.buff.remaining=maxf(0,float(state.buff.remaining)-maxf(0,delta))
	if state.buff.remaining<=0:
		state.buff={"id":"","remaining":0.0}
		changed.emit();Events.progress_committed.emit()

func speed_multiplier() -> float:
	return 1.15 if state.get("buff",{}).get("id","")=="speed" and float(state.buff.remaining)>0 else 1.0
func energy_cost(amount: int) -> int:
	if amount<=0: return 0
	return maxi(1,floori(amount*.75)) if state.get("buff",{}).get("id","")=="thrift" and float(state.buff.remaining)>0 else amount
func mining_power() -> int:
	return 1 if state.get("buff",{}).get("id","")=="mining" and float(state.buff.remaining)>0 else 0
func fishing_assist() -> float:
	return .03 if state.get("buff",{}).get("id","")=="fishing" and float(state.buff.remaining)>0 else 0.0

func validate(raw: Variant, day: int) -> bool:
	if not exact(raw,defaults(day).keys()) or not whole(day,1,999999): return false
	if not unique(raw.built,FACILITIES) or not whole(raw.next_job,1,999999) or not whole(raw.berry_day,0,day) or not whole(raw.last_settled_day,1,day): return false
	for name in ["cooked","collected"]:
		if not raw[name] is Dictionary or raw[name].size()>(RECIPES.size() if name=="cooked" else PROCESSING.size()): return false
		for id in raw[name]:
			if id not in (RECIPES if name=="cooked" else PROCESSING) or not whole(raw[name][id],1,999999): return false
	if not raw.claimed is Array or raw.claimed.size()>128: return false
	var known := {}
	for id in raw.claimed:
		if not whole(id,1,int(raw.next_job)-1) or known.has(int(id)): return false
		known[int(id)]=true
	if not raw.queue is Array or raw.queue.size()>4: return false
	for job in raw.queue:
		if not exact(job,["id","recipe","batches","started","ready_day","ready"]): return false
		if not whole(job.id,1,int(raw.next_job)-1) or known.has(int(job.id)) or job.recipe not in PROCESSING or not whole(job.batches,1,8) or not whole(job.started,1,day): return false
		known[int(job.id)]=true
		var recipe: Dictionary=data.processing[job.recipe]
		if recipe.facility not in raw.built or not whole(job.ready_day,int(job.started)+int(recipe.days),int(job.started)+int(recipe.days)) or not job.ready is bool: return false
		if job.ready and int(job.ready_day)>day: return false
		if int(job.ready_day)>999999: return false
	var buff: Variant=raw.buff
	if not exact(buff,["id","remaining"]) or not buff.id is String: return false
	if not (buff.remaining is int or buff.remaining is float) or not is_finite(float(buff.remaining)): return false
	if buff.id=="": return float(buff.remaining)==0
	return BUFF_SECONDS.has(buff.id) and float(buff.remaining)>0 and float(buff.remaining)<=float(BUFF_SECONDS[buff.id])

func whole(value: Variant, low: int, high: int) -> bool:
	return FarmSaveSchema.whole(value,low,high)
func exact(raw: Variant, keys: Array) -> bool:
	return AquacultureSaveSchema.exact(raw,keys)
func unique(values: Variant, allowed: Array) -> bool:
	return AquacultureSaveSchema.unique(values,allowed)
