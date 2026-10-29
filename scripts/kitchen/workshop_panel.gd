extends PanelContainer
## Stable recipe list, deferred transaction refresh and clock-driven progress.
var device: String=""
var selected: String=""
var quantity: int=1
var epoch: int=0
var session: int=0
var pending: Dictionary={}
var title: Label
var list: VBoxContainer
var detail: VBoxContainer
var status: Label
var feedback: Label
var progress: ProgressBar
var remaining: Label
var actions: HFlowContainer
var left_scroll: ScrollContainer
var right_scroll: ScrollContainer
var recipe_buttons: Dictionary={}
var list_station: String=""
var detail_signature: Array=[]
var refresh_queued: bool=false
var progress_signature: Array=[]
var list_builds: int=0
var detail_builds: int=0
var progress_updates: int=0
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var head:=HBoxContainer.new();column.add_child(head)
	title=FarmUIStyle.label("丰收匠心",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;head.add_child(title)
	head.add_child(FarmUIStyle.button("收起 ×",close_panel,110))
	status=FacilityLayout.text(column,"选择配方，核对原料后开始。",17)
	feedback=FacilityLayout.text(column,"",16);feedback.hide()
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);column.add_child(body)
	left_scroll=ScrollContainer.new();left_scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));left_scroll.custom_minimum_size.x=220;left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(left_scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left_scroll.add_child(list)
	right_scroll=ScrollContainer.new();right_scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));right_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right_scroll)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",12);right_scroll.add_child(detail)
	progress=ProgressBar.new();progress.custom_minimum_size.y=16;progress.show_percentage=false;column.add_child(progress)
	remaining=FacilityLayout.text(column,"",16);actions=FacilityLayout.actions(column)
	Workshop.changed.connect(queue_refresh);Inventory.changed.connect(queue_refresh);VillageProjects.changed.connect(queue_refresh);GameClock.changed.connect(refresh_progress)
	Events.notice.connect(func(text: String):
		if visible: feedback.text=text;feedback.show()
	)
	Events.location_changed.connect(func(_area: String):
		if visible: close_panel()
	)
	FacilityLayout.decorate(self,"workshop")
func open_panel(id: String) -> void:
	if GameState.modal or not Workshop.near_device(id) or (Workshop.station_id(id)=="" and not Workshop.state.orchard.has(id)): return
	session+=1;list_station="";detail_signature=[];progress_signature=[];feedback.hide()
	device=id;selected=str(Workshop.state.jobs.get(id,{}).get("recipe",""));quantity=int(Workshop.state.jobs.get(id,{}).get("batches",1));pending.clear()
	left_scroll.scroll_vertical=0;right_scroll.scroll_vertical=0;GameState.set_modal(true);show();refresh();call_deferred("layout_panel")
	if Workshop.station_id(id)=="mill":
		var hint: String=Workshop.game.tutorial.inline_hint("workshop_first")
		if hint!="": feedback.text=hint;feedback.show()
func layout_panel() -> void:
	if visible and is_instance_valid(Workshop.game): Workshop.game.hud.reflow_panels()
func close_panel() -> void:
	epoch+=1;session+=1;pending.clear();device="";hide();GameState.set_modal(false)
func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child);child.queue_free()
func queue_refresh() -> void:
	if not visible or refresh_queued: return
	refresh_queued=true;call_deferred("flush_refresh")
func flush_refresh() -> void:
	refresh_queued=false
	if visible: refresh()
func action(parent: Node, text: String, callback: Callable, width: int=180) -> Button:
	var token: int=epoch
	var button:=FarmUIStyle.button(text,func():
		if visible and token==epoch and not GameState.restoring: callback.call()
	,width);parent.add_child(button);return button
func cost(inputs: Dictionary) -> String:
	var words: Array[String]=[]
	for id in inputs: words.append("%s　%d / %d" % [Catalog.item_name(id),Inventory.count(id),int(inputs[id])])
	return "\n".join(words)
func select_recipe(id: String) -> void:
	selected=id;pending.clear();feedback.hide();right_scroll.scroll_vertical=0;refresh()
func build_list(station: String) -> void:
	if list_station==station: return
	list_station=station;list_builds+=1;clear(list);recipe_buttons.clear()
	var token: int=session
	for id in HarvestCatalog.data().processing:
		var recipe: Dictionary=HarvestCatalog.data().processing[id]
		if recipe.processing_station_id!=station: continue
		var recipe_id: String=id
		var button:=FarmUIStyle.button(str(recipe.name),func():
			if visible and session==token and not GameState.restoring: select_recipe(recipe_id)
		,200)
		button.icon=ItemPresentation.texture(str(recipe.output_item_id));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28);button.add_theme_font_size_override("font_size",16)
		button.set_meta("recipe_id",id);list.add_child(button);recipe_buttons[id]=button
func refresh() -> void:
	if not visible: return
	if Workshop.state.orchard.has(device):
		epoch+=1;clear(detail);clear(actions);show_orchard();return
	left_scroll.show();var station:=Workshop.station_id(device)
	if station=="": close_panel();return
	build_list(station)
	var recipes: Dictionary=HarvestCatalog.data().processing
	if not recipe_buttons.has(selected): selected=str(recipe_buttons.keys()[0]) if not recipe_buttons.is_empty() else ""
	for id in recipe_buttons:
		var r: Dictionary=recipes[id];var ready: bool=HarvestCatalog.unlocked(str(r.unlock_condition));var missing:=Workshop.missing_materials(Kitchen.scaled(r.input_items,quantity))
		var state: String="未解锁" if not ready else "材料不足" if missing!="" else "可制作"
		var button: Button=recipe_buttons[id];button.text=str(r.name)+"\n"+state;button.tooltip_text=missing
		if button.get_meta("recipe_state","")!=state:
			button.add_theme_color_override("font_color",FarmUIStyle.SUCCESS if ready and missing=="" else FarmUIStyle.MUTED);button.set_meta("recipe_state",state)
		if not button.has_meta("is_selected") or bool(button.get_meta("is_selected"))!=(id==selected):
			button.add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if id==selected else "secondary"));button.set_meta("is_selected",id==selected)
	var job: Dictionary=Workshop.state.jobs.get(device,{})
	var held: Array=[]
	if selected!="" and (job.is_empty() or job.recipe!=selected):
		for id in recipes[selected].input_items: held.append([id,Inventory.count(id)])
	var signature: Array=[selected,quantity,job.hash(),pending.hash(),held]
	if signature==detail_signature: refresh_progress();return
	detail_signature=signature;epoch+=1;detail_builds+=1
	var scroll: int=right_scroll.scroll_vertical;clear(detail);clear(actions)
	title.text=HarvestCatalog.data().stations[station].name+" · 丰收匠心"
	status.text="空闲 · 选配方后确认投入" if job.is_empty() else "成品已完成 · 等待收取" if WorkshopVisual.status(device)=="ready" else "加工中 · 可离开设备，进度会保留"
	if selected!="":
		var recipe: Dictionary=recipes[selected];var current: bool=not job.is_empty() and job.recipe==selected
		var output: Dictionary=job.outputs if current else {str(recipe.output_item_id):int(recipe.output_quantity)*quantity}
		var product: String=str(output.keys()[0]);var header:=HBoxContainer.new();detail.add_child(header);FacilityLayout.item_preview(header,product,56)
		var heading:=FacilityLayout.text(header,Catalog.item_name(product)+" ×"+str(output[product]),23);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		FacilityLayout.text(detail,"本单已投入" if current else "需要原料 · 持有 / 需要",20)
		ProductionInfo.materials(detail,job.inputs if current else Kitchen.scaled(recipe.input_items,quantity),current)
		var duration: int=int(job.finish_at)-int(job.started_at) if current else int(recipe.processing_duration)*quantity
		FacilityLayout.text(detail,"总耗时 "+ProductionInfo.duration(duration)+" · 单价 %d金" % Catalog.sell_price(product),17)
		FacilityLayout.text(detail,ProductionInfo.uses(product),16)
		if not job.is_empty() and not current: FacilityLayout.text(detail,"正在浏览下一份配方；本单仍为"+str(recipes[job.recipe].name)+"。",16)
	if not pending.is_empty():
		status.text="确认投入后开始加工；取消不扣材料。"
		action(actions,"确认开始",func():
			var request:=pending.duplicate();pending.clear();Workshop.start(device,request.recipe,int(request.batches));refresh()
		)
		action(actions,"取消",func(): pending.clear();feedback.hide();refresh())
	elif not job.is_empty():
		var serial: int=int(job.id)
		var collect:=action(actions,"收取成品",func(): Workshop.claim(device,serial);refresh());collect.name="ClaimOutput";collect.disabled=WorkshopVisual.status(device)!="ready"
		if not collect.disabled: collect.add_theme_stylebox_override("normal",FarmUIStyle.surface("nature"))
	else:
		action(actions,"−",func(): quantity=maxi(1,quantity-1);feedback.hide();refresh(),48);actions.add_child(FarmUIStyle.label("%d 批" % quantity,20))
		action(actions,"+",func(): quantity=mini(8,quantity+1);feedback.hide();refresh(),48)
		var reason: String=Workshop.start_error(device,selected,quantity) if selected!="" else "没有可用配方。"
		var begin:=action(actions,"开始加工",func(): pending={"recipe":selected,"batches":quantity};feedback.hide();refresh(),180);begin.name="StartProcessing";begin.disabled=reason!=""
		if reason!="":
			status.text=reason
			if reason.begins_with("还缺"):
				var hint: String=Workshop.game.tutorial.inline_hint("recipe_missing")
				if hint!="": feedback.text=hint;feedback.show()
	progress_signature=[];refresh_progress();call_deferred("restore_scroll",epoch,scroll)
func restore_scroll(token: int, value: int) -> void:
	if visible and token==epoch: right_scroll.scroll_vertical=value
func refresh_progress() -> void:
	if not visible or Workshop.state.orchard.has(device): return
	var job: Dictionary=Workshop.state.jobs.get(device,{})
	var signature: Array=[selected,quantity,job.hash(),Workshop.now_minutes()]
	if signature==progress_signature: return
	progress_signature=signature;progress_updates+=1;progress.visible=not job.is_empty()
	if job.is_empty():
		var recipe: Dictionary=HarvestCatalog.data().processing.get(selected,{})
		remaining.text="预计完成："+ProductionInfo.eta(Workshop.now_minutes()+int(recipe.get("processing_duration",0))*quantity)+" · 按游戏时间计算"
		return
	var left: int=maxi(0,int(job.finish_at)-Workshop.now_minutes())
	progress.max_value=int(job.finish_at)-int(job.started_at);progress.value=progress.max_value-left
	remaining.text="加工完成 · 满包时成品会继续保留" if left==0 else "剩余 "+ProductionInfo.duration(left)+" · 预计 "+ProductionInfo.eta(int(job.finish_at))
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
func show_orchard() -> void:
	left_scroll.hide();progress.hide();pending.clear()
	var fruit: String=str(Territory.object(device).kind).trim_prefix("orchard_")
	var tree: Dictionary=HarvestCatalog.data().orchard[fruit];var row: Dictionary=Workshop.state.orchard[device]
	title.text=str(tree.name)+" · 我的果园";status.text="生长不需每天浇水；移动保留树龄与果实。"
	FacilityLayout.item_preview(detail,fruit,64);FacilityLayout.text(detail,"树龄 %d / %d 天" % [mini(Workshop.tree_age(device),int(tree.growth_days)),tree.growth_days],23)
	var seasons: Array[String]=[]
	for index in tree.seasons: seasons.append(["春","夏","秋","冬"][int(index)])
	FacilityLayout.text(detail,"结果季："+"、".join(seasons)+"。成熟后每%d天结%d份果实。" % [tree.regrow_days,tree.yield],18)
	FacilityLayout.text(detail,"树上成熟果实：%d。满包不丢果；回收树苗会重置生长，请优先移动。" % row.fruit,17)
	FacilityLayout.text(detail,ProductionInfo.uses(fruit),16)
	var button:=action(actions,"收获果实",func(): Workshop.harvest_fruit(device);refresh());button.name="HarvestFruit";button.disabled=int(row.fruit)<=0
	remaining.text="建造 → 植被 → 生产果园；树苗由种子合作社供货。"
