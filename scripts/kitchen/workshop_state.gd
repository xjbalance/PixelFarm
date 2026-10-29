extends Node
## Persistent expansion state; legacy Kitchen queues keep their original settlement dates.
signal changed
var state: Dictionary=defaults()
var game: Node
var busy: bool=false
func _ready() -> void:
	GameClock.changed.connect(update_ready)
func bind(owner_game: Node) -> void: game=owner_game
func defaults() -> Dictionary:
	return {"version":1,"jobs":{},"orchard":{},"next_job":1,"claimed":[],"legacy_installed":[],"selected_seed":"wheat_seed"}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false
	apply_seed();changed.emit()
func apply_seed() -> void:
	GameState.tools[5]=str(state.selected_seed)
	GameState.tool_names[5]=Catalog.item_name(str(state.selected_seed).trim_suffix("_seed"))
func select_seed(id: String) -> void:
	if not Catalog.crops.has(id) or Inventory.count(id+"_seed")<1: return
	if id in ["carrot","potato"]: GameState.select_tool(GameState.tools.find(id+"_seed"));return
	state.selected_seed=id+"_seed";apply_seed();GameState.select_tool(5);Events.progress_committed.emit()
func validate(raw: Variant, _save: Dictionary) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults().keys()): return false
	if not FarmSaveSchema.whole(raw.version,1,1) or not raw.selected_seed is String or not Catalog.crops.has(raw.selected_seed.trim_suffix("_seed")) or not raw.selected_seed.ends_with("_seed"): return false
	if not raw.jobs is Dictionary or raw.jobs.size()>Territory.MAX_OBJECTS or not FarmSaveSchema.whole(raw.next_job,1,999999999): return false
	if not raw.claimed is Array or raw.claimed.size()>128 or not AquacultureSaveSchema.unique(raw.legacy_installed,Kitchen.FACILITIES): return false
	var known: Dictionary={}
	for id in raw.claimed:
		if not FarmSaveSchema.whole(id,1,int(raw.next_job)-1) or known.has(int(id)): return false
		known[int(id)]=true
	var objects: Dictionary={}
	for entry in _save.get("territory",{}).get("objects",[]): objects[entry.id]=entry
	var now: int=(int(_save.get("day",1))-1)*1440+int(_save.get("minutes",360))
	for device in raw.jobs:
		var job: Variant=raw.jobs[device]
		if not objects.has(device) or not AquacultureSaveSchema.exact(job,["id","recipe","batches","started_at","finish_at","ready"]): return false
		if not FarmSaveSchema.whole(job.id,1,int(raw.next_job)-1) or known.has(int(job.id)): return false
		known[int(job.id)]=true
		if not job.recipe is String or not HarvestCatalog.data().processing.has(job.recipe) or not FarmSaveSchema.whole(job.batches,1,8): return false
		var recipe: Dictionary=HarvestCatalog.data().processing[job.recipe]
		if objects[device].kind!="station_"+str(recipe.processing_station_id): return false
		if not FarmSaveSchema.whole(job.started_at,360,now) or not job.ready is bool: return false
		var finish: int=int(job.started_at)+int(recipe.processing_duration)*int(job.batches)
		if not FarmSaveSchema.whole(job.finish_at,finish,finish) or (job.ready and finish>now): return false
	return raw.orchard is Dictionary and raw.orchard.is_empty()

func now_minutes() -> int: return (GameClock.day-1)*1440+int(GameClock.minutes)
func available() -> bool:
	return not busy and not Kitchen.busy and not GameState.restoring and not GameClock.settling and GameClock.minutes<1440 and is_instance_valid(game) and not game.backgrounded and not game.closing

func near_device(id: String) -> bool:
	if not available() or not game.territory_world.objects.has(id): return false
	var object: Node2D=game.territory_world.objects[id]
	return object.is_visible_in_tree() and object.entry.area==GameState.location and game.player.global_position.distance_to(object.global_position)<=54 and game.auto_move.navigation.line_of_sight(game.player.global_position,object.global_position,object)

func station_id(device: String) -> String:
	var entry:=Territory.object(device)
	return str(entry.get("kind","")).trim_prefix("station_") if str(entry.get("kind","")).begins_with("station_") else ""

func start(device: String, recipe_id: String, batches: int=1) -> bool:
	if not near_device(device) or batches<1 or batches>8 or state.jobs.has(device) or state.next_job>=999999999: return false
	var recipe: Dictionary=HarvestCatalog.data().processing.get(recipe_id,{})
	if recipe.is_empty() or str(recipe.processing_station_id)!=station_id(device) or not HarvestCatalog.unlocked(str(recipe.unlock_condition)): return false
	var end: int=now_minutes()+int(recipe.processing_duration)*batches
	if end>999999*1440-1: return false
	busy=true
	var exchange:=Inventory.preview_exchange(Kitchen.scaled(recipe.input_items,batches),{},0)
	if exchange.is_empty(): busy=false;Events.notice.emit("原料不足，没有扣除物品。");return false
	Inventory.items=exchange.items
	state.jobs[device]={"id":int(state.next_job),"recipe":recipe_id,"batches":batches,"started_at":now_minutes(),"finish_at":end,"ready":false}
	state.next_job+=1
	Inventory.changed.emit();changed.emit();busy=false;Events.progress_committed.emit()
	Events.notice.emit(str(recipe.name)+"已开始；离开设备后继续加工。")
	return true

func update_ready() -> void:
	if busy or GameState.restoring: return
	var names: Array[String]=[]
	for device in state.jobs:
		var job: Dictionary=state.jobs[device]
		if not job.ready and now_minutes()>=int(job.finish_at):
			job.ready=true;names.append(str(HarvestCatalog.data().processing[job.recipe].name))
	if not names.is_empty():
		changed.emit();Events.progress_committed.emit()
		Events.notice.emit("加工完成："+"、".join(names.slice(0,3))+("等%d笔" % names.size() if names.size()>3 else "")+"，成品留在设备中。")

func claim(device: String, expected_job: int) -> bool:
	if not near_device(device) or not state.jobs.has(device): return false
	var job: Dictionary=state.jobs[device]
	if int(job.id)!=expected_job or now_minutes()<int(job.finish_at): return false
	var recipe: Dictionary=HarvestCatalog.data().processing[job.recipe]
	busy=true
	var rewards: Dictionary={str(recipe.output_item_id):int(recipe.output_quantity)*int(job.batches)}
	var exchange:=Inventory.preview_exchange({},rewards,0)
	if exchange.is_empty(): busy=false;Events.notice.emit("背包已满，成品仍留在设备中。");return false
	Inventory.items=exchange.items;state.jobs.erase(device);state.claimed.append(expected_job)
	if state.claimed.size()>128: state.claimed.pop_front()
	Inventory.changed.emit();changed.emit();Events.processing_claimed.emit("workshop",str(job.recipe),expected_job,int(job.batches))
	busy=false;Events.progress_committed.emit();Events.notice.emit("收取"+Catalog.item_name(str(recipe.output_item_id))+" ×"+str(rewards[str(recipe.output_item_id)]))
	return true

func placement_cost(kind: String) -> Dictionary:
	if not kind.begins_with("station_"): return {"required":{},"coins":0}
	var id:=kind.trim_prefix("station_");var definition: Dictionary=HarvestCatalog.data().stations.get(id,{})
	if definition.is_empty(): return {}
	if Inventory.count(id+"_kit")>0: return {"required":{id+"_kit":1},"coins":0}
	if id in Kitchen.state.built and id not in state.legacy_installed: return {"required":{},"coins":0}
	return {"required":definition.required.duplicate(),"coins":int(definition.coins)}

func edit_error(plan: Dictionary) -> String:
	var kind: String=str(plan.get("kind",""))
	if not kind.begins_with("station_"): return ""
	if plan.op=="remove":
		if state.jobs.has(str(plan.id)): return "设备正在加工或留有成品；请先领取，再拆装。"
		if Inventory.count(kind.trim_prefix("station_")+"_kit")>=Inventory.MAX_STACK: return "整机背包已满，设备保留原位。"
	if plan.op=="place":
		var cost:=placement_cost(kind)
		if cost.is_empty() or Inventory.preview_exchange(cost.required,{},-int(cost.coins)).is_empty(): return "建设材料或金币不足；预览不会扣款。"
	return ""

func placement_hint(kind: String) -> String:
	if not kind.begins_with("station_"): return ""
	var cost:=placement_cost(kind);var words: Array[String]=[]
	for id in cost.required: words.append("%s %d/%d" % [Catalog.item_name(id),Inventory.count(id),int(cost.required[id])])
	words.append("%d金（持有%d）" % [cost.coins,Inventory.coins])
	return "确认建设："+" · ".join(words)+"。预览不扣款；整机可移动。"

func pay_for_plan(plan: Dictionary) -> bool:
	if not str(plan.kind).begins_with("station_"): return true
	if edit_error(plan)!="": return false
	var required: Dictionary={};var rewards: Dictionary={};var coins: int=0
	var id: String=str(plan.kind).trim_prefix("station_")
	if plan.op=="place":
		var cost:=placement_cost(str(plan.kind));required=cost.required;coins=-int(cost.coins)
	elif plan.op=="remove": rewards[id+"_kit"]=1
	var exchange:=Inventory.preview_exchange(required,rewards,coins)
	if exchange.is_empty(): return false
	# Territory holds its transaction lock; publish only after the entity and funds both commit.
	Inventory.items=exchange.items;Inventory.coins=exchange.coins
	if plan.op=="place" and id in Kitchen.FACILITIES:
		if id not in state.legacy_installed: state.legacy_installed.append(id)
		if id not in Kitchen.state.built: Kitchen.state.built.append(id)
	return true
