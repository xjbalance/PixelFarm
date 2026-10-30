extends Node2D
## 采集规则集中在此，防止重复掉落；存档包括剩余耐久和再生日期。
const RESOURCE_NODE = preload("res://scripts/gathering/resource_node.gd")
var area_id: String = "farm"
var state: Dictionary = {}
var objects: Dictionary = {}
var busy: bool = false

func _ready() -> void:
	y_sort_enabled = true
	var placements := FarmResourceCatalog.placements(area_id)
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
	if area_id=="farm": FarmLayout.changed.connect(refresh_layout)
	refresh_layout()

func refresh_layout() -> void:
	if area_id!="farm": return
	for id in objects:
		var object: Node2D=objects[id]
		var at:=FarmResourceCatalog.point(str(id))
		var stored: bool=FarmResourceCatalog.stored(str(id))
		if object.position==at and bool(object.get_meta("layout_stored",false))==stored: continue
		object.position=at;object.set_meta("layout_stored",stored);object.highlighted=false;object.refresh()

func find_target(origin: Vector2, facing: Vector2) -> Node2D:
	var found: Node2D
	var distance: float = 55.0
	for object in objects.values():
		if state[object.resource_id].hp == 0 or object.is_stored(): continue
		var offset: Vector2 = object.global_position-origin
		if offset.length() < distance and facing.dot(offset.normalized()) > 0.1:
			found = object
			distance = offset.length()
	return access_target(found) if found else null

func access_target(object: Node2D) -> Node2D:
	# The old cosmetic bush at the south lake edge overlaps an original stone.
	# Preserve both old coordinates, and clear the reachable natural blocker first.
	for other in objects.values():
		if other==object or int(state[other.resource_id].hp)<=0 or other.is_stored() or other.collision_layer & 1 == 0 or other.collider.disabled: continue
		var footprint: Rect2=other.collider.global_transform*other.collider.shape.get_rect()
		if footprint.has_point(object.global_position): return other
	return object

func highlight(target: Node2D) -> void:
	for object in objects.values(): object.set_highlight(object == target)

func hit(id: String, tool: String) -> bool:
	if busy or not objects.has(id): return false
	if objects[id].is_stored(): return false
	var data: Dictionary = state[id]
	var definition: Dictionary = FarmResourceCatalog.TYPES[objects[id].kind]
	if data.hp == 0:
		Events.notice.emit("这片土地已永久清理，可以自由规划。" if area_id=="farm" else "这里正在恢复，过几天再来看看。")
		return false
	if tool != definition.tool:
		Events.notice.emit("清理%s需要%s。" % [definition.name,{"axe":"斧头","pickaxe":"镐子","hoe":"锄头"}.get(str(definition.tool),"正确工具")])
		return false
	if str(definition.get("required_upgrade",""))!="" and not FarmProgress.has_upgrade(str(definition.required_upgrade)):
		Events.notice.emit("大石堆需要先在修缮工台建好工具架，升级镐子后再清理。")
		return false
	var damage: int = 2 if FarmProgress.has_upgrade("toolrack") else 1
	if data.hp <= damage and Inventory.count(definition.item)+int(definition.amount) > Inventory.MAX_STACK:
		Events.notice.emit("材料背包已满，先去摊位出售一些吧。")
		return false
	# 体力与背包通知会同步回调UI，同一次工具提交期间不接受嵌套采集。
	busy=true
	if not GameState.spend_energy(definition.energy): busy=false;return false
	data.hp = maxi(0,int(data.hp)-damage)
	if data.hp == 0:
		data.ready_day = 0 if area_id=="farm" else GameClock.day+int(definition.regrow)
		Inventory.add(definition.item,definition.amount)
		Xiaojing.on_gather(definition.item,int(definition.amount))
		Events.notice.emit("获得%s ×%d；土地已永久清理。" % [Catalog.item_name(definition.item),definition.amount] if area_id=="farm" else "获得%s ×%d；%d 天后这里会恢复。" % [Catalog.item_name(definition.item),definition.amount,definition.regrow])
	Events.resource_hit.emit(data.hp == 0)
	objects[id].hit_feedback()
	Events.progress_committed.emit()
	busy=false
	return true

func advance_day() -> void:
	if area_id=="farm": return # Cleared private land never regrows automatically.
	for id in state:
		var data: Dictionary = state[id]
		if data.hp == 0 and GameClock.day >= data.ready_day and objects[id].can_regrow():
			data.hp = int(FarmResourceCatalog.TYPES[objects[id].kind].hits)
			data.ready_day = 0
			objects[id].refresh()

func restore(data: Dictionary) -> void:
	busy=false
	for id in state:
		var maximum: int = FarmResourceCatalog.TYPES[objects[id].kind].hits
		var record: Dictionary = data.get(id,{"hp":maximum,"ready_day":0})
		state[id] = {"hp":int(record.hp),"ready_day":0 if area_id=="farm" else int(record.ready_day)}
		# Old replaceable bushes could already have furniture painted over them.
		if str(id).begins_with("brush_original_") and not data.has(id) and Territory.edited_cell("farm",Vector2i((FarmResourceCatalog.point(str(id))/32).floor())): state[id].hp=0
		objects[id].refresh()
	refresh_layout()
