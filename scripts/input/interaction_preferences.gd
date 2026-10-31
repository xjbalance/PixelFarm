class_name InteractionPreferences
extends RefCounted
## UI preferences live in the existing game save, separate from item ownership.
const HOTBAR: Array[String]=["hoe","water","hand","carrot_seed","potato_seed","wheat_seed","axe","pickaxe","fishing_rod"]
static func defaults(save: Dictionary={}) -> Dictionary:
	var bindings:=HOTBAR.duplicate()
	var workshop: Variant=save.get("workshop",{})
	var seed: Variant=workshop.get("selected_seed","wheat_seed") if workshop is Dictionary else "wheat_seed"
	if seed is String and Catalog.is_item(seed): bindings[5]=seed
	var selected: int=int(save.selected) if FarmSaveSchema.whole(save.get("selected"),0,8) else 0
	return {"version":1,"hotbar":bindings,"hotbar_slot":selected,"active_item":bindings[selected],"hotbar_display":"compact","bag_category":"all","ui_scale":1.0,"touch_sensitivity":1.0,"camera_sensitivity":1.0,"haptics":false,"notice_level":"normal","protect_hotbar":true}

static func normalize(raw: Variant, save: Dictionary={}) -> Dictionary:
	var result:=defaults(save)
	if not raw is Dictionary: return result
	if raw.get("hotbar") is Array and raw.hotbar.size()==9:
		for i in range(9):
			if raw.hotbar[i] is String and (raw.hotbar[i]=="" or ItemTaxonomy.is_permanent_tool(raw.hotbar[i]) or Catalog.is_item(raw.hotbar[i])): result.hotbar[i]=raw.hotbar[i]
	if FarmSaveSchema.whole(raw.get("hotbar_slot"),0,8): result.hotbar_slot=int(raw.hotbar_slot)
	if raw.get("active_item") is String and (ItemTaxonomy.is_permanent_tool(raw.active_item) or Catalog.is_item(raw.active_item)): result.active_item=raw.active_item
	if raw.get("hotbar_display") in ["compact","expanded"]: result.hotbar_display=raw.hotbar_display
	if raw.get("bag_category") in ItemTaxonomy.CATEGORIES: result.bag_category=raw.bag_category
	for key in ["ui_scale","touch_sensitivity","camera_sensitivity"]:
		var value: Variant=raw.get(key)
		if (value is int or value is float) and is_finite(float(value)) and float(value)>=.75 and float(value)<=1.5: result[key]=float(value)
	for key in ["haptics","protect_hotbar"]:
		if raw.get(key) is bool: result[key]=raw[key]
	if raw.get("notice_level") in ["normal","quiet"]: result.notice_level=raw.notice_level
	return result
