extends "res://tests/runner.gd"
## Rendering-only load fixture; it does not add devices, crops or animals to player state.
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));game.hud.root.hide()
	var before:=JSON.stringify(AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game)))
	var layer:=CanvasLayer.new();layer.layer=20;add_child(layer)
	var background:=ColorRect.new();background.color=Color("8cba68");background.size=Vector2(1280,720);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(background)
	var heading:=FarmUIStyle.label("渲染压力夹具 · 120株作物 / 40台工作设备 / 18只动物精灵 / 96枚图标",22);heading.position=Vector2(20,10);layer.add_child(heading)
	var cache: Dictionary={};var crop_ids:=Catalog.crops.keys()
	for i in range(120):
		var crop: CropDefinition=Catalog.crops[crop_ids[i%crop_ids.size()]]
		if not cache.has(crop.texture_path): cache[crop.texture_path]=load(crop.texture_path)
		var texture:=AtlasTexture.new();texture.atlas=cache[crop.texture_path];texture.region=Rect2((i%4)*32,crop.atlas_row*40,32,40);texture.filter_clip=true
		var sprite:=Sprite2D.new();sprite.texture=texture;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.position=Vector2(36+i%15*32,80+i/15*40);layer.add_child(sprite)
	var station_ids: Array=HarvestCatalog.data().stations.keys()
	for i in range(40):
		var sprite:=AnimatedSprite2D.new();sprite.sprite_frames=WorkshopVisual.frames_for(str(station_ids[i%10]));sprite.animation="work";sprite.play("work");sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.position=Vector2(44+i%10*48,438+i/10*64);layer.add_child(sprite)
	var animal_textures: Dictionary={}
	for i in range(18):
		var id: String=["chicken","cow","sheep"][i%3]
		if not animal_textures.has(id): animal_textures[id]=load("res://assets/livestock/"+id+".png")
		var sprite:=Sprite2D.new();sprite.texture=animal_textures[id];sprite.hframes=2;sprite.frame=i%2;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.position=Vector2(724+i%6*48,110+i/6*40);layer.add_child(sprite)
	var item_ids: Array=HarvestCatalog.data().items.keys()+Catalog.crops.keys()
	for i in range(96):
		var sprite:=Sprite2D.new();sprite.texture=ItemPresentation.texture(str(item_ids[i%item_ids.size()]));sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.position=Vector2(716+i%16*32,300+i/16*32);layer.add_child(sprite)
	var note:=FarmUIStyle.label("桌面软件OpenGL测量；夹具不保存、不代表Android真机性能。",18);note.position=Vector2(700,550);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.size=Vector2(540,100);layer.add_child(note)
	for i in range(30): await RenderingServer.frame_post_draw
	var times: Array[float]=[]
	for i in range(180):
		var start: int=Time.get_ticks_usec();await RenderingServer.frame_post_draw;times.append(float(Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	check(cache.size()==31 and WorkshopVisual.cached_frames.size()==10,"大量作物和设备复用31张作物纹理、10份动画帧资源")
	check(JSON.stringify(AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game)))==before,"渲染压力夹具不修改玩家经济、队列或存档")
	get_viewport().get_texture().get_image().save_png("res://docs/quality081/render-stress.png")
	var file:=FileAccess.open("res://docs/quality081/performance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checked,"failures":failed,"fixture":"render-only actual game resources","crops":120,"animated_devices":40,"animal_sprites":18,"item_icons":96,"frames":times.size(),"median_wall_ms":times[times.size()/2],"p95_wall_ms":times[int(times.size()*.95)],"renderer":"desktop software OpenGL under Xvfb; fixed 1/60 logic step; measured wall render intervals","android_device_tested":false},"\t"));file.close()
	print("QUALITY081 RENDER STRESS RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();layer.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
