class_name StarSaveSchema
extends RefCounted
## 新剧情只校验，不在恢复期间发奖、扣钻或推导新的完成事件。
static func strings(value: Variant, allowed: Array) -> bool:
	if not value is Array or value.size()>allowed.size(): return false
	var seen := {}
	for id in value:
		if not id is String or id not in allowed or seen.has(id): return false
		seen[id]=true
	return true

static func validate(s: Variant, day: int, x: Dictionary) -> bool:
	if not s is Dictionary or s.size()!=StarStory.defaults().size(): return false
	for key in StarStory.defaults():
		if not s.has(key): return false
	if not strings(s.events,["act_seed520","act_greenhouse","act_valley","act_memories","act_starlight","act_star1314","kept_appointment","repaired_promise","proposal","wedding"]): return false
	var facts: Array=["greenhouse_survey","vent_repaired","history_solved","hinge_repaired"]
	for m in Xiaojing.data.memories: facts.append("memory:"+str(m.id))
	if not strings(s.facts,facts) or not strings(s.invited,["linya","zhou","ahe"]): return false
	for key in ["repair_pending","legacy_import"]:
		if not s[key] is bool: return false
	for key in ["cooperate_day","gift_mood_day"]:
		if not FarmSaveSchema.whole(s[key],0,day): return false
	if not FarmSaveSchema.whole(s.season_done,-1,int((day-1)/28)) or not FarmSaveSchema.whole(s.assembly,0,2) or not FarmSaveSchema.whole(s.wedding_phase,0,4): return false
	if not s.choices is Dictionary or s.choices.size()>3: return false
	for key in s.choices:
		var allowed: Array=StarStory.data.choices.get(key,{}).keys() if key!="future" else ["share_home","keep_journeys"]
		if s.choices[key] not in allowed: return false
	if not s.appointment is Dictionary: return false
	if not s.appointment.is_empty():
		if s.appointment.size()!=2 or not FarmSaveSchema.whole(s.appointment.get("day"),1,day+1) or s.appointment.get("status") not in ["booked","missed"]: return false
		if s.appointment.status=="missed" and not s.repair_pending: return false
	if not s.season_run is Dictionary: return false
	if not s.season_run.is_empty():
		if not x.married: return false
		if s.season_run.size()!=5 or not s.season_run.get("lamp") is bool: return false
		for key in ["plant","water","harvest"]:
			if not FarmSaveSchema.whole(s.season_run.get(key),0,999999): return false
		if not FarmSaveSchema.whole(s.season_run.get("season"),0,int((day-1)/28)): return false
	if s.post_run not in ["","separate_desks","field_trip"]: return false
	var goals: Array=[] if s.post_run=="" else StarStory.data.post_events[s.post_run].goals
	if not strings(s.post_steps,goals): return false
	if not s.invited.is_empty() and "proposal" not in s.events: return false
	if s.wedding_phase>=1 and ("proposal" not in s.events or s.invited.size()!=3): return false
	if (s.wedding_phase>=3)!=x.married or ("wedding" in s.events)!=x.married: return false
	if s.wedding_phase>=1 and not x.greenhouse: return false
	if "proposal" in s.events and (not x.dating or not x.greenhouse): return false
	if "history_solved" in s.facts and x.memories.size()!=7: return false
	if s.post_run!="" and not x.married: return false
	return challenge(s.challenge,day,x)

static func challenge(c: Variant, day: int, x: Dictionary) -> bool:
	if not c is Dictionary: return false
	if c.is_empty(): return true # v7正在进行的旧合约允许结算一次。
	if c.size()!=16 or c.get("id") not in ["management","planning","cave","mechanism","joint"] or c.id!=x.trial.get("id",""): return false
	if not FarmSaveSchema.whole(c.get("day"),1,day): return false
	for key in ["plants","seed_value","sold_value","wood","stone","steps"]:
		if not FarmSaveSchema.whole(c.get(key),0,999999999): return false
	for key in ["planted","harvest"]:
		if not c.get(key) is Dictionary or c[key].size()>Catalog.crops.size(): return false
		for crop in c[key]:
			if crop not in Catalog.crops or not FarmSaveSchema.whole(c[key][crop],0,999999): return false
	if not c.get("jobs") is Array or c.jobs.size()>9999: return false
	var unique := {}
	for id in c.jobs:
		if not FarmSaveSchema.whole(id,1,999999999) or unique.has(id): return false
		unique[id]=true
	if not strings(c.get("crafted"),MineState.data.recipes.keys()) or not strings(c.get("parts"),["hinge"]) or not strings(c.get("checks"),["manual","water","star_hint"]) or not strings(c.get("coop"),["linya","zhou","ahe"]): return false
	if not c.get("last_cell") is String or c.last_cell.length()>40: return false
	return true
