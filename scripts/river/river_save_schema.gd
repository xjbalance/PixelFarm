class_name RiverSaveSchema
extends RefCounted
static func validate(s: Variant, day: int) -> bool:
	if not s is Dictionary or s.size()!=River.defaults().size(): return false
	for key in River.defaults():
		if not s.has(key): return false
	for key in ["legacy_rules","legacy_scene","venue_used"]:
		if not s[key] is bool: return false
	if not MiningSaveSchema.unique(s.old_checkpoints,[5,15]) or s.old_contract not in ["","management","planning","cave","mechanism","joint"]: return false
	var allowed: Array=ChapterTwo.allowed_facts()+["star_core","river80","river100"]
	if not MiningSaveSchema.unique(s.facts,allowed) or not MiningSaveSchema.unique(s.memory_seen,River.memory_ids()): return false
	if not s.memory_steps is Dictionary or s.memory_steps.size()>7: return false
	for id in s.memory_steps:
		if id not in River.memory_ids() or not MiningSaveSchema.unique(s.memory_steps[id],River.data.memories[id].steps): return false
	if not AbyssSaveSchema.ints(s.jobs,1,999999) or not s.crafted is Dictionary: return false
	for id in s.crafted:
		if id not in MineState.data.recipes or not FarmSaveSchema.whole(s.crafted[id],0,999999): return false
	if not FarmSaveSchema.whole(s.crop_count,0,999999) or not FarmSaveSchema.whole(s.weekly_day,0,day) or not FarmSaveSchema.whole(s.wedding_step,0,3) or not FarmSaveSchema.whole(s.festival,-1,int((day-1)/28)): return false
	if not FarmSaveSchema.whole(s.ending_day,0,day) or not (s.ending_until is int or s.ending_until is float) or not is_finite(float(s.ending_until)) or s.ending_until<0 or s.ending_until>=1440: return false
	if s.policy not in ["","water","rotation","commons"] or s.post not in ["","seed_collab","outing"]: return false
	if ("closing_choice" in s.facts)!=(s.policy!="") or ("closing_scene" in s.facts and s.policy==""): return false
	if not MiningSaveSchema.unique(s.post_done,["seed_collab","outing"]) or not MiningSaveSchema.unique(s.post_steps,["wheat","potato","water","tea"]): return false
	if not s.sown is Dictionary or s.sown.size()>FarmLayoutCatalog.GRID.get_area(): return false
	for cell in s.sown:
		if not cell is String or s.sown[cell] not in Catalog.crops: return false
		var v: PackedStringArray=cell.split(",")
		if v.size()!=2 or not v[0].is_valid_int() or not v[1].is_valid_int() or FarmLayoutCatalog.plot_cell(cell)==FarmLayoutCatalog.INVALID_CELL: return false
	return true
