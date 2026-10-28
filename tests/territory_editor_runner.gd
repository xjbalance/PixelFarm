extends "res://tests/runner.gd"
## 原生触点、批量预览、明确确认与横屏布局；不操作真实玩家存档。
const Touch=preload("res://tests/touch_navigation.gd")
var editor: Node
var captures: Array=[]
var capture_mode: bool=false

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))

func business() -> Dictionary:
	return canonical({"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"day":GameClock.day,"minutes":GameClock.minutes,"housing":Housing.snapshot(),"plots":game.farm.plots.duplicate(true),"story":Story.snapshot(),"xiaojing":Xiaojing.snapshot(),"star":StarStory.snapshot(),"mines":MineState.snapshot(),"abyss":AbyssState.snapshot(),"fishing":Fishing.snapshot(),"control_mode":GameState.control_mode})

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	editor=game.get("territory_editor")
	check(is_instance_valid(editor) and is_instance_valid(game.get("territory_world")),"真实主场景接入领地世界与建造模式")
	if not is_instance_valid(editor): finish();return
	game.tutorial.restore(GameTutorial.defaults(true))
	await entry_and_cancellation()
	load("res://tests/mining.gd").fresh_chapter(game);GameClock.day=225;Calendar.restore(Calendar.snapshot())
	Territory.restore(Territory.defaults());Territory.refresh_unlocks(false)
	game.change_location("east_holding");await frames(8)
	check(GameState.location=="east_holding","章节开放后进入真实河东领地进行编辑")
	await terrain_and_touch()
	await small_objects()
	await gesture_safety()
	await layout_samples()
	await lifecycle()
	finish()

func finish() -> void:
	var file:=FileAccess.open("res://builds/territory-editor-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));file.close()
	print("TERRITORY EDITOR "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	if is_instance_valid(editor) and editor.active: editor.cancel()
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func screen(cell: Vector2i) -> Vector2:
	return game.player.get_canvas_transform()*(Vector2(cell)*32+Vector2(16,16))

func finger(point: Vector2, down: bool, index: int=881) -> void:
	Touch.finger(self,point,down,index)

func tap(control: Control, index: int=881) -> void:
	if not is_instance_valid(control): check(false,"预期建造按钮存在");return
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(3)
	var point: Vector2=control.get_global_rect().get_center()
	finger(point,true,index);finger(point,false,index);await frames(4)

func at_world(cell: Vector2i, index: int=881) -> void:
	var point:=screen(cell);finger(point,true,index);finger(point,false,index);await frames(3)

func entry_and_cancellation() -> void:
	var previous: Dictionary=business();var territory: Dictionary=Territory.snapshot()
	check(editor.open() and editor.active and GameState.modal,"从正常农场打开建造，游戏暂停且明确进入编辑状态")
	check(not editor.open(),"快速重复打开不会建立第二份建造会话")
	await frames(5)
	check(not game.hud.toolbar.visible and not game.hud.action_button.visible and not game.hud.joystick.visible,"建造期间收起普通工具和摇杆，避免地图误操作")
	check(editor.palette.visible and editor.panel.visible and not game.hud.scrim.visible,"仅显示局部调色板与确认栏，地图保留完整视野")
	check(not editor.confirm() and Territory.snapshot()==territory,"没有预览时确认不提交任何数据")
	editor.choose_tool("soil");editor.preview_at(Vector2i(18,17))
	check(not editor.preview_plan.get("valid",false) and not editor.confirm(),"原有农田格属于保护区域，不能由地表编辑覆盖")
	editor.cancel();await frames(3)
	check(not editor.active and not GameState.modal and not editor.palette.visible and not editor.panel.visible,"退出建造关闭局部面板并恢复普通游戏")
	check(Territory.snapshot()==territory and business()==previous,"取消预览不改领地、农田、钱物、体力或剧情")
	game.change_location("village");await frames(4)
	check(not editor.open() and not GameState.modal,"公共村庄不能打开自由建造模式")
	game.change_location("home");await frames(4)
	check(not editor.open() and not GameState.modal,"住宅室内继续使用原布置系统，不混入领地编辑")
	game.change_location("farm");await frames(4)

func terrain_and_touch() -> void:
	var previous: Dictionary=business();var before: Dictionary=Territory.snapshot()
	check(editor.open(),"在已解锁私人领地打开建造")
	await frames(4)
	editor.choose_tool("soil")
	for cell in [Vector2i(26,17),Vector2i(27,17),Vector2i(28,17)]: editor.preview_at(cell)
	check(editor.preview_plan.get("valid",false) and editor.preview_plan.cells.size()==3 and Territory.snapshot()==before,"三格翻土只是批量预览，未确认不改变地表")
	await capture("terrain_preview")
	await tap(editor.confirm_button)
	check(Territory.state.terrain.get("east_holding",{}).get("26,17","")=="soil" and Territory.state.terrain.east_holding.get("28,17","")=="soil","原生确认一次提交整批翻土地表")
	var committed: Dictionary=Territory.snapshot();var commits: int=editor.commit_count
	check(not editor.confirm() and Territory.snapshot()==committed and editor.commit_count==commits,"迟到或重复确认不能重放已经提交的批量")
	editor.choose_tool("dirt_path")
	var start:=screen(Vector2i(26,18));var end:=screen(Vector2i(29,18))
	finger(start,true)
	var drag:=InputEventScreenDrag.new();drag.index=881;drag.position=end;drag.relative=end-start;get_viewport().push_input(drag,true)
	finger(end,false);await frames(3)
	check(editor.preview_plan.get("valid",false) and editor.preview_plan.cells.size()==4 and Territory.snapshot()==committed,"单指拖动连续涂刷四格但松手不会自动提交")
	await tap(editor.confirm_button)
	check(Territory.state.terrain.east_holding.get("29,18","")=="dirt_path","拖动道路经明确确认后生效")
	committed=Territory.snapshot();editor.choose_tool("grass");editor.preview_at(Vector2i(26,19));editor.preview_at(Vector2i(19,19))
	check(not editor.preview_plan.get("valid",false) and not editor.confirm() and Territory.snapshot()==committed,"批量中混入保护主路时整批拒绝，不部分写入")
	await tap(editor.discard_button)
	check(editor.preview_plan.is_empty() and Territory.snapshot()==committed,"取消预览仅丢弃临时刷子，不撤销已确认结果")
	check(business()==previous,"地表和道路编辑不扣体力、不推进时间、不改变经营与婚姻进度")
	editor.cancel();await frames(3)

func small_objects() -> void:
	var previous: Dictionary=business();check(editor.open(),"再次进入建造选择小型设施")
	await frames(3);editor.choose_category("vegetation");editor.choose_tool("tree");editor.preview_at(Vector2i(26,20))
	check(editor.preview_plan.get("valid",false),"观赏树按真实占地显示合法预览")
	await capture("vegetation_preview");editor.discard_preview();editor.choose_category("objects");editor.choose_tool("lamp");editor.preview_at(Vector2i(26,20))
	await tap(editor.confirm_button);await frames(4)
	var entry: Dictionary=Territory.object_at("east_holding",Vector2i(26,20))
	check(not entry.is_empty() and entry.kind=="lamp","庭院灯通过确认真实放入私人领地")
	if entry.is_empty(): editor.cancel();return
	var id: String=entry.id;editor.choose_tool("move");editor.preview_at(Vector2i(26,20))
	check(editor.selected_id==id and editor.preview_plan.is_empty(),"移动工具先选择自己的小型设施，不直接改变位置")
	editor.preview_at(Vector2i(28,20));check(editor.preview_plan.get("valid",false),"选中后可预览新的设施位置")
	await tap(editor.confirm_button);await frames(4)
	check(Territory.object(id).cell==[28,20] and Territory.object_at("east_holding",Vector2i(26,20)).is_empty(),"移动灯具保留同一ID，旧位置不留下重复对象")
	await capture("small_facility")
	editor.choose_tool("remove");editor.preview_at(Vector2i(28,20));var before: Dictionary=Territory.snapshot()
	check(editor.preview_plan.get("valid",false) and Territory.snapshot()==before,"拆除也需要先预览和确认")
	await tap(editor.confirm_button);await frames(4)
	check(Territory.object(id).is_empty(),"确认拆除只移除选中私人物件")
	check(business()==previous,"设施放置移动拆除不产生资源、金币或储物副本")
	editor.cancel();await frames(3)

func gesture_safety() -> void:
	check(editor.open(),"触控仲裁用例打开建造")
	await frames(3);editor.choose_tool("flowers")
	var previous: Dictionary=Territory.snapshot();var at: Vector2=game.player.global_position;var executions: int=game.auto_move.execution_count
	var first:=screen(Vector2i(26,21));var second: Vector2=editor.confirm_button.get_global_rect().get_center()
	finger(first,true,882);finger(second,true,883);finger(second,false,883);finger(first,false,882);await frames(4)
	check(editor.active and editor.preview_plan.is_empty() and Territory.snapshot()==previous,"第二根手指碰到确认会取消本次候选，不误放植物")
	check(game.player.global_position==at and game.auto_move.execution_count==executions and game.auto_move.path.is_empty(),"建造世界手势不触发点击移动或原工具动作")
	for down in [true,false]:
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=first;mouse.pressed=down
		get_viewport().push_input(mouse,true)
		if down: finger(second,true,884);finger(second,false,884)
	await frames(3)
	check(Territory.snapshot()==previous and editor.preview_plan.is_empty(),"鼠标与触屏混合输入也不能误确认已有候选")
	editor.choose_tool("flowers");await at_world(Vector2i(26,21));check(editor.preview_plan.get("valid",false),"多指候选释放后下一次单指操作可以正常预览")
	editor.cancel();await frames(3)
	check(Territory.snapshot()==previous and not GameState.modal,"退出仍未确认的植物预览不写任何地表数据")

func layout_samples() -> void:
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4);check(editor.open(),"横屏可进入建造："+str(extent));await frames(5);editor.layout_panel();await frames(3)
		var bounds: Rect2=game.hud.safe.get_global_rect();var valid: bool=bounds.grow(.5).encloses(editor.palette.get_global_rect()) and bounds.grow(.5).encloses(editor.panel.get_global_rect())
		for button in [editor.confirm_button,editor.cancel_button,editor.discard_button]: valid=valid and editor.panel.get_global_rect().grow(.5).encloses(button.get_global_rect()) and button.size.x>=UIMetrics.minimum_target() and button.size.y>=UIMetrics.minimum_target()
		check(valid and not editor.palette.get_global_rect().intersects(editor.panel.get_global_rect()),"调色板与确认栏不重叠、位于安全区且触区足够："+str(extent))
		await capture("layout_"+str(extent.x)+"x"+str(extent.y));editor.cancel();await frames(3)
	get_window().size=Vector2i(1280,720);await frames(4)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	check(editor.open(),"高DPI建造入口正常");await frames(5);editor.layout_panel();await frames(3)
	check(game.hud.safe.get_global_rect().grow(.5).encloses(editor.palette.get_global_rect()) and game.hud.safe.get_global_rect().grow(.5).encloses(editor.panel.get_global_rect()) and editor.confirm_button.size.y>=96,"480DPI换算后的触控区域仍完整可见")
	await capture("dpi_480");editor.cancel();UIMetrics.screen_provider=Callable();await frames(3)

func lifecycle() -> void:
	var mode: String=GameState.control_mode;GameState.set_control_mode("joystick",false)
	check(editor.open(),"备用摇杆模式也能进入建造");await frames(3)
	var previous: Dictionary=Territory.snapshot();var original_camera: Dictionary=editor._camera_state.duplicate(true)
	editor.choose_tool("flowers");editor.preview_at(Vector2i(26,21));editor.pan_view(Vector2.LEFT);await frames(3)
	check(game.player.velocity==Vector2.ZERO and game.player.touch_direction==Vector2.ZERO,"建造观察只平移视野，不移动人物")
	editor.cancel();await frames(3)
	check(GameState.control_mode=="joystick" and game.hud.joystick.visible and Territory.snapshot()==previous,"退出建造恢复原摇杆模式并丢弃未确认候选")
	check(game.camera_rig.mode==int(original_camera.mode) and game.camera_rig.view_center.distance_to(original_camera.center)<1,"退出恢复进入建造前的镜头模式和观察位置")
	check(editor.open(),"后台用例再次打开建造");editor.choose_tool("flowers");editor.preview_at(Vector2i(26,21))
	editor.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(3)
	check(not editor.active and not GameState.modal and Territory.snapshot()==previous,"切入后台取消临时建造，不把候选写进存档")
	check(editor.open(),"换图用例打开建造");game.change_location("farm");await frames(5)
	check(not editor.active and not GameState.modal and Territory.snapshot()==previous,"场景切换关闭建造，不跨地图应用旧候选")
	GameState.set_control_mode(mode,false)

func capture(name: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/territory-editor-"+name+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":name,"path":path})
