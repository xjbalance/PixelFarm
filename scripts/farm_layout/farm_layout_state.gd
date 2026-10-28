extends Node
## 只有布局覆盖；原功能ID、等级、作物、库存和采集耐久由既有业务保存。
signal changed
const MAX_REVISION: int=2147480000
var state: Dictionary=defaults()
var game: Node
var busy: bool=false
var last_error: String=""
var _validator: Callable

func defaults() -> Dictionary:
	return {"version":1,"revision":0,"fixtures":{},"resources":{},"plots":{}}
func migrate(_raw_save: Dictionary) -> Dictionary: return defaults()
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary, emit_change: bool=true) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;last_error=""
	if emit_change: changed.emit()
func bind(owner_game: Node, validator: Callable=Callable()) -> void:
	game=owner_game;_validator=validator

func record(kind: String, id: String) -> Dictionary:
	if not FarmLayoutCatalog.valid_id(kind,id): return {}
	return state[FarmLayoutCatalog.FIELDS[kind]].get(id,FarmLayoutCatalog.default_record(kind,id)).duplicate(true)
func cell(kind: String, id: String) -> Vector2i:
	var entry:=record(kind,id)
	return FarmLayoutCatalog.parse_cell(entry.get("cell"))
func stored(kind: String, id: String) -> bool:
	var entry:=record(kind,id)
	return bool(entry.get("stored",true))
func position(kind: String, id: String) -> Vector2:
	return FarmLayoutCatalog.world_point(kind,id,cell(kind,id))
func point(id: String) -> Vector2: return position("fixture",id)
func offset(id: String) -> Vector2:
	return point(id)-FarmLayoutCatalog.base_point(id) if FarmLayoutCatalog.valid_id("fixture",id) else Vector2.ZERO
func active(id: String) -> bool: return FarmLayoutCatalog.valid_id("fixture",id) and not stored("fixture",id)
func transform_point(original: Vector2, fixture_id: String="") -> Vector2:
	var id: String=fixture_id if fixture_id!="" else FarmLayoutCatalog.associated_fixture(original)
	return original+offset(id)
func to_logical(id: String, physical: Vector2) -> Vector2: return physical-offset(id)

func logical_plot_at(physical: Vector2i, plots: Dictionary={}) -> String:
	var records: Dictionary=plots
	if records.is_empty() and is_instance_valid(game) and is_instance_valid(game.get("farm")): records=game.farm.plots
	for id in records:
		if id is String and not stored("plot",id) and cell("plot",id)==physical: return id
	return ""

func _entry(state_data: Dictionary, kind: String, id: String) -> Dictionary:
	return state_data[FarmLayoutCatalog.FIELDS[kind]].get(id,FarmLayoutCatalog.default_record(kind,id))

func _failure(plan: Dictionary, reason: String) -> Dictionary:
	plan.valid=false;plan.reason=reason;return plan

func _plan(kind: String, id: String, at: Vector2i, put_away: bool, operation: String) -> Dictionary:
	var plan: Dictionary={"kind":kind,"id":id,"cell":at,"stored":put_away,"op":operation,"revision":int(state.revision),"valid":false,"reason":""}
	if not FarmLayoutCatalog.valid_id(kind,id): return _failure(plan,"这不是农场原有的固定实体，不能复制或移动。")
	if operation not in ["move","store","restore"] or put_away!=(operation=="store"): return _failure(plan,"布局操作类型不匹配。")
	if not FarmLayoutCatalog.GRID.has_point(at): return _failure(plan,"位置必须位于自己的农场内。")
	if kind=="plot" and is_instance_valid(game) and not game.farm.plots.has(id): return _failure(plan,"这里还没有真实生产田地，请先正常开垦。")
	var old:=record(kind,id)
	if operation=="store" and old.stored: return _failure(plan,"这件实体已经收纳。")
	if operation=="restore" and not old.stored: return _failure(plan,"这件实体已经在农场中。")
	if operation=="move" and old.stored: return _failure(plan,"先从收纳列表选择恢复，再决定摆放位置。")
	if old.stored==put_away and FarmLayoutCatalog.parse_cell(old.cell)==at: return _failure(plan,"请选择一个新的位置。")
	var candidate:=state.duplicate(true);_write_record(candidate,kind,id,{"cell":[at.x,at.y],"stored":put_away})
	if not validate(candidate,_validation_context()): return _failure(plan,"实体位置、身份或田地映射不合法，原布局保持不变。")
	plan.valid=true
	if _validator.is_valid():
		var result: Variant=_validator.call(plan.duplicate(true))
		if not result is Dictionary or not result.get("valid",false): return _failure(plan,str(result.get("reason","现场不能这样摆放。")) if result is Dictionary else "布局现场校验未完成。")
	return plan

func plan_move(kind: String, id: String, at: Vector2i) -> Dictionary: return _plan(kind,id,at,false,"move")
func plan_store(kind: String, id: String) -> Dictionary: return _plan(kind,id,cell(kind,id),true,"store")
func plan_restore(kind: String, id: String, at: Vector2i) -> Dictionary: return _plan(kind,id,at,false,"restore")

func _validation_context() -> Dictionary:
	return {"plots":game.farm.plots} if is_instance_valid(game) and is_instance_valid(game.get("farm")) else {}

func _can_apply() -> bool:
	if busy or not is_instance_valid(game) or GameState.restoring or GameClock.settling or GameClock.minutes>=1440 or GameState.location!="farm": return false
	if game.backgrounded or game.closing or game.player.suspended or game.player.action_time>0 or game.farm.committing or Housing.busy or game.resource_world.committing(): return false
	var editor: Variant=game.get("territory_editor")
	return is_instance_valid(editor) and editor.active and GameState.modal

func _write_record(target: Dictionary, kind: String, id: String, entry: Dictionary) -> void:
	var field: String=FarmLayoutCatalog.FIELDS[kind]
	# For original decorations an explicit default-position restore is still a
	# player placement; retain it so legacy terrain auto-cover cannot hide it.
	if entry==FarmLayoutCatalog.default_record(kind,id) and not (kind=="fixture" and id.begins_with("decor:")): target[field].erase(id)
	else: target[field][id]=entry.duplicate(true)

func apply_plan(plan: Dictionary) -> bool:
	last_error=""
	if not _can_apply(): last_error="请在农场建造模式中确认，等待当前动作完成。";return false
	if not FarmLayoutCatalog.whole(plan.get("revision"),0,MAX_REVISION) or int(plan.revision)!=int(state.revision) or int(state.revision)>=MAX_REVISION:
		last_error="预览已失效，请重新选择。";return false
	if not plan.get("kind") is String or not plan.get("id") is String or not plan.get("stored") is bool or plan.get("op") not in ["move","store","restore"]:
		last_error="原实体预览数据无效。";return false
	var at:=FarmLayoutCatalog.parse_cell(plan.get("cell"))
	var checked:=_plan(str(plan.kind),str(plan.id),at,bool(plan.stored),str(plan.op))
	if not checked.valid: last_error=str(checked.reason);return false
	busy=true
	_write_record(state,str(checked.kind),str(checked.id),{"cell":[at.x,at.y],"stored":bool(checked.stored)})
	state.revision+=1;changed.emit();Events.navigation_changed.emit();Events.progress_committed.emit()
	busy=false;return true

func register_plot(logical_id: String, physical: Vector2i) -> bool:
	if busy or not is_instance_valid(game) or not game.farm.committing or not game.farm.plots.has(logical_id) or not FarmLayoutCatalog.valid_id("plot",logical_id) or not FarmLayoutCatalog.GRID.has_point(physical): return false
	var candidate:=state.duplicate(true)
	_write_record(candidate,"plot",logical_id,{"cell":[physical.x,physical.y],"stored":false})
	if not validate(candidate,{"plots":game.farm.plots}): return false
	if candidate.plots==state.plots: return true
	busy=true;state.plots=candidate.plots;state.revision=mini(MAX_REVISION,int(state.revision)+1)
	changed.emit();Events.navigation_changed.emit();busy=false
	return true

func validate(raw: Variant, raw_save: Dictionary={}) -> bool:
	if not raw is Dictionary or raw.size()!=defaults().size(): return false
	for field in defaults():
		if not raw.has(field): return false
	if not FarmLayoutCatalog.whole(raw.version,1,1) or not FarmLayoutCatalog.whole(raw.revision,0,MAX_REVISION): return false
	for kind in FarmLayoutCatalog.KINDS:
		var field: String=FarmLayoutCatalog.FIELDS[kind];var entries: Variant=raw[field]
		if not entries is Dictionary or entries.size()>FarmLayoutCatalog.ids(kind).size(): return false
		for id in entries:
			if not id is String or not FarmLayoutCatalog.valid_id(kind,id): return false
			var entry: Variant=entries[id]
			if not entry is Dictionary or entry.size()!=2 or not entry.has("cell") or not entry.get("stored") is bool or not entry.cell is Array: return false
			var at:=FarmLayoutCatalog.parse_cell(entry.cell)
			if not FarmLayoutCatalog.GRID.has_point(at): return false
			if not entry.stored and at!=FarmLayoutCatalog.default_cell(kind,id) and not FarmLayoutCatalog.WORLD.grow(.01).encloses(FarmLayoutCatalog.world_rect(kind,id,at)): return false
	var occupied: Dictionary={}
	for id in FarmLayoutCatalog.ids("resource"):
		var entry:=_entry(raw,"resource",id)
		if entry.stored: continue
		var at:=FarmLayoutCatalog.parse_cell(entry.cell)
		if occupied.has(at): return false
		occupied[at]=true
	var plots: Variant=raw_save.get("plots",{})
	if not plots is Dictionary: return false
	occupied.clear()
	for id in plots:
		if not id is String or not FarmLayoutCatalog.valid_id("plot",id): return false
		var entry:=_entry(raw,"plot",id)
		if entry.stored: continue
		var at:=FarmLayoutCatalog.parse_cell(entry.cell)
		if occupied.has(at): return false
		occupied[at]=true
	if raw_save.has("plots"):
		for id in raw.plots:
			if not plots.has(id): return false
	return true
