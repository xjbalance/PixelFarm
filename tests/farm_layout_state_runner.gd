extends Node
## 原实体布局的身份、修订与状态边界；场景碰撞由实际世界套另外验证。
var checked: int=0
var failed: int=0
var host: Node
var initial: Dictionary
class PlayerStub:
	extends Node
	var suspended: bool=false
	var action_time: float=0
class FarmStub:
	extends Node
	var committing: bool=false
	var plots: Dictionary={"17,16":{"crop":"wheat","days":1,"watered":true},"18,16":{"crop":"","days":0,"watered":false}}
class ResourcesStub:
	extends Node
	func committing() -> bool: return false
class EditorStub:
	extends Node
	var active: bool=true
class GameStub:
	extends Node
	var backgrounded: bool=false
	var closing: bool=false
	var player: Node
	var farm: Node
	var resource_world: Node
	var territory_editor: Node

func _ready() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checked+=1
	if ok: print("PASS: ",message)
	else: failed+=1;push_error("FAIL: "+message)
func reset() -> void:
	FarmLayout.restore(FarmLayout.defaults());GameState.location="farm";GameState.set_modal(true)
	host.backgrounded=false;host.closing=false;host.player.suspended=false;host.player.action_time=0;host.farm.committing=false;host.territory_editor.active=true
	host.farm.plots={"17,16":{"crop":"wheat","days":1,"watered":true},"18,16":{"crop":"","days":0,"watered":false}}

func run() -> void:
	GameClock.running=false;GameWeather.enabled=false
	initial=FarmLayout.snapshot()
	host=GameStub.new();host.player=PlayerStub.new();host.farm=FarmStub.new();host.resource_world=ResourcesStub.new();host.territory_editor=EditorStub.new()
	for child in [host.player,host.farm,host.resource_world,host.territory_editor]: host.add_child(child)
	add_child(host);FarmLayout.bind(host)
	default_identities();fixture_transactions();resource_transactions();plot_transactions();bad_layouts()
	FarmLayout.restore(initial);FarmLayout.game=null;GameState.set_modal(false)
	host.queue_free();await get_tree().process_frame
	var file:=FileAccess.open("res://builds/farm-layout-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"android_device_tested":false},"\t"));file.close()
	print("FARM LAYOUT STATE RESULT: %d checks, %d failures" % [checked,failed]);get_tree().quit(1 if failed else 0)

func default_identities() -> void:
	reset()
	check(FarmLayout.validate(FarmLayout.defaults()) and FarmLayout.snapshot().fixtures.is_empty(),"初始仅存覆盖记录，原设施仍在原位")
	check(FarmLayoutCatalog.definitions().size()>=64,"固定索引包含主要建筑与原剧情、生活摆件")
	check(FarmLayoutCatalog.ids("resource").size()==42 and FarmLayoutCatalog.ids("plot").size()==1536,"只复用原42资源身份及48×32逻辑田池")
	for id in FarmLayoutCatalog.MAIN_FIXTURES:
		var at: Array=FarmLayoutCatalog.MAIN_FIXTURES[id]
		check(FarmLayout.point(id)==Vector2(at[0],at[1]) and FarmLayout.active(id),"默认设施保留完整旧pixel锚点："+str(id))
	check(FarmLayout.cell("resource","tree_5_8")==Vector2i(5,8) and FarmLayout.position("resource","tree_5_8")==Vector2(160,256),"原资源ID与脚底坐标不变")
	check(FarmLayout.position("plot","17,16")==Vector2(560,528) and not FarmLayout.stored("plot","17,16"),"生产田默认逻辑ID和物理坐标保持一致")
	check(FarmLayoutCatalog.valid_id("plot","47,31") and not FarmLayoutCatalog.valid_id("plot","48,31"),"逻辑生产田池完整而不越出原地图")
	for raw in [{},{"version":26},{"housing":false},{"plots":[]},{"resources":"bad"}]:
		check(FarmLayout.migrate(raw)==FarmLayout.defaults(),"迁移仅新增原位覆盖，不读取或重发旧业务进度")

func fixture_transactions() -> void:
	reset();var money: Dictionary={"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"stamina":GameState.stamina}
	var before:=FarmLayout.snapshot();var plan:=FarmLayout.plan_move("fixture","home",Vector2i(23,14))
	check(plan.valid and FarmLayout.snapshot()==before,"大型住宅预览只读，不扣资源也不移动实体")
	check(FarmLayout.apply_plan(plan) and FarmLayout.point("home")==Vector2(752,474),"住宅移动保留原像素余数，按格差平移")
	check(FarmLayout.offset("home")==Vector2(96,64) and FarmLayout.transform_point(Vector2(656,402),"home")==Vector2(752,466),"同一住宅关联点使用同一平移量")
	check(FarmLayout.transform_point(Vector2(656,440))==Vector2(752,504) and FarmLayout.to_logical("home",Vector2(752,504))==Vector2(656,440),"精确旧回程点正反映射一致")
	before=FarmLayout.snapshot();check(not FarmLayout.apply_plan(plan) and FarmLayout.snapshot()==before,"同一次预览重复确认无效")
	check(FarmLayout.apply_plan(FarmLayout.plan_store("fixture","home")) and not FarmLayout.active("home") and FarmLayout.point("home").is_finite(),"收纳只切实体状态，位置查询仍有限且不会复制住宅")
	check(not FarmLayout.plan_store("fixture","home").valid and not FarmLayout.plan_move("fixture","home",Vector2i(25,14)).valid,"已收纳实体不能重复收纳或绕过恢复流程")
	check(FarmLayout.apply_plan(FarmLayout.plan_restore("fixture","home",Vector2i(20,12))) and FarmLayout.active("home") and not FarmLayout.state.fixtures.has("home"),"恢复默认位置后删除冗余覆盖，仍是原来的同一住宅")
	check(not FarmLayout.plan_restore("fixture","home",Vector2i(21,12)).valid,"未收纳的原设施不能从列表复制一座")
	plan=FarmLayout.plan_move("fixture","shop",Vector2i(13,15));var forged:=plan.duplicate(true);forged.stored=true
	check(not FarmLayout.apply_plan(forged),"伪装move的store标记不能绕过操作检查")
	for key in ["backgrounded","closing"]:
		host.set(key,true);check(not FarmLayout.apply_plan(plan),"后台或退出期间不提交原设施布局："+key);host.set(key,false)
	host.player.action_time=.2;check(not FarmLayout.apply_plan(plan),"原工具动作尚未完成时不能搬动设施");host.player.action_time=0
	host.territory_editor.active=false;check(not FarmLayout.apply_plan(plan),"退出建造后的迟到确认无效");host.territory_editor.active=true
	check(money=={"coins":Inventory.coins,"items":Inventory.items,"stamina":GameState.stamina},"布局操作没有修改钱物、体力或任何生产等级")

func resource_transactions() -> void:
	reset();var before:=FarmResourceCatalog.placements("farm")
	check(FarmLayout.apply_plan(FarmLayout.plan_move("resource","tree_5_8",Vector2i(20,5))) and FarmLayout.position("resource","tree_5_8")==Vector2(640,160),"原资源身份不变，只移动实际脚底")
	check(not FarmLayout.plan_move("resource","tree_7_20",Vector2i(20,5)).valid,"两个现有资源身份不能叠到同一物理格")
	check(FarmLayout.apply_plan(FarmLayout.plan_store("resource","tree_5_8")) and FarmLayout.stored("resource","tree_5_8"),"原资源可收纳但不创建第二份HP或掉落数据")
	check(FarmLayout.apply_plan(FarmLayout.plan_restore("resource","tree_5_8",Vector2i(21,5))) and not FarmLayout.stored("resource","tree_5_8"),"恢复使用原资源ID而不是新增可刷节点")
	check(FarmResourceCatalog.placements("farm")==before,"布局没有改写原采集物目录或资源产量")

func plot_transactions() -> void:
	reset();var crops: Dictionary=host.farm.plots.duplicate(true)
	check(FarmLayout.apply_plan(FarmLayout.plan_move("plot","17,16",Vector2i(22,10))) and FarmLayout.cell("plot","17,16")==Vector2i(22,10),"带作物的逻辑田ID不变，只改变物理位置")
	check(FarmLayout.logical_plot_at(Vector2i(22,10))=="17,16" and host.farm.plots==crops,"原生长天数、浇水和作物留在同一逻辑ID")
	check(not FarmLayout.plan_move("plot","18,16",Vector2i(22,10)).valid,"真实生产田不允许重复物理占位")
	check(FarmLayout.apply_plan(FarmLayout.plan_store("plot","17,16")) and FarmLayout.logical_plot_at(Vector2i(22,10))=="","收纳田地保留原作物数据而不占地图")
	check(FarmLayout.apply_plan(FarmLayout.plan_move("plot","18,16",Vector2i(22,10))),"空出的物理格可用于另一块真实田地")
	check(not FarmLayout.plan_restore("plot","17,16",Vector2i(22,10)).valid,"收纳田地恢复时重新验证已有田地占位")
	host.farm.plots["0,0"]={"crop":"","days":0,"watered":false}
	check(not FarmLayout.register_plot("0,0",Vector2i(25,10)),"普通非农活调用不能悄悄创建生产布局")
	host.farm.committing=true;check(FarmLayout.register_plot("0,0",Vector2i(25,10)),"已提交的新逻辑田在原农活事务中登记物理映射");host.farm.committing=false
	check(FarmLayout.cell("plot","0,0")==Vector2i(25,10) and FarmLayout.validate(FarmLayout.snapshot(),{"plots":host.farm.plots}),"新田使用同一严格布局校验，不占用已搬移旧田的逻辑ID")
	check(not FarmLayout.plan_move("plot","1,1",Vector2i(26,10)).valid,"未开垦的逻辑池槽不能假装原有田地复制进度")

func bad_layouts() -> void:
	reset();var source:=FarmLayout.defaults()
	var bad:=source.duplicate(true);bad.fixtures.home_clone={"cell":[20,10],"stored":false};check(not FarmLayout.validate(bad),"不能复制固定住宅ID")
	bad=source.duplicate(true);bad.resources.new_tree={"cell":[20,10],"stored":false};check(not FarmLayout.validate(bad),"陌生资源ID不能加入原资源池")
	for at in [[48,10],[-1,10],[20,32],[1.5,10],[NAN,10],[10,10,0]]:
		bad=source.duplicate(true);bad.fixtures.home={"cell":at,"stored":false};check(not FarmLayout.validate(bad),"拒绝畸形或地图外坐标："+str(at))
	bad=source.duplicate(true);bad.fixtures.home={"cell":[47,31],"stored":false};check(not FarmLayout.validate(bad),"实体占地越出地图时不能伪造合法锚点")
	bad=source.duplicate(true);bad.fixtures.home={"cell":[20,12],"stored":1};check(not FarmLayout.validate(bad),"收纳标志必须为真实布尔值")
	bad=source.duplicate(true);bad.fixtures.home={"cell":[20,12],"stored":false,"level":4};check(not FarmLayout.validate(bad),"布局中不能夹带建筑等级或生产进度")
	bad=source.duplicate(true);bad.resources.tree_5_8={"cell":[7,20],"stored":false};check(not FarmLayout.validate(bad),"覆盖记录也需与未移动原资源交叉检查")
	bad=source.duplicate(true);bad.plots["01,1"]={"cell":[5,5],"stored":false};check(not FarmLayout.validate(bad),"田地逻辑ID必须使用规范坐标")
	bad=source.duplicate(true);bad.plots["999999999999999999999,1"]={"cell":[5,5],"stored":false};check(not FarmLayout.validate(bad),"巨长数字ID安全拒绝而不触发引擎整数溢出")
	bad=source.duplicate(true);bad.plots["1,1"]={"cell":[5,5],"stored":false};check(not FarmLayout.validate(bad,{"plots":{}}),"完整存档拒绝没有真实田地数据的孤立布局")
	bad=source.duplicate(true);bad.revision=INF;check(not FarmLayout.validate(bad),"非有限修订号不能载入")
