extends Node
## 角色卡只是临时选择；保存与新档提交属于主场景，组件不可偷偷写入。
var checked: int=0
var failed: int=0
var panel: PanelContainer
var menu: PanelContainer
var host: Control
var manager: Node
var confirmations: Array[String]=[]
var cancellations: int=0
var new_games: int=0
var progress_commits: int=0
var captures: Array=[]
var initial_appearance: Dictionary
var saved_file: PackedByteArray
var had_save: bool=false

func _ready() -> void: call_deferred("run")
func frames(count: int=3) -> void:
	for _i in range(count): await get_tree().physics_frame
func check(ok: bool, text: String) -> void:
	checked+=1
	if ok: print("PASS: ",text)
	else: failed+=1;push_error("FAIL: "+text)
func protected_state() -> Dictionary:
	return {"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"day":GameClock.day,"minutes":GameClock.minutes,"housing":Housing.snapshot(),"xiaojing":Xiaojing.snapshot(),"appearance":manager.snapshot()}

func run() -> void:
	GameClock.running=false;GameWeather.enabled=false
	manager=get_node_or_null("/root/Appearance")
	if not manager:
		check(false,"选择界面测试需要统一Appearance已接入")
		get_tree().quit(1);return
	initial_appearance=manager.snapshot()
	had_save=FileAccess.file_exists(FarmSaveStore.PATH)
	if had_save: saved_file=FileAccess.get_file_as_bytes(FarmSaveStore.PATH)
	get_window().size=Vector2i(1280,720)
	host=Control.new();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.theme=FarmUIStyle.make_theme();add_child(host)
	panel=load("res://scripts/appearance/character_select_panel.gd").new();host.add_child(panel)
	menu=load("res://scripts/ui/system_panel.gd").new();menu.size=Vector2(620,540);menu.position=Vector2(330,90);host.add_child(menu)
	panel.confirmed.connect(func(gender: String): confirmations.append(gender))
	panel.cancelled.connect(func(): cancellations+=1)
	menu.new_game_requested.connect(func(): new_games+=1)
	Events.progress_committed.connect(func(): progress_commits+=1)
	await frames(4)
	await choices_and_safety()
	await keyboard_and_controller()
	await menu_and_portraits()
	await layout_samples()
	manager.restore(initial_appearance)
	check(progress_commits==0,"选择、取消、菜单确认及头像切换不发放游戏奖励或自动提交进度")
	check(FileAccess.file_exists(FarmSaveStore.PATH)==had_save and (not had_save or FileAccess.get_file_as_bytes(FarmSaveStore.PATH)==saved_file),"组件从未创建或覆盖原主存档，确认仅发信号给协调层")
	var file:=FileAccess.open("res://builds/character-select-"+("state" if DisplayServer.get_name()=="headless" else "render")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));file.close()
	print("CHARACTER SELECT "+("STATE" if DisplayServer.get_name()=="headless" else "RENDER")+" RESULT: %d checks, %d failures" % [checked,failed])
	host.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func touch(point: Vector2, down: bool, index: int=731) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=down
	get_viewport().push_input(event,true)
func tap(control: Control, index: int=731) -> void:
	if not is_instance_valid(control):
		check(false,"预期公开按钮存在")
		return
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(3)
	var at:=control.get_global_rect().get_center();touch(at,true,index);touch(at,false,index);await frames(3)
func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;get_viewport().push_input(event,true)
	await frames(3)
func joy(button: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true;get_viewport().push_input(event,true);await frames(3)
func mouse_click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=down
		get_viewport().push_input(event,true);await frames(1)
	await frames(3)
func find_button(root: Node, caption: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text==caption and child.is_visible_in_tree(): return child
		var found:=find_button(child,caption)
		if found: return found
	return null

func choices_and_safety() -> void:
	var before:=protected_state()
	check(not panel.visible and panel.cards.size()==2 and not panel.is_in_group("modal_panels"),"角色选择默认收起，只有男女主角两张卡")
	check(panel.open_panel("male") and GameState.modal,"角色选择正确打开并阻止底层世界操作")
	await frames(5)
	check(panel.images.male.texture!=null and panel.images.female.texture!=null and panel.companion_image.texture!=null and not panel.confirm_button.disabled,"两张主角正式形象及对应小京预览资源全部加载")
	check(panel.selected_gender=="male" and panel.preview_data.xiaojing_variant=="xiaojing_female","男主角预选只读对应女小京")
	await capture("male")
	await tap(panel.cards.female)
	check(panel.selected_gender=="female" and panel.preview_data.xiaojing_variant=="xiaojing_male","原生触屏女主角卡只读对应男小京")
	check(panel.cards.female.button_pressed and not panel.cards.male.button_pressed,"选中高亮准确且只出现一个选择")
	await capture("female")
	for i in range(10): await tap(panel.cards["male" if i%2==0 else "female"],732)
	check(protected_state()==before and confirmations.is_empty(),"十次原生切换预选不写外观、不扣物品、不创建新档")
	check(not panel.select_gender("invalid") and panel.selected_gender=="female","非法形象不能变成有效确认")
	var first: Vector2=panel.cards.male.get_global_rect().get_center();var second: Vector2=panel.confirm_button.get_global_rect().get_center()
	touch(first,true,733);touch(second,true,734);touch(second,false,734);touch(first,false,733);await frames(3)
	check(panel.visible and confirmations.is_empty() and panel.selected_gender=="female","双指碰到角色卡与确认不意外开始新游戏")
	var at: Vector2=panel.cards.male.get_global_rect().get_center();touch(at,true,735)
	var drag:=InputEventScreenDrag.new();drag.index=735;drag.position=at+Vector2(60,20);drag.relative=Vector2(60,20);get_viewport().push_input(drag,true)
	touch(drag.position,false,735);await frames(3)
	check(panel.selected_gender=="female" and confirmations.is_empty(),"拖过角色卡不会变成新的选择或确认")
	await tap(panel.confirm_button)
	check(confirmations==["female"] and not panel.visible and not GameState.modal,"原生确认只发一次选定主角并关闭选择页")
	panel.confirm_selection();panel.confirm_button.pressed.emit()
	check(confirmations==["female"] and protected_state()==before,"迟到和重复确认不重复提交或自行写入外观")
	panel.open_panel("male");await frames(3);await tap(panel.back_button)
	check(cancellations==1 and not panel.visible and protected_state()==before,"返回只取消预选，保留现有进度")

func keyboard_and_controller() -> void:
	var before:=protected_state()
	panel.open_panel("male");await frames(3)
	await key(KEY_RIGHT);check(panel.selected_gender=="female","键盘右键预选女主角")
	await key(KEY_LEFT);check(panel.selected_gender=="male","键盘左键预选男主角")
	await key(KEY_ENTER);check(confirmations.back()=="male" and not panel.visible,"Enter只确认当前主角")
	panel.open_panel("male");await frames(3);await mouse_click(panel.cards.female)
	check(panel.selected_gender=="female" and protected_state()==before,"鼠标点击角色卡只改变预选")
	await mouse_click(panel.confirm_button)
	check(confirmations.back()=="female" and not panel.visible and protected_state()==before,"鼠标确认同样只发一次信号，不自行创建存档")
	panel.open_panel("male");await frames(3);await joy(JOY_BUTTON_DPAD_RIGHT)
	check(panel.selected_gender=="female","手柄十字键支持切换")
	await joy(JOY_BUTTON_A);check(confirmations.back()=="female" and not panel.visible,"手柄A确认当前主角")
	panel.open_panel("male");await frames(3)
	var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_LEFT_X;axis.axis_value=.8;get_viewport().push_input(axis,true);await frames(3)
	check(panel.selected_gender=="female","手柄摇杆横轴支持预选")
	await joy(JOY_BUTTON_B);check(not panel.visible and cancellations==2,"手柄B返回而不确认")
	panel.open_panel("female");await frames(3);await key(KEY_ESCAPE)
	check(not panel.visible and cancellations==3 and protected_state()==before,"Escape取消选择且所有原数据不变")
	panel.open_panel("male");await frames(3);panel.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(panel.visible and panel.selected_gender=="male" and cancellations==3 and protected_state()==before,"后台期间清理手势但保留角色预选，不退出或提交默认角色")
	panel.close_panel()

func menu_and_portraits() -> void:
	for gender in ["male","female"]:
		manager.set_player_gender(gender);menu.open_panel();await frames(5)
		var paths: Dictionary=manager.preview_paths(gender)
		check(menu.player_avatar.visible and menu.player_avatar.current_avatar_path()==paths.player_portrait and not menu.appearance_hint.visible,"菜单头像从统一外观解析当前主角："+gender)
		await capture("menu_"+gender);menu.close_panel()
	var before:=protected_state()
	menu.open_panel();await frames(3)
	await tap(find_button(menu,"新游戏 · 重新开始"))
	check(menu._new_game_pending and new_games==0 and protected_state()==before,"菜单新游戏首先明确展示覆盖确认，不立即创建或替换存档")
	await capture("new_game_confirmation")
	var stale: int=menu._view_token
	await tap(find_button(menu,"取消，继续当前游戏"))
	menu.confirm_new_game(stale)
	check(not menu._new_game_pending and new_games==0 and protected_state()==before,"取消与迟到的菜单确认都保留原进度")
	await tap(find_button(menu,"新游戏 · 重新开始"));await tap(find_button(menu,"确认进入角色选择"))
	menu.confirm_new_game(stale)
	check(new_games==1 and not menu.visible and not GameState.modal and protected_state()==before,"最终菜单确认仅发送一次选择请求，实际保存交由主场景")
	manager.restore(initial_appearance)

func layout_samples() -> void:
	for size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(4);panel.open_panel("female");await frames(4);panel.layout_panel();await frames(3)
		var bounds:=Rect2(Vector2.ZERO,host.size)
		var valid: bool=bounds.grow(.5).encloses(panel.get_global_rect())
		for button in [panel.cards.male,panel.cards.female,panel.confirm_button,panel.back_button]: valid=valid and panel.get_global_rect().grow(.5).encloses(button.get_global_rect()) and button.size.x>=UIMetrics.minimum_target() and button.size.y>=UIMetrics.minimum_target()
		check(valid,"角色卡和最终按钮适配横屏且有合法触区："+str(size))
		await capture("layout_"+str(size.x)+"x"+str(size.y));panel.close_panel()
	get_window().size=Vector2i(1280,720);await frames(4)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	panel.open_panel("male");await frames(4);panel.layout_panel();await frames(3)
	print("CHARACTER SELECT DPI PROBE ",{"host":host.size,"panel":panel.get_global_rect(),"min":panel.get_combined_minimum_size(),"confirm":panel.confirm_button.get_global_rect(),"target":UIMetrics.minimum_target(),"header":panel.header.get_global_rect(),"footer":panel.footer.get_global_rect(),"card":panel.cards.male.get_global_rect()})
	check(Rect2(Vector2.ZERO,host.size).grow(.5).encloses(panel.get_global_rect()) and panel.confirm_button.size.y>=96,"480DPI注入触区放大时不裁切角色卡或最终确认")
	await capture("dpi_480");panel.close_panel();UIMetrics.screen_provider=Callable()

func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/character-select-"+tag+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append(path)
