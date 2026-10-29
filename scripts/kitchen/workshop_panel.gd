extends PanelContainer
## One real device per panel. The world input layer follows the existing modal contract.
var device: String=""
var selected: String=""
var quantity: int=1
var epoch: int=0
var pending: Dictionary={}
var title: Label
var list: VBoxContainer
var detail: VBoxContainer
var status: Label
var progress: ProgressBar
var remaining: Label
var actions: HFlowContainer
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var head:=HBoxContainer.new();column.add_child(head)
	title=FarmUIStyle.label("丰收工坊",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	head.add_child(FarmUIStyle.button("收起 ×",close_panel,110))
	status=FacilityLayout.text(column,"选择配方，核对原料后开始。",16)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);column.add_child(body)
	var left:=ScrollContainer.new();left.set_script(preload("res://scripts/ui/touch_scroll.gd"));left.custom_minimum_size.x=220;left.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(left)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.add_child(list)
	var right:=ScrollContainer.new();right.set_script(preload("res://scripts/ui/touch_scroll.gd"));right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",12);right.add_child(detail)
	progress=ProgressBar.new();progress.custom_minimum_size.y=16;progress.show_percentage=false;column.add_child(progress)
	remaining=FacilityLayout.text(column,"",16)
	actions=FacilityLayout.actions(column)
	Workshop.changed.connect(refresh);Inventory.changed.connect(refresh)
	Events.location_changed.connect(func(_area: String):
		if visible: close_panel()
	)
	FacilityLayout.decorate(self,"workshop")

func open_panel(id: String) -> void:
	if GameState.modal or not Workshop.near_device(id) or Workshop.station_id(id)=="": return
	device=id;selected="";quantity=1;pending.clear();GameState.set_modal(true);show();refresh()
	Workshop.game.hud.reflow_panels()
func close_panel() -> void:
	epoch+=1;pending.clear();device="";hide();GameState.set_modal(false)
func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child);child.queue_free()
func action(parent: Node, text: String, callback: Callable, width: int=180) -> Button:
	var token: int=epoch
	var button:=FarmUIStyle.button(text,func():
		if visible and token==epoch and not GameState.restoring: callback.call()
	,width);parent.add_child(button);return button
func cost(inputs: Dictionary) -> String:
	var words: Array[String]=[]
	for id in inputs: words.append("%s　%d / %d" % [Catalog.item_name(id),Inventory.count(id),int(inputs[id])])
	return "\n".join(words)
func refresh() -> void:
	if not visible: return
	epoch+=1;clear(list);clear(detail);clear(actions)
	var station: String=Workshop.station_id(device)
	if station=="": close_panel();return
	title.text=HarvestCatalog.data().stations[station].name+" · 丰收工坊"
	var recipes: Dictionary=HarvestCatalog.data().processing
	var choices: Array[String]=[]
	for id in recipes:
		if recipes[id].processing_station_id==station: choices.append(id)
	if selected not in choices: selected=choices[0] if not choices.is_empty() else ""
	for id in choices:
		var recipe_id: String=id
		var b:=action(list,str(recipes[id].name),func(): selected=recipe_id;pending.clear();refresh(),200)
		b.icon=ItemPresentation.texture(str(recipes[id].output_item_id));b.expand_icon=true;b.add_theme_constant_override("icon_max_width",28)
		b.add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if id==selected else "secondary"))
	status.text="原料数量：持有 / 需要　·　每台设备保留一笔订单"
	if selected!="":
		var r: Dictionary=recipes[selected]
		var header:=HBoxContainer.new();detail.add_child(header);FacilityLayout.item_preview(header,str(r.output_item_id),64)
		FacilityLayout.text(header,str(r.name)+" ×"+str(int(r.output_quantity)*quantity),23)
		FacilityLayout.text(detail,"投入原料",21);FacilityLayout.text(detail,cost(Kitchen.scaled(r.input_items,quantity)),18)
		FacilityLayout.text(detail,"每批 %d 游戏分钟 · 成品单价 %d 金" % [r.processing_duration,Catalog.sell_price(str(r.output_item_id))],17)
		FacilityLayout.text(detail,ItemPresentation.description(str(r.output_item_id)),16)
		var uses: Array[String]=[]
		for recipe in HarvestCatalog.data().recipes.values():
			if recipe.input_items.has(r.output_item_id): uses.append(str(recipe.name))
		if not uses.is_empty(): FacilityLayout.text(detail,"后续料理："+"、".join(uses),16)
	if not pending.is_empty():
		status.text="确认投入原料？加工开始后会继续完成；关闭面板不取消订单。"
		action(actions,"确认开始",func():
			var request:=pending.duplicate();pending.clear();Workshop.start(device,request.recipe,int(request.batches));refresh()
		)
		action(actions,"取消",func(): pending.clear();refresh())
	elif Workshop.state.jobs.has(device):
		var job: Dictionary=Workshop.state.jobs[device]
		FacilityLayout.text(detail,"当前订单："+str(recipes[job.recipe].name)+" ×"+str(job.batches),21)
		var serial: int=int(job.id)
		var collect:=action(actions,"收取成品",func(): Workshop.claim(device,serial);refresh());collect.name="ClaimOutput";collect.disabled=Workshop.now_minutes()<int(job.finish_at)
		FacilityLayout.text(detail,"成品满包时保留在设备。可在建造模式移动设备，订单不会丢失。",16)
	else:
		action(actions,"−",func(): quantity=maxi(1,quantity-1);refresh(),48)
		actions.add_child(FarmUIStyle.label("%d 批" % quantity,20))
		action(actions,"+",func(): quantity=mini(8,quantity+1);refresh(),48)
		var begin:=action(actions,"开始加工",func(): pending={"recipe":selected,"batches":quantity};refresh(),180);begin.name="StartProcessing"
		begin.disabled=selected=="" or Inventory.preview_exchange(Kitchen.scaled(recipes[selected].input_items,quantity),{},0).is_empty()
	refresh_progress()
func refresh_progress() -> void:
	if not visible: return
	var job: Dictionary=Workshop.state.jobs.get(device,{})
	progress.visible=not job.is_empty()
	if job.is_empty(): remaining.text="空闲 · 多批按顺序加工，总耗时随批数增加。";return
	var left: int=maxi(0,int(job.finish_at)-Workshop.now_minutes())
	progress.max_value=int(job.finish_at)-int(job.started_at);progress.value=progress.max_value-left
	remaining.text="加工完成 · 等待收取" if left==0 else "剩余 %d 小时 %02d 分钟（游戏时间）" % [left/60,left%60]
func _process(_delta: float) -> void: refresh_progress()
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
