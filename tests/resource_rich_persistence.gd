extends "res://tests/runner.gd"
## 六个独立进程：旧档写/旧档读/新采集写/重启读/坏主档/备份读。外部隔离目录。
const Rich=preload("res://tests/resource_rich_runner.gd")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--corrupt-resource-rich" in args:
		var broken:=FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);broken.store_string("interrupted resource field save");broken.close()
		print("RESOURCE RICH CORRUPT: PASS");get_tree().quit();return
	var legacy_write: bool="--write-resource-rich-legacy" in args
	var legacy_read: bool="--read-resource-rich-legacy" in args
	var writing: bool="--write-resource-rich" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not legacy_write and not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if legacy_write:
		Inventory.items={"wood":37,"stone":23,"carrot_seed":17};Inventory.coins=7821;Xiaojing.state.diamonds=1314
		GameState.set_control_mode("joystick",false)
		var old:=FarmSaveStore.snapshot(game);old.version=23;old.erase("appearance");old.erase("territory");old.erase("farm_layout");old.housing.erase("builtins");old.resources=Rich.legacy_resources(old.resources)
		old.resources.tree_7_20={"hp":0,"ready_day":GameClock.day+3};old.resources.rock_11_19={"hp":1,"ready_day":0}
		check(old.version==23 and old.resources.size()==19 and FarmSaveStore.valid(old),"独立旧档仅包含实际v23原19资源节点")
		write_json("user://resource-rich-legacy-proof.json",old)
		write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		check(FileAccess.file_exists(FarmSaveStore.PATH) and FarmSaveStore.read().resources.size()==19,"旧扁平格式真正写入主档和备份")
	elif legacy_read:
		var old:=read_json("user://resource-rich-legacy-proof.json")
		var now: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game));var preserved:=true
		for key in old:
			if key not in ["version","housing","resources"] and old[key]!=now.get(key): preserved=false;print("RESOURCE LEGACY MISMATCH ",key)
		for field in old.housing:
			if old.housing[field]!=now.housing.get(field): preserved=false;print("RESOURCE LEGACY HOUSING MISMATCH ",field)
		check(preserved,"旧档独立重启逐字段保留原金币背包婚礼钻石与操作模式")
		var kept:=true
		for id in old.resources: kept=kept and now.resources[id]==old.resources[id]
		check(kept and now.resources.size()==128,"旧已砍树和半损石完整保留，仅补新增资源ID")
		var full:=true;var all: Dictionary=FarmResourceCatalog.all_placements()
		for id in all:
			if not old.resources.has(id): full=full and now.resources[id]=={"hp":int(FarmResourceCatalog.TYPES[all[id].kind].hits),"ready_day":0}
		check(full,"新图与新增节点按各自默认耐久初始化，无物品补发")
		check(FarmSaveStore.write(game) and FarmSaveStore.read().resources.size()==128,"旧档升级后安全写回当前格式扩展资源集合")
	elif writing:
		Inventory.items={"wood":4,"stone":3,"carrot_seed":17};Inventory.coins=7921;Xiaojing.state.diamonds=1314;GameState.rest()
		await Rich.visit(self,game,"farm")
		var farm: Node2D=game.resource_world.fields.farm
		check(await Rich.approach_resource(self,game,"farm","tree_7_20"),"独立进程实走到原农场树木")
		var collected:=true
		for _i in range(3): collected=await Rich.click_resource_once(self,game,"farm","tree_7_20") and collected
		check(await Rich.click_resource_once(self,game,"farm","rock_11_19") and collected,"旧树采空和旧石部分耐久保存前真实产生")
		await Rich.visit(self,game,"mist_forest")
		var field: Node2D=game.resource_world.fields.mist_forest
		var tree_sample: Dictionary=await Rich.visible_resource(self,game,"mist_forest","tree")
		var tree: String=str(tree_sample.get("id",""))
		var rock_sample: Dictionary=await Rich.visible_resource(self,game,"mist_forest","rock")
		var rock: String=str(rock_sample.get("id",""))
		check(tree!="" and rock!="","新增森林存在可实际接近的树木石堆")
		if tree!="" and rock!="":
			collected=await Rich.approach_resource(self,game,"mist_forest",tree)
			for _i in range(3): collected=await Rich.click_resource_once(self,game,"mist_forest",tree) and collected
			collected=await Rich.click_resource_once(self,game,"mist_forest",rock) and collected
			check(collected and field.state[tree].hp==0 and field.state[rock].hp==1,"新增图同样写入真实耗尽与半损状态")
		GameState.set_control_mode("joystick",false);await frames(5)
		write_json("user://resource-rich-proof.json",FarmSaveStore.snapshot(game))
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"三张地图资源真正写入独立主档和有效备份")
	else:
		var proof:=read_json("user://resource-rich-proof.json")
		# 磁盘JSON的15位小数与Vector2的float32升double表示不同；比较相同磁盘表示，
		# 不给资源/数值增加容差，也不把亚像素位置舍入到人为网格。
		var loaded: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(FarmSaveStore.snapshot(game))))
		for key in proof:
			if loaded.get(key)!=proof[key]: print("RESOURCE RESTART MISMATCH ",key," expected=",proof[key]," actual=",loaded.get(key))
		check(loaded==proof,"独立重启及坏主档回退逐字段恢复全资源与原玩家数据")
		check(GameState.location=="mist_forest" and GameState.control_mode=="joystick" and Xiaojing.state.diamonds==1314,"重启保留森林位置、备用摇杆与1314钻石")
		check(game.resource_world.fields.farm.state.tree_7_20.hp==0 and game.resource_world.fields.farm.state.rock_11_19.hp==1,"独立重启不刷新旧已砍/已破坏进度")
		var before: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game));var stable:=true
		for _i in range(3): stable=FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(before))) and stable;await frames(4)
		check(stable and AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))==before and game.auto_move.target.is_empty(),"同日三次读档不重复采矿产物、恢复耐久或旧交互任务")
		check(FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty(),"备份恢复后仍可安全写回完整资源状态")
	print("RESOURCE RICH PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func write_json(path: String, value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()

func read_json(path: String) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))
