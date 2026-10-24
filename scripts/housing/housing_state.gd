extends Node
## 布置专用区与原必经路分离。库存、布局、样式和储物只在本层原子提交。
signal changed
const HOME := Vector2(384,496)
const YARD := Vector2(464,752)
const SLOTS := [0,2,4,8]
const HOME_RECTS := [Rect2i(),Rect2i(12,10,2,4),Rect2i(12,10,4,4),Rect2i(12,10,4,6)]
const EXTENSION_RECTS := [Rect2i(),Rect2i(),Rect2i(8,13,2,3),Rect2i(5,9,5,7)]
const YARD_RECT := Rect2i(10,20,4,4)
const MAX_PLACED: int=40
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/housing/housing.json")))
	state=defaults()
	GameClock.day_advanced.connect(func(): changed.emit())
	GameState.control_mode_changed.connect(func(): changed.emit())

func defaults(_day: int = GameClock.day) -> Dictionary:
	return {"level":1,"owned":{},"placed":[],"serial":0,"storage":{},"appearance":{"wallpaper":"plain","floor":"plain"},"flowers":{}}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit();Events.navigation_changed.emit()
func slot_count() -> int: return SLOTS[int(state.level)]
func near(area: String = GameState.location) -> bool:
	if not is_instance_valid(game): return false
	if area=="home": return GameState.location=="home" and game.player.global_position.distance_to(HOME)<=54
	if area in ["farm","yard"]: return GameState.location=="farm" and game.player.global_position.distance_to(YARD)<=54
	return false
func placement(id: String) -> Dictionary:
	for entry in state.placed:
		if entry.id==id: return entry
	return {}
func has_furniture(kind: String) -> bool:
	if int(state.owned.get(kind,0))>0: return true
	for entry in state.placed:
		if entry.kind==kind: return true
	return false
func near_item(id: String) -> bool:
	var entry := placement(id)
	if entry.is_empty() or not is_instance_valid(game) or GameState.location!=entry.area: return false
	return game.player.global_position.distance_to(center(entry.kind,Vector2i(entry.cell[0],entry.cell[1])))<=54
func can_manage(area: String, id: String = "") -> bool: return near(area) or (id!="" and near_item(id))
func unlocked(kind: String) -> bool:
	return data.furniture.has(kind) and state.level>=data.furniture[kind].level and (not data.furniture[kind].get("married",false) or Xiaojing.state.married)
func area_rect(area: String, level: int = int(state.level)) -> Rect2i:
	return HOME_RECTS[level] if area=="home" else YARD_RECT if area=="farm" else Rect2i()
func allowed_rect(rect: Rect2i, area: String, level: int = int(state.level)) -> bool:
	return area_rect(area,level).encloses(rect) or (area=="home" and level>=2 and EXTENSION_RECTS[level].encloses(rect))
func layout_rects(area: String) -> Array[Rect2i]:
	var result: Array[Rect2i]=[area_rect(area)]
	if area=="home" and state.level>=2: result.append(EXTENSION_RECTS[int(state.level)])
	return result
func footprint(kind: String, cell: Vector2i) -> Rect2i:
	var size: Array=data.furniture[kind].size
	return Rect2i(cell,Vector2i(size[0],size[1]))
func center(kind: String, cell: Vector2i) -> Vector2:
	var rect := footprint(kind,cell)
	return Vector2(rect.position)*32+Vector2(rect.size)*16
func _exchange(required: Dictionary, rewards: Dictionary, coins: int = 0) -> bool:
	if busy or GameClock.settling: return false
	busy=true
	if not Inventory.exchange(required,rewards,coins): busy=false;return false
	return true
func _commit(nav: bool = false) -> void:
	changed.emit()
	if nav: Events.navigation_changed.emit()
	Events.progress_committed.emit();busy=false
func upgrade(expected_level: int = -1) -> bool:
	if busy or not near("home") or state.level>=3 or (expected_level!=-1 and state.level!=expected_level): return false
	var entry: Dictionary=data.levels[str(int(state.level)+1)]
	if not _exchange(entry.required,{},-int(entry.coins)): return false
	state.level+=1;_commit();return true
func buy(kind: String, quantity: int = 1) -> bool:
	if busy or not (near("home") or near("farm")) or not unlocked(kind) or quantity<1 or quantity>20 or int(state.owned.get(kind,0))+quantity>99: return false
	var entry: Dictionary=data.furniture[kind]
	var required := {}
	for item in entry.required: required[item]=int(entry.required[item])*quantity
	if not _exchange(required,{},-int(entry.coins)*quantity): return false
	state.owned[kind]=int(state.owned.get(kind,0))+quantity
	_commit();return true
func can_place(kind: String, area: String, cell: Vector2i, except_id: String = "", check_physics: bool = true) -> bool:
	if not unlocked(kind) or data.furniture[kind].area!=area: return false
	var bounds := area_rect(area)
	var rect := footprint(kind,cell)
	if not allowed_rect(rect,area): return false
	# 管理台周围留白；原床/门/厨房/木盒不在允许区，永不能放置。
	if area=="home" and rect.has_point(Vector2i(12,15)): return false
	for entry in state.placed:
		if entry.area!=area or entry.id==except_id: continue
		if footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1])).intersects(rect): return false
	if not check_physics or not is_instance_valid(game): return true
	if GameState.location!=area: return false
	var desired: Rect2=Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32)
	# 放置不允许把玩家包住；无碰撞地毯、道路可铺在脚下。
	if data.furniture[kind].solid and desired.grow(10).has_point(game.player.global_position): return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new();shape.size=desired.size-Vector2(4,4)
	query.shape=shape;query.transform=Transform2D(0,desired.get_center());query.collision_mask=1
	if except_id!="":
		for object in get_tree().get_nodes_in_group("housing_furniture"):
			if object.housing_id==except_id: query.exclude=game.auto_move.navigation.collider_rids(object)
	return game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func place(kind: String, area: String, cell: Vector2i) -> bool:
	if busy or GameClock.settling or not near(area) or state.serial>=999999 or state.placed.size()>=MAX_PLACED or int(state.owned.get(kind,0))<1 or not can_place(kind,area,cell): return false
	busy=true;state.owned[kind]-=1
	if state.owned[kind]==0: state.owned.erase(kind)
	state.serial+=1;state.placed.append({"id":"furniture_%06d" % int(state.serial),"kind":kind,"area":area,"cell":[cell.x,cell.y]})
	_commit(true);return true
func move(id: String, cell: Vector2i) -> bool:
	var entry := placement(id)
	if busy or GameClock.settling or entry.is_empty() or not can_manage(entry.area,id) or not can_place(entry.kind,entry.area,cell,id): return false
	busy=true;entry.cell=[cell.x,cell.y];_commit(true);return true
func recycle(id: String) -> bool:
	var entry := placement(id)
	if busy or GameClock.settling or entry.is_empty() or state.flowers.has(id) or not can_manage(entry.area,id) or int(state.owned.get(entry.kind,0))>=99: return false
	busy=true;state.owned[entry.kind]=int(state.owned.get(entry.kind,0))+1
	state.placed.erase(entry);_commit(true);return true
func apply_style(kind: String) -> bool:
	if busy or GameClock.settling or not near("home") or not unlocked(kind) or kind not in ["wallpaper","floor"] or int(state.owned.get(kind,0))<1: return false
	busy=true;state.appearance[kind]=kind;_commit();return true
func clear_style(kind: String) -> bool:
	if busy or GameClock.settling or not near("home") or kind not in ["wallpaper","floor"] or state.appearance[kind]=="plain": return false
	busy=true;state.appearance[kind]="plain";_commit();return true
func deposit(item: String, quantity: int) -> bool:
	if busy or not near("home") or not Catalog.is_item(item) or quantity<1 or quantity>999 or int(state.storage.get(item,0))+quantity>999: return false
	if not state.storage.has(item) and state.storage.size()>=slot_count(): return false
	if not _exchange({item:quantity},{}): return false
	state.storage[item]=int(state.storage.get(item,0))+quantity;_commit();return true
func withdraw(item: String, quantity: int) -> bool:
	if busy or not near("home") or not Catalog.is_item(item) or quantity<1 or quantity>int(state.storage.get(item,0)): return false
	if not _exchange({},{item:quantity}): return false
	state.storage[item]-=quantity
	if state.storage[item]==0: state.storage.erase(item)
	_commit();return true
func validate(raw: Variant, _day: int) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults().keys()) or not FarmSaveSchema.whole(raw.level,1,3) or not FarmSaveSchema.whole(raw.serial,0,999999): return false
	if not raw.owned is Dictionary or raw.owned.size()>data.furniture.size() or not raw.storage is Dictionary or raw.storage.size()>SLOTS[int(raw.level)]: return false
	for kind in raw.owned:
		if not data.furniture.has(kind) or not FarmSaveSchema.whole(raw.owned[kind],1,99) or data.furniture[kind].level>raw.level: return false
	for item in raw.storage:
		if not Catalog.is_item(item) or not FarmSaveSchema.whole(raw.storage[item],1,999): return false
	if not AquacultureSaveSchema.exact(raw.appearance,["wallpaper","floor"]): return false
	for kind in raw.appearance:
		if raw.appearance[kind] not in ["plain",kind] or (raw.appearance[kind]==kind and int(raw.owned.get(kind,0))<1): return false
	if not raw.placed is Array or raw.placed.size()>MAX_PLACED: return false
	var seen := {};var occupied := {"home":[],"farm":[]}
	for entry in raw.placed:
		if not AquacultureSaveSchema.exact(entry,["id","kind","area","cell"]) or not entry.id is String or not entry.id.begins_with("furniture_"): return false
		var suffix: String=entry.id.trim_prefix("furniture_")
		if not suffix.is_valid_int() or not FarmSaveSchema.whole(int(suffix),1,int(raw.serial)) or entry.id!="furniture_%06d" % int(suffix) or seen.has(entry.id): return false
		seen[entry.id]=true
		if not data.furniture.has(entry.kind) or entry.area not in occupied or data.furniture[entry.kind].area!=entry.area or data.furniture[entry.kind].level>raw.level: return false
		if not entry.cell is Array or entry.cell.size()!=2 or not FarmSaveSchema.whole(entry.cell[0],0,47) or not FarmSaveSchema.whole(entry.cell[1],0,31): return false
		var rect := footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
		if not allowed_rect(rect,entry.area,int(raw.level)) or (entry.area=="home" and rect.has_point(Vector2i(12,15))): return false
		for old in occupied[entry.area]:
			if old.intersects(rect): return false
		occupied[entry.area].append(rect)
	if not raw.flowers is Dictionary or raw.flowers.size()>MAX_PLACED: return false
	for id in raw.flowers:
		if not id is String or not FarmSaveSchema.whole(raw.flowers[id],1,_day): return false
		var found := false
		for entry in raw.placed:
			if entry.id==id and entry.kind=="flower" and entry.area=="farm": found=true;break
		if not found: return false
	return true

func flower_age(id: String) -> int:
	return maxi(0,GameClock.day-int(state.flowers[id])) if state.flowers.has(id) else -1
func sow_flower(id: String) -> bool:
	var entry := placement(id)
	if busy or GameClock.settling or entry.is_empty() or entry.kind!="flower" or entry.area!="farm" or not near_item(id) or state.flowers.has(id) or GameState.stamina<Kitchen.energy_cost(1): return false
	if not _exchange({"spring_bloom_seed":1},{}): return false
	GameState.spend_energy(1);state.flowers[id]=GameClock.day;_commit();return true
func harvest_flower(id: String) -> bool:
	if busy or GameClock.settling or not near_item(id) or flower_age(id)<3: return false
	if not _exchange({},{"spring_bloom":1}): return false
	state.flowers.erase(id);_commit();return true
func uproot_flower(id: String) -> bool:
	if busy or GameClock.settling or not near_item(id) or not state.flowers.has(id): return false
	if not _exchange({},{"spring_bloom_seed":1}): return false
	state.flowers.erase(id);_commit();return true
