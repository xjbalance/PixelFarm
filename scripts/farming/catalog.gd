extends Node
var crops: Dictionary = {}
var materials: Dictionary = {}

func _ready() -> void:
	register_crop(preload("res://resources/crops/carrot.tres"))
	register_crop(preload("res://resources/crops/potato.tres"))
	register_crop(preload("res://resources/crops/wheat.tres"))
	materials = JSON.parse_string(FileAccess.get_file_as_string("res://resources/items/materials.json"))

func register_crop(definition: CropDefinition) -> void:
	crops[definition.id] = definition

func item_name(id: String) -> String:
	var crop_id := id.trim_suffix("_seed")
	if crops.has(crop_id):
		return crops[crop_id].display_name + ("种子" if id.ends_with("_seed") else "")
	return str(materials[id].name) if materials.has(id) else id

func is_item(id: String) -> bool:
	return materials.has(id) or crops.has(id.trim_suffix("_seed"))

func sell_price(id: String) -> int:
	if crops.has(id): return int(crops[id].sell_price)
	if materials.has(id): return int(materials[id].sell_price)
	return 0
