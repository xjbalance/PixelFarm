extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
const Fixture=preload("res://tests/harvest_fixture.gd")
var destination: String=""
func run() -> void:
	destination=OS.get_cmdline_user_args()[0]
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	Inventory.items={"carrot_seed":40,"potato_seed":12,"wheat_seed":24,"strawberry_seed":8,"carrot":16,"potato":8,"wheat":30,"wild_berry":8,"wood":76,"stone":45,"copper_bar":6,"flour":12,"berry_jam":3,"bread":8,"egg":12,"milk":6,"fish_carp":4,"rose":5,"cotton_cloth":2,"mill_kit":1}
	Inventory.coins=1200;Inventory.items.wood+=20;Inventory.items.stone+=20;Inventory.changed.emit()
	await Touch.place(self,game,"home",Housing.anchor("storage")+Vector2(32,0))
	check(Housing.deposit("wood",20) and Housing.deposit("stone",20),"旧一级仓库按原两种容量真实存入材料")
	await Touch.place(self,game,"farm",Vector2(656,480))
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"旧版UI共同夹具通过完整存档验证")
	var file:=FileAccess.open(destination+"/fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(FarmSaveStore.snapshot(game),"\t",true,true));file.close()
	await shot("hud-nine")
	game.hud.inventory_panel.open_panel(false);await frames(6);await shot("inventory")
	game.hud.inventory_panel.change_category(1);await frames(4);await shot("inventory-materials");game.hud.close_active_panel()
	await Touch.place(self,game,"home",Housing.anchor("storage")+Vector2(32,0));game.hud.housing_panel.open_panel("home");game.hud.housing_panel.page="storage";game.hud.housing_panel.refresh();await frames(5);await shot("storage");game.hud.close_active_panel()
	await Touch.place(self,game,"farm",FarmLayout.point("shop")+Vector2(0,32));game.hud.inventory_panel.open_panel(true);await frames(5);await shot("shop");game.hud.close_active_panel()
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32));game.hud.kitchen_panel.open_panel();await frames(5);await shot("kitchen");game.hud.close_active_panel()
	await Touch.place(self,game,"farm",Vector2(704,704))
	var pot: String=await Fixture.install(self,game,"station_jam_pot")
	check(pot!="" and await Fixture.approach(self,game,pot),"旧版本实际果酱锅可合法安装和接近")
	if pot!="": game.hud.workshop_panel.open_panel(pot);game.hud.workshop_panel.selected="berry_jam";game.hud.workshop_panel.refresh();await frames(5);await shot("processing")
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.8.2","初始UI采集来自实际0.8.2工程")
	print("UX083 BASELINE UI RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();game.set_process(false);await get_tree().create_timer(.3).timeout;game.queue_free();await frames(6);get_tree().quit(1 if failed else 0)
func shot(label: String) -> void:
	await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(destination+"/"+label+".png")
