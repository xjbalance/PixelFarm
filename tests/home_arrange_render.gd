extends "res://tests/runner.gd"
## 真窗口中从房间管理入口选择家具、原生点地图预览及确认；不以列表坐标代替。
const Touch=preload("res://tests/touch_navigation.gd")
const Arrange=preload("res://tests/home_arrange_runner.gd")
var captures: Array=[]
var native_map_taps: int=0
var native_map_drags: int=0

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.items={"wood":999,"stone":999,"carrot":20,"potato":10};Inventory.coins=100000;Xiaojing.state.diamonds=1314
	Inventory.changed.emit();GameState.changed.emit();GameClock.changed.emit()
	game.change_location("home",Vector2(640,500));await frames(8);await capture("before")
	for id in ["bed","sofa","kitchen","storage"]:
		var previous: Vector2=Housing.anchor(Arrange.CRITICAL[id]);var cell:=Arrange.find_cell(id,128)
		check(cell.x>=0,"窗口家具存在实际合法新位置："+id)
		if cell.x<0: continue
		check(await start_from_ui(id),"通过原管理台UI原生选择移动家具："+id)
		if not game.home_arrange.active: continue
		cell=Arrange.visible_cell(game,id,128)
		check(cell.x>=0,"实际布置操作栏打开后仍有可见且不被UI挡住的合法格："+id)
		if cell.x<0: game.home_arrange.cancel();continue
		var before: Dictionary=Housing.snapshot();var items: Dictionary=Inventory.items.duplicate(true);var stamina: int=GameState.stamina
		var world: Vector2=game.home_arrange.world_for_cell(cell)
		if id=="sofa": check(await map_drag(id,cell),"原生拖动实际沙发到新落点，抓取偏移跟随手势")
		else: check(await map_tap(world),"原生地图触点选择新家具落点："+id)
		check(game.home_arrange.preview_cell==cell and game.home_arrange.preview_valid and Housing.snapshot()==before and Inventory.items==items and GameState.stamina==stamina,"可见预览与地图格一致，提交前不改变布局或资源："+id)
		await capture(id+"_preview")
		if id=="bed":
			await control_tap(game.home_arrange.cancel_button)
			check(not game.home_arrange.active and Housing.snapshot()==before,"窗口原生取消保留原床位置")
			check(await start_from_ui(id),"取消后可从同一入口重新布置床")
			check(await map_tap(Vector2(936,400)) and not game.home_arrange.preview_valid,"窗口非法墙外预览不能提交")
			await capture("invalid_preview")
			check(await map_tap(world) and game.home_arrange.preview_valid,"原生新点击可从非法位置恢复合法预览")
		await control_tap(game.home_arrange.confirm_button);await frames(8)
		check(not game.home_arrange.active and Arrange.geometry(id).cell==cell and Housing.anchor(Arrange.CRITICAL[id]).distance_to(previous)>=128,"原生确认后实际家具与功能位置同步："+id)
		var resolved: Dictionary=TouchInteractionResolver.resolve(game,previous)
		check(resolved.get("object")!=Arrange.action_point(game,Arrange.CRITICAL[id]),"旧位置不再选中移动后的原功能："+id)
		if id=="bed": GameClock.minutes=1200;GameClock.changed.emit()
		var old_screen: Vector2=game.player.get_canvas_transform()*previous
		var old_click_visible: bool=get_viewport().get_visible_rect().grow(-8).has_point(old_screen) and not game.touch_input.ui_at(old_screen)
		check(old_click_visible,"旧功能位置也在真实窗口中接受原生反向验收："+id)
		if old_click_visible:
			Touch.tap(self,game,previous);await Touch.finish(self,game,1200);await frames(4)
			check(not GameState.modal,"窗口真正点击旧位置不再打开搬走的功能："+id)
			while game.hud.close_active_panel(): pass
		await capture(id+"_after")
		if id=="bed":
			GameClock.minutes=1200;GameClock.changed.emit()
			check(await Arrange.click_function(self,game,id,"sleep") and game.hud.system_panel.visible,"窗口点击新床真正打开原睡眠确认")
			var day: int=GameClock.day
			await control_tap(game.hud.system_panel.actions.get_child(0));await frames(5)
			check(GameClock.day==day+1 and GameClock.minutes==360,"窗口新床原生确认后正常只结算一日")
		elif id=="sofa":
			GameState.stamina=1;GameClock.minutes=600;GameState.changed.emit();GameClock.changed.emit()
			check(await Arrange.click_function(self,game,id,"sofa") and game.home_rest.panel.visible,"窗口点击新沙发实际开启小睡")
			await control_tap(game.home_rest.confirm_button);await frames(25)
			check(GameClock.minutes==660 and GameState.stamina==1+ceili(GameState.max_stamina()*.5),"新沙发原生确认恢复体力并推进原一小时")
		elif id=="kitchen":
			check(await Arrange.click_function(self,game,id,"kitchen") and game.hud.kitchen_panel.visible,"窗口新厨房点击开启实际料理")
			var dish:=find_button(game.hud.kitchen_panel,"制作暖锅蔬菜炖")
			check(dish!=null,"窗口厨房保留原料理制作按钮")
			if dish:
				await control_tap(dish)
				await control_tap(find_button(game.hud.kitchen_panel,"确认"))
			check(Inventory.count("carrot_stew")==1,"移动厨房通过真实料理按钮制作一份成品")
			game.hud.kitchen_panel.close_panel()
		else:
			check(await Arrange.click_function(self,game,id,"storage") and game.hud.housing_panel.visible,"新收纳台原生点击正常打开存取管理")
			game.hud.housing_panel.close_panel()
	game.change_location("home",Housing.anchor("storage")+Vector2(0,36));await frames(6)
	check(Housing.buy("chair"),"窗口从原有资源真实制作一把自制椅子")
	var custom_economy: Dictionary={"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":int(Xiaojing.state.diamonds)}
	game.hud.housing_panel.open_panel("home");await frames(5)
	var owned_button:=find_button(game.hud.housing_panel,"摆放"+str(Housing.data.furniture.chair.name))
	check(owned_button!=null,"原房间列表有已拥有家具的真实摆放入口")
	if owned_button: await control_tap(owned_button)
	if game.home_arrange.active:
		var custom_cell:=visible_custom_cell("chair")
		check(custom_cell.x>=0 and await map_tap(game.home_arrange.world_for_cell(custom_cell)) and game.home_arrange.preview_valid,"自制家具通过真实地图触点选择空位预览")
		await control_tap(game.home_arrange.confirm_button);await frames(5)
		check(Housing.state.placed.size()==1 and int(Housing.state.owned.get("chair",0))==0,"窗口确认只摆出一把已拥有的自制椅子")
		await capture("crafted_placed")
		if Housing.state.placed.size()==1:
			var custom: Dictionary=Housing.state.placed[0].duplicate(true);var serial: int=Housing.state.serial
			game.change_location("home",Housing.anchor("storage")+Vector2(0,36));await frames(5)
			game.hud.housing_panel.open_panel("home");await frames(4)
			var moved_button:=custom_button(game.hud.housing_panel,str(custom.id))
			check(moved_button!=null,"已摆椅子按稳定家具ID提供真实移动按钮")
			if moved_button: await control_tap(moved_button)
			custom_cell=visible_custom_cell("chair",str(custom.id),Vector2i(custom.cell[0],custom.cell[1]))
			check(game.home_arrange.active and custom_cell.x>=0 and await map_tap(game.home_arrange.world_for_cell(custom_cell)) and game.home_arrange.preview_valid,"自制椅子也能原生点地图选择第二个位置")
			await control_tap(game.home_arrange.confirm_button);await frames(5)
			check(Housing.state.placed.size()==1 and Housing.state.placed[0].id==custom.id and Housing.state.placed[0].cell==[custom_cell.x,custom_cell.y] and Housing.state.serial==serial,"窗口移动自制椅子保留原ID和序号，不复制家具")
			check(Inventory.items==custom_economy.items and Inventory.coins==custom_economy.coins and int(Xiaojing.state.diamonds)==custom_economy.diamonds,"自制家具地图放置与移动不重复扣制作资源或钻石")
			await capture("crafted_moved")
	check(await Arrange.approach(self,game,"sofa"),"窗口备用模式前实走到新沙发")
	GameState.set_control_mode("joystick",false);await frames(3);game.action_cooldown=0
	var sofa_point:=Arrange.action_point(game,"sofa")
	if is_instance_valid(sofa_point): game.player.facing=(sofa_point.global_position-game.player.global_position).normalized()
	var action: Control=game.hud.action_button;await control_tap(action)
	check(game.hud.joystick.visible and game.home_rest.panel.visible,"备用摇杆模式原生交互按钮仍打开搬迁后的沙发")
	game.home_rest.close_panel();GameState.set_control_mode("tap",false)
	for size in [Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(5);game.hud.update_safe_area();await frames(4)
		check(await start_from_ui("sofa"),"不同横屏比例可从原入口进入布置："+str(size))
		var panel: Control=game.home_arrange.panel
		check(game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),"布置操作栏完整处于安全区："+str(size))
		await capture("layout_"+str(size.x)+"x"+str(size.y));await control_tap(game.home_arrange.cancel_button)
	check(native_map_taps>=7 and native_map_drags>=1 and FarmSaveStore.valid(FarmSaveStore.snapshot(game)) and Xiaojing.state.diamonds==1314,"窗口多次真实地图触点保持存档与婚礼钻石安全")
	var file:=FileAccess.open("res://builds/home-arrange-render-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":DisplayServer.get_name(),"android_device_tested":false,"native_map_taps":native_map_taps,"native_map_drags":native_map_drags,"captures":captures,"checks":checked,"failures":failed},"\t"));file.close()
	print("HOME ARRANGE RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func find_button(root: Node, caption: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text.contains(caption): return child
		var found:=find_button(child,caption)
		if found: return found
	return null

func control_tap(control: Control) -> void:
	if not is_instance_valid(control): check(false,"窗口需要的真实控件存在");return
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(3)
	var point: Vector2=control.get_global_rect().get_center()
	check(game.hud.safe.get_global_rect().has_point(point),"原生UI点击点位于安全区")
	Touch.finger(self,point,true,471);Touch.finger(self,point,false,471);await frames(4)

func builtin_button(root: Node, id: String) -> Button:
	var exact:=builtin_button_id(root,id)
	if exact: return exact
	var names: Array={"bed":["原木床","床"],"sofa":["田园沙发","沙发"],"kitchen":["小屋厨房","厨房"],"storage":["储物柜","收纳"]}.get(id,[id])
	for name in names:
		for child in root.get_children():
			if child is Button and child.text.contains("移动") and child.text.contains(name): return child
			var found:=builtin_button_match(child,str(name))
			if found: return found
	return null

func builtin_button_id(root: Node, id: String) -> Button:
	for child in root.get_children():
		if child is Button and child.get_meta("home_builtin_id","")==id: return child
		var found:=builtin_button_id(child,id)
		if found: return found
	return null

func builtin_button_match(root: Node, name: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text.contains("移动") and child.text.contains(name): return child
		var found:=builtin_button_match(child,name)
		if found: return found
	return null

func start_from_ui(id: String) -> bool:
	while game.hud.close_active_panel(): pass
	game.change_location("home",Housing.anchor("storage")+Vector2(0,36));await frames(6)
	game.hud.housing_panel.open_panel("home");await frames(5)
	var button:=builtin_button(game.hud.housing_panel,id)
	if button==null:
		var entry:=find_button(game.hud.housing_panel,"直接在房间里布置")
		if entry: await control_tap(entry)
		button=builtin_button(game.home_arrange.panel,id)
	if button==null: return false
	await control_tap(button)
	return game.home_arrange.active

func custom_button(root: Node, id: String) -> Button:
	for child in root.get_children():
		if child is Button and child.get_meta("home_custom_id","")==id: return child
		var found:=custom_button(child,id)
		if found: return found
	return null

func visible_custom_cell(kind: String, except_id: String="", old: Vector2i=Vector2i(-1,-1)) -> Vector2i:
	for region in HomeLayout.placement_regions(int(Housing.state.level)):
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var cell:=Vector2i(x,y)
				if old.x>=0 and cell.distance_to(old)<2: continue
				if not Housing.can_place(kind,"home",cell,except_id): continue
				var world: Vector2=game.home_arrange.world_for_cell(cell)
				var screen: Vector2=game.player.get_canvas_transform()*world
				if get_viewport().get_visible_rect().grow(-8).has_point(screen) and not game.touch_input.ui_at(screen): return cell
	return Vector2i(-1,-1)

func map_tap(world: Vector2) -> bool:
	var screen: Vector2=game.player.get_canvas_transform()*world
	if not get_viewport().get_visible_rect().grow(-8).has_point(screen) or game.touch_input.ui_at(screen): return false
	var before: Vector2=game.player.global_position
	Touch.finger(self,screen,true,472);Touch.finger(self,screen,false,472);await frames(5);native_map_taps+=1
	return game.player.global_position==before and game.auto_move.target.is_empty()

func map_drag(id: String, cell: Vector2i) -> bool:
	var source:=Arrange.gesture_grab_point(game,id)
	if source==Vector2.INF: return false
	var from: Vector2=game.player.get_canvas_transform()*source
	var player: Vector2=game.player.global_position
	Touch.finger(self,from,true,473);await frames(1)
	# 非中心抓取后才读取controller的offset，保证真正把同一cell拖到目标处。
	var to: Vector2=game.player.get_canvas_transform()*game.home_arrange.world_for_cell(cell)
	if not get_viewport().get_visible_rect().grow(-8).has_point(to) or game.touch_input.ui_at(to):
		Touch.finger(self,from,false,473);return false
	Arrange.screen_drag(self,from,to,473);await frames(2)
	Touch.finger(self,to,false,473);await frames(5);native_map_drags+=1
	return game.player.global_position==player and game.auto_move.target.is_empty()

func capture(label: String) -> void:
	GameClock.changed.emit();GameState.changed.emit();game.hud.toast_time=0
	await get_tree().create_timer(2.9).timeout
	await RenderingServer.frame_post_draw
	var path: String="res://builds/home-arrange-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"level":Housing.state.level,"day":GameClock.day,"resolution":[get_window().size.x,get_window().size.y]})
