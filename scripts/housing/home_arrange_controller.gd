class_name HomeArrangeController
extends Node
## 装修是局部、可取消的预览。确认时重新验证并只提交一次；原移动输入保持不变。
var game: Node
var active: bool=false
var selected_kind: String=""
var selected_id: String=""
var preview_cell:=Vector2i(-1,-1)
var preview_valid: bool=false
var dragging: bool=false
var panel: PanelContainer
var confirm_button: Button
var cancel_button: Button
var choose_button: Button
var title_label: Label
var status_label: Label
var preview: Node2D
var _origin_cell:=Vector2i(-1,-1)
var _grab_offset:=Vector2.ZERO
var _committing: bool=false
var _hidden: Array=[]
var _fingers: Dictionary={}
var _candidate: int=-1
var _blocked: bool=false
var _world_start:=Vector2.ZERO
var _screen_start:=Vector2.ZERO
var _mouse_down: bool=false

func setup(owner_game: Node) -> void:
	game=owner_game
	panel=PanelContainer.new();panel.name="HomeArrangeBar";panel.set_script(preload("res://scripts/housing/home_arrange_panel.gd"));panel.controller=self
	panel.set_meta("home_editor",true);panel.grow_vertical=Control.GROW_DIRECTION_BEGIN;panel.hide();game.hud.safe.add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);panel.add_child(column)
	title_label=FarmUIStyle.label("布置房间",22,FarmUIStyle.TITLE);column.add_child(title_label)
	var row:=HBoxContainer.new();column.add_child(row)
	status_label=FarmUIStyle.label("",16);status_label.clip_text=true;status_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(status_label)
	choose_button=FarmUIStyle.button("家具列表",back_to_list,120);row.add_child(choose_button)
	confirm_button=FarmUIStyle.button("确认摆放",confirm,140);row.add_child(confirm_button)
	cancel_button=FarmUIStyle.button("退出布置",cancel,140);row.add_child(cancel_button)
	preview=Node2D.new();preview.set_script(preload("res://scripts/housing/home_placement_preview.gd"));preview.controller=self;preview.z_index=200;preview.hide();game.home.add_child(preview)
	Events.location_changed.connect(func(_area: String): cancel())
	GameState.control_mode_changed.connect(cancel)
	Events.tool_changed.connect(cancel)
	GameClock.day_ending.connect(func(_why: String): cancel())
	Housing.changed.connect(func():
		if active and not _committing: cancel()
	)
	get_viewport().size_changed.connect(func():
		if active: _clear_gesture();layout_panel()
	)

func _begin() -> bool:
	if active: return true
	if GameState.modal or not Housing.can_arrange(): return false
	var existing_fingers: Dictionary=game.touch_input.fingers.duplicate()
	game.auto_move.cancel();game.player.velocity=Vector2.ZERO;game.player.touch_direction=Vector2.ZERO
	game.touch_input.reset();game.hud.joystick.reset();game.camera_rig.follow_now()
	active=true;_clear_gesture();_fingers=existing_fingers;_blocked=not _fingers.is_empty();game.touch_input.fingers.clear();selected_kind="";selected_id="";preview_cell=Vector2i(-1,-1);preview_valid=false
	for control in [game.hud.toolbar,game.hud.action_button,game.hud.cycle_button,game.hud.joystick,game.hud.guide_panel,game.hud.prompt_label]:
		_hidden.append({"control":control,"visible":control.visible});control.hide()
	panel.add_to_group("modal_panels");GameState.set_modal(true);game.hud.scrim.hide();panel.show();preview.show()
	layout_panel();_update_bar();return true

func start_blank() -> bool: return _begin()
func start_builtin(id: String) -> bool:
	if not Housing.state.builtins.has(id) or not _begin(): return false
	return select_builtin(id)
func select_builtin(id: String) -> bool:
	if not active: return false
	var item: Dictionary=Housing.builtin_geometry(id)
	if item.is_empty(): return false
	selected_kind="builtin";selected_id=id;_origin_cell=item.cell
	_grab_offset=item.footprint.get_center()-Vector2(item.cell)*32
	preview_cell=item.cell if not item.stored else Vector2i(-1,-1);preview_valid=false
	_update_bar();return true
func start_item(id: String) -> bool:
	var entry: Dictionary=Housing.placement(id)
	if entry.is_empty() or entry.area!="home" or not _begin(): return false
	selected_kind="item";selected_id=id;_origin_cell=Vector2i(entry.cell[0],entry.cell[1]);_grab_offset=Vector2(Housing.footprint(entry.kind,_origin_cell).size)*16
	preview_cell=_origin_cell;preview_valid=false;_update_bar();return true
func start_owned(kind: String) -> bool:
	if not Housing.data.furniture.has(kind) or Housing.data.furniture[kind].area!="home" or int(Housing.state.owned.get(kind,0))<=0 or not _begin(): return false
	selected_kind="owned";selected_id=kind;_origin_cell=Vector2i(-1,-1);_grab_offset=Vector2(Housing.data.furniture[kind].size[0],Housing.data.furniture[kind].size[1])*16
	preview_cell=Vector2i(-1,-1);preview_valid=false;_update_bar();return true

func current_geometry() -> Dictionary:
	return _geometry(preview_cell)
func _geometry(cell: Vector2i) -> Dictionary:
	if selected_kind=="" or cell.x<0: return {}
	if selected_kind=="builtin": return HomeLayout.builtin_geometry(selected_id,{"cell":[cell.x,cell.y]},int(Housing.state.level))
	var kind: String=selected_id
	if selected_kind=="item":
		var entry: Dictionary=Housing.placement(selected_id)
		if entry.is_empty(): return {}
		kind=str(entry.kind)
	var rect: Rect2i=Housing.footprint(kind,cell)
	return {"position":Vector2(rect.position)*32,"footprint":Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32),"kind":kind,"cell":cell}
func preview_texture(item: Dictionary) -> Texture2D:
	if item.has("art"):
		var replacement:=SchemeCAssets.home_texture(str(game.home.refreshed_art_id(str(item.art))))
		if replacement: return replacement
	elif item.has("kind"):
		var replacement:=SchemeCAssets.furniture_texture(str(item.kind))
		if replacement: return replacement
	var path: String="res://assets/housing/interior/"+str(game.home.refreshed_art_id(str(item.art)))+".png" if item.has("art") else "res://assets/housing/interior/placeable_"+str(item.kind)+".png"
	if not ResourceLoader.exists(path) and item.has("kind"): path="res://assets/housing/"+str(item.kind)+".png"
	return load(path) if ResourceLoader.exists(path) else null
func world_for_cell(cell: Vector2i) -> Vector2: return Vector2(cell)*32+_grab_offset
func pick_world(point: Vector2) -> void:
	if not active: return
	if selected_kind=="":
		_select_at(point);return
	pick_cell(Vector2i(((point-_grab_offset)/32).round()))
func pick_cell(cell: Vector2i) -> void:
	if not active or selected_kind=="": return
	preview_cell=cell;dragging=false;preview_valid=_legal(cell,true);_update_bar()
func _legal(cell: Vector2i, full: bool) -> bool:
	if cell.x<0 or selected_kind=="": return false
	if selected_kind=="builtin":
		var record: Dictionary=Housing.state.builtins.get(selected_id,{})
		if record.is_empty() or (cell==_origin_cell and not record.get("stored",false)): return false
		return Housing.can_move_builtin(selected_id,cell,full)
	if not full: return false
	if selected_kind=="owned": return Housing.can_place(selected_id,"home",cell)
	var entry: Dictionary=Housing.placement(selected_id)
	return not entry.is_empty() and cell!=_origin_cell and Housing.can_place(str(entry.kind),"home",cell,selected_id)
func _select_at(point: Vector2) -> bool:
	var candidates: Array=[]
	for item in Housing.builtin_layout():
		if not item.stored and item.footprint.has_point(point): candidates.append({"mode":"builtin","id":str(item.id),"order":float(item.layer)*10000+float(item.sort_y)})
	for entry in Housing.state.placed:
		if entry.area!="home": continue
		var rect: Rect2i=Housing.footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1]))
		if Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32).has_point(point): candidates.append({"mode":"item","id":str(entry.id),"order":float(rect.end.y*32) if Housing.data.furniture[entry.kind].solid else -10000.0})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.order>b.order)
	if candidates.is_empty(): return false
	if candidates[0].mode=="builtin": select_builtin(str(candidates[0].id))
	else: start_item(str(candidates[0].id))
	_grab_offset=point-Vector2(_origin_cell)*32
	return true
func _light_preview(point: Vector2) -> void:
	if selected_kind=="": return
	var cell:=Vector2i(((point-_grab_offset)/32).round())
	if cell==preview_cell and dragging: return
	preview_cell=cell;dragging=true;preview_valid=false;_update_bar()

func confirm() -> bool:
	if not active or _committing or not preview_valid or not _fingers.is_empty() or _mouse_down or not Housing.can_arrange(): return false
	if not _legal(preview_cell,true): preview_valid=false;_update_bar();return false
	_committing=true
	var accepted: bool=false
	if selected_kind=="builtin": accepted=Housing.move_builtin(selected_id,preview_cell,_origin_cell)
	elif selected_kind=="item": accepted=Housing.move(selected_id,preview_cell)
	elif selected_kind=="owned": accepted=Housing.place(selected_id,"home",preview_cell)
	_committing=false
	if accepted:
		cancel();Events.notice.emit("家具已摆好，功能与碰撞一起移动。")
	else:
		preview_valid=false;_update_bar();Events.notice.emit("这个位置现在无法放置，请换一个位置。")
	return accepted
func back_to_list() -> void:
	cancel();game.hud.housing_panel.open_panel("room")
func cancel() -> void:
	if not active: return
	active=false;preview_valid=false;dragging=false;selected_kind="";selected_id="";preview_cell=Vector2i(-1,-1);_clear_gesture()
	panel.hide();preview.hide()
	if panel.is_in_group("modal_panels"): panel.remove_from_group("modal_panels")
	for entry in _hidden:
		if is_instance_valid(entry.control): entry.control.visible=entry.visible
	_hidden.clear();game.touch_input.fingers.clear();game.touch_input.reset();GameState.set_modal(false);game.hud.refresh_controls();game.hud.refresh()
func layout_panel() -> void:
	if not is_instance_valid(panel): return
	var target: float=UIMetrics.minimum_target();var size: Vector2=game.hud.safe.size
	for spec in [[choose_button,120],[confirm_button,140],[cancel_button,140]]: spec[0].custom_minimum_size=Vector2(maxf(float(spec[1]),target),target)
	var extent:=Vector2(minf(1020,size.x-24),minf(124+maxf(0,target-48),size.y-24))
	game.hud.place(panel,Vector2(.5,1),Vector2(.5,1),Rect2(Vector2(-extent.x/2,-12-extent.y),extent))
func _update_bar() -> void:
	var name: String="点选一件家具"
	if selected_kind=="builtin": name=str(Housing.builtin_geometry(selected_id).get("name","家具"))
	elif selected_kind=="item": name=str(Housing.data.furniture[Housing.placement(selected_id).kind].name)
	elif selected_kind=="owned": name=str(Housing.data.furniture[selected_id].name)
	title_label.text="布置房间 · "+name
	status_label.text="点击家具开始，拖动可预览新位置。" if selected_kind=="" else ("松手检查位置，确认后才会移动。" if dragging else ("可以放在这里，点击确认摆放。" if preview_valid else "点击空地预览；红色位置不能放。"))
	status_label.tooltip_text=status_label.text
	status_label.add_theme_color_override("font_color",FarmUIStyle.SUCCESS if preview_valid else FarmUIStyle.MUTED)
	confirm_button.disabled=not preview_valid
	preview.queue_redraw()
func _clear_gesture() -> void:
	_fingers.clear();_candidate=-1;_blocked=false;_mouse_down=false;dragging=false
func _reset_buttons() -> void:
	for button in [confirm_button,cancel_button,choose_button]:
		if is_instance_valid(button) and button.has_method("reset_touch"): button.reset_touch()
func _input(event: InputEvent) -> void:
	if not active: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device<0: return
	if event is InputEventScreenTouch:
		if event.pressed:
			var mixed: bool=_mouse_down;_mouse_down=false
			if _fingers.has(event.index):
				_blocked=true;_candidate=-1;preview_valid=false;_reset_buttons();_update_bar();get_viewport().set_input_as_handled();return
			_fingers[event.index]=event.position
			if mixed or _fingers.size()>1:
				_blocked=true;_candidate=-1;preview_valid=false;_reset_buttons();_update_bar();get_viewport().set_input_as_handled();return
			_blocked=event.canceled
			if game.touch_input.ui_at(event.position): return
			_candidate=event.index;_screen_start=event.position;_world_start=game.touch_input.world_point(event.position)
			if selected_kind=="": _select_at(_world_start)
			elif not current_geometry().is_empty() and current_geometry().footprint.has_point(_world_start): _grab_offset=_world_start-Vector2(preview_cell)*32
			get_viewport().set_input_as_handled()
		else:
			_fingers.erase(event.index)
			if _blocked:
				if _fingers.is_empty(): _blocked=false;_candidate=-1
				get_viewport().set_input_as_handled();return
			if event.index!=_candidate: return
			_candidate=-1
			if not event.canceled and selected_kind!="":
				var point: Vector2=game.touch_input.world_point(event.position) if dragging else _world_start
				pick_world(point)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==_candidate:
		if not _blocked and event.position.distance_to(_screen_start)>UIMetrics.drag_threshold(): _light_preview(game.touch_input.world_point(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not _fingers.is_empty(): _blocked=true;_mouse_down=false;_reset_buttons();get_viewport().set_input_as_handled();return
		if event.pressed:
			if game.touch_input.ui_at(event.position): return
			_mouse_down=true;_world_start=game.touch_input.world_point(event.position)
			if selected_kind=="": _select_at(_world_start)
			elif not current_geometry().is_empty() and current_geometry().footprint.has_point(_world_start): _grab_offset=_world_start-Vector2(preview_cell)*32
			get_viewport().set_input_as_handled()
		elif _mouse_down:
			_mouse_down=false;pick_world(game.touch_input.world_point(event.position) if dragging else _world_start);get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_down:
		_light_preview(game.touch_input.world_point(event.position));get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_cancel"): cancel();get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and active: cancel()
