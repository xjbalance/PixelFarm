extends PanelContainer
## 剧情读完才提交；确认窗口不预扣材料。
var content: VBoxContainer
var pending := Callable()
var text_title: String = ""
var story_text: String = ""
var page: String = "main"
var confirmation: String = "读完并记下"

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var layout := VBoxContainer.new()
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var caption := FarmUIStyle.label("小京的约定",25,FarmUIStyle.GOLD)
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,110))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)

func open_panel(kind: String = "xiaojing") -> void:
	if GameState.modal: return
	page = "main"
	pending = Callable()
	GameState.set_modal(true)
	show()
	if kind == "xiaojing_letter":
		read_story("没有邮戳的信","你照顾土地的样子，我从河岸看见过很多次。我在做一份耐阴作物的记录，白天在河东观察，夜里去农场看星。愿意的话，带着你自己的问题来。——小京",func(): Xiaojing.read_letter())
	elif kind.begins_with("xiaojing_memory:"):
		var id := kind.trim_prefix("xiaojing_memory:")
		for memory in Xiaojing.data.memories:
			if memory.id == id: read_story(memory.title,memory.text,func(): Xiaojing.visit_memory(id))
	else: refresh()

func close_panel() -> void:
	pending = Callable()
	hide()
	GameState.set_modal(false)

func label_row(text: String, size: int = 18) -> void:
	var label := FarmUIStyle.label(text,size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func button(text: String, callback: Callable) -> Button:
	var result := FarmUIStyle.button(text,callback,160)
	content.add_child(result)
	return result

func read_story(title: String, text: String, callback: Callable = Callable(), confirm_text: String = "读完并记下") -> void:
	confirmation = confirm_text
	page = "story"
	text_title = title
	story_text = text
	pending = callback
	refresh()

func finish_story() -> void:
	var callback := pending
	pending = Callable()
	if callback.is_valid(): callback.call()
	page = "main"
	refresh()

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if page == "story":
		var portrait := FarmPortrait.new()
		portrait.person = "xiaojing"
		content.add_child(portrait)
		label_row(text_title,22)
		label_row(story_text,21)
		button(confirmation,finish_story)
		button("稍后再读",close_panel)
		return
	var state: Dictionary = Xiaojing.state
	label_row("好感 %d · 信任 %d · 羁绊 %d / 100\n专属任务 %d/12 · 记忆 %d/7 · 试炼 %d/5\n钻石 %d / 1314 · 稀有原矿 %d" % [state.affection,state.trust,state.bond,state.quests.size(),state.memories.size(),state.trials.size(),state.diamonds,state.ore])
	if page == "wedding":
		label_row("确认举行婚礼，将消耗1314颗钻石点亮已修复温室的全部星灯。取消不会扣除资源。",21)
		button("确认婚礼 · 消耗1314钻石",func():
			if Xiaojing.confirm_wedding(true):
				read_story("星灯为两个人留光","小京没有站在灯架中央。她把两张研究桌并排放好，给彼此留了一条走动的过道。你们各自点亮一半星灯，最后一盏一起合上木闸。\n“明天我还要去河岸。”她说。“好，晚饭时交换见闻。”你回答。")
			else: label_row("条件尚未全部满足；没有扣除资源。")
		)
		button("取消，继续商量",func(): page="main"; refresh())
	elif page == "puzzle":
		if state.trial.get("id","") == "mechanism":
			label_row("九格星灯：每按一格，会反转自身与上下左右的灯。五次以内将九盏灯全部点亮。\n记忆里的提示：先想角落，再想中央。已用%d/5次。" % state.mechanism_moves)
			var grid := GridContainer.new()
			grid.columns=3
			content.add_child(grid)
			for i in range(9):
				grid.add_child(FarmUIStyle.button("亮" if (int(state.mechanism)&(1<<i))!=0 else "暗",func(): Xiaojing.mechanism_input(i); refresh(),150))
		else:
			label_row("种箱刻痕：种子先落下，河风经过，潮声最后回答。\n错误会重置本轮。当前正确步数：%d" % state.puzzle_step)
			for i in range(3): button(["种子","潮声","河风"][i],func(): Xiaojing.puzzle_input(i); refresh())
		button("返回",func(): page="main"; refresh())
	elif page == "cave":
		build_cave()
	else:
		build_main()
	button("收起",close_panel)

func build_main() -> void:
	var state: Dictionary = Xiaojing.state
	if not Xiaojing.nearby():
		label_row("小京白天在河东观察站，傍晚在农场星灯台；婚后夜间也会回小屋。靠近她后可以交谈、赠礼和办理任务。")
	else:
		button("每日交谈",func():
			read_story("今天各自做了什么","她把今天的水位画在记录边上，又留一块空白给你的见闻。" if not state.married else "小京把自己的调查笔记放在左边，把你的农场账本放在右边：先各自说今天遇到的一件小事吧。",func(): Xiaojing.talk())
		)
		for item in ["carrot","potato","wheat"]:
			button("赠送%s ×1（每天一份）" % Catalog.item_name(item),func(): Xiaojing.gift(item); refresh())
		var event := Xiaojing.available_event()
		if not event.is_empty():
			button("关系事件 · "+str(event.title),func(): read_story(event.title,event.text,func(): Xiaojing.finish_event(event.id,event.id=="secret"),"愿意认真交往" if event.id=="secret" else "读完并记下"))
		var quest := Xiaojing.current_quest()
		if not quest.is_empty():
			label_row("%s · %s\n%s" % [quest.type,quest.title,quest.description],20)
			label_row(quest_progress(quest)+"\n交付："+materials_text(quest.materials),16)
			button("完成这项约定",func():
				if not Xiaojing.quest_ready(quest) or not Story.has_items(quest.materials):
					Events.notice.emit("目标尚未完成或材料不足，进度已保留。")
					return
				read_story(quest.title,quest.story,func(): Xiaojing.finish_quest(),"读完并提交约定")
			)
		button("共同写计划（茶座，18:00后）",func(): read_story("两份计划","你们把下一季想做的事写在同一张纸上，又为彼此保留不同的出发日期。",func(): Xiaojing.activity()))
		button("种箱与星灯机关",func(): page="puzzle"; refresh())
		if state.quests.size()>=7:
			if state.trial.is_empty():
				for id in ["management","planning","cave","mechanism","joint"]:
					if id not in state.trials: button("开始试炼 · "+trial_name(id),func(): Xiaojing.start_trial(id); refresh())
			else:
				label_row("正在进行："+trial_name(state.trial.id)+"\n"+trial_progress())
				button("检查试炼目标",func():
					if not Xiaojing.check_trial(): Events.notice.emit("试炼目标尚未满足；可继续尝试或放弃本轮。")
					refresh()
				)
				button("放弃本轮试炼（不退还已用资源）",func(): state.trial={}; state.puzzle_step=0; Xiaojing.commit(); refresh())
		button("基础矿道勘探",func(): page="cave"; refresh())
		button("精炼原矿5 + 石料12 → 钻石2",func(): Xiaojing.refine(); refresh())
		button("高阶考察委托：土豆12、小麦12、木材20 → 钻石5",func(): Xiaojing.hard_order(); refresh())
		button("开启记忆遗匣（收齐七份，一次18钻石）",func(): Xiaojing.claim_relic(); refresh())
		if state.quests.size()==12 and not state.greenhouse: button("修复星光温室：木80、石60、800金",func(): Xiaojing.repair_greenhouse(); refresh())
		if not state.married:
			label_row("婚礼：三项属性100、五段关系事件、恋爱关系、12任务、7记忆、5试炼、温室修复、1314钻石。",16)
			var propose := button("商量求婚与婚礼",func(): page="wedding"; refresh())
			propose.disabled = not Xiaojing.marriage_ready()
		else:
			label_row("已经结婚 · 婚后第 %d 天" % (GameClock.day-state.wedding_day))
			for id in ["separate_desks","field_trip","day520"]:
				if id == "day520" and not state.ultimate: continue
				if id not in state.post_events: button("婚后事件 · "+{"separate_desks":"并排的两张桌","field_trip":"各自归来的傍晚","day520":"第520日的回信"}[id],func(): read_story("星灯以外",post_text(id),func(): Xiaojing.post_event(id)))
	label_row("记忆收藏："+str(state.memories.size())+"/7",20)
	for memory in Xiaojing.data.memories:
		label_row(memory.title+" · "+Story.NAMES[memory.location]+(" ✓" if memory.id in state.memories else " · 未找到"),16)

func materials_text(materials: Dictionary) -> String:
	var parts: Array[String] = []
	for id in materials: parts.append("%s %d/%d" % [Catalog.item_name(id),Inventory.count(id),materials[id]])
	return "无需额外交付" if parts.is_empty() else " · ".join(parts)

func quest_progress(quest: Dictionary) -> String:
	var parts: Array[String] = []
	var s: Dictionary = Xiaojing.state
	for key in quest.conditions:
		var goal = quest.conditions[key]
		if key == "memory": parts.append("记忆 %d/%d" % [s.memories.size(),goal])
		elif key == "locations": parts.append("观察区域 %d/%d" % [s.visited.size(),goal])
		elif key == "trial": parts.append(trial_name(goal)+(" ✓" if goal in s.trials else " · 待挑战"))
		else: parts.append("%s %d/%d" % [{"plant":"本项种植","activity":"共同活动","puzzle":"解开种箱"}[key],s.counters[key]-s.quest_baseline[key],goal])
	return "目标已满足" if parts.is_empty() else " · ".join(parts)

func trial_name(id: String) -> String:
	return {"management":"八日经营","planning":"一日背囊","cave":"基础矿道路线","mechanism":"四星机关","joint":"联合考察"}[id]

func trial_progress() -> String:
	var t: Dictionary = Xiaojing.state.trial
	return "第%d日开始 · 种植%d · 新田收获%d · 净销售%d金\n采木%d/20 · 采石%d/12 · 体力%d（至少35）\n联合考察：地图%d/3、新田收获%d/6、解开一次种箱。\n矿道困难目标：采四处矿晶，探索20格，回到入口时余氧≥4。" % [t.day,t.plants,t.harvest,t.profit,t.wood,t.stone,GameState.stamina,t.maps.size(),t.harvest]

func build_cave() -> void:
	var c: Dictionary = Xiaojing.state.cave
	label_row("基础矿道 · 路线、气囊与回程规划。\n每次携带小麦2；移动耗氧1，开采耗氧2。三处矿晶带回可得钻石3。",17)
	if c.is_empty():
		label_row("需完成第一章和前七项小京任务后开放。原型为固定9×9路线盘，完整多层矿洞留待后续。",16)
		button("开始普通勘探（60氧）",func():
			if not Xiaojing.start_cave(): Events.notice.emit("先完成第一章、前七项约定，并备好小麦2。")
			refresh()
		)
		if Xiaojing.state.trial.get("id","")=="cave": button("开始困难试炼（36氧）",func(): Xiaojing.start_cave(true); refresh())
	else:
		label_row("剩余氧气%d · 已采矿晶%d/4" % [c.air,c.mined.size()],21)
		var map := ""
		for y in range(9):
			for x in range(9):
				var id := y*9+x
				map += "人" if x==c.x and y==c.y else ("■" if Xiaojing.cave_wall(x,y) else ("◇" if id in [12,34,66,70] and id not in c.mined else ("门" if id==10 else "·")))
			map += "\n"
		label_row(map,22)
		var row := HBoxContainer.new()
		content.add_child(row)
		for vector in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]: row.add_child(FarmUIStyle.button({Vector2i.UP:"上",Vector2i.LEFT:"左",Vector2i.DOWN:"下",Vector2i.RIGHT:"右"}[vector],func(): Xiaojing.cave_move(vector); refresh(),100))
		button("开采脚下矿晶",func(): Xiaojing.cave_mine(); refresh())
		button("从入口返回并结算",func(): Xiaojing.leave_cave(); refresh())
		button("沿安全绳撤退（放弃本次矿晶）",func(): Xiaojing.leave_cave(true); refresh())
	button("返回小京",func(): page="main"; refresh())

func post_text(id: String) -> String:
	return {"separate_desks":"她把两张桌子之间的路又让宽了一点：你做账时，我不会把标本放到你的账本上。今天的约定很小，却可以每天做到。","field_trip":"你从农场回来，她从河东回来。两只沾泥的杯子摆在一起，你们各说一件没能做成的事，也各说一件明天还想试的事。","day520":"这次的信有收件人。小京写：我们没有把五百二十天过成同一天。谢谢你记得我想去的地方，也把自己的愿望说给我听。信的背面画着两条路，在家的窗前相遇。"}[id]

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
