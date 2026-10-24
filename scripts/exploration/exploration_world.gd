class_name ExplorationWorld
extends Node
var game: Node
func attach(owner_game: Node) -> void:
	game=owner_game;Exploration.game=game
	for area in Exploration.AREAS:
		var map := ExplorationMap.new();map.area_id=area
		game.add_child(map);map.hide();map.process_mode=Node.PROCESS_MODE_DISABLED;map.ground.enabled=false
		game.mine_maps[area]=map
	for id in Exploration.data.entrances:
		var point := Node2D.new();point.set_script(preload("res://scripts/exploration/exploration_point.gd"));point.exploration_id=id
		point.position=Exploration.point(id)
		var area: String=Exploration.data.entrances[id].area
		var parent: Node=game.world.get_node("Actors") if area=="farm" else game.village.get_node("Actors")
		parent.add_child(point)
	for id in Exploration.data.fishing_sites:
		if not Fishing.sites.has(id): Fishing.register_site(id,Exploration.data.fishing_sites[id])
		for world in get_tree().get_nodes_in_group("fishing_worlds"): world.add_site(id)
