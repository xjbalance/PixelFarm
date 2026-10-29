class_name AquacultureSaveSchema
extends RefCounted
## 纯数据校验：迁移不推算历史养鱼、不推进日期、不发奖励。
const SPECIES := {"crucian":2,"carp":3,"grass":4,"perch":5,"golden":8,"star":12}
const BREED_DAYS := {"crucian":3,"carp":4,"grass":5,"perch":6,"golden":8,"star":12}
const RECIPES := ["feed","dried","soup","crucian_dried","perch_soup","golden_soup","star_soup"]
const SITES := ["pen_1","pen_2","pen_3","pen_4"]
const CAPACITY := {0:0,1:12,2:20,3:32}

static func empty_pen(id: String, day: int) -> Dictionary:
	return {"id":id,"built":false,"level":0,"species":"","adults":0,"cohorts":[],
		"last_feed_day":0,"fed_count":0,"feed_stock":0,"water":80,"health":100,"breeding":0,
		"last_maintain_day":0,"last_settled_day":day}

static func defaults(day: int = 1) -> Dictionary:
	var pens := {}
	for id in SITES: pens[id]=empty_pen(id,day)
	return {"pens":pens,"quests":[],"collection":[],"harvested":{},"order_day":0,"order_count":0,
		"order_baseline":0,"processed":{},"meal_day":0,"last_settled_day":day,
		"xiaojing":{"stage":0,"invited_day":0,"care_days":[],"pen":"","harvested":0}}

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

static func exact(data: Variant, keys: Array) -> bool:
	if not data is Dictionary or data.size()!=keys.size(): return false
	for key in keys:
		if not data.has(key): return false
	return true

static func unique(values: Variant, allowed: Array) -> bool:
	if not values is Array or values.size()>allowed.size(): return false
	var seen := {}
	for value in values:
		if value not in allowed or seen.has(value): return false
		seen[value]=true
	return true

static func validate(raw: Variant, day: int) -> bool:
	if not exact(raw,defaults().keys()) or not whole(day,1,999999): return false
	if not exact(raw.pens,SITES): return false
	for id in SITES:
		if not valid_pen(raw.pens[id],id,day): return false
	if not unique(raw.quests,["intro","research"]): return false
	if "research" in raw.quests and "intro" not in raw.quests: return false
	if not unique(raw.collection,SPECIES.keys()): return false
	if not raw.harvested is Dictionary or raw.harvested.size()>SPECIES.size(): return false
	for id in raw.harvested:
		if id not in SPECIES or not whole(raw.harvested[id],1,999999) or id not in raw.collection: return false
	if raw.harvested.size()!=raw.collection.size(): return false
	for key in ["order_day","meal_day"]:
		if not whole(raw[key],0,day): return false
	if not whole(raw.last_settled_day,1,day) or not whole(raw.order_count,0,999999) or not whole(raw.order_baseline,0,999999): return false
	if int(raw.order_baseline)>int(raw.harvested.get("carp",0)): return false
	if (raw.order_day==0)!=(raw.order_count==0): return false
	if raw.order_count>0 and "intro" not in raw.quests: return false
	if not raw.processed is Dictionary or raw.processed.size()>RECIPES.size(): return false
	for id in raw.processed:
		if id not in RECIPES or not whole(raw.processed[id],1,999999): return false
	var x: Variant=raw.xiaojing
	if not exact(x,["stage","invited_day","care_days","pen","harvested"]): return false
	if not whole(x.stage,0,2) or not whole(x.invited_day,0,day) or not whole(x.harvested,0,999999): return false
	if not x.care_days is Array or x.care_days.size()>3: return false
	var seen := {}
	for care_day in x.care_days:
		if not whole(care_day,maxi(1,int(x.invited_day)),day) or seen.has(int(care_day)): return false
		seen[int(care_day)]=true
	if x.stage==0:
		if x.invited_day!=0 or x.pen!="" or not x.care_days.is_empty() or x.harvested!=0: return false
	else:
		if x.pen not in SITES or x.invited_day<1 or not raw.pens[x.pen].built: return false
		if x.stage==2 and (x.care_days.size()!=3 or x.harvested<2): return false
	return true

static func valid_pen(p: Variant, id: String, day: int) -> bool:
	if not exact(p,empty_pen(id,day).keys()) or p.id!=id or not p.built is bool: return false
	if not whole(p.level,0,3) or bool(p.built)!=(p.level>0): return false
	if not p.species is String or (p.species!="" and p.species not in SPECIES): return false
	if not whole(p.adults,0,int(CAPACITY[int(p.level)])) or not p.cohorts is Array or p.cohorts.size()>32: return false
	for key in ["last_feed_day","last_maintain_day"]:
		if not whole(p[key],0,day): return false
	if not whole(p.fed_count,0,int(CAPACITY[int(p.level)])): return false
	if (p.last_feed_day==0)!=(p.fed_count==0): return false
	if not whole(p.last_settled_day,1,day) or not whole(p.feed_stock,0,999) or not whole(p.water,0,100) or not whole(p.health,0,100) or not whole(p.breeding,0,12): return false
	var total: int=int(p.adults)
	var ages := {}
	for c in p.cohorts:
		if p.species=="" or not exact(c,["count","age"]): return false
		if not whole(c.count,1,32) or not whole(c.age,0,int(SPECIES[p.species])*4-1): return false
		if ages.has(int(c.age)): return false
		ages[int(c.age)]=true
		total+=int(c.count)
	if total>int(CAPACITY[int(p.level)]) or (total==0)!=(p.species==""): return false
	if p.species in ["golden","star"] and p.level < (2 if p.species=="golden" else 3): return false
	if p.feed_stock>0 and p.level<3: return false
	if not p.built and (total>0 or p.breeding>0 or p.last_feed_day>0 or p.last_maintain_day>0): return false
	if total==0 and p.breeding!=0: return false
	if p.species!="" and p.breeding>=int(BREED_DAYS[p.species]): return false
	if not p.built and (p.water!=80 or p.health!=100 or p.feed_stock!=0): return false
	return true
