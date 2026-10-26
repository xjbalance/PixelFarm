extends "res://tests/runner.gd"
## 每个参数由独立Godot进程执行，调用者必须使用同一个隔离用户目录。
const Home=preload("res://tests/home05_runner.gd")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if "--corrupt-home05" in args:
		var broken:=FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);broken.store_string("interrupted home construction save");broken.close()
		print("HOME 05 CORRUPT: PASS");get_tree().quit();return
	var writing_pending: bool="--write-home05-pending" in args
	var reading_pending: bool="--read-home05-pending" in args
	var writing_sofa: bool="--write-home05-sofa" in args
	var reading_sofa: bool="--read-home05-sofa" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing_pending and not writing_sofa;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if writing_pending:
		Inventory.coins=50000;Inventory.items={"wood":999,"stone":999,"iron_bar":99,"star_fragment":99,"carrot_seed":7};Xiaojing.state.diamonds=1314
		await Home.visit_builder(self,game)
		check(Housing.upgrade(1),"独立写进程从周砚真实预约二级施工")
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"施工只度过一个合法夜晚后保存")
		await frames(5)
		check(Housing.state.level==1 and not Housing.state.construction.is_empty(),"待施工存档保留原一级与剩余一天")
		write_proof("user://home05-pending-proof.json")
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"待施工状态真正写入主档和备份")
	elif reading_pending:
		var proof:=read_proof("user://home05-pending-proof.json")
		check(same_fields(proof),"独立重启逐字段保留待施工进度和原资源")
		var coins: int=Inventory.coins;var items: Dictionary=Inventory.items.duplicate(true)
		Housing.settle_day();await frames(4)
		check(Housing.state.level==1 and not Housing.state.construction.is_empty(),"重启当天不会补算第二日或提前完成")
		GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"独立重启后正常睡第二晚完成施工")
		await frames(5)
		check(Housing.state.level==2 and Housing.state.construction.is_empty() and Inventory.coins==coins and Inventory.items==items,"施工完成只改变等级，不重复扣费")
		write_proof("user://home05-finished-proof.json")
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"完成施工再次形成独立主档与备份")
	elif writing_sofa:
		Inventory.coins=321;Inventory.items={"carrot_seed":7,"wood":12};Xiaojing.state.diamonds=1314
		game.change_location("home",game.home_rest.SOFA+Vector2(0,36));await frames(5)
		GameClock.minutes=600;GameState.stamina=10
		check(game.home_rest.open(),"独立进程从真实沙发打开确认")
		var token: int=game.home_rest.pending_token
		check(game.home_rest.confirm(token),"小睡确认在过渡前同步完成状态")
		check(GameClock.minutes==660 and GameState.stamina==mini(GameState.max_stamina(),10+ceili(GameState.max_stamina()*.5)),"过渡期间分钟与体力已是完整结果")
		var token_file:=FileAccess.open("user://home05-sofa-token.json",FileAccess.WRITE);token_file.store_string(JSON.stringify({"token":token}));token_file.close()
		write_proof("user://home05-sofa-proof.json")
		check(FarmSaveStore.write(game),"小睡过渡期间可保存完整结果，不写pending动画")
	elif reading_sofa:
		var proof:=read_proof("user://home05-sofa-proof.json")
		check(same_fields(proof) and game.player.farm_action.is_empty(),"重启保留小睡后的完整资源时间，不恢复运行任务")
		var before:=FarmSaveStore.snapshot(game)
		var token_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://home05-sofa-token.json"))
		check(not game.home_rest.confirm(int(token_data.token)),"重启后旧沙发确认不能再次生效")
		await frames(30)
		check(FarmSaveStore.snapshot(game)==before and not game.home_rest.busy and game.home_rest.pending_token<0 and not game.home_rest.panel.visible,"重启等待后无额外时间/体力或悬空确认")
	else:
		var proof:=read_proof("user://home05-finished-proof.json")
		check(same_fields(proof) and Housing.state.level==2,"完成施工跨独立重启及坏主档回退保持全部原字段")
		var before:=Housing.snapshot();Housing.settle_day();GameClock.day_advanced.emit();await frames(4)
		check(Housing.snapshot()==before,"已完成施工的日结算和旧job不会重复领取")
		check(FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty(),"恢复备份后仍能安全写回有效主档")
	print("HOME 05 PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func write_proof(path: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(FarmSaveStore.snapshot(game)));file.close()

func read_proof(path: String) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))

func same_fields(proof: Dictionary) -> bool:
	var now: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
	var result:=true
	for key in proof:
		if now.get(key)!=proof[key]: result=false;print("HOME PERSISTENCE MISMATCH ",key)
	return result
