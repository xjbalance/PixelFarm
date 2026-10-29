extends "res://tests/runner.gd"
## Run in a rendered Godot window: draw commands must retain valid textures
## after _draw returns, including on boards that redraw later in the season.
var output_dir: String="res://builds/festival-icons-after"
var captures: Array=[]

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Festival visual regression requires a rendered window")
		get_tree().quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir=arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(12);game.tutorial.restore(GameTutorial.defaults(true))
	var boards: Array=[]
	for id in Festival.IDS:
		var viewport:=SubViewport.new();viewport.size=Vector2i(128,112)
		viewport.transparent_bg=true;viewport.world_2d=World2D.new()
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
		var point:=Node2D.new();point.set_script(load("res://scripts/festivals/festival_point.gd"))
		point.festival_id=id;point.position=Vector2(64,80);viewport.add_child(point)
		boards.append({"id":id,"point":point,"viewport":viewport})
	await frames(5);await RenderingServer.frame_post_draw
	for board in boards:
		await verify_icon(board,"initial")
	GameClock.changed.emit();await frames(5);await RenderingServer.frame_post_draw
	for board in boards:
		await verify_icon(board,"redraw")
	game.change_location("farm",Vector2(656,480));game.auto_move.cancel()
	GameClock.minutes=720;GameClock.changed.emit();game.camera_rig.follow_now()
	await get_tree().create_timer(3.0).timeout;await frames(5)
	game.hud.toast_time=0;await RenderingServer.frame_post_draw
	var screenshot: String=output_dir+"/farm-bench.png"
	check(get_viewport().get_texture().get_image().save_png(screenshot)==OK,"保存真实农场窗口长椅及活动牌截图")
	captures.append(screenshot)
	var report:=FileAccess.open(output_dir+"/result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"platform":DisplayServer.get_name(),"captures":captures,"android_device_tested":false},"\t"));report.close()
	print("FESTIVAL VISUAL RESULT: %d checks, %d failures" % [checked,failed])
	for board in boards: board.viewport.queue_free()
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func verify_icon(board: Dictionary, phase: String) -> void:
	var rendered: Image=board.viewport.get_texture().get_image()
	# Decode PNG as CPU image so the check cannot accidentally keep the GPU
	# texture alive and hide a resource lifetime bug in the production draw code.
	var event: Dictionary=Festival.data.events[board.id]
	var source:=Image.new()
	source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/festivals/"+str(event.reward.items.keys()[0])+".png"))
	var matched: int=0
	var expected: int=0
	for y in range(24):
		for x in range(24):
			var texel:=Vector2((x+.5)*source.get_width()/24,(y+.5)*source.get_height()/24)
			var reference: Color=source.get_pixel(int(texel.x),int(texel.y))
			if reference.a<.99: continue
			# A 32px icon drawn at 24px hits exact texel boundaries. Exclude
			# GPU-dependent nearest-sampling ties; test unambiguous interiors.
			var stable: bool=true
			for dy in [-.01,.01]:
				for dx in [-.01,.01]:
					if not source.get_pixel(int(texel.x+dx),int(texel.y+dy)).is_equal_approx(reference): stable=false
			if not stable: continue
			expected+=1
			var actual: Color=rendered.get_pixel(52+x,37+y)
			if absf(actual.r-reference.r)<.08 and absf(actual.g-reference.g)<.08 and absf(actual.b-reference.b)<.08 and actual.a>.9: matched+=1
	check(expected>20 and matched==expected,"节日图标实际像素与源图一致：%s/%s（%d/%d）" % [board.id,phase,matched,expected])
	var path: String=output_dir+"/"+str(board.id)+"-"+phase+".png"
	check(rendered.save_png(path)==OK,"保存节日图标透明渲染证据："+str(board.id)+"/"+phase)
	captures.append(path)
