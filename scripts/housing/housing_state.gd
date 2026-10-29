extends Node
## 布置专用区与原必经路分离。库存、布局、样式和储物只在本层原子提交。
signal changed
const HOME := Vector2(384,496)
const YARD := Vector2(464,752)
const SLOTS := [0,2,4,8,16]
const HOME_RECTS := [Rect2i(),Rect2i(12,10,2,4),Rect2i(12,10,4,4),Rect2i(12,10,4,6),Rect2i(12,10,4,6)]
const EXTENSION_RECTS := [Rect2i(),Rect2i(),Rect2i(8,13,2,3),Rect2i(5,9,5,7),Rect2i(3,8,7,9)]
const YARD_RECT := Rect2i(10,20,4,4)
const MAX_PLACED: int=40
const LEGACY_FIELDS := ["level","owned","placed","serial","storage","appearance","flowers"]
var data: Dictionary={}
var state: Dictionary={}
var game: Node
var busy: bool=false

func _ready() -> void:
	data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/housing/housing.json")))
	state=defaults()
	GameClock.day_advanced.connect(settle_day)
	GameState.control_mode_changed.connect(func(): changed.emit())

func defaults(day: int = GameClock.day) -> Dictionary:
	return {"level":1,"owned":{},"placed":[],"serial":0,"storage":{},"appearance":{"wallpaper":"plain","floor":"plain"},"flowers":{},"construction":{},"upgrade_serial":0,"completed_jobs":[],"last_settled_day":day,"recovered":[],"builtins":HomeLayout.default_builtins(1)}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit();Events.navigation_changed.emit()
func slot_count() -> int: return SLOTS[int(state.level)]
func anchor(action: String) -> Vector2:
	return HomeLayout.anchor(action,int(state.level),state.builtins)
func can_arrange() -> bool:
	return is_instance_valid(game) and GameState.location=="home" and not game.backgrounded and not game.closing and not GameState.restoring and not GameClock.settling and not game.player.suspended and game.player.action_time<=0
func builtin_layout() -> Array[Dictionary]:
	return HomeLayout.builtin_layout(int(state.level),state.builtins)
func builtin_geometry(id: String) -> Dictionary:
	return HomeLayout.builtin_geometry(id,state.builtins[id],int(state.level)) if state.builtins.has(id) else {}
func builtin(id: String) -> Dictionary: return builtin_geometry(id)
func _placed_obstacles(entries: Array) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for entry in entries:
		if entry.area=="home" and data.furniture[entry.kind].solid:
			var rect:=footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
			result.append(Rect2(Vector2(rect.position)*32+Vector2(2,2),Vector2(rect.size)*32-Vector2(4,4)))
	return result
func layout_routes_valid(raw: Dictionary={}) -> bool:
	var source: Dictionary=state if raw.is_empty() else raw
	return HomeLayout.routes_valid(int(source.level),source.builtins,_placed_obstacles(source.placed))
func _builtin_fits(id: String, record: Dictionary, level: int, records: Dictionary, entries: Array=[]) -> bool:
	var item:=HomeLayout.builtin_geometry(id,record,level)
	if item.is_empty(): return false
	if item.stored: return id not in HomeLayout.ESSENTIAL
	var bounds: Rect2=item.collision if item.solid else item.footprint
	if not HomeLayout.floor_encloses(bounds,level): return false
	if not item.solid: return true
	for obstacle in HomeLayout.structure_rects(level):
		if item.collision.intersects(obstacle): return false
	for other in HomeLayout.builtin_layout(level,records):
		if other.id!=id and other.solid and not other.stored and item.collision.intersects(other.collision): return false
	for obstacle in _placed_obstacles(entries):
		if item.collision.intersects(obstacle): return false
	return true
func can_move_builtin(id: String, cell: Vector2i, check_routes: bool=true) -> bool:
	if not state.builtins.has(id) or cell.x<0 or cell.y<0 or cell.x>47 or cell.y>31: return false
	var records: Dictionary=state.builtins.duplicate(true);records[id]={"cell":[cell.x,cell.y]}
	if not _builtin_fits(id,records[id],int(state.level),records,state.placed): return false
	if not check_routes: return true
	var item:=HomeLayout.builtin_geometry(id,records[id],int(state.level))
	if item.solid and is_instance_valid(game) and GameState.location=="home" and item.collision.grow(10).has_point(game.player.global_position): return false
	return HomeLayout.routes_valid(int(state.level),records,_placed_obstacles(state.placed),game.player.global_position if is_instance_valid(game) and GameState.location=="home" else Vector2.INF)
func move_builtin(id: String, cell: Vector2i, expected_cell: Vector2i=Vector2i(-1,-1)) -> bool:
	if busy or not can_arrange() or not state.builtins.has(id): return false
	var current:=Vector2i(state.builtins[id].cell[0],state.builtins[id].cell[1])
	if expected_cell!=Vector2i(-1,-1) and expected_cell!=current: return false
	if current==cell and not state.builtins[id].get("stored",false): return false
	if not can_move_builtin(id,cell): return false
	busy=true;state.builtins[id]={"cell":[cell.x,cell.y]};_commit(true);return true
func _reconciled_builtins(raw: Dictionary) -> Dictionary:
	var level: int=int(raw.level);var defaults: Dictionary=HomeLayout.default_builtins(level)
	var previous: Dictionary=raw.get("builtins",{});var result: Dictionary={}
	for id in defaults: result[id]={"cell":defaults[id].cell.duplicate(),"stored":true}
	var ordered: Array=HomeLayout.ESSENTIAL.duplicate()
	for id in defaults:
		if id not in ordered: ordered.append(id)
	for id in ordered:
		var original: Dictionary=previous.get(id,defaults[id]).duplicate(true)
		if original.get("stored",false) and id not in HomeLayout.ESSENTIAL: result[id]=original;continue
		original.erase("stored");result[id]=original
		var fits: bool=_builtin_fits(id,original,level,result)
		# 关键物件先全部放好，再判断装饰是否挡住操作和原剧情点。
		if fits and id not in HomeLayout.ESSENTIAL: fits=HomeLayout.routes_valid(level,result)
		if fits: continue
		result[id]={"cell":original.cell.duplicate(),"stored":true}
		var origin:=Vector2i(original.cell[0],original.cell[1]);var candidates: Array[Vector2i]=[]
		for region in HomeLayout.placement_regions(level):
			for y in range(region.position.y,region.end.y):
				for x in range(region.position.x,region.end.x): candidates.append(Vector2i(x,y))
		candidates.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(origin)<b.distance_squared_to(origin))
		for cell in candidates:
			var candidate: Dictionary={"cell":[cell.x,cell.y]};result[id]=candidate
			if _builtin_fits(id,candidate,level,result) and (id in HomeLayout.ESSENTIAL or HomeLayout.routes_valid(level,result)): break
			result[id]={"cell":original.cell.duplicate(),"stored":true}
		if result[id].get("stored",false) and id in HomeLayout.ESSENTIAL:
			# 已验证旧版关键物件默认几何总有位置；不删除生活功能。
			result[id]=defaults[id].duplicate(true)
	return result

func level_name(level: int = -1) -> String:
	return str(data.levels[str(int(state.level) if level<0 else clampi(level,1,4))].name)
func near_builder() -> bool:
	if not is_instance_valid(game) or GameState.location!="village": return false
	if MineState.near_service("forge"): return true
	for person in get_tree().get_nodes_in_group("interactables"):
		if "person_id" not in person or person.person_id!="zhou" or not person.is_visible_in_tree(): continue
		if game.player.global_position.distance_to(person.global_position)<=76 and game.auto_move.navigation.line_of_sight(game.player.global_position,person.global_position,person): return true
	return false
func preview_upgrade() -> Dictionary:
	if int(state.level)>=4: return {}
	var target: int=int(state.level)+1
	var result: Dictionary=data.levels[str(target)].duplicate(true)
	result.current_level=int(state.level);result.from_level=int(state.level);result.target_level=target;result.days=2
	result.pending=not state.construction.is_empty()
	result.affordable=Inventory.coins>=int(result.coins) and not Inventory.diamond_payment
	for item in result.required:
		result.affordable=result.affordable and Inventory.count(item)>=int(result.required[item])
	result.can_request=not busy and not GameClock.settling and not result.pending and near_builder() and result.affordable and GameClock.day<=999997
	return result
func construction_progress() -> Dictionary:
	if state.construction.is_empty(): return {"active":false,"current_level":int(state.level),"name":level_name()}
	var result: Dictionary=state.construction.duplicate(true)
	result.active=true;result.current_level=int(state.level);result.name=level_name(int(result.target_level))
	result.days=2;result.elapsed_days=clampi(GameClock.day-int(result.started_day),0,2)
	result.remaining_days=maxi(0,int(result.ready_day)-GameClock.day)
	return result
func settle_day() -> void:
	# 日信号在GameClock.settling期间发出；本层不再次推进日期。
	if busy or GameClock.day<=int(state.last_settled_day): return
	busy=true;state.last_settled_day=GameClock.day
	var completed: bool=not state.construction.is_empty() and GameClock.day>=int(state.construction.ready_day)
	if completed:
		var job: Dictionary=state.construction
		state.level=int(job.target_level);state.completed_jobs.append(int(job.job_id));state.construction={}
		var layout:=reconciled_furniture(state)
		state.placed=layout.placed;state.recovered=layout.recovered;state.builtins=layout.builtins
	_commit(completed)
	if completed: Events.notice.emit("周砚完成了住宅改建：%s。家具和柜中物品已保留。" % level_name())
func near(area: String = GameState.location) -> bool:
	if not is_instance_valid(game): return false
	if area=="home": return GameState.location=="home" and game.player.global_position.distance_to(anchor("storage"))<=54
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
	return HomeLayout.main_cells() if area=="home" else YARD_RECT if area=="farm" else Rect2i()
func allowed_rect(rect: Rect2i, area: String, level: int = int(state.level)) -> bool:
	return area_rect(area,level).encloses(rect) or (area=="home" and level>=2 and HomeLayout.extension_cells(level).encloses(rect))
func layout_rects(area: String) -> Array[Rect2i]:
	var result: Array[Rect2i]=[area_rect(area)]
	if area=="home" and state.level>=2: result.append(HomeLayout.extension_cells(int(state.level)))
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
	if busy or GameClock.settling or Inventory.diamond_payment or not near_builder() or state.level>=4 or not state.construction.is_empty() or GameClock.day>999997 or (expected_level!=-1 and state.level!=expected_level): return false
	var entry: Dictionary=data.levels[str(int(state.level)+1)]
	# 住宅只收金币，不借用其他商店同步交易中的钻石支付开关。
	if Inventory.coins<int(entry.coins): return false
	if not _exchange(entry.required,{},-int(entry.coins)): return false
	state.upgrade_serial+=1
	state.construction={"from_level":int(state.level),"target_level":int(state.level)+1,"started_day":GameClock.day,"ready_day":GameClock.day+2,"job_id":int(state.upgrade_serial)}
	_commit();return true
func recovery_items() -> Array:
	return state.recovered.duplicate(true)
func _home_obstacles(level: int, builtins: Dictionary={}) -> Array[Rect2]:
	return HomeLayout.blocked_rects(level,builtins)
func _home_cell_safe(kind: String, cell: Vector2i, level: int, occupied: Array[Rect2i], obstacles: Array[Rect2]) -> bool:
	var rect:=footprint(kind,cell)
	if not allowed_rect(rect,"home",level): return false
	var world_rect:=Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32)
	if data.furniture[kind].solid:
		for obstacle in obstacles:
			if world_rect.grow(-2).intersects(obstacle): return false
	for old in occupied:
		if old.intersects(rect): return false
	return true
func _owned_routes(entry: Dictionary, resolved: Dictionary, level: int, builtins: Dictionary) -> bool:
	if not data.furniture[entry.kind].solid: return true
	var entries: Array=resolved.values();entries.append(entry)
	return HomeLayout.routes_valid(level,builtins,_placed_obstacles(entries))
func reconciled_furniture(raw: Dictionary) -> Dictionary:
	# 纯数据迁移，不查询当前活动地图的物理世界，村庄施工完工也能安全整理室内。
	var level: int=int(raw.level)
	var builtins:=_reconciled_builtins(raw)
	var obstacles:=_home_obstacles(level,builtins)
	var occupied: Array[Rect2i]=[]
	var resolved: Dictionary={}
	var conflicts: Array[Dictionary]=[]
	var recovered: Array=raw.recovered.duplicate(true)
	# 先保留所有原位可用家具；迁走的家具不能抢占后面那件本来安全的位置。
	for entry in raw.placed:
		var cell:=Vector2i(entry.cell[0],entry.cell[1])
		if entry.area!="home": resolved[entry.id]=entry.duplicate(true)
		elif _home_cell_safe(entry.kind,cell,level,occupied,obstacles) and _owned_routes(entry,resolved,level,builtins):
			resolved[entry.id]=entry.duplicate(true);occupied.append(footprint(entry.kind,cell))
		else: conflicts.append(entry)
	var areas: Array[Rect2i]=HomeLayout.placement_regions(level)
	for entry in conflicts:
		var origin:=Vector2i(entry.cell[0],entry.cell[1])
		var nearest:=Vector2i(-1,-1)
		var best_distance: int=2147483647
		for area in areas:
			for y in range(area.position.y,area.end.y):
				for x in range(area.position.x,area.end.x):
					var candidate:=Vector2i(x,y)
					if not _home_cell_safe(entry.kind,candidate,level,occupied,obstacles): continue
					var preview: Dictionary=entry.duplicate(true);preview.cell=[candidate.x,candidate.y]
					if not _owned_routes(preview,resolved,level,builtins): continue
					var distance: int=origin.distance_squared_to(candidate)
					if distance<best_distance: nearest=candidate;best_distance=distance
		if nearest.x>=0:
			var moved: Dictionary=entry.duplicate(true);moved.cell=[nearest.x,nearest.y]
			resolved[entry.id]=moved;occupied.append(footprint(entry.kind,nearest))
		else: recovered.append(entry.duplicate(true))
	var placed: Array=[]
	for entry in raw.placed:
		if resolved.has(entry.id): placed.append(resolved[entry.id])
	return {"placed":placed,"recovered":recovered,"builtins":builtins}
func reconcile_layout() -> bool:
	if busy or GameClock.settling: return false
	var layout:=reconciled_furniture(state)
	if layout.placed==state.placed and layout.recovered==state.recovered and layout.builtins==state.builtins: return false
	busy=true;state.placed=layout.placed;state.recovered=layout.recovered;state.builtins=layout.builtins;_commit(true);return true
func recover_furniture(id: String) -> bool:
	if busy or GameClock.settling or not near("home"): return false
	for entry in state.recovered:
		if entry.id!=id: continue
		if int(state.owned.get(entry.kind,0))>=99: return false
		busy=true;state.owned[entry.kind]=int(state.owned.get(entry.kind,0))+1
		state.recovered.erase(entry);_commit();return true
	return false
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
	if area=="home" and not _home_cell_safe(kind,cell,int(state.level),[],_home_obstacles(int(state.level),state.builtins)): return false
	for entry in state.placed:
		if entry.area!=area or entry.id==except_id: continue
		if footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1])).intersects(rect): return false
	if area=="home":
		if data.furniture[kind].solid:
			var records: Array=state.placed.duplicate(true)
			for old in records.duplicate():
				if old.id==except_id: records.erase(old)
			records.append({"id":"preview","kind":kind,"area":"home","cell":[cell.x,cell.y]})
			if not HomeLayout.routes_valid(int(state.level),state.builtins,_placed_obstacles(records),game.player.global_position if check_physics and is_instance_valid(game) and GameState.location=="home" else Vector2.INF): return false
			if check_physics and is_instance_valid(game) and GameState.location=="home" and Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32).grow(10).has_point(game.player.global_position): return false
		return true
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
	if busy or GameClock.settling or (not can_arrange() if area=="home" else not near(area)) or state.serial>=999999 or state.placed.size()>=MAX_PLACED or int(state.owned.get(kind,0))<1 or not can_place(kind,area,cell): return false
	busy=true;state.owned[kind]-=1
	if state.owned[kind]==0: state.owned.erase(kind)
	state.serial+=1;state.placed.append({"id":"furniture_%06d" % int(state.serial),"kind":kind,"area":area,"cell":[cell.x,cell.y]})
	_commit(true);return true
func move(id: String, cell: Vector2i) -> bool:
	var entry := placement(id)
	if busy or GameClock.settling or entry.is_empty() or (not can_arrange() if entry.area=="home" else not can_manage(entry.area,id)) or not can_place(entry.kind,entry.area,cell,id): return false
	busy=true;entry.cell=[cell.x,cell.y];_commit(true);return true
func recycle(id: String) -> bool:
	var entry := placement(id)
	if busy or GameClock.settling or entry.is_empty() or state.flowers.has(id) or (not can_arrange() if entry.area=="home" else not can_manage(entry.area,id)) or int(state.owned.get(entry.kind,0))>=99: return false
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
func _v23_keys() -> Array:
	var keys: Array=defaults().keys();keys.erase("builtins");return keys
func migrate_legacy(raw: Variant, day: int) -> Dictionary:
	if not FarmSaveSchema.whole(day,1,999999) or not raw is Dictionary or not FarmSaveSchema.whole(raw.get("level"),1,3): return {}
	var result: Dictionary=AbyssSaveSchema.canonical(raw).duplicate(true)
	if AquacultureSaveSchema.exact(result,LEGACY_FIELDS):
		var initial:=defaults(day);initial.erase("builtins")
		for key in initial:
			if not result.has(key): result[key]=initial[key]
	else:
		if result.has("builtins"):
			if result.builtins!=HomeLayout.default_builtins(int(result.level)): return {}
			result.erase("builtins")
		if not AquacultureSaveSchema.exact(result,_v23_keys()): return {}
		for key in ["construction","upgrade_serial","completed_jobs","last_settled_day","recovered"]:
			if result[key]!=defaults(day)[key]: return {}
	return result if validate(result,day,true) else {}
func migrate_v23(raw: Variant, day: int) -> Dictionary:
	if not raw is Dictionary: return {}
	var result: Dictionary=AbyssSaveSchema.canonical(raw).duplicate(true)
	if result.has("builtins"):
		if not FarmSaveSchema.whole(result.get("level"),1,4) or result.builtins!=HomeLayout.default_builtins(int(result.level)): return {}
		result.erase("builtins")
	if not validate(result,day,true): return {}
	result.builtins=HomeLayout.default_builtins(int(result.level))
	var layout:=reconciled_furniture(result)
	result.builtins=layout.builtins;result.placed=layout.placed;result.recovered=layout.recovered
	return result if validate(result,day) else {}
func _valid_furniture(entry: Variant, raw: Dictionary, seen: Dictionary, require_placeable: bool = true) -> bool:
	if not AquacultureSaveSchema.exact(entry,["id","kind","area","cell"]) or not entry.id is String or not entry.id.begins_with("furniture_"): return false
	var suffix: String=entry.id.trim_prefix("furniture_")
	if not suffix.is_valid_int() or not FarmSaveSchema.whole(int(suffix),1,int(raw.serial)) or entry.id!="furniture_%06d" % int(suffix) or seen.has(entry.id): return false
	seen[entry.id]=true
	if not entry.kind is String or not data.furniture.has(entry.kind) or entry.area not in ["home","farm"] or data.furniture[entry.kind].area!=entry.area or data.furniture[entry.kind].level>raw.level: return false
	if not entry.cell is Array or entry.cell.size()!=2 or not FarmSaveSchema.whole(entry.cell[0],0,47) or not FarmSaveSchema.whole(entry.cell[1],0,31): return false
	# 暂存保留的是冲突前的原记录；坐标不再可摆放也不能丢失整件家具。
	if not require_placeable: return true
	var rect := footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
	return allowed_rect(rect,entry.area,int(raw.level))
func validate(raw: Variant, _day: int, legacy: bool=false) -> bool:
	if legacy:
		if not AquacultureSaveSchema.exact(raw,_v23_keys()) or not FarmSaveSchema.whole(raw.level,1,4): return false
		raw=raw.duplicate(true);raw.builtins=HomeLayout.default_builtins(int(raw.level))
	if not AquacultureSaveSchema.exact(raw,defaults().keys()) or not FarmSaveSchema.whole(raw.level,1,4) or not FarmSaveSchema.whole(raw.serial,0,999999): return false
	if not FarmSaveSchema.whole(raw.last_settled_day,1,_day) or not FarmSaveSchema.whole(raw.upgrade_serial,0,3): return false
	if not raw.completed_jobs is Array or raw.completed_jobs.size()>int(raw.level)-1 or not raw.construction is Dictionary: return false
	for i in range(raw.completed_jobs.size()):
		if not FarmSaveSchema.whole(raw.completed_jobs[i],i+1,i+1): return false
	if int(raw.upgrade_serial)!=raw.completed_jobs.size()+(0 if raw.construction.is_empty() else 1): return false
	if not raw.construction.is_empty():
		var job: Dictionary=raw.construction
		if not AquacultureSaveSchema.exact(job,["from_level","target_level","started_day","ready_day","job_id"]): return false
		if int(raw.level)>=4 or not FarmSaveSchema.whole(job.from_level,int(raw.level),int(raw.level)) or not FarmSaveSchema.whole(job.target_level,int(raw.level)+1,int(raw.level)+1): return false
		if not FarmSaveSchema.whole(job.started_day,1,mini(_day,999997)) or not FarmSaveSchema.whole(job.ready_day,int(job.started_day)+2,int(job.started_day)+2): return false
		if int(job.ready_day)<=int(raw.last_settled_day) or not FarmSaveSchema.whole(job.job_id,int(raw.upgrade_serial),int(raw.upgrade_serial)): return false
	if not AquacultureSaveSchema.exact(raw.builtins,HomeLayout.definitions(int(raw.level)).keys()): return false
	for id in raw.builtins:
		var record=raw.builtins[id]
		if not AquacultureSaveSchema.exact(record,["cell"]) and not AquacultureSaveSchema.exact(record,["cell","stored"]): return false
		if record.has("stored") and (record.stored!=true or not record.stored is bool or id in HomeLayout.ESSENTIAL): return false
		if not record.cell is Array or record.cell.size()!=2 or not FarmSaveSchema.whole(record.cell[0],0,47) or not FarmSaveSchema.whole(record.cell[1],0,31): return false
	if not legacy:
		for id in raw.builtins:
			if not _builtin_fits(id,raw.builtins[id],int(raw.level),raw.builtins): return false
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
		if not _valid_furniture(entry,raw,seen): return false
		var rect := footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
		if legacy and entry.area=="home" and not (HOME_RECTS[int(raw.level)].encloses(rect) or (raw.level>=2 and EXTENSION_RECTS[int(raw.level)].encloses(rect))): return false
		if legacy and entry.area=="home" and rect.has_point(Vector2i(12,15)): return false
		if not legacy and entry.area=="home" and not _home_cell_safe(entry.kind,Vector2i(entry.cell[0],entry.cell[1]),int(raw.level),[],_home_obstacles(int(raw.level),raw.builtins)): return false
		for old in occupied[entry.area]:
			if old.intersects(rect): return false
		occupied[entry.area].append(rect)
	if not raw.recovered is Array or raw.recovered.size()>MAX_PLACED*3: return false
	for entry in raw.recovered:
		if not _valid_furniture(entry,raw,seen,false) or entry.area!="home": return false
	if not raw.flowers is Dictionary or raw.flowers.size()>MAX_PLACED: return false
	for id in raw.flowers:
		if not id is String or not FarmSaveSchema.whole(raw.flowers[id],1,_day): return false
		var found := false
		for entry in raw.placed:
			if entry.id==id and entry.kind=="flower" and entry.area=="farm": found=true;break
		if not found: return false
	return legacy or layout_routes_valid(raw)

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
