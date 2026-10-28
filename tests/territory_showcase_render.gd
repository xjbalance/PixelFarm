extends Node
## 用真实建造确认组成展示地块；只用于隔离窗口截图，不向玩家档案预置布置。
var game: Node
var operations: int=0
func _ready() -> void: call_deferred("run")
func frames(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame
func paint(kind: String, region: Rect2i) -> void:
	game.territory_editor.choose_tool(kind)
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x): game.territory_editor.preview_at(Vector2i(x,y))
	assert(game.territory_editor.confirm(),"展示地块的地表必须经过实际确认："+kind)
	operations+=1;await frames(4)
func place(kind: String, cell: Vector2i) -> void:
	game.territory_editor.choose_tool(kind);game.territory_editor.preview_at(cell)
	await frames(4)
	assert(game.territory_editor.confirm(),"展示设施必须通过占地和通路检查："+kind+str(cell))
	operations+=1;await frames(4)
func capture(label: String) -> void:
	game.hud.toast_time=0;await frames(6);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://builds/territory-showcase-"+label+".png")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	# 只为窗口展示设置第一章已完成；四个地区的真实授权链由状态及存档套验证。
	Story.stage=8;Story.changed.emit()
	assert(WorldTravel.change(game,"east_holding"));await frames(6)
	assert(game.territory_editor.open())
	await paint("flowerbed",Rect2i(25,8,5,3))
	await paint("soil",Rect2i(24,11,4,3))
	await paint("stone_path",Rect2i(21,14,11,1))
	await paint("wood_path",Rect2i(25,17,7,2))
	await place("tree",Vector2i(30,11));await place("tree",Vector2i(22,18))
	await place("bush",Vector2i(24,9));await place("tall_grass",Vector2i(22,11));await place("rock_decor",Vector2i(22,12))
	for cell in [Vector2i(25,8),Vector2i(27,8),Vector2i(29,9),Vector2i(26,10)]: await place("flowers",cell)
	for x in range(25,32): await place("fence",Vector2i(x,16))
	await place("table",Vector2i(26,17));await place("chair",Vector2i(26,18));await place("chest",Vector2i(29,17))
	await place("bench",Vector2i(30,18));await place("lamp",Vector2i(32,17))
	game.territory_editor.pan_view(Vector2.UP);game.territory_editor.choose_category("terrain")
	await capture("garden_build")
	game.territory_editor.cancel();game.hud.atlas_panel.open_panel();game.hud.atlas_panel.show_current();await frames(20)
	await capture("garden_atlas");game.hud.atlas_panel.close_panel()
	var report:=FileAccess.open("res://builds/territory-showcase.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"platform":DisplayServer.get_name(),"confirmed_operations":operations,"captures":["res://builds/territory-showcase-garden_build.png","res://builds/territory-showcase-garden_atlas.png"],"isolated_fixture":true,"player_save_modified":false,"android_device_tested":false},"\t"));report.close()
	print("TERRITORY SHOWCASE WINDOW: PASS; ",operations," real editor confirmations")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit()
