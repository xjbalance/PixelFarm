extends "res://tests/runner.gd"
## 实际逐级施工后验收室内地图、确认UI和沙发/厨房触点，不以赋level替代建造。
const Touch=preload("res://tests/touch_navigation.gd")
const Home=preload("res://tests/home05_runner.gd")
var captures: Array=[]

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.coins=1000000;Inventory.items={"wood":999,"stone":999,"iron_bar":999,"star_fragment":999,"crystal":99,"carrot":10,"potato":10}
	var fresh:=FarmSaveStore.snapshot(game)
	game.change_location("home",Vector2(640,500));await frames(6)
	for level in [1,2,3,4]:
		check(int(Housing.state.level)==level,"窗口住宅等级由真实施工取得："+str(level))
		check(await all_routes(),"窗口该级床门厨房沙发和故事物件均可自动接近："+str(level))
		await capture("level_"+str(level))
		if level<4:
			await Home.visit_builder(self,game)
			game.hud.housing_panel.open_panel("upgrade");await frames(5)
			await audit(game.hud.housing_panel,"周砚升级预览："+str(level))
			(game.hud.housing_panel.content.get_parent() as ScrollContainer).scroll_vertical=0;await frames(3)
			await capture("upgrade_"+str(level))
			var before:=FarmSaveStore.snapshot(game)
			await tap(find_button(game.hud.housing_panel,"请周砚开始改建"))
			check(game.hud.housing_panel.pending.is_valid() and FarmSaveStore.snapshot(game)==before,"窗口升级初次点击只打开最终确认："+str(level))
			await tap(find_button(game.hud.housing_panel,"取消"))
			check(not game.hud.housing_panel.pending.is_valid() and FarmSaveStore.snapshot(game)==before,"窗口取消升级完整保留资源与原住宅："+str(level))
			await tap(find_button(game.hud.housing_panel,"请周砚开始改建"));await tap(find_button(game.hud.housing_panel,"确认"))
			check(int(Housing.state.level)==level and not Housing.state.construction.is_empty(),"窗口原生最终确认只受理真实施工："+str(level))
			game.hud.housing_panel.close_panel()
			for _i in range(2):
				GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"窗口施工合法度过一晚："+str(level));await frames(5)
			game.change_location("home",Vector2(640,500));await frames(6)
			check(Housing.state.level==level+1 and Housing.state.construction.is_empty(),"窗口原生确认施工两晚后完工："+str(level))
	game.change_location("home",game.home_rest.SOFA+Vector2(0,36));await frames(6)
	GameClock.minutes=600;GameState.stamina=1;GameClock.changed.emit();GameState.changed.emit()
	Touch.tap(self,game,game.home_rest.SOFA);await Touch.finish(self,game)
	check(game.home_rest.panel.visible and game.home_rest.pending_token>=0,"真实点击沙发自动靠近并打开确认")
	await audit(game.home_rest.panel,"沙发确认");await capture("sofa_before")
	await tap(game.home_rest.confirm_button);await capture("sofa_transition",false);await frames(20)
	check(GameClock.minutes==660 and GameState.stamina==1+ceili(GameState.max_stamina()*.5),"窗口沙发原生确认只推进一小时并恢复50%")
	await capture("sofa_after")
	game.change_location("home",Kitchen.ANCHOR+Vector2(0,36));await frames(6)
	Touch.tap(self,game,Kitchen.ANCHOR);await Touch.finish(self,game)
	check(game.hud.kitchen_panel.visible,"真实室内厨房点击打开原料理功能")
	await audit(game.hud.kitchen_panel,"室内厨房");await capture("kitchen")
	game.hud.kitchen_panel.close_panel()
	game.change_location("home",Vector2(752,350));await frames(5)
	GameClock.minutes=1140;GameClock.changed.emit()
	Touch.tap(self,game,Vector2(848,300));await Touch.finish(self,game)
	check(not game.hud.system_panel.visible and GameClock.minutes==1140,"点击实际床图像在20点前仍拒绝正式睡觉")
	GameClock.minutes=1200;GameClock.changed.emit()
	Touch.tap(self,game,Vector2(848,300));await Touch.finish(self,game)
	check(game.hud.system_panel.visible and game.hud.system_panel.sleep_mode,"20点点击整张床能自动靠近并打开正式睡眠确认")
	await audit(game.hud.system_panel,"正式床睡眠确认");await capture("bed_confirmation")
	game.hud.system_panel.close_panel()
	get_window().size=Vector2i(1600,720);await frames(5);game.hud.update_safe_area();await frames(4)
	await capture("level_4_wide")
	get_window().size=Vector2i(1280,720);await frames(5);game.hud.update_safe_area();await frames(4)
	var legacy:=fresh.duplicate(true);legacy.version=22;legacy.erase("farm_layout");legacy.erase("appearance");legacy.housing=Home.legacy_housing(legacy.housing)
	legacy.location="home";legacy.player=[640.0,500.0]
	check(FarmSaveStore.restore(game,legacy),"窗口可以读取真实v22旧住宅布局")
	await frames(8);await capture("legacy_v22")
	var file:=FileAccess.open("res://builds/home05-render-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"android_device_tested":false,"captures":captures,"checks":checked,"failures":failed},"\t"));file.close()
	print("HOME 05 RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func all_routes() -> bool:
	game.auto_move.navigation.invalidate();await frames(4);game.auto_move.navigation.rebuild()
	for point in get_tree().get_nodes_in_group("interactables"):
		if not point.is_visible_in_tree() or not game.home.is_ancestor_of(point): continue
		if game.auto_move.navigation.path_to({"kind":"object","object":point,"point":point.global_position}).is_empty(): print("HOME RENDER MISSING ",point.prompt());return false
	return true

func buttons(root: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(buttons(child))
	return result

func reveal(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(2)

func find_button(root: Node, text: String) -> Button:
	for button in buttons(root):
		if button.text==text: return button
	check(false,"窗口找到实际按钮："+text)
	return null

func tap(button: Button) -> void:
	if not is_instance_valid(button): return
	await reveal(button)
	var p: Vector2=button.get_global_rect().get_center();Touch.finger(self,p,true,410);Touch.finger(self,p,false,410);await frames(3)

func audit(panel: Control, label: String) -> void:
	await frames(4)
	check(panel.visible and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),label+"完整处于安全区")
	var legal:=true
	for control in buttons(panel):
		await reveal(control)
		legal=legal and control.size.x>=UIMetrics.minimum_target() and control.size.y>=UIMetrics.minimum_target() and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect())
		if control.has_method("contains_touch"): legal=legal and control.contains_touch(control.get_global_rect().get_center())
	check(legal,label+"按钮可滚入触达并满足当前密度最小尺寸")

func capture(label: String, settle: bool=true) -> void:
	if settle:
		game.hud.toast_time=0
		await get_tree().create_timer(2.9).timeout
	await RenderingServer.frame_post_draw
	var path: String="res://builds/home05-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures.append({"name":label,"path":path,"level":Housing.state.level,"day":GameClock.day,"minutes":GameClock.minutes})
