extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
const UI=preload("res://tests/story.gd")
var initial: Dictionary
var events: Array=[]
var trace: Array=[]
var records: Array=[]
var tracing: bool=false
var probe_name: String=""
var baseline: bool=false
var captured: int=0
var mismatches: Array[String]=[]
var capture_series: String=""

func run() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	Events.story_dialogue_requested.connect(func(id: String): log_event("story_dialogue",id))
	Events.interaction_requested.connect(func(id: String): log_event("interaction",id))
	Events.location_changed.connect(func(id: String): log_event("location",id))
	Letters.changed.connect(func():
		if tracing: events.append({"event":"task_facts_changed","facts":Letters.facts.duplicate(true),"completed":Letters.completed.duplicate()})
	)
	Events.notice.connect(func(message: String):
		if tracing: events.append({"event":"notice","text":message})
	)
	for spec in [
		{"id":"east_bank","stage":5,"area":"village","origin":Vector2(944,496),"goal":Vector2(957,496),"click":Vector2(957,496),"interact":false,"dialogue":""},
		{"id":"east_bank_edge","stage":5,"area":"village","origin":Vector2(945,496),"goal":Vector2(951,496),"click":Vector2(950.25,496),"interact":false,"dialogue":""},
		{"id":"welcome","stage":1,"area":"farm","origin":Vector2(429,510),"goal":Vector2(429,480),"click":Vector2(429,421),"interact":true,"dialogue":"welcome"},
		{"id":"home_entry","stage":0,"area":"farm","origin":Vector2(656,480),"goal":Vector2(656,440),"click":Vector2(656,408),"interact":true,"dialogue":""},
		{"id":"old_letter_marker","stage":0,"area":"home","origin":Vector2(720,336),"goal":Vector2(720,304),"click":Vector2(720,198),"interact":true,"dialogue":"letter"},
		{"id":"village_entry","stage":3,"area":"farm","origin":Vector2(480,310),"goal":Vector2(480,248),"click":Vector2(480,196),"interact":true,"dialogue":""},
		{"id":"village_return","stage":3,"area":"village","origin":Vector2(640,752),"goal":Vector2(640,790),"click":Vector2(640,806),"interact":true,"dialogue":""},
		{"id":"bridge_survey","stage":3,"area":"village","origin":Vector2(785,608),"goal":Vector2(785,572),"click":Vector2(785,516),"interact":true,"dialogue":"bridge_survey"},
		{"id":"repair_record","stage":3,"area":"village","origin":Vector2(570,460),"goal":Vector2(570,421),"click":Vector2(570,365),"interact":true,"dialogue":"repair_record"},
		{"id":"mill_records","stage":5,"area":"village","origin":Vector2(1130,450),"waypoints":[Vector2(1168,432),Vector2(1168,368)],"goal":Vector2(1136,368),"click":Vector2(1090,326),"interact":true,"dialogue":"mill"},
		{"id":"bridge_repair","stage":4,"area":"village","origin":Vector2(736,464),"goal":Vector2(790,464),"click":Vector2(790,426),"interact":true,"dialogue":"bridge","facts":["guestbook"],"inventory":{"wood":8,"stone":6}},
		{"id":"crop_delivery","stage":2,"area":"farm","origin":Vector2(429,510),"goal":Vector2(429,480),"click":Vector2(429,421),"interact":true,"dialogue":"harvest","facts":["plant","water","harvest"],"inventory":{"carrot":3}},
		{"id":"transport","stage":8,"area":"village","origin":Vector2(1200,464),"goal":Vector2(1184,432),"click":Vector2(1184,376),"interact":true,"dialogue":"","reading":true},
		{"id":"mine_entry","stage":8,"area":"village","origin":Vector2(1104,240),"goal":Vector2(1128,240),"click":Vector2(1168,184),"interact":true,"dialogue":"","reading":true,"enter":true,"mine_conditions":["transport"]},
		{"id":"mine_manual","stage":8,"area":"mine_a","origin":Vector2(176,752),"goal":Vector2(208,752),"click":Vector2(240,728),"interact":true,"dialogue":"","reading":true,"mine_conditions":["transport","entrance"]},
		{"id":"mine_locked_exit","stage":8,"area":"mine_a","origin":Vector2(1104,336),"goal":Vector2(1104,304),"click":Vector2(1104,248),"interact":true,"dialogue":"","mine_conditions":["transport","entrance"]},
		{"id":"farm_till","stage":1,"area":"farm","origin":Vector2(656,656),"goal":Vector2(656,624),"click":Vector2(656,592),"interact":true,"dialogue":"","tool":0},
		{"id":"farm_plant","stage":1,"area":"farm","origin":Vector2(656,656),"goal":Vector2(656,624),"click":Vector2(656,592),"interact":true,"dialogue":"","tool":3},
		{"id":"farm_water","stage":1,"area":"farm","origin":Vector2(656,656),"goal":Vector2(656,624),"click":Vector2(656,592),"interact":true,"dialogue":"","tool":1},
		{"id":"farm_harvest","stage":1,"area":"farm","origin":Vector2(656,656),"goal":Vector2(656,624),"click":Vector2(656,592),"interact":true,"dialogue":"","tool":2},
		{"id":"gather_tree","stage":1,"area":"farm","origin":Vector2(160,352),"goal":Vector2(160,296),"click":Vector2(160,248),"interact":true,"dialogue":"","tool":6,"hits":3},
		{"id":"gather_rock","stage":1,"area":"farm","origin":Vector2(128,288),"goal":Vector2(128,232),"click":Vector2(128,184),"interact":true,"dialogue":"","tool":7,"hits":2},
		{"id":"xiaojing_letter","stage":1,"area":"farm","origin":Vector2(748,528),"goal":Vector2(748,472),"click":Vector2(748,420),"interact":true,"dialogue":""},
		{"id":"lake_record","stage":8,"area":"farm","origin":Vector2(848,688),"goal":Vector2(880,688),"click":Vector2(912,668),"interact":true,"dialogue":""}
	]:
		await prepare(spec)
		var fixture:=FarmSaveStore.snapshot(game)
		check(FarmSaveStore.valid(fixture),"合法且可重复的任务前置状态 "+spec.id)
		var outcomes: Dictionary={}
		for mode in ["joystick","tap"]:
			while game.hud.close_active_panel(): pass
			check(FarmSaveStore.restore(game,fixture),"两种操作从同一份整档开始 "+spec.id+"/"+mode)
			GameClock.running=false;GameWeather.enabled=false;GameState.set_control_mode(mode,false);GameState.manual_tool=false
			if spec.has("tool"): GameState.select_tool(int(spec.tool))
			await frames(5);game.camera_rig.follow_now();await frames(3)
			game.hud.toast_time=0;game.hud.toast.hide()
			check(game.player.global_position.distance_to(spec.origin)<2 and not colliding(),"共同起点合法且没有恢复到其他位置 "+spec.id+"/"+mode)
			events=[];trace=[];captured=0;probe_name=spec.id+"-"+mode;tracing=true
			var before:=business()
			var calls_before: int=game.auto_move.execution_count
			var intent:=TouchInteractionResolver.resolve(game,spec.click)
			if mode=="joystick":
				for waypoint in spec.get("waypoints",[]): await walk(waypoint)
				await walk(spec.goal)
				if spec.interact:
					game.action_cooldown=0;UI.touch(self,game.hud.action_button);await frames(4)
			else:
				Touch.tap(self,game,spec.click)
				for i in range(600):
					await tick()
					if game.auto_move.state in [game.auto_move.State.IDLE,game.auto_move.State.FAILED]: break
			await frames(40)
			for repeat in range(int(spec.get("hits",1))-1):
				if mode=="joystick": game.action_cooldown=0;UI.touch(self,game.hud.action_button)
				else: Touch.tap(self,game,spec.click);await Touch.finish(self,game,600)
				await frames(20)
			var opened: String=game.hud.dialogue.scene_id if game.hud.dialogue.visible else ""
			if opened!="": await capture("interaction")
			if spec.dialogue!="" and opened==spec.dialogue:
				UI.finish(game.hud.dialogue,"renew" if opened=="letter" else "")
				await frames(4)
			if spec.get("reading",false) and game.hud.mine_panel.visible and game.hud.mine_panel.reading:
				await UI.touch_button(self,game.hud.mine_panel,"读完并记下")
			if spec.get("enter",false) and game.hud.mine_panel.visible and "entrance" in ChapterTwo.completed:
				await UI.touch_button(self,game.hud.mine_panel,"进入废弃矿道")
			if spec.id=="xiaojing_letter" and game.hud.xiaojing_panel.visible:
				await capture("interaction");await UI.touch_button(self,game.hud.xiaojing_panel,"读完并记下")
			if spec.id=="lake_record" and game.hud.ecology_panel.visible:
				await capture("interaction");await UI.touch_button(self,game.hud.ecology_panel,"提交恢复记录")
				var paid:=Inventory.items.duplicate(true);var coins: int=Inventory.coins
				await UI.touch_button(self,game.hud.ecology_panel,"提交恢复记录")
				check(Inventory.items==paid and Inventory.coins==coins,"湖泊任务重复提交不重复发奖 "+mode)
			var outcome:=business();outcomes[mode]=outcome
			if not baseline and GameState.location==spec.area:
				var reach: float=38 if intent.kind=="plot" else 54 if intent.kind=="resource" else 58
				if intent.kind!="ground": check(game.player.position.distance_to(intent.point)<=reach+.01,"业务成功时真实脚底在合法距离内 "+spec.id+"/"+mode)
				elif mode=="tap": check(game.player.position.distance_to(spec.click)<.01,"地面到达没有吸回格心或提前停在区域外 "+spec.id)
			var row: Dictionary={"task":spec.id,"target_id":target_id(intent),"mode":mode,"scene":spec.area,"start":[spec.origin.x,spec.origin.y],"click":[spec.click.x,spec.click.y],"resolved_kind":intent.kind,"stop":[game.player.global_position.x,game.player.global_position.y],"collision":colliding(),"entered_east_bank":Letters.knows("east_bank"),"dialogue":opened,"before":before,"after":outcome,"success":success(spec.id,outcome),"events":events.duplicate(true),"positions":trace.duplicate(true),"navigation_state":game.auto_move.state,"navigation_calls":game.auto_move.execution_count-calls_before}
			records.append(row);await capture("result");tracing=false
			print("TASK PARITY PROBE ",JSON.stringify(row))
			if mode=="joystick": check(success(spec.id,outcome),"摇杆真实走动和原业务能够完成 "+spec.id)
			if not baseline and mode=="tap": check(success(spec.id,outcome),"点击真实走动和原业务能够完成 "+spec.id)
		if outcomes.joystick!=outcomes.tap: mismatches.append(spec.id)
		if not baseline: check(outcomes.joystick==outcomes.tap,"同一任务的进度、数量、金币和场景等价 "+spec.id)
	var label: String="before" if baseline else "after"
	if DisplayServer.get_name()!="headless": label+="-window"
	DirAccess.make_dir_recursive_absolute("res://docs/ux083/p0")
	var file:=FileAccess.open("res://docs/ux083/p0/"+label+"-tasks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline":baseline,"checks":checked,"failures":failed,"business_mismatches":mismatches,"cases":records},"\t",true,true));file.close()
	print("UX083 TASK EQUIVALENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(5);get_tree().quit(1 if failed else 0)

func prepare(spec: Dictionary) -> void:
	while game.hud.close_active_panel(): pass
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	var story: Dictionary=Story.snapshot();story.stage=int(spec.stage);story.motive="renew" if spec.stage>0 else "";story.seen=[]
	if spec.stage==8: story.lantern="life"
	for id in Story.data.scenes:
		if Story.data.scenes[id].has("next") and int(Story.data.scenes[id].next)<=int(spec.stage): story.seen.append(id)
	Story.restore(story);Letters.restore(Letters.migrate(story))
	if spec.stage>=7: VillageProjects.restore({"built":["well","cooperative","arbor"],"water_day":0,"tea_day":0})
	for fact in spec.get("facts",[]): Letters.facts[fact]=1
	for item in spec.get("inventory",{}): Inventory.items[item]=spec.inventory[item]
	if spec.has("mine_conditions"):
		ChapterTwo.restore({"facts":spec.mine_conditions.duplicate(),"completed":spec.mine_conditions.duplicate(),"policy":""})
		if "entrance" in spec.mine_conditions: MineState.state.unlocked=["mine_a"]
	GameClock.minutes=720;GameClock.changed.emit()
	await Touch.place(self,game,spec.area,spec.origin);await frames(4)
	if str(spec.id).begins_with("farm_"):
		var cell:=Vector2i(20,18)
		if spec.id!="farm_till": check(game.farm.use_tool(cell,"hoe"),"农活夹具通过原业务开垦 "+spec.id)
		if spec.id in ["farm_water","farm_harvest"]: check(game.farm.use_tool(cell,"carrot_seed"),"农活夹具通过原业务播种 "+spec.id)
		if spec.id=="farm_harvest":
			for i in range(2):
				check(game.farm.use_tool(cell,"water"),"收获夹具实际浇水")
				GameClock.minutes=1200;check(GameClock.request_sleep(GameClock.day),"收获夹具正常过夜成长");await frames(4)
		if spec.id=="farm_plant": Xiaojing.state.plants=519;Xiaojing.state.plant_serial=519
		GameState.rest();GameClock.minutes=720;GameClock.running=false;GameClock.changed.emit();await Touch.place(self,game,spec.area,spec.origin)
	if spec.id=="xiaojing_letter":
		Xiaojing.state.plants=520;Xiaojing.state.plant_serial=520;Xiaojing.state.letter_ready=true
	if spec.id=="lake_record": LakeEcology.state.health=90;LakeEcology.state.plants=3;LakeEcology.state.cycle=true;LakeEcology.state.debris=0

func business() -> Dictionary:
	return {"story":Story.snapshot(),"letters":Letters.snapshot(),"coins":Inventory.coins,"items":Inventory.items.duplicate(true),"location":GameState.location,"chapter_two":ChapterTwo.snapshot(),"mines":MineState.snapshot(),"progress":FarmProgress.snapshot(),"stamina":GameState.stamina,"plots":game.farm.plots.duplicate(true),"xiaojing":Xiaojing.snapshot(),"ecology":LakeEcology.snapshot(),"gathering":{"tree":game.resource_world.fields.farm.state.tree_5_8.duplicate(),"rock":game.resource_world.fields.farm.state.rock_4_6.duplicate()}}

func success(id: String, state: Dictionary) -> bool:
	match id:
		"east_bank","east_bank_edge": return int(state.letters.facts.get("east_bank",0))==1
		"welcome": return int(state.story.stage)==2
		"home_entry": return state.location=="home"
		"old_letter_marker": return int(state.story.stage)==1
		"village_entry": return state.location=="village"
		"village_return": return state.location=="farm"
		"bridge_survey","repair_record": return int(state.letters.facts.get(id,0))==1
		"mill_records": return int(state.story.stage)==6
		"bridge_repair": return int(state.story.stage)==5 and not state.items.has("wood") and not state.items.has("stone")
		"crop_delivery": return int(state.story.stage)==3 and not state.items.has("carrot")
		"transport": return "transport" in state.chapter_two.completed
		"mine_entry": return state.location=="mine_a" and "entrance" in state.chapter_two.completed
		"mine_manual": return "mining_manual" in state.chapter_two.facts
		"mine_locked_exit": return state.location=="mine_a" and "mine_b" not in state.mines.unlocked
		"farm_till": return state.plots.has("20,18") and state.plots["20,18"].crop==""
		"farm_plant": return state.plots["20,18"].crop=="carrot" and state.xiaojing.plants==520 and state.xiaojing.plant_serial==520
		"farm_water": return state.plots["20,18"].watered
		"farm_harvest": return state.plots["20,18"].crop=="" and int(state.items.get("carrot",0))==1
		"gather_tree": return state.gathering.tree.hp==0 and int(state.items.get("wood",0))==4
		"gather_rock": return state.gathering.rock.hp==0 and int(state.items.get("stone",0))==3
		"xiaojing_letter": return state.xiaojing.unlocked and not state.xiaojing.letter_ready
		"lake_record": return state.ecology.restored
	return false

func target_id(intent: Dictionary) -> String:
	if not intent.has("object"): return str(intent.get("cell",intent.get("point")))
	var object: Node=intent.object
	for key in ["actor_id","person_id","mine_id","livestock_id","entry_id","kind"]:
		if key in object: return key+":"+str(object.get(key))
	return str(object.get_path())

func colliding() -> bool:
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=game.player.get_node("CollisionShape2D").shape;query.transform=game.player.global_transform;query.collision_mask=game.player.collision_mask
	return not game.player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func log_event(kind: String, id: String) -> void:
	if tracing: events.append({"event":kind,"id":id,"position":[game.player.global_position.x,game.player.global_position.y],"scene":GameState.location})

func walk(goal: Vector2) -> void:
	var center: Vector2=game.hud.joystick.get_global_rect().get_center()
	Touch.finger(self,center,true,43)
	for i in range(360):
		var offset: Vector2=goal-game.player.global_position
		if offset.length()<1 or GameState.modal: break
		var event:=InputEventScreenDrag.new();event.index=43;event.position=center+offset.normalized()*66*minf(1,offset.length()/(game.player.movement_speed()/60))
		get_viewport().push_input(event,true);await tick()
	Touch.finger(self,center,false,43);await frames(3)
	check(game.player.global_position.distance_to(goal)<2,"原生摇杆输入真实抵达 "+probe_name)

func tick() -> void:
	await frames(1)
	trace.append({"frame":Engine.get_physics_frames(),"position":[game.player.global_position.x,game.player.global_position.y],"collision":colliding(),"scene":GameState.location})
	var motion: bool=false
	for prefix in ["east_bank","old_letter_marker","welcome","mill_records","gather_tree","gather_rock","bridge_repair","narrow-passage","farm_plant"]:
		if probe_name.begins_with(prefix): motion=true
	if motion and trace.size()%3==0 and captured<96: await capture("frame-%02d" % captured);captured+=1

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var folder: String="res://docs/ux083/p0/"+("before" if baseline else "after")
	DirAccess.make_dir_recursive_absolute(folder)
	var series: String=folder+"/"+probe_name
	if capture_series!=series:
		capture_series=series
		for name in DirAccess.get_files_at(folder):
			if name.begins_with(probe_name+"-") and name.ends_with(".png"): DirAccess.remove_absolute(folder+"/"+name)
	await RenderingServer.frame_post_draw
	var picture:=get_viewport().get_texture().get_image()
	if label.begins_with("frame-"): picture.resize(640,360,Image.INTERPOLATE_NEAREST)
	picture.save_png(folder+"/"+probe_name+"-"+label+".png")
