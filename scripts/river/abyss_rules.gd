class_name AbyssRules
extends RefCounted
static func meta() -> Dictionary:
	var key := str(int(AbyssState.state.depth))
	if not AbyssState.state.extra.has(key): AbyssState.state.extra[key]={"utility":[],"angle":0,"round":0,"confirmed":false}
	return AbyssState.state.extra[key]
static func utility(symbol: int) -> bool:
	if symbol not in [0,1] or not AbyssState.near("utility_"+str(symbol)) or int(AbyssState.state.depth) not in AbyssState.state.notes: return false
	var m := meta()
	match AbyssState.layout().rule:
		"water":
			if m.utility.size()>=2: return false
			if symbol!=m.utility.size():
				m.utility=[]
				Events.notice.emit("先到泄压台，再到导流台。水闸安全复位。")
				AbyssState.commit()
				return false
			m.utility.append(symbol)
		"prism":
			if symbol==0: m.angle=(int(m.angle)+1)%3; m.confirmed=false
			else: m.confirmed=true; Events.notice.emit("测得光轴%d；本轮应为%d。" % [m.angle,0 if int(m.round)==0 else 2])
		_:
			if symbol in m.utility: return false
			m.utility.append(symbol)
	if not AbyssState.layout().has("passage_cells") and ready() and int(AbyssState.state.depth) not in AbyssState.state.shortcuts:
		AbyssState.state.shortcuts.append(int(AbyssState.state.depth))
		Events.navigation_changed.emit()
	AbyssState.commit()
	return true
static func ready() -> bool:
	var d: int=AbyssState.state.depth
	if d<=20: return true
	var m := meta()
	if d%20==0:
		for previous in range(20,d,20):
			if previous not in AbyssState.state.bosses: return false
	match AbyssState.layout().rule:
		"prism": return m.confirmed and int(m.angle)==(0 if int(m.round)==0 else 2)
		_: return m.utility.size()==2
static func finish_round() -> bool:
	if AbyssState.state.depth<=20: return true
	var m := meta()
	if int(m.round)+1<int(AbyssState.layout().rounds):
		m.round+=1
		m.utility=[]
		m.angle=0
		m.confirmed=false
		Events.notice.emit("第一组回路已接通。按刻痕复核下一轮的阀门、光轴或双端记录。")
		return false
	return true
static func clear_depth(depth: int) -> void:
	if depth%20==0 and depth not in AbyssState.state.bosses: AbyssState.state.bosses.append(depth)
	if "gate"+str(depth) in ChapterTwo.allowed_facts(): River.record("gate"+str(depth))
	River.observe_depth(depth)
static func inspect_text() -> String:
	if AbyssState.state.depth<=20: return ""
	var round_id: int=meta().round+1
	return {"water":"本轮先操作泄压台，再操作导流台；两轮之间重新操作。","prism":"旋光台转动0→1→2→0，测量台确认；第一轮光轴0，后轮光轴2。","rubbing":"亲访值班碑与撤离碑拓印，再操作分工手柄。每轮使用两份独立记录。","beacon":"先连接风水端与灯路端信标，再按四座分工台回应；每轮重新核对。"}.get(AbyssState.layout().rule,"")+"\n当前第%d/%d轮" % [round_id,AbyssState.layout().rounds]
static func hazard_at(cell: Vector2i) -> void:
	var d: int=AbyssState.state.depth
	var id := "%d:%d,%d" % [d,cell.x,cell.y]
	if [cell.x,cell.y] not in AbyssState.layout().hazards or id in AbyssState.state.hazards: return
	if not AbyssState.state.warnings.has(id):
		AbyssState.state.warnings[id]=GameClock.day*1440+GameClock.minutes
		Events.notice.emit("前方%s：地面已标记。可绕行；检查辅助台可开放安全侧路。" % AbyssState.layout().hazard_type)
		return
	if GameClock.day*1440+GameClock.minutes-float(AbyssState.state.warnings[id])<1: return
	AbyssState.state.hazards.append(id)
	if d not in AbyssState.state.safety:
		GameState.stamina=maxi(0,GameState.stamina-maxi(1,5-int(AbyssState.state.gear)))
		if AbyssState.layout().rule in ["water","prism","beacon"]: AbyssState.state.air=maxi(0,int(AbyssState.state.air)-{"water":4,"prism":6,"beacon":8}[AbyssState.layout().rule])
		if AbyssState.layout().rule=="rubbing": AbyssState.game.auto_move.cancel()
		GameState.changed.emit()

static func secure() -> bool:
	var depth: int=AbyssState.state.depth
	if not AbyssState.near("up") or depth in AbyssState.state.safety or not Inventory.exchange({"wood":1,"crystal":1},{},0): return false
	AbyssState.state.safety.append(depth)
	AbyssState.commit()
	Events.notice.emit("护栏、滤网与灯罩已固定。本层预警区有了安全通过方案。")
	return true

static func utility_title(symbol: int) -> String:
	var names: Array={"water":["泄压台","导流台"],"prism":["旋光台","测量台"],"rubbing":["值班碑","撤离碑"],"beacon":["风水端","灯路端"]}.get(AbyssState.layout().rule,["辅助台","辅助台"])
	return names[clampi(symbol,0,1)]

static func open_passage() -> bool:
	var depth: int=AbyssState.state.depth
	if not AbyssState.near("passage") or depth in AbyssState.state.shortcuts or not AbyssState.layout().has("passage_cells"): return false
	if not Inventory.exchange({"wood":2},{},0): return false
	AbyssState.state.shortcuts.append(depth)
	AbyssState.commit()
	Events.navigation_changed.emit()
	return true
