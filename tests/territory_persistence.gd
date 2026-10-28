extends "res://tests/runner.gd"
## 独立进程写入、恢复、语义坏档回退与真实v25迁移；必须由隔离用户目录运行。
const Arrange=preload("res://tests/home_arrange_runner.gd")
const Home=preload("res://tests/home05_runner.gd")
var legacy: bool=false

func canonical(raw: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(raw)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func proof_path() -> String: return "user://territory-v25-proof.json" if legacy else "user://territory-v26-proof.json"
func write_json(path: String, raw: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(raw,"\t"));file.close()
func read_json(path: String) -> Dictionary:
	return canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	legacy="--write-territory-v25" in args or "--read-territory-v25" in args
	if "--corrupt-territory" in args:
		corrupt_primary();finish_report("corrupt");get_tree().quit(1 if failed else 0);return
	var writing: bool="--write-territory" in args or "--write-territory-v25" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.persistence_enabled=false
	if writing: await write_fixture()
	else: await read_fixture()
	finish_report(("write" if writing else "read")+("-v25" if legacy else "-v26"))
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func finish_report(mode: String) -> void:
	var file:=FileAccess.open("res://builds/territory-persistence-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"checks":checked,"failures":failed,"independent_process":true,"android_device_tested":false},"\t"));file.close()
	print("TERRITORY PERSISTENCE "+mode+" RESULT: %d checks, %d failures" % [checked,failed])

func close_panels() -> void:
	if game.territory_editor.active: game.territory_editor.cancel()
	while game.hud.close_active_panel(): pass

func write_fixture() -> void:
	check(await Arrange.setup_married_home(self,game),"独立写进程通过原住宅接口建立已婚三级房屋、家具和柜存")
	check(await Home.finish_upgrade(self,game,3),"继续原两日施工实际完成最高四级住宅")
	Appearance.set_player_gender("female");game.tutorial.restore(GameTutorial.defaults(true));Letters.refresh()
	Inventory.coins=7319;GameState.stamina=37;GameState.set_control_mode("joystick",false)
	var resources: Dictionary=game.resource_world.snapshot()
	resources.tree_7_20={"hp":0,"ready_day":GameClock.day+3};resources.rock_11_19={"hp":1,"ready_day":0};game.resource_world.restore(resources)
	await frames(5)
	check(Housing.state.level==4 and Housing.state.storage.wood==12 and Xiaojing.state.married and Xiaojing.state.diamonds==1314,"住宅、原柜存、婚姻和钻石是原有系统的真实合法进度")
	if legacy:
		close_panels();game.change_location("home",Housing.anchor("storage")+Vector2(32,0));await frames(5)
		var old: Dictionary=snapshot();old.version=25;old.erase("territory");old.erase("farm_layout")
		check(FarmSaveStore.valid(old) and not old.has("territory") and old.location=="home","迁移夹具保留真正v25结构和旧场景，没有新领地字段")
		write_json(proof_path(),old);write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		check(read_json(FarmSaveStore.PATH)==old and FarmSaveStore.read().version==FarmSaveStore.VERSION,"读取旧档仅在内存迁移，磁盘原v25字节结构不改写")
		return
	close_panels();game.change_location("farm",Vector2(432,528));await frames(6)
	var editor: TerritoryEditor=game.territory_editor
	check(editor.open(),"真实建造模式打开，独立进程开始确认地表改造")
	editor.choose_tool("stone_path")
	var road_cells: Array[Vector2i]=[]
	for cell in [Vector2i(11,16),Vector2i(12,16),Vector2i(13,16),Vector2i(11,17),Vector2i(12,17)]:
		if Territory.plan_terrain("farm",[cell],"stone_path").valid: road_cells.append(cell)
		if road_cells.size()==2: break
	check(road_cells.size()==2,"实际农场中找到两格不覆盖旧农田或资源的可改造空地")
	if road_cells.size()!=2: return
	for cell in road_cells: editor.preview_at(cell)
	check(editor.preview_plan.get("valid",false) and editor.confirm(),"地表批量预览经真实编辑器确认两格石路")
	close_panels();game.change_location("east_holding",Vector2(640,800));await frames(6)
	check(GameState.location=="east_holding" and Territory.unlocked("east_holding"),"依据第一章真实进度进入河东私人领地")
	check(await place("tree",Vector2i(8,10)),"真实编辑器确认观赏树并创建碰撞对象")
	check(await place("chest",Vector2i(12,10)),"真实编辑器确认共享收纳箱")
	var chest: Dictionary=Territory.state.objects.filter(func(entry: Dictionary): return entry.kind=="chest")[0]
	var chest_id: String=chest.id
	editor.choose_tool("move");editor.preview_at(Vector2i(12,10));editor.preview_at(Vector2i(13,10));await frames(5)
	check(editor.preview_plan.get("valid",false) and editor.confirm(),"确认移动收纳箱而不是重新生成一只")
	check(Territory.object(chest_id).cell==[13,10] and Housing.state.storage.wood==12,"移动后箱子ID和原共享柜存保持不变")
	var committed: Dictionary=Territory.snapshot();editor.choose_tool("flowers");editor.preview_at(Vector2i(16,12));await frames(4)
	check(editor.preview_plan.get("valid",false) and Territory.snapshot()==committed,"未确认花草预览只在编辑器内，不污染持久化数据")
	var now: Dictionary=snapshot();check(FarmSaveStore.valid(now) and now.version==FarmSaveStore.VERSION,"实际道路、树木和设施构成合法当前完整存档")
	write_json(proof_path(),now)
	check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"预览期间通过原原子保存机制写入主档及备份")
	check(read_json(FarmSaveStore.PATH)==now and now.territory.objects.size()==2 and not now.territory.has("preview"),"磁盘只保存两件已确认对象，不保存悬空预览或输入状态")
	close_panels();check(snapshot()==now,"退出建造不会修改刚保存的确认布局和原经营数据")

func place(kind: String, cell: Vector2i) -> bool:
	var editor: TerritoryEditor=game.territory_editor
	if not editor.active and not editor.open(): return false
	editor.choose_tool(kind);editor.preview_at(cell);await frames(5)
	var result: bool=editor.preview_plan.get("valid",false) and editor.confirm()
	await frames(4);return result

func read_fixture() -> void:
	var proof:=read_json(proof_path());var now:=snapshot();var same: bool=true
	for key in proof:
		if legacy and key=="version": continue
		if proof[key]!=now.get(key): same=false;print("TERRITORY RESTART DIFFERENCE ",key)
	check(same and now.version==FarmSaveStore.VERSION,"独立重启逐字段恢复原钱物、角色、房屋、关系、农田与地图状态")
	check(Appearance.snapshot()==CharacterAppearance.defaults("female") and game.player.get_node("Sprite2D").texture.resource_path==Appearance.player_asset(),"独立重启继续使用原女主与对应男小京像素形象")
	check(Housing.state.level==4 and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"四级房屋、旧家具及柜存未因领地迁移复制或丢失")
	check(Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.stamina==37 and GameState.max_stamina()==130,"原婚姻、婚礼钻石、当前体力与床铺上限完整保留")
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible and not game.territory_editor.active and not GameState.modal,"读档恢复原操作方式，不重放上次建造模式和触点")
	check(game.resource_world.fields.farm.state.tree_7_20==proof.resources.tree_7_20 and game.resource_world.fields.farm.state.rock_11_19==proof.resources.rock_11_19,"原资源耗尽和再生日不受世界编辑存档影响")
	check(now.territory.unlocked==Territory.migrate(now).unlocked and now.territory.permissions==TerritoryCatalog.permissions(),"解锁缓存与编辑权限按保存的真实章节重建")
	if legacy:
		check(Territory.state.terrain.is_empty() and Territory.state.objects.is_empty() and Territory.state.serial==0,"v25迁移只新增空编辑记录，不补发设施或改动旧地图")
		check(Territory.unlocked("east_holding") and not Territory.unlocked("lake_holding"),"旧档已完成第一章可直接使用河东领地，未达湖修复条件不提前授权")
		var original_bytes: PackedByteArray=FileAccess.get_file_as_bytes(FarmSaveStore.PATH)
		check(read_json(FarmSaveStore.PATH).version==25,"仅载入旧档尚未主动写回，保留旧磁盘格式")
		check(FarmSaveStore.write(game) and FileAccess.get_file_as_bytes(FarmSaveStore.PATH+".bak")==original_bytes,"第一次v26保存保留完整原v25字节作为备份")
		check(read_json(FarmSaveStore.PATH).version==FarmSaveStore.VERSION and FarmSaveStore.read().territory==now.territory,"安全写回当前格式，不重复发放房屋或建设效果")
	else:
		check(GameState.location=="east_holding" and Territory.state.terrain.farm.size()==2 and Territory.state.objects.size()==2,"重启后回到真实已授权地块，并恢复农场两格道路和两件设施")
		var chest: Dictionary=Territory.state.objects.filter(func(entry: Dictionary): return entry.kind=="chest")[0]
		check(chest.cell==[13,10] and Territory.state.objects.filter(func(entry: Dictionary): return entry.kind=="tree").size()==1,"设施新位置及树木数量准确，不因重启重复生成")
		check(game.territory_world.objects.size()==2 and game.auto_move.target.is_empty(),"已确认物件事件驱动恢复，旧自动路线不重放")
	var baseline: Dictionary=snapshot();var stable: bool=true
	for _i in range(2):
		stable=FarmSaveStore.restore(game,baseline) and stable;await frames(4)
	check(stable and snapshot()==baseline,"重复读取不重复创建道路、树木、箱子或原资源奖励")

func corrupt_primary() -> void:
	var proof:=read_json("user://territory-v26-proof.json")
	check(read_json(FarmSaveStore.PATH+".bak")==proof,"语义坏档测试开始前备份保存完整已确认进度")
	var bad:=proof.duplicate(true);bad.territory.permissions.village="private";write_json(FarmSaveStore.PATH,bad)
	check(not FarmSaveStore.valid(bad) and canonical(FarmSaveStore.read())==proof,"非法公共编辑权限使主档失效，读取完整备份")
	bad=proof.duplicate(true);bad.territory.objects.append(bad.territory.objects[0].duplicate(true));write_json(FarmSaveStore.PATH,bad)
	check(not FarmSaveStore.valid(bad) and canonical(FarmSaveStore.read())==proof,"重复对象身份不能加载成复制家具，主档回退正确备份")
	check(read_json(FarmSaveStore.PATH+".bak")==proof,"坏主档恢复不覆盖唯一有效备份的原进度")
