extends "res://tests/runner.gd"
## 四个独立进程：当前写/重启读/真实v23写/迁移读；调用者使用同一隔离用户目录。
const Arrange=preload("res://tests/home_arrange_runner.gd")
const Home=preload("res://tests/home05_runner.gd")
var panel: PanelContainer
var legacy: bool=false

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	legacy="--write-atlas-v23" in args or "--read-atlas-v23" in args
	var writing: bool="--write-atlas" in args or "--write-atlas-v23" in args
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true));panel=game.hud.atlas_panel
	if writing: await write_fixture()
	else: await read_fixture()
	print("ATLAS PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func proof_path() -> String: return "user://atlas-v23-proof.json" if legacy else "user://atlas-proof.json"
func token_path() -> String: return "user://atlas-v23-token.json" if legacy else "user://atlas-token.json"
func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func write_json(path: String, value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func read_json(path: String) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))

func write_fixture() -> void:
	check(await Arrange.setup_married_home(self,game),"独立写进程建立已婚三级住宅、家具与柜存")
	await Home.visit_builder(self,game)
	check(Housing.upgrade(3),"独立写进程真实支付四级住宅施工费用")
	var explored:=Exploration.defaults();explored.facts=["forest_order"];explored.forest.step=2
	Exploration.restore(explored)
	var resources: Dictionary=game.resource_world.snapshot()
	resources.tree_7_20={"hp":0,"ready_day":GameClock.day+3};resources.rock_11_19={"hp":1,"ready_day":0}
	game.resource_world.restore(resources)
	GameState.set_control_mode("joystick",false)
	game.change_location("home",Vector2(640,500));await frames(5)
	var inventory: PanelContainer=game.hud.inventory_panel
	var held: int=Inventory.count("carrot");var money: int=Inventory.coins
	inventory.open_panel(true);inventory.request_sale_quantity("carrot");inventory.set_sale_quantity(7)
	var token: int=int(inventory.pending_sale.token);inventory.confirm_sale(token);inventory.confirm_sale(token)
	check(Inventory.count("carrot")==held-7 and Inventory.coins==money+7*Catalog.sell_price("carrot"),"写盘前真实按数量卖七件，一次结算且保留其余库存")
	inventory.close_panel();await frames(3)
	var before:=snapshot()
	check(FarmSaveStore.valid(before) and before.version==FarmSaveStore.VERSION and before.housing.level==3 and not before.housing.construction.is_empty(),"形成合法当前完整存档，包含已付款未完成工单")
	check(panel.open_panel(),"写进程实际展开新版图纸")
	panel.show_current();panel.map_canvas.zoom_by(2);panel.map_canvas.pan_by(Vector2(140,65));await frames(5)
	check(panel.visible and panel.map_canvas.zoom>1 and panel.map_canvas.region_id=="home" and snapshot()==before,"打开、缩放与拖动家内图纸不写资源、相机或地图持久状态")
	write_json(token_path(),{"token":token,"sold":7,"remaining":Inventory.count("carrot"),"coins":Inventory.coins})
	if legacy:
		var old: Dictionary=before.duplicate(true);old.version=23;old.erase("appearance");old.erase("territory");old.erase("farm_layout");old.housing.erase("builtins")
		check(FarmSaveStore.valid(old) and not old.housing.has("builtins"),"旧写进程使用真实v23字段结构，明确移除现代builtins")
		write_json(proof_path(),old);write_json(FarmSaveStore.PATH,old);write_json(FarmSaveStore.PATH+".bak",old)
		var disk:=read_json(FarmSaveStore.PATH)
		check(disk==old and disk.version==23 and FarmSaveStore.read().version==FarmSaveStore.VERSION,"v23原始主档和备份落盘，读取器可规范迁移为当前格式")
	else:
		write_json(proof_path(),before)
		check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"图纸仍打开时完整当前主档和备份成功写入磁盘")
		check(read_json(FarmSaveStore.PATH)==before,"磁盘只有原完整游戏字段，没有展开、缩放、选点或出售确认字段")
	panel.close_panel()

func read_fixture() -> void:
	var proof:=read_json(proof_path());var now:=snapshot()
	var same: bool=true
	for key in proof:
		if legacy and key in ["version","housing"]: continue
		if proof[key]!=now.get(key): same=false;print("ATLAS RESTART MISMATCH ",key)
	if legacy:
		for field in proof.housing:
			if proof.housing[field]!=now.housing.get(field): same=false;print("ATLAS LEGACY HOUSING MISMATCH ",field)
	check(same and now.version==FarmSaveStore.VERSION,"独立重启逐字段恢复钱物、住宅、探索、婚姻和全部其他游戏进度")
	if legacy: check(proof.version==23 and not proof.housing.has("builtins") and now.housing.has("builtins"),"真实v23磁盘档仅补家具位置、角色外观与版本，不降级或重建住宅")
	check(not panel.visible and not GameState.modal and panel.map_canvas.zoom==1 and game.auto_move.target.is_empty(),"重启地图默认收起，不恢复旧缩放、模态、路径或待执行交互")
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible,"独立重启保留原备用摇杆操作设置")
	var token:=read_json(token_path());var inventory: PanelContainer=game.hud.inventory_panel
	var before:=snapshot();inventory.confirm_sale(int(token.token));await frames(5)
	check(snapshot()==before and Inventory.count("carrot")==int(token.remaining) and Inventory.coins==int(token.coins),"重启后旧出售确认无效，不重复卖物或领取金币")
	check(Housing.state.level==3 and not Housing.state.construction.is_empty() and Housing.state.construction==proof.housing.construction and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"旧三级家具、柜存与已付款四级施工单原样保持")
	check(Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130,"地图读取不改婚姻、1314钻石与旧卧室体力上限")
	check(game.resource_world.fields.farm.state.tree_7_20==proof.resources.tree_7_20 and game.resource_world.fields.farm.state.rock_11_19==proof.resources.rock_11_19,"重启保留已砍树再生日期及半损矿石，不刷新资源")
	check(Exploration.state.forest.step==2 and "forest_order" in Exploration.state.facts and FarmAtlasData.known("mist_forest") and not FarmAtlasData.known("lake_ruins"),"探索机关中途和未发现区域继续沿原状态，不提前揭示遗迹")
	check(panel.open_panel(),"恢复当前或旧存档后可以正常展开图纸")
	panel.show_current();panel.map_canvas.zoom_by(1.5);panel.center_player();await frames(5)
	check(panel.map_canvas.region_id=="home" and panel.map_canvas.player_map_position().distance_to(FarmAtlasData.world_to_map("home",game.player.global_position))<.01,"住宅详图依据已恢复住宅等级和玩家坐标正确定位")
	panel.map_canvas.show_region("farm")
	var depleted: bool=false
	for mark in panel.map_canvas.resources:
		if mark.id=="tree_7_20": depleted=not mark.available
	check(depleted,"新图纸读取真实耗尽资源状态，而不把已砍树重置为可采")
	panel.close_panel();check(snapshot()==before and not GameState.modal,"独立读档后查看、缩放、定位、关闭仍逐字段保持原完整进度")
	var stable: bool=true
	for _i in range(2):
		stable=FarmSaveStore.restore(game,before) and stable;await frames(4)
	check(stable and snapshot()==before and not panel.visible,"同日重复读取不复制物品、柜存或已付款施工奖励")
	check(FarmSaveStore.write(game) and FarmSaveStore.read().version==FarmSaveStore.VERSION,"验收后仍能沿原主档备份机制保存为有效当前格式")
