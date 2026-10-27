extends "res://tests/runner.gd"
## 独立进程序列：v23写/迁移读/布置写/布置读/坏主档/备份读。外部隔离用户目录。
const Arrange=preload("res://tests/home_arrange_runner.gd")
const Home=preload("res://tests/home05_runner.gd")

func run() -> void:
	get_window().size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	if "--corrupt-home-arrange" in args:
		write_json(FarmSaveStore.PATH,{"interrupted":"home arrangement"})
		print("HOME ARRANGE CORRUPT: PASS");get_tree().quit();return
	var legacy_write: bool="--write-home-arrange-v23" in args
	var legacy_read: bool="--read-home-arrange-v23" in args
	var writing: bool="--write-home-arrange" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not legacy_write and not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if legacy_write:
		check(await Arrange.setup_married_home(self,game),"v23写进程真实三级施工、自制椅与柜存")
		await Home.visit_builder(self,game);check(Housing.upgrade(3),"旧已婚住宅仍有真实进行中的四级施工单")
		var old:=FarmSaveStore.snapshot(game);old.version=23;old.housing=Arrange.legacy_v23(old.housing)
		check(FarmSaveStore.valid(old) and not old.housing.has("builtins") and old.stamina==130 and old.xiaojing.married,"写入严格真实v23格式，保留130体力与旧婚姻")
		write_json("user://home-arrange-v23-proof.json",old);write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		check(not FarmSaveStore.read().is_empty(),"真实v23结构保存到磁盘且能规范读取")
	elif legacy_read:
		var old:=read_json("user://home-arrange-v23-proof.json");var now: Dictionary=Arrange.disk_snapshot(game);var kept:=true
		for key in old:
			if key not in ["version","housing"] and old[key]!=now.get(key): kept=false;print("HOME ARRANGE V23 MISMATCH ",key)
		for key in old.housing:
			if old.housing[key]!=now.housing.get(key): kept=false;print("HOME ARRANGE V23 HOUSING MISMATCH ",key)
		check(kept and now.version==24 and not now.housing.builtins.is_empty(),"独立重启迁移逐旧字段保留，仅补builtins与版本")
		check(Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130 and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"旧婚姻钻石、自制家具与柜存不会因布置更新重置")
		var layout: Dictionary=Housing.state.builtins.duplicate(true);var items: Dictionary=Inventory.items.duplicate(true);var coins: int=Inventory.coins
		for _i in range(2): GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"已付费旧施工单在迁移后合法经过一晚");await frames(5)
		check(Housing.state.level==4 and Housing.state.construction.is_empty() and Arrange.preserved_upgrade(layout,Housing.state.builtins) and Inventory.items==items and Inventory.coins==coins,"旧施工正常完工，关键布局和既有家具ID保留且不重扣费用")
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"迁移施工完成后形成当前v24有效主档备份")
	elif writing:
		check(await Arrange.setup_married_home(self,game),"布置写进程真实形成已有家具的三级家园")
		for id in ["bed","sofa","kitchen","storage","dining_table"]:
			var cell:=Arrange.find_cell(id)
			check(cell.x>=0 and Housing.move_builtin(id,cell),"独立写进程通过公开规则移动原家具："+id);await frames(5)
		game.change_location("home",Housing.anchor("storage")+Vector2(0,36));await frames(6)
		GameState.set_control_mode("joystick",false)
		var proof: Dictionary=Arrange.disk_snapshot(game);write_json("user://home-arrange-proof.json",proof)
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"动态床灶沙发收纳和自制家具真正写入主档备份")
	else:
		var proof:=read_json("user://home-arrange-proof.json")
		check(Arrange.disk_snapshot(game)==proof,"独立重启及坏主档恢复逐字段保留动态布局与原玩家数据")
		check(not game.home_arrange.active and not game.home_arrange.confirm() and game.auto_move.target.is_empty(),"重启不恢复未提交的布置或旧自动交互")
		var consistent:=true
		for action in ["sleep","sofa","kitchen","storage","mail"]:
			var point:=Arrange.action_point(game,action)
			if not is_instance_valid(point) or point.global_position.distance_to(Housing.anchor(action))>.5: consistent=false
		check(consistent and GameState.control_mode=="joystick" and Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130,"新家具动态功能位置与原模式婚姻体力全部恢复")
		var before: Dictionary=Arrange.disk_snapshot(game);var stable:=true
		for _i in range(3): stable=FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(before))) and stable;await frames(4)
		check(stable and Arrange.disk_snapshot(game)==before,"同日反复读档不复制家具、库存或施工奖励")
		check(FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty(),"布局备份恢复后仍能安全写回完整主档")
	print("HOME ARRANGE PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func write_json(path: String, value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()

func read_json(path: String) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))
