extends "res://tests/runner.gd"
## 真正窗口中的畜舍/动物绘制、触点和南庭相机边界。
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	Inventory.items={"wood":999,"stone":999,"copper_bar":99,"iron_bar":99,"hay":999};Inventory.coins=100000
	await frames(6)
	var panel: PanelContainer=game.hud.livestock_panel
	await Touch.place(self,game,"farm",Livestock.SITES.coop+Vector2(0,72))
	Touch.tap(self,game,Livestock.SITES.coop+Vector2(0,-12));await Touch.finish(self,game,500)
	check(panel.visible and panel.context=="coop","真实触点点击南庭木牌靠近并打开建设")
	var before: int=Inventory.coins
	await touch_caption(panel,"建造鸡鸭舍")
	check(panel.pending.is_valid(),"建造先进入明确确认页")
	await touch_caption(panel,"取消")
	check(Inventory.coins==before and Livestock.building("coop").level==0,"触点取消建造不扣资源")
	await touch_caption(panel,"建造鸡鸭舍");await touch_caption(panel,"确认")
	check(Livestock.building("coop").level==1 and Inventory.coins==before-160,"真实确认只执行一次建设事务")
	panel.accept();panel.accept()
	check(Inventory.coins==before-160,"重复空确认回调不再次扣料")
	await touch_caption(panel,"接回一只小鸡 · 60 金");await touch_caption(panel,"确认")
	check(Livestock.animals_at("coop").size()==1,"实际购买入口生成可见独立幼畜")
	panel.close_panel()
	var first: Dictionary=Livestock.animals_at("coop")[0]
	await Touch.place(self,game,Livestock.animal_area(first),Livestock.animal_point(first)+Vector2(0,64))
	Touch.tap(self,game,Livestock.animal_point(first)+Vector2(0,-12));await Touch.finish(self,game,500)
	check(panel.visible and panel.context=="animal:"+first.id,"点击地图幼畜自动靠近并打开照料")
	var hay: int=Inventory.count("hay")
	await touch_caption(panel,"投喂 · 干草1份")
	check(Inventory.count("hay")==hay-1 and first.fed_day==GameClock.day,"真实触点投喂一次")
	var energy: int=GameState.stamina
	await touch_caption(panel,"抚摸 · 1体力")
	check(GameState.stamina==energy-1 and first.bond==3,"真实触点抚摸受每日限制")
	panel.close_panel()
	# 满级六只牛放牧，确认南庭靠近底边仍能通过屏幕点选全部动物。
	await Touch.place(self,game,"farm",Livestock.SITES.barn+Vector2(0,32))
	Livestock.build("barn");Livestock.upgrade("barn");Livestock.upgrade("barn")
	for i in range(6): Livestock.buy_animal("barn")
	GameClock.minutes=600;GameClock.changed.emit();Livestock.graze("barn")
	game.change_location("pasture_barn");await frames(4)
	GameClock.running=true;await frames(240);GameClock.running=false
	check(Livestock.is_grazing("barn"),"晴天放牧实际让六只动物在庭院活动")
	for entry in Livestock.animals_at("barn"):
		await Touch.place(self,game,Livestock.animal_area(entry),Livestock.animal_point(entry)+Vector2(0,32))
		var target: Vector2=Livestock.animal_point(entry)+Vector2(0,-14)
		var screen: Vector2=game.player.get_canvas_transform()*target
		check(not game.touch_input.ui_at(screen),"南庭动物身体点击区域未被工具栏遮住："+entry.id)
		Touch.tap(self,game,target);await Touch.finish(self,game,500)
		check(panel.visible and panel.context=="animal:"+entry.id,"满级庭院实际触点能选择对应动物："+entry.id)
		panel.close_panel()
	await frames(5)
	get_viewport().get_texture().get_image().save_png("res://builds/screenshot-livestock-b.png")
	for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=resolution;await frames(4)
		await Touch.place(self,game,"farm",Livestock.SITES.barn+Vector2(0,32))
		panel.open_panel("barn");await frames(4)
		check(game.hud.safe.get_global_rect().encloses(panel.get_global_rect()),"畜牧滚动面板横屏安全区："+str(resolution))
		panel.close_panel()
	print("LIVESTOCK B RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func find_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==caption: return child
		var found := find_button(child,caption)
		if found: return found
	return null

func touch_caption(panel: PanelContainer, caption: String) -> void:
	var control := find_button(panel,caption)
	if not control: check(false,"缺少预期实际操作按钮："+caption);return
	var scroll := panel.content.get_parent() as ScrollContainer
	scroll.ensure_control_visible(control);await frames(4)
	load("res://tests/story.gd").touch(self,control);await frames(4)
