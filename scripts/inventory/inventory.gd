extends Node
## 数量字典自然堆叠；所有增减由统一接口校验，UI 订阅 changed。
signal changed
const MAX_STACK: int = 999
const MAX_COINS: int = 999999999
var items: Dictionary = {"carrot_seed": 12, "potato_seed": 6, "wheat_seed": 6}
var coins: int = 120
var diamond_payment: bool = false # 只在已确认的同步交易期间启用，不保存此瞬态。
var layout: Dictionary={}
var revision: int=0
var layout_busy: bool=false
var preferred_uid: int=0
var _layout_items: Dictionary={}

func _ready() -> void:
	layout=InventorySlots.defaults(items);_layout_items=items.duplicate(true)
	changed.connect(sync_layout)

func sync_layout() -> void:
	if items==_layout_items and not layout.is_empty(): return
	layout=InventorySlots.normalize(layout,items,preferred_uid)
	_layout_items=items.duplicate(true);revision+=1

func snapshot_layout() -> Dictionary:
	sync_layout();return layout.duplicate(true)

func restore_layout(raw: Dictionary) -> void:
	layout=InventorySlots.normalize(raw,items);_layout_items=items.duplicate(true);preferred_uid=0;layout_busy=false;revision+=1

func stack_index(uid: int) -> int:
	sync_layout()
	for i in range(layout.slots.size()):
		if not layout.slots[i].is_empty() and int(layout.slots[i].uid)==uid: return i
	return -1

func stack(uid: int) -> Dictionary:
	var index:=stack_index(uid)
	return layout.slots[index].duplicate() if index>=0 else {}

func stack_locked(uid: int) -> bool:
	sync_layout();return uid in layout.locked

func transferable(id: String) -> int:
	sync_layout()
	if ItemTaxonomy.is_permanent_tool(id): return 0
	var result: int=0
	for entry in layout.slots:
		if not entry.is_empty() and entry.item==id and entry.uid not in layout.locked: result+=int(entry.amount)
	return result

func layout_available(expected: int) -> bool:
	sync_layout()
	if not FarmSaveSchema.valid_item_totals(items): return false
	if is_instance_valid(Kitchen.game) and (Kitchen.game.backgrounded or Kitchen.game.closing): return false
	return not layout_busy and not GameState.restoring and not GameClock.settling and expected==revision

func commit_layout(candidate: Dictionary) -> bool:
	if not InventorySlots.valid(candidate,items): return false
	if candidate==layout: return true
	layout_busy=true;layout=candidate;revision+=1
	changed.emit();layout_busy=false;Events.progress_committed.emit();return true

func toggle_stack_lock(uid: int, expected: int) -> bool:
	if not layout_available(expected) or stack_index(uid)<0: return false
	var candidate:=layout.duplicate(true)
	if uid in candidate.locked: candidate.locked.erase(uid)
	else: candidate.locked.append(uid)
	return commit_layout(candidate)

func move_stack(uid: int, target_index: int, expected: int) -> bool:
	if not layout_available(expected) or target_index<0 or target_index>=InventorySlots.limit(): return false
	var source_index:=stack_index(uid)
	if source_index<0 or stack_locked(uid): return false
	if target_index==source_index: return true
	var candidate:=layout.duplicate(true)
	while candidate.slots.size()<=target_index: candidate.slots.append({})
	var from: Dictionary=candidate.slots[source_index];var to: Dictionary=candidate.slots[target_index]
	if not to.is_empty() and int(to.uid) in candidate.locked: return false
	if not to.is_empty() and to.item==from.item:
		var amount:=mini(int(from.amount),MAX_STACK-int(to.amount))
		if amount<=0: return false
		to.amount+=amount;from.amount-=amount
		if from.amount==0: candidate.slots[source_index]={}
	else:
		candidate.slots[source_index]=to;candidate.slots[target_index]=from
	return commit_layout(candidate)

func split_stack(uid: int, amount: int, expected: int) -> bool:
	if not layout_available(expected): return false
	var source_index:=stack_index(uid)
	if source_index<0 or stack_locked(uid): return false
	var source: Dictionary=layout.slots[source_index]
	if ItemTaxonomy.is_permanent_tool(source.item) or amount<1 or amount>int(source.amount): return false
	var index:=InventorySlots.empty_index(layout.slots)
	if amount==int(source.amount): return move_stack(uid,index,expected)
	var groups: int=0
	for entry in layout.slots:
		if not entry.is_empty(): groups+=1
	if groups>=InventorySlots.SPLIT_GROUP_LIMIT or int(layout.next_uid)>=InventorySlots.MAX_UID: return false
	var candidate:=layout.duplicate(true)
	var part: Dictionary={"uid":int(candidate.next_uid),"item":str(source.item),"amount":amount};candidate.next_uid+=1
	candidate.slots[source_index].amount-=amount
	if index==candidate.slots.size(): candidate.slots.append(part)
	else: candidate.slots[index]=part
	return commit_layout(candidate)

func sort_stacks(expected: int) -> bool:
	if not layout_available(expected): return false
	var candidate:=layout.duplicate(true);var merged: Dictionary={}
	for i in range(candidate.slots.size()):
		var entry: Dictionary=candidate.slots[i]
		if entry.is_empty() or int(entry.uid) in candidate.locked: continue
		if not merged.has(entry.item): merged[entry.item]=entry.duplicate()
		else:
			var total: int=int(merged[entry.item].amount)+int(entry.amount)
			if int(entry.uid)<int(merged[entry.item].uid): merged[entry.item]=entry.duplicate()
			merged[entry.item].amount=total
		candidate.slots[i]={}
	var entries: Array=merged.values();entries.sort_custom(ItemTaxonomy.comes_before)
	for entry in entries:
		var index:=InventorySlots.empty_index(candidate.slots)
		if index==candidate.slots.size(): candidate.slots.append(entry)
		else: candidate.slots[index]=entry
	while not candidate.slots.is_empty() and candidate.slots[-1].is_empty(): candidate.slots.pop_back()
	return commit_layout(candidate)

func discard_stack(uid: int, amount: int, expected: int) -> bool:
	if not layout_available(expected): return false
	var entry:=stack(uid)
	if entry.is_empty() or stack_locked(uid) or ItemTaxonomy.is_protected(entry.item) or amount<1 or amount>int(entry.amount): return false
	layout_busy=true;preferred_uid=uid
	var ok:=exchange({str(entry.item):amount},{},0)
	preferred_uid=0;layout_busy=false
	if ok: Events.progress_committed.emit()
	return ok

func use_stack(uid: int, expected: int) -> bool:
	if not layout_available(expected): return false
	var entry:=stack(uid)
	if entry.is_empty(): return false
	var id: String=entry.item
	if ItemTaxonomy.is_permanent_tool(id): GameState.select_tool(int(ItemTaxonomy.TOOL_INDEX[id]));Events.progress_committed.emit();return true
	if id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed")):
		Workshop.select_seed(id.trim_suffix("_seed"));return GameState.tool()==id
	layout_busy=true;preferred_uid=uid
	var ok: bool=false
	if Recovery.FOOD.has(id): ok=Recovery.eat_crop(id)
	elif id in ["dried_fish","fish_soup"]: ok=Aquaculture.consume_food(id)
	elif Kitchen.data.items.get(id,{}).get("kind","")=="food": ok=Kitchen.consume(id)
	elif id=="fishing_hook": ok=Fishing.equip_hook()
	preferred_uid=0;layout_busy=false
	return ok

func count(id: String) -> int:
	return int(items.get(id, 0))

func add(id: String, amount: int) -> bool:
	if not Catalog.is_item(id) or amount <= 0 or count(id) + amount > MAX_STACK:
		return false
	items[id] = count(id) + amount
	changed.emit()
	return true

func exchange(required: Dictionary, rewards: Dictionary, coin_delta: int) -> bool:
	# 多物品交易先在副本中完整计算，拒绝时数量和金币都不变化。
	var result := preview_exchange(required,rewards,coin_delta)
	if result.is_empty(): return false
	items = result.items
	coins = result.coins
	if result.has("diamonds"):
		var spent: int=int(result.diamonds)-int(Xiaojing.state.diamonds)
		Xiaojing.state.diamonds=result.diamonds
		Playtest.record("diamonds",{"source":"purchase","delta":spent})
		Xiaojing.changed.emit()
		Events.progress_committed.emit()
	changed.emit()
	return true

func preview_exchange(required: Dictionary, rewards: Dictionary, coin_delta: int) -> Dictionary:
	var diamond_cost: int=DiamondPayments.price(-coin_delta) if diamond_payment and coin_delta<0 else 0
	if diamond_cost>Xiaojing.state.diamonds: return {}
	if diamond_cost>0: coin_delta=0
	if coins+coin_delta < 0 or coins+coin_delta > MAX_COINS: return {}
	var candidate := items.duplicate(true)
	for changes in [required,rewards]:
		for id in changes:
			if not id is String or not Catalog.is_item(id): return {}
			var amount = changes[id]
			if not (amount is int or amount is float) or amount <= 0 or amount > MAX_STACK or float(amount) != floorf(float(amount)): return {}
	for id in required:
		if int(candidate.get(id,0)) < int(required[id]): return {}
		candidate[id] = int(candidate[id])-int(required[id])
		if candidate[id] == 0: candidate.erase(id)
	for id in rewards:
		var total: int = int(candidate.get(id,0))+int(rewards[id])
		if total > MAX_STACK: return {}
		candidate[id] = total
	var result := {"items":candidate,"coins":coins+coin_delta}
	if diamond_cost>0: result.diamonds=int(Xiaojing.state.diamonds)-diamond_cost
	return result

func remove(id: String, amount: int) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true
