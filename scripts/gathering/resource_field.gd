extends Node2D
## 采集规则集中在此，防止重复掉落；存档包括剩余耐久和再生日期。
const RESOURCE_NODE = preload("res://scripts/gathering/resource_node.gd")
var state: Dictionary = {}
var objects: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	var placements := FarmResourceCatalog.placements()
	for id in placements:
		var entry: Dictionary = placements[id]
		state[id] = {"hp":int(FarmResourceCatalog.TYPES[entry.kind].hits),"ready_day":0}
		var object := StaticBody2D.new()
		object.set_script(RESOURCE_NODE)
		object.resource_id = id
		object.kind = entry.kind
		object.field = self
		object.position = Vector2(entry.cell)*32
		objects[id] = object
		add_child(object)
	GameClock.day_advanced.connect(advance_day)

func find_target(origin: Vector2, facing: Vector2) -> Node2D:
	var found: Node2D
	var distance: float = 55.0
	for object in objects.values():
		if state[object.resource_id].hp == 0: continue
		var offset: Vector2 = object.global_position-origin
		if offset.length() < distance and facing.dot(offset.normalized()) > 0.1:
			found = object
			distance = offset.length()
	return found

func highlight(target: Node2D) -> void:
	for object in objects.values(): object.set_highlight(object == target)

func hit(id: String, tool: String) -> bool:
	if not objects.has(id): return false
	var data: Dictionary = state[id]
	var definition: Dictionary = FarmResourceCatalog.TYPES[objects[id].kind]
	if data.hp == 0:
		Events.notice.emit("这里正在恢复，过几天再来看看。")
		return false
	if tool != definition.tool:
		Events.notice.emit("树木要用斧头，石堆要用镐。")
		return false
	var damage: int = 2 if FarmProgress.has_upgrade("toolrack") else 1
	if data.hp <= damage and Inventory.count(definition.item)+int(definition.amount) > Inventory.MAX_STACK:
		Events.notice.emit("材料背包已满，先去摊位出售一些吧。")
		return false
	if not GameState.spend_energy(definition.energy): return false
	data.hp = maxi(0,int(data.hp)-damage)
	if data.hp == 0:
		data.ready_day = GameClock.day+int(definition.regrow)
		Inventory.add(definition.item,definition.amount)
		Xiaojing.on_gather(definition.item,int(definition.amount))
		Events.notice.emit("获得%s ×%d；%d 天后这里会恢复。" % [Catalog.item_name(definition.item),definition.amount,definition.regrow])
	Events.resource_hit.emit(data.hp == 0)
	objects[id].hit_feedback()
	return true

func advance_day() -> void:
	for id in state:
		var data: Dictionary = state[id]
		if data.hp == 0 and GameClock.day >= data.ready_day and objects[id].can_regrow():
			data.hp = int(FarmResourceCatalog.TYPES[objects[id].kind].hits)
			data.ready_day = 0
			objects[id].refresh()

func restore(data: Dictionary) -> void:
	for id in state:
		var maximum: int = FarmResourceCatalog.TYPES[objects[id].kind].hits
		var record: Dictionary = data.get(id,{"hp":maximum,"ready_day":0})
		state[id] = {"hp":int(record.hp),"ready_day":int(record.ready_day)}
		objects[id].refresh()
