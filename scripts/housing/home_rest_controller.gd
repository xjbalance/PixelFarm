class_name HomeRestController
extends Node
## 沙发只有一次同步事务；过渡不携带待发奖励，存读档不重放休息。
const SOFA:=Vector2(704,492)
var game: Node
var sofa_point: Node2D
var bed_point: Node2D
var opened_anchor:=Vector2.ZERO
var panel: PanelContainer
var confirm_button: Button
var cancel_button: Button
var body: Label
var overlay: ColorRect
var busy: bool=false
var pending_token: int=-1
var serial: int=0
var opened_day: int=0
var opened_minute: float=0
var transition: Tween
var confirmation_callback:=Callable()

func setup(owner_game: Node) -> void:
	game=owner_game
	var point:=Node2D.new();point.name="SofaNap"
	point.set_script(preload("res://scripts/housing/home_action_point.gd"));point.home_action="nap";point.builtin_id="sofa";point.position=Housing.anchor("sofa");sofa_point=point

	game.home.add_child(point)
	# 原床保留坐标/业务，仅换为整张床可点的命中框。
	for object in game.home.get_children():
		if "kind" in object and object.kind=="sleep":
			object.remove_from_group("interactables");object.queue_free()
	var bed:=Node2D.new();bed.name="BedRest";bed.set_script(preload("res://scripts/housing/home_action_point.gd"));bed.home_action="sleep";bed.builtin_id="bed";bed.position=Housing.anchor("sleep");bed_point=bed;game.home.add_child(bed)
	Housing.changed.connect(sync_layout)
	panel=PanelContainer.new();panel.set_script(preload("res://scripts/housing/home_rest_panel.gd"));panel.controller=self;panel.name="HomeNapConfirmation";panel.add_to_group("modal_panels");panel.set_meta("home_confirmation",true)
	panel.hide();game.hud.safe.add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	column.add_child(FarmUIStyle.label("在家歇一会儿",24,FarmUIStyle.TITLE))
	body=FarmUIStyle.label("",18);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(body)
	var row:=HBoxContainer.new();column.add_child(row)
	cancel_button=FarmUIStyle.button("先不休息",close_panel,160);row.add_child(cancel_button)
	confirm_button=FarmUIStyle.button("确认小睡 1 小时",func(): pass,220);confirm_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(confirm_button)
	overlay=ColorRect.new();overlay.color=Color(0.12,0.08,0.05,0);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.hide();game.hud.safe.add_child(overlay)
	Events.location_changed.connect(func(_id: String): cancel())
	GameState.control_mode_changed.connect(cancel)
	panel.minimum_size_changed.connect(func(): game.hud.call_deferred("reflow_panels"))

func sync_layout() -> void:
	var changed_anchor: bool=is_instance_valid(sofa_point) and sofa_point.position!=Housing.anchor("sofa")
	if is_instance_valid(sofa_point): sofa_point.position=Housing.anchor("sofa")
	if is_instance_valid(bed_point): bed_point.position=Housing.anchor("sleep")
	if changed_anchor and is_instance_valid(panel) and panel.visible: cancel()

func available() -> bool:
	return is_instance_valid(game) and not game.backgrounded and not game.closing and not GameState.restoring and not GameClock.settling and GameState.location=="home" and not game.player.suspended and game.player.action_time<=0 and GameClock.minutes<1440 and GameClock.day<999999 and game.player.global_position.distance_to(Housing.anchor("sofa"))<=54 and game.auto_move.navigation.line_of_sight(game.player.global_position,Housing.anchor("sofa"),sofa_point)

func open() -> bool:
	if busy or GameState.modal or not available(): return false
	game.auto_move.cancel();game.player.velocity=Vector2.ZERO
	serial+=1;pending_token=serial;opened_day=GameClock.day;opened_minute=GameClock.minutes;opened_anchor=Housing.anchor("sofa")
	var amount: int=ceili(GameState.max_stamina()*.5)
	var full: bool=GameState.stamina>=GameState.max_stamina()
	body.text="小睡1小时，恢复最大体力的50%%（%d点）。\n不超过上限，不占屋东休息椅次数。" % amount
	if full: body.text+="\n体力已满：本次只推进时间。"
	if GameClock.minutes+60>=1440: body.text+="\n到午夜优先昏睡：次日06:00醒来，按原规则恢复60%体力，不补剩余分钟。"
	body.text+="\n正式床睡眠仍需20:00后。"
	panel.set_meta("home_confirmation_height",(330 if GameClock.minutes+60>=1440 else 270)+maxf(0,UIMetrics.minimum_target()-48))
	if confirmation_callback.is_valid() and confirm_button.pressed.is_connected(confirmation_callback): confirm_button.pressed.disconnect(confirmation_callback)
	confirmation_callback=confirm.bind(pending_token);confirm_button.pressed.connect(confirmation_callback)
	confirm_button.disabled=false;cancel_button.disabled=false
	GameState.set_modal(true);panel.show();game.hud.call_deferred("reflow_panels")
	return true

func confirm(token: int) -> bool:
	if opened_anchor.distance_to(Housing.anchor("sofa"))>.01 or busy or token<0 or token!=pending_token or not panel.visible or not GameState.modal or not available() or opened_day!=GameClock.day or absf(opened_minute-GameClock.minutes)>.01: return false
	# 先使旧按钮无效，再一次性提交时间与体力；所有保存信号都在完整状态之后。
	pending_token=-1;serial+=1;busy=true;panel.hide();confirm_button.disabled=true
	var fatigue: bool=GameClock.minutes+60>=1440
	var previous: int=GameState.stamina
	if fatigue:
		GameClock.minutes=1440
		GameClock._process(0) # 唯一的原午夜入口；不补完余下分钟、不再加半管体力。
	else:
		GameClock.minutes+=60
		GameState.stamina=mini(GameState.max_stamina(),GameState.stamina+ceili(GameState.max_stamina()*.5))
		GameClock.changed.emit();GameState.changed.emit()
	GameState.set_modal(true)
	Events.progress_committed.emit()
	if not fatigue: Events.notice.emit("在沙发小睡1小时，恢复%d体力。" % (GameState.stamina-previous))
	overlay.color.a=.55;overlay.show()
	transition=create_tween();transition.tween_property(overlay,"color:a",0.0,.3)
	transition.finished.connect(finish)
	return true

func finish() -> void:
	if not busy: return
	busy=false;overlay.hide();GameState.set_modal(false)

func close_panel() -> void:
	if busy: return
	var was_visible: bool=is_instance_valid(panel) and panel.visible
	pending_token=-1;serial+=1
	if is_instance_valid(panel): panel.hide()
	if was_visible: GameState.set_modal(false)

func cancel() -> void:
	var owned_modal: bool=busy or (is_instance_valid(panel) and panel.visible)
	pending_token=-1;serial+=1;busy=false
	if transition and transition.is_valid(): transition.kill()
	if is_instance_valid(overlay): overlay.hide()
	if is_instance_valid(panel): panel.hide()
	if owned_modal: GameState.set_modal(false)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(panel) and panel.visible and event.is_action_pressed("ui_cancel"):
		close_panel();get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: cancel()
