class_name FarmRiverMap
extends FarmAtlasCanvas
## 旧调用兼容入口；所有绘制和手势统一委托给羊皮纸画布。
var location: String="farm":
	set(value):
		location=value
		if is_node_ready():
			show_region(location)
			world_size=FarmAtlasData.bounds(location).size
var world_size:=FarmLayoutCatalog.WORLD.size

func _ready() -> void:
	super._ready()
	custom_minimum_size=Vector2(570,350)
	var owner_game: Node=get_parent()
	while owner_game and not ("player" in owner_game and "resource_world" in owner_game): owner_game=owner_game.get_parent()
	if owner_game: setup(owner_game)
	show_region(location)
	world_size=FarmAtlasData.bounds(location).size

func point(world: Vector2) -> Vector2:
	return map_to_screen(FarmAtlasData.world_to_map(location,world))
