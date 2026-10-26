class_name ResourceWorld
extends Node
## 所有地图共享原木石规则；每张图独立节点，存档沿用原resources扁平ID表。
var game: Node
var fields: Dictionary={}
func attach(owner_game: Node) -> void:
	game=owner_game
	fields["farm"]=game.world.resource_field
	for area in ["village","mist_forest"]:
		var field:=Node2D.new();field.name="GatheringResources"
		field.set_script(preload("res://scripts/gathering/resource_field.gd"));field.area_id=area
		var parent: Node=game.village.get_node("Actors") if area=="village" else game.mine_maps[area].get_node("Actors")
		parent.add_child(field);fields[area]=field
	Events.location_changed.connect(func(_area: String):
		for field in fields.values(): field.highlight(null)
	)
func active_field() -> Node2D:
	return fields.get(GameState.location) as Node2D
func committing() -> bool:
	for field in fields.values():
		if field.busy: return true
	return false
func snapshot() -> Dictionary:
	var result: Dictionary={}
	for field in fields.values(): result.merge(field.state.duplicate(true))
	return result
func restore(raw: Dictionary) -> void:
	for field in fields.values(): field.restore(raw)
