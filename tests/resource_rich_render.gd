extends "res://tests/runner.gd"
## 原生窗口触点与真实采集，不把离屏输入或桌面帧率声称为手机验收。
const Touch=preload("res://tests/touch_navigation.gd")
const Rich=preload("res://tests/resource_rich_runner.gd")
var captures: Array=[]
var all_taps_visible: bool=true

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.items={"wood":1,"stone":1};Xiaojing.state.diamonds=1314
	load("res://tests/mining.gd").fresh_chapter(game);Calendar.restore(Calendar.snapshot());GameState.rest()
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(5)
		for area in ["farm","village","mist_forest"]:
			await Rich.visit(self,game,area)
			var field: Node2D=game.resource_world.fields[area]
			check(field.is_visible_in_tree() and field.objects.size()==FarmResourceCatalog.placements(area).size(),"窗口存在完整实体资源而非文字列表："+area+str(resolution))
			for kind in ["tree","rock"]:
				var sample: Dictionary=await Rich.visible_resource(self,game,area,kind)
				var id: String=str(sample.get("id",""))
				check(id!="" and await Rich.approach_resource(self,game,area,id),"窗口先实走到资源，不离屏冒充点击："+area+kind)
				if id=="": continue
				var object: Node2D=field.objects[id];var world: Vector2=Rich.visible_click_point(game,object)
				await frames(8)
				var screen: Vector2=game.player.get_canvas_transform()*world
				var visible_target: bool=get_viewport().get_visible_rect().grow(-8).has_point(screen) and not game.touch_input.ui_at(screen)
				all_taps_visible=all_taps_visible and visible_target
				check(visible_target,"资源原生触点实际可见且不受UI遮挡："+id+str(resolution))
				if not visible_target: continue
				GameState.manual_tool=false;GameState.rest()
				var hp: int=field.state[id].hp;var calls: int=game.auto_move.execution_count
				Touch.tap(self,game,world);await Touch.finish(self,game);await frames(20)
				check(field.state[id].hp==hp-1 and game.auto_move.execution_count==calls+1 and game.player.auto_direction==Vector2.ZERO,"窗口真实点树石后只采一下并准确停止："+id)
			await capture(area+"_"+str(resolution.x)+"x"+str(resolution.y))
	await Rich.visit(self,game,"mist_forest")
	for id in ["forest_order","forest_spring","forest_summer","forest_autumn","forest_winter"]:
		var point: Node2D=game.mine_maps.mist_forest.objects[id]
		game.auto_move.request_target({"kind":"object","object":point,"point":point.global_position});await Touch.finish(self,game,2400)
		while game.hud.close_active_panel(): pass
		check(Exploration.near_id(id) and (Exploration.read(id) if id=="forest_order" else Exploration.operate(id)),"资源林窗口仍按原谜题实走开门："+id)
	await frames(5);game.auto_move.navigation.rebuild()
	check(Exploration.state.forest.open,"窗口森林扩充后原四步机关仍正常完成")
	await capture("forest_open")
	var field: Node2D=game.resource_world.fields.mist_forest
	var tree:=Rich.first_resource(game,"mist_forest","tree")
	if tree!="":
		check(await Rich.approach_resource(self,game,"mist_forest",tree),"窗口备用操作前实走近资源")
		GameState.select_tool(GameState.tools.find("axe"));GameState.set_control_mode("joystick",false)
		game.player.facing=(field.objects[tree].global_position-game.player.global_position).normalized();await frames(4)
		var hp: int=field.state[tree].hp;var button: Control=game.hud.action_button;var p: Vector2=button.get_global_rect().get_center()
		Touch.finger(self,p,true,458);Touch.finger(self,p,false,458);await frames(20)
		check(field.state[tree].hp==hp-1 and game.hud.joystick.visible,"窗口备用摇杆模式原生动作按钮能砍同一森林树")
	check(all_taps_visible,"所有资源地图触点均在实际窗口且不穿透UI")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)) and Xiaojing.state.diamonds==1314,"窗口资源扩充与原完整存档及钻石状态保持兼容")
	var file:=FileAccess.open("res://builds/resource-rich-render-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":DisplayServer.get_name(),"android_device_tested":false,"captures":captures,"checks":checked,"failures":failed},"\t"));file.close()
	print("RESOURCE RICH RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://builds/resource-rich-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"location":GameState.location,"resource_nodes":game.resource_world.active_field().objects.size(),"resolution":[get_window().size.x,get_window().size.y]})
