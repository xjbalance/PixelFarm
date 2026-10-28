extends "res://tests/runner.gd"
## 在真实既有旅程中换装；使用独立存档，完整比较除外观外的经营与关系状态。
const Touch=preload("res://tests/touch_navigation.gd")
var path: String=""
var captures: Array=[]
var capture_mode: bool=false

func canonical(value: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))
func progress() -> Dictionary:
	var value:=snapshot();value.erase("appearance");return value

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	path="user://appearance-switch-%d.json" % Time.get_ticks_usec()
	Appearance.set_player_gender("male")
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.tutorial.restore(GameTutorial.defaults(true))
	Inventory.coins=8765;Inventory.items.carrot=17;GameState.stamina=43;GameClock.minutes=615
	GameState.set_control_mode("joystick",false);await frames(3)
	check(FarmSaveStore.write(game,path),"既有旅程先形成独立合法存档，不接触真实玩家文件")
	game.persistence_enabled=true
	await preview_and_cancel()
	await confirmations()
	await failed_save()
	await married_progress()
	await blocking_states()
	await layout_and_gestures()
	await restart_existing()
	var file:=FileAccess.open("res://builds/appearance-switch-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));file.close()
	print("APPEARANCE SWITCH "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func button_named(root: Node, prefix: String) -> Button:
	if root is Button and root.text.begins_with(prefix) and root.is_visible_in_tree(): return root
	for child in root.get_children():
		var result: Button=button_named(child,prefix)
		if result: return result
	return null

func tap(control: Control, index: int=821) -> void:
	if not is_instance_valid(control): return
	var ancestor: Node=control.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames(3)
	var center: Vector2=control.get_global_rect().get_center()
	Touch.finger(self,center,true,index);Touch.finger(self,center,false,index);await frames(3)

func open_from_menu() -> void:
	game.hud.system_panel.open_panel();await frames(3)
	var button: Button=button_named(game.hud.system_panel,"切换人物形象")
	check(button!=null,"既有游戏菜单提供独立的切换人物入口")
	await capture("menu_entry")
	if button: await tap(button)
	await frames(3)
	check(game.switching_character and game.character_select.visible and GameState.modal and not game.awaiting_character_choice,"原生触摸打开游戏内选择，未进入新游戏流程")
	check(game.hud.safe.get_global_rect().grow(.5).encloses(game.character_select.get_global_rect()) and game.character_select.get_global_rect().grow(.5).encloses(game.character_select.confirm_button.get_global_rect()),"第一次从菜单打开即完整显示立绘和确认按钮")

func preview_and_cancel() -> void:
	var original: Dictionary=snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	await open_from_menu()
	check(game.character_select.selected_gender=="male","游戏内选择以当前主角预选")
	check(game.character_select.confirm_button.text.contains("形象") and not game.character_select.confirm_button.text.contains("开始"),"游戏内确认明确表示使用形象，不暗示重新开始")
	await tap(game.character_select.cards.female)
	check(game.character_select.selected_gender=="female" and game.character_select.preview_data.xiaojing_gender=="male","触屏预选女主同步预览男小京")
	check(snapshot()==original and FileAccess.get_file_as_bytes(path)==bytes,"预选不修改主角、小京、原进度或原存档")
	await capture("preview_female")
	check(game.hud.safe.get_global_rect().grow(.5).encloses(game.character_select.get_global_rect()) and game.character_select.get_global_rect().grow(.5).encloses(game.character_select.footer.get_global_rect()),"首次预选另一形象后仍完整显示确认区")
	for i in range(10): await tap(game.character_select.cards["male" if i%2==0 else "female"],822)
	check(snapshot()==original and FileAccess.get_file_as_bytes(path)==bytes,"反复切换预览十次不修改游戏状态或写盘")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);game.character_select.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(3)
	check(game.switching_character and game.character_select.visible and game.character_select.selected_gender=="female" and snapshot()==original,"预选时进入后台保留临时选择和原旅程")
	check(canonical(FarmSaveStore.read(path))==original,"后台自动保存只保存旧的已确认形象，不提交女主预览")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN);await frames(3)
	check(game.character_select.visible and not game.backgrounded and not game.player.suspended,"恢复前台可继续预选或返回，不残留后台操作锁")
	await tap(game.character_select.back_button)
	check(not game.switching_character and not game.character_select.visible and game.hud.system_panel.visible and GameState.modal,"取消后返回既有游戏菜单")
	check(snapshot()==original and FileAccess.get_file_as_bytes(path)==bytes,"取消后金币、体力、时间、物品与所有经营关系数据完整保留")
	game.hud.system_panel.close_panel();await frames(3)
	check(not GameState.modal and GameState.control_mode=="joystick","关闭菜单恢复原备用摇杆模式")

func verify_bindings(gender: String) -> void:
	check(Appearance.gender("player")==gender and Appearance.gender()==CharacterAppearance.opposite(gender),"主角与小京的对应形象实际联动："+gender)
	var sprite: Sprite2D=game.player.get_node("Sprite2D")
	check(sprite.texture.resource_path==Appearance.player_asset() and sprite.hframes==4 and sprite.vframes==4 and sprite.position==CharacterVisuals.OFFSET,"场景主角实时使用对应行走帧且脚底坐标不变："+gender)
	var linked: int=0;var all_ok: bool=true
	for object in get_tree().get_nodes_in_group("xiaojing"):
		if not game.is_ancestor_of(object): continue
		var other: Sprite2D=object.get_node_or_null("Sprite2D")
		if not other and object.get_child_count()>0 and object.get_child(0) is Sprite2D: other=object.get_child(0)
		if not other: continue
		linked+=1;all_ok=all_ok and other.get_meta("appearance_variant","")==Appearance.companion_variant()
	check(linked==4 and all_ok,"现有四处小京显示点统一刷新，无第二份NPC身份："+gender)
	game.hud.system_panel.open_panel();await frames(3)
	check(game.hud.system_panel.player_avatar.current_avatar_path()==Appearance.portrait_asset("player"),"既有菜单头像随游戏内切换实时更新："+gender)
	await capture("menu_"+gender);game.hud.system_panel.close_panel()
	await capture("world_"+gender)
	game.hud.dialogue.portrait.person="xiaojing"
	check(game.hud.dialogue.portrait.current_avatar_path()==Appearance.portrait_asset(),"原对话头像使用同一个已切换小京："+gender)
	var saved: Dictionary=FarmSaveStore.read(path)
	check(saved.get("version")==25 and saved.get("appearance")==CharacterAppearance.defaults(gender),"切换写入现有v25存档，不新增不兼容结构："+gender)

func confirmations() -> void:
	for gender in ["female","male","female"]:
		var old: Dictionary=progress()
		check(game.begin_character_switch(),"既有旅程可直接进入形象切换："+gender)
		await frames(2)
		game.confirm_character_switch("invalid")
		check(game.switching_character and Appearance.gender("player")!=gender and progress()==old,"非法确认不修改外观或进度："+gender)
		game.character_select.select_gender(gender)
		check(game.character_select.confirm_selection(),"既有选择面板确认新的形象："+gender)
		await frames(5)
		check(not game.switching_character and not game.awaiting_character_choice and not game.character_select.visible and game.hud.system_panel.visible and GameState.modal,"成功切换返回原游戏菜单，不进入新旅程："+gender)
		check(progress()==old,"除外观外完整存档快照保持一致："+gender)
		await verify_bindings(gender)
		await frames(3)
		var stable: Dictionary=snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
		game.confirm_character_switch(CharacterAppearance.opposite(gender));game.character_select.confirm_selection();await frames(3)
		check(snapshot()==stable and FileAccess.get_file_as_bytes(path)==bytes,"同帧及迟到重复确认不重置进度或覆写新形象："+gender)
	check(not FileAccess.file_exists(path+".before_new_game.bak"),"游戏内换形象不调用新游戏覆盖与备份流程")
	var original: Dictionary=snapshot()
	check(game.begin_character_switch(),"当前相同形象仍可打开选择")
	game.character_select.confirm_selection();await frames(4)
	check(snapshot()==original,"确认当前形象保持全部数据，不重置原旅程")
	game.hud.system_panel.close_panel();await frames(3)

func failed_save() -> void:
	var original: Dictionary=snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	check(game.begin_character_switch(),"保存失败用例进入现有旅程的形象选择")
	var gender: String=CharacterAppearance.opposite(Appearance.gender("player"))
	game.character_select.select_gender(gender)
	check(DirAccess.make_dir_absolute(path+".tmp")==OK,"专用测试文件夹使原子临时写入失败，不影响真实存档")
	game.character_select.confirm_selection();await frames(4)
	check(snapshot()==original and FileAccess.get_file_as_bytes(path)==bytes,"写盘失败回滚主角与小京，原进度和原字节不变")
	check(game.switching_character and game.character_select.visible and GameState.modal and game.character_select.selected_gender==gender,"失败后保留预选和重试界面，仍拦截地图")
	check(game.character_select.status_label.text.contains("保存"),"失败界面说明未能保存")
	DirAccess.remove_absolute(path+".tmp")
	game.character_select.confirm_selection();await frames(4)
	check(not game.switching_character and Appearance.gender("player")==gender and progress()==without_appearance(original),"恢复可写后可以重试，仅切换外观")
	await verify_bindings(gender)

func without_appearance(value: Dictionary) -> Dictionary:
	var data:=value.duplicate(true);data.erase("appearance");return data

func married_progress() -> void:
	game.persistence_enabled=false
	load("res://tests/star_runner.gd").fixture(game,true)
	game.tutorial.restore(GameTutorial.defaults(true));GameClock.running=false;GameWeather.enabled=false
	await frames(4)
	check(Xiaojing.state.married and FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"使用既有小京婚后合法存档夹具")
	check(FarmSaveStore.restore(game,FarmSaveStore.snapshot(game)),"既有婚后夹具先通过当前存档规范迁移，再比较切换前后状态")
	# 旧STAR夹具已选贸易方向但尚未运行手记定时刷新；先结算该既有事实，避免把后台定时刷新误算为换形象副作用。
	Letters.refresh()
	await frames(5)
	game.persistence_enabled=true
	for gender in ["female","male"]:
		var before: Dictionary=progress()
		check(game.begin_character_switch(),"婚后旅程仍可切换人物："+gender)
		game.character_select.select_gender(gender);game.character_select.confirm_selection();await frames(5)
		check(progress()==before and Xiaojing.state.married and Xiaojing.state.wedding_day==190 and Xiaojing.state.diamonds==1400,"婚后换形象不重领奖励、不重置钻石婚期及剧情："+gender)
		check(Appearance.gender("player")==gender and Appearance.gender()==CharacterAppearance.opposite(gender),"婚后小京仍按唯一形象状态自动对应："+gender)
		check(canonical(FarmSaveStore.read(path)).xiaojing==canonical({"x":Xiaojing.snapshot()}).x,"婚后关系完整写入原有存档身份："+gender)
		game.hud.system_panel.close_panel();await frames(3)

func blocking_states() -> void:
	var before: Dictionary=snapshot()
	GameState.set_modal(true);check(not game.begin_character_switch(),"其他弹窗期间拒绝开启形象切换");GameState.set_modal(false)
	game.player.action_time=1;check(not game.begin_character_switch(),"工具动画未完成时拒绝切换");game.player.action_time=0
	game.player.suspended=true;check(not game.begin_character_switch(),"角色暂停操作时拒绝切换");game.player.suspended=false
	GameState.restoring=true;check(not game.begin_character_switch(),"读档恢复期间拒绝切换");GameState.restoring=false
	GameClock.settling=true;check(not game.begin_character_switch(),"日期结算期间拒绝切换");GameClock.settling=false
	game.farm.committing=true;check(not game.begin_character_switch(),"农田事务正在提交时拒绝切换");game.farm.committing=false
	Housing.busy=true;check(not game.begin_character_switch(),"家具住宅事务正在提交时拒绝切换");Housing.busy=false
	game.home_rest.busy=true;check(not game.begin_character_switch(),"沙发休息结算期间拒绝切换");game.home_rest.busy=false
	var minute: float=GameClock.minutes;GameClock.minutes=1440;check(not game.begin_character_switch(),"午夜尚未结算时拒绝切换");GameClock.minutes=minute
	game.backgrounded=true;check(not game.begin_character_switch(),"应用后台期间拒绝切换");game.backgrounded=false
	game.closing=true;check(not game.begin_character_switch(),"关闭保存期间拒绝切换");game.closing=false
	check(snapshot()==before,"所有无效切换请求均不改变游戏状态")
	check(game.begin_character_switch() and not game.begin_character_switch(),"快速连续打开只保留一个切换实例")
	check(not game.begin_character_creation(),"游戏内切换时不能混入新游戏覆盖流程")
	game.character_select.close_panel();game.hud.system_panel.close_panel();await frames(3)
	check(game.begin_character_creation() and game.awaiting_character_choice and not game.character_select.runtime_mode,"原有新游戏选择仍使用独立的新旅程模式")
	check(not game.begin_character_switch(),"新游戏预选期间不能再打开运行时切换")
	game.character_select.close_panel();game.hud.system_panel.close_panel();await frames(3)
	check(snapshot()==before and not game.switching_character and not game.awaiting_character_choice,"取消新游戏与游戏内切换后原进度均保持完整")
	check(game.begin_character_switch(),"后台迟到确认测试进入预选")
	game.character_select.select_gender(CharacterAppearance.opposite(Appearance.gender("player")))
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);game.character_select.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(3)
	var accepted: bool=game.character_select.confirm_selection();await frames(3)
	check(not accepted and game.switching_character and game.character_select.visible and snapshot()==before,"后台迟到确认被丢弃，保留预览且不改变主角或小京")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN);await frames(3)
	game.character_select.close_panel();game.hud.system_panel.close_panel();await frames(3)
	check(game.begin_character_switch(),"日结算迟到确认测试进入预选")
	game.character_select.select_gender(CharacterAppearance.opposite(Appearance.gender("player")))
	GameClock.settling=true;game.character_select.confirm_selection();GameClock.settling=false;await frames(3)
	if snapshot()!=before:
		var settled: Dictionary=snapshot()
		for key in before:
			if before[key]!=settled.get(key): print("APPEARANCE SETTLE DIFFERENCE ",key,": ",before[key]," -> ",settled.get(key))
	if game.switching_character or GameState.modal: print("APPEARANCE SETTLE MODAL ",game.switching_character," ",GameState.modal)
	check(not game.switching_character and not GameState.modal and snapshot()==before,"日结算时迟到确认不覆盖外观、不留下模态锁")
	check(game.begin_character_switch(),"读档中断测试进入预选")
	game.character_select.select_gender(CharacterAppearance.opposite(Appearance.gender("player")))
	check(FarmSaveStore.restore(game,before),"预选中可以从合法已有旅程恢复")
	await frames(5)
	var after: Dictionary=snapshot()
	if after!=before:
		for key in before:
			if before[key]!=after.get(key): print("APPEARANCE RESTORE DIFFERENCE ",key,": ",before[key]," -> ",after.get(key))
	check(not game.switching_character and not game.character_select.visible and not GameState.modal and snapshot()==before,"读档关闭临时预选，恢复完整原形象和原进度")

func layout_and_gestures() -> void:
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(4)
		check(game.begin_character_switch(),"横屏尺寸可打开游戏内选择："+str(extent))
		await frames(5)
		var panel: PanelContainer=game.character_select
		var bounds: Rect2=game.hud.safe.get_global_rect()
		var inside: bool=bounds.grow(.5).encloses(panel.get_global_rect())
		for button in [panel.cards.male,panel.cards.female,panel.confirm_button,panel.back_button]:
			inside=inside and panel.get_global_rect().grow(.5).encloses(button.get_global_rect()) and button.size.y>=UIMetrics.minimum_target()
		check(inside,"游戏内选择、取消和确认位于安全区且满足触控尺寸："+str(extent))
		await capture("layout_"+str(extent.x)+"x"+str(extent.y))
		var prior: Dictionary=snapshot();var at: Vector2=game.player.position;var calls: int=game.auto_move.execution_count
		var first: Vector2=panel.cards.female.get_global_rect().get_center();var second: Vector2=panel.confirm_button.get_global_rect().get_center()
		Touch.finger(self,first,true,823);Touch.finger(self,second,true,824);Touch.finger(self,second,false,824);Touch.finger(self,first,false,823);await frames(4)
		check(game.switching_character and panel.visible and snapshot()==prior,"双指碰角色卡与确认不会误切换："+str(extent))
		Touch.finger(self,bounds.position+Vector2(6,6),true,825);Touch.finger(self,bounds.position+Vector2(6,6),false,825);await frames(3)
		check(game.player.position==at and game.auto_move.execution_count==calls and game.auto_move.path.is_empty(),"选择界面外缘触摸不穿透到底层行走："+str(extent))
		panel.close_panel();game.hud.system_panel.close_panel();await frames(2)
	get_window().size=Vector2i(1280,720);await frames(3)

func restart_existing() -> void:
	var expected: Dictionary=snapshot();var gender: String=Appearance.gender("player")
	check(FarmSaveStore.write(game,path),"重启前实际保存已切换的婚后旅程")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	Appearance.set_player_gender(CharacterAppearance.opposite(gender))
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	check(not game.awaiting_character_choice and not game.switching_character and not game.character_select.visible,"重新创建主场景继续已有档，不要求重新选人")
	check(snapshot()==expected,"读档恢复已切换外观和完整婚后经营进度")
	check(Appearance.gender("player")==gender and game.player.get_node("Sprite2D").texture.resource_path==Appearance.player_asset(),"重启后主角实际精灵从保存选择恢复")
	check(Xiaojing.state.married and Appearance.gender()==CharacterAppearance.opposite(gender),"重启后联动小京和婚姻状态同时恢复")
	await open_from_menu();game.character_select.close_panel();game.hud.system_panel.close_panel();await frames(3)
	check(not GameState.modal,"读档后仍能再次切换并正常返回游戏")
	game.persistence_enabled=false

func capture(tag: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var target: String="res://builds/appearance-switch-"+tag+".png"
	get_viewport().get_texture().get_image().save_png(target);captures.append({"name":tag,"path":target})
