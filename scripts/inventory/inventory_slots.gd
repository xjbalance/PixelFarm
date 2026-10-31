class_name InventorySlots
extends RefCounted
## Persistent grouping and placement of the authoritative Inventory.items totals.
## Original permanent tools are immutable capabilities represented once in this layout.
const SPLIT_GROUP_LIMIT: int=2048
const MAX_UID: int=999999999

static func limit() -> int: return SPLIT_GROUP_LIMIT+Catalog.items.size()+ItemTaxonomy.TOOLS.size()+32
static func owned(items: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for id in items: result[id]=int(items[id])
	for id in ItemTaxonomy.TOOLS: result[id]=1
	return result

static func defaults(items: Dictionary) -> Dictionary:
	var entries: Array=[]
	var available:=owned(items)
	for id in available: entries.append({"uid":0,"item":str(id),"amount":int(available[id])})
	entries.sort_custom(ItemTaxonomy.comes_before)
	var serial: int=1
	for entry in entries: entry.uid=serial;serial+=1
	return {"version":1,"next_uid":serial,"slots":entries,"locked":[]}

static func structure(raw: Variant) -> bool:
	if not raw is Dictionary or not AquacultureSaveSchema.exact(raw,["version","next_uid","slots","locked"]): return false
	if not FarmSaveSchema.whole(raw.version,1,1) or not FarmSaveSchema.whole(raw.next_uid,1,MAX_UID): return false
	if not raw.slots is Array or raw.slots.size()>limit() or not raw.locked is Array or raw.locked.size()>raw.slots.size(): return false
	var ids: Dictionary={}
	for entry in raw.slots:
		if not entry is Dictionary: return false
		if entry.is_empty(): continue
		if not AquacultureSaveSchema.exact(entry,["uid","item","amount"]): return false
		if not FarmSaveSchema.whole(entry.uid,1,int(raw.next_uid)-1) or ids.has(int(entry.uid)): return false
		if not entry.item is String or (not Catalog.is_item(entry.item) and not ItemTaxonomy.is_permanent_tool(entry.item)): return false
		if not FarmSaveSchema.whole(entry.amount,1,1 if ItemTaxonomy.is_permanent_tool(entry.item) else Inventory.MAX_STACK): return false
		ids[int(entry.uid)]=true
	var locks: Dictionary={}
	for uid in raw.locked:
		if not FarmSaveSchema.whole(uid,1,MAX_UID) or not ids.has(int(uid)) or locks.has(int(uid)): return false
		locks[int(uid)]=true
	return true

static func totals(raw: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for entry in raw.slots:
		if not entry.is_empty(): result[entry.item]=int(result.get(entry.item,0))+int(entry.amount)
	return result

static func valid(raw: Variant, items: Dictionary) -> bool:
	return FarmSaveSchema.valid_item_totals(items) and structure(raw) and totals(raw)==owned(items)

static func empty_index(slots: Array) -> int:
	for i in range(slots.size()):
		if slots[i].is_empty(): return i
	return slots.size()

static func normalize(raw: Variant, items: Dictionary, preferred_uid: int=0) -> Dictionary:
	if not structure(raw): return defaults(items)
	var result: Dictionary=AbyssSaveSchema.canonical(raw).duplicate(true)
	var desired:=owned(items);var current:=totals(result)
	for id in current:
		var excess: int=int(current[id])-int(desired.get(id,0))
		if excess<=0: continue
		var candidates: Array[int]=[]
		for i in range(result.slots.size()):
			if not result.slots[i].is_empty() and result.slots[i].item==id: candidates.append(i)
		candidates.sort_custom(func(a: int,b: int):
			var au: int=result.slots[a].uid;var bu: int=result.slots[b].uid
			if au==preferred_uid: return bu!=preferred_uid
			if bu==preferred_uid: return false
			if (au in result.locked)!=(bu in result.locked): return au not in result.locked
			return a>b
		)
		for i in candidates:
			var removed:=mini(excess,int(result.slots[i].amount));result.slots[i].amount-=removed;excess-=removed
			if result.slots[i].amount==0:
				result.locked.erase(int(result.slots[i].uid));result.slots[i]={}
			if excess==0: break
	current=totals(result)
	for id in desired:
		var missing: int=int(desired[id])-int(current.get(id,0))
		if missing<=0: continue
		for entry in result.slots:
			if not entry.is_empty() and entry.item==id:
				var added:=mini(missing,Inventory.MAX_STACK-int(entry.amount));entry.amount+=added;missing-=added
				if missing==0: break
		if missing>0:
			if int(result.next_uid)>=MAX_UID: return defaults(items)
			var index:=empty_index(result.slots)
			var entry: Dictionary={"uid":int(result.next_uid),"item":id,"amount":missing};result.next_uid+=1
			if index==result.slots.size(): result.slots.append(entry)
			else: result.slots[index]=entry
	while not result.slots.is_empty() and result.slots[-1].is_empty(): result.slots.pop_back()
	return result if valid(result,items) else defaults(items)
