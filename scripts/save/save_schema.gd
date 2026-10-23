class_name FarmSaveSchema
extends RefCounted
## schema 版本迁移与验证不修改游戏状态；返回空字典表示整份存档不可用。
static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not whole(raw.get("version"),1,6): return {}
	var data: Dictionary = raw.duplicate(true)
	if int(data.version) == 1:
		# 旧版没有采集/设施/委托，保持所有已有进度，新增字段取初始值。
		if not whole(data.get("stamina"),0,100) or not whole(data.get("selected"),0,5): return {}
		var old_items = data.get("items")
		if not old_items is Dictionary: return {}
		for id in old_items:
			if not id is String or not Catalog.crops.has(id.trim_suffix("_seed")): return {}
		data.version = 2
		data.progress = {"built":[],"quests":{},"friendship":0,"last_talk_day":0}
		data.resources = {}
	if int(data.version) == 2:
		data.version = 3
		data.story = {"stage":0,"motive":"","lantern":"","seen":[],"assisted_tools":true}
		data.village = {"built":[],"water_day":0,"tea_day":0}
	if int(data.version) == 3:
		data.version = 4
		data.letters = Letters.migrate(data.story,data.get("journal",[]) if data.get("journal",[]) is Array else []) if data.get("story") is Dictionary and whole(data.story.get("stage"),0,8) else {}
	if int(data.version) == 4:
		data.version = 5
		data.xiaojing = Xiaojing.defaults()
	if int(data.version) == 5:
		data.version = 6
		data.control_mode = "tap"
	if not valid_current(data): return {}
	return data

static func valid_progress(data: Variant, day: Variant) -> bool:
	if not data is Dictionary or not whole(day,1,999999): return false
	var built = data.get("built")
	if not built is Array or built.size() > FarmProgress.upgrades.size(): return false
	var seen := {}
	for id in built:
		if not id is String or not FarmProgress.upgrades.has(id) or seen.has(id): return false
		seen[id] = true
	var quests = data.get("quests")
	if not quests is Dictionary or quests.size() > FarmProgress.quests.size(): return false
	for id in quests:
		if not id is String or not FarmProgress.quests.has(id) or not whole(quests[id],1,2): return false
		var previous: String = FarmProgress.quests[id].previous
		if previous != "" and not whole(quests.get(previous),2,2): return false
	return whole(data.get("friendship"),0,100) and whole(data.get("last_talk_day"),0,int(day))

static func valid_resources(data: Variant, day: Variant) -> bool:
	if not data is Dictionary or not whole(day,1,999999): return false
	var placements := FarmResourceCatalog.placements()
	if data.size() > placements.size(): return false
	for id in data:
		if not id is String or not placements.has(id): return false
		var entry = data[id]
		if not entry is Dictionary: return false
		var definition: Dictionary = FarmResourceCatalog.TYPES[placements[id].kind]
		if not whole(entry.get("hp"),0,int(definition.hits)): return false
		if entry.hp > 0:
			if not whole(entry.get("ready_day"),0,0): return false
		elif not whole(entry.get("ready_day"),1,int(day)+int(definition.regrow)): return false
	return true

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func valid_current(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not Letters.validate(data.get("letters")): return false
	if data.letters.direction != "" and (not data.get("story") is Dictionary or data.story.get("stage") != 8): return false
	if not whole(data.get("day"),1,999999) or not Xiaojing.validate(data.get("xiaojing"),int(data.day)): return false
	if not valid_progress(data.get("progress"),data.get("day")): return false
	if not valid_resources(data.get("resources"),data.get("day")): return false
	if not whole(data.get("version"),6,6) or not Story.validate(data.get("story")): return false
	if data.get("control_mode") not in ["tap","joystick"]: return false
	if not VillageProjects.validate(data.get("village"),data.get("day"),int(data.story.stage)): return false
	if not whole(data.get("day"),1,999999): return false
	if not whole(data.get("coins"),0,999999999): return false
	if not whole(data.get("stamina"),0,130 if "bedding" in data.progress.built else 100): return false
	if not whole(data.get("selected"),0,GameState.tools.size()-1): return false
	var minute = data.get("minutes")
	if not (minute is int or minute is float) or not is_finite(float(minute)) or minute < 360 or minute >= 1440: return false
	var location = data.get("location")
	if location not in ["farm","home","village"]: return false
	var pos = data.get("player")
	if not pos is Array or pos.size() != 2: return false
	for axis in pos:
		if not (axis is int or axis is float) or not is_finite(float(axis)): return false
	var region := Rect2(10,10,1516,1004) if location == "farm" else Rect2(362,234,556,332)
	if location == "village": region = Rect2(10,10,1260,876)
	if not region.has_point(Vector2(pos[0],pos[1])): return false
	var items = data.get("items")
	if not items is Dictionary or items.size() > 32: return false
	for id in items:
		if not id is String or not Catalog.is_item(id): return false
		if not whole(items[id],1,Inventory.MAX_STACK): return false
	var plots = data.get("plots")
	if not plots is Dictionary or plots.size() > 60: return false
	for id in plots:
		if not id is String: return false
		var parts: PackedStringArray = id.split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var cell := Vector2i(int(parts[0]),int(parts[1]))
		if id != "%d,%d" % [cell.x,cell.y] or not Rect2i(17,16,10,6).has_point(cell): return false
		var plot = plots[id]
		if not plot is Dictionary or not plot.get("watered") is bool: return false
		var crop_id = plot.get("crop")
		if not crop_id is String or (crop_id != "" and not Catalog.crops.has(crop_id)): return false
		var max_days: int = 0 if crop_id == "" else Catalog.crops[crop_id].growth_days
		if not whole(plot.get("days"),0,max_days): return false
	var journal = data.get("journal",[])
	if not journal is Array or journal.size() > 4: return false
	for entry in journal:
		if entry not in ["翻土","播种","浇水","收获"]: return false
	if not data.get("muted",false) is bool: return false
	return true
