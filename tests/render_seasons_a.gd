extends "res://tests/runner.gd"
## 实窗口四季与九天气呈现；验证原tile结构/设施/点击，不代表Android真机。
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true
	await frames(6)
	load("res://tests/star_runner.gd").fixture(game,true)
	Aquaculture.restore(Aquaculture.defaults(GameClock.day))
	Inventory.coins=10000;Inventory.items.wood=100;Inventory.items.stone=100
	await Touch.place(self,game,"farm",Vector2(912,592))
	Aquaculture.build("pen_1")
	var surfaces := get_tree().get_nodes_in_group("season_landscapes")
	check(surfaces.size()==1,"主场景只挂一份季节呈现协调器")
	var seasonal_textures := {}
	var features: Dictionary=WorldChanges.features().duplicate(true)
	for day in [225,253,281,309]:
		GameClock.day=day;GameClock.minutes=720
		Calendar.restore(Calendar.snapshot(day));GameClock.changed.emit();await frames(5)
		if not surfaces.is_empty(): check(surfaces[0].applied_season==Calendar.season(),"世界纹理切换到当前季节："+str(Calendar.season()))
		for map_id in ["farm","village"]:
			game.change_location(map_id,Vector2(912,592) if map_id=="farm" else Vector2(640,756));await frames(5)
			var map: Node=game.world if map_id=="farm" else game.village
			var tilemap: TileMapLayer=map.get_node("Ground")
			var atlas: TileSetAtlasSource=tilemap.tile_set.get_source(0)
			seasonal_textures[atlas.texture.resource_path]=true
			check(tilemap.get_used_cells().size()==(1536 if map_id=="farm" else 1120) and tilemap.tile_set.get_source_count()==1,"换季保留真实TileMap格数与source布局："+map_id)
			check(atlas.get_tile_data(Vector2i(5,0),0).get_collision_polygons_count(0)==1 and atlas.get_tile_data(Vector2i(6,0),0).get_collision_polygons_count(0)==1,"四季水格保持原碰撞边界："+map_id)
			check(WorldChanges.features()==features,"季节装饰不抹去已建世界变化："+map_id)
			if map_id=="farm": get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070a-"+Calendar.SEASON_IDS[Calendar.season()]+".png")
	check(seasonal_textures.size()==4,"实际地图使用四套独立季节纹理资源")
	var weather_layer: Control
	for node in game.find_children("*","Control",true,false):
		if node.get_script()==load("res://scripts/presentation/weather_screen.gd"): weather_layer=node;break
	check(weather_layer!=null and weather_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"天气效果不捕获UI或地图触点")
	var dates := {}
	for day in range(29,449):
		var id: String=Calendar.predicted_weather(day)
		if not dates.has(id): dates[id]=day
	game.change_location("farm",Vector2(880,560))
	for id in dates:
		GameClock.day=dates[id];GameClock.minutes=1260
		Calendar.restore(Calendar.snapshot(GameClock.day));GameClock.changed.emit()
		GameClock.running=true;await frames(4);GameClock.running=false
		check(GameWeather.weather_id()==id,"真实窗口绘制天气分支："+id)
	if weather_layer:
		var animation_time: float=weather_layer.time
		weather_layer._process(10)
		check(weather_layer.time==animation_time,"后台停止时天气动画时钟不继续快进")
		GameClock.running=true;GameState.set_modal(true)
		weather_layer._process(10)
		check(weather_layer.time==animation_time,"模态阅读时雪雨动画暂停，避免后台积累")
		GameState.set_modal(false);GameClock.running=false
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		check(game.hud.safe.get_global_rect().encloses(game.hud.clock_label.get_global_rect()),"年月季日与天气HUD适配横屏："+str(resolution))
		await Touch.place(self,game,"farm",Vector2(880,560))
		Touch.tap(self,game,Vector2(944,580));await Touch.finish(self,game,500)
		check(game.hud.aquaculture_panel.visible and Aquaculture.near_pen("pen_1"),"季节地表和天气叠加后原湖栏触点仍能靠岸："+str(resolution))
		game.hud.close_active_panel()
	print("RENDER SEASONS A RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
