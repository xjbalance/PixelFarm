class_name AbyssSaveSchema
extends RefCounted
static func ints(a: Variant, low: int, high: int) -> bool:
	if not a is Array or a.size()>high-low+1: return false
	var used := {}
	for n in a:
		if not FarmSaveSchema.whole(n,low,high) or used.has(n): return false
		used[n]=true
	return true
static func validate(s: Variant, day: int) -> bool:
	if not s is Dictionary or s.size()!=AbyssState.defaults().size(): return false
	for key in AbyssState.defaults():
		if not s.has(key): return false
	if not s.unlocked is bool: return false
	for key in ["depth","checkpoint"]:
		if not FarmSaveSchema.whole(s[key],1,100): return false
	if not FarmSaveSchema.whole(s.max_clear,0,100) or s.depth>mini(100,int(s.max_clear)+1): return false
	if (s.checkpoint not in [1,5,15] and int(s.checkpoint)%10!=0) or s.checkpoint>maxi(1,int(s.max_clear)): return false
	if not FarmSaveSchema.whole(s.gear,1,7) or int(AbyssState.layout(int(s.depth)).gear)>s.gear: return false
	if (s.gear>=2 and s.max_clear<10) or (s.gear>=3 and s.max_clear<15): return false
	if not FarmSaveSchema.whole(s.air,0,160) or not FarmSaveSchema.whole(s.rations,0,3) or not FarmSaveSchema.whole(s.camp_day,0,day) or not FarmSaveSchema.whole(s.survey_day,0,day): return false
	for key in ["rescues","survey","run"]:
		if not FarmSaveSchema.whole(s[key],0,999999): return false
	for key in ["gates","notes","chests"]:
		if not ints(s[key],1,100): return false
		for depth in s[key]:
			if depth>mini(100,int(s.max_clear)+1): return false
	for depth in range(1,int(s.max_clear)+1):
		if depth not in s.gates: return false
	for depth in s.gates:
		if depth not in s.notes: return false
	if 20 in s.gates and 10 not in s.notes: return false
	if not s.steps is Dictionary or s.steps.size()>100 or not s.ores is Dictionary or s.ores.size()>200: return false
	for id in s.steps:
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<1 or int(id)>100 or int(id) in s.gates: return false
		if not FarmSaveSchema.whole(s.steps[id],0,AbyssState.layout(int(id)).solution.size()-1): return false
	for id in s.ores:
		if not cell_key(id,false) or not FarmSaveSchema.whole(s.ores[id],0,3): return false
	for key in ["seen","hazards"]:
		if not s[key] is Array or s[key].size()>112000: return false
		var seen := {}
		for id in s[key]:
			if not cell_key(id,true) or seen.has(id): return false
			seen[id]=true
	if not ints(s.safety,1,100) or not s.ore_days is Dictionary or s.ore_days.size()>200: return false
	for id in s.ore_days:
		if not cell_key(id,false) or not FarmSaveSchema.whole(s.ore_days[id],1,day+3) or int(s.ores.get(id,3))!=0: return false
	if not MiningSaveSchema.unique(s.bosses,[20,40,60,80,100]) or not ints(s.shortcuts,1,100) or not s.extra is Dictionary or s.extra.size()>100 or not s.warnings is Dictionary or s.warnings.size()>1000: return false
	if not FarmSaveSchema.whole(s.diamond_counter,0,999999): return false
	for id in s.extra:
		if not id is String or not id.is_valid_int() or int(id)<21 or int(id)>100: return false
		var m=s.extra[id]
		if not m is Dictionary or m.size()!=4 or not m.get("confirmed") is bool or not MiningSaveSchema.unique(m.get("utility"),[0,1]) or not FarmSaveSchema.whole(m.get("angle"),0,2) or not FarmSaveSchema.whole(m.get("round"),0,2): return false
	for id in s.warnings:
		if not cell_key(id,true) or not (s.warnings[id] is int or s.warnings[id] is float) or not is_finite(float(s.warnings[id])): return false
	for rank in range(4,int(s.gear)+1):
		if s.max_clear<int(AbyssState.config.gear[str(rank)].depth): return false
	if not s.unlocked and (s.max_clear>0 or s.gear>1 or not s.gates.is_empty()): return false
	return true
static func cell_key(id: Variant, xy: bool) -> bool:
	if not id is String: return false
	var p: PackedStringArray=id.split(":")
	if p.size()!=2 or not p[0].is_valid_int() or int(p[0])<1 or int(p[0])>100 or str(int(p[0]))!=p[0]: return false
	if not xy: return p[1] in ["0","1"]
	var c: PackedStringArray=p[1].split(",")
	return c.size()==2 and c[0].is_valid_int() and c[1].is_valid_int() and Rect2i(0,0,40,28).has_point(Vector2i(int(c[0]),int(c[1])))
static func legend(s: Variant, x: Dictionary, day: int) -> bool:
	if not s is Dictionary or s.size()!=LegendState.defaults().size(): return false
	for key in LegendState.defaults():
		if not s.has(key): return false
	for key in ["legacy_vow","review"]:
		if not s[key] is bool: return false
	if not FarmSaveSchema.whole(s.greenhouse,0,5) or not FarmSaveSchema.whole(s.deduction,0,3) or not FarmSaveSchema.whole(s.survey_day,0,day): return false
	if s.greenhouse==5 and not x.married: return false
	if x.married and s.greenhouse!=5: return false
	if s.greenhouse>=2 and x.quests.size()!=12: return false
	if s.greenhouse>=4 and not x.greenhouse: return false
	if x.greenhouse and s.greenhouse<2: return false
	if not ints(s.evidence,1,20): return false
	for d in s.evidence:
		if d not in [10,12,20]: return false
	if s.deduction>0 and (x.memories.size()!=7 or s.evidence.size()!=3): return false
	if not s.trials is Array: return false
	for id in s.trials:
		if id not in x.trials: return false
	if not MiningSaveSchema.unique(s.trials,LegendTrials.IDS) or not s.gifts is Array or s.gifts.size()>6: return false
	for gift in s.gifts:
		if gift not in StarStory.data.gifts: return false
	if s.choice not in ["","water_first","open_records"]: return false
	return contract(s.contract,day)
static func contract(c: Variant, day: int) -> bool:
	if not c is Dictionary: return false
	if c.is_empty(): return true
	if c.size() not in [18,19] or c.get("id") not in LegendTrials.IDS or not c.get("fabricated") is bool: return false
	if c.size()==19 and (c.id!="cave" or not FarmSaveSchema.whole(c.get("arrival_air"),-1,160)): return false
	if not FarmSaveSchema.whole(c.get("day"),1,day): return false
	for key in ["plants","budget","sales","wood","stone","rescues","camp_run"]:
		if not FarmSaveSchema.whole(c.get(key),0,999999999): return false
	for key in ["harvest","outputs","crafted"]:
		if not c.get(key) is Dictionary: return false
		for id in c[key]:
			if id not in (MineState.data.recipes if key=="crafted" else Catalog.crops) or not FarmSaveSchema.whole(c[key][id],0,999999): return false
	if not c.get("sown") is Dictionary or c.sown.size()>60: return false
	for id in c.sown:
		if not id is String or c.sown[id] not in Catalog.crops: return false
		var xy: PackedStringArray=id.split(",")
		if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or not Rect2i(17,16,10,6).has_point(Vector2i(int(xy[0]),int(xy[1]))): return false
	if not ints(c.get("jobs"),1,999999) or not ints(c.get("depths"),1,100) or not ints(c.get("conduits"),1,100) or not MiningSaveSchema.unique(c.get("coop"),["linya","zhou","ahe"]): return false
	if c.conduits not in [[],[5],[5,12],[5,12,20],[20],[20,60],[20,60,100]]: return false
	return true

static func canonical(value: Variant) -> Variant:
	# Godot JSON将整数读为float；枚举数组的has/==严格比较类型，恢复前统一新分区整数。
	if value is float and is_finite(value) and value==floorf(value) and absf(value)<9007199254740992.0: return int(value)
	if value is Array:
		var result: Array=[]
		for item in value: result.append(canonical(item))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[key]=canonical(value[key])
		return result
	return value
