extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func find_button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix): return child
		var result: Button=find_button(child,prefix)
		if result: return result
	return null
func press_visible(panel: PanelContainer, control: Button) -> void:
	var scroll: ScrollContainer=panel.content.get_parent();scroll.ensure_control_visible(control);await frames(4)
	load("res://tests/story.gd").touch(self,control);await frames(4)
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);GameClock.running=false;game.get_node("Audio").muted=true;await frames(6)
	var original: Dictionary=FarmSaveStore.snapshot(game)
	Inventory.coins=10000;Inventory.items={"wood":100,"stone":100,"wheat":10,"spring_bloom_seed":3}
	game.change_location("farm",Housing.YARD+Vector2(32,0));await frames(4)
	check(Housing.buy("flower") and Housing.place("flower","farm",Vector2i(10,20)),"实际制作庭院花坛供节日赠种种植")
	await frames(4)
	if Housing.state.placed.is_empty():
		game.get_node("Audio").stop_all();game.queue_free();await frames(4);get_tree().quit(1);return
	var id: String=Housing.state.placed[0].id;var object: Node2D
	for candidate in get_tree().get_nodes_in_group("housing_furniture"):
		if candidate.housing_id==id: object=candidate;break
	check(object!=null,"节日种植使用已存在的实体花坛")
	if object:
		Touch.tap(self,game,object.global_position);await Touch.finish(self,game,600)
		check(game.hud.housing_panel.visible and Housing.near_item(id),"点击花坛自动走近，不隔空扣花种")
		var sow: Button=find_button(game.hud.housing_panel,"播下春铃花种")
		check(sow!=null and not sow.disabled,"实际花坛界面提供合法播种按钮")
		if sow: await press_visible(game.hud.housing_panel,sow)
		check(Housing.state.flowers.has(id) and Inventory.count("spring_bloom_seed")==2,"原生触点播种只消耗一粒花种")
		game.hud.housing_panel.close_panel()
		var days_ok: bool=true
		for i in range(3): GameClock.minutes=1200;days_ok=GameClock.request_sleep(GameClock.day) and days_ok;await frames(4)
		check(days_ok and Housing.flower_age(id)==3,"三次合法晚间结算后花坛成熟")
		var marker: Vector2=object.global_position+Vector2(0,-28)
		check(not game.touch_input.ui_at(game.player.get_canvas_transform()*marker),"成熟花标记在实际可触控区域")
		Touch.tap(self,game,marker);await Touch.finish(self,game,500)
		check(game.hud.housing_panel.visible,"点成熟标记同样能打开采收界面")
		var harvest: Button=find_button(game.hud.housing_panel,"采收春铃花")
		if harvest: await press_visible(game.hud.housing_panel,harvest)
		check(Inventory.count("spring_bloom")==1 and not Housing.state.flowers.has(id),"原生按钮成熟采收一朵，不重复返种")
		game.hud.housing_panel.close_panel()
	FarmSaveStore.restore(game,original);GameClock.running=false
	GameClock.day=15;GameClock.minutes=1199;GameWeather.enabled=true;Calendar.restore(Calendar.snapshot());GameClock.changed.emit()
	game.change_location("farm",LakeEcology.SHORE+Vector2(-32,0));await frames(5)
	check(not GameWeather.is_moon_night(),"月夜在20点之前不会提前出现")
	GameClock.minutes=1200;GameClock.changed.emit();await frames(5)
	check(GameWeather.is_moon_night(),"晴朗春15日20点实际出现特殊满月")
	game.hud.ecology_panel.open_panel();await frames(4)
	var observe: Button=find_button(game.hud.ecology_panel,"记录满月倒影")
	check(observe!=null and not observe.disabled,"水样台界面提供可用的月影观测触点")
	if observe: await press_visible(game.hud.ecology_panel,observe)
	check(Inventory.count("moon_note")==1 and "moon_reflection" in Exploration.state.facts,"现场原生触点只领取一次月影笺")
	game.hud.ecology_panel.close_panel();await frames(5)
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-070-moon.png")
	print("FINALE 070 RENDER RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
