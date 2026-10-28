extends "res://tests/runner.gd"
## 原房间家具布局、移动后的实际功能与预览事务；仅用外部隔离用户目录。
const Touch=preload("res://tests/touch_navigation.gd")
const Home=preload("res://tests/home05_runner.gd")
const CRITICAL: Dictionary={"bed":"sleep","sofa":"sofa","kitchen":"kitchen","storage":"storage","mail_desk":"mail"}
var initial: Dictionary

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	if "--editor-only" in OS.get_cmdline_user_args():
		await editor_transactions()
	elif "--gesture-only" in OS.get_cmdline_user_args():
		await native_gestures()
	elif "--migration-only" in OS.get_cmdline_user_args():
		await migration_and_construction()
	else:
		await defaults_and_moves()
		await editor_transactions()
		await crafted_editor()
		await native_gestures()
		await dynamic_functions()
		await migration_and_construction()
	print("HOME ARRANGE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

static func legacy_v23(raw: Dictionary) -> Dictionary:
	var old: Dictionary=raw.duplicate(true);old.erase("builtins");return old

static func disk_snapshot(owner_game: Node) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(FarmSaveStore.snapshot(owner_game))))

static func geometry(id: String) -> Dictionary:
	return Housing.builtin_geometry(id)

static func find_cell(id: String, minimum_distance: float=112.0) -> Vector2i:
	var original: Dictionary=geometry(id)
	if original.is_empty(): return Vector2i(-1,-1)
	var region: Rect2i=HomeLayout.navigation_region(int(Housing.state.level))
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell:=Vector2i(x,y)
			var delta: Vector2=Vector2(cell-original.cell)*32
			if delta.length()<minimum_distance: continue
			if Housing.can_move_builtin(id,cell,true): return cell
	return Vector2i(-1,-1)

static func visible_cell(owner_game: Node, id: String, minimum_distance: float=112.0) -> Vector2i:
	var original: Dictionary=geometry(id)
	if original.is_empty(): return Vector2i(-1,-1)
	var region: Rect2i=HomeLayout.navigation_region(int(Housing.state.level))
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell:=Vector2i(x,y)
			if Vector2(cell-original.cell).length()*32<minimum_distance or not Housing.can_move_builtin(id,cell,true): continue
			var world: Vector2=owner_game.home_arrange.world_for_cell(cell) if owner_game.home_arrange.active else Vector2(cell)*32+Vector2(16,16)
			var screen: Vector2=owner_game.player.get_canvas_transform()*world
			if owner_game.get_viewport().get_visible_rect().grow(-8).has_point(screen) and not owner_game.touch_input.ui_at(screen): return cell
	return Vector2i(-1,-1)

static func action_point(owner_game: Node, action: String) -> Node2D:
	var anchor: Vector2=Housing.anchor(action)
	for point in owner_game.get_tree().get_nodes_in_group("interactables"):
		if not point.is_visible_in_tree() or not owner_game.home.is_ancestor_of(point): continue
		if point.global_position.distance_to(anchor)>.5: continue
		if action=="sleep" and "home_action" in point and point.home_action=="sleep": return point
		if action in ["sofa","nap"] and "home_action" in point and point.home_action=="nap": return point
		if action=="kitchen" and "kitchen_id" in point and point.kitchen_id=="kitchen": return point
		if action=="storage" and "housing_id" in point and point.housing_id=="home": return point
		if action=="mail" and "actor_id" in point and point.actor_id=="mail": return point
		if action=="exit" and "kind" in point and point.kind=="exit": return point
	return null

static func approach(test: Node, owner_game: Node, action: String) -> bool:
	while owner_game.hud.close_active_panel(): pass
	GameState.set_control_mode("tap",false)
	var point:=action_point(owner_game,action)
	if not is_instance_valid(point): return false
	owner_game.auto_move.navigation.rebuild()
	var path: PackedVector2Array=owner_game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position})
	if path.is_empty(): return false
	owner_game.auto_move.request_target({"kind":"ground","point":path[-1]})
	await Touch.finish(test,owner_game,2400);await test.frames(8)
	return owner_game.auto_move.navigation.legal_interaction(owner_game.player.global_position,{"kind":"object","object":point,"point":point.global_position})

static func visible_point(owner_game: Node, id: String, action: String) -> Vector2:
	var record:=geometry(id);var point:=action_point(owner_game,action)
	if record.is_empty() or not is_instance_valid(point): return Vector2.INF
	var candidates: Array=[record.collision.get_center(),record.footprint.get_center(),record.anchor,record.position+Vector2(16,16)]
	for candidate in candidates:
		var at: Vector2=candidate;var screen: Vector2=owner_game.player.get_canvas_transform()*at
		if not owner_game.get_viewport().get_visible_rect().grow(-8).has_point(screen) or owner_game.touch_input.ui_at(screen): continue
		var resolved: Dictionary=TouchInteractionResolver.resolve(owner_game,at)
		if resolved.get("kind")=="object" and resolved.get("object")==point: return at
	return Vector2.INF

static func gesture_grab_point(owner_game: Node, id: String) -> Vector2:
	var item: Dictionary=geometry(id)
	if item.is_empty(): return Vector2.INF
	var rect: Rect2=item.footprint
	# 特意从非中心真实图像点抓起，验证编辑器保留实际抓取偏移。
	for at in [rect.position+Vector2(12,16),rect.end-Vector2(12,16),rect.position+Vector2(12,rect.size.y*.5)]:
		var point: Vector2=at;var screen: Vector2=owner_game.player.get_canvas_transform()*point
		if rect.has_point(point) and point.distance_to(rect.get_center())>1 and owner_game.get_viewport().get_visible_rect().grow(-8).has_point(screen) and not owner_game.touch_input.ui_at(screen): return point
	return Vector2.INF

static func screen_drag(test: Node, from: Vector2, to: Vector2, index: int) -> void:
	var drag:=InputEventScreenDrag.new();drag.index=index;drag.position=to;drag.relative=to-from
	test.get_viewport().push_input(drag,true)

static func mouse(test: Node, point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed;event.device=0
	test.get_viewport().push_input(event,true)

static func click_function(test: Node, owner_game: Node, id: String, action: String) -> bool:
	if not await approach(test,owner_game,action): return false
	var world:=visible_point(owner_game,id,action)
	if world==Vector2.INF: return false
	Touch.tap(test,owner_game,world);await Touch.finish(test,owner_game,1800);await test.frames(4)
	return true

static func preserved_upgrade(before: Dictionary, after: Dictionary) -> bool:
	# 扩建后侧厅桌毯会变宽，允许安全协调；玩家关键家具原cell必须保留，任何旧ID都不能消失。
	for id in before:
		if not after.has(id): return false
		if CRITICAL.has(id) and before[id]!=after[id]: return false
	return true

static func setup_married_home(test: Node, owner_game: Node) -> bool:
	load("res://tests/star_runner.gd").fixture(owner_game,true)
	Housing.restore(Housing.defaults(GameClock.day));Calendar.restore(Calendar.snapshot())
	Inventory.coins=100000;Inventory.items={"wood":999,"stone":999,"iron_bar":99,"star_fragment":99,"crystal":99,"carrot":20,"potato":10}
	FarmProgress.built.assign(["toolrack","bedding"]);GameState.stamina=130;Xiaojing.state.diamonds=1314
	if not await Home.finish_upgrade(test,owner_game,1) or not await Home.finish_upgrade(test,owner_game,2): return false
	owner_game.change_location("home",Housing.anchor("storage")+Vector2(32,0));await test.frames(5)
	return Housing.buy("chair") and Housing.place("chair","home",Vector2i(5,9)) and Housing.deposit("wood",12)

func fresh() -> void:
	if is_instance_valid(game.home_arrange): game.home_arrange.cancel()
	if game.home_rest.busy: game.home_rest.cancel()
	while game.hud.close_active_panel(): pass
	check(FarmSaveStore.restore(game,initial),"布置探针恢复完整初始进度")
	GameClock.running=false;GameWeather.enabled=false;GameState.set_control_mode("tap",false)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.coins=100000
	Inventory.items={"wood":999,"stone":999,"iron_bar":99,"star_fragment":99,"crystal":99,"carrot":20,"potato":10}
	Xiaojing.state.diamonds=1314;GameState.rest()
	game.change_location("home",Vector2(640,500));await frames(6)

func economy() -> Dictionary:
	return AbyssSaveSchema.canonical({"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"stamina":GameState.stamina,"plants":Xiaojing.state.plants,"day":GameClock.day,"minutes":GameClock.minutes,"progress":FarmProgress.snapshot()})

func routes() -> bool:
	game.auto_move.navigation.invalidate();await frames(4);game.auto_move.navigation.rebuild()
	for action in ["sleep","sofa","kitchen","storage","mail","exit"]:
		var point:=action_point(game,action)
		if not is_instance_valid(point): print("HOME ARRANGE MISSING ACTION ",action);return false
		if game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(): print("HOME ARRANGE MISSING ROUTE ",action);return false
	return true

func defaults_and_moves() -> void:
	await fresh()
	check(Housing.state.builtins.size()>=16 and FarmSaveStore.snapshot(game).version==FarmSaveStore.VERSION,"新房保留至少16件原室内家具并使用当前存档格式")
	check(Housing.can_arrange() and await routes(),"默认起居布局可编辑且六处必要功能有路")
	for id in ["bed","sofa","kitchen","storage","mail_desk","dining_table","dresser","lamp","plant"]:
		await fresh()
		var old: Dictionary=geometry(id);var destination:=find_cell(id)
		check(destination.x>=0,"原房间家具存在真正可移动的合法位置："+id)
		if destination.x<0: continue
		var original_cell: Vector2i=old.cell;var before:=economy()
		check(Housing.move_builtin(id,destination,original_cell),"以稳定ID移动原有家具："+id)
		await frames(6)
		var moved: Dictionary=geometry(id)
		check(moved.cell==destination and moved.anchor.distance_to(old.anchor)>=112 and economy()==before,"家具实际位移，金币物品体力520与钻石均不变："+id)
		var committed: Dictionary=Housing.snapshot()
		check(not Housing.move_builtin(id,original_cell,original_cell) and Housing.snapshot()==committed,"旧格确认回调不能重放到已移动家具："+id)
		check(await routes(),"移动后床门厨房沙发收纳和信件仍可达："+id)
		if CRITICAL.has(id):
			var moved_point:=action_point(game,CRITICAL[id])
			check(is_instance_valid(moved_point) and moved_point.global_position.distance_to(Housing.anchor(CRITICAL[id]))<.5,"功能触点与移动后家具同步："+id)
	await fresh();var before: Dictionary=Housing.snapshot()
	check(not Housing.move_builtin("bed",Vector2i(0,0)) and not Housing.move_builtin("bed",Vector2i(20,17)) and Housing.snapshot()==before,"越界与房门通道放床整笔拒绝，不改变现有布局")
	check(not Housing.can_move_builtin("kitchen",Vector2i(21,9),true) and Housing.snapshot()==before,"餐桌边缘无足够通行余量的厨房位置被拒绝，不能把信件书桌困住")

func editor_transactions() -> void:
	await fresh();var editor: Node=game.home_arrange
	var destination:=find_cell("bed");var before:=economy();var housing: Dictionary=Housing.snapshot()
	var toolbar_before: Rect2=game.hud.toolbar.get_global_rect()
	check(destination.x>=0 and editor.start_builtin("bed"),"原床可以进入地图布置预览")
	if not editor.active: return
	editor.pick_cell(destination)
	check(editor.preview_cell==destination and editor.preview_valid and economy()==before and Housing.snapshot()==housing,"选择真实落点只产生预览，不移动家具或扣资源")
	# 预览文字会改变容器最小尺寸；等真实布局完成后再从当前面板计算触点。
	await frames(6)
	var before_bar: Dictionary={"point":Vector2.ZERO,"panel":editor.panel.get_global_rect(),"active":editor.active,"cell":editor.preview_cell,"target":game.auto_move.target.duplicate()}
	var ui_point: Vector2=editor.panel.get_global_rect().position+Vector2(10,10)
	before_bar.point=ui_point;before_bar.ui_at=game.touch_input.ui_at(ui_point);before_bar.viewport=get_viewport().get_visible_rect();before_bar.cancel_button=editor.cancel_button.get_global_rect()
	Touch.finger(self,ui_point,true,484);Touch.finger(self,ui_point,false,484);await frames(3)
	print("HOME ARRANGE BAR PROBE before=",before_bar," after=",{"panel":editor.panel.get_global_rect(),"active":editor.active,"cell":editor.preview_cell,"housing_same":Housing.snapshot()==housing,"target":game.auto_move.target})
	check(editor.active and editor.preview_cell==destination and Housing.snapshot()==housing and game.auto_move.target.is_empty(),"点击布置操作栏不穿透地图、不移动角色或更改预览")
	editor.cancel()
	check(not editor.active and not editor.confirm() and Housing.snapshot()==housing and economy()==before,"取消及迟到确认完整保留原房间")
	await frames(4)
	var toolbar_restored:=true
	for button in game.hud.tool_buttons: toolbar_restored=toolbar_restored and button.is_visible_in_tree()
	check(toolbar_restored and game.hud.toolbar.get_global_rect()==toolbar_before,"退出布置恢复原完整九格大小，不缩小经典HUD")
	check(editor.start_builtin("bed"),"取消后可重新开始一次布置")
	editor.pick_cell(destination)
	check(editor.confirm() and not editor.confirm() and not editor.active,"布置最终确认唯一提交，连续点击不重复移动")
	check(geometry("bed").cell==destination and economy()==before,"确认仅改变目标家具布局，经济与属性保持")
	for transition in ["mode","scene","load","background","menu"]:
		await fresh();housing=Housing.snapshot();before=economy();destination=find_cell("sofa")
		check(editor.start_builtin("sofa"),"取消边界先打开沙发布置："+transition)
		editor.pick_cell(destination)
		var saved:=FarmSaveStore.snapshot(game)
		if transition=="mode": GameState.set_control_mode("joystick",false)
		elif transition=="scene": game.change_location("farm")
		elif transition=="load": check(FarmSaveStore.restore(game,saved),"布置预览中可以正常恢复完整存档")
		elif transition=="menu": game.hud.inventory_panel.open_panel(false)
		else: game.notification(NOTIFICATION_APPLICATION_PAUSED)
		await frames(4)
		if transition=="menu":
			check(editor.active and not game.hud.inventory_panel.visible and Housing.snapshot()==housing and economy()==before,"布置占用模态时背包不会覆盖操作栏或改变资源")
			editor.cancel()
		else:
			check(not editor.active and not editor.confirm() and Housing.snapshot()==housing and economy()==before,"场景/模式/读档/后台使未提交预览失效："+transition)
		if transition=="background": game.notification(NOTIFICATION_APPLICATION_RESUMED)

func crafted_editor() -> void:
	await fresh();game.change_location("home",Housing.anchor("storage")+Vector2(32,0));await frames(5)
	check(Housing.buy("chair"),"从原家具目录真实制作一把椅子")
	var before:=economy();var editor: Node=game.home_arrange
	var cell:=Vector2i(-1,-1)
	for region in HomeLayout.placement_regions(int(Housing.state.level)):
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if Housing.can_place("chair","home",Vector2i(x,y)): cell=Vector2i(x,y);break
			if cell.x>=0: break
		if cell.x>=0: break
	check(cell.x>=0 and editor.start_owned("chair"),"既有自制椅子可进入同一地图布置流程")
	if not editor.active: return
	editor.pick_cell(cell)
	check(editor.preview_valid and economy()==before and Housing.state.placed.is_empty(),"自制家具预览也不重复扣制作材料或提前摆出")
	check(editor.confirm() and Housing.state.placed.size()==1 and int(Housing.state.owned.get("chair",0))==0 and economy()==before,"确认仅将一件已拥有家具从库中摆出")
	await frames(5)
	var entry: Dictionary=Housing.state.placed[0].duplicate(true);var serial: int=Housing.state.serial
	var next_cell:=Vector2i(-1,-1)
	for region in HomeLayout.placement_regions(int(Housing.state.level)):
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var candidate:=Vector2i(x,y)
				if candidate.distance_to(cell)>=2 and Housing.can_place("chair","home",candidate,entry.id): next_cell=candidate;break
			if next_cell.x>=0: break
		if next_cell.x>=0: break
	check(next_cell.x>=0 and editor.start_item(entry.id),"已摆出的自制家具使用稳定ID进入地图移动")
	if not editor.active: return
	editor.pick_cell(next_cell)
	check(editor.preview_valid and editor.confirm() and Housing.state.placed.size()==1 and Housing.state.placed[0].id==entry.id and Housing.state.placed[0].cell==[next_cell.x,next_cell.y] and Housing.state.serial==serial and economy()==before,"自制家具地图移动保留原ID序号，不复制家具或扣资源")
	check(await routes(),"自制家具自由摆放仍保留六处必需功能路线")

func native_gestures() -> void:
	for id in ["bed","sofa"]:
		await fresh();var editor: Node=game.home_arrange
		check(editor.start_builtin(id),"原生拖动从实际家具开启预览："+id);await frames(6)
		var source:=gesture_grab_point(game,id)
		check(source!=Vector2.INF,"家具真实非中心抓取点可见且不被UI遮住："+id)
		if source==Vector2.INF: editor.cancel();continue
		var before: Dictionary=Housing.snapshot();var resources:=economy();var player: Vector2=game.player.global_position
		var from: Vector2=game.player.get_canvas_transform()*source
		Touch.finger(self,from,true,601);await frames(1)
		# 必须按下后再取world_for_cell：真实非中心抓取会更新offset。
		var cell:=visible_cell(game,id,128);var target: Vector2=editor.world_for_cell(cell)
		var to: Vector2=game.player.get_canvas_transform()*target
		check(cell.x>=0 and get_viewport().get_visible_rect().grow(-8).has_point(to) and not game.touch_input.ui_at(to),"按下后按实际抓取偏移计算可见合法拖动终点："+id)
		screen_drag(self,from,to,601);await frames(2)
		Touch.finger(self,to,false,601);await frames(4)
		check(editor.active and editor.preview_valid and editor.preview_cell==cell and Housing.snapshot()==before and economy()==resources and game.player.global_position==player and game.auto_move.target.is_empty(),"原生ScreenDrag释放仅预览，不搬家具不扣资源不移动角色："+id)
		check(editor.confirm() and not editor.confirm() and geometry(id).cell==cell and economy()==resources,"原生拖动后最终确认唯一提交："+id)
	await fresh();var editor: Node=game.home_arrange
	check(editor.start_builtin("bed"),"双指安全从原床预览开始");await frames(6)
	var source:=gesture_grab_point(game,"bed");var before: Dictionary=Housing.snapshot();var resources:=economy();var player: Vector2=game.player.global_position
	var from: Vector2=game.player.get_canvas_transform()*source
	Touch.finger(self,from,true,602);await frames(1)
	var cell:=visible_cell(game,"bed",128);var to: Vector2=game.player.get_canvas_transform()*editor.world_for_cell(cell)
	screen_drag(self,from,to,602);await frames(2)
	var button_point: Vector2=editor.confirm_button.get_global_rect().get_center()
	Touch.finger(self,button_point,true,603);Touch.finger(self,button_point,false,603)
	Touch.finger(self,to,false,602);await frames(4)
	check(editor.active and not editor.confirm() and Housing.snapshot()==before and economy()==resources and game.player.global_position==player,"地图手指与确认按钮第二指混合不能提交或重复扣除资源")
	cell=visible_cell(game,"bed",128);to=game.player.get_canvas_transform()*editor.world_for_cell(cell)
	Touch.finger(self,to,true,604);Touch.finger(self,to,false,604);await frames(4)
	check(editor.preview_valid and editor.preview_cell==cell and Housing.snapshot()==before and game.player.global_position==player,"双指放开后正常单击可再次预览，没有残留finger或旧任务")
	check(editor.confirm() and not editor.confirm() and geometry("bed").cell==cell and economy()==resources,"双指取消后下一独立确认仍只提交一次")
	await fresh();editor=game.home_arrange
	check(editor.start_builtin("sofa"),"桌面原生鼠标拖动从实际沙发开始");await frames(6)
	source=gesture_grab_point(game,"sofa");from=game.player.get_canvas_transform()*source
	before=Housing.snapshot();resources=economy();player=game.player.global_position
	mouse(self,from,true);await frames(1)
	cell=visible_cell(game,"sofa",128);to=game.player.get_canvas_transform()*editor.world_for_cell(cell)
	var motion:=InputEventMouseMotion.new();motion.device=0;motion.position=to;motion.relative=to-from;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true);await frames(2);mouse(self,to,false);await frames(4)
	check(source!=Vector2.INF and cell.x>=0 and get_viewport().get_visible_rect().grow(-8).has_point(to) and not game.touch_input.ui_at(to),"桌面鼠标抓取和目标同样来自真实可见区域")
	check(editor.active and editor.preview_valid and editor.preview_cell==cell and Housing.snapshot()==before and economy()==resources and game.player.global_position==player and game.auto_move.target.is_empty(),"原生MouseButton/Motion释放仅预览，资源位置保持")
	check(editor.confirm() and not editor.confirm() and geometry("sofa").cell==cell and economy()==resources,"桌面鼠标拖动确认也唯一提交")

func dynamic_functions() -> void:
	for id in ["bed","sofa","kitchen","storage"]:
		await fresh();var old_anchor: Vector2=Housing.anchor(CRITICAL[id]);var destination:=find_cell(id,128)
		if destination.x<0: check(false,"功能探针找到移动位置："+id);continue
		check(Housing.move_builtin(id,destination),"功能探针真实移动："+id);await frames(6)
		var old_target: Dictionary=TouchInteractionResolver.resolve(game,old_anchor)
		var point:=action_point(game,CRITICAL[id])
		check(is_instance_valid(point) and old_target.get("object")!=point and point.global_position.distance_to(old_anchor)>=128,"旧坐标不再选中原功能物件："+id)
		if not is_instance_valid(point): continue
		if id=="bed": GameClock.minutes=1200
		var before_old_click:=economy()
		Touch.tap(self,game,old_anchor);await Touch.finish(self,game,1200);await frames(4)
		check(not GameState.modal and economy()==before_old_click,"真正点击原位置不会打开旧功能、睡眠或重复扣资源："+id)
		while game.hud.close_active_panel(): pass
		if id=="bed":
			GameClock.minutes=1199
			check(await click_function(self,game,id,"sleep") and not game.hud.system_panel.visible,"搬床后19:59仍由原规则拒睡")
			GameClock.minutes=1200;var day: int=GameClock.day;GameState.stamina=2
			check(await click_function(self,game,id,"sleep") and game.hud.system_panel.visible and game.hud.system_panel.sleep_mode,"新床原生点击打开正式睡眠确认")
			game.hud.system_panel.actions.get_child(0).pressed.emit();await frames(5)
			check(GameClock.day==day+1 and GameClock.minutes==360 and GameState.stamina==GameState.max_stamina(),"移动后床仍通过原睡眠入口唯一结算次日")
		elif id=="sofa":
			FarmProgress.built.assign(["bedding"]);GameState.stamina=1;GameClock.minutes=600
			check(await click_function(self,game,id,"sofa") and game.home_rest.panel.visible,"新沙发原生点击能开启同一小睡确认")
			var token: int=game.home_rest.pending_token
			check(game.home_rest.confirm(token) and not game.home_rest.confirm(token),"移动沙发仍有唯一确认token")
			await frames(25)
			check(GameState.max_stamina()==130 and GameState.stamina==66 and GameClock.minutes==660,"新沙发按130体力上限恢复65并推进一小时")
		elif id=="kitchen":
			var carrots: int=Inventory.count("carrot");var potatoes: int=Inventory.count("potato")
			check(await click_function(self,game,id,"kitchen") and game.hud.kitchen_panel.visible,"新厨房原生点击打开原烹饪界面")
			check(Kitchen.cook("carrot_stew") and Inventory.count("carrot")==carrots-2 and Inventory.count("potato")==potatoes-1 and Inventory.count("carrot_stew")==1,"移动厨房仍按原配方消耗材料并产出一份")
			game.hud.kitchen_panel.close_panel()
		else:
			check(await click_function(self,game,id,"storage") and game.hud.housing_panel.visible,"新收纳台原生点击打开原家具与柜存入口")
			check(Housing.deposit("wood",12) and Housing.state.storage.wood==12 and Housing.withdraw("wood",12),"搬迁后柜存原子转移，容量与库存不变")
			game.hud.housing_panel.close_panel()
		GameState.set_control_mode("joystick",false)
		if id!="bed":
			var target:=action_point(game,CRITICAL[id]);game.player.facing=(target.global_position-game.player.global_position).normalized();game.action_cooldown=0
			game.interact();await frames(4)
			check(GameState.modal,"备用摇杆E仍使用搬迁后的功能位置："+id)
			while game.hud.close_active_panel(): pass

func migration_and_construction() -> void:
	await fresh();check(await setup_married_home(self,game),"迁移夹具以真实施工得到三级住宅及既有自制家具柜存")
	var old:=FarmSaveStore.snapshot(game);old.version=23;old.erase("appearance");old.erase("territory");old.erase("farm_layout");old.housing=legacy_v23(old.housing)
	var canonical_old: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(old)))
	var migrated:=FarmSaveSchema.normalize(JSON.parse_string(JSON.stringify(old)))
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION,"真实v23字段可以迁入当前可布置住宅格式")
	if migrated.is_empty(): return
	var kept:=true;var normalized_migrated: Dictionary=AbyssSaveSchema.canonical(migrated)
	for key in canonical_old:
		if key in ["version","housing"]: continue
		if migrated.get(key)!=canonical_old[key] and normalized_migrated.get(key)==canonical_old[key]: print("HOME ARRANGE LEGACY REPRESENTATION ",key," JSON integer/float normalized, values identical")
		if normalized_migrated.get(key)!=canonical_old[key]: kept=false;print("HOME ARRANGE LEGACY VALUE DIFFERENCE ",key," expected=",canonical_old[key]," actual=",normalized_migrated.get(key))
	for key in canonical_old.housing:
		if normalized_migrated.housing.get(key)!=canonical_old.housing[key]: kept=false;print("HOME ARRANGE LEGACY HOUSING DIFFERENCE ",key," expected=",canonical_old.housing[key]," actual=",normalized_migrated.housing.get(key))
	check(kept and migrated.housing.builtins.size()>=16,"v23逐旧字段保留家具ID位置柜存婚姻130上限与1314钻石，仅补室内布局")
	check(FarmSaveSchema.normalize(migrated)==migrated and not old.housing.has("builtins"),"v24布局迁移幂等且不污染原输入")
	check(FarmSaveStore.restore(game,migrated) and Xiaojing.state.married and GameState.max_stamina()==130 and Xiaojing.state.diamonds==1314,"旧已婚档真实恢复不重扣婚礼或降低体力上限")
	await frames(5)
	var destination:=find_cell("sofa")
	check(destination.x>=0 and Housing.move_builtin("sofa",destination),"施工前玩家可保存自己的沙发位置")
	var arranged: Dictionary=Housing.state.builtins.duplicate(true)
	check(await Home.finish_upgrade(self,game,3),"玩家布局随后经过真实两日施工升至四级")
	check(preserved_upgrade(arranged,Housing.state.builtins) and Housing.state.storage.wood==12 and Housing.state.placed.size()==1,"施工保留玩家关键家具位置、全部既有ID、自制家具和柜存，侧厅按新尺寸安全协调")
	check(await routes() and FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"布置与施工组合仍有完整必要路径和合法存档")
