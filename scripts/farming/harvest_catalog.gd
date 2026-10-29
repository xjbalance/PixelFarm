class_name HarvestCatalog
extends RefCounted
## Expansion data shares Catalog item IDs, Kitchen food effects and Territory placement.
const PATH := "res://resources/harvest/harvest.json"
static var _data: Dictionary={}
static func data() -> Dictionary:
	if _data.is_empty(): _data=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
	return _data

static func register(catalog: Node) -> void:
	for id in data().crops:
		var row: Dictionary=data().crops[id]
		var crop:=CropDefinition.new()
		crop.id=id;crop.display_name=row.name;crop.seed_price=row.seed_price;crop.sell_price=row.sell_price
		crop.growth_days=row.growth_days;crop.harvest_quantity=row.harvest_quantity
		crop.texture_path="res://assets/harvest/crops/"+id+".png"
		catalog.register_crop(crop)
		catalog.config.crop_seasons[id]=row.seasons.duplicate()
		catalog.items[id].merge({"description":row.description,"icon":"res://assets/harvest/items/"+id+".png","gift_to":row.gift_to},true)
		catalog.items[id+"_seed"].icon="res://assets/harvest/items/"+id+"_seed.png"
	for id in data().items:
		var row: Dictionary=data().items[id].duplicate(true);row.category="kitchen";row.source=PATH
		catalog.register_item(id,row)

static func unlocked(condition: String) -> bool:
	return condition=="basic" or (condition=="cooperative" and VillageProjects.has_project("cooperative"))

static func seed_available(id: String) -> bool:
	if not data().crops.has(id): return Catalog.crops.has(id)
	return Catalog.crop_grows(id) and unlocked(str(data().crops[id].unlock))

static func season_text(id: String) -> String:
	var names: Array[String]=[]
	for index in Catalog.config.crop_seasons.get(id,[]): names.append(["春","夏","秋","冬"][int(index)])
	return "、".join(names)

static func placeables() -> Dictionary:
	var result: Dictionary={}
	for id in data().stations:
		result["station_"+id]={"name":data().stations[id].name,"size":[1,1],"solid":true,"category":"objects","group":"workshop","art":"","station":id}
	for id in data().orchard:
		result["orchard_"+id]={"name":data().orchard[id].name+"（结果树）","size":[1,1],"solid":true,"category":"vegetation","group":"orchard","art":"","fruit":id}
	return result
