class_name MiningSaveSchema
extends RefCounted

static func unique(values: Variant, allowed: Array) -> bool:
	if not values is Array: return false
	var seen := {}
	for value in values:
		if value not in allowed or seen.has(value): return false
		seen[value]=true
	return true

static func validate(saved: Variant, day: int) -> bool:
	if not saved is Dictionary: return false
	for key in MineState.defaults():
		if not saved.has(key): return false
	if not unique(saved.unlocked,MineState.AREAS): return false
	for i in range(saved.unlocked.size()):
		if saved.unlocked[i]!=MineState.AREAS[i]: return false
	for key in ["furnace","track_repaired","water_lowered","hardened","resonance_open","legacy_board_claimable","legacy_board_settled"]:
		if not saved[key] is bool: return false
	if saved.legacy_board_claimable and saved.legacy_board_settled: return false
	if not FarmSaveSchema.whole(saved.tool,1,3) or (saved.tool>1 and not saved.furnace): return false
	for key in ["job_serial","survey","diamond_counter"]:
		if not FarmSaveSchema.whole(saved[key],0,999999): return false
	if not FarmSaveSchema.whole(saved.track_switch,0,1) or (saved.track_switch==1 and not saved.track_repaired): return false
	if not FarmSaveSchema.whole(saved.water_step,0,1) or (saved.water_lowered and saved.water_step!=0): return false
	if not FarmSaveSchema.whole(saved.resonance_step,0,2) or (saved.resonance_open and saved.resonance_step!=0): return false
	if saved.hardened and (not saved.water_lowered or saved.tool<2): return false
	if not unique(saved.legacy_trials,["management","planning","cave","mechanism","joint"]): return false
	if not unique(saved.linked_memories,["pond","mill"]) or not unique(saved.exploration_events,["b_memory","c_memory"]): return false
	var chest_ids: Array = []
	for id in MineState.placements:
		if MineState.placements[id].kind=="chest": chest_ids.append(id)
	if not unique(saved.chests,chest_ids): return false
	var rare_ids: Array=[]
	for id in MineState.placements:
		if MineState.placements[id].get("ore","") in ["starlight","diamond"]: rare_ids.append(id)
	if not unique(saved.commission_mines,rare_ids): return false
	if not saved.ores is Dictionary or saved.ores.size()>MineState.placements.size(): return false
	for id in saved.ores:
		if not MineState.placements.has(id) or MineState.placements[id].kind!="ore": return false
		var ore = saved.ores[id]
		var d: Dictionary=MineState.data.ores[MineState.placements[id].ore]
		if not ore is Dictionary or not FarmSaveSchema.whole(ore.get("hp"),0,int(d.hits)): return false
		if not FarmSaveSchema.whole(ore.get("ready_day"),0,day+int(d.regrow)): return false
		if ore.hp>0 and ore.ready_day!=0: return false
		if ore.hp==0 and int(d.regrow)>0 and ore.ready_day<1: return false
		if int(d.regrow)==0 and ore.ready_day!=0: return false
	if not saved.queue is Array or saved.queue.size()>4: return false
	var seen := {}
	for job in saved.queue:
		if not job is Dictionary or not MineState.data.recipes.has(job.get("recipe","")): return false
		if not FarmSaveSchema.whole(job.get("id"),1,int(saved.job_serial)) or seen.has(job.id): return false
		seen[job.id]=true
		if not FarmSaveSchema.whole(job.get("batches"),1,5) or not FarmSaveSchema.whole(job.get("ready_day"),1,day+1): return false
		if int(MineState.data.recipes[job.recipe].level)>int(saved.tool) or not saved.furnace: return false
	if not saved.expedition is Dictionary: return false
	var e: Dictionary=saved.expedition
	if not e.is_empty():
		if not FarmSaveSchema.whole(e.get("day"),1,day) or not FarmSaveSchema.whole(e.get("energy"),0,999999): return false
		if not unique(e.get("areas"),MineState.AREAS) or not unique(e.get("mined"),MineState.placements.keys()): return false
		for id in e.mined:
			if MineState.placements[id].kind!="ore": return false
		if not e.get("visited") is Array or e.visited.size()>3360: return false
		var visited := {}
		for id in e.visited:
			if not id is String or visited.has(id): return false
			visited[id]=true
			var parts: PackedStringArray=id.split(":")
			if parts.size()!=2 or parts[0] not in MineState.AREAS: return false
			var xy: PackedStringArray=parts[1].split(",")
			if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int(): return false
			if not Rect2i(0,0,40,28).has_point(Vector2i(int(xy[0]),int(xy[1]))): return false
	return true
