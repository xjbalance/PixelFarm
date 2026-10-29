extends PanelContainer
## 图纸是只读模态工具：不移动世界相机，不创建旅行或寻路任务。
var game: Node
var map_canvas: Control
var stage: Control
var reveal: Control
var title_label: Label
var info_label: Label
var zoom_label: Label
var world_button: Button
var current_button: Button
var detail_button: Button
var close_button: Button
var locate_button: Button
var zoom_in_button: Button
var zoom_out_button: Button
var selected_place: Dictionary={}
var unfold: Tween
var open_epoch: int=0
var layout_controls: Array[Button]=[]

func _ready() -> void:
	name="ParchmentAtlas";set_meta("parchment_atlas",true)
	add_to_group("modal_panels");hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	title_label=FarmUIStyle.label("河湾冒险图纸",24,FarmUIStyle.TITLE)
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title_label)
	close_button=FarmUIStyle.button("收起 ×",close_panel,104);header.add_child(close_button)
	var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",8);column.add_child(tools)
	world_button=FarmUIStyle.button("世界总览",show_world,120);tools.add_child(world_button)
	current_button=FarmUIStyle.button("当前区域",show_current,120);tools.add_child(current_button)
	locate_button=FarmUIStyle.button("定位人物",center_player,120);tools.add_child(locate_button)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;tools.add_child(spacer)
	zoom_out_button=FarmUIStyle.button("−",func(): map_canvas.zoom_by(1.0/1.25),48);tools.add_child(zoom_out_button)
	zoom_label=FarmUIStyle.label("100%",16);zoom_label.custom_minimum_size.x=56;zoom_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tools.add_child(zoom_label)
	zoom_in_button=FarmUIStyle.button("+",func(): map_canvas.zoom_by(1.25),48);tools.add_child(zoom_in_button)
	stage=Control.new();stage.clip_contents=true;stage.custom_minimum_size=Vector2(280,180)
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(stage)
	reveal=Control.new();reveal.clip_contents=true;stage.add_child(reveal)
	map_canvas=load("res://scripts/maps/atlas_canvas.gd").new();reveal.add_child(map_canvas)
	map_canvas.place_selected.connect(select_place)
	stage.resized.connect(resize_sheet)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	info_label=FarmUIStyle.label("拖动查看 · 双指或＋／−缩放 · 点击地点读说明",16)
	info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info_label.custom_minimum_size=Vector2(100,50)
	footer.add_child(info_label)
	detail_button=FarmUIStyle.button("查看详图",show_selected,120);detail_button.disabled=true;footer.add_child(detail_button)
	layout_controls=[close_button,world_button,current_button,locate_button,zoom_in_button,zoom_out_button,detail_button]
	Events.location_changed.connect(func(_area: String):
		if visible: close_panel()
	)
	GameClock.day_ending.connect(func(_reason: String):
		if visible: close_panel()
	)
	set_process(false)

func setup(owner_game: Node) -> void:
	game=owner_game;map_canvas.setup(game)

func open_panel() -> bool:
	if visible or not is_instance_valid(game) or GameState.modal or GameState.restoring or GameClock.settling or game.backgrounded or game.closing: return false
	if game.player.action_time>0:
		Events.notice.emit("等手上的动作结束，再展开地图。")
		return false
	game.auto_move.cancel();game.player.velocity=Vector2.ZERO;game.player.touch_direction=Vector2.ZERO
	game.hud.joystick.reset()
	# 旧农活短提示不盖住图纸底部的地点说明。
	game.hud.toast_time=0;game.hud.toast.hide()
	GameState.set_modal(true);show();set_process(true)
	layout_panel();show_world();resize_sheet()
	if is_instance_valid(unfold): unfold.kill()
	open_epoch+=1;reveal.size.x=0
	call_deferred("start_unfold",open_epoch)
	return true

func start_unfold(epoch: int) -> void:
	if not visible or epoch!=open_epoch: return
	# 等Container算完实际尺寸后展开裁剪，不缩放底图或中文。
	reveal.size=Vector2(0,stage.size.y)
	unfold=create_tween();unfold.tween_property(reveal,"size:x",stage.size.x,.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_panel() -> void:
	if not visible: return
	open_epoch+=1
	if is_instance_valid(unfold): unfold.kill()
	if map_canvas.has_method("reset_gesture"): map_canvas.reset_gesture()
	selected_place.clear();detail_button.disabled=true
	hide();set_process(false);GameState.set_modal(false)

func show_world() -> void:
	map_canvas.show_world();selected_place.clear();detail_button.disabled=true
	title_label.text="河湾冒险图纸 · 世界总览"
	info_label.text="沿河找到想去的地方。拖动查看，点击地点了解详情。"

func show_current() -> void:
	map_canvas.show_region();selected_place.clear();detail_button.disabled=true
	title_label.text="河湾冒险图纸 · 当前区域"
	info_label.text="白金标记是你。地点仅供查看；滚轮或双指缩放，拖动图纸查看周边。"

func center_player() -> void:
	map_canvas.center_player()
	title_label.text="河湾冒险图纸 · 你的位置"

func select_place(info: Dictionary) -> void:
	selected_place=info.duplicate(true)
	info_label.text=str(info.get("name","地点"))+" · "+str(info.get("description",""))
	detail_button.disabled=not bool(info.get("discovered",false)) or str(info.get("region",""))==""

func show_selected() -> void:
	if detail_button.disabled or selected_place.is_empty(): return
	map_canvas.show_region(str(selected_place.region))
	title_label.text="河湾冒险图纸 · "+str(selected_place.get("name","区域详图"))
	detail_button.disabled=true

func resize_sheet() -> void:
	if not is_instance_valid(map_canvas): return
	map_canvas.position=Vector2.ZERO;map_canvas.size=stage.size
	if not is_instance_valid(unfold) or not unfold.is_running(): reveal.size=stage.size
	else: reveal.size.y=stage.size.y

func layout_panel() -> void:
	if not is_instance_valid(game): return
	var usable: Vector2=game.hud.safe.size
	var extent: Vector2=(usable-Vector2(24,24)).min(Vector2(1440,900))
	game.hud.place(self,Vector2(.5,.5),Vector2(.5,.5),Rect2(-extent/2,extent))
	var target: float=UIMetrics.minimum_target()
	for button in layout_controls:
		button.custom_minimum_size.y=target
		button.custom_minimum_size.x=maxf(target,48 if button in [zoom_in_button,zoom_out_button] else (104 if button==close_button else 120))
	call_deferred("resize_sheet")

func _process(_delta: float) -> void:
	zoom_label.text="%d%%" % roundi(float(map_canvas.zoom)*100)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("story_map")):
		get_viewport().set_input_as_handled();close_panel()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and visible: close_panel()
