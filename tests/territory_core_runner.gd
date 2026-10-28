extends Node
## 权限、纯迁移与修订事务；场景碰撞和实际输入另由领地集成测试执行。
var checked: int=0
var failed: int=0
var host: Node
var prior: Dictionary

class StubPlayer:
	extends Node
	var suspended: bool=false
	var action_time: float=0
class StubFarm:
	extends Node
	var committing: bool=false
class StubResources:
	extends Node
	func committing() -> bool: return false
class StubEditor:
	extends Node
	var active: bool=true
class StubGame:
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

func raw_progress(stage: int=0, restored: bool=false, water: bool=false, forest: bool=false, finale: bool=false) -> Dictionary:
	return {"story":{"stage":stage},"ecology":{"restored":restored},"chapter_two":{"completed":["water"] if water else []},"exploration":{"forest":{"open":forest},"facts":["forest_archive"] if forest else []},"river":{"facts":["closing_scene"] if finale else []}}

func reset() -> void:
	Story.stage=0;ChapterTwo.completed.clear();LakeEcology.state.restored=false
	Exploration.state.forest.open=false;Exploration.state.facts=[];River.state.facts=[]
	Territory.restore(Territory.defaults());GameState.location="farm";GameState.set_modal(true)
	host.backgrounded=false;host.closing=false;host.player.suspended=false;host.player.action_time=0;host.farm.committing=false;host.territory_editor.active=true

func unlock_all() -> void:
	Story.stage=8;ChapterTwo.completed.assign(["water"]);LakeEcology.state.restored=true
	Exploration.state.forest.open=true;Exploration.state.facts=["forest_archive"];River.state.facts=["closing_scene"]
	Territory.refresh_unlocks(false)

func run() -> void:
	GameClock.running=false;GameWeather.enabled=false
	prior={"story":Story.snapshot(),"chapter":ChapterTwo.snapshot(),"ecology":LakeEcology.snapshot(),"exploration":Exploration.snapshot(),"river":River.snapshot(),"territory":Territory.snapshot(),"location":GameState.location,"modal":GameState.modal}
	host=StubGame.new();host.player=StubPlayer.new();host.farm=StubFarm.new();host.resource_world=StubResources.new();host.territory_editor=StubEditor.new()
	for child in [host.player,host.farm,host.resource_world,host.territory_editor]: host.add_child(child)
	add_child(host);Territory.bind(host)
	permissions_and_migration()
	terrain_transactions()
	objects_and_rights()
	malformed_saves()
	Story.restore(prior.story);ChapterTwo.restore(prior.chapter);LakeEcology.restore(prior.ecology);Exploration.restore(prior.exploration);River.restore(prior.river);Territory.restore(prior.territory)
	GameState.location=prior.location;GameState.set_modal(prior.modal)
	Territory.game=null;host.queue_free();await get_tree().process_frame
	var file:=FileAccess.open("res://builds/territory-core-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"android_device_tested":false},"\t"));file.close()
	print("TERRITORY CORE RESULT: %d checks, %d failures" % [checked,failed]);get_tree().quit(1 if failed else 0)

func permissions_and_migration() -> void:
	reset()
	check(Territory.snapshot().unlocked==["farm"] and Territory.unlocked("farm"),"初始仅有主农场私人领地")
	for area in TerritoryCatalog.PUBLIC_AREAS:
		check(not Territory.permission(area,Vector2i(8,16),"flowers").allowed,"公共、剧情及地下区域保持不可编辑："+area)
	check(not Territory.unlocked("east_holding") and not Territory.permission("east_holding",Vector2i(8,8),"grass").allowed,"未完成第一章不能进入或编辑河东开发地")
	for cell in [Vector2i(14,20),Vector2i(18,16),Vector2i(34,18),Vector2i(35,9)]:
		check(not Territory.permission("farm",cell,"stone_path").allowed,"旧主通路、农田、湖泊和入口广场不可覆盖："+str(cell))
	check(Territory.permission("farm",Vector2i(11,16),"grass").allowed,"私人空地具有明确地表编辑权限")
	check(not Territory.permission("farm",Vector2i(9,28),"fence").allowed,"牛棚尚未建成也保留原动物未来的放牧站位")
	check(not Territory.permission("farm",Vector2i(22,28),"fence").allowed,"羊圈未来放牧站位不被初始领地编辑堵住")
	var stages: Array=[raw_progress(),raw_progress(8),raw_progress(8,true,true),raw_progress(8,true,true,true),raw_progress(8,true,true,true,true)]
	for i in range(stages.size()):
		var imported:=Territory.migrate(stages[i])
		check(imported.unlocked.size()==i+1 and Territory.validate(imported,stages[i]),"五段授权按真实章节、修复与清障顺序迁移："+str(i+1))
	check(Territory.migrate(raw_progress(8,false,true,true,true)).unlocked==["farm","east_holding"],"终局标记不能跳过湖泊修复的先决授权")
	for malformed in [{"story":[]},{"story":{"stage":{}}},{"story":{"stage":8},"ecology":"bad"},{"story":{"stage":8},"ecology":{"restored":true},"chapter_two":{"completed":8}},{"story":{"stage":8},"ecology":{"restored":true},"chapter_two":{"completed":["water"]},"exploration":{"forest":false}}]:
		check(not Territory.migrate(malformed).is_empty(),"损坏子字段迁移安全返回，不打断整体坏档处理")
	Territory.state.unlocked=TerritoryCatalog.EDITABLE_AREAS.duplicate()
	check(not Territory.unlocked("manor_holding"),"篡改显示缓存不能获得进入或编辑权")
	Story.stage=8;Story.changed.emit()
	check(Territory.state.unlocked==["farm","east_holding"],"剧情变化事件更新授权缓存")
	unlock_all();check(Territory.state.unlocked==TerritoryCatalog.EDITABLE_AREAS,"全部婚前章节修复完成后解锁终局庄园")

func terrain_transactions() -> void:
	reset()
	var original: Dictionary=Territory.snapshot();var wealth: Dictionary={"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"stamina":GameState.stamina}
	var cells: Array=[Vector2i(11,16),Vector2i(12,16),Vector2i(13,16)]
	var kinds: Array=TerritoryCatalog.TERRAIN_KINDS.keys();kinds.erase("natural");kinds.append("natural")
	for kind in kinds:
		var plan:=Territory.plan_terrain("farm",cells,str(kind))
		check(plan.valid and Territory.snapshot()==original,"地表预览只读且合法："+str(kind))
		check(Territory.apply_plan(plan),"地表批量确认成功："+str(kind))
		check(not Territory.apply_plan(plan),"同一地表预览只能确认一次："+str(kind))
		original=Territory.snapshot()
	check(not Territory.state.terrain.has("farm"),"恢复自然地表清除覆盖记录，不积累无用瓦片")
	var invalid:=Territory.plan_terrain("farm",[Vector2i(11,16),Vector2i(14,16)],"dirt_path")
	check(not invalid.valid and not Territory.apply_plan(invalid) and Territory.snapshot()==original,"批量包含公共道路时整体失败，不涂半份")
	var old:=Territory.plan_terrain("farm",cells,"soil");Territory.state.revision+=1
	check(not Territory.apply_plan(old),"旧修订号不能提交过时地表操作")
	var saved: Dictionary=Territory.snapshot();var valid:=Territory.plan_terrain("farm",cells,"soil")
	host.territory_editor.active=false;check(not Territory.apply_plan(valid) and Territory.snapshot()==saved,"退出建造模式后迟到确认无效");host.territory_editor.active=true
	host.backgrounded=true;check(not Territory.apply_plan(valid),"后台不能提交建造");host.backgrounded=false
	host.player.action_time=1;check(not Territory.apply_plan(valid),"工具动作未完成时不能提交改造");host.player.action_time=0
	host.farm.committing=true;check(not Territory.apply_plan(valid),"原农田事务期间不能提交改造");host.farm.committing=false
	check(wealth=={"coins":Inventory.coins,"items":Inventory.items,"stamina":GameState.stamina},"非生产性景观编辑不产生资源收益或改变原经济与体力")

func objects_and_rights() -> void:
	reset();unlock_all();GameState.location="east_holding"
	var plan:=Territory.plan_place("east_holding","tree",Vector2i(8,16))
	check(plan.valid and Territory.apply_plan(plan) and Territory.state.objects.size()==1,"观赏树占地原子保存")
	var id: String=Territory.state.objects[0].id
	check(not Territory.plan_place("east_holding","flowers",Vector2i(9,17)).valid,"不同植物和设施不能占用同一占地")
	check(not Territory.plan_terrain("east_holding",[Vector2i(8,16)],"stone_path").valid,"有植物时不能穿过物体修改地表")
	check(Territory.plan_move(id,Vector2i(10,16)).valid and Territory.apply_plan(Territory.plan_move(id,Vector2i(10,16))),"已拥有的小型对象可以移动且ID稳定")
	check(Territory.state.objects.size()==1 and Territory.state.objects[0].id==id,"移动不复制对象或改变身份")
	check(Territory.apply_plan(Territory.plan_remove(id)) and Territory.state.objects.is_empty(),"拆除只移除指定私人对象")
	check(not Territory.plan_remove(id).valid,"重复拆除不存在对象无效")
	unlock_all()
	check(Territory.permission("east_holding",Vector2i(8,3),"flowers").allowed and not Territory.permission("east_holding",Vector2i(8,3),"fence").allowed,"半开放过渡地允许花草但不允许实体阻挡物")
	check(not Territory.permission("east_holding",Vector2i(19,12),"flowers").allowed,"新领地主通道也始终保留")
	for kind in TerritoryCatalog.OBJECT_KINDS:
		GameState.location="east_holding"
		var fresh:=Territory.plan_place("east_holding",str(kind),Vector2i(8,10))
		check(fresh.valid and Territory.apply_plan(fresh),"本批小型对象可独立摆放："+str(kind))
		check(Territory.validate(Territory.snapshot(),raw_progress(8,true,true,true,true)),"放置状态可安全序列化："+str(kind))
		Territory.apply_plan(Territory.plan_remove(str(Territory.state.objects[0].id)))
	var denied:=Territory.plan_place("village","lamp",Vector2i(8,10))
	check(not denied.valid,"村庄公共空间不能借小型设施入口绕过权限")

func malformed_saves() -> void:
	reset()
	var original:=Territory.defaults()
	check(Territory.validate(original,raw_progress()),"初始空改造状态严格通过校验")
	var mutation:=original.duplicate(true);mutation.permissions.village="private";check(not Territory.validate(mutation),"存档不能自授公共区域权限")
	mutation=original.duplicate(true);mutation.unlocked=["farm","manor_holding"];check(not Territory.validate(mutation),"解锁列表不能跳过阶段")
	mutation=Territory.migrate(raw_progress(8));check(not Territory.validate(mutation,raw_progress()),"缓存授权与保存剧情不符时拒绝")
	for key in ["01,16","11.0,16","11, 16","-1,16","999999999999999999999,16","14,16"]:
		mutation=original.duplicate(true);mutation.terrain={"farm":{key:"soil"}};check(not Territory.validate(mutation),"拒绝非规范、越界及公共格地表："+key)
	mutation=original.duplicate(true);mutation.terrain={"farm":{"11,16":"unknown"}};check(not Territory.validate(mutation),"未知地表不会加载错误效果")
	mutation=original.duplicate(true);mutation.terrain={"farm":{"11,16":"natural"}};check(not Territory.validate(mutation),"自然恢复应删除覆盖记录而不是留下冗余状态")
	mutation=original.duplicate(true);mutation.terrain={"farm":{"10,8":"soil"}};check(not Territory.validate(mutation),"存档注入地表也不能覆盖旧树木的再生与采集空间")
	mutation=original.duplicate(true);mutation.serial=1;mutation.objects=[{"id":"territory_000001","area":"farm","kind":"lamp","cell":[10,8]}]
	check(not Territory.validate(mutation),"格式合法的存档设施也不能覆盖原资源保留格")
	mutation=original.duplicate(true);mutation.terrain={"farm":{"6,17":"soil"}};check(not Territory.validate(mutation),"固定浆果交互点不能通过存档注入地表覆盖")
	mutation=original.duplicate(true);mutation.serial=2;mutation.objects=[{"id":"territory_000001","area":"farm","kind":"lamp","cell":[11,16]},{"id":"territory_000002","area":"farm","kind":"chest","cell":[11,16]}]
	check(not Territory.validate(mutation),"恢复存档时再次检查对象占地重叠")
	mutation.objects[1].cell=[12,16];mutation.objects[1].id="territory_000001";check(not Territory.validate(mutation),"重复对象身份不会加载成复制家具")
	mutation=original.duplicate(true);mutation.serial=1;mutation.objects=[{"id":"territory_000001","area":"abyss","kind":"lamp","cell":[11,16]}];check(not Territory.validate(mutation),"地下对象即使格式正常也不能加载为领地改造")
