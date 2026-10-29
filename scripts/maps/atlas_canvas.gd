class_name FarmAtlasCanvas
extends Control
## Independent viewing surface: every gesture is consumed here, never sent to world input.
signal place_selected(info: Dictionary)
signal view_changed
var game: Node
var layer_id: String="world"
var region_id: String="farm"
var zoom: float=1.0
var pan:=Vector2.ZERO
var places: Array[Dictionary]=[]
var selected_id: String=""
var gesture_dragged: bool=false
var gesture_multi: bool=false
var fingers: Dictionary={}
var _primary: int=-1
var _start:=Vector2.ZERO
var _last:=Vector2.ZERO
var _mouse_down: bool=false
var _textures: Dictionary={}
var _font: Font=preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc")
var _picture: Texture2D
var _refresh_elapsed: float=0
var _label_style: StyleBox
var _label_rects: Array[Rect2]=[]
var _label_hits: Dictionary={}
var resources: Array[Dictionary]=[]
const MIN_ZOOM: float=1.0
const MAX_ZOOM: float=3.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_label_style=FarmUIStyle.surface("secondary")
	custom_minimum_size=Vector2(100,100)
	resized.connect(func(): _clamp_pan();queue_redraw())
	Events.location_changed.connect(func(_id: String):
		reset_gesture()
		if layer_id=="region": show_region()
		else: refresh_state()
	)
func setup(owner_game: Node) -> void:
	game=owner_game;show_world()
func reset_gesture() -> void:
	fingers.clear();_primary=-1;gesture_dragged=false;gesture_multi=false;_mouse_down=false
func show_world() -> void:
	layer_id="world";region_id="";zoom=1;pan=Vector2.ZERO;selected_id="";reset_gesture();refresh_state()
func show_region(id: String="") -> void:
	var target: String=FarmAtlasData.current_region() if id=="" else id
	if not FarmAtlasData.known(target): return
	layer_id="region";region_id=target;zoom=1;pan=Vector2.ZERO;selected_id="";reset_gesture();refresh_state()
func refresh_state() -> void:
	places=FarmAtlasData.world_places() if layer_id=="world" else FarmAtlasData.region_places(region_id)
	var resource_state: Dictionary=game.resource_world.snapshot() if is_instance_valid(game) and "resource_world" in game and is_instance_valid(game.resource_world) else {}
	resources.clear()
	if layer_id=="region": resources=FarmAtlasData.resource_marks(region_id,resource_state)
	_picture=_texture(("world" if layer_id=="world" else FarmAtlasData.picture(region_id))+".png")
	queue_redraw();view_changed.emit()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_elapsed+=delta
	if _refresh_elapsed>=.2:
		_refresh_elapsed=0;refresh_state()
func _texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var path: String="res://assets/maps/"+file
		_textures[file]=load(path) if ResourceLoader.exists(path) else null
	return _textures[file]
func fit_scale() -> float:
	return maxf(.01,minf(size.x/FarmAtlasData.PAPER_SIZE.x,size.y/FarmAtlasData.PAPER_SIZE.y)*.98)
func map_scale() -> float: return fit_scale()*zoom
func map_origin() -> Vector2: return size*.5-FarmAtlasData.PAPER_SIZE*map_scale()*.5+pan
func map_to_screen(point: Vector2) -> Vector2: return (map_origin()+point*map_scale()).round()
func screen_to_map(point: Vector2) -> Vector2: return (point-map_origin())/map_scale()
func player_map_position() -> Vector2:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return Vector2.INF
	if layer_id=="world": return FarmAtlasData.WORLD_POINTS.get(FarmAtlasData.player_world_region(),Vector2.INF)
	if not FarmAtlasData.player_region_matches(region_id): return Vector2.INF
	var point: Vector2=game.player.global_position
	if region_id=="lake" and not FarmAtlasData.bounds(region_id).has_point(point): return Vector2.INF
	return FarmAtlasData.world_to_map(region_id,point)
func center_player() -> void:
	if layer_id=="region" and not FarmAtlasData.player_region_matches(region_id): show_region()
	var point:=player_map_position()
	if point==Vector2.INF:
		show_region();point=player_map_position()
	if point!=Vector2.INF: pan=(FarmAtlasData.PAPER_SIZE*.5-point)*map_scale()
	_clamp_pan();queue_redraw();view_changed.emit()
func zoom_by(factor: float) -> void: _zoom_at(factor,size*.5)
func _zoom_at(factor: float, anchor: Vector2) -> void:
	var old:=screen_to_map(anchor);zoom=clampf(zoom*factor,MIN_ZOOM,MAX_ZOOM)
	pan=anchor-size*.5+(FarmAtlasData.PAPER_SIZE*.5-old)*map_scale()
	_clamp_pan();queue_redraw();view_changed.emit()
func pan_by(delta: Vector2) -> void:
	pan+=delta;_clamp_pan();queue_redraw();view_changed.emit()
func _clamp_pan() -> void:
	var extent:=FarmAtlasData.PAPER_SIZE*map_scale()
	for axis in [0,1]:
		if extent[axis]<=size[axis]: pan[axis]=0
		else:
			var origin: float=size[axis]*.5-extent[axis]*.5+pan[axis]
			origin=clampf(origin,size[axis]-extent[axis]-12,12)
			pan[axis]=origin-size[axis]*.5+extent[axis]*.5
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("d2bd96"))
	if not _picture: return
	draw_texture_rect(_picture,Rect2(map_origin().round(),FarmAtlasData.PAPER_SIZE*map_scale()),false)
	if layer_id=="region": _draw_changes()
	else: _draw_world_changes()
	for item in resources:
		var at:=map_to_screen(item.point)
		var tone:=Color("62806a") if item.kind=="tree" else Color("8c8770")
		if not item.available: tone=Color("ae9b78")
		if item.kind=="tree": draw_colored_polygon(PackedVector2Array([at+Vector2(0,-5),at+Vector2(-4,3),at+Vector2(4,3)]),tone)
		else: draw_circle(at,3,tone)
	_label_rects.clear();_label_hits.clear()
	for item in places: _draw_place(item)
	var player:=player_map_position()
	if player!=Vector2.INF:
		var at:=map_to_screen(player)
		draw_circle(at,10,Color("35291f"));draw_circle(at,7,Color("f5e6bb"));draw_circle(at,4,Color("c3744d"))
		draw_line(at+Vector2(-3,-11),at+Vector2(0,-15),Color("f5e6bb"),2);draw_line(at+Vector2(0,-15),at+Vector2(3,-11),Color("f5e6bb"),2)
func _draw_world_changes() -> void:
	# The overview is a topological drawing; its bridge uses a paper coordinate,
	# not the independent village world coordinate used by the detailed sheet.
	var at:=map_to_screen(FarmAtlasData.WORLD_BRIDGE)
	var extent:=Vector2(40,27)*map_scale()
	draw_rect(Rect2(at-extent*.5,extent),Color("bfa173") if FarmAtlasData.bridge_open() else Color("86b5ad"))
	if FarmAtlasData.bridge_open():
		for x in range(-3,4): draw_line(at+Vector2(x*5,-12)*map_scale(),at+Vector2(x*5,12)*map_scale(),Color("e5c995"),maxf(1,2*map_scale()))
		draw_line(at+Vector2(-20,-13)*map_scale(),at+Vector2(20,-13)*map_scale(),Color("72553b"),maxf(1,2*map_scale()))
		draw_line(at+Vector2(-20,13)*map_scale(),at+Vector2(20,13)*map_scale(),Color("72553b"),maxf(1,2*map_scale()))
	else:
		draw_line(at+Vector2(-9,-7)*map_scale(),at+Vector2(9,7)*map_scale(),Color("a46b4b"),3)
		draw_line(at+Vector2(-9,7)*map_scale(),at+Vector2(9,-7)*map_scale(),Color("a46b4b"),3)
	if LakeEcology.state.restored:
		var lake:=map_to_screen(FarmAtlasData.WORLD_POINTS.lake+Vector2(-34,-14))
		for shift in [-7,0,7]: draw_line(lake+Vector2(shift,2),lake+Vector2(shift-2,-6),Color("62806a"),2)
	if FarmAtlasData.known("greenhouse") and (LegendState.state.greenhouse>=4 or Xiaojing.state.married):
		var star:=map_to_screen(FarmAtlasData.WORLD_POINTS.greenhouse+Vector2(25,-23))
		draw_line(star-Vector2(4,0),star+Vector2(4,0),Color("e7b96b"),2);draw_line(star-Vector2(0,5),star+Vector2(0,5),Color("e7b96b"),2)
func _draw_changes() -> void:
	if region_id=="home":
		for cells in HomeLayout.placement_regions(int(Housing.state.level)):
			var start:=map_to_screen(FarmAtlasData.world_to_map("home",Vector2(cells.position)*32))
			var end:=map_to_screen(FarmAtlasData.world_to_map("home",Vector2(cells.end)*32))
			var room:=Rect2(start,end-start)
			draw_rect(room,Color("d4b585"));draw_rect(room,Color("8e6c49"),false,3)
			for line in range(int(start.y+12),int(end.y),12): draw_line(Vector2(start.x+3,line),Vector2(end.x-3,line),Color("ead1a2"),1)
		for item in Housing.builtin_layout():
			if item.stored or not item.solid: continue
			var start:=map_to_screen(FarmAtlasData.world_to_map("home",item.position))
			var end:=map_to_screen(FarmAtlasData.world_to_map("home",item.position+item.size))
			draw_rect(Rect2(start,end-start),Color("8f9b76") if item.id in ["bed","sofa"] else Color("b19568"))
	if region_id=="village":
		var at:=map_to_screen(FarmAtlasData.world_to_map("village",Vector2(868,480)))
		var extent:=Vector2(87,24)*map_scale()
		draw_rect(Rect2(at-extent*.5,extent),Color("bfa173") if Story.stage>=5 else Color("719e9a"))
		if Story.stage>=5:
			for x in range(-4,5): draw_line(at+Vector2(x*9,-10)*map_scale(),at+Vector2(x*9,10)*map_scale(),Color("e5c995"),maxf(1,2*map_scale()))
		else:
			draw_line(at-Vector2(12,9),at+Vector2(12,9),Color("a46b4b"),3);draw_line(at+Vector2(-12,9),at+Vector2(12,-9),Color("a46b4b"),3)
	if region_id in ["farm","lake"] and LakeEcology.state.restored:
		for point in [Vector2(1024,512),Vector2(1192,656),Vector2(1064,704)]:
			var at:=map_to_screen(FarmAtlasData.world_to_map(region_id,point))
			draw_line(at,at-Vector2(3,9),Color("62806a"),2);draw_line(at,at+Vector2(3,-7),Color("789c79"),2)
func _draw_place(item: Dictionary) -> void:
	var at:=map_to_screen(item.point)
	if not Rect2(Vector2.ZERO,size).grow(80).has_point(at): return
	var icon: Texture2D=_texture("icon_"+str(item.icon)+".png")
	if item.id==selected_id: draw_circle(at,22,Color("e7b96b99"));draw_arc(at,22,0,TAU,24,Color("754b36"),1)
	if icon: draw_texture_rect(icon,Rect2(at-Vector2(18,22),Vector2(36,36)),false)
	var name_text: String=item.name
	var text_size: int=16
	var width: float=_font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
	for shift in [Vector2(0,28),Vector2(0,-28),Vector2(width*.5+25,4),Vector2(-width*.5-25,4),Vector2(0,52),Vector2(0,-52)]:
		var y: float=at.y+shift.y
		var x: float=clampf(at.x+shift.x-width*.5,8,maxf(8,size.x-width-8))
		var back:=Rect2(Vector2(x-5,y-17),Vector2(width+10,22))
		if not Rect2(Vector2.ZERO,size).encloses(back): continue
		var overlap: bool=false
		for old in _label_rects:
			if old.grow(3).intersects(back): overlap=true;break
		if overlap: continue
		_label_rects.append(back);_label_hits[str(item.id)]=back
		draw_style_box(_label_style,back)
		draw_string(_font,Vector2(x,y),name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("35291f") if item.discovered else Color("807354"))
		break
func place_at(position_local: Vector2) -> Dictionary:
	for item in places:
		if _label_hits.has(str(item.id)) and _label_hits[str(item.id)].has_point(position_local): return item
	var best: Dictionary={};var distance: float=maxf(30,UIMetrics.minimum_target()*.5)
	for item in places:
		var at:=map_to_screen(item.point);var current: float=at.distance_to(position_local)
		if current<distance: distance=current;best=item
	return best
func select_at(position_local: Vector2) -> void:
	var item:=place_at(position_local)
	if item.is_empty(): return
	selected_id=str(item.id);place_selected.emit(item.duplicate(true));queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device<0:
		accept_event();return
	if event is InputEventScreenTouch:
		if event.pressed:
			var mixed: bool=_mouse_down
			_mouse_down=false
			fingers[event.index]=event.position
			if fingers.size()==1: _primary=event.index;_start=event.position;_last=event.position;gesture_dragged=mixed;gesture_multi=event.canceled or mixed
			else: gesture_multi=true;gesture_dragged=true
		else:
			var click: bool=event.index==_primary and not event.canceled and not gesture_dragged and not gesture_multi and fingers.size()==1
			fingers.erase(event.index)
			if click: select_at(_start)
			if fingers.is_empty(): reset_gesture()
			elif fingers.size()==1: _last=fingers.values()[0];_start=_last
		accept_event()
	elif event is InputEventScreenDrag:
		if not fingers.has(event.index): accept_event();return
		if fingers.size()==1:
			if event.position.distance_to(_start)>UIMetrics.drag_threshold(): gesture_dragged=true
			if gesture_dragged: pan_by(event.position-_last)
			_last=event.position;fingers[event.index]=event.position
		elif fingers.size()==2:
			var old: Array=fingers.values();var old_center: Vector2=(old[0]+old[1])*.5;var old_distance: float=old[0].distance_to(old[1])
			fingers[event.index]=event.position;var next: Array=fingers.values();var next_center: Vector2=(next[0]+next[1])*.5;var next_distance: float=next[0].distance_to(next[1])
			if old_distance>12: _zoom_at(next_distance/old_distance,old_center)
			pan_by(next_center-old_center)
			gesture_multi=true;gesture_dragged=true
		else: fingers[event.index]=event.position;gesture_multi=true
		accept_event()
	elif event is InputEventMouseButton:
		if not fingers.is_empty(): gesture_multi=true;accept_event();return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			_zoom_at(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15,event.position)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _mouse_down=true;_start=event.position;_last=event.position;gesture_dragged=false
			elif _mouse_down:
				_mouse_down=false
				if not gesture_dragged: select_at(_start)
		accept_event()
	elif event is InputEventMouseMotion and _mouse_down:
		if event.position.distance_to(_start)>UIMetrics.drag_threshold(): gesture_dragged=true
		if gesture_dragged: pan_by(event.position-_last)
		_last=event.position;accept_event()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_VISIBILITY_CHANGED]: reset_gesture()
