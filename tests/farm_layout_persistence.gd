extends "res://tests/runner.gd"
## 真正的v26原位档、v27搬迁档与独立进程坏档回退。只在隔离用户目录执行。
const Arrange=preload("res://tests/home_arrange_runner.gd")
const Home=preload("res://tests/home05_runner.gd")
var legacy: bool=false

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func proof_path() -> String: return "user://farm-layout-v26-proof.json" if legacy else "user://farm-layout-v27-proof.json"
func write_json(path: String, value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close()
func read_json(path: String) -> Dictionary:
	return canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	legacy="--write-farm-layout-v26" in args or "--read-farm-layout-v26" in args
	if "--corrupt-farm-layout" in args:
		bad_primary();report("corrupt");get_tree().quit(1 if failed else 0);return
	var writing: bool="--write-farm-layout" in args or "--write-farm-layout-v26" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.persistence_enabled=false
	if writing: await write_fixture()
	else: await read_fixture()
	report(("write" if writing else "read")+("-v26" if legacy else "-v27"))
	game.territory_editor.cancel();game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func report(mode: String) -> void:
	var file:=FileAccess.open("res://builds/farm-layout-persistence-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"checks":checked,"failures":failed,"independent_process":true,"android_device_tested":false},"\t"));file.close()
	print("FARM LAYOUT PERSISTENCE "+mode+" RESULT: %d checks, %d failures" % [checked,failed])

func write_fixture() -> void:
	check(await Arrange.setup_married_home(self,game),"用原住宅升级与收纳接口构造已婚三级家，不重发婚姻")
	check(await Home.finish_upgrade(self,game,3),"通过两日施工完成已有四级住宅")
	Appearance.set_player_gender("female");game.tutorial.restore(GameTutorial.defaults(true));Letters.refresh()
	game.change_location("farm",Vector2(656,470));await frames(5)
	Inventory.items.wheat_seed=10;GameState.rest()
	check(game.farm.use_tool(Vector2i(17,16),"hoe"),"沿原农活事务开垦一块旧逻辑田")
	check(game.farm.use_tool(Vector2i(17,16),"wheat_seed") and game.farm.use_tool(Vector2i(17,16),"water"),"真实播种浇水仅消耗原一份种子")
	GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"沿原正式睡眠推进作物成长");await frames(6)
	check(game.farm.plots["17,16"].crop=="wheat" and game.farm.plots["17,16"].days==1,"迁移前拥有真实作物成长进度")
	Inventory.coins=8123;GameState.stamina=37;GameState.set_control_mode("joystick",false)
	var field: Node=game.resource_world.fields.farm
	var resources: Dictionary=game.resource_world.snapshot();resources.tree_5_8={"hp":1,"ready_day":0};resources.rock_11_19={"hp":0,"ready_day":GameClock.day+2};game.resource_world.restore(resources)
	await frames(5)
	check(Housing.state.level==4 and Housing.state.storage.wood==12 and Xiaojing.state.married and Xiaojing.state.diamonds==1314,"旧业务等级、柜存、婚姻与钻石均为原数据")
	if legacy:
		game.change_location("home",Housing.anchor("storage")+Vector2(32,0));await frames(5)
		var old:=snapshot();old.version=26;old.erase("farm_layout")
		check(FarmSaveStore.valid(old) and not old.has("farm_layout"),"构造真正v26结构，没有新增布局字段")
		write_json(proof_path(),old);write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		check(read_json(FarmSaveStore.PATH).version==26 and FarmSaveStore.read().version==FarmSaveStore.VERSION,"旧档只在内存新增原位布局，磁盘原字节暂不改写")
		return
	check(game.territory_editor.open(),"当前农场打开真实编辑器，原实体通过同一确认上下文搬迁")
	await frames(5)
	check(await apply_move("fixture","home",[Vector2i(20,10),Vector2i(21,10),Vector2i(22,10)]),"原住宅通过现场碰撞和通路校验移动，不建第二座")
	check(await apply_move("resource","tree_5_8",[Vector2i(6,7),Vector2i(8,6),Vector2i(20,5)]),"移动原半损树节点，保持同一个采集ID")
	check(await apply_move("plot","17,16",[Vector2i(22,20),Vector2i(23,20),Vector2i(22,19)]),"移动真实小麦田，逻辑ID和生长进度不变")
	var store:=FarmLayout.plan_store("resource","tree_7_20")
	check(store.valid and FarmLayout.apply_plan(store),"原树节点可收纳，不生成新资源身份")
	await frames(5);game.territory_editor.cancel()
	check(game.farm.use_tool(Vector2i(17,16),"hoe"),"旧田搬走后可在原物理位置正常开垦")
	await frames(20)
	var new_id: String=FarmLayout.logical_plot_at(Vector2i(17,16))
	check(new_id!="" and new_id!="17,16" and game.farm.plots["17,16"].days==1,"新田使用空逻辑槽，旧作物没有复制或重新计时")
	check(game.territory_editor.open(),"保存前可重新打开原设施预览")
	var preview:=FarmLayout.plan_move("fixture","mail",FarmLayout.cell("fixture","mail")+Vector2i(1,0));await frames(3)
	var now:=snapshot();check(FarmSaveStore.valid(now) and now.version==FarmSaveStore.VERSION,"搬迁、收纳、半损资源和新田构成合法v27完整档")
	write_json(proof_path(),now)
	check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"未确认预览期间原子保存主档与备份")
	check(read_json(FarmSaveStore.PATH)==now and not now.farm_layout.fixtures.has("mail") and preview.revision==now.farm_layout.revision,"磁盘只包含确认布局，预览和编辑输入不写入")
	check(field.state.tree_5_8.hp==1 and field.state.rock_11_19.hp==0 and Housing.state.storage.wood==12,"搬迁没有修复耐久、复制储物或领取采集物")
	game.territory_editor.cancel()

func apply_move(kind: String, id: String, options: Array[Vector2i]) -> bool:
	for at in options:
		var plan:=FarmLayout.plan_move(kind,id,at)
		if plan.valid:
			var accepted: bool=FarmLayout.apply_plan(plan);await frames(5);return accepted
		print("FARM LAYOUT CANDIDATE ",kind," ",id," ",at," ",plan.reason)
	return false

func read_fixture() -> void:
	var proof:=read_json(proof_path());var now:=snapshot();var same: bool=true
	for key in proof:
		if legacy and key=="version": continue
		if proof[key]!=now.get(key): same=false;print("FARM LAYOUT RESTART DIFFERENCE ",key)
	check(same and now.version==FarmSaveStore.VERSION,"独立重启逐旧字段恢复经营、作物、地图、原资源和关系")
	check(Appearance.snapshot()==CharacterAppearance.defaults("female") and game.player.get_node("Sprite2D").texture.resource_path==Appearance.player_asset(),"重启保留女性主角和对应小京，不重新选人")
	check(Housing.state.level==4 and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"住宅等级、旧家具和原收纳均未复制或丢失")
	check(Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130,"布局迁移不动婚姻、钻石和原体力上限")
	check(GameState.control_mode=="joystick" and not game.territory_editor.active and not GameState.modal,"重启保留原操作方式且不重放编辑状态")
	check(game.farm.plots["17,16"].crop=="wheat" and game.farm.plots["17,16"].days==1,"同一逻辑作物的成长进度准确恢复")
	var field: Node=game.resource_world.fields.farm
	check(field.state.tree_5_8.hp==1 and field.state.rock_11_19==proof.resources.rock_11_19,"资源耐久和再生日按原ID恢复")
	if legacy:
		check(FarmLayout.snapshot()==FarmLayout.defaults() and FarmLayout.point("home")==Vector2(656,410),"v26迁移只补默认原位布局，不擅自改旧世界")
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(FarmSaveStore.PATH)
		check(read_json(FarmSaveStore.PATH).version==26,"首次读取旧档后原磁盘仍为v26")
		check(FarmSaveStore.write(game) and FileAccess.get_file_as_bytes(FarmSaveStore.PATH+".bak")==bytes,"首次v27写回保留完整原v26字节备份")
		check(read_json(FarmSaveStore.PATH).version==FarmSaveStore.VERSION and FarmSaveStore.read().farm_layout==FarmLayout.defaults(),"安全写回只新增默认布局，不补发建筑或资源")
	else:
		check(FarmLayout.point("home")!=Vector2(656,410) and game.farm_layout_world.groups.home.size()>0,"重启后原住宅在确认的新位置，仍复用原节点组")
		check(field.objects.tree_5_8.position==FarmLayout.position("resource","tree_5_8") and FarmLayout.stored("resource","tree_7_20"),"资源新坐标和收纳状态在真实场景恢复")
		check(FarmLayout.cell("plot","17,16")!=Vector2i(17,16) and FarmLayout.logical_plot_at(Vector2i(17,16))!="17,16","田地逻辑身份与物理位置分离，旧位置的新田无串档")
		check(not FarmLayout.state.fixtures.has("mail"),"上次未确认信箱预览不会在重启时生效")
	var baseline:=snapshot();var stable: bool=true
	var points: Dictionary={}
	for node in get_tree().get_nodes_in_group("interactables"):
		if game.world.is_ancestor_of(node) and str(node.get_meta("farm_fixture","")) in ["recovery","berry"]: points[str(node.get_meta("farm_fixture"))]=node
	var hidden:=baseline.duplicate(true)
	for id in ["recovery","berry"]:
		var entry:=FarmLayoutCatalog.default_record("fixture",id);entry.stored=true;hidden.farm_layout.fixtures[id]=entry
	check(points.size()==2 and FarmSaveStore.restore(game,hidden),"合法收纳档恢复真实休息椅与浆果业务节点")
	await frames(5)
	check(not points.recovery.visible and not points.berry.visible,"收纳状态正确隐藏受业务管理的原功能实体")
	check(FarmSaveStore.restore(game,baseline),"从当前收纳状态重新读取已摆放档")
	await frames(5)
	check(points.recovery.visible and points.berry.visible and snapshot()==baseline,"完整恢复末端广播重新显示业务节点，不残留上一档隐藏状态")
	for _i in range(2): stable=FarmSaveStore.restore(game,baseline) and stable;await frames(5)
	check(stable and snapshot()==baseline,"同日重复读档不复制实体、不补发物品或重放成长")

func bad_primary() -> void:
	var proof:=read_json("user://farm-layout-v27-proof.json")
	check(read_json(FarmSaveStore.PATH+".bak")==proof,"坏档测试先确认有效备份包含完整确认布局")
	var bad:=proof.duplicate(true);bad.farm_layout.fixtures.home_clone={"cell":[20,10],"stored":false};write_json(FarmSaveStore.PATH,bad)
	check(not FarmSaveStore.valid(bad) and canonical(FarmSaveStore.read())==proof,"伪造住宅复制ID使主档失效并回退原备份")
	bad=proof.duplicate(true);bad.farm_layout.fixtures.home={"cell":[999,999],"stored":false};write_json(FarmSaveStore.PATH,bad)
	check(not FarmSaveStore.valid(bad) and canonical(FarmSaveStore.read())==proof,"地图外布局拒绝加载，不移动或丢弃其他进度")
	var keys: Array=proof.plots.keys()
	if keys.size()>=2:
		bad=proof.duplicate(true)
		var first: String=str(keys[0]);var second: String=str(keys[1])
		var a: Array=bad.farm_layout.plots.get(first,{"cell":[FarmLayoutCatalog.plot_cell(first).x,FarmLayoutCatalog.plot_cell(first).y]}).cell
		bad.farm_layout.plots[second]={"cell":a.duplicate(),"stored":false};write_json(FarmSaveStore.PATH,bad)
		check(not FarmSaveStore.valid(bad) and canonical(FarmSaveStore.read())==proof,"真实田地重复物理占位时使用备份，不加载重叠副本")
	check(read_json(FarmSaveStore.PATH+".bak")==proof,"坏主档从未覆盖唯一有效的原进度备份")
