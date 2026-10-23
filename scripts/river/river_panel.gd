extends "res://scripts/ui/mine_panel.gd"
func open_panel(id: String = "journal") -> void:
	if GameState.modal: return
	context=id;reading=false;pending=Callable()
	if id.begins_with("talk:"):
		var who := id.trim_prefix("talk:")
		read("留给下一班的话 · "+Story.data.people[who].name,River.data.talks[who]+"\n"+ChapterTwo.branch_line(),func(): River.talk(who))
	GameState.set_modal(true);show();refresh()
func act(callback: Callable) -> void:
	if not callback.call(): Events.notice.emit("现场或条件还未满足，已保留进度与资源。")
	refresh()
func refresh() -> void:
	if reading: super.refresh();return
	for n in content.get_children(): content.remove_child(n);n.queue_free()
	match context:
		"ceremony_left":
			words("林芽把留种袋放在桌角，周砚压好灯线，阿禾翻开留言册。你与小京各留下自己的研究位置。",21)
			button("摆好两只杯子与研究笔记",func(): act(StarStory.place_wedding_table))
		"ceremony_right":
			words("最后确认：消耗1314颗钻石点亮全部星灯，缔结婚姻。取消不扣。当前%d钻石。" % Xiaojing.state.diamonds,21)
			button("最终确认 · 点亮1314盏星灯",func():
				if Xiaojing.confirm_wedding(true):
					read("第1314颗星星","两个人一起合上灯闸。林芽说，留种的那页终于有了归期；周砚把备用灯芯留在桌下；阿禾为两位各添一行名字。\n小京：我想和你在这里生活。明天我仍去河岸，你也不必放下自己的田。\n请走到前方星灯下，交换最后的约定。",Callable())
				else: Events.notice.emit("条件尚未满足；没有扣除钻石。")
				refresh()
			)
			button("取消，继续准备",close_panel)
		"vows","ceremony_girl":
			words("小京把研究尺放在你的账本旁。你们向前走了一小步，留出各自能转身的空间。",21)
			if River.state.wedding_step<3 and StarStory.state.wedding_phase==3:
				button("交换约定 · "+str(River.state.wedding_step+1)+"/3",func():
					read("星灯下的约定",["你：有想去的地方就告诉我。家不是把所有路收起来。","小京：遇到做不到的事，我们先说实话，再一起改计划。","阿禾合上留言册。两个人向亲友挥手，灯光照向温室门外的归路。"] [mini(2,int(River.state.wedding_step))],func(): StarCeremony.vows())
				)
			elif StarStory.state.wedding_phase==3: button("收好留言册，完成婚礼",func(): act(StarStory.finish_ceremony))
			else: words("先布置左研究桌，再到右桌确认点灯。")
			button("日常交谈与关系",func(): close_panel(); Events.interaction_requested.emit("xiaojing"))
		"venue_exit": button("返回农场（仪式进度保留）",func(): close_panel(); StarCeremony.leave())
		"star_core":
			words("星核室留下的是共享路线图。空车接人的记号一直延伸到这里，终点原本就是为回程充能。你要把哪句话先留给下一班？",21)
			for choice in ["water","records"]:
				button({"water":"先保清水与居民归路","records":"公开记录与共同检修"}[choice],func(): act(func(): return River.core(choice)))
		"forge":
			words("周砚的分流器：需要本轮实际加工铁锭2，再交铁锭2、晶石2、木4。")
			button("亲手装配可复核的分流器",func(): act(River.prototype))
		"council":
			words("林芽留出粮食车位，周砚写明每次检修的边界，阿禾把不同意见原样装订。接下来如何安排？\n"+ChapterTwo.branch_line(),21)
			if River.state.policy=="":
				for value in ["water","rotation","commons"]:
					button({"water":"清水与农田优先","rotation":"轮换检修，公开时刻表","commons":"设公共档案与共享工具"}[value],func(): act(func(): return River.choose_policy(value)))
			elif not River.has("closing_scene"):
				button("等第一班车回村，完成交接",func(): read("山谷深处的回声 · 终章","林芽数过种袋，周砚让下一班再核一遍阀门，阿禾把空白页放在最上面。没有人替整座山谷保证永远平安，他们终于学会把需要停下来的时候写清楚。\n远途信使带来一只空邮袋，袋底有另一座小镇的回执。第三章：星河之外。",func(): River.end_chapter()))
			button("每周协作便条（麦4木4）",func(): act(River.weekly))
		_:
			if context.begins_with("probe:"):
				var id := context.trim_prefix("probe:")
				var entry: Dictionary=River.data.points[id]
				words(entry.title+"：把这一处的刻度抄在自己的记录里。")
				button("实地测量并记下",func(): act(func(): return probe(id)))
			else: build_daily()
	button("收起",close_panel)
func probe(id: String) -> bool:
	var entry: Dictionary=River.data.points[id]
	if GameState.location!=entry.area or StarStory.game.player.global_position.distance_to(Vector2(entry.position[0],entry.position[1]))>64: return false
	River.memory_step(entry.memory,entry.step);return true
func build_daily() -> void:
	words("星河之约 · 温室档案",24)
	var q := ChapterTwo.current()
	if not q.is_empty(): words(q.title+"\n"+q.description)
	button("查看第二章当前任务",func(): close_panel(); Events.interaction_requested.emit("mine:journal"))
	if Xiaojing.state.married:
		for id in ["seed_collab","outing"]:
			button("婚后计划 · "+{"seed_collab":"两种留种试验","outing":"地下水脉共同外出"}[id],func(): act(func(): return River.begin_post(id)))
		words("当前项目："+{"":"尚未接取","seed_collab":"新收小麦与土豆，再回温室","outing":"重访40层以上记录，再到茶座交换见闻"}[River.state.post])
		button("记录项目成果",func(): act(River.finish_post))
		button("季末节日，交换下一季的计划",func(): act(River.festival))
		if GameClock.day-int(Xiaojing.state.wedding_day)>=520 and "day520" not in Xiaojing.state.post_events:
			button("婚后520日最终回信",func(): read("最后的回信",StarStory.data.post_events.day520.text,func(): Xiaojing.post_event("day520")))
	button("进入星光温室礼堂",func(): close_panel(); StarCeremony.enter())
	if GameState.location=="greenhouse": button("返回农场",func(): close_panel(); StarStory.game.change_location("farm",Vector2(1360,816)))
