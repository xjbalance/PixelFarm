extends "res://tests/runner.gd"
## 六个独立进程：女主写/读/坏主档/备份读/真实v24写/迁移读。
var legacy: bool=false

func canonical(raw: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(raw)))
func proof_path() -> String: return "user://appearance-v24-proof.json" if legacy else "user://appearance-proof.json"
func write_json(path: String, raw: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(raw));file.close()
func read_json(path: String) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--corrupt-appearance" in args:
		var file:=FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);file.store_string("interrupted appearance save");file.close()
		print("APPEARANCE CORRUPT: PASS");get_tree().quit();return
	legacy="--write-appearance-v24" in args or "--read-appearance-v24" in args
	var writing: bool="--write-appearance" in args or "--write-appearance-v24" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if writing: await write_fixture()
	else: await read_fixture()
	print("APPEARANCE PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func write_fixture() -> void:
	var Arrange=load("res://tests/home_arrange_runner.gd")
	check(await Arrange.setup_married_home(self,game),"独立写进程形成真实已婚三级住宅、旧家具与柜存")
	Appearance.set_player_gender("female")
	Inventory.coins=7319;GameState.stamina=37;GameState.set_control_mode("joystick",false)
	var resources: Dictionary=game.resource_world.snapshot()
	resources.tree_7_20={"hp":0,"ready_day":GameClock.day+3};resources.rock_11_19={"hp":1,"ready_day":0}
	game.resource_world.restore(resources);game.change_location("home",Vector2(640,500));await frames(5)
	var now: Dictionary=canonical(FarmSaveStore.snapshot(game))
	check(now.version==FarmSaveStore.VERSION and FarmSaveStore.valid(now) and now.appearance==CharacterAppearance.defaults("female"),"确认女主和男小京形成合法v25完整档")
	if legacy:
		var old: Dictionary=now.duplicate(true);old.version=24;old.erase("appearance");old.erase("territory");old.erase("farm_layout")
		check(FarmSaveStore.valid(old) and old.version==24 and not old.has("appearance"),"旧写进程构造严格真实v24形状，移除现代外观字段")
		write_json(proof_path(),old);write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		var existing: PackedStringArray=DirAccess.get_files_at("user://")
		var backed_up: bool=FarmSaveStore.backup_before_new_game();var backup_path: String=""
		for name in DirAccess.get_files_at("user://"):
			if str(name).begins_with("farm_save.json.before_new_game") and name not in existing: backup_path="user://"+str(name)
		write_json("user://appearance-v24-backup-proof.json",{"path":backup_path})
		check(backed_up and backup_path!="" and read_json(backup_path)==old,"新开局备份保留真正v24原字节，不提前改写磁盘结构")
		check(read_json(FarmSaveStore.PATH).version==24 and FarmSaveStore.read().appearance==CharacterAppearance.defaults(),"读取v24在内存补男主/女小京，原文件仍为v24")
	else:
		write_json(proof_path(),now)
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"女性主角、男性小京与原全部经营数据写入真实主档和备份")
		check(read_json(FarmSaveStore.PATH)==now,"新档磁盘保存外观，但不保存未确认选择或新开局种子")

func read_fixture() -> void:
	var proof:=read_json(proof_path());var now:=canonical(FarmSaveStore.snapshot(game))
	var same: bool=true
	for key in proof:
		if legacy and key=="version": continue
		if proof[key]!=now.get(key): same=false;print("APPEARANCE RESTART DIFFERENCE ",key)
	check(same and now.version==FarmSaveStore.VERSION,"独立重启逐旧字段恢复全部原钱物、房屋、农田、矿洞和小京进度")
	var expected:=CharacterAppearance.defaults() if legacy else CharacterAppearance.defaults("female")
	check(Appearance.snapshot()==expected and now.appearance==expected,"独立重启恢复正确对应，不被默认男主覆盖女主存档")
	check(Appearance.player_asset().contains("player_"+str(expected.player_gender)) and Appearance.companion_asset().contains("xiaojing_"+str(expected.xiaojing_gender)),"世界资源解析与磁盘确认的主角及小京性别一致")
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible and GameState.stamina==37,"外观迁移保留原操作模式与当前体力")
	check(Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130,"外观不重置婚姻、婚礼钻石或既有卧室体力升级")
	check(Housing.state.level==3 and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"住宅等级、柜存与原家具不因新外观复制或消失")
	check(game.resource_world.fields.farm.state.tree_7_20==proof.resources.tree_7_20 and game.resource_world.fields.farm.state.rock_11_19==proof.resources.rock_11_19,"新旧外观读档保留耗尽树的恢复日与半损石头")
	check(not game.get("awaiting_character_choice") and game.auto_move.target.is_empty() and not GameState.modal,"有已保存外观或真实旧档时不弹新开局选择、不重放交互")
	var before: Dictionary=now.duplicate(true);var stable: bool=true
	for _i in range(2):
		stable=FarmSaveStore.restore(game,before) and stable;await frames(4)
	check(stable and canonical(FarmSaveStore.snapshot(game))==before,"同日重复读取不重复发资源、婚姻或外观奖励")
	check(FarmSaveStore.write(game) and FarmSaveStore.read().version==FarmSaveStore.VERSION,"恢复后按原tmp/备份机制安全写回当前v25")
	if legacy:
		var backup: Dictionary=read_json("user://appearance-v24-backup-proof.json")
		check(read_json(str(backup.path))==proof,"写入v25后原独立v24备份仍完整保留")
