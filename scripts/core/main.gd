extends Node
## 主场景只负责协调场景与交互，玩法规则留在各个系统里。
@export var persistence_enabled: bool = true
@onready var world: Node2D = $FarmWorld
@onready var player: CharacterBody2D = $FarmWorld/Actors/Player
@onready var farm: Node2D = $FarmWorld/FarmPlots
@onready var hud: CanvasLayer = $HUD
var action_cooldown: float = 0.0
var home: Node2D
var village: Node2D
var was_running: bool = true
var backgrounded: bool = false
var closing: bool = false
var schedule_restore_pending: bool = false
var auto_move: Node2D
var touch_input: Node

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
	hud.sleep_requested.connect(GameClock.next_day)
	hud.mute_requested.connect(toggle_audio)
	Events.action_requested.connect(interact)
	Events.interaction_requested.connect(handle_interaction)
	GameClock.day_advanced.connect(autosave)
	Events.progress_committed.connect(func(): call_deferred("autosave"))
	build_xiaojing_world()
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
	Events.notice.emit("欢迎回家。屋东的信箱里，有一封留给你的信。")
	if persistence_enabled and (FileAccess.file_exists(FarmSaveStore.PATH) or FileAccess.file_exists(FarmSaveStore.PATH+".bak")):
		load_game()
	elif persistence_enabled:
		call_deferred("opening_letter")

func opening_letter() -> void:
	if Story.stage == 0 and not GameState.modal: Events.notice.emit("先回小屋看看。窗下木盒里有一封旧信和半张地图。")

func _process(delta: float) -> void:
	action_cooldown = maxf(0, action_cooldown - delta)
	if GameState.location == "farm": farm.highlight(player.target_cell())
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
		var current: float = player.global_position.distance_to(object.global_position)
		if current < distance:
			distance = current
			found = object
	return found

func interact() -> void:
	if auto_move: auto_move.cancel()
	if GameState.modal or action_cooldown > 0: return
	action_cooldown = 0.16
	var resource := resource_target()
	if resource:
		world.resource_field.hit(resource.resource_id,GameState.tool())
		return
	var nearest := nearest_interactable()
	if nearest:
		nearest.interact()
	else:
		if GameState.tool() in ["axe","pickaxe"]: Events.notice.emit("面向附近的树木或石堆，再使用工具。")
		elif GameState.location == "farm": farm.use_tool(player.target_cell(), context_tool())
		else: Events.notice.emit("沿河走走，靠近村民、木牌或长椅再交互。" if GameState.location == "village" else "走到床边休息，或从下方门口返回农场。")

func resource_target() -> Node2D:
	if GameState.location != "farm" or GameState.tool() not in ["axe","pickaxe"]: return null
	return world.resource_field.find_target(player.global_position,player.facing)

func handle_interaction(kind: String) -> void:
	if auto_move: auto_move.cancel()
	if kind.begins_with("xiaojing"): hud.xiaojing_panel.open_panel(kind)
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
	if destination not in ["farm","home","village"]: return
	if auto_move: auto_move.cancel()
	GameState.location = destination
	player.touch_direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	hud.joystick.reset()
	# 复用同一个角色节点，避免换图时出现两份背包或两台摄像机。
	var target: Node2D = home if destination == "home" else world.get_node("Actors")
	if destination == "village": target = village.get_node("Actors")
	player.reparent(target,false)
	world.visible = destination == "farm"
	world.get_node("Ground").enabled = destination == "farm"
	home.visible = destination == "home"
	village.visible = destination == "village"
	village.get_node("Ground").enabled = destination == "village"
	world.process_mode = Node.PROCESS_MODE_INHERIT if destination == "farm" else Node.PROCESS_MODE_DISABLED
	home.process_mode = Node.PROCESS_MODE_INHERIT if destination == "home" else Node.PROCESS_MODE_DISABLED
	village.process_mode = Node.PROCESS_MODE_INHERIT if destination == "village" else Node.PROCESS_MODE_DISABLED
	var entry: Vector2 = {"farm":Vector2(656,440),"home":Vector2(640,500),"village":Vector2(640,756)}[destination]
	player.position = saved_position if saved_position != Vector2.INF else entry
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2.ONE if destination == "home" else Vector2(1.35,1.35)
	camera.position.y = 0 if destination == "home" else -60
	camera.limit_right = 1536 if destination == "farm" else 1280
	camera.limit_bottom = {"farm":1024,"home":720,"village":896}[destination]
	camera.reset_smoothing()
	$DayNight.refresh()
	Events.location_changed.emit(destination)
	Xiaojing.record_location(destination)
	call_deferred("restore_schedules")
	GameState.changed.emit()

func recover_blocked_position() -> void:
	# JSON 坐标合法但可能落在碰撞体中；保留其余进度并回到安全出生点。
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.transform = player.global_transform
	query.collision_mask = 1
	var hits := player.get_world_2d().direct_space_state.intersect_shape(query,1)
	if not hits.is_empty():
		player.position = {"home":Vector2(640,500),"farm":Vector2(656,440),"village":Vector2(640,756)}[GameState.location]
		player.get_node("Camera2D").reset_smoothing()

func save_game() -> void:
	if FarmSaveStore.write(self): Events.notice.emit("进度已保存。下次回来会继续这一天。")
	else: Events.notice.emit("保存失败，原有存档仍保留。")

func load_game() -> void:
	var data := FarmSaveStore.read()
	if data.is_empty():
		Events.notice.emit("没有找到有效存档，当前进度保持不变。")
		return
	FarmSaveStore.restore(self,data)
	Events.notice.emit("已回到第 %d 天，欢迎回家。" % GameClock.day)

func autosave() -> void:
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
			was_running = GameClock.running
			GameClock.running = false
			$Audio.in_background = true
			player.touch_direction = Vector2.ZERO
			auto_move.cancel()
			touch_input.reset()
			hud.joystick.reset()
			for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			autosave()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		if backgrounded:
			backgrounded = false
			GameClock.running = was_running
			$Audio.in_background = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		close_session()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not hud.close_active_panel(): hud.system_panel.open_panel()

func close_session() -> void:
	if closing: return
	closing = true
	autosave()
	$Audio.stop_all()
	$Audio.set_process(false)
	# 混音线程延迟释放播放对象；正常关窗留一轮清理时间，防止长音乐在退出时残留。
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func show_bag() -> void:
	hud.inventory_panel.open_panel(false)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.modal: return
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
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
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
	return {"hoe":"翻土","water":"浇水","hand":"收获","axe":"砍伐","pickaxe":"采石"}.get(context_tool(),"播种")

func context_hint() -> String:
	if GameState.location == "home": return "床边可以休息 · 下方门口回农场"
	if GameState.location != "farm": return "沿河慢慢走 · 靠近村民或物件可交互"
	var plot: Dictionary = farm.plots.get(farm.key(player.target_cell()),{})
	if not plot.is_empty() and str(plot.crop) != "":
		var crop = Catalog.crops[plot.crop]
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
		person.get_node("Sprite2D").texture = preload("res://assets/characters/xiaojing.png")
		var parent: Node = {"farm":world.get_node("Actors"),"home":home,"village":village.get_node("Actors")}[location]
		parent.add_child(person)
		var refresh_person := func():
			var place := "village" if GameClock.minutes < 1080 else ("home" if Xiaojing.state.married and GameClock.minutes>=1260 else "farm")
			# 共同活动时到茶座，婚后仍保留独立的白天工作。
			if GameClock.minutes>=1080 and GameClock.minutes<1200 and VillageProjects.has_project("arbor"): place="village"
			var desired: Vector2 = Vector2(624,624) if location=="village" and GameClock.minutes>=1080 else {"farm":Vector2(1232,800),"village":Vector2(1120,624),"home":Vector2(720,452)}[location]
			if GameState.location == location and player.global_position.distance_to(desired)<30:
				desired += Vector2(40,0)
			person.position = desired
			person.visible = Xiaojing.state.unlocked and place == location
			person.process_mode = Node.PROCESS_MODE_INHERIT if person.visible else Node.PROCESS_MODE_DISABLED
		Xiaojing.changed.connect(refresh_person)
		GameClock.changed.connect(refresh_person)
		VillageProjects.changed.connect(refresh_person)
		refresh_person.call()
	var greenhouse := Node2D.new()
	greenhouse.set_script(preload("res://scripts/world/greenhouse.gd"))
	greenhouse.position = Vector2(1280,780)
	world.get_node("Actors").add_child(greenhouse)
