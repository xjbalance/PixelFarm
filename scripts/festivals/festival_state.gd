extends Node
## 四季活动订阅成功事务的事实；读档不补产物，活动本身从不跳时间或替玩家生产。
signal changed
const IDS := ["spring","summer","autumn","winter"]
const PEOPLE := ["linya","zhou","ahe","xiaojing"]
const MAX_CLAIMS: int = 35716
var data: Dictionary = {}
var state: Dictionary = {}
var game: Node
var busy: bool = false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/festivals/festivals.json")))
	state=defaults()
	Events.farm_committed.connect(on_farm)
	Events.fishing_landed.connect(on_fishing)
	Events.aquaculture_harvested.connect(on_aquaculture)
	Events.animal_produced.connect(on_animal)
	Events.dish_cooked.connect(on_cooking)
	GameClock.changed.connect(refresh_time)
	GameClock.day_ending.connect(func(_reason: String): check_spring())

func defaults(day: int = GameClock.day) -> Dictionary:
	return {"runs":{},"claims":[],"purchases":{},"production":{"season":Calendar.season_serial(day),"items":{}},
		"tracking":{"farm":{},"fishing":0,"aquaculture":{},"animal":{},"cooking":{}},"xiaojing_summer":false}

func bind(owner_game: Node) -> void:
	game=owner_game
	game.farm.changed.connect(check_spring)

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit()

func key(id: String, year: int = Calendar.year()) -> String:
	return "%d:%s" % [year,id]

func active_id(day: int = GameClock.day) -> String:
	for id in IDS:
		var event: Dictionary=data.events[id]
		if Calendar.season(day)==int(event.season) and Calendar.day_of_season(day)==int(event.season_day): return id
	return ""

func is_open(id: String) -> bool:
	if id not in IDS or active_id()!=id or GameClock.settling: return false
	var event: Dictionary=data.events[id]
	return GameClock.minutes>=float(event.opens) and GameClock.minutes<float(event.closes)

func run_for(id: String) -> Dictionary:
	return state.runs.get(id,{})

func current_run(id: String) -> bool:
	var run := run_for(id)
	return not run.is_empty() and int(run.day)==GameClock.day and int(run.year)==Calendar.year()

func near_board(id: String) -> bool:
	if id not in IDS or not is_instance_valid(game): return false
	var event: Dictionary=data.events[id]
	return GameState.location==event.area and game.player.global_position.distance_to(Vector2(event.board[0],event.board[1]))<=54

func person_near(person: String) -> bool:
	if person not in PEOPLE or not is_instance_valid(game): return false
	for npc in get_tree().get_nodes_in_group("interactables"):
		if "person_id" in npc and npc.person_id==person and npc.is_visible_in_tree() and game.player.global_position.distance_to(npc.global_position)<=76:
			return game.auto_move!=null and game.auto_move.navigation.line_of_sight(game.player.global_position,npc.global_position,npc)
	return false

func _exchange(required: Dictionary, rewards: Dictionary, coins: int = 0) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins): busy=false;return false
	return true

func commit() -> void:
	changed.emit();Events.progress_committed.emit();busy=false

func begin(id: String) -> bool:
	if busy or not is_open(id) or not near_board(id) or key(id) in state.claims: return false
	var old := run_for(id)
	if not old.is_empty() and (old.year==Calendar.year() or (old.ready and key(id,int(old.year)) not in state.claims)): return false
	var cells: Array=[]
	if id=="spring":
		for y in range(game.farm.BOUNDS.position.y,game.farm.BOUNDS.end.y):
			for x in range(game.farm.BOUNDS.position.x,game.farm.BOUNDS.end.x):
				var cell := Vector2i(x,y)
				var plot: Dictionary=game.farm.plots.get(game.farm.key(cell),{})
				if str(plot.get("crop",""))=="": cells.append([x,y])
				if cells.size()==3: break
			if cells.size()==3: break
		if cells.size()!=3:
			Events.notice.emit("先在原农田收出三格空地再报名。现有作物与材料都已保留。")
			return false
	busy=true
	state.runs[id]={"year":Calendar.year(),"day":GameClock.day,"ready":false,"claimed":false,"cells":cells,"sown":{},"watered":[],"fish":[],"talks":[],"lantern":"","exhibit":{},"score":0,"cooked":0,"delivered":[]}
	commit();return true

func restart_spring() -> bool:
	if busy or not is_open("spring") or not near_board("spring") or not current_run("spring"): return false
	var previous := run_for("spring").duplicate(true)
	if previous.ready or previous.claimed: return false
	state.runs.erase("spring")
	if begin("spring"): return true
	state.runs.spring=previous
	return false

func check_spring() -> void:
	if busy or not is_instance_valid(game) or not current_run("spring") or not is_open("spring"): return
	var run := run_for("spring")
	if run.ready or run.claimed or run.sown.size()!=3: return
	var watered: Array=[]
	var varieties := {}
	for cell in run.cells:
		var id := "%d,%d" % [int(cell[0]),int(cell[1])]
		if not run.sown.has(id): return
		var crop: String=run.sown[id]
		var plot: Dictionary=game.farm.plots.get(id,{})
		if plot.get("crop","")!=crop: return
		varieties[crop]=true
		if bool(plot.get("watered",false)): watered.append(id)
	var changed_water: bool=run.watered!=watered
	run.watered=watered
	if watered.size()==3 and varieties.size()>=2: run.ready=true
	if changed_water or run.ready: busy=true;commit()

func _record_production(item: String, amount: int, day: int) -> void:
	if amount<1 or day<1 or day>GameClock.day or item_family(item)=="": return
	var serial: int=Calendar.season_serial(day)
	if serial<int(state.production.season): return
	if serial>int(state.production.season): state.production={"season":serial,"items":{}}
	state.production.items[item]=mini(999999,int(state.production.items.get(item,0))+amount)

func on_farm(kind: String, cell: Vector2i, crop: String, serial: int) -> void:
	if busy or not is_instance_valid(game) or GameState.location!="farm" or not Catalog.crops.has(crop) or kind not in ["播种","浇水","收获"]: return
	if serial<0 or serial!=int(Xiaojing.state.plant_serial): return
	var id := "%d,%d" % [cell.x,cell.y]
	if not game.farm.BOUNDS.has_point(cell): return
	var proof := "%s:%s" % [kind,id]
	var token := "%d:%d" % [GameClock.day,serial]
	if state.tracking.farm.get(proof,"")==token: return
	busy=true;state.tracking.farm[proof]=token
	if kind=="收获": _record_production(crop,1,GameClock.day)
	if kind=="播种" and current_run("spring") and is_open("spring"):
		var run := run_for("spring")
		if not run.ready and [cell.x,cell.y] in run.cells and not run.sown.has(id): run.sown[id]=crop
	commit();check_spring()

func on_fishing(site: String, species: String, serial: int, day: int) -> void:
	if busy or day!=GameClock.day or serial<=int(state.tracking.fishing) or serial!=int(Fishing.state.serial) or Fishing.state.pending!=species: return
	if not Fishing.sites.has(site) or not Fishing.data.species.has(species): return
	busy=true;state.tracking.fishing=serial
	_record_production(str(Fishing.data.species[species].item),1,day)
	if current_run("summer") and is_open("summer") and Fishing.sites[site].habitat=="lake":
		var run := run_for("summer")
		if not run.ready and run.fish.size()<2 and serial not in run.fish: run.fish.append(serial)
	commit();check_summer()

func on_aquaculture(species: String, quantity: int, total: int, day: int) -> void:
	if busy or day!=GameClock.day or not Aquaculture.data.species.has(species) or quantity<1 or total<=int(state.tracking.aquaculture.get(species,0)): return
	if total!=int(Aquaculture.state.harvested.get(species,0)): return
	busy=true;state.tracking.aquaculture[species]=total
	_record_production("fish_"+species,quantity,day);commit()

func on_animal(animal_id: String, item: String, day: int) -> void:
	if busy or item not in ["egg","milk","wool"] or day>GameClock.day or day<1 or day<=int(state.tracking.animal.get(animal_id,0)): return
	var animal: Dictionary=Livestock.animal(animal_id)
	if animal.is_empty() or animal.product_day!=day or Livestock.data.species[animal.species].product!=item: return
	busy=true;state.tracking.animal[animal_id]=day
	_record_production(item,1,day);commit()

func on_cooking(recipe: String, batches: int, total: int, day: int) -> void:
	if busy or recipe not in Kitchen.RECIPES or batches<1 or day!=GameClock.day or total<=int(state.tracking.cooking.get(recipe,0)): return
	if total!=int(Kitchen.state.cooked.get(recipe,0)): return
	busy=true;state.tracking.cooking[recipe]=total
	if recipe=="carrot_stew" and current_run("winter") and is_open("winter"):
		var run := run_for("winter")
		if not run.ready: run.cooked=mini(3,int(run.cooked)+batches)
	commit()

func talk(person: String) -> bool:
	var id := active_id()
	if busy or id=="" or not is_open(id) or not current_run(id) or not person_near(person): return false
	var run := run_for(id)
	if person in run.talks: return false
	busy=true;run.talks.append(person)
	Events.notice.emit(daily_line(person));commit();check_summer();return true

func daily_line(person: String) -> String:
	var id := active_id()
	return str(data.talks[id].get(person,"")) if id!="" else ""

func watch_lantern(choice: String) -> bool:
	if busy or not is_open("summer") or not near_board("summer") or not current_run("summer") or GameClock.minutes<1200 or not data.lanterns.has(choice): return false
	var run := run_for("summer")
	if run.lantern!="" or run.fish.size()<2: return false
	busy=true;run.lantern=choice
	Events.notice.emit(data.lanterns[choice].text);commit();check_summer();return true

func check_summer() -> void:
	if busy or not current_run("summer") or not is_open("summer"): return
	var run := run_for("summer")
	if run.ready or run.claimed: return
	var villagers := 0
	for person in run.talks:
		if person in ["linya","zhou","ahe"]: villagers+=1
	if run.fish.size()>=2 and villagers>=2 and run.lantern!="": busy=true;run.ready=true;commit()

func summer_xiaojing() -> bool:
	if busy or not current_run("summer") or not is_open("summer") or not near_board("summer") or GameClock.minutes<1200 or state.xiaojing_summer or not Xiaojing.state.unlocked or Xiaojing.state.affection<50 or not person_near("xiaojing"): return false
	var run := run_for("summer")
	if run.fish.size()<2 or run.lantern=="": return false
	busy=true;state.xiaojing_summer=true
	Xiaojing.boost(0,0,1,"summer_lantern_once")
	Xiaojing.changed.emit()
	Events.notice.emit("小京把灯沿着岸边转过半圈：这样不会把水草照得太亮。明年的水样由我来记，你若有空，再来钓一会儿。羁绊+1，只记录一次。")
	commit();return true

func item_family(item: String) -> String:
	if Catalog.crops.has(item): return "crop"
	if item.begins_with("fish_") and item!="fish_eternal" and Aquaculture.data.species.has(item.trim_prefix("fish_")): return "fish"
	if item in ["egg","milk","wool"]: return "animal"
	return ""

func submit_autumn(required: Dictionary) -> bool:
	if busy or not is_open("autumn") or not current_run("autumn") or not near_board("autumn") or required.is_empty() or required.size()>6: return false
	var run := run_for("autumn")
	if run.ready or not run.exhibit.is_empty() or int(state.production.season)!=Calendar.season_serial(): return false
	var quantity := 0;var families := {}
	for item in required:
		if not item is String or item_family(item)=="" or not whole(required[item],1,2): return false
		if int(state.production.items.get(item,0))<int(required[item]): return false
		quantity+=int(required[item]);families[item_family(item)]=true
	if quantity<3 or quantity>6 or families.size()<2: return false
	if not _exchange(required,{}): return false
	run.exhibit=required.duplicate(true)
	run.score=families.size()*20+required.size()*5+quantity*3
	run.ready=true
	for item in required: state.production.items[item]-=int(required[item])
	commit();return true

func deliver_winter(person: String) -> bool:
	if busy or not is_open("winter") or not current_run("winter") or person not in ["linya","zhou","ahe"] or not person_near(person): return false
	var run := run_for("winter")
	if run.ready or person in run.delivered or run.cooked<=run.delivered.size(): return false
	if not _exchange({"carrot_stew":1},{}): return false
	run.delivered.append(person)
	if person not in run.talks: run.talks.append(person)
	if run.delivered.size()==3: run.ready=true
	Events.notice.emit(data.talks.winter[person]);commit();return true

func reward(id: String) -> Dictionary:
	var result: Dictionary=data.events[id].reward.duplicate(true)
	if id=="autumn":
		var score: int=int(run_for(id).get("score",0))
		result.coins+=30 if score>=80 else (15 if score>=60 else 0)
		if score>=80: result.items.wheat_seed=3
	return result

func claim(id: String) -> bool:
	if busy or id not in IDS or not near_board(id): return false
	var run := run_for(id)
	if run.is_empty() or not run.ready or run.claimed or key(id,int(run.year)) in state.claims: return false
	var gain := reward(id)
	if not _exchange({},gain.items,int(gain.coins)): return false
	run.claimed=true;state.claims.append(key(id,int(run.year)))
	Events.notice.emit("%s的纪念已收好。活动奖励一年一次，日期和原剧情继续照常。" % data.events[id].name)
	commit();return true

func shop_entry(id: String, item: String) -> Dictionary:
	if id not in IDS: return {}
	for offer in data.shops[id]:
		if offer.item==item: return offer
	return {}

func shop_unlocked(offer: Dictionary) -> bool:
	if offer.is_empty(): return false
	if offer.unlock=="basic": return true
	if offer.unlock in Kitchen.FACILITIES: return offer.unlock in Kitchen.state.built
	return Kitchen.recipe_unlocked(offer.unlock)

func shop(item: String, quantity: int = 1) -> bool:
	var id := active_id()
	if busy or id=="" or not is_open(id) or not near_board(id) or not whole(quantity,1,12): return false
	var offer := shop_entry(id,item)
	if not shop_unlocked(offer): return false
	var record_key := key(id)
	var bought: Dictionary=state.purchases.get(record_key,{})
	if int(bought.get(item,0))+quantity>int(offer.limit): return false
	if not _exchange({},{item:quantity},-int(offer.price)*quantity): return false
	bought[item]=int(bought.get(item,0))+quantity;state.purchases[record_key]=bought
	commit();return true

func refresh_time() -> void:
	changed.emit()

func whole(value: Variant, low: int, high: int) -> bool:
	return FarmSaveSchema.whole(value,low,high)

func valid_key(value: Variant, max_year: int) -> bool:
	if not value is String: return false
	var parts: PackedStringArray=value.split(":")
	if parts.size()!=2 or not parts[0].is_valid_int() or not whole(int(parts[0]),1,max_year) or parts[1] not in IDS or value!="%d:%s" % [int(parts[0]),parts[1]]: return false
	return true

func validate(raw: Variant, day: int) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults(day).keys()) or not whole(day,1,999999): return false
	if not raw.xiaojing_summer is bool or not raw.runs is Dictionary or raw.runs.size()>4: return false
	if not raw.claims is Array or raw.claims.size()>MAX_CLAIMS or not raw.purchases is Dictionary or raw.purchases.size()>MAX_CLAIMS: return false
	var known := {}
	for event_key in raw.claims:
		if not valid_key(event_key,Calendar.year(day)) or known.has(event_key): return false
		known[event_key]=true
	for event_key in raw.purchases:
		if not valid_key(event_key,Calendar.year(day)) or not raw.purchases[event_key] is Dictionary: return false
		var id: String=event_key.split(":")[1]
		for item in raw.purchases[event_key]:
			var offer := shop_entry(id,item)
			if offer.is_empty() or not whole(raw.purchases[event_key][item],1,int(offer.limit)): return false
	for id in raw.runs:
		if id not in IDS or not valid_run(raw.runs[id],id,day,raw.claims): return false
	var production: Variant=raw.production
	if not AquacultureSaveSchema.exact(production,["season","items"]) or not whole(production.season,0,Calendar.season_serial(day)) or not production.items is Dictionary or production.items.size()>12: return false
	for item in production.items:
		if item_family(item)=="" or not whole(production.items[item],0,999999): return false
	var tracking: Variant=raw.tracking
	if not AquacultureSaveSchema.exact(tracking,["farm","fishing","aquaculture","animal","cooking"]): return false
	if not whole(tracking.fishing,0,day*12): return false
	if not tracking.farm is Dictionary or tracking.farm.size()>180: return false
	for proof in tracking.farm:
		if not proof is String or proof.split(":").size()!=2: return false
		var parts: PackedStringArray=proof.split(":")
		if parts[0] not in ["播种","浇水","收获"]: return false
		var coords: PackedStringArray=parts[1].split(",")
		if coords.size()!=2 or not coords[0].is_valid_int() or not coords[1].is_valid_int() or not Rect2i(17,16,10,6).has_point(Vector2i(int(coords[0]),int(coords[1]))): return false
		var token: Variant=tracking.farm[proof]
		if not token is String or token.split(":").size()!=2: return false
		var values: PackedStringArray=token.split(":")
		if not values[0].is_valid_int() or not values[1].is_valid_int() or not whole(int(values[0]),1,day) or not whole(int(values[1]),0,999999999): return false
	for group in ["aquaculture","animal","cooking"]:
		if not tracking[group] is Dictionary: return false
	if tracking.aquaculture.size()>6 or tracking.animal.size()>999999 or tracking.cooking.size()>Kitchen.RECIPES.size(): return false
	for id in tracking.aquaculture:
		if not Aquaculture.data.species.has(id) or not whole(tracking.aquaculture[id],1,999999): return false
	for id in tracking.animal:
		if not id is String or not id.begins_with("animal_") or not id.trim_prefix("animal_").is_valid_int() or not whole(tracking.animal[id],1,day): return false
	for id in tracking.cooking:
		if id not in Kitchen.RECIPES or not whole(tracking.cooking[id],1,999999): return false
	return true

func valid_run(run: Variant, id: String, day: int, claims: Array) -> bool:
	if not AquacultureSaveSchema.exact(run,["year","day","ready","claimed","cells","sown","watered","fish","talks","lantern","exhibit","score","cooked","delivered"]): return false
	if not whole(run.year,1,Calendar.year(day)) or not whole(run.day,1,day) or Calendar.year(int(run.day))!=run.year or active_id(int(run.day))!=id: return false
	if not run.ready is bool or not run.claimed is bool or (run.claimed and not run.ready) or run.claimed!=(key(id,int(run.year)) in claims): return false
	if not run.cells is Array or run.cells.size()>(3 if id=="spring" else 0) or not run.sown is Dictionary or run.sown.size()>3 or not run.watered is Array or run.watered.size()>3: return false
	var cell_ids: Array[String]=[]
	for cell in run.cells:
		if not cell is Array or cell.size()!=2 or not whole(cell[0],17,26) or not whole(cell[1],16,21): return false
		var cell_id := "%d,%d" % [int(cell[0]),int(cell[1])]
		if cell_id in cell_ids: return false
		cell_ids.append(cell_id)
	for cell_id in run.sown:
		if cell_id not in cell_ids or not Catalog.crops.has(run.sown[cell_id]): return false
	var known := {}
	for cell_id in run.watered:
		if cell_id not in cell_ids or known.has(cell_id): return false
		known[cell_id]=true
	if not run.fish is Array or run.fish.size()>2 or not AquacultureSaveSchema.unique(run.talks,PEOPLE) or not AquacultureSaveSchema.unique(run.delivered,["linya","zhou","ahe"]): return false
	known.clear()
	for serial in run.fish:
		if not whole(serial,1,day*12) or known.has(int(serial)): return false
		known[int(serial)]=true
	if not run.lantern is String or (run.lantern!="" and not data.lanterns.has(run.lantern)) or not run.exhibit is Dictionary or run.exhibit.size()>6 or not whole(run.score,0,108) or not whole(run.cooked,0,3): return false
	var amount := 0;var families := {}
	for item in run.exhibit:
		if item_family(item)=="" or not whole(run.exhibit[item],1,2): return false
		amount+=int(run.exhibit[item]);families[item_family(item)]=true
	if id=="spring":
		if run.cells.size()!=3 or not run.fish.is_empty() or run.lantern!="" or not run.exhibit.is_empty() or run.score!=0 or run.cooked!=0 or not run.delivered.is_empty(): return false
		if run.ready and (run.sown.size()!=3 or run.watered.size()!=3): return false
		if run.ready:
			var kinds := {}
			for crop in run.sown.values(): kinds[crop]=true
			if kinds.size()<2: return false
	elif id=="summer":
		if not run.sown.is_empty() or not run.watered.is_empty() or not run.exhibit.is_empty() or run.score!=0 or run.cooked!=0 or not run.delivered.is_empty(): return false
		var people := 0
		for person in run.talks:
			if person!="xiaojing": people+=1
		if run.ready and (run.fish.size()!=2 or people<2 or run.lantern==""): return false
	elif id=="autumn":
		if not run.sown.is_empty() or not run.watered.is_empty() or not run.fish.is_empty() or run.lantern!="" or run.cooked!=0 or not run.delivered.is_empty(): return false
		if run.ready and (amount<3 or amount>6 or families.size()<2 or run.score!=families.size()*20+run.exhibit.size()*5+amount*3): return false
		if not run.ready and (not run.exhibit.is_empty() or run.score!=0): return false
	elif id=="winter":
		if not run.sown.is_empty() or not run.watered.is_empty() or not run.fish.is_empty() or run.lantern!="" or not run.exhibit.is_empty() or run.score!=0: return false
		if run.delivered.size()>run.cooked or (run.ready and run.delivered.size()!=3): return false
	return true

func progress(id: String) -> String:
	var run := run_for(id)
	if run.is_empty(): return "尚未报名"
	if run.claimed: return "第%d年纪念已领取" % int(run.year)
	if run.ready: return "活动已完成，纪念待领取（满包时保留）"
	match id:
		"spring": return "亲手播种%d/3格 · 照料%d/3格 · 至少两种作物" % [run.sown.size(),run.watered.size()]
		"summer": return "新钓获%d/2尾 · 节日交流%d人 · %s" % [run.fish.size(),run.talks.size(),"灯已点亮" if run.lantern!="" else "20:00后回湖岸选灯"]
		"autumn": return "展篮尚未提交；需要本季真实新产证明，至少两类、3至6份"
		"winter": return "报名后新做暖锅%d/3份 · 亲手送达%d/3位村民" % [run.cooked,run.delivered.size()]
	return ""

func next_date(day: int = GameClock.day) -> Dictionary:
	for offset in range(0,113):
		var id := active_id(day+offset)
		if id!="": return {"id":id,"day":day+offset,"name":data.events[id].name}
	return {}
