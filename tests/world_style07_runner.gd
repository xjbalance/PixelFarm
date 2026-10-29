extends "res://tests/runner.gd"
## 原尺寸/透明轮廓/真实Y排序与建筑角色同屏验收，不修改世界业务。
var capture_mode: bool=false
var before_mode: bool=false
var captures: Array=[]

func run() -> void:
	before_mode="--before" in OS.get_cmdline_user_args()
	capture_mode=capture_mode or before_mode
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));GameClock.minutes=720;GameClock.changed.emit();await frames(5)
	game.hud.toast_time=0;await frames(2)
	var original: Dictionary=FarmSaveStore.snapshot(game)
	if not before_mode: await art_invariants()
	await occlusion()
	await places()
	check(FarmSaveStore.restore(game,original),"材质及层次画面验证后原完整存档可恢复")
	var report:=FileAccess.open("res://builds/world-style07-"+("before" if before_mode else ("render" if capture_mode else "state"))+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"android_device_tested":false,"platform":DisplayServer.get_name()},"\t"));report.close()
	print("WORLD STYLE07 "+("BEFORE" if before_mode else ("RENDER" if capture_mode else "STATE"))+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func art_invariants() -> void:
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/ui/world_style07.json"))
	check(proof.assets.size()==14,"六套角色、四座既有建筑与四级住宅使用同一材质规范")
	for path in proof.assets:
		var baseline:=Image.new()
		var source: String="res://tools/art_sources/style07/"+str(path).trim_prefix("assets/")
		var error: Error=baseline.load_png_from_buffer(FileAccess.get_file_as_bytes(source))
		var texture: Texture2D=load("res://"+str(path))
		var output: Image=texture.get_image() if texture else Image.new()
		var loaded: bool=error==OK and not output.is_empty()
		check(loaded and baseline.get_size()==output.get_size(),"贴图和角色帧表原尺寸不变："+str(path))
		if not loaded: continue
		var alpha_same: bool=true;var changed: int=0
		for y in range(output.get_height()):
			for x in range(output.get_width()):
				var a: Color=baseline.get_pixel(x,y);var b: Color=output.get_pixel(x,y)
				alpha_same=alpha_same and a.a==b.a
				if a!=b: changed+=1
		check(alpha_same and changed>20,"材质确实更新且逐像素保留脚底、轮廓、旧阴影与动画占位："+str(path))
	check(game.player.get_node("Sprite2D").hframes==4 and game.player.get_node("Sprite2D").vframes==4,"角色原四方向十六帧布局保持不变")
	check(game.world.get_node("Actors").y_sort_enabled and game.village.get_node("Actors").y_sort_enabled and game.home.y_sort_enabled,"农场、村庄、室内继续按原脚底Y排序，不加假前景层")
	check(game.player.get_node("Sprite2D").texture_filter in [CanvasItem.TEXTURE_FILTER_PARENT_NODE,CanvasItem.TEXTURE_FILTER_NEAREST],"世界精灵保持清晰像素采样")

func image_now() -> Image:
	await frames(3);await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func occlusion() -> void:
	check(game.world.get_node("Actors").y_sort_enabled,"实际建筑与玩家共享Actors脚底排序空间")
	if DisplayServer.get_name()=="headless": return
	game.hud.root.hide();game.player.suspended=true
	var sprite: Sprite2D=game.player.get_node("Sprite2D");sprite.frame=0
	game.camera_rig.mode=game.camera_rig.Mode.FREE_LOOK;game.camera_rig.view_center=Vector2(656,370);game.camera_rig.apply_camera()
	for sample in [[Vector2(656,320),"behind",false],[Vector2(656,422),"front",true]]:
		game.player.global_position=sample[0];sprite.show();await frames(3)
		var shown: Image=await image_now()
		await capture("house_"+str(sample[1]))
		sprite.hide();var hidden: Image=await image_now();sprite.show()
		var at: Vector2=game.player.get_canvas_transform()*game.player.global_position
		var rect:=Rect2i(Vector2i(at-Vector2(24,64)),Vector2i(48,78)).intersection(Rect2i(Vector2i.ZERO,shown.get_size()))
		var difference: int=0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): difference+=1
		check((difference>20) if sample[2] else (difference==0),"真实像素遮挡："+("人物在建筑前方自然显示" if sample[2] else "人物走到屋后由屋顶正常遮挡"))
	game.player.suspended=false;game.hud.root.show();game.camera_rig.follow_now()

func places() -> void:
	for sample in [["farm",Vector2(656,440),"farm_home"],["farm",Vector2(360,450),"farm_market"],["village",Vector2(392,454),"village_people"],["home",Vector2(640,500),"home_people"]]:
		game.change_location(sample[0],sample[1]);await frames(7)
		check(GameState.location==sample[0] and game.player.position.distance_to(sample[1])<1,"外观更新不挪动实际角色或地图坐标："+str(sample[2]))
		await capture(str(sample[2]))
	game.change_location("farm",Vector2(656,440));await frames(5)

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/world-style07-"+("before-" if before_mode else "after-")+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
