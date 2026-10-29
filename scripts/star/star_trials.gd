class_name StarTrials
extends RefCounted
## 新接试炼使用独立合约；v7已在途的一轮没有合约，仍按原规则结算。
static func active(id: String = "") -> bool:
	var c: Dictionary=StarStory.state.challenge
	return not c.is_empty() and (id=="" or c.id==id)

static func begin(id: String) -> bool:
	if id=="planning" and not MineState.state.furnace:
		Events.notice.emit("先完成矿道修轨并建好周砚的熔炼炉，制作链试炼才有工台可用。")
		return false
	if id=="cave" and "mine_b" not in MineState.state.unlocked: return false
	if id=="mechanism" and "mine_c" not in MineState.state.unlocked: return false
	StarStory.state.challenge={"id":id,"day":GameClock.day,"plants":0,"seed_value":0,"planted":{},"harvest":{},
		"sold_value":0,"wood":0,"stone":0,"jobs":[],"crafted":[],"parts":[],"checks":[],"steps":0,"last_cell":"","coop":[]}
	return true

static func on_farm(action: String, crop: String, eligible: bool) -> void:
	if not active(): return
	var c: Dictionary=StarStory.state.challenge
	if action=="播种":
		c.plants+=1
		c.seed_value+=FarmEconomy.seed_price(crop)
		c.planted[crop]=int(c.planted.get(crop,0))+1
	elif action=="收获" and eligible:
		c.harvest[crop]=int(c.harvest.get(crop,0))+1

static func on_trade(item: String, eligible: int) -> void:
	if active("management") and eligible>0: StarStory.state.challenge.sold_value+=eligible*Catalog.sell_price(item)

static func on_enqueue(job: Dictionary, required: Dictionary) -> void:
	if not active("planning"): return
	var c: Dictionary=StarStory.state.challenge
	c.jobs.append(int(job.id))
	c.wood+=int(required.get("wood",0))
	c.stone+=int(required.get("stone",0))

static func on_claim(job: Dictionary) -> void:
	if not active("planning") or int(job.id) not in StarStory.state.challenge.jobs: return
	if job.recipe not in StarStory.state.challenge.crafted: StarStory.state.challenge.crafted.append(job.recipe)

static func build_hinge() -> bool:
	if not active("planning") or not StarStory.near_point("greenhouse"): return false
	var c: Dictionary=StarStory.state.challenge
	if "copper_bar" not in c.crafted or "hinge" in c.parts: return false
	if int(c.wood)+4>24 or int(c.stone)+2>16 or not Inventory.exchange({"copper_bar":1,"wood":4,"stone":2},{},0): return false
	c.wood+=4
	c.stone+=2
	c.parts.append("hinge")
	StarStory.mark("hinge_repaired")
	StarStory.commit()
	return true

static func observe_note(id: String) -> void:
	if active():
		var clue: String={"a_tutorial":"manual","b_hint":"water","c_star_hint":"star_hint"}.get(id,"")
		if clue!="" and clue not in StarStory.state.challenge.checks: StarStory.state.challenge.checks.append(clue)
	if id=="b_hint": StarStory.post_observation("sample_water")
	StarStory.commit()

static func walk(area: String, cell: Vector2i) -> void:
	if not active("cave"): return
	var c: Dictionary=StarStory.state.challenge
	var key := "%s:%d,%d" % [area,cell.x,cell.y]
	if key==c.last_cell: return
	c.last_cell=key
	c.steps=mini(999999,int(c.steps)+1)

static func collaborate(id: String, answer: int = 0) -> bool:
	if not active("joint") or id not in ["linya","zhou","ahe"] or not StarStory.near_person(id): return false
	var c: Dictionary=StarStory.state.challenge
	if id in c.coop: return false
	if answer!=0:
		Events.notice.emit("先把各自的需要记清楚，再带着记录来商量。")
		return false
	if id=="linya":
		if int(c.harvest.get("wheat",0))<3 or not Inventory.exchange({"wheat":3},{},0): return false
	elif id=="zhou" and not StarStory.has("vent_repaired"): return false
	elif id=="ahe" and not StarStory.has("history_solved"): return false
	c.coop.append(id)
	StarStory.commit()
	return true

static func complete(id: String) -> bool:
	if not active(): return true
	if not active(id): return false
	var c: Dictionary=StarStory.state.challenge
	match id:
		"management":
			var kinds := 0
			for crop in Catalog.FOUNDATION_CROPS:
				if int(c.harvest.get(crop,0))>=12: kinds+=1
			return GameClock.day-int(c.day)<=8 and c.plants<=60 and c.seed_value<=1000 and kinds>=2 and int(c.sold_value)-int(c.seed_value)>=1800
		"planning": return GameClock.day-int(c.day)<=3 and c.wood<=24 and c.stone<=16 and "copper_bar" in c.crafted and "hinge" in c.parts
		"cave": return c.steps<=180 and "manual" in c.checks and "water" in c.checks
		"mechanism": return StarStory.has("history_solved") and "star_hint" in c.checks
		"joint": return c.coop.size()==3 and int(c.harvest.get("wheat",0))>=3
	return false

static func settled(id: String) -> void:
	StarStory.state.challenge={}
	if id=="cave": StarStory.event("act_valley")
	StarStory.commit()

static func cancel() -> void:
	StarStory.state.challenge={}
	MineState.state.expedition={}
	StarStory.commit()

static func describe() -> String:
	if not active(): return "旧档在途合约：沿用原先的完成规则，本轮结束后再启用深化规则。"
	var c: Dictionary=StarStory.state.challenge
	match c.id:
		"management": return "限60种子、价值预算1000，至少两种各收12；净收益1800。\n已播%d/60 · 种值%d/1000 · 标准净收益%d" % [c.plants,c.seed_value,int(c.sold_value)-int(c.seed_value)]
		"planning": return "三日内采木20石12，亲自加工铜锭并到温室修铰链，余体力35。\n项目用木%d/24 石%d/16 · 加工%s · 修件%s" % [c.wood,c.stone,str(c.crafted),str(c.parts)]
		"cave": return "同日四矿、水脉、20格与回村，余20体力、采矿≤90；查手册和水位牌。\n安全观察路线%d/180段 · 检查%s" % [c.steps,str(c.checks)]
		"mechanism": return "拼好温室历史，读晶窟东南基座线索，再走到九座星灯；五步内全亮。"
		"joint": return "三图、新田收获6、解一次种箱；新收麦3交林芽，与周砚核窗架、阿禾对停用记录。\n已协作："+str(c.coop)
	return ""
