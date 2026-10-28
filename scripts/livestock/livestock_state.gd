extends Node
## 畜牧只通过此状态层扣料和结算；可见动物和面板都是原系统的请求端。
signal changed
const SITES := {"coop":Vector2(176,880),"barn":Vector2(400,912),"fold":Vector2(816,912)}
const CAPACITY := [0,2,4,6]
const INDOOR := [Vector2(-40,-16),Vector2(-8,-16),Vector2(24,-16),Vector2(-40,16),Vector2(-8,16),Vector2(24,16)]
const PASTURE := [Vector2(-88,-40),Vector2(88,-40),Vector2(96,-8),Vector2(-96,-8),Vector2(-88,16),Vector2(88,16)]
var data: Dictionary = {}
var state: Dictionary = {}
var game: Node
var busy: bool = false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/livestock/livestock.json")))
	state=defaults(GameClock.day)
	GameClock.day_advanced.connect(settle_day)

func defaults(day: int = GameClock.day) -> Dictionary:
	var buildings := {}
	for site in SITES: buildings[site]={"level":0,"last_breed_day":0,"grazing_day":0}
	return {"buildings":buildings,"animals":[],"serial":0,"last_settled_day":day}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true)
	busy=false
	changed.emit()
	Events.navigation_changed.emit()

func building(site: String) -> Dictionary:
	return state.buildings.get(site,{})

func animal(id: String) -> Dictionary:
	for entry in state.animals:
		if entry.id==id: return entry
	return {}

func animals_at(site: String) -> Array:
	var result: Array=[]
	for entry in state.animals:
		if entry.site==site: result.append(entry)
	return result

func summary(site: String) -> Dictionary:
	if not SITES.has(site): return {}
	var occupants := animals_at(site)
	var adults := 0
	var products := 0
	for entry in occupants:
		if is_adult(entry): adults+=1
		products+=int(entry.product)
	return {"count":occupants.size(),"adults":adults,"products":products,"capacity":CAPACITY[int(building(site).level)]}

func is_adult(entry: Dictionary) -> bool:
	return not entry.is_empty() and int(entry.age)>=int(data.species[entry.species].growth_days)

func display_name(id: String) -> String:
	var entry := animal(id)
	if entry.is_empty(): return "动物"
	var definition: Dictionary=data.species[entry.species]
	return str(definition.name if is_adult(entry) else definition.young_name)+"%d号" % int(id.trim_prefix("animal_"))

func site_point(site: String) -> Vector2: return FarmLayout.point(site) if SITES.has(site) else Vector2.INF
func animal_point(entry: Dictionary) -> Vector2:
	return FarmLayout.transform_point(Vector2(entry.position[0],entry.position[1]),str(entry.site)) if not entry.is_empty() else Vector2.INF
func near_site(site: String) -> bool:
	return SITES.has(site) and FarmLayout.active(site) and is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(site_point(site))<=54

func near_animal(id: String) -> bool:
	var entry := animal(id)
	return not entry.is_empty() and FarmLayout.active(str(entry.site)) and is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(animal_point(entry))<=54

func near_any() -> bool:
	for site in SITES:
		if near_site(site): return true
	return false

func _exchange(required: Dictionary, rewards: Dictionary, coins: int) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins):
		busy=false
		Events.notice.emit("饲料、材料、余额或背包空间不足；畜牧状态已保留。")
		return false
	return true

func _commit(navigation: bool = false) -> void:
	changed.emit()
	if navigation: Events.navigation_changed.emit()
	Events.progress_committed.emit()
	busy=false

func build(site: String) -> bool:
	if busy or not near_site(site) or int(building(site).level)>0: return false
	var definition: Dictionary=data.buildings[site]
	if not _exchange(definition.required,{},-int(definition.coins)): return false
	building(site).level=1
	Events.notice.emit(definition.name+"安好了。先买少量幼畜，每天留好饲料。")
	_commit(true)
	return true

func upgrade(site: String) -> bool:
	if busy or not near_site(site) or int(building(site).level) not in [1,2]: return false
	var next_level: int=int(building(site).level)+1
	var definition: Dictionary=data.upgrades[str(next_level)]
	if not _exchange(definition.required,{},-int(definition.coins)): return false
	building(site).level=next_level
	Events.notice.emit("畜舍扩容，原有动物、产物和成长进度全部保留。")
	_commit(true)
	return true

func _new_animal(site: String) -> Dictionary:
	state.serial+=1
	var index: int=animals_at(site).size()
	var at: Vector2=SITES[site]+INDOOR[index]
	var result := {"id":"animal_%06d" % int(state.serial),"site":site,"species":str(data.buildings[site].species),"age":0,"hunger":40,"mood":60,"bond":0,
		"fed_day":0,"pet_day":0,"product":0,"product_day":0,"progress":0,"position":[at.x,at.y]}
	state.animals.append(result)
	return result

func buy_animal(site: String) -> bool:
	if busy or not near_site(site) or int(building(site).level)<1 or state.serial>=999999: return false
	if int(summary(site).count)>=int(summary(site).capacity):
		Events.notice.emit("畜舍已经住满了，请先扩建。")
		return false
	var species: String=data.buildings[site].species
	if not _exchange({}, {},-int(data.species[species].price)): return false
	_new_animal(site)
	_commit()
	return true

func buy_hay(quantity: int) -> bool:
	if busy or not near_any() or quantity<1 or quantity>99: return false
	if not _exchange({},{"hay":quantity},-int(data.items.hay.price)*quantity): return false
	_commit()
	return true

func make_hay(batches: int = 1) -> bool:
	if busy or not near_any() or batches<1 or batches>99: return false
	var has_building := false
	for site in SITES:
		if near_site(site) and int(building(site).level)>0: has_building=true
	if not has_building or not _exchange({"wheat":batches},{"hay":batches*5},0): return false
	_commit()
	return true

func feed(id: String) -> bool:
	var entry := animal(id)
	if busy or not near_animal(id) or int(entry.fed_day)>=GameClock.day: return false
	var needed: int=int(data.species[entry.species].feed)
	if not _exchange({"hay":needed},{},0): return false
	entry.fed_day=GameClock.day
	entry.hunger=maxi(0,int(entry.hunger)-60)
	entry.mood=mini(100,int(entry.mood)+4)
	entry.bond=mini(100,int(entry.bond)+1)
	Events.notice.emit("今天的饲料已备好，成长和产物在次日统一结算。")
	_commit()
	return true

func pet(id: String) -> bool:
	var entry := animal(id)
	if busy or GameClock.settling or not near_animal(id) or int(entry.pet_day)>=GameClock.day: return false
	busy=true
	if not GameState.spend_energy(1): busy=false;return false
	entry.pet_day=GameClock.day
	entry.mood=mini(100,int(entry.mood)+7)
	entry.bond=mini(100,int(entry.bond)+2)
	_commit()
	return true

func collect(id: String) -> bool:
	var entry := animal(id)
	if busy or not near_animal(id) or int(entry.product)<1: return false
	var item: String=data.species[entry.species].product
	var quantity: int=int(entry.product)
	if not _exchange({},{item:quantity},0): return false
	entry.product=0
	Events.notice.emit("收集%s ×%d。未领取的产物最多暂存三份。" % [Catalog.item_name(item),quantity])
	_commit()
	return true

func can_graze(site: String) -> bool:
	return SITES.has(site) and int(building(site).level)>0 and not animals_at(site).is_empty() and Calendar.season()!=3 and GameWeather.weather_id() in ["clear","cloudy","meteor"] and GameClock.minutes>=480 and GameClock.minutes<=840

func is_grazing(site: String) -> bool:
	return SITES.has(site) and int(building(site).grazing_day)==GameClock.day and Calendar.season()!=3 and GameWeather.weather_id() in ["clear","cloudy","meteor"] and GameClock.minutes<1080

func graze(site: String) -> bool:
	if busy or GameClock.settling or not near_site(site) or not can_graze(site) or int(building(site).grazing_day)==GameClock.day: return false
	busy=true
	building(site).grazing_day=GameClock.day
	Events.notice.emit("栏门打开了。动物在庭院吃草，雨雪或傍晚会自动回到门廊。冬季请备干草。")
	_commit()
	return true

func breed(site: String) -> bool:
	if busy or not near_site(site) or int(building(site).level)<1 or state.serial>=999999: return false
	if int(summary(site).count)>=int(summary(site).capacity): return false
	var definition: Dictionary=data.species[data.buildings[site].species]
	if int(building(site).last_breed_day)>0 and GameClock.day-int(building(site).last_breed_day)<int(definition.breed_days): return false
	var parents := 0
	for entry in animals_at(site):
		if is_adult(entry) and int(entry.bond)>=35 and int(entry.mood)>=60 and int(entry.fed_day)==GameClock.day: parents+=1
	if parents<2:
		Events.notice.emit("至少两只成年动物需要亲密35、心情60并在今天喂好，才能办理繁育。")
		return false
	if not _exchange({"hay":int(definition.breed_hay)},{},-int(definition.breed_coins)): return false
	building(site).last_breed_day=GameClock.day
	_new_animal(site)
	Events.notice.emit("繁育站送来了幼畜。它仍需要独立成长，不会继承成年动物进度。")
	_commit()
	return true

func settle_day() -> void:
	var today: int=GameClock.day
	if busy or today<=int(state.last_settled_day): return
	busy=true
	var yesterday: int=today-1
	for entry in state.animals:
		var species: Dictionary=data.species[entry.species]
		var grazed: bool=int(building(entry.site).grazing_day)==yesterday and Calendar.season(yesterday)!=3 and GameWeather.weather_id(yesterday) in ["clear","cloudy","meteor"]
		var fed: bool=int(entry.fed_day)==yesterday or grazed
		if fed:
			entry.age=mini(int(species.growth_days),int(entry.age)+1)
			entry.hunger=mini(100,15 if grazed else int(entry.hunger)+15)
			entry.mood=mini(100,int(entry.mood)+3)
		else:
			entry.hunger=mini(100,int(entry.hunger)+25)
			entry.mood=maxi(0,int(entry.mood)-5)
		if fed and is_adult(entry) and entry.hunger<=65 and entry.mood>=35 and int(entry.product)<3:
			entry.progress+=1
			if int(entry.progress)>=int(species.cycle):
				entry.product+=1
				entry.progress=0
				entry.product_day=yesterday
				Events.animal_produced.emit(entry.id,str(data.species[entry.species].product),yesterday)
	state.last_settled_day=today
	_commit()

func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

func exact(raw: Variant, keys: Array) -> bool:
	if not raw is Dictionary or raw.size()!=keys.size(): return false
	for key in keys:
		if not raw.has(key): return false
	return true

func validate(raw: Variant, day: int) -> bool:
	if not whole(day,1,999999) or not exact(raw,defaults(day).keys()) or not exact(raw.buildings,SITES.keys()): return false
	if not whole(raw.serial,0,999999) or not whole(raw.last_settled_day,1,day) or not raw.animals is Array or raw.animals.size()>18: return false
	for site in SITES:
		var b: Variant=raw.buildings[site]
		if not exact(b,["level","last_breed_day","grazing_day"]) or not whole(b.level,0,3) or not whole(b.last_breed_day,0,day) or not whole(b.grazing_day,0,day): return false
		if int(b.level)==0 and (b.last_breed_day!=0 or b.grazing_day!=0): return false
	var ids := {}
	var counts := {"coop":0,"barn":0,"fold":0}
	for entry in raw.animals:
		if not exact(entry,["id","site","species","age","hunger","mood","bond","fed_day","pet_day","product","product_day","progress","position"]): return false
		if not entry.id is String or not entry.id.begins_with("animal_") or entry.id.length()!=13 or not entry.id.trim_prefix("animal_").is_valid_int(): return false
		var serial: int=int(entry.id.trim_prefix("animal_"))
		if not whole(serial,1,int(raw.serial)) or entry.id!="animal_%06d" % serial or ids.has(entry.id): return false
		ids[entry.id]=true
		if entry.site not in SITES or entry.species!=data.buildings[entry.site].species: return false
		var definition: Dictionary=data.species[entry.species]
		counts[entry.site]+=1
		if not whole(entry.age,0,int(definition.growth_days)) or not whole(entry.hunger,0,100) or not whole(entry.mood,0,100) or not whole(entry.bond,0,100): return false
		for key in ["fed_day","pet_day","product_day"]:
			if not whole(entry[key],0,day): return false
		if not whole(entry.product,0,3) or not whole(entry.progress,0,int(definition.cycle)-1): return false
		if entry.age<int(definition.growth_days) and (entry.product>0 or entry.progress>0 or entry.product_day>0): return false
		if entry.product>0 and entry.product_day<1: return false
		if not entry.position is Array or entry.position.size()!=2: return false
		for axis in entry.position:
			if not (axis is int or axis is float) or not is_finite(float(axis)): return false
		if not Rect2(SITES[entry.site]+Vector2(-116,-48),Vector2(232,160)).has_point(Vector2(entry.position[0],entry.position[1])): return false
	for site in SITES:
		if int(counts[site])>CAPACITY[int(raw.buildings[site].level)]: return false
	return true
