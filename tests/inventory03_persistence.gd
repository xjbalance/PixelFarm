extends "res://tests/runner.gd"
## 写入/读取必须为隔离目录内两个独立Godot进程，不保存临时选择对象。
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	var writing: bool="--write-inventory03" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	var panel: PanelContainer=game.hud.inventory_panel
	if writing:
		Inventory.items={"carrot_seed":17,"potato_seed":5,"carrot":4,"wood":999,"stone":8,"fish_feed":9,"fishing_bait":10,"fish_soup":2,"potato_bread":2}
		Inventory.coins=19283;Xiaojing.state.diamonds=1314;GameState.stamina=47
		GameState.set_control_mode("joystick",false)
		game.change_location("farm",Vector2(656,480));await frames(4)
		panel.open_panel(false);panel.select_item("carrot_seed")
		check(FarmSaveStore.write(game),"背包打开且选中物品时能写入原v22存档")
		var proof:=FarmSaveStore.snapshot(game)
		check(proof.version==FarmSaveStore.VERSION and not proof.has("selected_item") and proof.items==Inventory.items,"临时背包选中不写入存档，库存与原结构保持")
		var file:=FileAccess.open("user://inventory03-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	else:
		var proof: Dictionary=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("user://inventory03-proof.json")))
		var current: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
		check(current.items==proof.items and current.coins==proof.coins and current.stamina==proof.stamina,"独立重启原物品、金币和体力逐字段恢复")
		check(Xiaojing.state.diamonds==1314 and GameState.control_mode=="joystick" and game.hud.joystick.visible,"独立重启保留1314钻石与备用摇杆选择")
		check(not panel.visible and str(panel.selected_item)=="" and not GameState.modal and game.auto_move.target.is_empty(),"独立重启不恢复旧选中菜单、物品回调和路径")
		var old:=proof.duplicate(true);old.version=21;old.erase("tutorial")
		var migrated:=FarmSaveSchema.normalize(old)
		check(not migrated.is_empty() and migrated.items==proof.items and migrated.xiaojing.diamonds==1314,"真实v21字段迁移保留全部物品及婚礼钻石")
		panel.open_panel(false);await frames(3);panel.select_item("carrot")
		var before: Dictionary=Inventory.items.duplicate(true);var stamina: int=GameState.stamina
		check(panel.selected_item=="carrot" and Inventory.items==before and GameState.stamina==stamina,"重启后可重新选择物品且只查看不消费")
		panel.close_panel();GameState.set_control_mode("tap",false)
		Touch.tap(self,game,Vector2(784,496));await Touch.finish(self,game)
		check(game.player.position.distance_to(Vector2(784,496))<1.1,"背包重启验证后原点击移动仍正常")
	print("INVENTORY 03 PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
