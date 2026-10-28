class_name HouseExterior
extends Node
## 仅替换原玩家房屋同尺寸贴图；不添加/移动农场物件或改变碰撞入口。
var house: Sprite2D
var applied_level: int=0
func attach(game: Node) -> void:
	for child in game.world.get_children():
		find_house(child)
	Housing.changed.connect(refresh)
	refresh()
func find_house(node: Node) -> void:
	if node is Sprite2D and node.texture and node.texture.resource_path=="res://assets/buildings/house.png": house=node
	for child in node.get_children(): find_house(child)
func refresh() -> void:
	var level: int=int(Housing.state.level)
	if not is_instance_valid(house) or applied_level==level: return
	var path: String="res://assets/world_scheme_c/derived/exterior_%d.png" % level
	if ResourceLoader.exists(path):
		house.texture=load(path);applied_level=level
