class_name WorldDevelopmentWorld
extends Node2D
## 新设施叠加在原村庄陆岸上；原TileMap/桥/水域和已有设施不重建。
var game: Node
var points: Dictionary = {}
func attach(owner_game: Node) -> void:
	game=owner_game;WorldDevelopment.bind(game);add_to_group("world_development_worlds")
	for context in ["board","dock","community","lamp:west","lamp:square","lamp:river"]:
		var point := Node2D.new();point.set_script(preload("res://scripts/world_progress/world_development_point.gd"))
		point.development_id=context;point.position=WorldDevelopment.anchor(context)
		game.village.get_node("Actors").add_child(point);points[context]=point
	WorldDevelopment.changed.connect(refresh);GameClock.changed.connect(refresh);Calendar.changed.connect(refresh)
	refresh()
func refresh() -> void:
	for context in points:
		points[context].visible=context=="board" or (context=="dock" and WorldDevelopment.state.dock>0) or (context!="dock" and context!="board" and WorldDevelopment.state.community>0)
		points[context].refresh()
