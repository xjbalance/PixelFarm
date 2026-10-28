extends "res://tests/runner.gd"
## Real runtime resources and preserved original services; no player save access.
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	var original:=FarmSaveStore.snapshot(game)
	check(SchemeCAssets.catalog().size()==97,"97项用户世界素材均进入运行目录")
	for id in SchemeCAssets.catalog():
		var info: Dictionary=SchemeCAssets.definition(id)
		var texture:=SchemeCAssets.texture(id)
		check(texture!=null and texture.get_size()==Vector2(info.size[0],info.size[1]),"原生素材尺寸可加载："+str(id))
		check(SchemeCAssets.offset(id)==Vector2(float(info.size[0])*.5-float(info.anchor[0]),float(info.size[1])*.5-float(info.anchor[1])),"保留源素材脚底锚点："+str(id))
		if int(info.frames)>1:
			var animation:=SchemeCAssets.animation(id)
			check(animation!=null and animation.get_frame_count("loop")==4 and animation.get_animation_loop("loop") and animation.get_animation_speed("loop")==4,"四帧动画真实接入："+str(id))
	var house: Sprite2D
	for node in game.get_children():
		if node is HouseExterior: house=node.house
	check(is_instance_valid(house),"新房屋仍绑定原房屋实体")
	var geometry: Array=[]
	for child in game.world.actors.get_children():
		if child.is_ancestor_of(house):
			geometry=child.find_children("*","CollisionShape2D",true,false)
	var collision_count:=geometry.size()
	var textures: Array=[]
	for level in range(1,5):
		var state:=Housing.defaults();state.level=level;state.builtins=HomeLayout.default_builtins(level);Housing.restore(state);await frames(4)
		check(house.texture.resource_path.ends_with("derived/exterior_%d.png" % level) and house.texture.get_size()==Vector2(192,168),"四级住宅新外观保持原画布和入口："+str(level))
		textures.append(hash(house.texture.get_image().get_data()))
	check(textures[0]!=textures[1] and textures[1]!=textures[2] and textures[2]!=textures[3],"四级房屋真实像素外观有区别")
	check(collision_count==1 and geometry.size()==collision_count,"换图不会复制房屋实体碰撞")
	check(game.world.ground.get_used_cells().size()==1536 and game.farm.BOUNDS==Rect2i(17,16,10,6),"原1536格地形和60格生产农田未改坐标或规模")
	for area in game.resource_world.fields:
		for object in game.resource_world.fields[area].objects.values():
			check(object.sprite.texture.resource_path.contains("/world_scheme_c/") and object.sprite.scale==Vector2.ONE,"新树石保留原生比例："+str(area)+"/"+str(object.resource_id))
	check(FarmSaveStore.restore(game,original),"新美术支持原完整存档恢复")
	await frames(5)
	check(FarmSaveStore.snapshot(game).plots==original.plots and FarmSaveStore.snapshot(game).resources==original.resources and Housing.snapshot()==original.housing,"美术接入保留农田、资源、家具和储物状态")
	check(FarmSaveStore.VERSION==26 and FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"仍为v26有效存档，没有因贴图升级丢失旧进度")
	print("WORLD ASSETS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
