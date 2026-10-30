class_name LivestockWorld
extends Node2D
## 三处既有农场南岸空地；只生成当前畜舍与最多18个轻量动物。
var game: Node
var sites: Dictionary = {}
var animals: Dictionary = {}

func attach(owner_game: Node) -> void:
	game=owner_game
	Livestock.game=game
	for id in RanchLayout.ENABLED:
		var map:=RanchMap.new();map.site=id;map.game=game;map.hide();map.process_mode=Node.PROCESS_MODE_DISABLED
		game.add_child(map);map.ground.enabled=false;game.mine_maps[RanchLayout.area(id)]=map
		var gate:=Node2D.new();gate.set_script(preload("res://scripts/livestock/ranch_gate.gd"));gate.game=game;gate.site=id;game.world.get_node("Actors").add_child(gate)
	for id in Livestock.SITES:
		var point := Node2D.new()
		point.set_script(preload("res://scripts/livestock/livestock_point.gd"))
		point.livestock_id=id
		point.position=Livestock.site_point(id)
		game.world.get_node("Actors").add_child(point)
		sites[id]=point
	Livestock.changed.connect(refresh)
	var nest:=Node2D.new();nest.set_script(preload("res://scripts/livestock/livestock_nest.gd"));game.world.get_node("Actors").add_child(nest)
	FarmLayout.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var wanted := {}
	for entry in Livestock.state.animals:
		wanted[entry.id]=true
		if not animals.has(entry.id):
			var animal := CharacterBody2D.new()
			animal.set_script(preload("res://scripts/livestock/livestock_animal.gd"))
			animal.animal_id=entry.id
			animal.position=Livestock.animal_point(entry)
			var area: String=Livestock.animal_area(entry)
			var parent: Node=game.world if area=="farm" else game.mine_maps[area]
			parent.get_node("Actors").add_child(animal)
			animals[entry.id]=animal
		else:
			var body: CharacterBody2D=animals[entry.id]
			var destination:=Livestock.animal_point(entry)
			if body.position.distance_to(destination)>.2: body.route.clear();body.behavior=0;body.timer=.3
			body.position=destination
			animals[entry.id].refresh()
		var animal: CharacterBody2D=animals[entry.id]
		animal.visible=FarmLayout.active(str(entry.site))
		animal.process_mode=Node.PROCESS_MODE_INHERIT if animal.visible else Node.PROCESS_MODE_DISABLED
		animal.collision_mask=1 if animal.visible else 0
	for id in animals.keys():
		if not wanted.has(id):
			var old: Node=animals[id]
			animals.erase(id)
			old.remove_from_group("interactables")
			old.queue_free()
