class_name SchemeCTerrain
extends RefCounted
## 47-pattern native terrain exported with the user-provided world pack.
## Only textures are selected here; TileData, physics, farm plot IDs and navigation stay intact.
const ROOT: String="res://assets/world_scheme_c/"
const SEASONS: Array[String]=["spring","summer","autumn","winter"]
const DIRECTIONS: Array[Vector2i]=[Vector2i.UP,Vector2i(1,-1),Vector2i.RIGHT,Vector2i(1,1),Vector2i.DOWN,Vector2i(-1,1),Vector2i.LEFT,Vector2i(-1,-1)]
static var _regions: Dictionary={}
static var _tiles: Dictionary={}

static func normalize_mask(mask: int) -> int:
	for edges in [[2,1,4],[8,4,16],[32,16,64],[128,64,1]]:
		if mask & int(edges[1]) == 0 or mask & int(edges[2]) == 0: mask &= ~int(edges[0])
	return mask

static func tile(material: String, season: int, mask: int=255) -> Texture2D:
	if _regions.is_empty():
		var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"terrain_mapping.json"))
		if raw is Dictionary:
			for entry in raw.get("sets",[]):
				var mapping: Dictionary={}
				for cell in entry.tiles: mapping[int(cell.mask)]=Vector2i(int(cell.atlas[0]),int(cell.atlas[1]))
				_regions[str(entry.id)]=mapping
	if not _regions.has(material): return SchemeCAssets.texture(material,season)
	mask=normalize_mask(mask)
	var key: String=material+":"+str(season)+":"+str(mask)
	if not _tiles.has(key):
		var atlas:=AtlasTexture.new()
		atlas.atlas=load(ROOT+"seasons/"+SEASONS[clampi(season,0,3)]+"/terrain/"+material+".png")
		atlas.region=Rect2(Vector2(_regions[material].get(mask,Vector2i(6,5)))*32,Vector2(32,32))
		_tiles[key]=atlas
	return _tiles[key]

static func material_kind(kind: String) -> String:
	if kind in ["soil","flowerbed"]: return "tilled_soil"
	if kind in ["dirt_path","stone_path","wood_path","sand","gravel"]: return kind
	return "grass"

static func connected_mask(cells: Dictionary, cell: Vector2i, kind: String, ground: TileMapLayer=null) -> int:
	var mask: int=0
	for index in range(DIRECTIONS.size()):
		var neighbor: Vector2i=cell+DIRECTIONS[index]
		var other: String=str(cells.get(TerritoryCatalog.key(neighbor),""))
		if other=="" and is_instance_valid(ground):
			var index_at: int=ground.get_cell_atlas_coords(neighbor).x
			other="dirt_path" if index_at==3 else ""
		if material_kind(other)==material_kind(kind) and other!="": mask |= 1 << index
	return normalize_mask(mask)
