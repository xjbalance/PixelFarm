extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
const Touch=preload("res://tests/touch_navigation.gd")
var devices: Dictionary={}
func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));Fixture.stock();Fixture.cooperative()
	for station in HarvestCatalog.data().stations:
		devices[station]=await Fixture.install(self,game,"station_"+str(station))
		check(devices[station]!="","窗口加载实际设备："+str(station))
	var ids: Array=["carrot","potato","wheat","strawberry","cabbage","radish","peas","spinach","rapeseed","garlic_shoot","lavender","rose"]
	for i in range(ids.size()):
		var id: String=ids[i];var cell:=Vector2i(18+i%6,17+i/6)
		game.farm.plots[TerritoryCatalog.key(cell)]={"crop":id,"days":Catalog.crops[id].growth_days,"watered":true}
		Inventory.items[id]=8;Inventory.items[id+"_seed"]=10
	game.farm.queue_redraw();game.player.position=Vector2(704,704);game.camera_rig.follow_now();await frames(5)
	await shot("farm-workshop")
	game.hud.root.hide();game.camera_rig.set_physics_process(false);game.player.get_node("Camera2D").zoom=Vector2(.7,.7)
	game.player.get_node("Camera2D").global_position=Vector2(768,512);game.player.get_node("Camera2D").force_update_scroll();await frames(5);await shot("farm-panorama")
	game.hud.root.show();game.camera_rig.set_physics_process(true);game.player.get_node("Camera2D").zoom=Vector2.ONE;game.camera_rig.follow_now()
	game.territory_editor.open();await frames(3)
	var index: int=0
	for fruit in HarvestCatalog.data().orchard:
		Inventory.items[fruit+"_sapling"]=1
		var plan:=Territory.plan_place("farm","orchard_"+fruit,Vector2i(18+index*4,5))
		if not plan.valid:
			for y in range(4,9):
				for x in range(17+index*4,20+index*4):
					var alternative:=Territory.plan_place("farm","orchard_"+fruit,Vector2i(x,y))
					if alternative.valid: plan=alternative;break
				if plan.valid: break
		check(plan.valid and Territory.apply_plan(plan),"窗口真实果园摆放："+fruit+" · "+str(plan.reason))
		index+=1;await frames(4)
	game.territory_editor.cancel();await frames(5)
	for i in range(12): GameClock.minutes=1200;GameClock.request_sleep(GameClock.day)
	await Touch.place(self,game,"farm",Vector2(768,240));game.camera_rig.follow_now();game.hud.root.hide();await frames(5);await shot("orchard-grown")
	for season in range(4):
		GameClock.day=1+season*28+14;Calendar.restore(Calendar.snapshot(GameClock.day));GameClock.day_advanced.emit();GameClock.changed.emit();await frames(5)
		await shot("orchard-season-"+str(season))
	game.hud.root.show()
	await Touch.place(self,game,"farm",Vector2(704,704));await Fixture.approach(self,game,str(devices.jam_pot))
	Inventory.items.strawberry=20
	game.hud.workshop_panel.open_panel(str(devices.jam_pot));game.hud.workshop_panel.selected="strawberry_jam";game.hud.workshop_panel.quantity=2;game.hud.workshop_panel.refresh()
	await frames(5)
	var start_button: Button=load("res://tests/story.gd").find_button(game.hud.workshop_panel,"开始加工")
	check(start_button!=null,"窗口存在可触摸开始加工按钮")
	if start_button: load("res://tests/story.gd").touch(self,start_button)
	await frames(4)
	var confirm: Button=load("res://tests/story.gd").find_button(game.hud.workshop_panel,"确认开始")
	check(confirm!=null and Inventory.count("strawberry")==20,"首次触摸仅预览不扣材料")
	if confirm: load("res://tests/story.gd").touch(self,confirm)
	await frames(5)
	check(Inventory.count("strawberry")==16 and Workshop.state.jobs.has(str(devices.jam_pot)),"窗口原生确认两批果酱只扣四份草莓")
	await shot("jam-progress")
	for extent in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=extent;await frames(6);game.hud.reflow_panels();await frames(3)
		check(Rect2(Vector2.ZERO,Vector2(extent)).encloses(game.hud.workshop_panel.get_global_rect()),"加工窗口不超出横屏："+str(extent))
		await shot("workshop-%dx%d" % [extent.x,extent.y])
	game.hud.close_active_panel();get_window().size=Vector2i(1280,720);await frames(4)
	await Touch.place(self,game,"home",Housing.anchor("kitchen")+Vector2(0,32))
	Inventory.items.flour=10;Inventory.items.egg=10;Inventory.items.milk=10
	game.hud.kitchen_panel.open_panel();game.hud.kitchen_panel.recipe_page=1;game.hud.kitchen_panel.selected_recipe="cake";game.hud.kitchen_panel.refresh();await shot("kitchen-recipes");game.hud.close_active_panel()
	game.hud.inventory_panel.open_panel(false);await shot("crops-inventory");game.hud.close_active_panel()
	var font: Font=load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc");var glyphs_ok: bool=true
	for row in HarvestCatalog.data().items.values():
		var text: String=str(row.name)+str(row.description)
		for i in range(text.length()):
			if text.unicode_at(i)>32 and not font.has_char(text.unicode_at(i)): glyphs_ok=false
	check(glyphs_ok,"新增名称与说明均有Noto中文字符覆盖")
	check(FarmSaveStore.valid(FarmSaveStore.snapshot(game)),"窗口展示作物、设备、果树与真实存档状态一致")
	print("HARVEST WINDOW RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().call_deferred("quit",1 if failed else 0)
func shot(id: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/harvest-workshop/"+id+".png")
