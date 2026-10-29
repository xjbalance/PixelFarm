extends PanelContainer
var person: String="linya"
var site: String=""
var content: VBoxContainer
var pending := Callable()
var text: String=""
var content_section: VBoxContainer
func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.heading(header,"河湾近况 · 每个人的生活","village")
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
func content_group() -> VBoxContainer:
	if not is_instance_valid(content_section) or not content_section.is_inside_tree(): content_section=FarmUIStyle.card(content)
	return content_section
func words(line: String,size: int=18) -> void:
	if size>=22: content_section=FarmUIStyle.card(content)
	var label := FarmUIStyle.label(line,size,FarmUIStyle.TITLE if size>=22 else FarmUIStyle.TEXT);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content_group().add_child(label)
func button(caption: String,callback: Callable) -> Button:
	var control := FarmUIStyle.button(caption,callback,160);content_group().add_child(control);return control
func open_panel(id: String="linya") -> void:
	if GameState.modal or id not in Social.PEOPLE: return
	person=id;site="";pending=Callable();GameState.set_modal(true);show();refresh()
func open_site(id: String) -> void:
	if GameState.modal or not Social.near_site(id): return
	site=id;pending=Callable();GameState.set_modal(true);show();refresh()
func close_panel() -> void:
	pending=Callable();hide();GameState.set_modal(false)
func ask(line: String,callback: Callable) -> void:
	text=line;pending=callback;refresh()
func finish_read() -> void:
	var callback := pending;pending=Callable()
	if visible and callback.is_valid(): callback.call()
	refresh()
func outcome(ok: bool) -> void:
	if not ok: Events.notice.emit("还缺现场行动、时间、关系或材料；已完成记录保留，不会因此永久失去结局。")
	refresh()
func refresh() -> void:
	if not visible: return
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words(text,21);button("确认并继续",finish_read);button("稍后再说",func(): pending=Callable();refresh());return
	if site!="":
		words("把现场看清楚",23)
		words(site_line(site))
		button("完成这次现场观察",func(): outcome(Social.observe_site(site)))
		return
	var data: Dictionary=Social.data.people[person]
	var profile:=FarmUIStyle.card(content)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);profile.add_child(row)
	var portrait := FarmPortrait.new();portrait.person=person;portrait.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;row.add_child(portrait)
	content_section=VBoxContainer.new();content_section.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(content_section)
	var name_label:=FarmUIStyle.heading(content_section,"%s · 好感%d/100 · 生日%s%d日" % [data.name,Social.friendship(person),Calendar.SEASON_NAMES[data.birthday[0]],data.birthday[1]])
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words(Social.daily_line(person))
	content_section=null
	var nearby: bool=Social.near_person(person)
	if not nearby: words("现在可以读近况和目标；交谈、赠礼、接取与完成约定需要走到本人身边。",16)
	button("聊聊今天",func(): ask(Social.daily_line(person),func(): outcome(Social.talk(person)))).disabled=not nearby
	var gift_ids: Array=data.likes.duplicate();gift_ids.append_array(data.dislikes)
	if person!="xiaojing":
		for item in Inventory.items:
			if item not in gift_ids and Catalog.items.get(item,{}).get("gift_to","")==person: gift_ids.append(item)
	for item in gift_ids:
		button("赠送%s ×1 · %s（持有%d）" % [Catalog.item_name(item),Social.taste(person,item),Inventory.count(item)],func(): ask("赠送一份"+Catalog.item_name(item)+"？与此人的其他赠礼入口共享每日额度，最近重复的礼物不反复加好感。",func(): outcome(Social.gift(person,item)))).disabled=not nearby or Inventory.count(item)<1
	var quest: Dictionary=Social.current(person)
	if quest.is_empty(): words("个人三章已完成。你们说过的选择仍在日常对白里，生活会继续。",20)
	else:
		words(quest.title,23);words(quest.description);words(Social.progress(person),16)
		if not quest.required.is_empty():
			var needs: Array[String]=[]
			for item in quest.required: needs.append("%s%d / 持有%d" % [Catalog.item_name(item),int(quest.required[item]),Inventory.count(item)])
			words("最终交付："+"、".join(needs),16)
		if not Social.state.active.has(person): button("接下这项约定",func(): outcome(Social.accept(person))).disabled=not nearby
		else:
			words(quest.failure,16)
			if Social.state.active[person].missed: button("带着新行动重新约定时间",func(): outcome(Social.rebook())).disabled=not nearby
			for choice in quest.choices:
				button(quest.choices[choice],func(): ask(quest.reply+"\n选择："+quest.choices[choice]+"\n完成要求与材料会在确认时再次检查。",func(): outcome(Social.finish(person,choice)))).disabled=not nearby or not Social.ready(person)
	var festival := get_node_or_null("/root/Festival")
	if festival and festival.has_method("active_id") and festival.active_id()!="":
		button("聊聊今天的节日",func(): outcome(festival.talk(person))).disabled=not nearby
		if festival.active_id()=="winter": button("送一份冬日暖锅",func(): outcome(festival.deliver_winter(person))).disabled=not nearby
func site_line(id: String) -> String:
	return {"kitchen":"打开台面上的设备盖，看看零件怎样拆装。需要至少一台已建加工设备；不用拆除或重建旧设备。","cycle":"沿湖岸确认修好的循环口，抄下水流方向。需要实际修好水循环设施。","tea":"18:00–20:00把晚饭安排放到已建茶座，阿禾也需要在附近。","tea_season":"看看当季茶座留下的使用痕迹，给阿禾的休息日留一份不占用座位的安排。","lake_date":"约定日18:00–20:00和小京在湖边见面，看完水面再实际抛竿。两项都完成才算守约；没赶上可以做一餐或新收获后重约。","summer_sky":"夏季20:00以后，一起辨认湖上的星位。小京会先完成自己的日间记录再来。","winter_window":"冬季检查温室气窗与灯罩的旧刻度。结构至少修复到第二阶段，原有温室无需再交建设材料。","ecology_after":"修复完成后把新旧湖水放在同一张记录上，小京白天会在岸边一起核对。","star_lake":"只有真实流星夜才能看到这条映光。生态修复后，小京会在湖边和你一起记录；不是把普通晴夜改成流星。"}.get(id,"")
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
