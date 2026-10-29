class_name FishingWorld
extends Node2D
## 钓点只有岸边脚标与水中浮标；原水格碰撞始终保持。
var game: Node
var points: Dictionary = {}
func attach(owner_game: Node) -> void:
	game=owner_game;Fishing.bind(game)
	add_to_group("fishing_worlds")
	for id in Fishing.sites: add_site(id)
func add_site(id: String) -> bool:
	if points.has(id) or not Fishing.sites.has(id): return false
	var site: Dictionary=Fishing.sites[id]
	var maps: Dictionary=WorldTravel.maps(game)
	if not maps.has(site.area): return false
	var point := Node2D.new();point.set_script(preload("res://scripts/fishing/fishing_point.gd"))
	point.fish_point_id=id;point.position=Fishing.point(id)
	var parent: Node=maps[site.area].get_node_or_null("Actors")
	(parent if parent else maps[site.area]).add_child(point)
	points[id]=point
	return true
static func resolve_water(owner_game: Node, world_point: Vector2) -> Dictionary:
	if GameState.tool()!="fishing_rod": return {}
	var map: Node=WorldTravel.maps(owner_game).get(GameState.location)
	if not map: return {}
	var ground: TileMapLayer=map.get_node_or_null("Ground")
	if not ground: return {}
	var cell := Vector2i((world_point/32).floor())
	var atlas: Vector2i=ground.get_cell_atlas_coords(cell)
	if GameState.location=="mine_b":
		if atlas.x!=6: return {}
	elif GameState.location in ["farm","village"]:
		if atlas.x not in [5,6]: return {}
	else:
		if not map.has_method("is_fishing_water") or not map.is_fishing_water(cell): return {}
	var best: Node2D
	var distance := INF
	for node in owner_game.get_tree().get_nodes_in_group("interactables"):
		if not "fish_point_id" in node or not node.is_visible_in_tree(): continue
		var id: String=node.fish_point_id
		if Fishing.sites[id].area!=GameState.location: continue
		var current: float=Fishing.point(id,true).distance_squared_to(world_point)
		if current<distance: best=node;distance=current
	return {"kind":"object","object":best,"point":best.global_position} if best else {}
