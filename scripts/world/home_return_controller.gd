class_name HomeReturnController
extends Node
## 回家只复用原场景切换；不推进日期、不恢复体力、不生成奖励。
var game: Node
var busy: bool=false
var execution_count: int=0
var _fingers: Dictionary={}
var _mouse_down: bool=false
var _blocked: bool=false

func setup(owner_game: Node) -> void:
	game=owner_game
	game.hud.home_return_requested.connect(request)
	update_button()

func unavailable_reason() -> String:
	if not is_instance_valid(game) or game.closing or game.backgrounded or GameState.restoring or GameClock.settling: return "当前暂时无法回家。"
	if GameClock.minutes>=1440: return "今天已经结束，请等待正常休息结算。"
	if game.player.suspended or game.farm.committing or Housing.busy or game.resource_world.committing(): return "当前动作正在结算，请稍后再回家。"
	if game.awaiting_character_choice or GameState.modal: return "请先关闭当前界面，再传送回家。"
	if GameState.location=="home": return "你已经在家里了。"
	if StarStory.state.wedding_phase==3 and GameState.location=="greenhouse": return "请先完成当前温室仪式，再传送回家。"
	if not MineState.state.expedition.is_empty(): return "矿洞考察中，请沿原出口完成回程。"
	if Fishing.active(): return "请先收起鱼线，再传送回家。"
	return ""

func can_return() -> bool:
	return not busy and unavailable_reason()==""

func landing_point() -> Vector2:
	var level: int=int(Housing.state.level)
	var obstacles: Array[Rect2]=HomeLayout.blocked_rects(level,Housing.state.builtins)
	for entry in Housing.state.placed:
		if entry.area!="home" or not Housing.data.furniture[entry.kind].solid: continue
		var rect: Rect2i=Housing.footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
		obstacles.append(Rect2(Vector2(rect.position)*32+Vector2(2,2),Vector2(rect.size)*32-Vector2(4,4)))
	var door: Vector2=HomeLayout.ANCHORS.exit
	var candidates: Array[Vector2]=[door+Vector2(0,-20),door,door+Vector2(16,-28),door+Vector2(-16,-28),door+Vector2(32,-28),door+Vector2(-32,-28)]
	for point in candidates:
		var foot:=Rect2(point-Vector2(10,10),Vector2(20,20))
		if not HomeLayout.floor_encloses(foot,level): continue
		var corridor:=Rect2(door,Vector2.ZERO).expand(point).grow(10.02)
		var clear: bool=true
		for obstacle in obstacles:
			if foot.grow(.02).intersects(obstacle) or corridor.intersects(obstacle): clear=false;break
		if not clear: continue
		# 室内可能未激活：静态家具按真实几何验证，人物按自身坐标保守避让。
		for person in game.get_tree().get_nodes_in_group("interactables"):
			if person is CharacterBody2D and game.home.is_ancestor_of(person) and person.visible and person.global_position.distance_to(point)<28:
				clear=false;break
		if clear: return point
	return Vector2.INF

func request() -> bool:
	if busy or _blocked or not _fingers.is_empty() or _mouse_down: return false
	var reason: String=unavailable_reason()
	if reason!="": Events.notice.emit(reason);return false
	var destination:=landing_point()
	if destination==Vector2.INF:
		Events.notice.emit("门口暂时没有安全落脚位置，请稍后再试。")
		return false
	busy=true
	stop_previous_action()
	var previous: String=GameState.location
	var accepted: bool=WorldTravel.change(game,"home",destination)
	if accepted:
		game.player.facing=Vector2.UP;game.camera_rig.follow_now()
		execution_count+=1
		if previous=="abyss": Playtest.record("mine_exit",{"source":"abyss","depth":AbyssState.state.depth,"reason":"home_return"})
		Events.progress_committed.emit();Events.notice.emit("已回到家中。")
	call_deferred("release_busy")
	update_button()
	return accepted

func stop_previous_action() -> void:
	game.auto_move.cancel();game.player.cancel_farm_action();game.player.action_time=0
	game.player.auto_direction=Vector2.ZERO;game.player.touch_direction=Vector2.ZERO;game.player.velocity=Vector2.ZERO
	game.hud.joystick.reset();game.touch_input.reset()
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)

func release_busy() -> void:
	busy=false;update_button()

func update_button() -> void:
	if not is_instance_valid(game): return
	var button: Button=game.hud.home_return_button
	button.disabled=not can_return()
	button.tooltip_text="一键传送回家 · 不消耗时间或体力" if not button.disabled else unavailable_reason()
	button.visible=not GameState.modal and not game.awaiting_character_choice and not game.backgrounded and not game.closing

func _process(_delta: float) -> void:
	update_button()

func clear_block_if_idle() -> void:
	if _fingers.is_empty() and not _mouse_down: _blocked=false

func _input(event: InputEvent) -> void:
	# 只取消回家按钮的混合/多指候选，世界和其他UI仍接收原输入流。
	if event is InputEventScreenTouch:
		if event.pressed:
			if _fingers.has(event.index) or _mouse_down: _blocked=true
			_fingers[event.index]=true
			if _fingers.size()>1 or event.canceled: _blocked=true
			elif not _blocked and can_return() and game.hud.home_return_button.is_visible_in_tree() and not game.hud.home_return_button.disabled and game.hud.home_return_button.contains_touch(event.position): stop_previous_action()
		else: _fingers.erase(event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device>=0:
		_mouse_down=event.pressed
		if not _fingers.is_empty(): _blocked=true
		if event.pressed and not _blocked and can_return() and game.hud.home_return_button.is_visible_in_tree() and not game.hud.home_return_button.disabled and game.hud.home_return_button.get_global_rect().has_point(event.position): stop_previous_action()
	else: return
	if _blocked:
		game.hud.home_return_button.reset_touch()
		if _fingers.is_empty() and not _mouse_down: call_deferred("clear_block_if_idle")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_fingers.clear();_mouse_down=false;_blocked=false
		if is_instance_valid(game): game.hud.home_return_button.reset_touch()
