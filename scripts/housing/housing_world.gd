class_name HousingWorld
extends Node
var game: Node
var objects: Dictionary={}
var surface: Node2D
var extension: Node2D
func attach(owner_game: Node) -> void:
	game=owner_game;Housing.game=game
	for id in ["home","yard"]:
		var point := Node2D.new();point.set_script(preload("res://scripts/housing/housing_point.gd"));point.housing_id=id
		point.position=Housing.HOME if id=="home" else Housing.YARD
		var parent: Node=game.home if id=="home" else game.world.get_node("Actors")
		parent.add_child(point)
	surface=Node2D.new();surface.set_script(preload("res://scripts/housing/housing_surface.gd"));surface.game=game;game.home.add_child(surface)
	extension=Node2D.new();extension.set_script(preload("res://scripts/housing/housing_extension.gd"));extension.game=game;game.home.add_child(extension)
	Housing.changed.connect(refresh);refresh()
func refresh() -> void:
	if game.home.has_method("set_house_level"): game.home.set_house_level(Housing.state.level)
	var wanted := {}
	for entry in Housing.state.placed:
		wanted[entry.id]=true
		if not objects.has(entry.id):
			var object := Node2D.new();object.set_script(preload("res://scripts/housing/housing_furniture.gd"));object.housing_id=entry.id
			var parent: Node=game.home if entry.area=="home" else game.world.get_node("Actors")
			parent.add_child(object);objects[entry.id]=object
		objects[entry.id].refresh()
	for id in objects.keys():
		if not wanted.has(id):
			var object: Node=objects[id];objects.erase(id);object.remove_from_group("interactables");object.queue_free()
	if surface: surface.refresh()
	if extension: extension.refresh()
