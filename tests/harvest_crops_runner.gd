extends "res://tests/runner.gd"
var original: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	original=FarmSaveStore.snapshot(game)
	check(Catalog.crops.size()==33 and HarvestCatalog.data().orchard.size()==4,"原三种作物加27季节作物与3花卉；果树独立定义")
	for id in Catalog.crops:
		FarmSaveStore.restore(game,original);GameClock.running=false
		var crop: CropDefinition=Catalog.crops[id]
		var season: int=int(Catalog.config.crop_seasons[id][0]);GameClock.day=season*28+1;Calendar.restore(Calendar.snapshot(GameClock.day));game.farm.last_growth_day=GameClock.day
		Inventory.items[id+"_seed"]=4;GameState.stamina=100
		var cell:=Vector2i(18,17)
		check(game.farm.use_tool(cell,"hoe") and game.farm.use_tool(cell,id+"_seed"),"实际农田播种："+id)
		var serial: int=Xiaojing.state.plant_serial
		check(not game.farm.use_tool(cell,id+"_seed") and Xiaojing.state.plant_serial==serial,"重复播种不能追加520计数："+id)
		for day in range(crop.growth_days):
			game.farm.use_tool(cell,"water");GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
		check(game.farm.is_mature(game.farm.plot_at(cell)),"每日浇水按配置成熟："+id)
		var before: int=Inventory.count(id)
		check(game.farm.use_tool(cell,"hand") and Inventory.count(id)==before+crop.harvest_quantity,"配置数量一次收获且ID不变："+id)
		if HarvestCatalog.data().crops.has(id):
			var forbidden: int=-1
			for index in range(4):
				if index not in Catalog.config.crop_seasons[id]: forbidden=index;break
			if forbidden>=0:
				GameClock.day=forbidden*28+1;var held: int=Inventory.count(id+"_seed")
				check(not game.farm.use_tool(cell,id+"_seed") and Inventory.count(id+"_seed")==held,"季节不符拒绝且保留种子："+id)
	FarmSaveStore.restore(game,original);GameClock.running=false
	var old:=original.duplicate(true);old.version=27;old.erase("workshop")
	check(FarmSaveStore.valid(old),"真实v27旧档迁移可读")
	var migrated:=FarmSaveSchema.normalize(old)
	var same: bool=true
	for key in old:
		if key!="version" and JSON.stringify(old[key])!=JSON.stringify(migrated.get(key)): same=false
	check(same and migrated.version==28,"旧档经营、婚姻、背包、田地与控制模式逐字段保留")
	Inventory.items.strawberry_seed=3;Workshop.select_seed("strawberry")
	check(GameState.tools.size()==9 and GameState.tool()=="strawberry_seed","九格布局内可装备新种子")
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,saved) and GameState.tool()=="strawberry_seed","新种子装备状态保存恢复")
	var bad:=saved.duplicate(true);bad.workshop.selected_seed="invalid_seed"
	check(not FarmSaveStore.valid(bad),"未知种子状态拒绝读入")
	Inventory.coins=99999
	check(not FarmEconomy.buy("blueberry",1),"跨季或未建合作社不能提前买高级种子")
	check(FarmEconomy.buy("strawberry",1),"春季基础草莓种子正常购买")
	Inventory.items.tomato=3;game.hud.inventory_panel.open_panel(true)
	var found: bool=false;var blocked_seed: bool=false
	for page in range(5):
		game.hud.inventory_panel.crop_page=page;game.hud.inventory_panel.content_key="";game.hud.inventory_panel.refresh()
		if game.hud.inventory_panel.row_views.has("crop:tomato"):
			found=true
			for button in game.hud.inventory_panel.row_views["crop:tomato"].actions:
				if button.get_meta("action_kind","")=="seed_buy": blocked_seed=button.disabled
			break
	check(found and blocked_seed,"非当季持有作物仍列入出售页，但不开放跨季种子购买")
	check(FarmEconomy.sell("tomato",2) and Inventory.count("tomato")==1,"跨季库存可以按数量正常出售")
	game.hud.inventory_panel.close_panel()
	print("HARVEST CROPS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
