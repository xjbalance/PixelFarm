extends Node
## Persistent expansion state; legacy Kitchen queues keep their original settlement dates.
signal changed
var state: Dictionary=defaults()
var game: Node
var busy: bool=false
var compatibility: Dictionary={}
func _ready() -> void:
	GameClock.changed.connect(update_ready)
	GameClock.day_advanced.connect(settle_orchard)
func bind(owner_game: Node) -> void: game=owner_game
func defaults() -> Dictionary:
	return {"version":2,"jobs":{},"orchard":{},"next_job":1,"claimed":[],"legacy_installed":[],"selected_seed":"wheat_seed"}
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
	if not FarmSaveSchema.whole(_save.get("day"),1,999999): return false
	var minute: Variant=_save.get("minutes")
	if not (minute is int or minute is float) or not is_finite(float(minute)) or float(minute)<360 or float(minute)>=1440: return false
	if not _save.get("kitchen") is Dictionary or not _save.kitchen.get("built") is Array or not _save.get("territory") is Dictionary or not _save.territory.get("objects") is Array: return false
	if not AquacultureSaveSchema.exact(raw,defaults().keys()): return false
	if not FarmSaveSchema.whole(raw.version,2,2) or not raw.selected_seed is String or not Catalog.crops.has(raw.selected_seed.trim_suffix("_seed")) or not raw.selected_seed.ends_with("_seed"): return false
	if not raw.jobs is Dictionary or raw.jobs.size()>Territory.MAX_OBJECTS or not FarmSaveSchema.whole(raw.next_job,1,999999999): return false
	if not raw.claimed is Array or raw.claimed.size()>128 or not AquacultureSaveSchema.unique(raw.legacy_installed,Kitchen.FACILITIES): return false
	for id in raw.legacy_installed:
		if id not in _save.get("kitchen",{}).get("built",[]): return false
	var known: Dictionary={}
	for id in raw.claimed:
		if not FarmSaveSchema.whole(id,1,int(raw.next_job)-1) or known.has(int(id)): return false
		known[int(id)]=true
	var objects: Dictionary={}
	for entry in _save.territory.objects:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("kind") is String or objects.has(entry.id): return false
		objects[entry.id]=entry
	var now: int=(int(_save.get("day",1))-1)*1440+int(_save.get("minutes",360))
	for device in raw.jobs:
		var job: Variant=raw.jobs[device]
		if not objects.has(device) or not AquacultureSaveSchema.exact(job,["id","recipe","batches","started_at","finish_at","ready","inputs","outputs"]): return false
		if not FarmSaveSchema.whole(job.id,1,int(raw.next_job)-1) or known.has(int(job.id)): return false
		known[int(job.id)]=true
		if not job.recipe is String or not HarvestCatalog.data().processing.has(job.recipe) or not FarmSaveSchema.whole(job.batches,1,8): return false
		var recipe: Dictionary=HarvestCatalog.data().processing[job.recipe]
		var old: Dictionary=old_recipes().get(job.recipe,{})
		var inputs:=Kitchen.scaled(recipe.input_items,int(job.batches))
		var outputs: Dictionary={str(recipe.output_item_id):int(recipe.output_quantity)*int(job.batches)}
		if not valid_quantities(job.inputs) or not valid_quantities(job.outputs): return false
		if job.inputs!=inputs and (old.is_empty() or job.inputs!=Kitchen.scaled(old.inputs,int(job.batches))): return false
		if job.outputs!=outputs and (old.is_empty() or job.outputs!=Kitchen.scaled(old.outputs,int(job.batches))): return false
		if objects[device].kind!="station_"+str(recipe.processing_station_id): return false
		if not FarmSaveSchema.whole(job.started_at,360,now) or not job.ready is bool: return false
		var finish: int=int(job.started_at)+int(recipe.processing_duration)*int(job.batches)
		if not FarmSaveSchema.whole(job.finish_at,finish,finish) or (job.ready and finish>now): return false
	if not raw.orchard is Dictionary or raw.orchard.size()>Territory.MAX_OBJECTS: return false
	for id in raw.orchard:
		if not objects.has(id) or not str(objects[id].kind).begins_with("orchard_"): return false
		var fruit: String=str(objects[id].kind).trim_prefix("orchard_")
		if not HarvestCatalog.data().orchard.has(fruit): return false
		var row: Variant=raw.orchard[id];var tree: Dictionary=HarvestCatalog.data().orchard[fruit];var day: int=int(_save.day)
		if not AquacultureSaveSchema.exact(row,["planted_day","next_fruit_day","fruit","settled_day"]): return false
		if not FarmSaveSchema.whole(row.planted_day,1,day) or not FarmSaveSchema.whole(row.settled_day,int(row.planted_day),day): return false
		if not FarmSaveSchema.whole(row.next_fruit_day,int(row.planted_day)+int(tree.growth_days),maxi(int(row.planted_day)+int(tree.growth_days),day+int(tree.regrow_days))): return false
		if not FarmSaveSchema.whole(row.fruit,0,int(tree.yield)) or (int(row.fruit)>0 and day<int(row.planted_day)+int(tree.growth_days)): return false
	for id in objects:
		if str(objects[id].kind).begins_with("orchard_") and not raw.orchard.has(id): return false
	return true

func old_recipes() -> Dictionary:
	if compatibility.is_empty(): compatibility=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/harvest/production_080.json")))
	return compatibility.recipes

func valid_quantities(items: Variant) -> bool:
	if not items is Dictionary or items.is_empty() or items.size()>12: return false
	for id in items:
		if not id is String or not Catalog.is_item(id) or not FarmSaveSchema.whole(items[id],1,Inventory.MAX_STACK): return false
	return true

func migrate_v28(raw: Variant, save: Dictionary) -> Dictionary:
	if not AquacultureSaveSchema.exact(raw,defaults().keys()) or not FarmSaveSchema.whole(raw.version,1,2) or not raw.jobs is Dictionary: return {}
	var result: Dictionary=AbyssSaveSchema.canonical(raw).duplicate(true)
	if int(result.version)==1:
		for device in result.jobs:
			var job: Variant=result.jobs[device]
			if not AquacultureSaveSchema.exact(job,["id","recipe","batches","started_at","finish_at","ready"]) or not job.recipe is String or not old_recipes().has(job.recipe) or not FarmSaveSchema.whole(job.batches,1,8): return {}
			var old: Dictionary=old_recipes()[job.recipe]
			job.inputs=Kitchen.scaled(old.inputs,int(job.batches));job.outputs=Kitchen.scaled(old.outputs,int(job.batches))
		result.version=2
	return result if validate(result,save) else {}

func now_minutes() -> int: return (GameClock.day-1)*1440+int(GameClock.minutes)
func available() -> bool:
	return not busy and not Kitchen.busy and not Territory.busy and not FarmLayout.busy and not Housing.busy and not GameState.restoring and not GameClock.settling and GameClock.minutes<1440 and is_instance_valid(game) and not game.backgrounded and not game.closing and not game.player.suspended and game.player.action_time<=0 and not game.farm.committing

func near_device(id: String) -> bool:
	if not available() or not game.territory_world.objects.has(id): return false
	var object: Node2D=game.territory_world.objects[id]
	return object.is_visible_in_tree() and object.entry.area==GameState.location and game.player.global_position.distance_to(object.global_position)<=54 and game.auto_move.navigation.line_of_sight(game.player.global_position,object.global_position,object)

func station_id(device: String) -> String:
	var entry:=Territory.object(device)
	return str(entry.get("kind","")).trim_prefix("station_") if str(entry.get("kind","")).begins_with("station_") else ""

func start_error(device: String, recipe_id: String, batches: int=1) -> String:
	if not available(): return "当前动作或场景切换尚未结束，请稍候。"
	if not near_device(device): return "请走到设备旁的可操作位置。"
	if batches<1 or batches>8: return "每笔可制作1至8批。"
	if state.jobs.has(device): return "设备已占用，请在加工完成后收取成品。"
	if state.next_job>=999999999: return "工单编号已达到上限。"
	var recipe: Dictionary=HarvestCatalog.data().processing.get(recipe_id,{})
	if recipe.is_empty() or str(recipe.processing_station_id)!=station_id(device): return "这种配方不属于当前设备。"
	if not HarvestCatalog.unlocked(str(recipe.unlock_condition)): return "配方尚未解锁。"
	if not valid_quantities(Kitchen.scaled(recipe.input_items,batches)) or not valid_quantities({str(recipe.output_item_id):int(recipe.output_quantity)*batches}): return "本批数量超过单类背包上限，请减少批数。"
	var shortages:=missing_materials(Kitchen.scaled(recipe.input_items,batches))
	if shortages!="": return "还缺："+shortages
	if now_minutes()+int(recipe.processing_duration)*batches>999999*1440-1: return "剩余日期不足以完成这笔加工。"
	return ""

func missing_materials(required: Dictionary) -> String:
	var missing: Array[String]=[]
	for id in required:
		var amount: int=int(required[id])-Inventory.count(id)
		if amount>0: missing.append(Catalog.item_name(id)+" ×"+str(amount))
	return "、".join(missing)

func start(device: String, recipe_id: String, batches: int=1) -> bool:
	var error:=start_error(device,recipe_id,batches)
	if error!="": Events.notice.emit(error);return false
	var recipe: Dictionary=HarvestCatalog.data().processing[recipe_id]
	var end: int=now_minutes()+int(recipe.processing_duration)*batches
	busy=true
	var inputs:=Kitchen.scaled(recipe.input_items,batches)
	var outputs: Dictionary={str(recipe.output_item_id):int(recipe.output_quantity)*batches}
	var exchange:=Inventory.preview_exchange(inputs,{},0)
	if exchange.is_empty(): busy=false;Events.notice.emit("原料不足，没有扣除物品。");return false
	Inventory.items=exchange.items
	state.jobs[device]={"id":int(state.next_job),"recipe":recipe_id,"batches":batches,"started_at":now_minutes(),"finish_at":end,"ready":false,"inputs":inputs.duplicate(true),"outputs":outputs.duplicate(true)}
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
	busy=true
	var rewards: Dictionary=job.outputs.duplicate(true)
	var exchange:=Inventory.preview_exchange({},rewards,0)
	if exchange.is_empty(): busy=false;Events.notice.emit("背包已满，成品仍留在设备中。");return false
	Inventory.items=exchange.items;state.jobs.erase(device);state.claimed.append(expected_job)
	if state.claimed.size()>128: state.claimed.pop_front()
	Inventory.changed.emit();changed.emit();Events.processing_claimed.emit("workshop",str(job.recipe),expected_job,int(job.batches))
	var product: String=str(rewards.keys()[0])
	busy=false;Events.progress_committed.emit();Events.notice.emit("收取"+Catalog.item_name(product)+" ×"+str(rewards[product]))
	return true

func placement_cost(kind: String) -> Dictionary:
	if kind.begins_with("orchard_"):
		return {"required":{kind.trim_prefix("orchard_")+"_sapling":1},"coins":0}
	if not kind.begins_with("station_"): return {"required":{},"coins":0}
	var id:=kind.trim_prefix("station_");var definition: Dictionary=HarvestCatalog.data().stations.get(id,{})
	if definition.is_empty(): return {}
	if Inventory.count(id+"_kit")>0: return {"required":{id+"_kit":1},"coins":0}
	if id in Kitchen.state.built and id not in state.legacy_installed: return {"required":{},"coins":0}
	return {"required":definition.required.duplicate(),"coins":int(definition.coins)}

func edit_error(plan: Dictionary) -> String:
	var kind: String=str(plan.get("kind",""))
	if not (kind.begins_with("station_") or kind.begins_with("orchard_")): return ""
	if plan.op=="remove":
		if state.jobs.has(str(plan.id)): return "设备正在加工或留有成品；请先领取，再拆装。"
		if int(state.orchard.get(str(plan.id),{}).get("fruit",0))>0: return "树上还有果实，请先收获再回收树苗。"
		var refund: String=kind.trim_prefix("station_")+"_kit" if kind.begins_with("station_") else kind.trim_prefix("orchard_")+"_sapling"
		if Inventory.count(refund)>=Inventory.MAX_STACK: return "背包已满，物件保留原位。"
	if plan.op=="place":
		var cost:=placement_cost(kind)
		if Inventory.diamond_payment and not cost.is_empty() and int(cost.coins)>0: return "设备建设按金币报价，请使用金币确认。"
		if cost.is_empty() or Inventory.preview_exchange(cost.required,{},-int(cost.coins)).is_empty(): return "建设材料或金币不足；预览不会扣款。"
	return ""

func placement_hint(kind: String) -> String:
	if not (kind.begins_with("station_") or kind.begins_with("orchard_")): return ""
	var cost:=placement_cost(kind);var words: Array[String]=[]
	for id in cost.required: words.append("%s %d/%d" % [Catalog.item_name(id),Inventory.count(id),int(cost.required[id])])
	words.append("%d金（持有%d）" % [cost.coins,Inventory.coins])
	return "确认建设："+" · ".join(words)+("。移动保留树龄；回收为树苗会重新生长。" if kind.begins_with("orchard_") else "。预览不扣款；整机可移动。")

func pay_for_plan(plan: Dictionary) -> bool:
	var fruit_tree: bool=str(plan.kind).begins_with("orchard_")
	if not str(plan.kind).begins_with("station_") and not fruit_tree: return true
	if edit_error(plan)!="": return false
	var required: Dictionary={};var rewards: Dictionary={};var coins: int=0
	var id: String=str(plan.kind).trim_prefix("orchard_" if fruit_tree else "station_")
	if plan.op=="place":
		var cost:=placement_cost(str(plan.kind));required=cost.required;coins=-int(cost.coins)
	elif plan.op=="remove": rewards[id+("_sapling" if fruit_tree else "_kit")]=1
	var exchange:=Inventory.preview_exchange(required,rewards,coins)
	if exchange.is_empty() or exchange.has("diamonds"): return false
	# Territory holds its transaction lock; publish only after the entity and funds both commit.
	Inventory.items=exchange.items;Inventory.coins=exchange.coins
	if plan.op=="place" and not fruit_tree and id in Kitchen.FACILITIES:
		if id not in state.legacy_installed: state.legacy_installed.append(id)
		if id not in Kitchen.state.built: Kitchen.state.built.append(id)
	return true

func after_plan(plan: Dictionary, placed_id: String="") -> void:
	if not str(plan.kind).begins_with("orchard_"): return
	if plan.op=="place":
		var fruit: String=str(plan.kind).trim_prefix("orchard_")
		state.orchard[placed_id]={"planted_day":GameClock.day,"next_fruit_day":GameClock.day+int(HarvestCatalog.data().orchard[fruit].growth_days),"fruit":0,"settled_day":GameClock.day}
	elif plan.op=="remove": state.orchard.erase(str(plan.id))

func settle_orchard() -> void:
	if busy or GameState.restoring: return
	var updated: bool=false
	for id in state.orchard:
		var row: Dictionary=state.orchard[id]
		if int(row.settled_day)>=GameClock.day: continue
		var entry:=Territory.object(id)
		if entry.is_empty(): continue
		var tree: Dictionary=HarvestCatalog.data().orchard[str(entry.kind).trim_prefix("orchard_")]
		row.settled_day=GameClock.day;updated=true
		if int(row.fruit)==0 and GameClock.day>=int(row.next_fruit_day) and Calendar.season() in tree.seasons: row.fruit=int(tree.yield)
	if updated: changed.emit();Events.progress_committed.emit()

func tree_age(id: String) -> int:
	return maxi(0,GameClock.day-int(state.orchard.get(id,{}).get("planted_day",GameClock.day)))
func tree_texture(entry: Dictionary) -> Texture2D:
	var fruit: String=str(entry.get("kind","")).trim_prefix("orchard_")
	if not HarvestCatalog.data().orchard.has(fruit): return null
	var stage: String="fruit" if int(state.orchard.get(str(entry.get("id","")),{}).get("fruit",0))>0 else "mature" if tree_age(str(entry.get("id","")))>=int(HarvestCatalog.data().orchard[fruit].growth_days) else "growing" if tree_age(str(entry.get("id","")))>=4 else "young"
	return load("res://assets/harvest/orchard/%s_%s_%s.png" % [fruit,stage,Calendar.SEASON_IDS[Calendar.season()]])

func harvest_fruit(id: String) -> bool:
	if not near_device(id) or not state.orchard.has(id): return false
	var row: Dictionary=state.orchard[id]
	if int(row.fruit)<=0: return false
	var fruit: String=str(Territory.object(id).kind).trim_prefix("orchard_")
	var exchange:=Inventory.preview_exchange({},{fruit:int(row.fruit)},0)
	if exchange.is_empty(): Events.notice.emit("背包已满，成熟果实保留在树上。");return false
	busy=true;var amount: int=int(row.fruit);Inventory.items=exchange.items;row.fruit=0
	row.next_fruit_day=GameClock.day+int(HarvestCatalog.data().orchard[fruit].regrow_days)
	Inventory.changed.emit();changed.emit();busy=false;Events.progress_committed.emit()
	Events.notice.emit("收获"+Catalog.item_name(fruit)+" ×"+str(amount));return true

func buy_sapling(id: String, quantity: int=1) -> bool:
	if not available() or not HarvestCatalog.data().orchard.has(id) or quantity<1 or quantity>99: return false
	var tree: Dictionary=HarvestCatalog.data().orchard[id]
	if not HarvestCatalog.unlocked(str(tree.unlock)): Events.notice.emit("种子合作社建成后供应结果树苗。");return false
	busy=true
	var price: int=ceili(int(tree.sapling_price)*(.8 if VillageProjects.has_project("cooperative") else 1.0))
	var success: bool=Inventory.exchange({},{id+"_sapling":quantity},-price*quantity)
	busy=false
	if success: Events.progress_committed.emit()
	return success
