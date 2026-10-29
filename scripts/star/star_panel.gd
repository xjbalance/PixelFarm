extends "res://scripts/ui/xiaojing_panel.gd"
## 复用原有安全区、原生触点滚动和模态取消。所有按钮仍由规则层检查距离。
var context: String = "overview"
func _ready() -> void:
	super._ready()
	panel_title.text="星光手记 · 记忆与约定"
func open_panel(kind: String = "overview") -> void:
	if GameState.modal: return
	context=kind
	page="main"
	pending=Callable()
	GameState.set_modal(true)
	show()
	refresh()
func act(callback: Callable) -> void:
	if not callback.call(): Events.notice.emit("暂时做不了：检查现场、前置记录、时段和材料。进度已保留。")
	refresh()
func refresh() -> void:
	if page=="story":
		super.refresh()
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	label_row("第 1314 颗星星",25)
	if context.begins_with("memory:"):
		build_memory(context.trim_prefix("memory:"))
	elif context.begins_with("person:"):
		var id := context.trim_prefix("person:")
		label_row("“把你们的决定当面告诉我吧。温室的桌子，也留一个给要来借书的人。”",21)
		if StarStory.has("proposal") and id not in StarStory.state.invited:
			button("亲自送出婚礼邀请",func(): act(func(): return StarStory.invite(id)))
		if LegendTrials.active("joint"):
			button("按传说联合考察的分工提交",func(): act(func(): return LegendTrials.cooperate(id)))
		if StarTrials.active("joint"):
			label_row({"linya":"先新收小麦3，交给林芽留下种源。","zhou":"和周砚确认已修气窗的检修位置。","ahe":"和阿禾核对已拼好的停用记录。"}[id])
			button("核对需要，再分工",func(): act(func(): return StarTrials.collaborate(id)))
			button("替对方直接决定",func(): act(func(): return StarTrials.collaborate(id,1)))
		button("继续原本的村庄交谈",func(): close_panel(); Story.request(id))
	elif context=="seed_box":
		label_row("种子先落下，河风经过，潮声最后回答。每次转动一只旋扣，错误可以重试。")
		for i in range(3): button(["种子","潮声","河风"][i],func(): Xiaojing.puzzle_input(i); refresh())
		label_row("已对齐%d/3" % Xiaojing.state.puzzle_step)
	elif context=="greenhouse": build_greenhouse()
	elif context in ["desk_left","desk_right"]: build_desk()
	else: build_overview()
	button("收起",close_panel)
func build_memory(id: String) -> void:
	for memory in Xiaojing.data.memories:
		if memory.id!=id: continue
		label_row(memory.title,23)
		label_row(memory.text,21)
		label_row("观察方法："+memory.action)
		if not River.state.legacy_rules: label_row(River.data.memories[id].hint)
		if id in ["window","bridge","mill","orchard"] and not River.memory_ready(id):
			for step in River.data.memories[id].steps:
				if id=="bridge" and step=="new": continue
				button({"date":"比对育苗日期","light":"量取窗边光线","old":"拓印旧水线","seed":"对照留种栏","empty":"对照空车接人栏","night":"观察晚归灯图"}[step],func(): act(func(): return memory_probe(id,step)))
		var options: Array=StarStory.data.memory_options[memory.method]
		for i in range(options.size()):
			button(options[i],func():
				if StarStory.memory_action(id,i):
					for key in MineState.placements:
						if MineState.placements[key].get("memory","")==id and MineState.near_id(key): MineState.memory_at(key)
					label_row("这份记忆已记下。旧收藏不会再计一次。")
			)
func build_overview() -> void:
	if not Xiaojing.state.married:
		label_row("婚礼生活准备",20)
		label_row(Xiaojing.marriage_goals_text(),17)
	for entry in Xiaojing.data.acts: label_row(("✓ " if StarStory.has("act_"+str(entry.id)) else "○ ")+entry.title+" · "+entry.text,20)
	label_row("温室在农场东南，旧种箱在小屋南侧。先调查气窗，再把七份记忆带回档案桌。\n小京婚后6–9时在农场，9–16时在河东，16–18时回温室；18–20时有茶座则到村庄，21时回小屋。")
	var q := Xiaojing.current_quest()
	if not q.is_empty():
		label_row(q.title+"\n触发："+q.trigger+"\n玩法："+q.gameplay+"\n暂缓："+q.failure+"\n后续："+q.after)
		label_row("属性奖励：好感%d 信任%d 羁绊%d" % [q.reward.affection,q.reward.trust,q.reward.bond])
	if Xiaojing.nearby():
		if "tea_together" in Xiaojing.state.quests and not StarStory.state.choices.has("tables"):
			label_row("桌子怎么摆？两种决定都能继续。")
			for option in ["separate","together"]: button(StarStory.data.choices.tables[option],func(): act(func(): return StarStory.choose("tables",option)))
		if Xiaojing.state.dating:
			button("约明晚18–20时在公共茶座见面",func(): act(StarStory.book_appointment))
			button("赴约，交换今天的见闻",func(): act(StarStory.attend_appointment))
		if StarStory.state.repair_pending:
			button("说明失约的原因，重新商量安排",func(): act(StarStory.repair_relationship))
		if not Xiaojing.state.married:
			label_row("求婚需要三属性100、全部任务记忆试炼、五段关系事件、温室、历史拼接、两项决定、1314钻石，以及已完工四级住宅和永恒星鲤钓获记录。求婚不扣钻。")
			for choice in ["share_home","keep_journeys"]:
				button({"share_home":"求婚：一起经营家，也留独立研究桌","keep_journeys":"求婚：一起生活，也保留各自的远行"}[choice],func(): act(func(): return StarStory.propose(choice)))
	if not Xiaojing.state.trial.is_empty(): label_row(StarTrials.describe())
func build_greenhouse() -> void:
	button("星光温室礼堂 / 0.6婚后计划",func(): close_panel(); Events.interaction_requested.emit("river:archive"))
	button("传说约定 · 五阶段温室 / 百层勘探计划",func(): close_panel(); Events.interaction_requested.emit("abyss:legend"))
	var s: Dictionary=StarStory.state
	label_row("气窗里压着一张避洪安置表。温室先是育苗处，洪水时让给居民临时住下；停用页写的是缺少检修与清水，不是某一个人的过错。\n拼接提示：先找窗边育苗日期，再对桥的水线，最后看安置名单的批注。",21)
	button("调查气窗与旧安置表",func(): act(StarStory.inspect_greenhouse))
	button("修气窗 · 木2 石2",func(): act(StarStory.repair_vent))
	if StarTrials.active("planning"): button("安装自己加工的铰链 · 铜锭1 木4 石2",func(): act(StarTrials.build_hinge))
	if Xiaojing.state.memories.size()==7 and not StarStory.has("history_solved"):
		label_row("把三份证据按发生顺序摆好。已摆%d/3，错序可重试。" % s.assembly)
		for id in ["window","bridge","post"]: button({"window":"窗边育苗笔记","bridge":"旧桥水线","post":"停用名单批注"}[id],func(): act(func(): return StarStory.assemble(id)))
	if StarStory.has("history_solved") and not s.choices.has("closure"):
		for choice in ["water","seeds"]: button(StarStory.data.choices.closure[choice],func(): act(func(): return StarStory.choose("closure",choice)))
	if not Xiaojing.state.married:
		label_row(Xiaojing.marriage_goals_text(),17)
		label_row("已邀请："+str(s.invited)+"。邀请需要亲自到三位村民身边交谈。")
		button("开始温室仪式，等候亲友到场",func(): act(StarStory.start_ceremony))
		if s.wedding_phase==1: label_row("林芽带来留种袋，周砚检查灯闸，阿禾把留言册放在入口。请走到左研究桌布置。")
	else:
		if s.wedding_phase==3:
			label_row("周砚扶稳灯架，林芽把留种袋递给你们，阿禾请大家在册上写下归期。小京拉开两张桌之间的过道：明天我仍去河岸，晚上回来交换见闻。最后一盏星灯亮起。",21)
			button("一起收好留言册，结束仪式",func(): act(StarStory.finish_ceremony))
		for id in ["separate_desks","field_trip"]:
			if id in Xiaojing.state.post_events: continue
			var entry: Dictionary=StarStory.data.post_events[id]
			button("开始婚后项目 · "+entry.title,func(): act(func(): return StarStory.start_post(id)))
			if s.post_run==id:
				label_row("目标："+str(entry.goals)+"\n已完成："+str(s.post_steps))
				button("核对成果 · "+entry.title,func(): read_story(entry.title,entry.text,func(): Xiaojing.post_event(id)))
		button("共同照料最多6格缺水作物（每日一次）",func(): act(StarStory.cooperate))
		label_row("季节活动：春播3、夏浇6、秋收3、冬到右桌点灯。每季完成一次，奖励麦种2。")
		button("开始本季共同活动",func(): act(StarStory.start_season))
		button("记录本季成果",func(): act(StarStory.finish_season))
		if GameClock.day-int(Xiaojing.state.wedding_day)>=520 and "day520" not in Xiaojing.state.post_events:
			button("打开第520日的最终回信",func(): read_story("第520日的回信",StarStory.data.post_events.day520.text,func(): Xiaojing.post_event("day520")))
func build_desk() -> void:
	var s: Dictionary=StarStory.state
	label_row("一张留给研究，一张留给农场账本。中间的过道不堆东西。")
	if s.post_run=="separate_desks": button("亲手整理这张研究桌",func(): act(func(): return StarStory.work_desk(context)))
	if context=="desk_left" and s.wedding_phase==1: button("摆好两只杯子与村民留言册",func(): act(StarStory.place_wedding_table))
	if context=="desk_right" and s.wedding_phase==2:
		label_row(Xiaojing.marriage_goals_text(),17)
		label_row("最终确认将消耗1314颗钻石，点亮温室全部星灯并缔结婚姻。取消不会扣除。",21)
		button("最终确认婚礼 · 消耗1314钻石",func():
			if Xiaojing.confirm_wedding(true):
				read_story("第 1314 颗星星","小京把灯闸握在你手边。周砚扶稳支架，林芽把麦种放在桌上，阿禾翻开新的一页。你们一起合上木闸，灯光沿着窗架一盏盏亮起。\n“明天我还去河岸。”小京说。“好，晚饭时交换见闻。”\n回温室档案桌收好留言册，仪式就结束了。")
			else: Events.notice.emit("条件尚未全部满足，没有扣钻。")
		)
		button("取消，先收起灯闸",close_panel)
	if context=="desk_right" and Xiaojing.state.married: button("冬季检查灯罩并点灯",func(): act(StarStory.winter_lamp))

func memory_probe(id: String, step: String) -> bool:
	if not StarStory.near_memory(id): return false
	if id=="orchard" and GameClock.minutes<1140: return false
	if id=="window" and step=="light" and "date" not in River.state.memory_steps.get(id,[]): return false
	River.memory_step(id,step);return true
