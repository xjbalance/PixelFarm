extends "res://tests/runner.gd"
## 快捷栏保留九格及旧索引，仅检查显示同步、命中、反馈与现有动作取消。
const Touch=preload("res://tests/touch_navigation.gd")
var initial: Dictionary

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	initial=FarmSaveStore.snapshot(game)
	await switching()
	await quantities()
	await safe_modes()
	await layout()
	print("HOTBAR 03 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func touch(button: Control,index: int=61) -> void:
	var point:=button.get_global_rect().get_center()
	Touch.finger(self,point,true,index);Touch.finger(self,point,false,index)

func fresh() -> void:
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	GameState.set_control_mode("tap",false);game.tutorial.restore(GameTutorial.defaults(true))
	await Touch.place(self,game,"farm",Vector2(624,592))

func switching() -> void:
	await fresh()
	check(game.hud.tool_buttons.size()==9 and GameState.tools.slice(0,8)==["hoe","water","hand","carrot_seed","potato_seed","wheat_seed","axe","pickaxe"] and GameState.tools[8]=="fishing_rod","保留原八工具索引及现有第九格鱼竿")
	var positions: Array=[]
	for button in game.hud.tool_buttons: positions.append(button.get_instance_id())
	var at: Vector2=game.player.position
	var selected_correct:=true
	var styles_correct:=true
	for cycle in range(4):
		for index in range(9):
			await Touch.expand_hotbar(self,game)
			touch(game.hud.tool_buttons[index]);await frames(1)
			selected_correct=selected_correct and GameState.selected==index and game.auto_move.target.is_empty() and game.player.position==at
			for j in range(9):
				var style: StyleBox=game.hud.tool_buttons[j].get_theme_stylebox("normal")
				var expected: String="selected" if j==index else "button"
				styles_correct=styles_correct and style is StyleBoxTexture and (str(style.texture.get_meta("ui_role",""))==expected or style.texture.resource_path.ends_with("/"+expected+".png"))
	check(selected_correct,"36次原生触点切换准确选择同一格，不执行地图移动")
	check(styles_correct,"快速切换始终只有当前工具具有选中金色边框")
	var identity:=true
	for i in range(9): identity=identity and game.hud.tool_buttons[i].get_instance_id()==positions[i]
	check(identity,"快捷切换不销毁重建按钮或重复绑定节点")

func quantities() -> void:
	await fresh()
	var seed_index: int=GameState.tools.find("carrot_seed")
	Inventory.items.carrot_seed=7;Inventory.changed.emit()
	check(game.hud.tool_buttons[seed_index].text.contains("7"),"库存变化后种子7份立即同步快捷栏")
	check(Inventory.remove("carrot_seed",2) and game.hud.tool_buttons[seed_index].text.contains("5"),"消耗两份种子后快捷栏立即显示5份")
	Inventory.items.carrot_seed=Inventory.MAX_STACK;Inventory.changed.emit()
	check(game.hud.tool_buttons[seed_index].text.contains("999") and not Inventory.add("carrot_seed",1),"堆叠上限999显示正确，溢出失败不改数量")
	Inventory.items.carrot_seed=1;Inventory.changed.emit()
	GameState.select_tool(seed_index)
	game.farm.plots={"20,18":{"crop":"","days":0,"watered":false}}
	check(game.player.begin_farm_action(game.farm,Vector2i(20,18),"carrot_seed"),"使用现有农活动作生效入口消耗最后一份种子")
	await frames(18)
	check(Inventory.count("carrot_seed")==0 and not Inventory.items.has("carrot_seed") and game.farm.plots["20,18"].crop=="carrot","最后一粒成功播种后库存原规则移除零项")
	check(game.hud.tool_buttons[seed_index].text=="0" and game.hud.tool_name_label.text.contains("已用完"),"种子耗尽时独立数量和当前工具名称明确显示已用完")
	var energy: int=GameState.stamina
	game.farm.plots["21,18"]={"crop":"","days":0,"watered":false}
	game.player.position=Vector2(656,592)
	check(not game.player.begin_farm_action(game.farm,Vector2i(21,18),"carrot_seed") and GameState.stamina==energy and game.farm.plots["21,18"].crop=="","耗尽种子仍由原规则拒绝，不扣体力或错误种植")
	Inventory.items.carrot_seed=3;Inventory.changed.emit()
	check(game.hud.tool_buttons[seed_index].text.contains("3") and not game.hud.tool_name_label.text.contains("已用完"),"补充种子后数量与耗尽状态即时恢复")
	var style_ids: Array=[]
	for b in game.hud.tool_buttons: style_ids.append(b.get_theme_stylebox("normal").get_instance_id())
	var texts: Array=[]
	for b in game.hud.tool_buttons: texts.append(b.text)
	for i in range(60): GameClock.changed.emit()
	var retained:=true
	for i in range(9): retained=retained and style_ids[i]==game.hud.tool_buttons[i].get_theme_stylebox("normal").get_instance_id() and texts[i]==game.hud.tool_buttons[i].text
	check(retained,"60次无库存变化的时钟通知不重建快捷栏样式或改变显示")

func safe_modes() -> void:
	await fresh()
	game.auto_move.request(Vector2(784,496));await frames(4)
	await Touch.expand_hotbar(self,game)
	touch(game.hud.tool_buttons[2]);await frames(2)
	check(game.auto_move.target.is_empty() and game.player.auto_direction==Vector2.ZERO,"切工具继续取消旧自动路径和待交互")
	game.hud.inventory_panel.open_panel(false)
	var prior: int=GameState.selected
	touch(game.hud.tool_buttons[0]);await frames(2)
	check(GameState.selected==prior and game.auto_move.target.is_empty(),"背包打开时底层快捷栏触点被模态挡住")
	game.hud.inventory_panel.close_panel()
	GameState.set_control_mode("joystick",false)
	var joy: Control=game.hud.joystick
	Touch.finger(self,joy.get_global_rect().get_center()+Vector2(38,0),true,62)
	await Touch.expand_hotbar(self,game)
	touch(game.hud.tool_buttons[1],63);await frames(2)
	check(GameState.selected==1 and joy.finger==62 and game.player.touch_direction.x>.5,"备用摇杆与另一手指切工具兼容，不抢摇杆触点")
	Touch.finger(self,joy.get_global_rect().get_center(),false,62)
	GameState.set_control_mode("tap",false)
	await Touch.place(self,game,"farm",Vector2(624,592))
	game.farm.plots={"20,18":{"crop":"","days":0,"watered":false}}
	GameState.select_tool(3)
	check(game.player.begin_farm_action(game.farm,Vector2i(20,18),"carrot_seed"),"切工具取消回归开始一次未生效播种")
	var plants: int=Xiaojing.state.plants;var seeds: int=Inventory.count("carrot_seed")
	await Touch.expand_hotbar(self,game)
	touch(game.hud.tool_buttons[1]);await frames(20)
	check(game.player.farm_action.is_empty() and game.player.action_time==0 and game.farm.plots["20,18"].crop=="" and Inventory.count("carrot_seed")==seeds and Xiaojing.state.plants==plants,"起手时切快捷工具取消未生效农活，不扣种/刷520或残留动画")
	var diamonds: int=Xiaojing.state.diamonds
	for i in range(9):
		await Touch.expand_hotbar(self,game)
		touch(game.hud.tool_buttons[i])
	check(Xiaojing.state.diamonds==diamonds,"所有快捷栏操作不改变小京钻石数量")

func layout() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		game.hud.update_safe_area()
		await Touch.expand_hotbar(self,game)
		var legal:=true
		for button in game.hud.tool_buttons:
			legal=legal and button.size.x>=48 and button.size.y>=48 and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect())
			if not game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect()): print("HOTBAR LAYOUT ",button.text," ",button.get_global_rect()," safe ",game.hud.safe.get_global_rect()," min ",button.get_minimum_size()," font ",button.get_theme_font_size("font_size")," icon ",button.icon.get_size())
		check(legal,"九格快捷栏完整位于横屏安全区且至少48×48："+str(resolution))
	get_window().size=Vector2i(1280,720);await frames(4)
	game.hud.apply_safe_area(Rect2(64,0,1152,720),Vector2(1280,720));await frames(3)
	await Touch.expand_hotbar(self,game)
	var safe_layout:=true
	for button in game.hud.tool_buttons: safe_layout=safe_layout and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect())
	check(safe_layout,"模拟左右安全区后九格快捷栏仍可完整触达")
	game.hud.update_safe_area()
