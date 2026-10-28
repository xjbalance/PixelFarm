extends "res://tests/runner.gd"
## 与附属地素材套分开：同一块正常农场空地逐个实放，不清空原资源以迁就摆放。
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true))
	var before: Dictionary={"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"resources":game.resource_world.snapshot(),"plots":game.farm.plots.duplicate(true)}
	check(game.territory_editor.open(),"从初始农场进入真实编辑器，不额外开放章节或清理资源")
	await frames(4)
	var ids: Dictionary={};var saves_valid: bool=true;var used: int=0
	for kind in TerritoryCatalog.OBJECT_KINDS:
		var plan:=Territory.plan_place("farm",str(kind),Vector2i(20,5))
		var placed: bool=plan.valid and Territory.apply_plan(plan)
		check(placed,"正常农场空地实际摆放："+str(kind)+(" · "+str(plan.reason) if not plan.valid else ""))
		if not placed: continue
		await frames(4)
		var id: String=Territory.state.objects[-1].id;ids[id]=true;used+=1
		saves_valid=FarmSaveStore.valid(FarmSaveStore.snapshot(game)) and saves_valid
		check(Territory.apply_plan(Territory.plan_remove(id)),"同一唯一ID拆除："+str(kind))
		await frames(4)
	check(used==TerritoryCatalog.OBJECT_KINDS.size() and ids.size()==used and Territory.state.objects.is_empty(),"全部素材可以在真实农场轮流摆放，ID不复用、无残留副本")
	check(saves_valid,"每一款农场物件都通过含原物布局的完整v27存档校验")
	var after: Dictionary={"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"resources":game.resource_world.snapshot(),"plots":game.farm.plots.duplicate(true)}
	check(before==after,"逐款摆放与拆除不修改钱物、真实农田或原资源状态")
	var file:=FileAccess.open("res://builds/farm-edit-kinds-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"kinds":used,"unique_ids":ids.size(),"area":"farm","cell":[20,5],"original_resources_cleared":false,"android_device_tested":false},"\t"));file.close()
	print("FARM EDIT KINDS STATE RESULT: %d checks, %d failures" % [checked,failed])
	game.territory_editor.cancel();game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
