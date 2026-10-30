extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	Inventory.coins=10000;Inventory.items={"wood":100,"stone":100,"copper_bar":10,"iron_bar":10,"carrot":10,"potato":10,"wheat":10}
	var panel: PanelContainer=game.hud.kitchen_panel
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution
		await Touch.place(self,game,"home",Vector2(640,500))
		Touch.tap(self,game,Vector2(848,410));await Touch.finish(self,game,500)
		check(panel.visible and Kitchen.near_kitchen(),"实际窗口触点正确靠近厨房："+str(resolution))
		for page in ["recipes","processing","queue"]:
			panel.page=page;panel.refresh();await frames(4)
			check(game.hud.safe.get_global_rect().encloses(panel.get_global_rect()),"厨房页面位于安全区并可滚动："+page+str(resolution))
		panel.close_panel()
	get_window().size=Vector2i(1280,720)
	await Touch.place(self,game,"home",Vector2(848,464))
	panel.open_panel();panel.page="processing";panel.refresh();await frames(4)
	var money: int=Inventory.coins
	var button: Button=find_button(panel,"建造手摇磨坊")
	check(button==null,"厨房加工页引导实体工坊，不再把设备塞进住宅")
	panel.close_panel();await Touch.place(self,game,"farm",Vector2(704,704))
	check(game.territory_editor.open(),"窗口打开现有农场实体建造入口");await frames(4)
	game.territory_editor.choose_tool("station_mill");game.territory_editor.preview_at(Vector2i(23,25));await frames(4)
	check(game.territory_editor.preview_plan.get("valid",false),"实体磨坊预览具有合法占地")
	game.territory_editor.cancel();check(Inventory.coins==money,"取消实体设备预览不扣金币材料")
	game.territory_editor.open();await frames(4);game.territory_editor.choose_tool("station_mill");game.territory_editor.preview_at(Vector2i(23,25));await frames(4)
	button=game.territory_editor.confirm_button
	check(button!=null and button.size.y>=48,"实体设备确认保留至少48px触点")
	var count: int=Territory.state.objects.size()
	load("res://tests/story.gd").touch(self,button);await frames(5)
	check(Territory.state.objects.size()==count+1 and Inventory.coins==money-80,"原生触点确认一次实体磨坊建造")
	game.territory_editor.confirm();game.territory_editor.confirm()
	check(Inventory.coins==money-80,"重放已清空的实体预览不能重复扣款")
	game.territory_editor.cancel();await Touch.place(self,game,"home",Vector2(848,464));panel.open_panel()
	panel.page="recipes";panel.refresh();await frames(4)
	button=find_button(panel,"制作暖锅蔬菜炖 ×1")
	if button: await touch(panel,button)
	button=find_button(panel,"确认")
	if button: await touch(panel,button)
	check(Inventory.count("carrot_stew")==1 and Inventory.count("carrot")==8 and Inventory.count("potato")==9,"触屏料理确认真实扣食材并制作一份")
	GameState.stamina=10;panel.refresh();await frames(4)
	button=find_button(panel,"食用一份暖锅蔬菜炖")
	if button: await touch(panel,button)
	check(Inventory.count("carrot_stew")==0 and GameState.stamina==42,"触屏食用恢复32体力且保留单一增益规则")
	var at: Vector2=game.player.global_position
	Touch.tap(self,game,Vector2(640,500));await frames(5)
	check(game.player.global_position==at and game.auto_move.target.is_empty(),"厨房面板拦截地图触点，不误触走出房间")
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070b-kitchen-panel.png")
	panel.close_panel()
	for id in ["cheese_table","smoker","jam_pot"]: Kitchen.build(id)
	await frames(6)
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070b-kitchen.png")
	await Touch.place(self,game,"farm",Vector2(304,560));Touch.tap(self,game,Vector2(240,542));await Touch.finish(self,game,500)
	check(panel.visible and panel.context=="berry","窗口野莓灌木打开独立采摘交互")
	GameState.stamina=100;button=find_button(panel,"采摘今天的野莓")
	if button: await touch(panel,button)
	check(Inventory.count("wild_berry")==2 and GameState.stamina==98,"原生触点完成一次有限野莓采摘")
	print("KITCHEN B RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
func find_button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==caption: return child
		var result := find_button(child,caption)
		if result: return result
	return null
func touch(panel: PanelContainer, button: Button) -> void:
	(panel.content.get_parent() as ScrollContainer).ensure_control_visible(button);await frames(4)
	load("res://tests/story.gd").touch(self,button);await frames(4)
