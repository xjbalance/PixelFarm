class_name LegendTrials
extends RefCounted
const IDS := ["management","planning","cave","mechanism","joint"]
static func active(id: String = "") -> bool:
	return not LegendState.state.contract.is_empty() and (id=="" or LegendState.state.contract.id==id)
static func begin(id: String) -> bool:
	if id not in IDS or active() or id in LegendState.state.trials or not Xiaojing.state.trial.is_empty() or not StarStory.near_point("greenhouse") or not Xiaojing.state.unlocked: return false
	if id=="joint" and LegendState.state.trials.size()<4: return false
	if id=="cave" and AbyssState.state.max_clear<(10 if River.state.legacy_rules else 80): return false
	if id in ["planning","joint"] and not MineState.state.furnace: return false
	Playtest.record("trial_start",{"id":"legend:"+id})
	River.state.old_contract=""
	LegendState.state.contract={"id":id,"day":GameClock.day,"plants":0,"budget":0,"sown":{},"harvest":{},"outputs":{},"sales":0,"wood":0,"stone":0,"jobs":[],"crafted":{},"depths":[],"conduits":[],"coop":[],"rescues":int(AbyssState.state.rescues),"camp_run":int(AbyssState.state.run),"fabricated":false}
	if id=="cave": LegendState.state.contract.arrival_air=-1
	LegendState.commit()
	return true
static func farm(action: String, cell: Vector2i, crop: String) -> void:
	if not active(): return
	var c: Dictionary=LegendState.state.contract
	var key := "%d,%d" % [cell.x,cell.y]
	if action=="播种":
		c.plants+=1
		c.budget+=FarmEconomy.seed_price(crop)
		c.sown[key]=crop
	elif action=="收获" and c.sown.get(key,"")==crop:
		c.sown.erase(key)
		c.harvest[crop]=int(c.harvest.get(crop,0))+1
		c.outputs[crop]=int(c.outputs.get(crop,0))+1
static func trade(item: String, count: int, income: int) -> void:
	if not active("management") or income<=0: return
	var c: Dictionary=LegendState.state.contract
	var eligible: int=mini(count,int(c.outputs.get(item,0)))
	if eligible<=0: return
	c.outputs[item]=int(c.outputs.get(item,0))-eligible
	c.sales+=eligible*Catalog.sell_price(item)
static func enqueue(job: Dictionary, cost: Dictionary) -> void:
	if not active("planning"): return
	var c: Dictionary=LegendState.state.contract
	c.jobs.append(int(job.id))
	c.wood+=int(cost.get("wood",0))
	c.stone+=int(cost.get("stone",0))
static func claim(job: Dictionary) -> void:
	if not active("planning") or int(job.id) not in LegendState.state.contract.jobs: return
	var c: Dictionary=LegendState.state.contract
	c.crafted[job.recipe]=int(c.crafted.get(job.recipe,0))+int(job.batches)
static func fabricate() -> bool:
	if not active("planning") or not StarStory.near_point("greenhouse"): return false
	var c: Dictionary=LegendState.state.contract
	if c.fabricated or int(c.crafted.get("copper_bar",0))<2 or int(c.crafted.get("iron_bar",0))<3 or int(c.crafted.get("star_alloy",0))<1: return false
	if c.wood+4>24 or c.stone+8>16 or not Inventory.exchange({"copper_bar":2,"iron_bar":2,"star_alloy":1,"wood":4,"stone":8},{},0): return false
	c.wood+=4
	c.stone+=8
	c.fabricated=true
	LegendState.commit()
	return true
static func observed(depth: int) -> void:
	var target: int=20 if River.state.legacy_rules or River.state.old_contract=="joint" else 100
	if active("joint") and depth==target and target not in LegendState.state.contract.depths: LegendState.state.contract.depths.append(target)
static func visited(depth: int) -> void:
	if not active("cave"): return
	var c: Dictionary=LegendState.state.contract
	if depth not in c.depths: c.depths.append(depth)
	var start: int=10 if River.state.legacy_rules or River.state.old_contract=="cave" else 80
	var end: int=20 if start==10 else 100
	if depth!=end or int(c.get("arrival_air",-1))>=0: return
	for required in range(start,end+1):
		if required not in c.depths: return
	c.arrival_air=int(AbyssState.state.air)
static func conduit() -> bool:
	if not active("mechanism") or not AbyssState.near("conduit"): return false
	var c: Dictionary=LegendState.state.contract
	var d: int=AbyssState.state.depth
	var sequence: Array=[5,12,20] if River.state.legacy_rules or River.state.old_contract=="mechanism" else [20,60,100]
	if c.conduits.size()>=sequence.size(): return false
	if d not in AbyssState.state.notes or LegendState.state.deduction!=3 or d!=sequence[c.conduits.size()]: return false
	c.conduits.append(d)
	LegendState.commit()
	return true
static func cooperate(id: String) -> bool:
	if not active("joint") or not StarStory.near_person(id) or id not in ["linya","zhou","ahe"]: return false
	var c: Dictionary=LegendState.state.contract
	if id in c.coop: return false
	if id=="linya":
		for crop in Catalog.crops:
			if int(c.harvest.get(crop,0))<12: return false
		if not Inventory.exchange({"wheat":12,"potato":12,"carrot":12},{},0): return false
	elif id=="zhou" and not StarStory.has("vent_repaired"): return false
	elif id=="ahe" and (LegendState.state.deduction!=3 or (20 if River.state.legacy_rules or River.state.old_contract=="joint" else 100) not in c.depths): return false
	c.coop.append(id)
	LegendState.commit()
	return true
static func finish() -> bool:
	if not active() or not StarStory.near_point("greenhouse"): return false
	var c: Dictionary=LegendState.state.contract
	var ok := false
	match c.id:
		"management":
			var r: Dictionary=LegendState.data.trials.management
			var kinds := 0
			for crop in Catalog.crops:
				if int(c.harvest.get(crop,0))>=int(r.harvest_each): kinds+=1
			ok=kinds==3 and c.plants<=int(r.seeds) and c.budget<=int(r.budget) and c.sales-c.budget>=int(r.profit) and GameClock.day-c.day<=int(r.days)
		"planning": ok=c.fabricated and c.wood<=24 and c.stone<=16 and GameClock.day-c.day<=4
		"cave":
			var start: int=10 if River.state.legacy_rules or River.state.old_contract=="cave" else 80
			var end: int=20 if start==10 else 100
			ok=AbyssState.state.rescues==c.rescues and int(c.get("arrival_air",AbyssState.state.air))>=10
			for depth in range(start,end+1):
				if depth not in c.depths: ok=false
		"mechanism": ok=c.conduits==([5,12,20] if River.state.legacy_rules or River.state.old_contract=="mechanism" else [20,60,100])
		"joint": ok=c.coop.size()==3 and (20 if River.state.legacy_rules or River.state.old_contract=="joint" else 100) in c.depths and StarStory.has("kept_appointment") and not StarStory.state.repair_pending
	if not ok:
		var reason := failure_reason(c)
		Playtest.trial_failure("%s:%s" % [c.id,c.day],reason)
		if reason!="":
			Events.notice.emit("本轮已不满足"+reason+"；取消本轮后可重新尝试。")
			return false
		Events.notice.emit("传说目标尚未全部完成，记录已保存；可继续或取消本轮重试。")
		return false
	River.state.old_contract=""
	LegendState.state.trials.append(c.id)
	# 强化版直接认可同类型原试炼，玩家无需为十二任务再重复一轮基础版。
	if c.id not in Xiaojing.state.trials: Xiaojing.state.trials.append(c.id)
	LegendState.state.contract={}
	Xiaojing.boost(2,3,3,"legend_trial:"+str(c.id))
	Playtest.record("trial_finish",{"id":"legend:"+str(c.id)})
	Xiaojing.changed.emit()
	LegendState.commit()
	return true
static func cancel() -> void:
	if active():
		var c: Dictionary=LegendState.state.contract
		Playtest.trial_failure("%s:%s" % [c.id,c.day],failure_reason(c))
		Playtest.record("trial_cancel",{"id":"legend:"+str(c.id)})
	River.state.old_contract=""
	LegendState.state.contract={}
	LegendState.commit()

static func failure_reason(c: Dictionary) -> String:
	if c.id=="management" and (GameClock.day-c.day>12 or c.plants>120 or c.budget>2800): return "经营期限或种子预算"
	if c.id=="planning" and (GameClock.day-c.day>4 or c.wood>24 or c.stone>16): return "制作期限或材料预算"
	if c.id=="cave" and (AbyssState.state.rescues!=c.rescues or (c.get("arrival_air",-1)>=0 and c.arrival_air<10)): return "无救援与终点空气要求"
	return ""
