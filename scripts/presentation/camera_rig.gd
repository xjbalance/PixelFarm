class_name WorldCameraRig
extends Node
## 镜头状态完全瞬态。只改变Camera2D，不修改角色/地图/玩法数据。
enum Mode { FOLLOW, FREE_LOOK, RETURNING }
var mode: Mode=Mode.FOLLOW
var game: Node
var camera: Camera2D
var view_center:=Vector2.ZERO
var dragging: bool=false
var return_button: Button
var backdrop: ColorRect

func setup(owner_game: Node) -> void:
	game=owner_game;camera=game.player.get_node("Camera2D")
	process_physics_priority=10 # 玩家物理移动之后，镜头与当前脚底同步。
	camera.position_smoothing_enabled=false
	camera.process_callback=Camera2D.CAMERA2D_PROCESS_PHYSICS
	var layer:=CanvasLayer.new();layer.layer=-20;add_child(layer)
	backdrop=ColorRect.new();backdrop.color=Color("203029")
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(backdrop)
	return_button=FarmUIStyle.button("回到人物",func(): return_to_player(true),104)
	return_button.hide()
	return_button.tooltip_text="返回人物中心，恢复跟随"
	game.hud.safe.add_child(return_button)
	game.hud.place(return_button,Vector2(1,0),Vector2(1,0),Rect2(-132,94,120,UIMetrics.minimum_target()))
	Events.location_changed.connect(func(_id: String): map_changed())
	GameState.control_mode_changed.connect(follow_now)
	Events.modal_changed.connect(func(active: bool):
		if active: end_free_look()
	)
	GameClock.day_ending.connect(func(_reason: String): follow_now())
	get_viewport().size_changed.connect(func(): apply_camera())
	map_changed()

func map_rect() -> Rect2:
	if GameState.location in RanchLayout.AREAS: return RanchLayout.world_rect(RanchLayout.site(GameState.location))
	if GameState.location=="farm": return FarmLayoutCatalog.WORLD
	if GameState.location=="home": return HomeLayout.map_rect(int(Housing.state.level))
	return Rect2(0,0,1280,896)

func map_bounds() -> Rect2:
	var made:=map_rect()
	# Keep edge plots and moving animals out from under the preserved full HUD.
	if GameState.location=="farm": made=made.grow(224)
	elif GameState.location in RanchLayout.AREAS: made=made.grow(128)
	var visible_size:=get_viewport().get_visible_rect().size/camera.zoom
	var size:=Vector2(maxf(made.size.x,visible_size.x),maxf(made.size.y,visible_size.y))
	return Rect2(made.get_center()-size/2,size)

func clamp_center(point: Vector2) -> Vector2:
	var bounds:=map_bounds()
	var half:=get_viewport().get_visible_rect().size/camera.zoom/2
	return point.clamp(bounds.position+half,bounds.end-half)

func follow_center() -> Vector2:
	return clamp_center(game.player.global_position)

func can_free_look() -> bool:
	if GameState.modal or GameState.restoring or game.backgrounded or game.player.suspended or GameClock.settling: return false
	if game.player.action_time>0 or game.player.velocity.length_squared()>1: return false
	if Input.get_vector("move_left","move_right","move_up","move_down").length()>.05 or game.player.touch_direction.length()>.08: return false
	if game.auto_move.state in [game.auto_move.State.PATHFINDING,game.auto_move.State.MOVING,game.auto_move.State.INTERACTING]: return false
	if GameState.location=="greenhouse" and StarStory.state.wedding_phase in [1,2,3]: return false
	return true

func begin_free_look() -> bool:
	if not can_free_look(): return false
	view_center=camera.get_screen_center_position()
	mode=Mode.FREE_LOOK;dragging=true
	game.auto_move.cancel()
	return true

func pan_screen(delta: Vector2) -> void:
	if not dragging or mode!=Mode.FREE_LOOK or not can_free_look():
		dragging=false;return
	view_center=clamp_center(view_center-delta/camera.zoom*UILayout.DRAG_SENSITIVITY)
	apply_camera()

func end_free_look() -> void:
	dragging=false

func return_to_player(smooth: bool = true) -> void:
	dragging=false
	if smooth:
		mode=Mode.RETURNING
	else: follow_now()

func follow_now() -> void:
	if not is_instance_valid(game) or not is_instance_valid(camera): return
	dragging=false;mode=Mode.FOLLOW;view_center=follow_center();apply_camera()

func map_changed() -> void:
	camera.offset=Vector2.ZERO
	# 统一由上面的可见区域约束，避免Camera原生限位与小图填充互相拉扯。
	camera.limit_left=-1000000;camera.limit_top=-1000000
	camera.limit_right=1000000;camera.limit_bottom=1000000
	follow_now()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	return_button.visible=not GameState.modal and not game.backgrounded and mode==Mode.FREE_LOOK and view_center.distance_to(follow_center())>1
	if game.backgrounded: dragging=false;return
	if game.player.velocity.length_squared()>1 or game.player.auto_direction.length()>.01 or game.player.touch_direction.length()>.08 or game.player.action_time>0:
		mode=Mode.FOLLOW;dragging=false
	if mode==Mode.FOLLOW: view_center=follow_center()
	elif mode==Mode.RETURNING:
		view_center=view_center.lerp(follow_center(),1-exp(-UILayout.CAMERA_RETURN_SPEED*delta))
		if view_center.distance_to(follow_center())<.5: mode=Mode.FOLLOW;view_center=follow_center()
	apply_camera()

func apply_camera() -> void:
	if not is_instance_valid(camera): return
	view_center=clamp_center(view_center)
	# 相机投影按屏幕像素取整，角色仍用原物理精度与原速度。
	var center:=clamp_center((view_center*camera.zoom).round()/camera.zoom)
	camera.global_position=center
	camera.force_update_scroll()
	var made:=map_rect();var shown:=get_viewport().get_visible_rect().size/camera.zoom
	backdrop.visible=GameState.location=="home" or made.size.x<shown.x or made.size.y<shown.y

func screen_error() -> Vector2:
	return (camera.get_screen_center_position()-follow_center())*camera.zoom
