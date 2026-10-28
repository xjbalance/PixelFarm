class_name FarmTerrain
extends RefCounted
## The editable farm's effective terrain. Source 0 keeps the original TileData;
## selecting atlas columns 5/6 changes real water collision, not only its paint.
const REGION:=Rect2i(0,0,48,32)
const ROOT: String="res://assets/world_scheme_c/"
static var _base: Dictionary={}
static var _images: Dictionary={}

static func _prepare_base() -> void:
	if not _base.is_empty(): return
	var rng:=RandomNumberGenerator.new();rng.seed=7129
	for y in range(32):
		for x in range(48):
			var index: int=rng.randi_range(0,2)
			if y in [13,14] or (x in [14,15] and y>5): index=3
			if Rect2i(16,15,12,8).has_point(Vector2i(x,y)): index=4
			_base[Vector2i(x,y)]=index

static func overrides() -> Dictionary:
	return Territory.state.get("terrain",{}).get("farm",{})

static func base_index(cell: Vector2i, lake_offset: Vector2=Vector2.INF, lake_active: bool=true) -> int:
	_prepare_base()
	if not REGION.has_point(cell): return -1
	if lake_offset==Vector2.INF:
		lake_offset=FarmLayout.offset("lake");lake_active=FarmLayout.active("lake")
	var index: int=int(_base[cell])
	if lake_active:
		var point: Vector2=Vector2(cell)-lake_offset/32-Vector2(34,18)
		var distance: float=point.length()
		if distance<4.8: index=3
		if distance<4.1: index=5
		if distance<2.9: index=6
	return index

static func effective_index(cell: Vector2i, terrain_overrides: Variant=null, lake_offset: Vector2=Vector2.INF, lake_active: bool=true) -> int:
	if not REGION.has_point(cell): return -1
	var source: Dictionary=overrides() if terrain_overrides==null else (terrain_overrides if terrain_overrides is Dictionary else {})
	var kind: String=str(source.get(TerritoryCatalog.key(cell),""))
	match kind:
		"grass": return 0
		"soil","flowerbed","sand","gravel": return 4
		"dirt_path","stone_path": return 3
		"wood_path": return 7
		"water": return 5
		"deep_water": return 6
	return base_index(cell,lake_offset,lake_active)

static func index(cell: Vector2i, terrain_overrides: Variant=null, lake_offset: Vector2=Vector2.INF, lake_active: bool=true) -> int:
	return effective_index(cell,terrain_overrides,lake_offset,lake_active)

static func apply(target: Node) -> bool:
	var ground: TileMapLayer=target as TileMapLayer
	if not ground and is_instance_valid(target):
		if target.has_node("Ground"): ground=target.get_node("Ground")
		elif "world" in target and is_instance_valid(target.world): ground=target.world.get_node("Ground")
	if not is_instance_valid(ground): return false
	var changed: bool=false
	var source: Dictionary=overrides()
	var offset: Vector2=FarmLayout.offset("lake");var active: bool=FarmLayout.active("lake")
	for y in range(32):
		for x in range(48):
			var cell:=Vector2i(x,y);var value:=Vector2i(effective_index(cell,source,offset,active),0)
			if ground.get_cell_source_id(cell)==0 and ground.get_cell_atlas_coords(cell)==value: continue
			ground.set_cell(cell,0,value);changed=true
	if changed: Events.navigation_changed.emit()
	return changed

static func hoe_error(game: Node, cell: Vector2i) -> String:
	if not REGION.has_point(cell): return "这里已超出农场范围。"
	if effective_index(cell) in [5,6]: return "先在建造模式把水面填成陆地，再开垦。"
	if not Territory.object_at("farm",cell).is_empty(): return "先移动或收纳这里的摆件，再开垦。"
	var kind: String=str(overrides().get(TerritoryCatalog.key(cell),""))
	if kind in ["dirt_path","stone_path","wood_path","sand","gravel","flowerbed"]: return "先恢复成草地或自然地表，再开垦。"
	if not is_instance_valid(game) or not is_instance_valid(game.get("player")) or not is_instance_valid(game.get("world")): return "农场尚未准备好。"
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(28,28)
	query.shape=shape;query.transform=Transform2D(0,Vector2(cell)*32+Vector2(16,16));query.collision_mask=1
	for hit in game.player.get_world_2d().direct_space_state.intersect_shape(query,64):
		if hit.collider==game.world or game.world.is_ancestor_of(hit.collider): return "这里被建筑、家具、树石或设施占用，请先移动它们。"
	return ""

static func safe_for_hoe(game: Node, cell: Vector2i) -> bool: return hoe_error(game,cell)==""

static func _image(id: String, season: int) -> Image:
	var key: String=id+":"+str(season)
	if not _images.has(key):
		var texture: Texture2D=SchemeCAssets.texture(id,season)
		var result: Image=texture.get_image();result.convert(Image.FORMAT_RGBA8);_images[key]=result
	return _images[key]

static func _tile(material: String, season: int, mask: int) -> Image:
	var key: String=material+":"+str(season)+":"+str(SchemeCTerrain.normalize_mask(mask))
	if not _images.has(key):
		var result: Image=SchemeCTerrain.tile(material,season,mask).get_image();result.convert(Image.FORMAT_RGBA8);_images[key]=result
	return _images[key]

static func _ground_tile(index_value: int, season: int) -> Image:
	var key: String="ground:"+str(season)+":"+str(index_value)
	if not _images.has(key):
		var texture: Texture2D=load(ROOT+"derived/ground_"+SchemeCAssets.SEASONS[season]+".png")
		var result: Image=texture.get_image().get_region(Rect2i(index_value*32,0,32,32));result.convert(Image.FORMAT_RGBA8);_images[key]=result
	return _images[key]

static func _kind(cell: Vector2i, source: Dictionary, offset: Vector2, active: bool) -> String:
	var kind: String=str(source.get(TerritoryCatalog.key(cell),""))
	if kind not in ["","natural"]: return "water" if kind=="deep_water" else kind
	var value: int=base_index(cell,offset,active)
	return "grass" if value<3 else "dirt_path" if value==3 else "dirt" if value==4 else "water" if value in [5,6] else "wood_path"

static func texture(season: int, terrain_overrides: Variant=null, lake_offset: Vector2=Vector2.INF, lake_active: bool=true) -> Texture2D:
	var source: Dictionary=overrides() if terrain_overrides==null else (terrain_overrides if terrain_overrides is Dictionary else {})
	if lake_offset==Vector2.INF: lake_offset=FarmLayout.offset("lake");lake_active=FarmLayout.active("lake")
	# Preserve the reviewed baseline when no ground edit exists. Changed layouts use a
	# full rebuild, so filling or relocating the pond cannot leave its baked image behind.
	if source.is_empty() and lake_offset==Vector2.ZERO and lake_active:
		return load(ROOT+"derived/farm_ground_"+SchemeCAssets.SEASONS[season]+".png")
	var result:=Image.create(1536,1024,false,Image.FORMAT_RGBA8)
	var kinds: Dictionary={}
	for y in range(32):
		for x in range(48): kinds[Vector2i(x,y)]=_kind(Vector2i(x,y),source,lake_offset,lake_active)
	for y in range(32):
		for x in range(48):
			var cell:=Vector2i(x,y);var kind: String=str(kinds[cell]);var tile: Image
			var value: int=effective_index(cell,source,lake_offset,lake_active)
			if kind=="grass": tile=_ground_tile(value if value<3 else 0,season)
			elif kind=="water":
				tile=_ground_tile(6 if value==6 else 5,season).duplicate() as Image
				var bank: Image=_image("sand",season)
				for index_value in range(4):
					var direction: Vector2i=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][index_value]
					if str(kinds.get(cell+direction,""))=="water": continue
					var edge: Rect2i=[Rect2i(0,0,32,3),Rect2i(29,0,3,32),Rect2i(0,29,32,3),Rect2i(0,0,3,32)][index_value]
					tile.blit_rect(bank,edge,edge.position)
				# Six native pixels round exposed corners; the water remains entirely
				# inside the same blocking grid cells and keeps crisp binary edges.
				for pair in [[Vector2i.UP,Vector2i.LEFT,Vector2i.ZERO],[Vector2i.UP,Vector2i.RIGHT,Vector2i(31,0)],[Vector2i.DOWN,Vector2i.RIGHT,Vector2i(31,31)],[Vector2i.DOWN,Vector2i.LEFT,Vector2i(0,31)]]:
					if str(kinds.get(cell+Vector2i(pair[0]),""))=="water" or str(kinds.get(cell+Vector2i(pair[1]),""))=="water": continue
					var corner: Vector2i=pair[2]
					for cy in range(6):
						for cx in range(6):
							if Vector2(cx-5,cy-5).length_squared()<=25: continue
							var point:=Vector2i(cx if corner.x==0 else 31-cx,cy if corner.y==0 else 31-cy)
							tile.set_pixelv(point,bank.get_pixelv(point))
			else:
				var mask: int=0
				for index_value in range(8):
					var neighbor: String=str(kinds.get(cell+SchemeCTerrain.DIRECTIONS[index_value],""))
					if neighbor==kind or (kind=="dirt_path" and neighbor=="water"): mask|=1<<index_value
				tile=_tile("tilled_soil" if kind in ["soil","flowerbed"] else kind,season,mask)
			result.blit_rect(tile,Rect2i(0,0,32,32),cell*32)
	# Retain the baseline's native grass/flower scatter after an edit. Explicitly
	# painted cells stay clear, so one water edit does not erase every meadow detail.
	var protected: Array[Rect2i]=[Rect2i(16,7,10,8),Rect2i(8,9,6,6),Rect2i(16,14,13,10),Rect2i(29,13,12,11)]
	for counter in range(135):
		var cell:=Vector2i(2+(counter*17)%44,2+(counter*11)%28)
		if str(kinds.get(cell,""))!="grass" or source.has(TerritoryCatalog.key(cell)): continue
		var reserved: bool=false
		for rect in protected:
			if rect.has_point(cell): reserved=true;break
		if reserved: continue
		var art: String=["short_grass","clover","grass_clump","white_wildflowers","yellow_wildflowers"][counter%5]
		var herb: Image=_image(art,season)
		result.blend_rect(herb,Rect2i(Vector2i.ZERO,herb.get_size()),cell*32+Vector2i(16-herb.get_width()/2,18-herb.get_height()))
	return ImageTexture.create_from_image(result)
