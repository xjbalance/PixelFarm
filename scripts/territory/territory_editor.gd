class_name TerritoryEditor
extends Node
## 建造只预览，明确确认才提交；触点不会转交普通移动或交互。
var game: Node
var active: bool=false
var panel: PanelContainer
var palette: PanelContainer
var preview: Node2D
var confirm_button: Button
var cancel_button: Button
var discard_button: Button
var status_label: Label
var selection_label: Label
var area_label: Label
var tool_list: VBoxContainer
var tool_scroll: ScrollContainer
var category_buttons: Dictionary={}
var tool_buttons: Dictionary={}
var movement_buttons: Array[Button]=[]
var edit_row: HBoxContainer
var direction_row: HBoxContainer
var action_buttons: Array[Button]=[]
var selected_tool: String="grass"
var selected_id: String=""
var selected_entity: Dictionary={}
var category: String="terrain"
var inventory_page: int=0
var subgroup: String="all"
var group_button: Button
var preview_plan: Dictionary={}
var permission_overlay: Array[Dictionary]=[]
var commit_count: int=0
var _opened_area: String=""
var _committing: bool=false
var _hidden: Array[Dictionary]=[]
var _camera_state: Dictionary={}
var _fingers: Dictionary={}
var _candidate: int=-1
var _blocked: bool=false
var _mouse_held: bool=false
var _mouse_world: bool=false
var _touch_world: bool=false
var _dragging: bool=false
var _screen_start:=Vector2.ZERO
var _world_start:=Vector2.ZERO
var _brush_cells: Array[Vector2i]=[]
var _last_brush:=Vector2i(-1,-1)
var _brush_overflow: bool=false
var _status_override: String=""
var _navigation_waiting: bool=false
const BRUSH_LIMIT: int=128

func setup(owner_game: Node) -> void:
	game=owner_game
	palette=_make_panel("TerritoryPalette")
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);palette.add_child(column)
	FarmUIStyle.heading(column,"建造 / 改造领地","house_1")
	area_label=FarmUIStyle.label("",16,FarmUIStyle.MUTED);area_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(area_label)
	var legend:=FarmUIStyle.label("全场DIY · 原物可移动或收纳\n空地选锄头可开垦；水池可改形。",14,FarmUIStyle.MUTED)
	legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(legend)
	var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",6);column.add_child(tabs)
	for spec in [["terrain","地表"],["vegetation","植被"],["objects","摆件"],["farm","原物"]]:
		var tab:=FarmUIStyle.button(spec[1],choose_category.bind(str(spec[0])),48)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.toggle_mode=true;tabs.add_child(tab);category_buttons[spec[0]]=tab
	group_button=FarmUIStyle.button("分组 · 全部",cycle_group,120)
	group_button.add_theme_font_size_override("font_size",16);group_button.tooltip_text="点击切换同类素材分组。";column.add_child(group_button)
	tool_scroll=ScrollContainer.new();tool_scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	tool_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;tool_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(tool_scroll)
	tool_list=VBoxContainer.new();tool_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tool_list.add_theme_constant_override("separation",6);tool_scroll.add_child(tool_list)
	panel=_make_panel("TerritoryConfirmation")
	var footer:=VBoxContainer.new();footer.add_theme_constant_override("separation",8);panel.add_child(footer)
	selection_label=FarmUIStyle.label("",20,FarmUIStyle.TITLE);footer.add_child(selection_label)
	status_label=FarmUIStyle.label("",16,FarmUIStyle.MUTED);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible=2;footer.add_child(status_label)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);footer.add_child(actions)
	confirm_button=FarmUIStyle.button("确认改造",confirm,140);actions.add_child(confirm_button)
	discard_button=FarmUIStyle.button("取消预览",discard_preview,120);actions.add_child(discard_button)
	cancel_button=FarmUIStyle.button("退出建造",cancel,140);actions.add_child(cancel_button)
	for button in [confirm_button,discard_button,cancel_button]: button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var edits:=HBoxContainer.new();edits.add_theme_constant_override("separation",8);footer.add_child(edits);edit_row=edits
	direction_row=HBoxContainer.new();direction_row.add_theme_constant_override("separation",8);footer.add_child(direction_row);direction_row.hide()
	for spec in [["move","移动"],["store","收纳"],["remove","拆除"]]:
		var button:=FarmUIStyle.button(spec[1],choose_tool.bind(str(spec[0])),96)
		button.toggle_mode=true;button.set_meta("territory_tool",str(spec[0]))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;edits.add_child(button);action_buttons.append(button)
	for spec in [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]:
		var button:=FarmUIStyle.button(spec[0],pan_view.bind(spec[1]),48)
		button.tooltip_text="观察视野，不移动人物。";edits.add_child(button);movement_buttons.append(button)
	preview=Node2D.new();preview.set_script(preload("res://scripts/territory/territory_preview.gd"));preview.controller=self
	preview.name="TerritoryPreview";preview.z_index=200;preview.hide();game.world.add_child(preview)
	Events.location_changed.connect(func(_area: String): cancel())
	GameState.control_mode_changed.connect(cancel)
	GameClock.day_ending.connect(func(_why: String): cancel())
	Territory.changed.connect(_state_changed)
	FarmLayout.changed.connect(_state_changed)
	get_viewport().size_changed.connect(func():
		if active: _reset_gesture();layout_panel();refresh_overlay()
	)
	choose_category("terrain")

func _make_panel(node_name: String) -> PanelContainer:
	var result:=PanelContainer.new();result.name=node_name;result.set_script(preload("res://scripts/territory/territory_editor_panel.gd"))
	result.controller=self;result.set_meta("territory_editor",true);result.theme=FarmUIStyle.make_theme();result.hide();game.hud.safe.add_child(result)
	result.minimum_size_changed.connect(func():
		if active: call_deferred("layout_panel")
	)
	return result

func open() -> bool:
	if active: return false
	if GameState.modal or GameState.restoring or GameClock.settling or GameClock.minutes>=1440 or game.backgrounded or game.closing or game.player.suspended or game.player.action_time>0: return false
	if GameState.location not in TerritoryCatalog.EDITABLE_AREAS or not Territory.unlocked(GameState.location):
		Events.notice.emit("这里没有领地改造权限。请前往自己的农场或已解锁领地。")
		return false
	if game.farm.committing or Housing.busy or game.resource_world.committing() or Fishing.active(): return false
	_opened_area=GameState.location
	_camera_state={"mode":game.camera_rig.mode,"center":game.camera_rig.view_center}
	game.auto_move.cancel();game.player.velocity=Vector2.ZERO;game.player.auto_direction=Vector2.ZERO;game.player.touch_direction=Vector2.ZERO
	game.hud.joystick.reset();game.touch_input.reset();_reset_gesture()
	_fingers=game.touch_input.fingers.duplicate();_blocked=not _fingers.is_empty()
	active=true;selected_id="";selected_entity={};_clear_preview()
	for control in [game.hud.top_cluster,game.hud.toolbar,game.hud.action_button,game.hud.cycle_button,game.hud.joystick,game.hud.guide_panel,game.hud.prompt_label,game.hud.atlas_button,game.hud.home_return_button]:
		if is_instance_valid(control): _hidden.append({"control":control,"visible":control.visible});control.hide()
	for editor_panel in [palette,panel]: editor_panel.add_to_group("modal_panels")
	GameState.set_modal(true);game.hud.scrim.hide();palette.show();panel.show()
	var map: Node=WorldTravel.maps(game).get(_opened_area)
	if is_instance_valid(map) and preview.get_parent()!=map: preview.reparent(map,false)
	preview.show();area_label.text=str(Territory.region_info(_opened_area).get("name","我的领地"))
	layout_panel();refresh_overlay();_update_status();call_deferred("layout_panel")
	return true

func cancel() -> void:
	if not active: return
	active=false;_clear_preview();selected_id="";selected_entity={};_reset_buttons();_reset_gesture()
	for editor_panel in [palette,panel]:
		editor_panel.hide()
		if editor_panel.is_in_group("modal_panels"): editor_panel.remove_from_group("modal_panels")
	preview.hide();permission_overlay.clear()
	for entry in _hidden:
		if is_instance_valid(entry.control): entry.control.visible=entry.visible
	_hidden.clear();game.touch_input.reset();game.hud.joystick.reset();GameState.set_modal(false)
	if GameState.location==_opened_area and not _camera_state.is_empty():
		game.camera_rig.mode=int(_camera_state.mode);game.camera_rig.view_center=_camera_state.center;game.camera_rig.dragging=false;game.camera_rig.apply_camera()
	_camera_state.clear();game.hud.refresh_controls();game.hud.refresh()

func choose_category(value: String) -> void:
	if value not in ["terrain","vegetation","objects","farm"]: return
	if value=="farm" and GameState.location!="farm": _status_override="原有实体改造请回主农场。";_update_status();return
	category=value;subgroup="all";inventory_page=0;_populate_tools()

func group_keys() -> Array[String]:
	var result: Array[String]=["all"]
	if category=="terrain": return result
	if category=="farm": return ["all","fixture","resource","plot","stored"]
	for entry in TerritoryCatalog.OBJECT_KINDS.values():
		if entry.category==category and str(entry.get("group","")) not in result: result.append(str(entry.group))
	return result

func cycle_group() -> void:
	var groups:=group_keys();subgroup=groups[posmod(groups.find(subgroup)+1,groups.size())];inventory_page=0;_populate_tools()

func _inventory_turn(direction: int) -> void:
	inventory_page=maxi(0,inventory_page+direction);_populate_tools()

func _populate_tools() -> void:
	for child in tool_list.get_children(): tool_list.remove_child(child);child.queue_free()
	tool_buttons.clear()
	if category=="farm":
		var matching: Array[Dictionary]=[]
		for entry in game.farm_layout_world.entries():
			if subgroup=="stored" and not entry.stored: continue
			if subgroup not in ["all","stored"] and entry.kind!=subgroup: continue
			matching.append(entry)
		var pages: int=maxi(1,ceili(float(matching.size())/32.0));inventory_page=clampi(inventory_page,0,pages-1)
		for entry in matching.slice(inventory_page*32,mini(matching.size(),(inventory_page+1)*32)):
			var key: String="layout:"+str(entry.kind)+":"+str(entry.id)
			var button:=FarmUIStyle.button(("收纳 · " if entry.stored else "已放 · ")+str(entry.name),select_entity.bind(entry),140)
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;button.tooltip_text=str(entry.name)
			button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tool_list.add_child(button);tool_buttons[key]=button
		if pages>1:
			var line:=HBoxContainer.new();tool_list.add_child(line)
			var previous:=FarmUIStyle.button("上一页",_inventory_turn.bind(-1),80);previous.disabled=inventory_page==0;line.add_child(previous)
			line.add_child(FarmUIStyle.label("%d/%d" % [inventory_page+1,pages],14))
			var following:=FarmUIStyle.button("下一页",_inventory_turn.bind(1),80);following.disabled=inventory_page>=pages-1;line.add_child(following)
		for key in category_buttons: category_buttons[key].set_pressed_no_signal(key==category)
		group_button.text="分组 · "+str({"all":"所有原物","fixture":"建筑与设施","resource":"原生树石","plot":"生产农田","stored":"已收纳"}.get(subgroup,"全部"));group_button.disabled=false
		tool_scroll.scroll_vertical=0
		if active: call_deferred("layout_panel")
		_update_status();return
	for key in (TerritoryCatalog.TERRAIN_KINDS if category=="terrain" else TerritoryCatalog.OBJECT_KINDS):
		var definition: Dictionary=TerritoryCatalog.TERRAIN_KINDS[key] if category=="terrain" else TerritoryCatalog.OBJECT_KINDS[key]
		if category!="terrain" and (definition.category!=category or (subgroup!="all" and str(definition.get("group",""))!=subgroup)): continue
		var button:=FarmUIStyle.button(str(definition.name),choose_tool.bind(str(key)),120)
		button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tool_list.add_child(button);tool_buttons[key]=button
	for key in category_buttons: category_buttons[key].set_pressed_no_signal(key==category)
	group_button.text="分组 · "+str(TerritoryCatalog.OBJECT_GROUPS.get(subgroup,"全部"));group_button.disabled=category=="terrain"
	if not tool_buttons.has(selected_tool) and not tool_buttons.is_empty(): choose_tool(str(tool_buttons.keys()[0]))
	else: _update_status()
	tool_scroll.scroll_vertical=0
	if active: call_deferred("layout_panel")

func choose_tool(kind: String) -> bool:
	if kind not in ["move","store","restore","remove"] and not TerritoryCatalog.TERRAIN_KINDS.has(kind) and not TerritoryCatalog.OBJECT_KINDS.has(kind): return false
	if kind in ["store","remove"] and not selected_entity.is_empty() and selected_entity.get("source")=="layout":
		selected_tool=kind;_clear_preview();preview_plan=_layout_preview(FarmLayout.cell(str(selected_entity.kind),str(selected_entity.id)),true);_update_status();return true
	selected_tool=kind;selected_id="";selected_entity={};_clear_preview();_reset_buttons();_update_status()
	if active: refresh_overlay()
	return true

func select_entity(entry: Dictionary) -> void:
	selected_entity=entry.duplicate(true);selected_entity.source=str(entry.get("source","layout"))
	selected_id=str(entry.id);selected_tool="restore" if bool(entry.get("stored",false)) else "move"
	_clear_preview();_status_override="已选中"+str(entry.name)+"。点击新位置预览；可移动或收纳，原进度保留。"
	_update_status()

func _pick_any(cell: Vector2i) -> Dictionary:
	var placed:=_object_at(cell)
	if not placed.is_empty(): return {"source":"territory","id":str(placed.id),"kind":str(placed.kind),"name":str(TerritoryCatalog.OBJECT_KINDS[placed.kind].name)}
	for entry in Housing.state.placed:
		if entry.area=="farm" and Housing.footprint(entry.kind,Vector2i(entry.cell[0],entry.cell[1])).has_point(cell): return {"source":"housing","id":str(entry.id),"kind":str(entry.kind),"name":str(Housing.data.furniture[entry.kind].name)}
	if GameState.location=="farm":
		var entry: Dictionary=game.farm_layout_world.pick(cell)
		if not entry.is_empty(): entry.source="layout"
		return entry
	return {}

func _layout_preview(cell: Vector2i, store: bool=false) -> Dictionary:
	var kind: String=str(selected_entity.get("kind",""));var id: String=str(selected_entity.get("id",""))
	var plan: Dictionary=FarmLayout.plan_store(kind,id) if store else (FarmLayout.plan_restore(kind,id,cell) if selected_tool=="restore" else FarmLayout.plan_move(kind,id,cell))
	plan.source="layout";plan.layout=true;plan.display_name=str(selected_entity.get("name",id));return plan

func preview_at(cell: Vector2i) -> bool:
	if not active or GameState.location!=_opened_area: return false
	_status_override=""
	if TerritoryCatalog.TERRAIN_KINDS.has(selected_tool):
		_add_brush_cell(cell);preview_plan=Territory.plan_terrain(_opened_area,_brush_cells,selected_tool)
		if _brush_overflow: preview_plan.valid=false;preview_plan.reason="一次最多预览128格。请取消预览后缩小涂刷范围。"
	elif selected_tool in ["move","store","restore","remove"]:
		var item:=_pick_any(cell)
		if selected_tool=="restore" and selected_entity.get("source")=="owned": preview_plan={"source":"owned","id":selected_entity.id,"cell":cell,"valid":Housing.can_place(str(selected_entity.id),"farm",cell),"reason":"请选能放下家具且不堵路的空地。","op":"place"}
		elif selected_tool=="restore" and not selected_entity.is_empty(): preview_plan=_layout_preview(cell)
		elif selected_tool in ["remove","store"]:
			if not item.is_empty(): selected_entity=item;selected_id=str(item.id)
			if selected_entity.get("source")=="layout": preview_plan=_layout_preview(cell,true)
			elif selected_entity.get("source")=="territory": preview_plan=Territory.plan_remove(str(selected_entity.id))
			elif selected_entity.get("source")=="housing": preview_plan={"source":"housing","id":selected_entity.id,"op":"store","cell":cell,"valid":true,"reason":"回收到原家具库存，不会复制物品。"}
			else: preview_plan={}
		elif selected_entity.is_empty() or (not item.is_empty() and str(item.id)!=str(selected_entity.id)):
			selected_entity=item;selected_id=str(item.get("id",""));preview_plan={};_status_override="已选中"+str(item.get("name",""))+"，点击新位置预览。" if not item.is_empty() else "点选现有建筑、设施、田地或摆件；也可从「原物」列表选择。"
		elif selected_entity.get("source")=="layout": preview_plan=_layout_preview(cell)
		elif selected_entity.get("source")=="housing": preview_plan={"source":"housing","id":selected_entity.id,"op":"move","cell":cell,"valid":Housing.can_place(str(selected_entity.kind),"farm",cell,str(selected_entity.id)),"reason":"请选择不与其他实体重叠且保留通路的位置。"}
		else: preview_plan=Territory.plan_move(selected_id,cell)
	else: preview_plan=Territory.plan_place(_opened_area,selected_tool,cell)
	_update_status();_retry_after_navigation();return bool(preview_plan.get("valid",false))

func _retry_after_navigation() -> void:
	# 刚放置的碰撞需同步两个物理帧；只为这次预览等待，不逐帧刷新整套界面。
	if _navigation_waiting or not active or not str(preview_plan.get("reason","")).contains("通路正在更新"): return
	_navigation_waiting=true
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_navigation_waiting=false
	if not active or preview_plan.is_empty() or not str(preview_plan.get("reason","")).contains("通路正在更新"): return
	if preview_plan.get("source")=="layout": preview_plan=_layout_preview(FarmLayoutCatalog.parse_cell(preview_plan.cell),bool(preview_plan.get("stored",false)));_update_status();return
	var operation: String=str(preview_plan.get("op",""))
	var cells: Array=preview_plan.get("cells",[])
	if cells.is_empty(): return
	if operation=="terrain": preview_plan=Territory.plan_terrain(_opened_area,cells,str(preview_plan.kind))
	elif operation=="place": preview_plan=Territory.plan_place(_opened_area,str(preview_plan.kind),TerritoryCatalog.to_cell(cells[0]))
	elif operation=="move": preview_plan=Territory.plan_move(str(preview_plan.id),TerritoryCatalog.to_cell(cells[0]))
	elif operation=="remove": preview_plan=Territory.plan_remove(str(preview_plan.id))
	_update_status()

func _object_at(cell: Vector2i) -> Dictionary:
	for item in Territory.state.objects:
		if item.area==_opened_area and TerritoryCatalog.footprint(str(item.kind),Vector2i(item.cell[0],item.cell[1])).has_point(cell): return item
	return {}

func _add_brush_cell(cell: Vector2i) -> void:
	if cell in _brush_cells: return
	if _brush_cells.size()>=BRUSH_LIMIT: _brush_overflow=true;return
	_brush_cells.append(cell)

func _brush_line(from: Vector2i, to: Vector2i) -> void:
	var point:=from;var dx: int=absi(to.x-from.x);var dy: int=-absi(to.y-from.y)
	var sx: int=1 if from.x<to.x else -1;var sy: int=1 if from.y<to.y else -1;var error: int=dx+dy
	for _i in range(BRUSH_LIMIT+1):
		_add_brush_cell(point)
		if point==to: break
		var twice: int=error*2
		if twice>=dy: error+=dy;point.x+=sx
		if twice<=dx: error+=dx;point.y+=sy
	preview_at(to)

func _clear_preview() -> void:
	preview_plan={};_brush_cells.clear();_last_brush=Vector2i(-1,-1);_brush_overflow=false;_status_override=""

func discard_preview() -> void:
	_clear_preview();selected_id="";selected_entity={};_reset_buttons();_update_status()

func confirm() -> bool:
	if not active or _committing or _blocked or not _fingers.is_empty() or _mouse_held or _brush_overflow or not preview_plan.get("valid",false): return false
	if game.backgrounded or game.closing or GameState.restoring or GameClock.settling or GameState.location!=_opened_area: return false
	_committing=true
	var accepted: bool=false
	if preview_plan.get("source")=="layout": accepted=FarmLayout.apply_plan(preview_plan)
	elif preview_plan.get("source")=="owned": accepted=Housing.place(str(preview_plan.id),"farm",FarmLayoutCatalog.parse_cell(preview_plan.cell))
	elif preview_plan.get("source")=="housing":
		accepted=Housing.recycle(str(preview_plan.id)) if preview_plan.op=="store" else Housing.move(str(preview_plan.id),FarmLayoutCatalog.parse_cell(preview_plan.cell))
	else: accepted=Territory.apply_plan(preview_plan)
	_committing=false
	if accepted:
		commit_count+=1;_clear_preview();selected_id="";selected_entity={};_status_override="改造已确认。原有进度保留，可以继续规划。";refresh_overlay()
		if category=="farm": call_deferred("_populate_tools")
	else:
		_clear_preview();_status_override=FarmLayout.last_error if FarmLayout.last_error!="" else Territory.last_error if Territory.last_error!="" else "领地状态或位置已变化，没有提交本次预览。请重新选择。"
	_update_status();return accepted

func pan_view(direction: Vector2) -> void:
	if not active or _blocked or game.backgrounded: return
	game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK
	game.camera_rig.view_center=game.camera_rig.clamp_center(game.camera_rig.view_center+direction*128)
	game.camera_rig.apply_camera()
	# 固定格预览跟随世界，不随镜头位移变换坐标。
	preview.queue_redraw()

func layout_panel() -> void:
	if not active or not is_instance_valid(panel): return
	var available: Vector2=game.hud.safe.size
	var target: float=UIMetrics.minimum_target()
	var width: float=maxf(maxf(252,target*4+50),palette.get_combined_minimum_size().x)
	width=minf(width,available.x-460)
	var extent:=Vector2(width,maxf(240,available.y-24))
	game.hud.place(palette,Vector2.ZERO,Vector2.ZERO,Rect2(Vector2(12,12),extent))
	for button in category_buttons.values(): button.custom_minimum_size=Vector2(target,target)
	for button in tool_buttons.values(): button.custom_minimum_size=Vector2(target,target)
	for button in movement_buttons: button.custom_minimum_size=Vector2(target,target)
	for button in action_buttons: button.custom_minimum_size=Vector2(target,target)
	group_button.custom_minimum_size=Vector2(target,target)
	for spec in [[confirm_button,140],[discard_button,120],[cancel_button,140]]:
		spec[0].custom_minimum_size=Vector2(maxf(float(spec[1]),target),target)
	var footer_width: float=maxf(400,available.x-width-36)
	var split_directions: bool=footer_width<maxf(target,96)*3+target*4+80
	var parent: HBoxContainer=direction_row if split_directions else edit_row
	for button in movement_buttons:
		if button.get_parent()!=parent: button.reparent(parent,false)
	direction_row.visible=split_directions
	var footer_height: float=maxf(212,target*(3 if split_directions else 2)+116)
	game.hud.place(panel,Vector2(1,1),Vector2(1,1),Rect2(Vector2(-12-footer_width,-12-footer_height),Vector2(footer_width,footer_height)))

func refresh_overlay() -> void:
	permission_overlay.clear()
	if not active: return
	var region: Rect2i=WorldTravel.region(_opened_area)
	var protected: Dictionary={}
	var operation: String=selected_tool if selected_tool not in ["move","store","restore","remove"] else "grass"
	if is_instance_valid(game.territory_world) and game.territory_world.has_method("protected_cells"): protected=game.territory_world.protected_cells(_opened_area,operation)
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell:=Vector2i(x,y);var permission: Dictionary=Territory.permission(_opened_area,cell,operation)
			var denied: bool=not permission.allowed or protected.has(cell) or protected.has("%d,%d" % [x,y])
			var color:=Color(0.73,0.34,0.25,0.13) if denied else Color(0.41,0.65,0.41,0.045)
			if not denied and str(permission.get("ownership","")) in ["limited","semi","semi_open"]: color=Color(0.88,0.65,0.29,0.095)
			permission_overlay.append({"rect":Rect2(Vector2(cell)*32,Vector2(32,32)),"color":color})
	preview.queue_redraw()

func preview_rects() -> Array[Rect2]:
	var result: Array[Rect2]=[]
	if preview_plan.is_empty(): return result
	if preview_plan.get("source")=="layout":
		result.append(game.farm_layout_world.preview_rect(preview_plan));return result
	if preview_plan.get("source")=="owned":
		var rect:=Housing.footprint(str(preview_plan.id),FarmLayoutCatalog.parse_cell(preview_plan.cell));result.append(Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32));return result
	if preview_plan.get("source")=="housing":
		var entry:=Housing.placement(str(preview_plan.id))
		if not entry.is_empty():
			var rect:=Housing.footprint(entry.kind,FarmLayoutCatalog.parse_cell(preview_plan.cell));result.append(Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32))
		return result
	var operation: String=str(preview_plan.get("op",""))
	var kind: String=str(preview_plan.get("kind",""))
	if operation=="terrain":
		for cell in preview_plan.get("cells",[]): result.append(Rect2(Vector2(cell)*32,Vector2(32,32)))
	elif TerritoryCatalog.OBJECT_KINDS.has(kind):
		var cells: Array=preview_plan.get("cells",[])
		if not cells.is_empty():
			var cell:=Vector2i(cells[0]);var rect: Rect2i=TerritoryCatalog.footprint(kind,cell)
			result.append(Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32))
	return result

func preview_texture() -> Texture2D:
	if preview_plan.get("source") in ["layout","housing","owned"]: return null
	var kind: String=str(preview_plan.get("kind",""))
	if not TerritoryCatalog.OBJECT_KINDS.has(kind): return null
	if is_instance_valid(game.territory_world) and game.territory_world.has_method("object_texture"): return game.territory_world.object_texture(kind)
	var path: String=str(TerritoryCatalog.OBJECT_KINDS[kind].get("art",""))
	return load(path) if path!="" and ResourceLoader.exists(path) else null

func preview_art() -> Array[Dictionary]:
	return game.farm_layout_world.preview_art(preview_plan) if preview_plan.get("source")=="layout" else []

func _state_changed() -> void:
	if not active: return
	if not _committing: _clear_preview();selected_id="";selected_entity={};_status_override="领地状态已更新，请重新预览。"
	refresh_overlay();_update_status()

func _update_status() -> void:
	if not is_instance_valid(selection_label): return
	var title: String="移动原物或摆件" if selected_tool=="move" else "收纳 · 保留原进度" if selected_tool in ["store","remove"] else "放回农场" if selected_tool=="restore" else str(TerritoryCatalog.TERRAIN_KINDS.get(selected_tool,TerritoryCatalog.OBJECT_KINDS.get(selected_tool,{})).get("name","领地改造"))
	if not selected_entity.is_empty(): title+=" · "+str(selected_entity.get("name",""))
	selection_label.text=title+(" · %d格预览" % _brush_cells.size() if not _brush_cells.is_empty() else "")
	var valid: bool=bool(preview_plan.get("valid",false))
	status_label.text=_status_override if _status_override!="" else (str(preview_plan.get("reason","")) if not preview_plan.is_empty() and not valid else ("绿色预览可确认；确认前不会改变地表或设施。" if valid else "点击空地预览；地表可连续拖动涂刷。施工只调整景观，不产出资源。"))
	if _status_override=="" and (preview_plan.is_empty() or valid) and str(TerritoryCatalog.OBJECT_KINDS.get(selected_tool,{}).get("group",""))=="buildings": status_label.text="这是建筑景观装饰，不提供生产、住宿或场景入口。确认前可取消。"
	status_label.tooltip_text=status_label.text
	status_label.add_theme_color_override("font_color",FarmUIStyle.SUCCESS if valid else FarmUIStyle.MUTED)
	confirm_button.text="确认收纳" if selected_tool in ["remove","store"] else "确认移动" if selected_tool=="move" else "确认放回" if selected_tool=="restore" else "确认改造"
	confirm_button.disabled=not valid or _blocked or not _fingers.is_empty() or _mouse_held
	discard_button.disabled=preview_plan.is_empty() and selected_id==""
	for key in tool_buttons: tool_buttons[key].set_pressed_no_signal(key==selected_tool)
	for button in action_buttons: button.set_pressed_no_signal(str(button.get_meta("territory_tool",""))==selected_tool)
	if is_instance_valid(preview): preview.queue_redraw()

func _ui_at(point: Vector2) -> bool:
	return (palette.is_visible_in_tree() and palette.get_global_rect().has_point(point)) or (panel.is_visible_in_tree() and panel.get_global_rect().has_point(point))

func _cell_at(screen: Vector2) -> Vector2i:
	return Vector2i((game.touch_input.world_point(screen)/32).floor())

func _begin_world(screen: Vector2) -> void:
	_screen_start=screen;_world_start=game.touch_input.world_point(screen);_dragging=false
	_last_brush=Vector2i((_world_start/32).floor())
	preview_at(_last_brush)

func _drag_world(screen: Vector2) -> void:
	if _ui_at(screen): return
	if screen.distance_to(_screen_start)<=UIMetrics.drag_threshold() and not _dragging: return
	_dragging=true
	var cell:=_cell_at(screen)
	if TerritoryCatalog.TERRAIN_KINDS.has(selected_tool): _brush_line(_last_brush,cell);_last_brush=cell
	else: preview_at(cell)

func _reset_gesture() -> void:
	_fingers.clear();_candidate=-1;_blocked=false;_mouse_held=false;_mouse_world=false;_touch_world=false;_dragging=false

func _reset_buttons() -> void:
	for host in [palette,panel]:
		if not is_instance_valid(host): continue
		for node in host.find_children("*","Button",true,false):
			if node.has_method("reset_touch"): node.reset_touch()
		for node in host.find_children("*","ScrollContainer",true,false):
			if node.has_method("reset_touch"): node.reset_touch()

func _cancel_mixed_gesture() -> void:
	_blocked=true;_candidate=-1;_mouse_world=false;_touch_world=false;_clear_preview();selected_id="";_reset_buttons()
	_status_override="多指或混合输入已取消本次预览。请用一根手指重新选择。";_update_status()

func _consume() -> void: get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not active: return
	if event.is_action_pressed("ui_cancel"): cancel();_consume();return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device<0: _consume();return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _fingers.has(event.index) or not _fingers.is_empty() or _mouse_held or event.canceled:
				_fingers[event.index]=event.position;_cancel_mixed_gesture();_consume();return
			_fingers[event.index]=event.position
			if _ui_at(event.position): return
			_candidate=event.index;_touch_world=true;_begin_world(event.position);_consume()
		else:
			_fingers.erase(event.index)
			if _blocked:
				game.touch_input.fingers.erase(event.index)
				if _fingers.is_empty() and not _mouse_held: _blocked=false
				_update_status();_consume();return
			if event.index!=_candidate: return
			_candidate=-1;_touch_world=false
			if event.canceled: discard_preview()
			else: _update_status()
			_consume()
	elif event is InputEventScreenDrag:
		if _blocked: _consume();return
		if event.index==_candidate and _touch_world: _drag_world(event.position);_consume()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_held=true
			if not _fingers.is_empty(): _cancel_mixed_gesture();_consume();return
			_mouse_world=not _ui_at(event.position)
			if _mouse_world: _begin_world(event.position);_consume()
		else:
			_mouse_held=false
			if _blocked:
				if _fingers.is_empty(): _blocked=false
				_update_status();_consume();return
			if _mouse_world: _mouse_world=false;_update_status();_consume()
	elif event is InputEventMouseMotion and _mouse_held and _mouse_world:
		_drag_world(event.position);_consume()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and active: cancel()
