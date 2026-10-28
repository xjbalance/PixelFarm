class_name SocialWorld
extends Node
func attach(owner_game: Node) -> void:
	Social.game=owner_game
	for id in Social.SITES:
		var entry: Dictionary=Social.SITES[id]
		var point := Node2D.new();point.name="PersonalNote_"+id
		point.set_script(preload("res://scripts/social/social_point.gd"));point.site_id=id;point.position=Social.site_point(id)
		var parent: Node=owner_game.home if entry.area=="home" else (owner_game.world.get_node("Actors") if entry.area=="farm" else owner_game.village.get_node("Actors"))
		parent.add_child(point)
