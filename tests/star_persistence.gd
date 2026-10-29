extends Node
## 由测试入口提供独立用户目录；独立进程验证新剧情字段和钻石购物结果。
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var writing: bool="--write-star-save" in OS.get_cmdline_user_args()
	var corrupt: bool="--corrupt-star-save" in OS.get_cmdline_user_args()
	if corrupt:
		var bad := FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE)
		bad.store_string("broken star-story primary")
		bad.close()
		print("STAR PERSISTENCE CORRUPT: PASS")
		get_tree().quit()
		return
	var game := preload("res://scenes/main/main.tscn").instantiate()
	game.persistence_enabled=not writing
	add_child(game)
	game.get_node("Audio").muted=true
	GameClock.running=false
	for i in range(5): await get_tree().physics_frame
	var ok := true
	if writing:
		load("res://tests/star_runner.gd").fixture(game)
		StarStory.state.choices.future="keep_journeys"
		StarStory.state.post_run="field_trip"
		StarStory.state.post_steps=["sample_pond"]
		StarStory.state.appointment={"day":201,"status":"booked"}
		StarStory.state.season_run={"season":7,"plant":2,"water":0,"harvest":0,"lamp":false}
		StarStory.state.cooperate_day=200
		Xiaojing.state.diamonds=1400
		DiamondPayments.selected=true
		Inventory.coins=0
		Inventory.items.wheat_seed=1
		DiamondPayments.perform(func(): FarmEconomy.buy("wheat",5))
		DiamondPayments.selected=false
		GameState.set_control_mode("joystick",false)
		game.change_location("farm",Vector2(1360,912))
		ok=FarmSaveStore.write(game) and FarmSaveStore.write(game)
	else:
		ok=Xiaojing.state.married and Xiaojing.state.wedding_day==190 and Xiaojing.state.diamonds==1399
		ok=ok and Inventory.coins==0 and Inventory.count("wheat_seed")==6 and GameState.control_mode=="joystick"
		ok=ok and StarStory.state.wedding_phase==4 and StarStory.state.choices.future=="keep_journeys"
		ok=ok and StarStory.state.post_run=="field_trip" and StarStory.state.post_steps==["sample_pond"]
		ok=ok and StarStory.state.appointment.day==201 and StarStory.state.season_run.plant==2 and StarStory.state.cooperate_day==200
		ok=ok and GameClock.day==200 and GameClock.day-Xiaojing.state.wedding_day==10
		ok=ok and not StarStory.post_ready("day520") and not Inventory.diamond_payment
		ok=ok and FarmSaveStore.write(game) and not FarmSaveStore.read(FarmSaveStore.PATH+".bak").is_empty()
	print("STAR PERSISTENCE ","WRITE" if writing else "RESTART/BACKUP",": ","PASS" if ok else "FAIL")
	game.persistence_enabled=false
	game.get_node("Audio").stop_all()
	await get_tree().create_timer(.25).timeout
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
