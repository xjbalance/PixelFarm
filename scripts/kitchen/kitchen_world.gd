class_name KitchenWorld
extends Node
func attach(owner_game: Node) -> void:
	Kitchen.game=owner_game
	for id in ["kitchen","berry"]:
		var point := Node2D.new();point.name="Kitchen" if id=="kitchen" else "WildBerry"
		point.set_script(preload("res://scripts/kitchen/kitchen_point.gd"));point.kitchen_id=id
		point.position=Kitchen.ANCHOR if id=="kitchen" else Kitchen.BERRY
		var parent: Node=owner_game.home if id=="kitchen" else owner_game.world.get_node("Actors")
		parent.add_child(point)
