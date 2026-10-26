extends "res://tests/runner.gd"
## UI05 compact HUD：真实控件和触点，原工具/资源/场景业务不替代。
const Touch=preload("res://tests/touch_navigation.gd")

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	await Touch.place(self,game,"farm",Vector2(656,480));GameState.select_tool(3);await frames(3)
	await compact_tools()
	await menu_navigation()
	await guide_and_camera()
	await configurations()
	UIMetrics.screen_provider=Callable()
	print("UI05 HOTBAR RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func visible_tools() -> Array[int]:
	var result: Array[int]=[]
	for child in game.hud.toolbar.get_children():
		var index: int=game.hud.tool_buttons.find(child)
		if index>=0 and child.is_visible_in_tree(): result.append(index)
	return result

func touch(control: Control,index: int=301) -> void:
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(2)
	var point:=control.get_global_rect().get_center()
	Touch.finger(self,point,true,index);Touch.finger(self,point,false,index)
	await frames(2)

func button(root: Node,caption: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text==caption: return child
		var found:=button(child,caption)
		if found: return found
	return null

func compact_tools() -> void:
	check(game.hud.tool_buttons.size()==9 and not game.hud.hotbar_expanded and visible_tools()==[2,3,4],"默认只显示前一/当前/后一工具，保留九个原始槽与索引")
	check(game.hud.tool_buttons[3].text==str(Inventory.count("carrot_seed")) and game.hud.tool_name_label.text.contains("胡萝卜"),"当前种子数量与单行名称独立清晰显示")
	var proof:=FarmSaveStore.snapshot(game)
	await touch(game.hud.cycle_button)
	check(game.hud.hotbar_expanded and visible_tools()==[0,1,2,3,4,5,6,7,8] and game.hud.toolbar.columns==3,"原生展开按钮展示原顺序3×3九格工具")
	check(FarmSaveStore.snapshot(game)==proof and game.auto_move.target.is_empty(),"只展开工具不修改资源、角色进度或生成地图意图")
	var correct:=true
	var identities: Array=[]
	for tool in game.hud.tool_buttons: identities.append(tool.get_instance_id())
	for index in range(9):
		game.hud.expand_hotbar();await frames(2)
		await touch(game.hud.tool_buttons[index])
		var expected: Array[int]=[posmod(index-1,9),index,posmod(index+1,9)]
		correct=correct and GameState.selected==index and not game.hud.hotbar_expanded and visible_tools()==expected and game.auto_move.target.is_empty()
	check(correct,"九个工具真实点击绑定正确且选择后恢复三邻槽，不穿透地图")
	var retained:=true
	for i in range(9): retained=retained and identities[i]==game.hud.tool_buttons[i].get_instance_id()
	check(retained,"展开/折叠只重排原按钮，不销毁重建工具节点")
	game.hud.expand_hotbar();GameState.select_tool(0);await frames(2)
	check(visible_tools()==[8,0,1] and not game.hud.hotbar_expanded,"键盘/既有工具选择信号也折叠并正确环绕鱼竿到锄头")
	GameState.select_tool(3);Inventory.items.carrot_seed=0;Inventory.items.erase("carrot_seed");Inventory.changed.emit();await frames(2)
	check(game.hud.tool_buttons[3].text=="0" and game.hud.tool_name_label.text.contains("已用完"),"零种子在独立数量与当前名称处提示，不显示错误剩余量")
	Inventory.items.carrot_seed=7;Inventory.changed.emit();await frames(2)
	check(game.hud.tool_buttons[3].text=="7" and not game.hud.tool_name_label.text.contains("已用完"),"补货后数量与已用完提示同步恢复")
	GameState.set_control_mode("joystick",false)
	var joy: Control=game.hud.joystick
	Touch.finger(self,joy.get_global_rect().get_center()+Vector2(40,0),true,302)
	await touch(game.hud.tool_buttons[4],303)
	check(GameState.selected==4 and joy.finger==302 and game.player.touch_direction.x>.5,"备用摇杆的一根手指与三槽工具另一根手指兼容")
	Touch.finger(self,joy.get_global_rect().get_center(),false,302)
	GameState.set_control_mode("tap",false);await frames(4)

func menu_navigation() -> void:
	for spec in [["背包 B",game.hud.inventory_panel],["委托 J",game.hud.progress_panel],["手记 M",game.hud.story_panel]]:
		await touch(game.hud.menu_button)
		check(game.hud.system_panel.visible and GameState.modal,"唯一顶部菜单入口可用："+str(spec[0]))
		var entry:=button(game.hud.system_panel,spec[0])
		check(entry!=null,"菜单保留原背包/委托/手记触屏入口："+str(spec[0]))
		if entry: await touch(entry)
		check(spec[1].visible and not game.hud.system_panel.visible and GameState.modal,"菜单导航先关闭旧模态再打开原面板："+str(spec[0]))
		while game.hud.close_active_panel(): pass
		await frames(2)

func guide_and_camera() -> void:
	GameState.select_tool(3);game.change_location("farm",Vector2(656,480));await frames(5)
	check(game.hud.guide_collapsed and not game.hud.progress_label.visible and not game.hud.quest_label.visible,"任务默认收为一行，正文只在主动展开时显示")
	var proof:=FarmSaveStore.snapshot(game)
	await touch(game.hud.guide_toggle)
	check(not game.hud.guide_collapsed and game.hud.progress_label.visible and game.hud.quest_label.visible,"真实点击任务标题仍可读取原完整任务")
	await touch(game.hud.guide_toggle)
	check(game.hud.guide_collapsed and FarmSaveStore.snapshot(game)==proof,"任务折叠/展开不修改原任务或存档结构")
	check(game.camera_rig.begin_free_look(),"回中心布局检查从真实空闲自由观察开始")
	game.camera_rig.pan_screen(Vector2(100,0));game.camera_rig.end_free_look();await frames(3)
	var back: Button=game.camera_rig.return_button
	check(back.is_visible_in_tree() and game.hud.safe.get_global_rect().grow(.5).encloses(back.get_global_rect()) and back.get_global_rect().end.y<=game.hud.cycle_button.get_global_rect().position.y,"原回中心按钮可见且在右下工具上方，不新增第二份回调")
	await touch(back);await frames(40)
	check(game.camera_rig.mode==game.camera_rig.Mode.FOLLOW and game.camera_rig.screen_error().length()<1,"重排后的原生回中心触点仍恢复人物跟随")

func configurations() -> void:
	for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(4);game.hud.update_safe_area()
		for target in [48,64,96]:
			UIMetrics.screen_provider=func(): return {"dpi":float(target)*160.0/48.0,"physical":Vector2(size),"canvas":Vector2(size)}
			game.hud.collapse_hotbar();await frames(3)
			var compact_ok:=true
			for control in game.hud.tool_buttons:
				if not control.is_visible_in_tree(): continue
				compact_ok=compact_ok and control.size.x>=target and control.size.y>=target and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect())
			compact_ok=compact_ok and game.hud.menu_button.size.x>=target and game.hud.menu_button.size.y>=target
			check(compact_ok,"三槽与菜单满足触区并处于安全区："+str(size)+" target"+str(target))
			game.hud.expand_hotbar();await frames(3)
			var expanded_ok:=true
			for control in game.hud.tool_buttons: expanded_ok=expanded_ok and control.size.x>=target and control.size.y>=target and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect())
			check(expanded_ok,"3×3展开九格在同一触区标准下全部可达："+str(size)+" target"+str(target))
			game.hud.collapse_hotbar()
