class_name TerritorySurface
extends Node2D
## Native 32px terrain overlays; original TileData, water collision and crop state stay intact.
var area_id: String="farm"
var cells: Dictionary={}
var season: int=-1
var ground: TileMapLayer

func _ready() -> void:
	z_index=-3;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ground=get_parent().get_node_or_null("Ground")
	Calendar.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var next: Dictionary=Territory.state.get("terrain",{}).get(area_id,{})
	var next_season: int=Calendar.season()
	if next==cells and season==next_season: return
	cells=next.duplicate(true);season=next_season;queue_redraw()

func _draw() -> void:
	for key in cells:
		var cell:=TerritoryCatalog.cell_from_key(str(key))
		var kind: String=str(cells[key])
		var origin:=Vector2(cell)*32
		var material: String=SchemeCTerrain.material_kind(kind)
		var texture: Texture2D=SchemeCAssets.texture("grass",season) if material=="grass" else SchemeCTerrain.tile(material,season,SchemeCTerrain.connected_mask(cells,cell,kind,ground))
		if texture: draw_texture(texture,origin)
		if kind=="flowerbed":
			SchemeCAssets.draw(self,"short_grass",origin+Vector2(15,24),season)
