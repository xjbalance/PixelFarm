extends Node
## 村民个人生活与原主线并存；任务只记录已发生的玩法提交，不代办种植/采集。
signal changed
const PEOPLE := ["linya","zhou","ahe","xiaojing"]
const LAKE := Vector2(944,464)
const COMPANION := Vector2(912,432)
const SITES := {"kitchen":{"area":"home","point":Vector2(880,464)},"tea":{"area":"village","point":Vector2(592,688)},"tea_season":{"area":"village","point":Vector2(592,688)},"cycle":{"area":"farm","point":Vector2(912,688)},"lake_date":{"area":"farm","point":LAKE},"summer_sky":{"area":"farm","point":LAKE},"winter_window":{"area":"farm","point":Vector2(1312,812)},"ecology_after":{"area":"farm","point":Vector2(912,688)},"star_lake":{"area":"farm","point":LAKE}}
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false
var last_clean_day: int=0

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/social/people.json")))
	state=defaults(GameClock.day)
	# 特殊料理仍走原小京赠礼事务与最近礼物限制，不产生第二份每日额度。
	for id in data.people.xiaojing.special_gifts: StarStory.data.gifts[id]=data.people.xiaojing.special_gifts[id].duplicate(true)
	Events.farm_committed.connect(on_farm)
	Events.fishing_landed.connect(on_fish)
	Events.aquaculture_harvested.connect(on_aquaculture)
	Events.dish_cooked.connect(on_cook)
	Events.processing_claimed.connect(on_processing)
	Events.world_inspected.connect(on_inspect)
	Events.berry_gathered.connect(on_berry)
	LakeEcology.changed.connect(observe_clean)
	GameClock.day_advanced.connect(check_dates)
	GameClock.changed.connect(check_dates)

func defaults(_day: int = GameClock.day) -> Dictionary:
	var daily := {}
	for id in PEOPLE: daily[id]={"talk_day":0,"gift_day":0,"birthday_year":0,"gifts":[]}
	return {"friendship":{"linya":0,"zhou":0,"ahe":0},"daily":daily,"active":{},"completed":[],"choices":{}}
func migrate(old: Dictionary) -> Dictionary:
	if not FarmSaveSchema.whole(old.get("day"),1,999999) or not old.get("progress") is Dictionary: return {}
	if not FarmSaveSchema.whole(old.progress.get("friendship"),0,100): return {}
	var result := defaults(int(old.day))
	result.friendship.linya=int(old.progress.friendship)
	return result
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;last_clean_day=int(LakeEcology.state.clean_day);changed.emit()
func commit() -> void:
	changed.emit();Events.progress_committed.emit();busy=false
func person_node(id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("interactables"):
		if "person_id" in node and node.person_id==id and node.is_visible_in_tree(): return node
	return null
func near_person(id: String) -> bool:
	if not is_instance_valid(game) or id not in PEOPLE: return false
	var node := person_node(id)
	return node!=null and node.global_position.distance_to(game.player.global_position)<=76
func friendship(id: String) -> int:
	return int(Xiaojing.state.affection) if id=="xiaojing" else int(state.friendship.get(id,0))
func is_birthday(id: String, day: int = GameClock.day) -> bool:
	return data.people.has(id) and Calendar.season(day)==int(data.people[id].birthday[0]) and Calendar.day_of_season(day)==int(data.people[id].birthday[1])
func taste(id: String, item: String) -> String:
	if item in data.people[id].likes: return "喜欢"
	if item in data.people[id].dislikes: return "不喜欢"
	return "普通"
func daily_line(id: String) -> String:
	if id not in PEOPLE: return ""
	var person: Dictionary=data.people[id]
	var text: String=person.daily[posmod(GameClock.day,person.daily.size())]+"\n"+person.season[Calendar.season()]
	var weather: String="snow" if GameWeather.is_snowy() else ("harsh" if GameWeather.is_harsh() else ("rain" if GameWeather.is_rainy() else ("fog" if GameWeather.weather_id()=="fog" else ("meteor" if GameWeather.is_meteor_night() else "clear"))))
	text+="\n"+str(person.weather[weather])
	if is_birthday(id): text=person.birthday_line+"\n"+text
	var festival := get_node_or_null("/root/Festival")
	if festival and festival.has_method("daily_line") and festival.active_id()!="": text+="\n"+str(festival.daily_line(id))
	if id=="xiaojing" and GameWeather.is_moon_night(): text+="\n今晚的月影边缘很清楚。我想把它记在水样旁，等下次湖水起风时再比一比。"
	if id=="xiaojing" and Xiaojing.state.married:
		text+="\n"+["我把留种用的小碗放在家里了，晚饭后各自写一页计划。","今晚出门看星之前，我会先把自己的水样送回温室。","你忙收成，我去整理档案。回来时给彼此留一杯水。","冬天桌子靠窗会冷，我把两把椅子各挪了一点，过道仍留着。"][Calendar.season()]
	var quest := current(id)
	if not quest.is_empty() and state.active.has(id) and state.active[id].missed: text+="\n上次没见到你。带一份自己新做的饭或新收获再来约，计划可以重新写，不用勉强。"
	for q in data.quests:
		if q.person==id and state.choices.has(q.id): text+="\n上次说好的事还记着："+str(q.choices[state.choices[q.id]])
	return text
func talk(id: String) -> bool:
	if busy or not near_person(id): return false
	if id=="xiaojing": return Xiaojing.talk()
	if state.daily[id].talk_day>=GameClock.day: return false
	busy=true;state.daily[id].talk_day=GameClock.day
	state.friendship[id]=mini(100,int(state.friendship[id])+1)
	for who in state.active: note(who,"talk:"+id,1,"talk:%s:%d" % [id,GameClock.day])
	commit();return true
func gift(id: String, item: String) -> bool:
	if busy or id not in PEOPLE or not near_person(id): return false
	if id=="xiaojing": return Xiaojing.gift(item)
	if state.daily[id].gift_day>=GameClock.day or not Catalog.is_item(item): return false
	busy=true
	if not Inventory.exchange({item:1},{},0): busy=false;return false
	var daily: Dictionary=state.daily[id]
	daily.gift_day=GameClock.day
	var liking := taste(id,item)
	var gain: int=3 if liking=="喜欢" else (-1 if liking=="不喜欢" else 1)
	if item in daily.gifts: gain=mini(0,gain)
	if is_birthday(id) and daily.birthday_year<Calendar.year():
		daily.birthday_year=Calendar.year()
		if gain>0: gain+=2
	daily.gifts.append(item)
	if daily.gifts.size()>3: daily.gifts.pop_front()
	state.friendship[id]=clampi(int(state.friendship[id])+gain,0,100)
	Events.notice.emit(data.people[id].name+"："+("我留在合适的地方，谢谢你记得。" if gain>0 else ("这不是我喜欢的东西，不过下次可以直接问我。" if liking=="不喜欢" else "这份已经有了，先留给你自己的计划吧。")))
	commit();return true
func current(person: String) -> Dictionary:
	for quest in data.quests:
		if quest.person==person and quest.id not in state.completed: return quest
	return {}
func definition(id: String) -> Dictionary:
	for quest in data.quests:
		if quest.id==id: return quest
	return {}
func accept(person: String) -> bool:
	if busy or GameClock.settling or not near_person(person) or state.active.has(person): return false
	var quest := current(person)
	if quest.is_empty() or friendship(person)<int(quest.friendship): return false
	if person=="xiaojing" and (not Xiaojing.state.unlocked or Xiaojing.state.trust<40): return false
	busy=true
	var meeting_day := GameClock.day if GameClock.minutes<1080 else mini(999999,GameClock.day+1)
	state.active[person]={"id":quest.id,"start_day":GameClock.day,"counts":{},"tracked":{},"seen":[],"meeting_day":meeting_day if quest.id=="xiaojing_1" else 0,"missed":false,"repair_ready":false}
	last_clean_day=int(LakeEcology.state.clean_day)
	commit();return true
func note(person: String, goal: String, amount: int, token: String) -> bool:
	if not state.active.has(person): return false
	var active: Dictionary=state.active[person]
	var quest := definition(active.id)
	if not quest.goals.has(goal) or token in active.seen: return false
	if int(active.counts.get(goal,0))>=int(quest.goals[goal]): return false
	active.seen.append(token)
	active.counts[goal]=mini(int(quest.goals[goal]),int(active.counts.get(goal,0))+amount)
	return true
func on_farm(kind: String, cell: Vector2i, crop: String, serial: int) -> void:
	if GameState.restoring: return
	var did := false
	var cell_id := "%d,%d" % [cell.x,cell.y]
	for person in state.active:
		var active: Dictionary=state.active[person]
		if active.missed and kind=="收获": active.repair_ready=true;did=true
		var q := definition(active.id)
		var tracks_farm: bool=q.goals.has("plant_wheat") or q.goals.has("plant_types")
		if kind=="播种" and tracks_farm:
			active.tracked[cell_id]={"crop":crop,"serial":serial}
			did=note(person,"plant_"+crop,1,"plant:%d" % serial) or did
			did=note(person,"plant_types",1,"type:"+crop) or did
		elif active.tracked.has(cell_id):
			var entry: Dictionary=active.tracked[cell_id]
			if kind=="浇水": did=note(person,"water_own",1,"water:%d" % int(entry.serial)) or did
			elif kind=="收获" and entry.crop==crop:
				did=note(person,"harvest_"+crop,1,"harvest:%d" % int(entry.serial)) or did
				active.tracked.erase(cell_id)
	if did: commit()
func on_fish(site: String, _species: String, serial: int, day: int) -> void:
	if GameState.restoring: return
	if not state.active.has("xiaojing") or site!="farm_lake" or day!=GameClock.day or not meeting_now(): return
	if note("xiaojing","shared_fish",1,"fish:%d" % serial): commit()
func on_aquaculture(species: String, quantity: int, total: int, day: int) -> void:
	if GameState.restoring: return
	if day!=GameClock.day: return
	var did := false
	for person in state.active: did=note(person,"fish_"+species,quantity,"fishpen:%s:%d" % [species,total]) or did
	if did: commit()
func on_cook(recipe: String, batches: int, total: int, day: int) -> void:
	if GameState.restoring: return
	if day!=GameClock.day: return
	var did := false
	for person in state.active:
		if state.active[person].missed: state.active[person].repair_ready=true;did=true
		did=note(person,"cook:"+recipe,batches,"cook:%s:%d" % [recipe,total]) or did
	if did: commit()
func on_processing(source: String, recipe: String, job_id: int, batches: int) -> void:
	if GameState.restoring: return
	var did := false
	for person in state.active: did=note(person,"process:%s:%s" % [source,recipe],batches,"process:%s:%d" % [source,job_id]) or did
	if did: commit()
func on_inspect(event_id: String) -> void:
	if GameState.restoring: return
	var did := false
	for person in state.active: did=note(person,"inspect:"+event_id,1,"inspect:"+event_id) or did
	if did: commit()
func on_berry(day: int, _quantity: int) -> void:
	if GameState.restoring: return
	if day!=GameClock.day: return
	var did := false
	for person in state.active: did=note(person,"berry_days",1,"berry:%d" % day) or did
	if did: commit()
func observe_clean() -> void:
	if GameState.restoring: return
	var day: int=LakeEcology.state.clean_day
	if day<=last_clean_day: return
	last_clean_day=day
	if day==GameClock.day and note("zhou","clean_lake",1,"clean:%d" % day): commit()
func near_site(id: String) -> bool:
	return SITES.has(id) and is_instance_valid(game) and GameState.location==SITES[id].area and game.player.global_position.distance_to(SITES[id].point)<=60
func observe_site(id: String) -> bool:
	if busy or GameClock.settling or not near_site(id): return false
	var person: String={"kitchen":"zhou","cycle":"zhou","tea":"ahe","tea_season":"ahe"}.get(id,"xiaojing")
	if not state.active.has(person): return false
	if id=="kitchen" and Kitchen.state.built.is_empty(): return false
	if id=="cycle" and not LakeEcology.state.cycle: return false
	if id in ["tea","tea_season"] and not VillageProjects.has_project("arbor"): return false
	if id=="tea" and (GameClock.minutes<1080 or GameClock.minutes>=1200 or not near_person("ahe")): return false
	if id=="lake_date" and not meeting_now(): return false
	if id=="summer_sky" and (Calendar.season()!=1 or GameClock.minutes<1200 or not companion_here(LAKE)): return false
	if id=="winter_window" and (Calendar.season()!=3 or LegendState.state.greenhouse<2): return false
	if id=="ecology_after" and (not LakeEcology.state.restored or not companion_here(LakeEcology.SHORE)): return false
	if id=="star_lake" and (not GameWeather.is_meteor_night() or not LakeEcology.state.restored or not companion_here(LAKE)): return false
	if not note(person,"site:"+id,1,"site:"+id): return false
	commit();return true
func ready(person: String) -> bool:
	if not state.active.has(person): return false
	var active: Dictionary=state.active[person]
	if active.missed: return false
	var quest := definition(active.id)
	for goal in quest.goals:
		if int(active.counts.get(goal,0))<int(quest.goals[goal]): return false
	return true
func finish(person: String, choice: String) -> bool:
	if busy or not near_person(person) or not ready(person): return false
	var quest := definition(state.active[person].id)
	if not quest.choices.has(choice): return false
	busy=true
	if not Inventory.exchange(quest.required,quest.reward_items,0): busy=false;return false
	state.completed.append(quest.id);state.choices[quest.id]=choice;state.active.erase(person)
	if person=="xiaojing": Xiaojing.boost(0,0,1,"social:"+str(quest.id));Xiaojing.changed.emit()
	else: state.friendship[person]=mini(100,int(state.friendship[person])+int(quest.reward_friendship))
	Events.notice.emit(quest.reply)
	commit();return true
func check_dates() -> void:
	if GameState.restoring: return
	if busy or not state.active.has("xiaojing"): return
	var active: Dictionary=state.active.xiaojing
	if active.id!="xiaojing_1" or active.missed or ready("xiaojing"): return
	if GameClock.day>int(active.meeting_day) or (GameClock.day==int(active.meeting_day) and GameClock.minutes>=1200):
		active.missed=true;commit()
func rebook() -> bool:
	if busy or not near_person("xiaojing") or not state.active.has("xiaojing"): return false
	var active: Dictionary=state.active.xiaojing
	if not active.missed or not active.repair_ready: return false
	active.missed=false;active.repair_ready=false
	active.meeting_day=GameClock.day if GameClock.minutes<1080 else mini(999999,GameClock.day+1)
	commit();return true
func meeting_now() -> bool:
	if not state.active.has("xiaojing"): return false
	var active: Dictionary=state.active.xiaojing
	return active.id=="xiaojing_1" and not active.missed and GameClock.day==int(active.meeting_day) and GameClock.minutes>=1080 and GameClock.minutes<1200 and companion_here(LAKE)
func companion_here(at: Vector2) -> bool:
	var person := person_node("xiaojing")
	return person!=null and GameState.location=="farm" and person.global_position.distance_to(at)<=80
func area(person: String) -> String:
	if person!="xiaojing" or not state.active.has(person): return ""
	var active: Dictionary=state.active[person]
	if active.id=="xiaojing_1" and not active.missed and GameClock.day==int(active.meeting_day) and GameClock.minutes>=1080 and GameClock.minutes<1200: return "farm"
	if active.id=="xiaojing_2" and Calendar.season()==1 and GameClock.minutes>=1200: return "farm"
	if active.id=="xiaojing_3" and ((GameClock.minutes>=540 and GameClock.minutes<1080) or GameWeather.is_meteor_night()): return "farm"
	return ""
func station(person: String, location: String) -> Vector2:
	if area(person)!=location or location!="farm": return Vector2.INF
	if state.active[person].id=="xiaojing_3" and not GameWeather.is_meteor_night(): return Vector2(912,656)
	return COMPANION
func progress(person: String) -> String:
	var quest := current(person)
	if quest.is_empty(): return "这一页已经写完，日常生活还会继续。"
	if not state.active.has(person): return "尚未接下 · 需要好感%d" % quest.friendship
	var active: Dictionary=state.active[person]
	var lines: Array[String]=[]
	for goal in quest.goals: lines.append("%s：%d/%d" % [goal_label(goal),int(active.counts.get(goal,0)),int(quest.goals[goal])])
	if active.meeting_day>0: lines.append("约定第%d天18:00–20:00%s" % [active.meeting_day," · 已错过，可重新约定" if active.missed else ""])
	return "\n".join(lines)
func validate(raw: Variant, day: int) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults().keys()) or not FarmSaveSchema.whole(day,1,999999): return false
	if not AquacultureSaveSchema.exact(raw.friendship,["linya","zhou","ahe"]) or not AquacultureSaveSchema.exact(raw.daily,PEOPLE): return false
	for person in raw.friendship:
		if not FarmSaveSchema.whole(raw.friendship[person],0,100): return false
	for person in PEOPLE:
		var daily: Variant=raw.daily[person]
		if not AquacultureSaveSchema.exact(daily,["talk_day","gift_day","birthday_year","gifts"]): return false
		for key in ["talk_day","gift_day"]:
			if not FarmSaveSchema.whole(daily[key],0,day): return false
		if not FarmSaveSchema.whole(daily.birthday_year,0,Calendar.year(day)) or not daily.gifts is Array or daily.gifts.size()>3: return false
		for item in daily.gifts:
			if not item is String or not Catalog.is_item(item): return false
	var ids: Array=[]
	for quest in data.quests: ids.append(quest.id)
	if not AquacultureSaveSchema.unique(raw.completed,ids) or not raw.choices is Dictionary or raw.choices.size()!=raw.completed.size(): return false
	for id in raw.completed:
		var quest := definition(id)
		if quest.previous!="" and quest.previous not in raw.completed: return false
		if not raw.choices.has(id) or not quest.choices.has(raw.choices[id]): return false
	if not raw.active is Dictionary or raw.active.size()>4: return false
	for person in raw.active:
		if person not in PEOPLE: return false
		var active: Variant=raw.active[person]
		if not AquacultureSaveSchema.exact(active,["id","start_day","counts","tracked","seen","meeting_day","missed","repair_ready"]): return false
		var quest := definition(active.id) if active.id is String else {}
		if quest.is_empty() or quest.person!=person or active.id in raw.completed or (quest.previous!="" and quest.previous not in raw.completed): return false
		if not FarmSaveSchema.whole(active.start_day,1,day) or not FarmSaveSchema.whole(active.meeting_day,0,mini(999999,day+1)) or not active.missed is bool or not active.repair_ready is bool: return false
		if active.id!="xiaojing_1" and (active.meeting_day!=0 or active.missed or active.repair_ready): return false
		if active.id=="xiaojing_1" and active.meeting_day<active.start_day: return false
		if not active.counts is Dictionary or active.counts.size()>quest.goals.size(): return false
		for goal in active.counts:
			if not quest.goals.has(goal) or not FarmSaveSchema.whole(active.counts[goal],1,int(quest.goals[goal])): return false
		if not active.seen is Array or active.seen.size()>128: return false
		var seen := {}
		for token in active.seen:
			if not token is String or token.length()>100 or seen.has(token): return false
			seen[token]=true
		if not active.tracked is Dictionary or active.tracked.size()>60: return false
		for cell in active.tracked:
			if not cell is String: return false
			var parts: PackedStringArray=cell.split(",")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var point := Vector2i(int(parts[0]),int(parts[1]))
			if cell!="%d,%d" % [point.x,point.y] or not Rect2i(17,16,10,6).has_point(point): return false
			var entry: Variant=active.tracked[cell]
			if not AquacultureSaveSchema.exact(entry,["crop","serial"]) or not Catalog.crops.has(entry.crop) or not FarmSaveSchema.whole(entry.serial,1,999999999): return false
	return true

func goal_label(goal: String) -> String:
	return {"plant_wheat":"新种小麦","water_own":"照料自己新种的作物","harvest_wheat":"收获新种小麦","plant_types":"实际新种作物种类","fish_carp":"亲手收获鲤鱼","inspect:bridge_survey":"桥墩水线调查","inspect:mill":"风车货运簿","inspect:repair_record":"木作维修记录","inspect:b_record":"地下水脉矿工记录","process:mines:copper_bar":"新熔炼铜锭","site:kitchen":"加工设备现场检查","clean_lake":"实际湖岸清理","site:cycle":"循环水道检查","talk:linya":"与林芽当日交流","talk:zhou":"与周砚当日交流","cook:carrot_stew":"亲手制作暖锅炖菜","site:tea":"晚间茶座安排","berry_days":"不同日期采摘野莓","site:tea_season":"当季茶座观察","site:lake_date":"赴湖边约定","shared_fish":"小京在场共同钓获","site:summer_sky":"夏夜共同观星","site:winter_window":"冬季温室检查","cook:milk_porridge":"亲手制作奶香麦粥","site:ecology_after":"生态修复后共同回访","site:star_lake":"流星夜湖面观察"}.get(goal,"现场行动")
