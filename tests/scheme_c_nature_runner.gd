extends "res://tests/runner.gd"
## Actual scene art integration, native-size terrain masks and unchanged gameplay state.
@export var capture_mode: bool=false
var captures: Array=[]

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	GameClock.minutes=720;GameClock.changed.emit();await frames(3)
	game.tutorial.restore(GameTutorial.defaults(true))
	var original: Dictionary=FarmSaveStore.snapshot(game)
	await native_assets()
	await crown_hit_regions()
	await seasonal_maps()
	await real_terrain()
	check(FarmSaveStore.restore(game,original),"自然美术验证后原完整经营快照仍可恢复")
	await frames(5)
	check(game.farm.plots==original.plots and game.resource_world.snapshot()==original.resources,"自然素材替换未改变作物与全部128节点耐久、再生时间")
	check(Housing.snapshot()==original.housing and Xiaojing.snapshot()==original.xiaojing,"自然素材替换未改变住宅或小京状态")
	var report:=FileAccess.open("res://builds/scheme-c-nature-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));report.close()
	print("SCHEME C NATURE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func native_assets() -> void:
	var masks: Dictionary={}
	for mask in range(256): masks[SchemeCTerrain.normalize_mask(mask)]=true
	check(masks.size()==47,"八邻接掩码规范化恰好得到提供素材中的47种连接形状")
	for season in range(4):
		var atlas: Texture2D=load("res://assets/world_scheme_c/derived/ground_"+SchemeCAssets.SEASONS[season]+".png")
		var water: Image=atlas.get_image().get_region(Rect2i(160,0,32,32))
		var seamless: bool=true
		for pixel in range(32):
			seamless=seamless and water.get_pixel(0,pixel)==water.get_pixel(31,pixel) and water.get_pixel(pixel,0)==water.get_pixel(pixel,31)
		check(seamless,"水面相邻纹理两侧逐像素配对，无方形瓦片接缝："+str(season))
	for material in ["dirt","tilled_soil","sand","gravel","dirt_path","stone_path","wood_path"]:
		for season in range(4):
			var valid: bool=true
			for mask in masks:
				var tile: Texture2D=SchemeCTerrain.tile(material,season,mask)
				valid=valid and tile is AtlasTexture and tile.get_size()==Vector2(32,32) and tile.atlas.resource_path.contains("world_scheme_c/seasons/")
			check(valid,"原生32像素连接图块完整："+material+" / "+str(season))
	var resources: Dictionary=game.resource_world.snapshot()
	check(resources.size()==128,"全部旧采集ID保持128项，不以观赏树替换业务节点")
	for area in ["farm","village","mist_forest"]:
		var field: Node=game.resource_world.fields[area]
		var valid: bool=true
		for node in field.objects.values():
			var texture: Texture2D=node.sprite.texture
			var art: String=str(node.art_id)
			valid=valid and texture.resource_path.contains("/world_scheme_c/") and node.sprite.scale==Vector2.ONE and node.sprite.position==SchemeCAssets.offset(art)
			var size: Array=SchemeCAssets.definition(art).size
			valid=valid and texture.get_size()==Vector2(size[0],size[1]) and node.collider.shape.size==(Vector2(22,19) if node.kind=="tree" else Vector2(30,16))
		check(valid,"树石采用源像素大小与脚底锚点，旧碰撞形状未改："+area)
	check(game.world.get_node("GroundDetail06").trees.size()==30,"农场30棵采集树全部接入，不遗留旧树贴图")

func crown_hit_regions() -> void:
	var wide_found: bool=false
	var gap_found: bool=false
	var old_rect:=Rect2(-25,-80,50,96)
	for id in ["tree_29_11","tree_27_8","tree_37_6","tree_41_13","tree_40_23"]:
		var node: Node=game.resource_world.fields.farm.objects[id]
		var source: Image=node.sprite.texture.get_image()
		var rect: Rect2=node.sprite.get_rect()
		for y in range(0,source.get_height(),3):
			for x in range(0,source.get_width(),3):
				var point: Vector2=node.sprite.to_global(rect.position+Vector2(x,y))
				var offset: Vector2=point-node.global_position
				if old_rect.has_point(offset): continue
				var resolved: Dictionary=TouchInteractionResolver.resolve(game,point)
				if source.get_pixel(x,y).a>.5 and resolved.get("kind","")=="resource" and resolved.get("object")==node:
					wide_found=true
				if source.get_pixel(x,y).a==0 and resolved.get("kind","") in ["ground","plot"]:
					gap_found=true
				if wide_found and gap_found: break
			if wide_found and gap_found: break
		if wide_found and gap_found: break
	check(wide_found,"新宽树冠超出旧命中框的可见像素仍正确选中同一采集树")
	check(gap_found,"树冠画布的透明间隙继续命中真实世界，不成为矩形触控遮挡")

func cell_state(ground: TileMapLayer) -> Dictionary:
	var result: Dictionary={}
	for cell in ground.get_used_cells():
		var data: TileData=ground.get_cell_tile_data(cell)
		result[TerritoryCatalog.key(cell)]=[ground.get_cell_source_id(cell),ground.get_cell_atlas_coords(cell),data.get_collision_polygons_count(0)]
	return result

func seasonal_maps() -> void:
	var farm_before: Dictionary=cell_state(game.world.ground)
	var village_before: Dictionary=cell_state(game.village.ground)
	var forest: Node=game.mine_maps.mist_forest
	var forest_before: Dictionary=cell_state(forest.ground)
	var resources_before: Dictionary=game.resource_world.snapshot()
	for season in range(4):
		GameClock.day=season*28+1;Calendar.restore(Calendar.snapshot());GameClock.changed.emit();await frames(5)
		var name: String=SchemeCAssets.SEASONS[season]
		var visual: Node=game.world.get_node("GroundDetail06")
		check(visual.applied_season==season and visual.ground_detail.texture.resource_path.ends_with("farm_ground_"+name+".png") and visual.ground_detail.texture.get_size()==Vector2(1536,1024),"农场整图采用对应季节的源素材组合："+name)
		check(cell_state(game.world.ground)==farm_before and cell_state(game.village.ground)==village_before and cell_state(forest.ground)==forest_before,"三图换季逐格保留原地形类型与碰撞："+name)
		check(game.resource_world.snapshot()==resources_before,"换季不提前再生或收获资源："+name)
		var valid: bool=true
		for area in ["farm","village","mist_forest"]:
			for node in game.resource_world.fields[area].objects.values():
				if node.kind=="tree": valid=valid and node.sprite.texture.resource_path.contains("/seasons/"+name+"/")
		check(valid,"全部85棵资源树同步季节配色："+name)
		var atlas: TileSetAtlasSource=forest.ground.tile_set.get_source(0)
		check(atlas.texture.resource_path.ends_with("forest_ground_"+name+".png"),"只更新森林地表材质，未替换地下场景："+name)
		game.change_location("farm",Vector2(656,470));await frames(5);await capture("farm_"+name)
	for area in ["village","mist_forest"]:
		game.change_location(area,Vector2(640,480));await frames(5);await capture(area)
	game.change_location("farm",Vector2(656,440));await frames(5)

func real_terrain() -> void:
	load("res://tests/star_runner.gd").fixture(game,false);Territory.refresh_unlocks(false)
	game.change_location("east_holding",Vector2(640,800));await frames(6)
	check(game.territory_editor.open(),"源地表验证先进入真实建造模式")
	await frames(3)
	for index in range(9):
		var kind: String=["soil","grass","dirt_path","stone_path","wood_path","flowerbed","natural","sand","gravel"][index]
		var plan: Dictionary=Territory.plan_terrain("east_holding",[Vector2i(5+index,12),Vector2i(5+index,13)],kind)
		check(plan.valid and Territory.apply_plan(plan),"真实领地确认使用同一素材地表："+kind)
		await frames(3)
	var surface: Node=game.territory_world.surfaces.east_holding
	check(surface is TerritorySurface and surface.cells.get("7,12")=="dirt_path" and surface.cells.get("9,13")=="wood_path","实际叠加层保持格坐标与道路类型")
	await capture("source_terrain_paths")
	game.territory_editor.cancel()

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(5);await RenderingServer.frame_post_draw
	var path: String="res://builds/scheme-c-nature-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
