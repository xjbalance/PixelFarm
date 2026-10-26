extends "res://tests/ui04_runner.gd"
## UI05布局契约：复用旧公开入口/滚动辅助，只检查新布局，不重复主题与全业务矩阵。
var samples: Array=[]
var screenshot_paths: Array[String]=[]
var configuration: String=""

func run() -> void:
	var representative: bool="--representative-only" in OS.get_cmdline_user_args()
	if not representative:
		await layout_configuration(Vector2i(1280,720),48,false,true)
		for size in [Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
			await layout_configuration(size,48,false,false)
		await layout_configuration(Vector2i(1280,720),48,true,false)
	await layout_configuration(Vector2i(1280,720),64,false,false)
	await layout_configuration(Vector2i(1600,720),96,true,false)
	UIMetrics.screen_provider=Callable()
	var file:=FileAccess.open("res://builds/UI05/layout-matrix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":DisplayServer.get_name(),"android_device_tested":false,"checks":checked,"failures":failed,"samples":samples,"issues":issues,"screenshots":screenshot_paths},"\t"));file.close()
	print("UI05 LAYOUT RESULT: %d checks, %d failures" % [checked,failed])
	get_tree().quit(1 if failed else 0)

func layout_configuration(size: Vector2i,target: int,inset: bool,all_panels: bool) -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/UI05")
	get_window().size=size;await frames(3)
	UIMetrics.screen_provider=func(): return {"dpi":float(target)*160.0/48.0,"physical":Vector2(size),"canvas":Vector2(size)}
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	load("res://tests/star_runner.gd").fixture(game,true)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Inventory.coins=12345;Inventory.items={"carrot_seed":8,"potato_seed":6,"wheat_seed":4,"carrot":20,"potato":12,"wheat":12,"wood":99,"stone":99,"iron_bar":99,"crystal":99,"fishing_bait":30,"fish_feed":30,"hay":30,"potato_bread":3}
	Xiaojing.state.diamonds=1400
	if inset: game.hud.apply_safe_area(Rect2(64,0,size.x-128,size.y),Vector2(size))
	await frames(4)
	configuration="%dx%d-target%d%s" % [size.x,size.y,target,"-safe64" if inset else ""]
	prefix=configuration;visited.clear()
	await compact_toolbar()
	await inventory_layout(false)
	await inventory_layout(true)
	await quest_layout()
	await bottom_dialogue()
	await show_panel(game.hud.system_panel,[],"设置菜单")
	await show_panel(game.hud.xiaojing_panel,[],"小京关系")
	await at("home",Kitchen.ANCHOR+Vector2(0,32));await show_panel(game.hud.kitchen_panel,[],"厨房")
	await at("farm",Aquaculture.SITES.pen_1+Vector2(-32,0));await show_panel(game.hud.aquaculture_panel,["pen_1"],"湖岸鱼栏")
	if all_panels:
		await remaining_public_panels()
		var omitted: Array[String]=[]
		for panel in get_tree().get_nodes_in_group("modal_panels"):
			if game.is_ancestor_of(panel) and not visited.has(panel.get_instance_id()): omitted.append(panel.get_script().resource_path.get_file())
		check(omitted.is_empty(),prefix+"一次基准遍历覆盖所有既有modal公开入口"+str(omitted))
	while game.hud.close_active_panel(): pass
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(5)

func show_panel(panel: Control,arguments: Array,title: String) -> void:
	while game.hud.close_active_panel(): pass
	panel.callv("open_panel",arguments)
	await audit(panel,title)
	if panel.visible: panel.close_panel()

func audit(panel: Control,title: String) -> void:
	await frames(4);visited[panel.get_instance_id()]=true
	var bounds: Rect2=panel.get_global_rect();var safe_bounds: Rect2=game.hud.safe.get_global_rect()
	check(panel.is_visible_in_tree() and GameState.modal and safe_bounds.grow(.5).encloses(bounds),prefix+" "+title+"公开打开且实际边框在安全区内")
	var reachable:=true;var readable:=true;var reasons: Array[String]=[]
	var target: float=UIMetrics.minimum_target();var active: Array[Button]=buttons(panel)
	for control in active:
		await reveal(control)
		var rect: Rect2=control.get_global_rect()
		if control.size.x<target or control.size.y<target or not safe_bounds.grow(.5).encloses(rect) or not panel.get_global_rect().grow(.5).encloses(rect):
			reachable=false;reasons.append("触区/边界:"+control.text.left(24))
		if control.has_method("contains_touch") and not control.contains_touch(rect.get_center()): reachable=false;reasons.append("裁剪:"+control.text.left(24))
		if control.get_minimum_size().x>control.size.x+.5: readable=false;reasons.append("按钮文字:"+control.text.left(24))
	for label in labels(panel):
		var rect: Rect2=label.get_global_rect()
		if rect.position.x<bounds.position.x-.5 or rect.end.x>bounds.end.x+.5: readable=false;reasons.append("横向文字:"+label.text.left(24))
	check(not active.is_empty() and reachable,prefix+" "+title+"全部主要按钮≥%d且可滚入并命中" % int(target))
	check(readable,prefix+" "+title+"中文与按钮不横向溢出")
	samples.append({"configuration":configuration,"panel":title,"rect":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"button_count":active.size(),"reachable":reachable,"readable":readable})
	if not reasons.is_empty(): issues.append({"configuration":configuration,"panel":title,"reasons":reasons})

func compact_toolbar() -> void:
	await at("farm",Vector2(656,480));game.hud.collapse_hotbar();await frames(3)
	var visible:=0
	for control in game.hud.tool_buttons:
		if control.is_visible_in_tree(): visible+=1
	check(visible==3 and not game.hud.hotbar_expanded,prefix+"地图常驻工具仅三个邻槽")
	game.hud.expand_hotbar();await frames(3)
	var legal:=true
	for control in game.hud.tool_buttons: legal=legal and control.is_visible_in_tree() and game.hud.safe.get_global_rect().grow(.5).encloses(control.get_global_rect()) and control.size.x>=UIMetrics.minimum_target() and control.size.y>=UIMetrics.minimum_target()
	check(legal and game.hud.toolbar.columns==3,prefix+"完整工具为可触达的原九格3×3，不因比例降触区")
	game.hud.collapse_hotbar()

func inventory_layout(shop: bool) -> void:
	var panel: PanelContainer=game.hud.inventory_panel
	panel.open_panel(shop);await frames(4);panel.select_item("carrot");await audit(panel,"商店" if shop else "背包")
	var grid: Rect2=panel.scroll.get_global_rect();var details: Rect2=panel.details_scroll.get_global_rect()
	check(panel.item_grid.columns>=2 and grid.end.x<=details.position.x+.5 and details.size.x>=240,prefix+" "+("商店" if shop else "背包")+"多列网格在左、详情在右且互不叠压")
	check(panel.selected_item=="carrot" and panel.selected_detail.text.contains(Catalog.item_name("carrot")) and panel.selected_detail.text.contains(str(Inventory.count("carrot"))) and panel.selected_icon.texture!=null,prefix+"选中项图标/名称/数量进入独立详情区")
	await capture("shop-grid" if shop else "inventory-grid")
	panel.close_panel()

func quest_layout() -> void:
	var panel: PanelContainer=game.hud.progress_panel
	panel.open_panel("journal",false);await audit(panel,"任务日志")
	check(panel.tabs is VBoxContainer and not panel.body.vertical and panel.list_scroll.get_global_rect().end.x<=panel.detail_scroll.get_global_rect().position.x+.5,prefix+"任务采用左侧纵向列表与右侧详情")
	var ids: Array=panel.tab_buttons.keys()
	if ids.size()>1:
		var next_id: String=str(ids[1]);var before: Dictionary=FarmSaveStore.snapshot(game)
		await tap(panel.tab_buttons[next_id])
		check(panel.selected_id==next_id and panel.heading.text.length()>0 and FarmSaveStore.snapshot(game)==before,prefix+"点左列表更新右详情，查看不会提交任务或消耗")
	await capture("quest-columns");panel.close_panel()

func bottom_dialogue() -> void:
	Events.dialogue_requested.emit("阿禾",[{"who":"阿禾","portrait":"ahe","text":"窗台的第一盆花开了。留言册不用换新本，旧页后面还有空白。等你把今天的收获放好，我们再一起核对河岸的记号。每一页都留给亲自走过这些路的人，不必赶着把故事翻完。"}])
	var panel: PanelContainer=game.hud.dialogue
	await audit(panel,"底部中文长对话")
	var rect: Rect2=panel.get_global_rect();var safe_bounds: Rect2=game.hud.safe.get_global_rect()
	check(rect.position.y>=safe_bounds.position.y+safe_bounds.size.y*.45 and safe_bounds.end.y-rect.end.y<=maxf(48,UIMetrics.minimum_target()) and rect.end.y<=safe_bounds.end.y+.5,prefix+"对话锚定下方且不跑到屏幕中央或越过底边")
	check(panel.portrait.size.x<=112 and panel.body_label.text.length()>70,prefix+"长正文与较小头像共享下方对话区")
	await capture("dialogue-bottom");panel.close_dialogue()
	panel.open_story("festival")
	for i in range(20):
		if panel.choices_box.visible: break
		panel.advance()
	await frames(4)
	check(panel.choices_box.visible and panel.choices_box.get_child_count()==3 and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),prefix+"剧情末尾三个选项出现后向上扩展，仍完整位于安全区")
	var options_reachable:=true
	for option in panel.choices_box.get_children():
		options_reachable=options_reachable and game.hud.safe.get_global_rect().encloses(option.get_global_rect()) and option.size.y>=UIMetrics.minimum_target()
	check(options_reachable,prefix+"后出现的三个剧情选项均可见且保持触区")
	await capture("dialogue-choices");panel.close_dialogue()

func remaining_public_panels() -> void:
	await at("home",game.home_rest.SOFA+Vector2(0,36));check(game.home_rest.open(),prefix+"真实靠近沙发打开确认");await audit(game.home_rest.panel,"沙发小睡确认");game.home_rest.close_panel()
	await at("farm",Vector2(656,480))
	for entry in [[game.hud.story_panel,[],"村庄手记"],[game.hud.calendar_panel,[],"四季日历"],[game.hud.mine_panel,["journal"],"矿道手记"],[game.hud.star_panel,["overview"],"星星手记"],[game.hud.social_panel,["linya"],"村民近况"],[game.hud.abyss_panel,["legend"],"深渊试炼"],[game.hud.river_panel,["journal"],"河湾剧情"]]:
		await show_panel(entry[0],entry[1],entry[2])
	game.hud.progress_panel.open_panel("workshop",true);await audit(game.hud.progress_panel,"建设图纸");game.hud.progress_panel.close_panel()
	await at("farm",Recovery.BENCH+Vector2(0,32));await show_panel(game.hud.recovery_panel,[],"白天恢复")
	await at("farm",LakeEcology.SHORE+Vector2(0,32));await show_panel(game.hud.ecology_panel,[],"湖泊生态")
	await at("farm",Livestock.SITES.coop+Vector2(0,32));await show_panel(game.hud.livestock_panel,["coop"],"畜牧管理")
	await at("home",Housing.HOME+Vector2(32,0));await show_panel(game.hud.housing_panel,["home"],"家具摆放")
	var event: Dictionary=Festival.data.events.spring
	await at(event.area,Vector2(event.board[0],event.board[1])+Vector2(0,32));await show_panel(game.hud.festival_panel,["spring"],"季节节日")
	var entrance: Dictionary=Exploration.definition("forest_entry")
	await at(entrance.area,Exploration.point("forest_entry")+Vector2(0,32));await show_panel(game.hud.exploration_panel,["forest_entry"],"隐藏地图入口")
	await at("village",WorldDevelopment.anchor("board")+Vector2(0,32));await show_panel(game.hud.world_development_panel,["board"],"村庄共建")
	await at("farm",Fishing.point("farm_lake")+Vector2(-32,0));GameState.select_tool(8)
	await show_panel(game.hud.fishing_panel,["farm_lake"],"钓鱼准备")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(2);await RenderingServer.frame_post_draw
	var path: String="res://builds/UI05/layout-"+configuration+"-"+label.validate_filename()+".png"
	if get_viewport().get_texture().get_image().save_png(path)!=OK:
		failed+=1;push_error("UI05实际窗口截图保存失败："+path)
	else: screenshot_paths.append(path)
