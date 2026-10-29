extends Node
## 数量字典自然堆叠；所有增减由统一接口校验，UI 订阅 changed。
signal changed
const MAX_STACK: int = 999
const MAX_COINS: int = 999999999
var items: Dictionary = {"carrot_seed": 12, "potato_seed": 6, "wheat_seed": 6}
var coins: int = 120
var diamond_payment: bool = false # 只在已确认的同步交易期间启用，不保存此瞬态。

func count(id: String) -> int:
	return int(items.get(id, 0))

func add(id: String, amount: int) -> bool:
	if amount <= 0 or count(id) + amount > MAX_STACK:
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
