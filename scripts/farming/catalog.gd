extends Node
## 统一只读物品目录；旧作物资源与矿物/养殖ID仍是来源，不复制或改写玩家物品。
const FOUNDATION_CROPS: Array[String]=["carrot","potato","wheat"]
var crops: Dictionary = {}
var materials: Dictionary = {}
var aquaculture_items: Dictionary = {}
var items: Dictionary = {}
var config: Dictionary = {}

func _ready() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://resources/seasons/economy.json"))
	register_crop(preload("res://resources/crops/carrot.tres"))
	register_crop(preload("res://resources/crops/potato.tres"))
	register_crop(preload("res://resources/crops/wheat.tres"))
	for group in config.groups:
		var source: Dictionary=config.groups[group]
		var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path))
		var definitions: Dictionary=raw if source.section=="" else raw[source.section]
		if group=="materials": materials=definitions
		if group=="aquaculture": aquaculture_items=definitions
		for id in definitions:
			var entry: Dictionary=definitions[id].duplicate(true)
			entry.category=source.category
			entry.source=source.path
			register_item(id,entry)

	HarvestCatalog.register(self)

func register_item(id: String, definition: Dictionary) -> bool:
	if items.has(id) or id=="" or not definition.get("name") is String or not definition.get("sell_price") is float and not definition.get("sell_price") is int:
		push_error("重复或无效的物品定义："+id)
		return false
	if float(definition.sell_price)<0 or float(definition.sell_price)!=floorf(float(definition.sell_price)): return false
	var entry := definition.duplicate(true)
	entry.sell_price=int(entry.sell_price)
	items[id]=entry
	return true

func register_crop(definition: CropDefinition) -> void:
	crops[definition.id] = definition
	register_item(definition.id,{"name":definition.display_name,"sell_price":definition.sell_price,"category":"crop","source":definition.resource_path})
	register_item(definition.id+"_seed",{"name":definition.display_name+"种子","sell_price":0,"category":"seed","source":definition.resource_path})

func item_name(id: String) -> String:
	return str(items[id].name) if items.has(id) else id

func is_item(id: String) -> bool:
	return items.has(id)

func sell_price(id: String) -> int:
	return int(items[id].sell_price) if items.has(id) else 0

func definition(id: String) -> Dictionary:
	return items.get(id,{}).duplicate(true)

func crop_grows(id: String, day: int = GameClock.day) -> bool:
	if not crops.has(id): return false
	# JSON numbers are floats; convert only for comparison, keep source data immutable.
	for season in config.crop_seasons[id]:
		if int(season)==Calendar.season(day): return true
	return false
