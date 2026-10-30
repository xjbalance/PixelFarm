extends "res://tests/runner.gd"
const Fixture=preload("res://tests/harvest_fixture.gd")
func run() -> void:
	if "--corrupt-ranch" in OS.get_cmdline_user_args():
		var broken:=FileAccess.open(FarmSaveStore.PATH,FileAccess.WRITE);broken.store_string("interrupted ranch save");broken.close();print("RANCH082 CORRUPT: PASS");get_tree().quit();return
	var writing: bool="--write-ranch" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10);game.persistence_enabled=false
	if writing: await write_fixture()
	else: await read_fixture()
	print("RANCH082 PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
func proof_write(data: Dictionary) -> void:
	var proof:=FileAccess.open("user://ranch082-proof.json",FileAccess.WRITE);proof.store_string(JSON.stringify(data,"  ",true,true));proof.close()
func write_fixture() -> void:
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/ranch082/legacy081-v29.json"))
	check(FarmSaveStore.restore(game,legacy),"write process loads actual v29 old world");await frames(5)
	game.change_location("pasture_coop",RanchLayout.service("coop")+Vector2(0,32));await frames(4)
	check(Livestock.buy_animal("coop","duck"),"new duck bought in migrated old coop")
	var duck: Dictionary=Livestock.state.animals[-1]
	game.player.position=Livestock.animal_point(duck)+Vector2(0,32)
	check(Livestock.feed(duck.id) and Livestock.pet(duck.id),"new duck fed and petted before shutdown")
	game.change_location("farm",Vector2(1600,1744));await frames(5)
	var field: Node2D=game.resource_world.fields.farm
	while int(field.state.exp082_tree_50_53.hp)>0:
		GameState.stamina=100;check(field.hit("exp082_tree_50_53","axe"),"new expanded tree legally cleared")
	game.player.position=Vector2(65,48)*32+Vector2(16,16);GameState.stamina=100
	check(game.farm.use_tool(Vector2i(65,48),"hoe") and game.farm.use_tool(Vector2i(65,48),"wheat_seed") and game.farm.use_tool(Vector2i(65,48),"water"),"new sparse coordinate plot planted watered before quit")
	await frames(24);game.change_location("pasture_coop",RanchLayout.entry("coop"));await frames(5)
	GameState.set_control_mode("joystick",false)
	var snapshot:=FarmSaveStore.snapshot(game)
	check(snapshot.version==30 and FarmSaveStore.valid(snapshot),"pasture location and all old/new animal state valid")
	var device: String=str(Workshop.state.jobs.keys()[0]);var serial: int=int(Workshop.state.jobs[device].id)
	proof_write({"data":snapshot,"duck":duck.id,"device":device,"serial":serial,"claimed":false})
	check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"v30 pasture save and valid backup written in independent process")
func read_fixture() -> void:
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://ranch082-proof.json"))
	var expected: Dictionary=AbyssSaveSchema.canonical(proof.data);var actual: Dictionary=AbyssSaveSchema.canonical(FarmSaveStore.snapshot(game))
	check(actual==expected,"new process restores exact world location sparse crops herd and jobs")
	var duck:=Livestock.animal(str(proof.duck))
	check(duck.species=="duck" and duck.fed_day==GameClock.day and duck.pet_day==GameClock.day,"duck identity and daily care survived restart")
	check(game.resource_world.fields.farm.state.exp082_tree_50_53.hp==0 and game.resource_world.fields.farm.state.tree_5_8.hp==0,"both original and expansion cleared trees stay dead after real restart")
	var before:=Livestock.snapshot();Livestock.settle_day();GameClock.day_advanced.emit();check(Livestock.snapshot()==before,"restart and repeated day event cannot generate animal product twice")
	var device: String=str(proof.device);var serial: int=int(proof.serial)
	if not bool(proof.claimed):
		Fixture.advance(45);check(Workshop.state.jobs[device].ready,"pending old order finishes using actual game minutes after restart")
		check(not Workshop.claim(device,serial),"pasture cannot remotely claim farm machine output")
		var object: Node2D=game.territory_world.objects[device]
		game.change_location("farm",object.position+Vector2(0,48));await frames(5)
		var flour: int=Inventory.count("flour");Inventory.items.flour=999
		check(not Workshop.claim(device,serial) and Workshop.state.jobs.has(device),"restored full inventory preserves ready output")
		Inventory.items.flour=flour
		check(Workshop.claim(device,serial) and Inventory.count("flour")==flour+1,"original invested order claimed exactly once")
		check(not Workshop.claim(device,serial),"same order serial cannot claim twice")
		proof.claimed=true
	else: check(not Workshop.state.jobs.has(device) and not Workshop.claim(device,serial),"backup restart cannot recreate already collected order")
	await frames(5)
	proof.data=FarmSaveStore.snapshot(game);proof_write(proof)
	check(FarmSaveStore.write(game) and FarmSaveStore.write(game),"postclaim main and backup both preserve consumed output serial")
