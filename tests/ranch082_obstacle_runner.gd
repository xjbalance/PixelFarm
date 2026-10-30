extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game);GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false);GameClock.minutes=720;GameClock.changed.emit()
	var field: Node2D=game.resource_world.fields.farm
	var bush: Node2D=field.objects.brush_original_5;var rock: Node2D=field.objects.rock_28_24
	check(bush.position==Vector2(900,770) and rock.position==Vector2(896,768),"overlapping legacy scenery and stone retain exact original positions")
	check(field.access_target(bush)==rock,"old bush access resolves its real natural stone blocker")
	var point: Vector2=bush.position+Vector2(0,-12)
	var normal:=TouchInteractionResolver.resolve(game,point)
	check(normal.kind=="object","ordinary tap retains existing nearby story-facility interaction")
	GameState.select_tool(7);var intent:=TouchInteractionResolver.resolve(game,point)
	check(intent.get("object")==rock and intent.has("covered_resource"),"visible bush tap clearly targets reachable stone first")
	game.auto_move.navigation.rebuild();var path: PackedVector2Array=game.auto_move.navigation.path_to(intent)
	check(not path.is_empty(),"natural blocker has a real legal approach without crossing walls")
	if path.is_empty(): await finish();return
	game.player.position=path[-1];game.camera_rig.follow_now();await frames(4)
	await shot("legacy-overlap-before")
	var wood: int=Inventory.count("wood");var stone: int=Inventory.count("stone");var energy: int=GameState.stamina
	GameState.select_tool(6);Touch.tap(self,game,point);await Touch.finish(self,game,600);await frames(20)
	check(field.state.rock_28_24.hp==2 and GameState.stamina==energy,"explicit axe selection cannot damage or bypass blocking stone")
	for i in range(2):
		GameState.select_tool(7);Touch.tap(self,game,point);await Touch.finish(self,game,600);await frames(20)
		check(field.state.rock_28_24.hp==1-i and field.state.brush_original_5.hp==1,"one explicit pickaxe click mines one stone hit before bush "+str(i))
	check(Inventory.count("stone")==stone+3 and rock.collider.disabled,"original stone yields once and releases collision")
	GameState.select_tool(6);intent=TouchInteractionResolver.resolve(game,point)
	check(intent.get("object")==bush and not intent.has("covered_resource"),"after mining, same unchanged bush becomes directly reachable")
	Touch.tap(self,game,point);await Touch.finish(self,game,600);await frames(24)
	check(field.state.brush_original_5.hp==0 and Inventory.count("wood")==wood+1,"same original bush can actually be cleared through normal click input")
	check(not field.hit("brush_original_5","axe") and not field.hit("rock_28_24","pickaxe"),"rapid repeated clear cannot duplicate either material")
	await shot("legacy-overlap-after")
	for i in range(3): GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"normal daily settlement after natural overlap clearing");await frames(3)
	var save:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))),"overlap cleared states restore through whole save");await frames(5)
	check(field.state.brush_original_5.hp==0 and field.state.rock_28_24.hp==0 and bush.position==Vector2(900,770) and rock.position==Vector2(896,768),"day and restart never respawn resources or shift old layout")
	await finish()
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(4);await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://docs/ranch082/"+label+".png")
func finish() -> void:
	print("RANCH082 OBSTACLE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(8);get_tree().quit(1 if failed else 0)
