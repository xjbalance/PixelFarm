extends Node
## 主场景只负责协调场景与交互，玩法规则留在各个系统里。
@export var persistence_enabled: bool = true
@onready var world: Node2D = $FarmWorld
@onready var player: CharacterBody2D = $FarmWorld/Actors/Player
@onready var farm: Node2D = $FarmWorld/FarmPlots
@onready var hud: CanvasLayer = $HUD
var action_cooldown: float = 0.0
var mine_maps: Dictionary = {}
var home: Node2D
var village: Node2D
var was_running: bool = true
var backgrounded: bool = false
var closing: bool = false
var autosave_pending: bool = false
var autosave_epoch: int = 0
var schedule_restore_pending: bool = false
var auto_move: Node2D
var touch_input: Node
var life_schedule: Node
var tutorial: GameTutorial
var prompt_elapsed: float = 0

func _ready() -> void:
	get_tree().quit_on_go_back = false
	get_tree().auto_accept_quit = false
	home = preload("res://scenes/world/home.tscn").instantiate()
	add_child(home)
	home.hide()
	home.process_mode = Node.PROCESS_MODE_DISABLED
	village = preload("res://scenes/world/village.tscn").instantiate()
	add_child(village)
	village.hide()
	village.get_node("Ground").enabled = false
	village.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("Camera2D").position.y = -60
	var atmosphere := CanvasLayer.new()
	atmosphere.layer = 4
	add_child(atmosphere)
	var weather := Control.new()
	weather.set_script(preload("res://scripts/presentation/weather_screen.gd"))
	atmosphere.add_child(weather)
	hud.movement.connect(func(direction: Vector2): player.touch_direction = direction)
	hud.bag_requested.connect(show_bag)
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)
	hud.sleep_requested.connect(GameClock.request_sleep)
	GameClock.day_ending.connect(on_day_ending)
	hud.mute_requested.connect(toggle_audio)
	Events.action_requested.connect(interact)
	Events.interaction_requested.connect(handle_interaction)
	GameClock.day_advanced.connect(queue_autosave)
	Events.progress_committed.connect(queue_autosave)
	Playtest.bind(self)
	WorldTravel.create_mines(self)
	var lake := AquacultureWorld.new()
	add_child(lake)
	lake.attach(self)
	var development_world := WorldDevelopmentWorld.new()
	add_child(development_world);development_world.attach(self)
	if not Housing.changed.is_connected(WorldChanges.refresh): Housing.changed.connect(WorldChanges.refresh)
	if not WorldDevelopment.changed.is_connected(WorldChanges.refresh): WorldDevelopment.changed.connect(WorldChanges.refresh)
	WorldDevelopment.changed.connect(village.refresh_gathering)
	var exploration_world := ExplorationWorld.new()
	add_child(exploration_world);exploration_world.attach(self)
	var housing_world := HousingWorld.new()
	add_child(housing_world);housing_world.attach(self)
	var festival_world := FestivalWorld.new()
	add_child(festival_world);festival_world.attach(self)
	var social_world := SocialWorld.new()
	add_child(social_world);social_world.attach(self)
	var kitchen_world := KitchenWorld.new()
	add_child(kitchen_world);kitchen_world.attach(self)
	var ecology := LakeEcologyWorld.new()
	add_child(ecology);ecology.attach(self)
	var fishing_world := FishingWorld.new()
	add_child(fishing_world);fishing_world.attach(self)
	var livestock_world := LivestockWorld.new()
	add_child(livestock_world);livestock_world.attach(self)
	Recovery.game=self
	var rest_point := Node2D.new()
	rest_point.set_script(preload("res://scripts/recovery/recovery_point.gd"))
	rest_point.position=Recovery.BENCH
	world.get_node("Actors").add_child(rest_point)
	var seasonal := SeasonLandscape.new()
	add_child(seasonal)
	seasonal.attach(self)
	build_xiaojing_world()
	var star_world := StarWorld.new()
	add_child(star_world)
	star_world.setup(self)
	life_schedule=preload("res://scripts/seasons/life_schedule.gd").new();add_child(life_schedule);life_schedule.attach(self)
	auto_move = Node2D.new()
	auto_move.set_script(preload("res://scripts/navigation/auto_move_controller.gd"))
	add_child(auto_move)
	auto_move.setup(self)
	auto_move.navigation.invalidate()
	# 最后添加，_input 先于现有原生触点按钮记录归属。
	touch_input = Node.new()
	touch_input.set_script(preload("res://scripts/input/touch_input_manager.gd"))
	add_child(touch_input)
	touch_input.setup(self)
	tutorial=GameTutorial.new();add_child(tutorial);tutorial.attach(self)
	Events.notice.emit("欢迎回家。屋东的信箱里，有一封留给你的信。")
	if persistence_enabled and (FileAccess.file_exists(FarmSaveStore.PATH) or FileAccess.file_exists(FarmSaveStore.PATH+".bak")):
		load_game()
	elif persistence_enabled:
		call_deferred("opening_letter")

func opening_letter() -> void:
	if Story.stage == 0 and not GameState.modal: Events.notice.emit("先回小屋看看。窗下木盒里有一封旧信和半张地图。")

func _process(delta: float) -> void:
	action_cooldown = maxf(0, action_cooldown - delta)
	if backgrounded: return
	if GameState.location == "farm": farm.highlight(player.target_cell())
	# 提示不是交互判定：10Hz足够跟随，按键/点击执行仍即时查询真实位置。
	prompt_elapsed+=delta
	if prompt_elapsed<0.1: return
	prompt_elapsed=0
	var resource := resource_target()
	world.resource_field.highlight(resource)
	if resource:
		var definition: Dictionary = FarmResourceCatalog.TYPES[resource.kind]
		hud.set_prompt("%s · %s  ·  耐久 %d" % [GameState.tool_names[GameState.selected],definition.name,world.resource_field.state[resource.resource_id].hp],false)
		return
	var nearest := nearest_interactable()
	if nearest:
		hud.set_prompt("E / 交互  ·  " + nearest.prompt(), true)
	else:
		hud.set_prompt(context_hint(), false)
		hud.action_button.text = context_action_name()+"\n使用" if GameState.location == "farm" else "交互"

func nearest_interactable() -> Node2D:
	var found: Node2D = null
	var distance: float = 58.0
	for object in get_tree().get_nodes_in_group("interactables"):
		if not object.is_visible_in_tree(): continue
		if "fish_point_id" in object and GameState.tool()!="fishing_rod": continue
		if ("mine_id" in object or "abyss_id" in object) and "active" in object and not object.active: continue
		var current: float = player.global_position.distance_to(object.global_position)
		if current < distance:
			distance = current
			found = object
	return found

func interact() -> void:
	if auto_move: auto_move.cancel()
	if backgrounded or GameState.modal or action_cooldown > 0: return
	var resource := resource_target()
	var nearest := nearest_interactable() if not resource else null
	# 工具不能重叠执行，人物/门口交互仍可及时打开原面板或换图。
	if player.action_time>0 and (resource or nearest==null): return
	action_cooldown = 0.16
	if resource:
		if world.resource_field.hit(resource.resource_id,GameState.tool()): player.start_action("采集")
		return
	if nearest:
		nearest.interact()
	else:
		if GameState.tool() in ["axe","pickaxe"]: Events.notice.emit("面向附近的树木或石堆，再使用工具。")
		elif GameState.location == "farm": player.begin_farm_action(farm,player.target_cell(),context_tool())
		else: Events.notice.emit("沿河走走，靠近村民、木牌或长椅再交互。" if GameState.location == "village" else "走到床边休息，或从下方门口返回农场。")

func resource_target() -> Node2D:
	if GameState.location != "farm" or GameState.tool() not in ["axe","pickaxe"]: return null
	return world.resource_field.find_target(player.global_position,player.facing)

func handle_interaction(kind: String) -> void:
	if backgrounded: return
	if auto_move: auto_move.cancel()
	if kind.begins_with("world_development:"): hud.world_development_panel.open_panel(kind.trim_prefix("world_development:"))
	elif kind.begins_with("exploration:"): hud.exploration_panel.open_panel(kind.trim_prefix("exploration:"))
	elif kind.begins_with("housing:"): hud.housing_panel.open_panel(kind.trim_prefix("housing:"))
	elif kind.begins_with("festival:"): hud.festival_panel.open_panel(kind.trim_prefix("festival:"))
	elif kind.begins_with("social_site:"): hud.social_panel.open_site(kind.trim_prefix("social_site:"))
	elif kind.begins_with("social:"): hud.social_panel.open_panel(kind.trim_prefix("social:"))
	elif kind=="kitchen": hud.kitchen_panel.open_panel()
	elif kind=="kitchen:berry": hud.kitchen_panel.open_panel("berry")
	elif kind=="ecology": hud.ecology_panel.open_panel()
	elif kind.begins_with("fishing:"): hud.fishing_panel.open_panel(kind.trim_prefix("fishing:"))
	elif kind.begins_with("livestock:"): hud.livestock_panel.open_panel(kind.trim_prefix("livestock:"))
	elif kind=="recovery": hud.recovery_panel.open_panel()
	elif kind=="calendar": hud.calendar_panel.open_panel()
	elif kind.begins_with("fish:"): hud.aquaculture_panel.open_panel(kind.trim_prefix("fish:"))
	elif kind.begins_with("river:"): hud.river_panel.open_panel(kind.trim_prefix("river:"))
	elif kind.begins_with("abyss:"): hud.abyss_panel.open_panel(kind.trim_prefix("abyss:"))
	elif kind.begins_with("star:"): hud.star_panel.open_panel(kind.trim_prefix("star:"))
	elif kind.begins_with("mine:"): MineInteractions.request(self,kind.trim_prefix("mine:"))
	elif kind.begins_with("xiaojing_memory:"): hud.star_panel.open_panel("memory:"+kind.trim_prefix("xiaojing_memory:"))
	elif kind.begins_with("xiaojing"): hud.xiaojing_panel.open_panel(kind)
	elif kind == "home": change_location("home")
	elif kind == "exit": change_location("farm")
	elif kind == "sleep": hud.system_panel.open_panel(true)
	elif kind == "shop": hud.inventory_panel.open_panel(true)
	elif kind == "workshop": hud.progress_panel.open_panel("workshop",true)
	elif kind == "board": hud.progress_panel.open_panel("journal",true)
	elif kind == "journal": hud.progress_panel.open_panel("journal",false)
	elif kind == "village": change_location("village")
	elif kind == "farm_return": change_location("farm",Vector2(480,260))
	elif kind == "story": hud.story_panel.open_panel()
	elif kind == "community": hud.story_panel.open_panel(true)

func change_location(destination: String, saved_position: Vector2 = Vector2.INF) -> void:
	WorldTravel.change(self,destination,saved_position)

func recover_blocked_position() -> void:
	# JSON 坐标合法但可能落在碰撞体中；保留其余进度并回到安全出生点。
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.transform = player.global_transform
	query.collision_mask = 1
	var hits := player.get_world_2d().direct_space_state.intersect_shape(query,1)
	if not hits.is_empty():
		player.position = WorldTravel.entry(GameState.location)
		player.get_node("Camera2D").reset_smoothing()

func save_game() -> void:
	cancel_pending_save()
	if FarmSaveStore.write(self): Events.notice.emit("进度已保存。下次回来会继续这一天。")
	else: Events.notice.emit("保存失败，原有存档仍保留。")

func load_game() -> void:
	var data := FarmSaveStore.read()
	if data.is_empty():
		Events.notice.emit("没有找到有效存档，当前进度保持不变。")
		return
	FarmSaveStore.restore(self,data)
	Events.notice.emit("已回到第 %d 天，欢迎回家。" % GameClock.day)

func cancel_pending_save() -> void:
	autosave_epoch+=1
	autosave_pending=false

func queue_autosave() -> void:
	if not persistence_enabled or closing or autosave_pending: return
	autosave_pending=true
	call_deferred("flush_autosave",autosave_epoch)

func flush_autosave(epoch: int) -> void:
	if epoch!=autosave_epoch: return
	autosave_pending=false
	autosave()

func autosave() -> void:
	cancel_pending_save()
	# 成功时静默保存，保留刚领取的奖励提示；只有失败才打断通知。
	if persistence_enabled and not FarmSaveStore.write(self):
		Events.notice.emit("自动保存失败，请在菜单中重试保存。")

func toggle_audio() -> void:
	$Audio.muted = not $Audio.muted
	Events.notice.emit("音乐与环境声已关闭" if $Audio.muted else "音乐与环境声已开启")

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if not backgrounded:
			backgrounded = true
			player.suspended = true
			player.cancel_farm_action()
			was_running = GameClock.running
			GameClock.running = false
			$Audio.in_background = true
			player.touch_direction = Vector2.ZERO
			auto_move.cancel()
			touch_input.reset()
			hud.joystick.reset()
			for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			autosave()
			Playtest.record("background",{"value":true});Playtest.flush()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		if backgrounded:
			backgrounded = false
			player.suspended = false
			GameClock.running = was_running
			$Audio.in_background = false
			hud.update_safe_area()
			Playtest.record("background",{"value":false})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		close_session()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not hud.close_active_panel(): hud.system_panel.open_panel()

func close_session() -> void:
	if closing: return
	closing = true
	freeze_for_close()
	autosave()
	Playtest.flush()
	$Audio.stop_all()
	$Audio.set_process(false)
	# 混音线程延迟释放播放对象；正常关窗留一轮清理时间，防止长音乐在退出时残留。
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func show_bag() -> void:
	hud.inventory_panel.open_panel(false)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.modal or backgrounded: return
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_tool"):
		GameState.select_tool(GameState.selected + 1)
	elif event.is_action_pressed("bag"):
		show_bag()
	elif event.is_action_pressed("journal"):
		hud.progress_panel.open_panel("journal",false)
	elif event.is_action_pressed("story_map"):
		hud.story_panel.open_panel()
	elif event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
	elif event.is_action_pressed("ui_cancel"):
		hud.system_panel.open_panel()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			var index: int = event.physical_keycode - KEY_1
			if index < GameState.tools.size(): GameState.select_tool(index)

func context_tool() -> String:
	var selected := GameState.tool()
	if not Story.assisted_tools or selected in ["axe","pickaxe"]: return selected
	var plot: Dictionary = farm.plots.get(farm.key(player.target_cell()),{})
	if not plot.is_empty() and str(plot.crop) != "":
		if farm.is_mature(plot): return "hand"
		if not plot.watered: return "water"
	return selected

func context_action_name() -> String:
	return {"hoe":"翻土","water":"浇水","hand":"收获","axe":"砍伐","pickaxe":"采石","fishing_rod":"抛竿"}.get(context_tool(),"播种")

func context_hint() -> String:
	if GameState.location in Exploration.AREAS: return Story.NAMES[GameState.location]+" · 点击路标和机关，调查提示后再操作，沿入口返回"
	if GameState.location=="greenhouse": return "星光温室 · 左右桌准备仪式 · 星灯下交换约定 · 档案桌安排日常"
	if GameState.location=="abyss": return "深渊%d层 · 空气%d/160 · 检查刻痕、机关和安全绳" % [AbyssState.state.depth,AbyssState.state.air]
	if GameState.location in MineState.AREAS: return "点击矿脉采一次 · 阶梯返回 · 手记查看矿道任务"
	if GameState.location == "home": return "20:00后床边休息 · 白天可去屋东休息椅 · 下方门口回农场"
	if GameState.location != "farm": return "沿河慢慢走 · 靠近村民或物件可交互"
	var plot: Dictionary = farm.plots.get(farm.key(player.target_cell()),{})
	if not plot.is_empty() and str(plot.crop) != "":
		var crop = Catalog.crops[plot.crop]
		if not farm.is_mature(plot) and not Catalog.crop_grows(plot.crop): return "%s · 冬季休眠，转暖后继续生长" % crop.display_name
		return "%s · %s" % [Catalog.item_name(plot.crop),"可以收获了" if farm.is_mature(plot) else ("已浇水 · 还需 %d 个生长日" % (crop.growth_days-int(plot.days)) if plot.watered else "需要一点水")]
	return "对准脚前亮框 · "+context_action_name()

func restore_schedules() -> void:
	# 等待新桥面/碰撞在物理服务器同步后再恢复 NPC 站点。
	if schedule_restore_pending: return
	schedule_restore_pending = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	village.refresh_gathering()
	world.refresh_linya()
	for person in village.villagers.values():
		person.reset_station()
		if person.station != Vector2.INF:
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = person.get_node("CollisionShape2D").shape
			query.exclude = [person.get_rid()]
			query.collision_mask = 3
			query.transform = Transform2D(0,person.station)
			if person.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): person.position = person.station
	if life_schedule: life_schedule.refresh()
	schedule_restore_pending = false

func build_xiaojing_world() -> void:
	for memory in Xiaojing.data.memories:
		var point := Node2D.new()
		point.set_script(preload("res://scripts/world/xiaojing_point.gd"))
		point.memory_id = memory.id
		point.title = memory.title
		point.position = Vector2(memory.position[0],memory.position[1])
		var map: Node = {"farm":world.get_node("Actors"),"home":home,"village":village.get_node("Actors")}[memory.location]
		map.add_child(point)
	for location in ["farm","village","home"]:
		var person := preload("res://scenes/npc/linya.tscn").instantiate()
		person.person_id = "xiaojing"
		person.position = {"farm":Vector2(1232,800),"village":Vector2(1120,624),"home":Vector2(720,452)}[location]
		person.get_node("Sprite2D").texture = load("res://assets/characters/xiaojing.png")
		var parent: Node = {"farm":world.get_node("Actors"),"home":home,"village":village.get_node("Actors")}[location]
		parent.add_child(person)
		var refresh_person := func():
			StarWorld.schedule(person,location,self)
		Social.changed.connect(refresh_person)
		LakeEcology.changed.connect(refresh_person)
		Aquaculture.changed.connect(refresh_person)
		StarStory.changed.connect(refresh_person)
		Xiaojing.changed.connect(refresh_person)
		GameClock.changed.connect(refresh_person)
		VillageProjects.changed.connect(refresh_person)
		refresh_person.call()
	var greenhouse := Node2D.new()
	greenhouse.set_script(preload("res://scripts/world/greenhouse.gd"))
	greenhouse.position = Vector2(1280,780)
	world.get_node("Actors").add_child(greenhouse)

func on_day_ending(_reason: String) -> void:
	if _reason=="fatigue" and GameState.location=="abyss": AbyssState.rescue("fatigue")
	if auto_move: auto_move.cancel()
	player.touch_direction=Vector2.ZERO
	player.auto_direction=Vector2.ZERO
	player.velocity=Vector2.ZERO
	player.action_time=0
	hud.joystick.reset()
	if touch_input: touch_input.reset()
	while hud.close_active_panel(): pass
	GameState.set_modal(false)

func freeze_for_close() -> void:
	GameClock._process(0) # 若已到午夜，先唯一结算再保存。
	GameClock.running=false
	auto_move.cancel()
	player.touch_direction=Vector2.ZERO
	touch_input.reset();hud.joystick.reset()
	GameState.set_modal(true)
