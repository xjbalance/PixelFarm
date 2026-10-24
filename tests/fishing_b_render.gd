extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	game.get_node("Audio").muted=true;GameClock.running=false;await frames(6)
	Inventory.items.fishing_bait=20
	GameState.select_tool(GameState.tools.find("fishing_rod"))
	var panel: PanelContainer=game.hud.fishing_panel
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(5)
		await Touch.place(self,game,"farm",Vector2(944,464))
		var water_click := Vector2(1040,528)
		check(not game.touch_input.ui_at(game.player.get_canvas_transform()*water_click),"选择未被工具栏遮挡的真实水面触点")
		Touch.tap(self,game,water_click);await Touch.finish(self,game,500)
		check(panel.visible,"窗口水面触点自动靠岸："+str(resolution))
		for page in ["cast","gear","book"]:
			panel.page=page;panel.refresh();await frames(4)
			check(game.hud.safe.get_global_rect().encloses(panel.get_global_rect()),"钓鱼页面安全区："+str(resolution)+" "+page)
		panel.close_panel()
	get_window().size=Vector2i(1280,720);await frames(4)
	await Touch.place(self,game,"farm",Vector2(944,464));panel.open_panel("farm_lake")
	var cast := find_button(panel,"向水面抛竿")
	check(cast!=null and cast.size.y>=48,"真实抛竿按钮具备48px触点")
	if cast: load("res://tests/story.gd").touch(self,cast)
	await frames(5)
	check(Fishing.active() and is_instance_valid(panel.hold),"真实触点开始等待并创建长按小游戏控制")
	check(is_instance_valid(panel.hold) and game.hud.safe.get_global_rect().encloses(panel.hold.get_global_rect()),"实际追鱼控制位于横屏安全区")
	if is_instance_valid(panel.hold):
		var center: Vector2=panel.hold.get_global_rect().get_center()
		var serial: int=Fishing.state.serial
		Touch.finger(self,center,true,91)
		check(panel.hold.held,"追鱼控制认领第一根原生手指")
		Touch.finger(self,center,true,92);Touch.finger(self,center,false,92)
		check(panel.hold.held and Fishing.state.serial==serial,"第二根手指不抢控制、不重复抛竿或资源扣除")
		Touch.finger(self,center,false,91)
		check(not panel.hold.held,"主手指释放后追鱼控制立即复位")
	var pressed := false
	var survived := false
	for i in range(1800):
		if not Fishing.active(): survived=true;break
		var desired: bool=Fishing.session.player>Fishing.session.fish
		if desired!=pressed and is_instance_valid(panel.hold):
			Touch.finger(self,panel.hold.get_global_rect().get_center(),desired,71)
			pressed=desired
		if i==160: get_viewport().get_texture().get_image().save_png("res://builds/fishing-qte-070.png")
		await frames(1)
	if pressed: Touch.finger(self,Vector2(640,400),false,71)
	check(survived and Fishing.state.total==1 and Fishing.session.phase=="landed","真实触屏按住/释放追鱼成功，奖励只入包一尾")
	var before: Dictionary=Fishing.snapshot()
	panel.close_panel();await frames(4)
	check(Fishing.snapshot()==before and not Fishing.active(),"关闭窗口不重复结算已成功鱼获")
	print("RENDER FISHING B RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==text: return child
		var found := find_button(child,text)
		if found: return found
	return null
