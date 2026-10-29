class_name ProductionInfo
extends RefCounted
## Shared read-only wording for production, cooking and seeds.
static var usage_cache: Dictionary={}
static func materials(parent: Node, required: Dictionary, invested: bool=false) -> void:
	for id in required:
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);parent.add_child(row)
		FacilityLayout.item_preview(row,str(id),28)
		var label:=FarmUIStyle.label(Catalog.item_name(str(id)),18);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(label)
		var text: String="已投入 %d" % int(required[id]) if invested else "%d / %d" % [Inventory.count(str(id)),int(required[id])]
		row.add_child(FarmUIStyle.label(text,18,FarmUIStyle.MUTED if invested else FarmUIStyle.SUCCESS if Inventory.count(str(id))>=int(required[id]) else FarmUIStyle.DANGER))
static func eta(absolute_minute: int) -> String:
	var day: int=absolute_minute/1440+1;var minute: int=posmod(absolute_minute,1440)
	var sleep: bool=minute<360
	if sleep: minute=360
	var prefix: String="今天" if day==GameClock.day else "明天" if day==GameClock.day+1 else "第%d天" % day
	return "%s %02d:%02d%s" % [prefix,minute/60,minute%60,"可收取（夜间完成）" if sleep else ""]
static func duration(minutes: int) -> String:
	if minutes<60: return "%d分钟" % minutes
	return "%d小时" % (minutes/60) if minutes%60==0 else "%d小时%d分" % [minutes/60,minutes%60]
static func uses(item: String) -> String:
	if usage_cache.has(item): return usage_cache[item]
	var names: Array[String]=[]
	for recipe in Kitchen.data.recipes.values():
		if recipe.required.has(item) and str(recipe.name) not in names: names.append(str(recipe.name))
	for recipe in HarvestCatalog.data().processing.values():
		if recipe.input_items.has(item) and str(recipe.name) not in names: names.append(str(recipe.name))
	for furniture in Housing.data.furniture.values():
		if furniture.required.has(item): names.append(str(furniture.name))
	var lines: Array[String]=[]
	if not names.is_empty(): lines.append("可用于："+"、".join(names.slice(0,3))+("等%d种制作" % names.size() if names.size()>3 else ""))
	var definition:=Catalog.definition(item)
	if definition.get("kind","")=="food": lines.append("食用恢复%d体力；已有增益不叠加或续时。" % int(definition.get("energy",0)))
	if definition.get("gift_to","")!="": lines.append("可赠给"+str(Social.data.people.get(str(definition.gift_to),{}).get("name","村民")))
	if lines.is_empty(): lines.append(ItemPresentation.description(item))
	usage_cache[item]="\n".join(lines);return usage_cache[item]
static func kitchen_error(id: String, batches: int) -> String:
	if not Kitchen.data.recipes.has(id): return "配方不存在。"
	if not Kitchen.recipe_unlocked(id): return str(Kitchen.data.recipes[id].hint)
	if batches<1 or batches>8: return "每次可制作1至8批。"
	var recipe: Dictionary=Kitchen.data.recipes[id];var required:=Kitchen.scaled(recipe.required,batches)
	var missing:=Workshop.missing_materials(required)
	if missing!="": return "还缺："+missing
	if Inventory.preview_exchange(required,Kitchen.scaled(recipe.rewards,batches),0).is_empty(): return "成品背包空间不足，请先整理。"
	return ""
static func seed_hint(id: String) -> String:
	if not Catalog.crops.has(id): return ""
	var current: bool=Catalog.crop_grows(id)
	var hint: String=("当前季节可种" if current else "当前季节不生长")+" · "+HarvestCatalog.season_text(id)+"季 · %d个浇水生长日" % Catalog.crops[id].growth_days
	if HarvestCatalog.data().crops.has(id) and not HarvestCatalog.unlocked(str(HarvestCatalog.data().crops[id].unlock)): hint+="\n供货条件：建成种子合作社。"
	hint+="\n"+uses(id)
	return hint
