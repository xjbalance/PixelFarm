extends "res://tests/runner.gd"
var old: Dictionary
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	old=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://docs/ux083/legacy082-v30.json")))
	var migrated:=FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==31,"实际0.8.2 v30档迁移到背包布局v31")
	if migrated.is_empty(): await finish();return
	for key in old:
		if key!="version": check(migrated[key]==old[key],"迁移不修改旧业务字段 "+str(key))
	check(FarmSaveSchema.normalize(migrated)==migrated,"重复迁移不重发物品或改变格子身份")
	check(InventorySlots.valid(migrated.inventory_layout,migrated.items),"初始格子严格对应原物品总量与永久工具")
	check(migrated.ui_preferences.hotbar_display=="compact" and migrated.ui_preferences.hotbar_slot==int(old.selected),"旧档默认三格展示并保留当前工具")
	check(FarmSaveStore.restore(game,old),"旧牧场、动物、加工订单和背包完整恢复")
	await frames(6)
	Inventory.items={"wood":80,"stone":30,"carrot_seed":12,"fish_eternal":1};Inventory.changed.emit()
	var totals:=Inventory.items.duplicate(true);var coins: int=Inventory.coins;var selected: int=GameState.selected
	var wood:=uid_for("wood");var stone:=uid_for("stone");var token: int=Inventory.revision
	check(Inventory.split_stack(wood,17,token),"拆出精确17份木材")
	check(Inventory.items==totals and InventorySlots.valid(Inventory.layout,Inventory.items) and Inventory.stack(wood).amount==63,"拆分保持总量、来源栈与独立分组一致")
	var before:=Inventory.snapshot_layout()
	check(not Inventory.split_stack(wood,17,token) and Inventory.snapshot_layout()==before,"同一确认token不能重复拆分")
	var part:=uid_for("wood",wood)
	check(part>0 and Inventory.stack(part).amount==17,"新分组具有独立稳定身份")
	var empty: int=Inventory.layout.slots.size()+2
	check(Inventory.move_stack(part,empty,Inventory.revision) and Inventory.stack_index(part)==empty,"整组可移到真实空格而不改变物品总量")
	var wood_index:=Inventory.stack_index(wood);var stone_index:=Inventory.stack_index(stone)
	check(Inventory.move_stack(wood,stone_index,Inventory.revision) and Inventory.stack_index(stone)==wood_index,"不同物品交换实际格子位置")
	check(Inventory.move_stack(part,Inventory.stack_index(wood),Inventory.revision) and Inventory.stack(part).is_empty() and Inventory.stack(wood).amount==80,"同类分组合法合并，来源格清空")
	check(Inventory.toggle_stack_lock(stone,Inventory.revision),"锁定真实物品格")
	stone_index=Inventory.stack_index(stone);before=Inventory.snapshot_layout()
	check(not Inventory.move_stack(stone,empty,Inventory.revision) and Inventory.snapshot_layout()==before,"锁定格不能被拖走")
	check(Inventory.split_stack(wood,21,Inventory.revision) and Inventory.sort_stacks(Inventory.revision),"整理合并未锁定分组并按种类稳定排序")
	check(Inventory.stack_index(stone)==stone_index and Inventory.stack_locked(stone),"整理保留锁定格位置和身份")
	check(Inventory.items==totals and Inventory.coins==coins and GameState.selected==selected,"整理与交换不改变数量、金币或装备工具")
	var bindings: Array=GameState.preferences.hotbar.duplicate()
	var whole_index: int=Inventory.stack_index(wood)
	check(Inventory.split_stack(wood,80,Inventory.revision) and Inventory.stack_index(wood)!=whole_index and Inventory.stack(wood).amount==80,"拆分全部实际移动原分组，不创建零数量或重复UID")
	Inventory.sort_stacks(Inventory.revision)
	check(GameState.preferences.hotbar==bindings and Inventory.items==totals,"背包分组合并移动不改变独立快捷栏物品绑定")
	before=Inventory.snapshot_layout();var rev: int=Inventory.revision
	check(Inventory.sort_stacks(rev) and Inventory.snapshot_layout()==before and Inventory.revision==rev,"重复整理幂等，不重复生成分组")
	check(not Inventory.discard_stack(uid_for("hoe"),1,Inventory.revision),"永久工具不能丢弃或丢失")
	check(not Inventory.discard_stack(uid_for("fish_eternal"),1,Inventory.revision),"真实稀有收藏物品受保护")
	check(not Inventory.discard_stack(stone,1,Inventory.revision),"锁定物品不可误丢")
	before=Inventory.snapshot_layout();var protected_items:=Inventory.items.duplicate(true);var protected_coins: int=Inventory.coins
	check(not FarmEconomy.sell("stone",1) and Inventory.items==protected_items and Inventory.coins==protected_coins and Inventory.snapshot_layout()==before,"原出售业务同样保护锁定分组，不只禁用按钮")
	check(Inventory.discard_stack(wood,3,Inventory.revision) and Inventory.count("wood")==77,"明确提交后仅丢弃指定数量")
	check(Inventory.exchange({"wood":5},{"stone":2},0) and InventorySlots.valid(Inventory.layout,Inventory.items),"原交易接口消费和获取后自动同步真实分组")
	check(Inventory.count("wood")==72 and Inventory.count("stone")==32 and Inventory.stack_index(stone)==stone_index,"旧业务消耗数量正确，固定格保留位置")
	Inventory.items.wood=999;Inventory.changed.emit();before=Inventory.snapshot_layout()
	check(not Inventory.add("wood",1) and Inventory.count("wood")==999 and Inventory.snapshot_layout()==before,"原每种999上限保留，整理不能扩大经济容量")
	check(not Inventory.add("missing_item",1),"非法物品不能进入库存")
	var save:=FarmSaveStore.snapshot(game)
	Inventory.items.wood=17;Inventory.changed.emit()
	check(FarmSaveStore.valid(save) and FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))),"布局、锁定、总量随整档JSON恢复")
	check(Inventory.snapshot_layout()==save.inventory_layout and Inventory.items==save.items,"读档后格子、数量和稳定UID完全一致")
	var damaged:=save.duplicate(true);damaged.inventory_layout.slots[0].amount=999
	var repaired:=FarmSaveSchema.normalize(damaged)
	check(not repaired.is_empty() and repaired.items==save.items and InventorySlots.valid(repaired.inventory_layout,repaired.items),"损坏的显示布局按原库存修复，不补发任何物品")
	damaged=save.duplicate(true);damaged.items.wood=1000
	check(FarmSaveSchema.normalize(damaged).is_empty(),"真实库存超上限仍按坏档拒绝，不用布局掩盖")
	check(FarmSaveStore.restore(game,old),"数据专项结束可恢复完整原有世界")
	await finish()
func uid_for(id: String, except_uid: int=0) -> int:
	Inventory.sync_layout()
	for entry in Inventory.layout.slots:
		if not entry.is_empty() and entry.item==id and int(entry.uid)!=except_uid: return int(entry.uid)
	return 0
func finish() -> void:
	print("UX083 INVENTORY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(5);get_tree().quit(1 if failed else 0)
