extends PanelContainer
## 实体遗址交互：读完再提交调查，机关仅在玩家真实站位合法时执行。
var content: VBoxContainer
var context: String="forest_entry"
var pending := Callable()
var heading: String=""
var reading: String=""
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("山谷隐径 · 林地、水廊与归航庭",23,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title);header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
	FacilityLayout.decorate(self,"exploration","读懂刻线与水纹，再向隐径深处走一步。")

func words(text: String, size: int = 18) -> void:
	FacilityLayout.text(content,text,size)
func button(text: String, callback: Callable) -> Button:
	var control := FarmUIStyle.button(text,callback,160);content.add_child(control);return control
func open_panel(id: String) -> void:
	if GameState.modal or not Exploration.near_id(id): return
	context=id;pending=Callable();heading="";reading="";GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();heading="";reading="";hide();GameState.set_modal(false)
func result(ok: bool) -> void:
	if not ok: Events.notice.emit("前置、站位、恢复间隔或背包空间不满足，已有进度和资源已保留。")
	refresh()
func read_note(title: String, text: String, callback: Callable) -> void:
	heading=title;reading=text;pending=callback;refresh()
func finish_reading() -> void:
	var callback := pending;pending=Callable();heading="";reading=""
	if visible and Exploration.near_id(context) and callback.is_valid(): callback.call()
	refresh()
func cost_text(items: Dictionary) -> String:
	var parts: Array[String]=[]
	for item in items: parts.append("%s%d" % [Catalog.item_name(item),int(items[item])])
	return "、".join(parts)
func refresh() -> void:
	if not visible: return
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words(heading,23);words(reading,21);button("读完并记下",finish_reading);button("稍后再读",close_panel);return
	var record: Dictionary=Exploration.definition(context)
	words(record.title,23)
	if Exploration.data.entrances.has(context):
		words(record.text,20)
		var destination: String=record.destination
		if not Exploration.unlocked(destination):
			words("调查条件：湖底遗迹需要生态修复、森林排水副页；神庙需要前两份档案、星纹镐与晶石洞窟，不要求小京关系。",16)
			button("核对刻度并检查入口",func(): result(Exploration.inspect_entrance(destination)))
		else:
			words("入口稳定，出口随时可返回原地表。")
			button("沿真实通道进入"+Exploration.data.areas[destination].title,func(): close_panel();Exploration.enter(destination))
		return
	if not Exploration.accessible(context):
		words("前方仍有缠枝、积水或未校正的光路。先调查附近的刻线与控制点，再来这里。")
		return
	match record.kind:
		"exit": button(record.title,func(): close_panel();Exploration.exit_area())
		"note":
			button("展开记录"+(" · 已记下" if context in Exploration.state.facts else ""),func(): read_note(record.title,record.text,func(): Exploration.read(context)))
			if context in ["forest_order","lake_hint","temple_hint"]:
				var area: String=record.area
				button("在入口重置本轮未完成机关",func(): result(Exploration.reset_puzzle(area)))
			if context=="temple_archive": show_collection()
		"chest":
			words("匣内："+cost_text(record.reward)+"。满包时整笔保留，已领不会刷新。")
			button("打开并领取",func(): result(Exploration.claim_chest(context))).disabled=context in Exploration.state.chests
		"plant":
			var previous: int=int(Exploration.state.gathered.get(context,0))
			words("这处维护采样架每%d游戏日恢复，今天采集%s%d份；消耗2体力。" % [record.interval,Catalog.item_name(record.item),1 if context=="forest_herbs" and Calendar.season()==3 else record.count])
			if previous>0: words("上次记录：绝对第%d天。再进地图或读档不会加速恢复。" % previous,16)
			button("实际采集并记录",func(): result(Exploration.gather(context)))
		_:
			if record.area=="mist_forest": words("四季石桩已亮%d/4。刻痕提示在入口北侧，次序错了可重新走一轮。" % Exploration.state.forest.step)
			elif record.area=="lake_ruins": words("水位%d · 旁渠%s · 石桥%s" % [Exploration.state.lake.water,"已分流" if Exploration.state.lake.flow else "未分流","已露出" if Exploration.state.lake.open else "仍积水"])
			else: words("日光镜朝%s · 归航台%d/3" % [["东","顶","西"][int(Exploration.state.temple.mirror)],Exploration.state.temple.step])
			button("操作眼前机关一次",func(): result(Exploration.operate(context)))
func show_collection() -> void:
	words("归航手作与四季采样册",21)
	words("三个封记各制作一次。四季实际采过香叶、完成三种封记后可整理完整采样册；这是额外长期收藏，不是通过遗址的前置。",16)
	for id in Exploration.data.recipes:
		var recipe: Dictionary=Exploration.data.recipes[id]
		words(recipe.name+"："+cost_text(recipe.required),17)
		button("制作"+recipe.name,func(): result(Exploration.craft(id))).disabled=id in Exploration.state.crafted
	words("已记录%d/4季；已制作%d/3封记。整理完整册子奖励古水纹片2，只结算一次。" % [Exploration.state.samples.size(),Exploration.state.crafted.size()],16)
	button("整理完整四季采样册",func(): result(Exploration.claim_collection())).disabled=Exploration.state.collection_reward
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
