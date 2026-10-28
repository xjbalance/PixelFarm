class_name AquacultureWorld
extends Node2D
## 只给原农场湖泊添加岸边鱼栏，不改变 TileMap 的水域或原存档坐标。
const SITES := {
	"pen_1": Vector2(944,592),
	"pen_2": Vector2(1104,752),
	"pen_3": Vector2(1264,592),
	"pen_4": Vector2(1104,432)
}
const DIRECTIONS := {
	"pen_1": Vector2.RIGHT,
	"pen_2": Vector2.UP,
	"pen_3": Vector2.LEFT,
	"pen_4": Vector2.DOWN
}
var points: Dictionary = {}

func attach(owner_game: Node) -> void:
	Aquaculture.game=owner_game
	for id in SITES:
		var point := Node2D.new()
		point.set_script(preload("res://scripts/aquaculture/aquaculture_point.gd"))
		point.name="Lake_"+id
		point.pen_id=id
		point.position=Aquaculture.site_point(id)
		point.water_direction=DIRECTIONS[id]
		owner_game.world.get_node("Actors").add_child(point)
		points[id]=point
