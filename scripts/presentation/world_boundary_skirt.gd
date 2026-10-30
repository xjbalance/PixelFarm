class_name WorldBoundarySkirt
extends RefCounted
## Native grass beyond the physical boundary keeps UI-safe edge panning filled.
## These cells are presentation only: navigation, ownership and saves use the real region.
static func attach(map: Node2D, ground: TileMapLayer, region: Rect2i, padding: int=7) -> void:
	var layer:=TileMapLayer.new();layer.name="BoundaryScenery";layer.z_index=-6;layer.tile_set=ground.tile_set
	for y in range(-padding,region.size.y+padding):
		for x in range(-padding,region.size.x+padding):
			if region.has_point(Vector2i(x,y)): continue
			layer.set_cell(Vector2i(x,y),0,Vector2i(absi(x*71+y*137)%3,0))
	map.add_child(layer)
