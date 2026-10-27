extends "res://tests/runner.gd"
## 真实主场景的新建/取消/失败回滚/外观绑定；只写专用临时名称，不删原存档。
const Touch=preload("res://tests/touch_navigation.gd")
var path: String=""
var capture_mode: bool=false
var captures: Array=[]

func canonical(value: Dictionary) -> Dictionary: return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func snapshot() -> Dictionary: return canonical(FarmSaveStore.snapshot(game))

func run() -> void:
	capture_mode=capture_mode or "--capture" in OS.get_cmdline_user_args()
	path="user://scheme-c-flow-%d.json" % Time.get_ticks_usec()
	Appearance.set_player_gender("male")
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	await first_choice()
	await bindings()
	await new_game_safety()
	await restart_existing()
	var report:=FileAccess.open("res://builds/scheme-c-game-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"android_device_tested":false,"platform":DisplayServer.get_name()},"\t"));report.close()
	print("SCHEME C GAME "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func first_choice() -> void:
	var panel: PanelContainer=game.character_select
	check(game.awaiting_character_choice and panel.visible and GameState.modal,"真实无档开局自动展示方案C选择，世界暂停")
	check(not FileAccess.file_exists(path),"确认前没有悄悄写入默认性别新档")
	var original: Dictionary=snapshot();panel.select_gender("female");await frames(3)
	check(panel.selected_gender=="female" and snapshot()==original,"选择女主只是预览，不提前改主角或小京状态")
	game.autosave();game.save_game()
	check(not FileAccess.file_exists(path),"自动保存和手动保存均不能把未确认选择落盘")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);panel.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(3)
	check(panel.visible and panel.selected_gender=="female" and game.awaiting_character_choice and not FileAccess.file_exists(path),"后台保留临时选择，不退出也不保存默认男主")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN);await frames(3)
	await capture("select_female")
	check(panel.confirm_selection(),"女主最终确认通过真实主场景事务")
	await frames(5)
	check(not game.awaiting_character_choice and not panel.visible and not GameState.modal,"确认后退出选择并恢复正常游戏")
	var saved: Dictionary=FarmSaveStore.read(path)
	check(not saved.is_empty() and saved.version==25 and saved.appearance==CharacterAppearance.defaults("female"),"新档实际写入女主与男小京配对")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	game.confirm_character_creation("male");panel.confirm_selection()
	check(FileAccess.get_file_as_bytes(path)==bytes and Appearance.gender("player")=="female","迟到或重复确认不会重选、重复重置或覆写新档")

func bindings() -> void:
	for gender in ["male","female"]:
		Appearance.set_player_gender(gender);await frames(4)
		var player_sprite: Sprite2D=game.player.get_node("Sprite2D")
		check(player_sprite.texture.resource_path==Appearance.player_asset() and player_sprite.hframes==4 and player_sprite.vframes==4,"主角像素帧表与当前选择一致："+gender)
		check(player_sprite.position==CharacterVisuals.OFFSET,"方案C统一脚底偏移，不改变物理角色位置："+gender)
		var linked: int=0;var all_ok: bool=true
		for object in get_tree().get_nodes_in_group("xiaojing"):
			if not game.is_ancestor_of(object): continue
			var sprite: Sprite2D=object.get_node_or_null("Sprite2D")
			if not sprite and object.get_child_count()>0 and object.get_child(0) is Sprite2D: sprite=object.get_child(0)
			if not sprite: continue
			linked+=1;all_ok=all_ok and sprite.get_meta("appearance_variant","")==Appearance.companion_variant() and sprite.hframes==4 and sprite.vframes==4
		check(all_ok and linked==4,"三地图小京与温室同一身份四个显示点全部自动切换："+gender)
		game.hud.system_panel.open_panel();await frames(3)
		check(game.hud.system_panel.player_avatar.current_avatar_path()==Appearance.portrait_asset("player"),"菜单头像使用已选主角的正式头像："+gender)
		await capture("menu_"+gender);game.hud.system_panel.close_panel()
		var portrait: FarmPortrait=game.hud.dialogue.portrait;portrait.person="xiaojing"
		check(portrait.current_avatar_path()==Appearance.portrait_asset(),"对白小京头像由相同外观入口解析："+gender)
		for spec in [["move_down",Vector2.DOWN,0],["move_left",Vector2.LEFT,1],["move_right",Vector2.RIGHT,2],["move_up",Vector2.UP,3]]:
			await Touch.place(self,game,"farm",Vector2(720,600))
			var before: Vector2=game.player.global_position
			Input.action_press(spec[0]);await frames(8)
			var advanced: float=(game.player.global_position-before).dot(spec[1])
			check(advanced>8 and game.player.facing==spec[1] and player_sprite.frame/4==spec[2] and player_sprite.position==CharacterVisuals.OFFSET,"真实输入四方向移动、行走帧与脚底正确："+gender+str(spec[1]))
			Input.action_release(spec[0]);await frames(2)
		var previous: int=StarStory.state.wedding_phase
		StarStory.state.wedding_phase=1;game.change_location("greenhouse",Vector2(640,730))
		# 初识夹具尚不允许进入温室；直接验证实际婚礼角色的资源刷新，准入另由原剧情回归覆盖。
		game.mine_maps.greenhouse.refresh()
		var couple: Sprite2D=game.mine_maps.greenhouse.couple.get_child(0)
		check(couple.texture.resource_path==Appearance.companion_asset(true),"温室仪式使用同一性别的小京方案C礼仪派生："+gender)
		StarStory.state.wedding_phase=previous;game.mine_maps.greenhouse.refresh();game.change_location("farm",Vector2(656,440));await frames(4)
		await capture("world_"+gender)
		await companion_gallery(gender)
	Appearance.set_player_gender("female")

func companion_gallery(gender: String) -> void:
	var original: Dictionary=snapshot();var persistent: bool=game.persistence_enabled;game.persistence_enabled=false
	var object: Node2D
	for person in get_tree().get_nodes_in_group("xiaojing"):
		if game.world.is_ancestor_of(person): object=person;break
	if not is_instance_valid(object): check(false,"农场存在原小京NPC身份");return
	var old_position: Vector2=object.position;var old_visible: bool=object.visible
	Xiaojing.state.plants=520;Xiaojing.state.plant_serial=520;Xiaojing.state.unlocked=true;Xiaojing.changed.emit()
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"小京画面使用合法520次播种解锁状态夹具："+gender)
	game.change_location("farm",Vector2(680,480));object.position=Vector2(736,480);object.show();await frames(4)
	check(object.person_id=="xiaojing" and object.get_node("Sprite2D").get_meta("appearance_variant")==Appearance.companion_variant(),"实际场景展示对应小京像素形象，仍使用同一NPC身份："+gender)
	await capture("companion_world_"+gender)
	game.hud.xiaojing_panel.open_panel();await frames(4)
	var standing: Node=game.hud.xiaojing_panel.find_children("*","TextureRect",true,false).filter(func(node: Node): return node.has_meta("appearance_standing"))[0]
	check(standing.texture.resource_path==Appearance.standing_asset() and standing.get_meta("appearance_standing")==Appearance.companion_variant(),"小京关系页真正展示对应纸面立绘卡："+gender)
	await capture("companion_standing_"+gender);game.hud.xiaojing_panel.close_panel()
	game.hud.dialogue.open_dialogue("小京",[str(Xiaojing.data.memories[0].text)]);await frames(4)
	check(game.hud.dialogue.portrait.current_avatar_path()==Appearance.portrait_asset() and game.hud.dialogue.speaker_label.text=="小京","真实对话头像与名字自动联动，无旧林芽/旧小京混用："+gender)
	await capture("companion_dialogue_"+gender);game.hud.dialogue.close_dialogue()
	check(FarmSaveStore.restore(game,original),"立绘/对话画面夹具恢复原经营与关系进度")
	object.position=old_position;object.visible=old_visible;game.persistence_enabled=persistent

func button_named(root: Node, prefix: String) -> Button:
	if root is Button and root.text.begins_with(prefix): return root
	for child in root.get_children():
		var result: Button=button_named(child,prefix)
		if result: return result
	return null

func open_new_game() -> void:
	game.hud.system_panel.open_panel();await frames(2)
	game.hud.system_panel.ask_new_game();await frames(2)
	var accept: Button=button_named(game.hud.system_panel,"确认进入角色选择")
	check(accept!=null,"设置中的新游戏有独立覆盖确认")
	if accept: accept.pressed.emit()
	await frames(3)

func new_game_safety() -> void:
	Inventory.coins=7654;Inventory.items.carrot=12;GameState.set_control_mode("joystick",false)
	game.persistence_enabled=false;await frames(2);game.persistence_enabled=true
	check(FarmSaveStore.write(game,path),"旧旅程实际形成可保留的原字节存档")
	var old: Dictionary=snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	await open_new_game()
	check(game.awaiting_character_choice and game.character_select.visible and snapshot()==old,"菜单确认仅进入预选，不重置原金币或外观")
	game.character_select.select_gender("male");game.character_select.close_panel();await frames(3)
	check(not game.awaiting_character_choice and game.hud.system_panel.visible and snapshot()==old and FileAccess.get_file_as_bytes(path)==bytes,"取消新游戏完整返回旧游戏菜单，不覆盖旧数据")
	game.hud.system_panel.close_panel();await open_new_game()
	var temp_dir: String=path+".tmp"
	check(DirAccess.make_dir_absolute(temp_dir)==OK,"专用测试命名空间构造写盘失败，不触真实用户文件")
	game.character_select.select_gender("male");game.character_select.confirm_selection();await frames(4)
	check(game.awaiting_character_choice and game.character_select.visible and snapshot()==old and FileAccess.get_file_as_bytes(path)==bytes,"确认写盘失败完整回滚原进度与性别，保留重试界面")
	DirAccess.remove_absolute(temp_dir)
	game.character_select.close_panel();game.hud.system_panel.close_panel();await open_new_game()
	game.character_select.select_gender("male");game.character_select.confirm_selection();await frames(5)
	check(not game.awaiting_character_choice and Appearance.gender("player")=="male" and Appearance.gender()=="female","最终新游戏确认后采用男主女小京")
	check(Inventory.coins==120 and Inventory.count("carrot")==0 and GameClock.day==1,"正式新游戏才恢复初始农场，而非只换性别保留旧财富")
	check(GameState.control_mode=="joystick" and game.get_node("Audio").muted,"新旅程保留原操作模式与音量偏好")
	check(FileAccess.get_file_as_bytes(path+".before_new_game.bak")==bytes,"第一次确认前单独备份完整旧存档原字节")
	check(FarmSaveStore.read(path).appearance==CharacterAppearance.defaults(),"新的男主形象与联动已真正保存")

func restart_existing() -> void:
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	check(not game.awaiting_character_choice and not game.character_select.visible,"重开已有档直接继续，不重新弹出选择或重置外观")
	check(Appearance.gender("player")=="male" and game.player.get_node("Sprite2D").texture.resource_path==Appearance.player_asset(),"重建真实主场景后资源仍按保存外观恢复")
	game.persistence_enabled=false

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(5);await RenderingServer.frame_post_draw
	var path: String="res://builds/scheme-c-game-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
