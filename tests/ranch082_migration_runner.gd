extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
var old: Dictionary
var normalized: Dictionary
var report: Dictionary={"preserved_sections":[],"checks":{}}
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/ranch082/legacy081-source-proof.json"))
	check(proof.source_version=="0.8.1" and proof.schema==29 and proof.failures==0,"legacy fixture actually produced by passing old 244c379 source")
	old=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://docs/ranch082/legacy081-v29.json")))
	normalized=FarmSaveSchema.normalize(old)
	check(not normalized.is_empty() and normalized.version==30,"actual v29 full save migrates to v30")
	if normalized.is_empty(): await finish();return
	for section in old:
		if section in ["version","resources","livestock"]: continue
		check(normalized[section]==old[section],"migration preserves entire existing section "+str(section));report.preserved_sections.append(section)
	check(normalized.livestock.animals.size()==old.livestock.animals.size() and normalized.livestock.buildings==old.livestock.buildings,"all original animals and paid upgrades preserved")
	for i in range(old.livestock.animals.size()):
		var original: Dictionary=old.livestock.animals[i];var migrated: Dictionary=normalized.livestock.animals[i].duplicate(true);migrated.erase("pasture_position")
		check(migrated==original,"animal ID age hunger mood feed pet products and old logical position retained "+original.id)
	check(normalized.resources.tree_5_8.hp==0 and normalized.resources.tree_5_8.ready_day==0,"old pending farm regrowth becomes permanently cleared land")
	check(normalized.resources.tree_7_20==old.resources.tree_7_20,"old partial tree durability preserved")
	for id in old.resources:
		if id.begins_with("mist_forest_") or id.begins_with("village_"): check(normalized.resources[id]==old.resources[id],"wild resource state and regrowth untouched "+str(id))
	check(FarmSaveSchema.normalize(normalized)==normalized,"migration is idempotent, no repeated animal or reward grants")
	check(FarmSaveStore.restore(game,old),"real old world restores in expanded game")
	await frames(6)
	for entry in Livestock.state.animals:
		var node:=animal_node(str(entry.id))
		check(node!=null and node.get_parent()==game.mine_maps[Livestock.animal_area(entry)].get_node("Actors"),"one real animal node belongs to correct pasture "+entry.id)
		check(node.position.distance_to(Livestock.animal_point(entry))<.1,"restored world body matches persistent pasture position "+entry.id)
	check(Inventory.items==old.items and Inventory.coins==old.coins and Xiaojing.state.married and Housing.state.level==4,"migration gives no currency/material reward and preserves marriage and house")
	check(game.farm.plots==old.plots and FarmLayout.snapshot()==old.farm_layout,"all old physical crop and DIY coordinates remain exact")
	var repeat:=Livestock.snapshot();Livestock.settle_day();GameClock.day_advanced.emit();check(Livestock.snapshot()==repeat,"reload cannot replay the settled animal day")
	await identity_changes()
	await bush_compatibility()
	await diy()
	await safety()
	var snapshot:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"v30 real disk save and backup written")
	var loaded: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.read());var expected: Dictionary=AbyssSaveSchema.canonical(FarmSaveSchema.normalize(snapshot))
	check(Vector2(loaded.player[0],loaded.player[1])==Vector2(expected.player[0],expected.player[1]),"disk player position remains exact at Godot vector precision")
	expected.player=loaded.player
	check(loaded==expected,"disk roundtrip keeps world sparse plots herd and production orders")
	report.checks={"total":checked,"failures":failed};var file:=FileAccess.open("res://docs/ranch082/migration-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	await finish()
func animal_node(id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("livestock_animals"):
		if node.animal_id==id: return node
	return null
func identity_changes() -> void:
	var alternate:=normalized.duplicate(true);var entry: Dictionary=alternate.livestock.animals[0]
	entry.site="barn";entry.species="cow";entry.age=6;entry.progress=0;entry.position=[392,896];entry.pasture_position=[768,112]
	check(FarmSaveStore.restore(game,alternate),"different valid save can reuse an animal ID in another barn")
	await frames(5)
	var node:=animal_node(str(entry.id))
	check(node.get_parent()==game.mine_maps.pasture_barn.get_node("Actors") and node.species_id=="cow","reused ID reparents actual body and refreshes four-way species art")
	check(get_tree().get_nodes_in_group("livestock_animals").size()==4,"cross-save identity change creates no duplicate animals")
	check(FarmSaveStore.restore(game,normalized),"restore original herd without loss")
	await frames(5);node=animal_node(str(entry.id))
	check(node.get_parent()==game.mine_maps.pasture_coop.get_node("Actors") and node.species_id=="chicken","reused ID restores original poultry identity and map")
func bush_compatibility() -> void:
	var legacy:=old.duplicate(true)
	legacy.plots["17,12"]={"crop":"wheat","days":1,"watered":true}
	var migrated:=FarmSaveSchema.normalize(legacy)
	check(not migrated.is_empty() and migrated.resources.get("brush_original_0",{}).get("hp",1)==0,"old legal crop overlapping cosmetic bush is protected during migration")
	check(migrated.plots==legacy.plots and migrated.items==legacy.items,"bush conversion never clears crop or gives material compensation")
	check(FarmSaveStore.restore(game,legacy),"old decorative overlap restores safely")
	await frames(4)
	check(not game.resource_world.fields.farm.objects.brush_original_0.sprite.visible and game.farm.plots["17,12"].crop=="wheat","new resource cannot reappear over existing crop")
	check(FarmSaveStore.restore(game,normalized),"return to actual old save")
	await frames(5)
func diy() -> void:
	game.change_location("farm",Livestock.site_point("coop")+Vector2(0,32));await frames(24)
	var animals:=Livestock.snapshot();var original:=FarmLayout.snapshot()
	check(game.territory_editor.open(),"existing farm DIY manages original shelter");await frames(4)
	var plan:=FarmLayout.plan_store("fixture","coop")
	check(plan.valid and FarmLayout.apply_plan(plan),"store original shelter through existing safe UI framework");await frames(4)
	check(Livestock.snapshot()==animals and not animal_node(str(animals.animals[0].id)).visible,"shelter storage preserves whole herd products and stops body activity")
	check(not WorldTravel.change(game,"pasture_coop"),"stored barn cannot leave orphaned pasture entrance")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"stored livestock shelter remains valid save")
	plan=FarmLayout.plan_restore("fixture","coop",Vector2i(66,50))
	check(plan.valid and FarmLayout.apply_plan(plan),"restore existing shelter onto expanded legal farm");await frames(5)
	check(Livestock.snapshot()==animals,"barn relocation does not change animal IDs products or pasture coordinates")
	var gate: Node2D
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("livestock_id")=="pasture_gate:coop" and not node.get("returning"): gate=node;break
	check(gate!=null and gate.position==Livestock.gate_point("coop"),"real gate follows moved barn")
	game.territory_editor.cancel();game.change_location("farm",Livestock.gate_point("coop")+Vector2(0,32));await frames(5)
	check(Livestock.enter_pasture("coop") and GameState.location=="pasture_coop","moved barn gate opens same real herd pasture")
	await frames(4)
	check(Livestock.snapshot()==animals,"scene switch preserves stored fed pet growth and product records")
	game.change_location("farm",Livestock.site_point("barn")+Vector2(0,32));await frames(5)
	var count: int=Livestock.summary("barn").count;var products: int=Livestock.summary("barn").products
	check(Livestock.upgrade("barn") and Livestock.summary("barn").count==count and Livestock.summary("barn").products==products,"paid existing barn upgrade changes capacity without copying animals or products")
	FarmLayout.restore(original);await frames(5)
	check(FarmSaveStore.restore(game,normalized),"DIY roundtrip can restore original full state")
	await frames(5)
func safety() -> void:
	var id: String=str(Livestock.state.animals[0].id)
	game.change_location("pasture_coop",Livestock.animal_point(Livestock.animal(id))+Vector2(0,32));await frames(4)
	var before:=Livestock.snapshot();var items:=Inventory.items.duplicate(true)
	game.backgrounded=true
	check(not Livestock.feed(id) and not Livestock.pet(id) and not Livestock.collect(id),"background cannot submit delayed animal actions")
	game.backgrounded=false;GameState.restoring=true
	check(not Livestock.feed(id) and not Livestock.collect(id),"restore transaction blocks animal mutations")
	GameState.restoring=false
	check(Livestock.snapshot()==before and Inventory.items==items,"blocked callbacks leave feed energy products and inventory unchanged")
	var attempts: Array=[]
	var callback:=func(): attempts.append([Livestock.feed(id),FarmSaveStore.write(game)])
	Inventory.changed.connect(callback)
	check(Livestock.feed(id),"legitimate new-day feed remains available")
	Inventory.changed.disconnect(callback)
	check(attempts.size()==1 and attempts[0]==[false,false],"inventory signal reentry cannot double-feed or save half a transaction")
	check(FarmSaveStore.restore(game,normalized),"restore initial test state after transaction checks");await frames(5)
	var bad:=old.duplicate(true);bad.resources.tree_5_8.hp=-1
	check(FarmSaveSchema.normalize(bad).is_empty(),"migration rejects negative durability instead of sanitizing malicious rewards")
	bad=old.duplicate(true);bad.livestock.animals.append(bad.livestock.animals[0].duplicate(true))
	check(FarmSaveSchema.normalize(bad).is_empty(),"migration refuses duplicate animal ID")
	bad=normalized.duplicate(true);bad.livestock.animals[0].pasture_position=[-100,100]
	check(not FarmSaveStore.valid(bad),"save rejects animal outside real fence")
	bad=normalized.duplicate(true);bad.livestock.animals[0].pasture_position=[384,100]
	check(not FarmSaveStore.valid(bad),"save rejects animal inside shelter wall")
	bad=normalized.duplicate(true);bad.location="pasture_coop";bad.player=[512,672];bad.farm_layout.fixtures.coop={"cell":[5,27],"stored":true}
	check(not FarmSaveStore.valid(bad),"save rejects pasture location with stored inaccessible shelter")
func finish() -> void:
	print("RANCH082 MIGRATION RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
