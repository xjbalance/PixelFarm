extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(8)
	var args:=OS.get_cmdline_user_args()
	if "--write" in args:
		Fixture.stock()
		await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
		Inventory.items.wheat=10;Kitchen.build("mill");Kitchen.enqueue("flour",2)
		var old:=FarmSaveStore.snapshot(game);old.version=27;old.erase("workshop")
		var legacy:=FileAccess.open("user://harvest-legacy.json",FileAccess.WRITE);legacy.store_string(JSON.stringify(old));legacy.close()
		await Touch.place(self,game,"farm",Vector2(704,704));Fixture.cooperative()
		var mill: String=await Fixture.install(self,game,"station_mill")
		Workshop.buy_sapling("apple");var tree: String=await Fixture.install(self,game,"orchard_apple")
		check(mill!="" and tree!="","独立写进程安装设备与果树")
		Inventory.items.strawberry_seed=2;game.farm.use_tool(Vector2i(18,17),"hoe");game.farm.use_tool(Vector2i(18,17),"strawberry_seed");game.farm.use_tool(Vector2i(18,17),"water")
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(3)
		await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,mill)
		check(Workshop.start(mill,"mill_flour",2),"保存前投入新分钟订单")
		Fixture.advance(45);Workshop.select_seed("strawberry")
		check(FarmSaveStore.write(game,"user://harvest-new.json"),"写入当前格式的作物、果树、半成品、旧队列与种子外观")
		var expected:=FileAccess.open("user://harvest-expected.json",FileAccess.WRITE);expected.store_string(JSON.stringify(FarmSaveStore.snapshot(game)));expected.close()
	elif "--legacy" in args:
		var bytes:=FileAccess.get_file_as_bytes("user://harvest-legacy.json")
		var old: Dictionary=JSON.parse_string(bytes.get_string_from_utf8());var migrated:=FarmSaveStore.read("user://harvest-legacy.json")
		check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION,"独立进程读取原v27格式并迁入当前格式")
		var unchanged: bool=true
		for key in old:
			if key not in ["version","tutorial"] and JSON.stringify(old[key])!=JSON.stringify(migrated.get(key)): unchanged=false
		check(GameTutorial.migrate_080(old.tutorial)==migrated.tutorial,"旧档新增帮助视为已读，旧已读记录保留")
		check(unchanged and FileAccess.get_file_as_bytes("user://harvest-legacy.json")==bytes,"迁移不修改旧磁盘字节及任何原有经营字段")
		check(FarmSaveStore.restore(game,migrated),"旧档带旧加工单恢复实际场景")
		await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
		check(not Kitchen.claim_job(1),"旧订单仍不能提前领取")
		GameClock.minutes=1200;GameClock.request_sleep(GameClock.day);await frames(3)
		check(Kitchen.claim_job(1) and Inventory.count("flour")==2 and not Kitchen.claim_job(1),"旧一日工单按原日期结算一次，没有迁移奖励")
	elif "--read-claimed" in args:
		check(FarmSaveStore.restore(game,FarmSaveStore.read("user://harvest-claimed.json")),"第二次独立重启加载领取后的存档")
		check(Workshop.state.jobs.is_empty() and Inventory.count("flour")==2,"已经领取的新工单不会重生")
		for entry in Territory.state.objects:
			if str(entry.kind)=="station_mill": check(not Workshop.claim(entry.id,1),"跨进程旧领取编号无效")
	else:
		var saved:=FarmSaveStore.read("user://harvest-new.json")
		check(not saved.is_empty() and FarmSaveStore.restore(game,saved),"独立读进程完整恢复当前格式")
		await frames(5)
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://harvest-expected.json"))
		check(JSON.stringify(AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game)))==JSON.stringify(AbyssSaveSchema.canonical(expected)),"新进程逐字段恢复原进度、投入材料、树龄与当前种子")
		check(GameState.tool()=="strawberry_seed" and game.farm.plots["18,17"].days==1,"新作物生长与快捷栏装备跨重启保持")
		var device: String=Workshop.state.jobs.keys()[0];var serial: int=Workshop.state.jobs[device].id
		Fixture.advance(45);await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,device)
		check(Workshop.claim(device,serial) and Inventory.count("flour")==2,"重启后只加工剩余时间并领取两份面粉")
		check(FarmSaveStore.write(game,"user://harvest-claimed.json"),"领取状态原子落盘")
	print("HARVEST PERSISTENCE %s RESULT: %d checks, %d failures" % [str(args),checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
