extends "res://tests/runner.gd"
## 全局UI矩阵：真实窗口尺寸/原生触点/每个已存在模态面板；不称作Android真机或dp测试。
const Touch=preload("res://tests/touch_navigation.gd")
var prefix: String=""
var visited: Dictionary={}
var issues: Array=[]
var specimen: int=0

func run() -> void:
	theme_materials()
	if "--theme-only" in OS.get_cmdline_user_args():
		print("UI 04 THEME RESULT: %d checks, %d failures" % [checked,failed])
		get_tree().quit(1 if failed else 0);return
	var density_only: bool="--density-only" in OS.get_cmdline_user_args()
	if not density_only:
		var configurations: Array=[Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]
		for size in configurations:
			await one_configuration(size,false)
		await one_configuration(Vector2i(1280,720),true)
	UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(2400,1080),"canvas":Vector2(1600,720)}
	check(UIMetrics.minimum_target()==96,"注入480DPI校准样本后实际控件最小触区为96逻辑像素")
	await one_configuration(Vector2i(1600,720),false)
	UIMetrics.screen_provider=func(): return {"dpi":320.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	check(UIMetrics.minimum_target()==64,"注入320DPI校准样本后实际控件最小触区为64逻辑像素")
	await one_configuration(Vector2i(1280,720),false,true)
	UIMetrics.screen_provider=Callable()
	var file:=FileAccess.open("res://builds/"+("ui04-density-matrix.json" if density_only else "ui04-matrix.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"Linux Xvfb/Mesa rendered window","android_device_tested":false,"unit":"Godot logical pixels; not physical dp","checks":checked,"failures":failed,"issues":issues},"\t"));file.close()
	print("UI 04 RESULT: %d checks, %d failures" % [checked,failed])
	get_tree().quit(1 if failed else 0)

func luminance(tint: Color) -> float:
	var linear:=tint.srgb_to_linear()
	return .2126*linear.r+.7152*linear.g+.0722*linear.b

func contrast(a: Color,b: Color) -> float:
	var x:=luminance(a);var y:=luminance(b)
	return (maxf(x,y)+.05)/(minf(x,y)+.05)

func theme_materials() -> void:
	var theme:=FarmUIStyle.make_theme()
	var material_ok:=true
	for role in ["paper","secondary","button","hover","pressed","disabled","focus","selected","nature","star","danger","track","fill"]:
		var box: StyleBoxTexture=FarmUIStyle.surface(role)
		material_ok=material_ok and box.texture!=null and box.texture.get_width()>box.get_texture_margin(SIDE_LEFT)+box.get_texture_margin(SIDE_RIGHT) and box.texture.get_height()>box.get_texture_margin(SIDE_TOP)+box.get_texture_margin(SIDE_BOTTOM)
	check(material_ok,"公共九宫格材质均能加载，中心与边框有合法拉伸范围")
	check(theme.get_stylebox("panel","PanelContainer") is StyleBoxTexture and theme.get_stylebox("normal","Button") is StyleBoxTexture,"公共纸面与按钮实际使用可拉伸纹理主题")
	var paper: StyleBoxTexture=theme.get_stylebox("panel","PanelContainer")
	var image: Image=paper.texture.get_image();var worst: float=INF
	for y in range(int(paper.get_texture_margin(SIDE_TOP)),image.get_height()-int(paper.get_texture_margin(SIDE_BOTTOM))):
		for x in range(int(paper.get_texture_margin(SIDE_LEFT)),image.get_width()-int(paper.get_texture_margin(SIDE_RIGHT))): worst=minf(worst,contrast(FarmUIStyle.TEXT,image.get_pixel(x,y)))
	check(worst>=4.5,"主正文与真实纸面纹理每个中心像素的最低对比度≥4.5（实测%.2f）" % worst)
	var states_ok:=true
	for state in [["normal","font_color"],["hover","font_hover_color"],["pressed","font_pressed_color"]]:
		var box: StyleBoxTexture=theme.get_stylebox(state[0],"Button")
		var texture: Image=box.texture.get_image()
		var background: Color=texture.get_pixel(texture.get_width()/2,texture.get_height()/2)
		states_ok=states_ok and contrast(theme.get_color(state[1],"Button"),background)>=4.5
	check(states_ok,"按钮普通/悬停/按下三态文字与各自实际材质对比度≥4.5")
	check(UIMetrics.logical_touch_size(320,Vector2(1920,1080),Vector2(1280,720))==64,"320DPI与1.5倍画布缩放时48dp纯换算为64逻辑像素")
	check(UIMetrics.logical_touch_size(480,Vector2(2400,1080),Vector2(1600,720))==96,"480DPI与1.5倍画布缩放时48dp纯换算为96逻辑像素")
	check(UIMetrics.logical_touch_size(0,Vector2(1920,1080),Vector2(1280,720))==48,"缺少设备密度时触区换算安全回退48逻辑像素")

func one_configuration(size: Vector2i, safe_area: bool, representative: bool=false) -> void:
	# 控件初始布局必须面对实际比例，避免只在实例化后拉伸掩盖首帧溢出。
	get_window().size=size;await frames(3)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	load("res://tests/star_runner.gd").fixture(game,true)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Inventory.coins=12345;Inventory.items={"carrot_seed":8,"potato_seed":6,"wheat_seed":4,"carrot":20,"potato":12,"wheat":12,"wood":99,"stone":99,"iron_bar":99,"crystal":99,"fishing_bait":30,"fish_feed":30,"hay":30,"potato_bread":3}
	Xiaojing.state.diamonds=1400
	if safe_area: game.hud.apply_safe_area(Rect2(64,0,size.x-128,size.y),Vector2(size))
	await frames(4);prefix=str(size)+( " safe64" if safe_area else "")+(" target%d" % int(UIMetrics.minimum_target()) if UIMetrics.minimum_target()>48 else "")
	visited.clear()
	await toolbar()
	await task_card()
	if representative:
		await density_representatives()
	else:
		await general_panels()
		await facility_panels()
		await married_panels()
	var covered:=true;var omitted: Array[String]=[]
	for panel in get_tree().get_nodes_in_group("modal_panels"):
		if game.is_ancestor_of(panel) and not visited.has(panel.get_instance_id()): covered=false;omitted.append(panel.get_script().resource_path.get_file())
	if not representative: check(covered,prefix+"全部既有模态面板均通过实际公开入口被打开"+str(omitted))
	while game.hud.close_active_panel(): pass
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(5)

func at(area: String, point: Vector2) -> void:
	while game.hud.close_active_panel(): pass
	game.change_location(area,point);await frames(4)

func buttons(root: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child in root.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(buttons(child))
	return result

func labels(root: Node) -> Array[Label]:
	var result: Array[Label]=[]
	for child in root.get_children():
		if child is Label and child.is_visible_in_tree(): result.append(child)
		result.append_array(labels(child))
	return result

func reveal(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(2)

func find_button(root: Node, caption: String) -> Button:
	for button in buttons(root):
		if button.text.begins_with(caption): return button
	return null

func tap(button: Button,index: int=260) -> void:
	if not is_instance_valid(button): check(false,prefix+"公开交互按钮存在");return
	await reveal(button)
	var point: Vector2=button.get_global_rect().get_center()
	Touch.finger(self,point,true,index);Touch.finger(self,point,false,index);await frames(3)

func audit(panel: Control, title: String) -> void:
	await frames(4)
	visited[panel.get_instance_id()]=true
	check(panel.visible and GameState.modal and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),prefix+" "+title+"面板在安全区内")
	var touch_size:=true;var reach:=true;var text_width:=true;var detail: Array[String]=[]
	var required: float=UIMetrics.minimum_target()
	var all:=buttons(panel)
	for button in all:
		if button.size.x<required or button.size.y<required: touch_size=false;detail.append("size "+button.text)
		await reveal(button)
		if not panel.get_global_rect().grow(.5).encloses(button.get_global_rect()) or not game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect()): reach=false;detail.append("outside "+button.text)
		if button.has_method("contains_touch") and not button.contains_touch(button.get_global_rect().get_center()): reach=false;detail.append("clip "+button.text)
		if button.get_minimum_size().x>button.size.x+.5: text_width=false;detail.append("button text "+button.text)
	for label in labels(panel):
		# 多行正文可纵向滚动，但不应宽于模态边框或自身容器。
		var rect: Rect2=label.get_global_rect();var limits: Rect2=panel.get_global_rect()
		if rect.position.x<limits.position.x-.5 or rect.end.x>limits.end.x+.5: text_width=false;detail.append("label "+label.text.left(25))
	check(not all.is_empty() and touch_size,prefix+" "+title+"主要按钮至少%d逻辑像素" % int(required))
	check(reach,prefix+" "+title+"全部按钮可滚入并命中合法触区")
	check(text_width,prefix+" "+title+"中文正文与按钮不横向溢出")
	if not detail.is_empty(): issues.append({"configuration":prefix,"panel":title,"detail":detail})
	var at_player: Vector2=game.player.position;var calls: int=game.auto_move.execution_count
	var blank: Vector2=panel.get_global_rect().position+Vector2(24,24)
	Touch.finger(self,blank,true,261);Touch.finger(self,blank,false,261);await frames(2)
	check(game.player.position==at_player and game.auto_move.execution_count==calls and game.auto_move.target.is_empty(),prefix+" "+title+"触摸不穿透到地图")

func toolbar() -> void:
	await at("farm",Vector2(656,480))
	var correct:=true;var dimensions:=true
	var required: float=UIMetrics.minimum_target()
	for i in range(game.hud.tool_buttons.size()):
		await Touch.expand_hotbar(self,game)
		var button: Button=game.hud.tool_buttons[i]
		dimensions=dimensions and button.size.x>=required and button.size.y>=required and game.hud.safe.get_global_rect().grow(.5).encloses(button.get_global_rect())
		await tap(button)
		correct=correct and GameState.selected==i and game.auto_move.target.is_empty()
	check(dimensions and game.hud.tool_buttons.size()==9,prefix+"九格快捷栏完整可见并有足够触区")
	check(correct,prefix+"九个快捷工具实际原生触点准确命中")

func task_card() -> void:
	if game.hud.guide_collapsed: await tap(game.hud.guide_toggle)
	var proof: Dictionary=FarmSaveStore.snapshot(game)
	var expanded_height: float=game.hud.guide_panel.size.y
	await tap(game.hud.guide_toggle)
	check(game.hud.guide_collapsed and not game.hud.progress_label.visible and not game.hud.quest_label.visible and game.hud.guide_panel.size.y<expanded_height,prefix+"任务卡原生点击可折叠并释放地图空间")
	check(FarmSaveStore.snapshot(game)==proof,prefix+"折叠任务卡不改变物品、任务、日期或关系进度")
	await tap(game.hud.guide_toggle)
	check(not game.hud.guide_collapsed and game.hud.progress_label.visible and game.hud.quest_label.visible and FarmSaveStore.snapshot(game)==proof,prefix+"任务卡原生还原后正文恢复且状态守恒")

func general_panels() -> void:
	game.hud.inventory_panel.open_panel(false);await audit(game.hud.inventory_panel,"背包");game.hud.inventory_panel.close_panel()
	game.hud.inventory_panel.open_panel(true);await audit(game.hud.inventory_panel,"商店");await capture("shop");game.hud.inventory_panel.close_panel()
	game.hud.progress_panel.open_panel("journal",false);await audit(game.hud.progress_panel,"委托日志");game.hud.progress_panel.close_panel()
	game.hud.progress_panel.open_panel("workshop",true);await audit(game.hud.progress_panel,"建设图纸");game.hud.progress_panel.close_panel()
	game.hud.story_panel.open_panel();game.hud.story_panel.select_page(2);await audit(game.hud.story_panel,"村民手记");game.hud.story_panel.close_panel()
	game.hud.dialogue.open_dialogue("林芽",["湖里的鱼和田里的麦子都需要留些余地。今天慢慢来，明天还会有新的收获。你带来的留种笔记，我会替你收好。"])
	await audit(game.hud.dialogue,"NPC中文长对话");await capture("dialogue")
	await tap(find_button(game.hud.dialogue,"稍后再聊"));check(not GameState.modal,prefix+"NPC长对话可原生关闭")
	game.hud.system_panel.open_panel();await audit(game.hud.system_panel,"设置菜单")
	await tap(find_button(game.hud.system_panel,"操作与生活指南"));await audit(game.hud.system_panel,"生活指南长文")
	await tap(find_button(game.hud.system_panel,"返回设置"));game.hud.system_panel.close_panel()
	game.hud.calendar_panel.open_panel();await audit(game.hud.calendar_panel,"四季天气日历");game.hud.calendar_panel.close_panel()
	game.hud.mine_panel.open_panel("journal");await audit(game.hud.mine_panel,"矿道手记");game.hud.mine_panel.close_panel()
	game.hud.star_panel.open_panel("overview");await audit(game.hud.star_panel,"星星专属手记");game.hud.star_panel.close_panel()
	game.hud.social_panel.open_panel("linya");await audit(game.hud.social_panel,"村民个人事件");game.hud.social_panel.close_panel()

func density_representatives() -> void:
	game.hud.inventory_panel.open_panel(false);await audit(game.hud.inventory_panel,"背包");game.hud.inventory_panel.close_panel()
	game.hud.inventory_panel.open_panel(true);await audit(game.hud.inventory_panel,"商店");await capture("shop");game.hud.inventory_panel.close_panel()
	game.hud.dialogue.open_dialogue("林芽",["湖里的鱼和田里的麦子都需要留些余地。今天慢慢来，明天还会有新的收获。你带来的留种笔记，我会替你收好。"])
	await audit(game.hud.dialogue,"NPC中文长对话");await capture("dialogue")
	await tap(find_button(game.hud.dialogue,"稍后再聊"));check(not GameState.modal,prefix+"NPC长对话可原生关闭")
	game.hud.system_panel.open_panel();await audit(game.hud.system_panel,"设置菜单")
	await tap(find_button(game.hud.system_panel,"操作与生活指南"));await audit(game.hud.system_panel,"生活指南长文")
	await tap(find_button(game.hud.system_panel,"返回设置"));game.hud.system_panel.close_panel()

func facility_panels() -> void:
	await at("farm",Recovery.BENCH+Vector2(0,32));game.hud.recovery_panel.open_panel();await audit(game.hud.recovery_panel,"白天休息与食物");game.hud.recovery_panel.close_panel()
	await at("farm",Aquaculture.SITES.pen_1+Vector2(-32,0));game.hud.aquaculture_panel.open_panel("pen_1");await audit(game.hud.aquaculture_panel,"湖泊鱼栏");game.hud.aquaculture_panel.close_panel()
	await at("farm",LakeEcology.SHORE+Vector2(0,32));game.hud.ecology_panel.open_panel();await audit(game.hud.ecology_panel,"湖泊生态");game.hud.ecology_panel.close_panel()
	await at("farm",Livestock.SITES.coop+Vector2(0,32));game.hud.livestock_panel.open_panel("coop");await audit(game.hud.livestock_panel,"畜牧管理");game.hud.livestock_panel.close_panel()
	await at("home",Kitchen.ANCHOR+Vector2(0,32));game.hud.kitchen_panel.open_panel();await audit(game.hud.kitchen_panel,"厨房加工");game.hud.kitchen_panel.close_panel()
	await at("home",Housing.HOME+Vector2(32,0));game.hud.housing_panel.open_panel("home");await audit(game.hud.housing_panel,"家具摆放");game.hud.housing_panel.close_panel()
	var event: Dictionary=Festival.data.events.spring
	await at(event.area,Vector2(event.board[0],event.board[1])+Vector2(0,32));game.hud.festival_panel.open_panel("spring");await audit(game.hud.festival_panel,"季节节日");game.hud.festival_panel.close_panel()
	var entrance: Dictionary=Exploration.definition("forest_entry")
	await at(entrance.area,Exploration.point("forest_entry")+Vector2(0,32));game.hud.exploration_panel.open_panel("forest_entry");await audit(game.hud.exploration_panel,"隐藏地图调查");game.hud.exploration_panel.close_panel()
	await at("village",WorldDevelopment.anchor("board")+Vector2(0,32));game.hud.world_development_panel.open_panel("board");await audit(game.hud.world_development_panel,"永久世界共建");game.hud.world_development_panel.close_panel()
	await at("farm",Fishing.point("farm_lake")+Vector2(-32,0));GameState.select_tool(8)
	game.hud.fishing_panel.open_panel("farm_lake");await audit(game.hud.fishing_panel,"钓鱼准备")
	var casts: int=Fishing.state.serial;await tap(find_button(game.hud.fishing_panel,"向水面抛竿"))
	check(Fishing.active() and Fishing.state.serial==casts+1,prefix+"真实触屏开始一轮钓鱼，不重复抛竿")
	if is_instance_valid(game.hud.fishing_panel.hold):
		var hold: Control=game.hud.fishing_panel.hold;await reveal(hold)
		var point: Vector2=hold.get_global_rect().get_center();Touch.finger(self,point,true,262)
		var hold_legal: bool=hold.held and hold.size.x>=UIMetrics.minimum_target() and hold.size.y>=UIMetrics.minimum_target() and game.hud.safe.get_global_rect().grow(.5).encloses(hold.get_global_rect())
		check(hold_legal,prefix+"小游戏长按控件可达且实际认领触点")
		if not hold_legal: issues.append({"configuration":prefix,"panel":"钓鱼长按","size":str(hold.size),"rect":str(hold.get_global_rect()),"held":hold.held})
		Touch.finger(self,point,false,262)
	game.hud.fishing_panel.close_panel()

func married_panels() -> void:
	await at("farm",Vector2(656,480));game.hud.abyss_panel.open_panel("legend");await audit(game.hud.abyss_panel,"终局试炼与深渊记录");game.hud.abyss_panel.close_panel()
	await at("greenhouse",Vector2(640,700))
	check(Xiaojing.state.married and GameState.location=="greenhouse",prefix+"已婚温室场景以真实前置正常进入")
	game.hud.river_panel.open_panel("vows");await audit(game.hud.river_panel,"温室已婚互动");game.hud.river_panel.close_panel()
	game.hud.xiaojing_panel.open_panel();await audit(game.hud.xiaojing_panel,"小京婚后关系");await capture("married");game.hud.xiaojing_panel.close_panel()

func capture(label: String) -> void:
	if prefix!=str(Vector2i(1280,720)) and not prefix.contains("safe64") and not prefix.contains("target"): return
	await RenderingServer.frame_post_draw
	var tag: String="target%d" % int(UIMetrics.minimum_target()) if prefix.contains("target") else ("safe" if prefix.contains("safe64") else "wide")
	get_viewport().get_texture().get_image().save_png("res://builds/ui04-"+label+"-"+tag+".png")
