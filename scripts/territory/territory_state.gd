extends Node
## 本层只管理私人领地改造。预览不保存，确认以修订号原子提交，不产生经济收益。
signal changed
signal unlocked_changed
const MAX_TERRAIN_PER_AREA: int=4096
const MAX_OBJECTS: int=256
const MAX_BRUSH_CELLS: int=128
const MAX_SERIAL: int=999999
const MAX_REVISION: int=2147480000
var state: Dictionary=defaults()
var game: Node
var busy: bool=false
var last_error: String=""
var _validator: Callable

func _ready() -> void:
	for source in [Story,ChapterTwo,LakeEcology,Exploration,River]:
		source.changed.connect(func(): refresh_unlocks(not GameState.restoring))

func defaults() -> Dictionary:
	return {"version":1,"permissions":TerritoryCatalog.permissions(),"unlocked":["farm"],"terrain":{},"objects":[],"serial":0,"revision":0}

func migrate(raw_save: Dictionary) -> Dictionary:
	var result:=defaults()
	result.unlocked=TerritoryCatalog.earned_regions(raw_save)
	return result

func bind(owner_game: Node, validator: Callable=Callable()) -> void:
	game=owner_game;_validator=validator
	refresh_unlocks(false)

func snapshot() -> Dictionary: return state.duplicate(true)

func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;last_error=""
	changed.emit();unlocked_changed.emit();Events.navigation_changed.emit()

func refresh_unlocks(emit_progress: bool=true) -> bool:
	var earned:=TerritoryCatalog.earned_regions()
	if state.unlocked==earned: return false
	state.unlocked=earned
	state.revision=mini(MAX_REVISION,int(state.revision)+1)
	unlocked_changed.emit();changed.emit()
	if emit_progress and not GameState.restoring: Events.progress_committed.emit()
	return true

func unlocked(area: String) -> bool:
	# 存档中的列表是显示缓存，实际进入与编辑每次依据当前剧情检查。
	return area in TerritoryCatalog.earned_regions()

func region_info(area: String) -> Dictionary:
	var info:=TerritoryCatalog.region(area)
	info.unlocked=unlocked(area) if area in TerritoryCatalog.EDITABLE_AREAS else true
	info.can_edit=area in TerritoryCatalog.EDITABLE_AREAS and info.unlocked
	return info

func permission(area: String, cell: Vector2i, operation: String) -> Dictionary:
	if area not in TerritoryCatalog.EDITABLE_AREAS:
		return {"allowed":false,"reason":"公共、剧情和地下区域不开放领地改造。","ownership":"public"}
	if not unlocked(area): return {"allowed":false,"reason":str(TerritoryCatalog.region(area).hint),"ownership":"locked"}
	var rights:=TerritoryCatalog.cell_allowed(area,cell,operation)
	if area=="farm" and rights.allowed:
		var context:=_farm_context()
		var reason: String=""
		if is_instance_valid(game) and is_instance_valid(game.get("farm")) and game.farm.has_method("plot_at"):
			if not game.farm.plot_at(cell).is_empty(): reason="先移动或收纳这里的生产田地，再修改地表。"
			for id in TerritoryCatalog.resource_ids_at(cell):
				if int(context.resources.get(id,{}).get("hp",0))>0: reason="先移动、收纳或正常采集这里的树石。"
		else: reason=TerritoryCatalog.farm_obstruction(cell,context.plots,context.resources)
		if reason!="": return {"allowed":false,"reason":reason,"ownership":"private"}
	return rights

func _farm_context() -> Dictionary:
	var result: Dictionary={"plots":{},"resources":{}}
	if not is_instance_valid(game): return result
	var farm: Variant=game.get("farm")
	if is_instance_valid(farm) and farm.get("plots") is Dictionary: result.plots=farm.plots
	var resources: Variant=game.get("resource_world")
	if is_instance_valid(resources) and resources.get("fields") is Dictionary and resources.fields.has("farm"):
		result.resources=resources.fields.farm.state
	return result

func object(id: String) -> Dictionary:
	for entry in state.objects:
		if entry.id==id: return entry
	return {}

func object_at(area: String, cell: Vector2i) -> Dictionary:
	for entry in state.objects:
		if entry.area==area and TerritoryCatalog.footprint(entry.kind,TerritoryCatalog.to_cell(entry.cell)).has_point(cell): return entry
	return {}

func edited_cell(area: String, cell: Vector2i) -> bool:
	return state.terrain.get(area,{}).has(TerritoryCatalog.key(cell)) or not object_at(area,cell).is_empty()

func resource_edited(resource_id: String, area: String="farm") -> bool:
	if area!="farm": return false
	# 与原采集物真实脚底一致；树冠不是不可改造的土地。
	var rect:=TerritoryCatalog.resource_footprint(resource_id)
	var plots: Dictionary=_farm_context().plots
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var cell:=Vector2i(x,y)
			if plots.has(TerritoryCatalog.key(cell)) or edited_cell(area,cell): return true
	return false

func farm_plot_error(cell: Vector2i) -> String:
	if not object_at("farm",cell).is_empty(): return "这里摆有植物或物件，请先在建造模式移走，再开垦。"
	var kind: String=str(state.terrain.get("farm",{}).get(TerritoryCatalog.key(cell),""))
	if kind in ["dirt_path","stone_path","wood_path","sand","gravel","flowerbed"]: return "这里是景观地表，请先在建造模式恢复自然土地，再开垦。"
	return ""

func on_farm_plot_created(cell: Vector2i) -> void:
	if not is_instance_valid(game) or not game.farm.committing or game.farm.plot_at(cell).is_empty(): return
	var cells: Dictionary=state.terrain.get("farm",{});var key: String=TerritoryCatalog.key(cell)
	if str(cells.get(key,"")) not in ["soil","grass"]: return
	if FarmTerrain.base_index(cell) in [5,6]:
		cells[key]="grass" # Permanent fill under a real crop; never restore water below it.
		state.revision=mini(MAX_REVISION,int(state.revision)+1)
		changed.emit();Events.navigation_changed.emit();return
	cells.erase(key)
	if cells.is_empty(): state.terrain.erase("farm")
	state.revision=mini(MAX_REVISION,int(state.revision)+1)
	changed.emit();Events.navigation_changed.emit()

func _failure(plan: Dictionary, message: String) -> Dictionary:
	plan.valid=false;plan.reason=message
	return plan

func _plan(area: String, op: String, kind: String, cells: Array, id: String="") -> Dictionary:
	var plan: Dictionary={"area":area,"op":op,"kind":kind,"cells":[],"id":id,"revision":int(state.revision),"valid":false,"reason":""}
	if op not in ["terrain","place","move","remove"]: return _failure(plan,"不支持这种改造。")
	if cells.is_empty() or cells.size()>MAX_BRUSH_CELLS: return _failure(plan,"一次改造需要1至%d个地块。" % MAX_BRUSH_CELLS)
	var seen: Dictionary={}
	for raw in cells:
		var cell:=TerritoryCatalog.to_cell(raw)
		if cell==TerritoryCatalog.INVALID_CELL: return _failure(plan,"地块坐标无效。")
		if not seen.has(cell): plan.cells.append(cell);seen[cell]=true
	if op=="terrain" and not TerritoryCatalog.TERRAIN_KINDS.has(kind): return _failure(plan,"这种地表尚未开放。")
	if op!="terrain" and (plan.cells.size()!=1 or not TerritoryCatalog.OBJECT_KINDS.has(kind)): return _failure(plan,"放置物或位置无效。")
	var existing:=object(id) if id!="" else {}
	if op in ["move","remove"] and (existing.is_empty() or existing.area!=area or existing.kind!=kind): return _failure(plan,"这件私人设施已经不在原来的位置。")
	if op=="place" and (state.objects.size()>=MAX_OBJECTS or int(state.serial)>=MAX_SERIAL): return _failure(plan,"领地放置物已达到本阶段上限。")
	if op=="terrain":
		var current: Dictionary=state.terrain.get(area,{})
		var count: int=current.size()
		for cell: Vector2i in plan.cells:
			var rights:=permission(area,cell,kind)
			if not rights.allowed: return _failure(plan,str(rights.reason))
			if not object_at(area,cell).is_empty(): return _failure(plan,"先移走这里的植物或设施，再修改地表。")
			if not current.has(TerritoryCatalog.key(cell)) and kind!="natural": count+=1
		if count>MAX_TERRAIN_PER_AREA: return _failure(plan,"这个区域的地表记录已达到上限。")
	else:
		var extent:=TerritoryCatalog.footprint(kind,plan.cells[0])
		for y in range(extent.position.y,extent.end.y):
			for x in range(extent.position.x,extent.end.x):
				var rights:=permission(area,Vector2i(x,y),kind)
				if not rights.allowed: return _failure(plan,str(rights.reason))
		if op!="remove":
			for other in state.objects:
				if other.area==area and other.id!=id and TerritoryCatalog.footprint(other.kind,TerritoryCatalog.to_cell(other.cell)).intersects(extent): return _failure(plan,"这里已经有植物或设施。")
			if op=="move" and TerritoryCatalog.to_cell(existing.cell)==plan.cells[0]: return _failure(plan,"请选择一个新的位置。")
	plan.valid=true
	if _validator.is_valid():
		var checked: Variant=_validator.call(plan.duplicate(true))
		if not checked is Dictionary or not checked.get("valid",false): return _failure(plan,str(checked.get("reason","现场不允许这次改造。")) if checked is Dictionary else "现场校验未能完成。")
	return plan

func plan_terrain(area: String, cells: Array, kind: String) -> Dictionary:
	return _plan(area,"terrain",kind,cells)

func plan_place(area: String, kind: String, cell: Vector2i) -> Dictionary:
	return _plan(area,"place",kind,[cell])

func plan_move(id: String, cell: Vector2i) -> Dictionary:
	var entry:=object(id)
	return _plan(str(entry.get("area","")),"move",str(entry.get("kind","")),[cell],id)

func plan_remove(id: String) -> Dictionary:
	var entry:=object(id)
	return _plan(str(entry.get("area","")),"remove",str(entry.get("kind","")),[TerritoryCatalog.to_cell(entry.get("cell"))],id)

func _can_commit(area: String) -> bool:
	if busy or GameState.restoring or GameClock.settling or GameClock.minutes>=1440 or not is_instance_valid(game): return false
	if game.backgrounded or game.closing or game.player.suspended or game.player.action_time>0 or game.farm.committing or Housing.busy or game.resource_world.committing(): return false
	var editor: Variant=game.get("territory_editor")
	return is_instance_valid(editor) and editor.active and GameState.modal and GameState.location==area

func apply_plan(plan: Dictionary) -> bool:
	last_error=""
	if not plan.get("area") is String or not _can_commit(str(plan.area)):
		last_error="请在当前私人领地的建造模式中确认。";return false
	if not TerritoryCatalog.whole(plan.get("revision"),0,MAX_REVISION) or int(plan.revision)!=int(state.revision) or int(state.revision)>=MAX_REVISION:
		last_error="预览已失效，请重新选择位置。";return false
	if not plan.get("op") is String or not plan.get("kind") is String or not plan.get("id","") is String or not plan.get("cells") is Array:
		last_error="改造预览数据无效。";return false
	var checked:=_plan(str(plan.area),str(plan.op),str(plan.kind),plan.cells,str(plan.get("id","")))
	if not checked.valid: last_error=str(checked.reason);return false
	busy=true
	if checked.op=="terrain":
		if not state.terrain.has(checked.area): state.terrain[checked.area]={}
		for cell: Vector2i in checked.cells:
			var cell_key:=TerritoryCatalog.key(cell)
			if checked.kind=="natural": state.terrain[checked.area].erase(cell_key)
			else: state.terrain[checked.area][cell_key]=checked.kind
		if state.terrain[checked.area].is_empty(): state.terrain.erase(checked.area)
	elif checked.op=="place":
		state.serial+=1
		var cell: Vector2i=checked.cells[0]
		state.objects.append({"id":"territory_%06d" % int(state.serial),"area":checked.area,"kind":checked.kind,"cell":[cell.x,cell.y]})
	elif checked.op=="move":
		var entry:=object(str(checked.id));var cell: Vector2i=checked.cells[0]
		entry.cell=[cell.x,cell.y]
	else: state.objects.erase(object(str(checked.id)))
	state.revision+=1
	changed.emit();Events.navigation_changed.emit();Events.progress_committed.emit()
	busy=false
	return true

func validate(raw: Variant, raw_save: Dictionary={}) -> bool:
	if not raw is Dictionary or raw.size()!=defaults().size(): return false
	for field in defaults():
		if not raw.has(field): return false
	if not TerritoryCatalog.whole(raw.version,1,1) or not TerritoryCatalog.whole(raw.serial,0,MAX_SERIAL) or not TerritoryCatalog.whole(raw.revision,0,MAX_REVISION): return false
	if not raw.permissions is Dictionary or raw.permissions!=TerritoryCatalog.permissions(): return false
	if not raw.unlocked is Array or raw.unlocked.is_empty() or raw.unlocked.size()>TerritoryCatalog.EDITABLE_AREAS.size(): return false
	for i in range(raw.unlocked.size()):
		if raw.unlocked[i]!=TerritoryCatalog.EDITABLE_AREAS[i]: return false
	if not raw_save.is_empty() and raw.unlocked!=TerritoryCatalog.earned_regions(raw_save): return false
	if not raw.terrain is Dictionary or raw.terrain.size()>TerritoryCatalog.EDITABLE_AREAS.size(): return false
	for area in raw.terrain:
		if not area is String or area not in raw.unlocked or not raw.terrain[area] is Dictionary or raw.terrain[area].size()>MAX_TERRAIN_PER_AREA: return false
		for cell_key in raw.terrain[area]:
			if not cell_key is String: return false
			var cell:=TerritoryCatalog.cell_from_key(cell_key)
			var kind: Variant=raw.terrain[area][cell_key]
			if cell==TerritoryCatalog.INVALID_CELL or not kind is String or not TerritoryCatalog.TERRAIN_KINDS.has(kind) or kind=="natural" or not TerritoryCatalog.cell_allowed(area,cell,kind).allowed: return false
			if area=="farm" and not raw_save.is_empty() and _saved_farm_obstruction(raw_save,cell,kind)!="": return false
	if not raw.objects is Array or raw.objects.size()>MAX_OBJECTS: return false
	var ids: Dictionary={};var occupied: Dictionary={}
	for entry in raw.objects:
		if not entry is Dictionary or entry.size()!=4: return false
		for field in ["id","area","kind","cell"]:
			if not entry.has(field): return false
		if not entry.id is String or not entry.area is String or not entry.kind is String or entry.area not in raw.unlocked or not TerritoryCatalog.OBJECT_KINDS.has(entry.kind): return false
		if not entry.id.begins_with("territory_") or entry.id.length()!=16 or not entry.id.trim_prefix("territory_").is_valid_int(): return false
		var serial: int=entry.id.trim_prefix("territory_").to_int()
		if serial<1 or serial>int(raw.serial) or entry.id!="territory_%06d" % serial or ids.has(entry.id): return false
		ids[entry.id]=true
		var cell:=TerritoryCatalog.to_cell(entry.cell)
		if not entry.cell is Array or cell==TerritoryCatalog.INVALID_CELL: return false
		var extent:=TerritoryCatalog.footprint(entry.kind,cell)
		for y in range(extent.position.y,extent.end.y):
			for x in range(extent.position.x,extent.end.x):
				var at:=Vector2i(x,y);var occupied_key: String=str(entry.area)+":"+TerritoryCatalog.key(at)
				if occupied.has(occupied_key) or not TerritoryCatalog.cell_allowed(entry.area,at,entry.kind).allowed: return false
				if entry.area=="farm" and not raw_save.is_empty() and _saved_farm_obstruction(raw_save,at)!="": return false
				occupied[occupied_key]=true
				# 地表可在放置前铺设，保存时允许地表与其上的设施共存。
	return true

func _saved_farm_obstruction(raw_save: Dictionary, cell: Vector2i, terrain_kind: String="") -> String:
	var plots: Variant=raw_save.get("plots",{});var resources: Variant=raw_save.get("resources",{})
	var layout: Dictionary=raw_save.get("farm_layout",{}) if raw_save.get("farm_layout",{}) is Dictionary else {}
	if not layout.get("plots",{}) is Dictionary or not layout.get("resources",{}) is Dictionary: return "布局数据不合法。"
	if plots is Dictionary:
		for id in plots:
			var entry: Dictionary=layout.get("plots",{}).get(id,{"cell":str(id).split(","),"stored":false})
			if entry.get("stored",false): continue
			var at: Vector2i=FarmLayoutCatalog.plot_cell(str(id)) if not layout.get("plots",{}).has(id) else TerritoryCatalog.to_cell(entry.cell)
			if at==cell and terrain_kind not in ["grass","soil"]: return "不能覆盖现有生产田地。"
	for id in FarmResourceCatalog.placements("farm"):
		var original: Dictionary=FarmResourceCatalog.placements("farm")[id]
		var entry: Dictionary=layout.get("resources",{}).get(id,{"cell":[original.cell.x,original.cell.y],"stored":false})
		if entry.get("stored",false): continue
		if FarmResourceCatalog.current_footprint(str(id),TerritoryCatalog.to_cell(entry.cell)).has_point(cell) and (not resources is Dictionary or int(resources.get(id,{}).get("hp",1))>0): return "不能覆盖存活的采集资源。"
	return ""
