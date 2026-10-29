class_name FarmEconomy
extends RefCounted
## 先校验整笔交易，再一次提交金币和物品，失败不改变任何资源。
static func buy(crop_id: String, quantity: int) -> bool:
	if not Catalog.crops.has(crop_id) or quantity < 1 or quantity > 99:
		Events.notice.emit("购买数量须为 1—99。")
		return false
	if not HarvestCatalog.seed_available(crop_id):
		Events.notice.emit("当前季节不出售这种种子，或尚需完成种子合作社建设。")
		return false
	var crop: CropDefinition = Catalog.crops[crop_id]
	var cost: int = seed_price(crop_id) * quantity
	var item := crop_id + "_seed"
	if not Inventory.diamond_payment and Inventory.coins < cost:
		Events.notice.emit("金币不足，还差 %d 金。" % (cost - Inventory.coins))
		return false
	if Inventory.count(item) + quantity > Inventory.MAX_STACK:
		Events.notice.emit("这类种子已经装满背包。")
		return false
	if not Inventory.exchange({},{item:quantity},-cost): return false
	Xiaojing.on_trade(-cost,item,quantity)
	Events.progress_committed.emit()
	Events.notice.emit("买到 %s种子 ×%d，花费 %s。" % [crop.display_name,quantity,"%d钻石" % DiamondPayments.price(cost) if Inventory.diamond_payment else "%d金" % cost])
	return true

static func seed_price(crop_id: String) -> int:
	var base: int = Catalog.crops[crop_id].seed_price
	return ceili(base * 0.8) if VillageProjects.has_project("cooperative") else base

static func sell(crop_id: String, quantity: int) -> bool:
	if Catalog.sell_price(crop_id) <= 0 or quantity <= 0 or Inventory.count(crop_id) < quantity:
		Events.notice.emit("没有足够的收获可以出售。")
		return false
	var total: int = Catalog.sell_price(crop_id) * quantity
	if not Inventory.exchange({crop_id:quantity},{},total):
		Events.notice.emit("金币已经达到上限。")
		return false
	Xiaojing.on_trade(total,crop_id,quantity)
	Events.progress_committed.emit()
	Events.notice.emit("出售 %s ×%d，获得 %d 金。" % [Catalog.item_name(crop_id),quantity,total])
	return true
