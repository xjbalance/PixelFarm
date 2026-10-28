extends Node
## 真实建设、现场订单与社区值日；原剧情选择只影响推荐/小补给，不锁定另一条路线。
signal changed
const TYPES := ["dock","community"]
const LAMPS := ["west","square","river"]
const STATIONS := {"linya":Vector2(624,720),"zhou":Vector2(688,752),"ahe":Vector2(720,752)}
var data: Dictionary = {}
var state: Dictionary = {}
var game: Node
var busy: bool = false
func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/world_progress/development.json")))
	state=defaults()
	Events.farm_committed.connect(on_farm)
	Events.fishing_landed.connect(on_fish)
	Events.aquaculture_harvested.connect(on_aquaculture)
	Events.animal_produced.connect(on_animal)
	Events.dish_cooked.connect(on_cooking)
	Events.processing_claimed.connect(on_processing)
func defaults(_day: int = GameClock.day) -> Dictionary:
	return {"dock":0,"community":0,"build_days":{"dock":[],"community":[]},"parcels":{},"parcel_claimed":[],"order":{},"trade_day":0,"trade_count":0,"community_day":0,"community_count":0,"supper_day":0,"supper_count":0,"lamps":{"west":0,"square":0,"river":0},"tracking":{"farm":{},"fishing":0,"aquaculture":{},"animal":{},"cooking":{},"jobs":[]}}
func bind(owner_game: Node) -> void: game=owner_game
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit();Events.navigation_changed.emit()
func anchor(context: String) -> Vector2:
	var at: Array=data.board
	if context=="dock": at=data.dock_anchor
	elif context=="community": at=data.community_anchor
	elif context.begins_with("lamp:"):
		var id := context.trim_prefix("lamp:")
		if not data.lamps.has(id): return Vector2.INF
		at=data.lamps[id]
	return Vector2(at[0],at[1])
func near(context: String) -> bool:
	if not is_instance_valid(game) or GameState.location!="village" or game.player.global_position.distance_to(anchor(context))>54: return false
	var object: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if "development_id" in node and node.development_id==context and node.is_visible_in_tree(): object=node;break
	return game.auto_move!=null and game.auto_move.navigation.line_of_sight(game.player.global_position,anchor(context),object)
func branch_id() -> String: return Letters.direction if data.branches.has(Letters.direction) else "default"
func branch_line() -> String: return data.branches[branch_id()].line
func commit(navigation: bool = false) -> void:
	changed.emit()
	if navigation: Events.navigation_changed.emit()
	Events.progress_committed.emit();busy=false
func exchange(required: Dictionary, rewards: Dictionary, coins: int = 0) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins): busy=false;return false
	return true
func build(id: String, expected_level: int = -1) -> bool:
	if busy or GameClock.settling or id not in TYPES or Story.stage!=8 or not VillageProjects.all_built() or not near("board"): return false
	var level: int=state[id]
	if level>=2 or (expected_level!=-1 and expected_level!=level): return false
	if level==1 and ((id=="dock" and state.trade_count<1) or (id=="community" and state.community_count<1)):
		Events.notice.emit("先在已建设施实际完成一次交接，再扩建第二阶段。")
		return false
	var definition: Dictionary=data.buildings[id][str(level+1)]
	if not exchange(definition.required,{},-int(definition.coins)): return false
	state[id]=level+1;state.build_days[id].append(GameClock.day)
	if level==0: state.parcels[id]={"direction":branch_id(),"items":data.branches[branch_id()][id].duplicate(true)}
	Events.notice.emit(definition.name+"已建成。原有桥、水井、共仓与温室照常保留。")
	commit(true);return true
func claim_parcel(id: String) -> bool:
	if busy or not near("board") or id not in TYPES or not state.parcels.has(id) or id in state.parcel_claimed: return false
	if not exchange({},state.parcels[id].items): return false
	state.parcels.erase(id);state.parcel_claimed.append(id);commit();return true
func order_unlocked(id: String) -> bool:
	if not data.orders.has(id) or state.dock<int(data.orders[id].level): return false
	var unlock: String=data.orders[id].unlock
	if unlock=="basic": return true
	if unlock=="meal": return Kitchen.recipe_unlocked("potato_bread") and Kitchen.recipe_unlocked("egg_meal")
	return "cheese_table" in Kitchen.state.built and Kitchen.recipe_unlocked("milk_porridge") and Kitchen.state.next_job<999999
func accept_order(id: String) -> bool:
	if busy or GameClock.settling or not near("dock") or Story.stage!=8 or not state.order.is_empty() or not order_unlocked(id): return false
	busy=true
	state.order={"id":id,"started":GameClock.day,"min_fish":int(Fishing.state.serial)+1,"min_job":int(Kitchen.state.next_job),"credit":{}}
	commit();return true
func cancel_order() -> bool:
	if busy or not near("dock") or state.order.is_empty(): return false
	busy=true;state.order={};commit();return true
func note(item: String, quantity: int, day: int) -> void:
	if state.order.is_empty() or quantity<1 or day<int(state.order.started) or day>GameClock.day: return
	var required: Dictionary=data.orders[state.order.id].required
	if not required.has(item): return
	state.order.credit[item]=mini(int(required[item]),int(state.order.credit.get(item,0))+quantity)
func trade_ready() -> bool:
	if state.order.is_empty(): return false
	for item in data.orders[state.order.id].required:
		if int(state.order.credit.get(item,0))<int(data.orders[state.order.id].required[item]): return false
	return true
func trade_reward() -> Dictionary:
	if state.order.is_empty(): return {}
	var branch: Dictionary=data.branches[branch_id()]
	return {"coins":int(data.orders[state.order.id].coins)+int(branch.trade_coins),"items":branch.trade_items.duplicate(true)}
func use_trade(id: String = "") -> bool:
	if busy or GameClock.settling or not near("dock") or state.order.is_empty() or (id!="" and id!=state.order.id) or not trade_ready(): return false
	if state.trade_day>0 and GameClock.day-int(state.trade_day)<int(data.trade_cooldown): return false
	var required: Dictionary=data.orders[state.order.id].required
	var reward := trade_reward()
	if not exchange(required,reward.items,int(reward.coins)): return false
	state.trade_day=GameClock.day;state.trade_count+=1;state.order={}
	Events.notice.emit("货物与新产记录核对好了。车位仍留给农产品，下一次交货间隔三日。")
	commit();return true
func inspect_lamp(id: String) -> bool:
	if busy or GameClock.settling or id not in LAMPS or state.community<1 or not near("lamp:"+id) or GameClock.minutes<1080 or GameClock.minutes>=1320 or state.lamps[id]>=GameClock.day: return false
	busy=true
	if not GameState.spend_energy(1): busy=false;return false
	state.lamps[id]=GameClock.day
	Events.world_inspected.emit("community_lamp:"+id)
	commit();return true
func lamps_ready() -> bool:
	for id in LAMPS:
		if int(state.lamps[id])!=GameClock.day: return false
	return true
func weekly_active() -> bool:
	return state.community>=2 and GameClock.day%7==6 and GameClock.minutes>=1080 and GameClock.minutes<1320 and Story.stage==8 and not River.gathering() and StarStory.state.wedding_phase not in [1,2,3] and Festival.active_id()!="summer"
func community_station(person: String) -> Vector2:
	return STATIONS[person] if STATIONS.has(person) and weekly_active() else Vector2.INF
func gathered_people() -> int:
	var result := 0
	if not is_instance_valid(game): return 0
	for person in ["linya","zhou","ahe"]:
		for node in get_tree().get_nodes_in_group("interactables"):
			if "person_id" in node and node.person_id==person and node.is_visible_in_tree() and node.global_position.distance_to(anchor("community"))<=128:
				result+=1;break
	return result
func daily_community(activity: String = "lamps") -> bool:
	if busy or GameClock.settling or activity not in ["lamps","supper"] or not near("community") or state.community<1 or state.community_day>=GameClock.day or not lamps_ready() or GameClock.minutes<1080 or GameClock.minutes>=1320: return false
	if activity=="supper" and (not weekly_active() or gathered_people()<2): return false
	var entry: Dictionary=data.community[activity]
	if not exchange(entry.required,entry.items,int(entry.coins)): return false
	state.community_day=GameClock.day;state.community_count+=1
	if activity=="supper": state.supper_day=GameClock.day;state.supper_count+=1
	Events.notice.emit("值日记录已经交接。每一天只结算一次巡灯或共餐，明晚也有人接着做。")
	commit();return true
func on_farm(kind: String, cell: Vector2i, crop: String, serial: int) -> void:
	if busy or kind!="收获" or not Catalog.crops.has(crop) or GameState.location!="farm" or serial!=Xiaojing.state.plant_serial or not Rect2i(0,0,48,32).has_point(cell): return
	var id := "%d,%d" % [cell.x,cell.y]
	if int(state.tracking.farm.get(id,0))>=GameClock.day: return
	busy=true;state.tracking.farm[id]=GameClock.day;note(crop,1,GameClock.day);commit()
func on_fish(site: String, species: String, serial: int, day: int) -> void:
	if busy or not Fishing.busy or not Fishing.sites.has(site) or not Fishing.data.species.has(species) or day!=GameClock.day or serial<=state.tracking.fishing or serial!=Fishing.state.serial or Fishing.state.pending!=species: return
	busy=true;state.tracking.fishing=serial
	if not state.order.is_empty() and serial>=int(state.order.min_fish): note(str(Fishing.data.species[species].item),1,day)
	commit()
func on_aquaculture(species: String, quantity: int, total: int, day: int) -> void:
	if busy or not Aquaculture.busy or day!=GameClock.day or not Aquaculture.data.species.has(species) or quantity<1 or total<=int(state.tracking.aquaculture.get(species,0)) or total!=int(Aquaculture.state.harvested.get(species,0)): return
	busy=true;state.tracking.aquaculture[species]=total;note("fish_"+species,quantity,day);commit()
func on_animal(id: String, item: String, day: int) -> void:
	if busy or not Livestock.busy or item not in ["egg","milk","wool"] or day<1 or day>GameClock.day or day<=int(state.tracking.animal.get(id,0)): return
	var animal: Dictionary=Livestock.animal(id)
	if animal.is_empty() or animal.product_day!=day or Livestock.data.species[animal.species].product!=item: return
	busy=true;state.tracking.animal[id]=day;note(item,1,day);commit()
func on_cooking(recipe: String, batches: int, total: int, day: int) -> void:
	if busy or not Kitchen.busy or recipe not in Kitchen.RECIPES or batches<1 or day!=GameClock.day or total<=int(state.tracking.cooking.get(recipe,0)) or total!=int(Kitchen.state.cooked.get(recipe,0)): return
	busy=true;state.tracking.cooking[recipe]=total
	for item in Kitchen.data.recipes[recipe].rewards: note(item,int(Kitchen.data.recipes[recipe].rewards[item])*batches,day)
	commit()
func on_processing(source: String, recipe: String, job_id: int, batches: int) -> void:
	if busy or source!="kitchen" or not Kitchen.busy or recipe not in Kitchen.PROCESSING or batches<1 or job_id in state.tracking.jobs or job_id not in Kitchen.state.claimed: return
	busy=true;state.tracking.jobs.append(job_id)
	if state.tracking.jobs.size()>128: state.tracking.jobs.pop_front()
	if not state.order.is_empty() and job_id>=int(state.order.min_job):
		for item in Kitchen.data.processing[recipe].rewards: note(item,int(Kitchen.data.processing[recipe].rewards[item])*batches,GameClock.day)
	commit()
func whole(value: Variant, low: int, high: int) -> bool: return FarmSaveSchema.whole(value,low,high)
func validate(raw: Variant, day: int) -> bool:
	if not whole(day,1,999999) or not AquacultureSaveSchema.exact(raw,defaults(day).keys()): return false
	for id in TYPES:
		if not whole(raw[id],0,2): return false
	if not AquacultureSaveSchema.exact(raw.build_days,TYPES) or not raw.parcels is Dictionary or raw.parcels.size()>2 or not AquacultureSaveSchema.unique(raw.parcel_claimed,TYPES): return false
	for id in TYPES:
		if not raw.build_days[id] is Array or raw.build_days[id].size()!=int(raw[id]): return false
		var previous := 0
		for built_day in raw.build_days[id]:
			if not whole(built_day,1,day) or int(built_day)<previous: return false
			previous=int(built_day)
		if raw[id]==0 and (id in raw.parcel_claimed or raw.parcels.has(id)): return false
		if raw[id]>0 and (id in raw.parcel_claimed)==raw.parcels.has(id): return false
	for id in raw.parcels:
		var parcel: Variant=raw.parcels[id]
		if id not in TYPES or not AquacultureSaveSchema.exact(parcel,["direction","items"]) or not data.branches.has(parcel.direction) or not parcel.items is Dictionary: return false
		if AbyssSaveSchema.canonical(parcel.items)!=data.branches[parcel.direction][id]: return false
	for key in ["trade_day","community_day","supper_day"]:
		if not whole(raw[key],0,day): return false
	if not whole(raw.trade_count,0,333333) or not whole(raw.community_count,0,day) or not whole(raw.supper_count,0,int(day/7)+1): return false
	if (raw.trade_count==0)!=(raw.trade_day==0) or (raw.community_count==0)!=(raw.community_day==0) or (raw.supper_count==0)!=(raw.supper_day==0): return false
	if raw.supper_count>raw.community_count or raw.supper_day>raw.community_day: return false
	if raw.dock==2 and raw.trade_count<1 or raw.community==2 and raw.community_count<1: return false
	if raw.trade_count>0 and raw.dock<1 or raw.community_count>0 and raw.community<1 or raw.supper_count>0 and raw.community<2: return false
	if not AquacultureSaveSchema.exact(raw.lamps,LAMPS): return false
	for id in LAMPS:
		if not whole(raw.lamps[id],0,day) or (raw.community==0 and raw.lamps[id]!=0): return false
		if raw.community_count>0 and raw.lamps[id]<raw.community_day: return false
	if not raw.order is Dictionary: return false
	if not raw.order.is_empty():
		if not AquacultureSaveSchema.exact(raw.order,["id","started","min_fish","min_job","credit"]) or not data.orders.has(raw.order.id) or not whole(raw.order.started,1,day) or raw.dock<int(data.orders[raw.order.id].level): return false
		if not whole(raw.order.min_fish,1,day*12+1) or not whole(raw.order.min_job,1,999999) or not raw.order.credit is Dictionary: return false
		var required: Dictionary=data.orders[raw.order.id].required
		if raw.order.credit.size()>required.size(): return false
		for item in raw.order.credit:
			if not required.has(item) or not whole(raw.order.credit[item],1,int(required[item])): return false
	var tracking: Variant=raw.tracking
	if not AquacultureSaveSchema.exact(tracking,["farm","fishing","aquaculture","animal","cooking","jobs"]) or not whole(tracking.fishing,0,day*12): return false
	if not tracking.farm is Dictionary or tracking.farm.size()>1536 or not tracking.aquaculture is Dictionary or tracking.aquaculture.size()>6 or not tracking.animal is Dictionary or tracking.animal.size()>999999 or not tracking.cooking is Dictionary or tracking.cooking.size()>Kitchen.RECIPES.size() or not tracking.jobs is Array or tracking.jobs.size()>128: return false
	for id in tracking.farm:
		if not id is String: return false
		var coords: PackedStringArray=id.split(",")
		if coords.size()!=2 or not coords[0].is_valid_int() or not coords[1].is_valid_int() or id!="%d,%d" % [int(coords[0]),int(coords[1])] or not Rect2i(0,0,48,32).has_point(Vector2i(int(coords[0]),int(coords[1]))) or not whole(tracking.farm[id],1,day): return false
	for id in tracking.aquaculture:
		if not Aquaculture.data.species.has(id) or not whole(tracking.aquaculture[id],1,999999): return false
	for id in tracking.animal:
		if not id is String or not id.begins_with("animal_") or not id.trim_prefix("animal_").is_valid_int() or not whole(tracking.animal[id],1,day): return false
	for id in tracking.cooking:
		if id not in Kitchen.RECIPES or not whole(tracking.cooking[id],1,999999): return false
	var jobs := {}
	for id in tracking.jobs:
		if not whole(id,1,999998) or jobs.has(int(id)): return false
		jobs[int(id)]=true
	return true
