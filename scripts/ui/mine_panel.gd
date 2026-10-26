extends PanelContainer
## 原生触点与滚动复用现有 UI；阅读完成、确认建造和队列领取分别提交。
var content: VBoxContainer
var context: String = "journal"
var pending := Callable()
var story_title: String = ""
var story_text: String = ""
var reading: bool = false

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var layout := VBoxContainer.new()
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := FarmUIStyle.label("星辉矿脉 · 山谷深处的回声",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(layout,refresh)
	var scroll := ScrollContainer.new()
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)

func words(text: String, size: int = 18) -> void:
	var label := FarmUIStyle.label(text,size,FarmUIStyle.TITLE if size>=22 else FarmUIStyle.TEXT)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func button(text: String, callback: Callable) -> Button:
	var result := FarmUIStyle.button(text,callback,160)
	if text.begins_with("最终确认") or text.begins_with("取消本轮试炼"):
		result.add_theme_stylebox_override("normal",FarmUIStyle.surface("danger"))
	content.add_child(result)
	return result

func read(title: String, text: String, callback: Callable) -> void:
	story_title=title
	story_text=text
	pending=callback
	reading=true

func open_panel(id: String = "journal") -> void:
	if GameState.modal: return
	context=id
	reading=false
	pending=Callable()
	if id=="transport":
		if Story.stage<8:
			read("尚未展开的运输单","先和大家走完河水带走的名字这一章。旧运输单会在风车东侧等你。",Callable())
		else:
			read("风车里的旧运输单","纸上把矿石订单划去，改成空车接人。背面画着村庄东北的岩壁：原来封闭矿道也接着这条运输线。\n"+ChapterTwo.branch_line(),func():
				if MineState.near_service("transport"): ChapterTwo.record("transport")
			)
	elif id=="entrance" and "entrance" not in ChapterTwo.completed:
		read("封矿牌背面","封闭原因不是矿物枯竭。刻痕写着洪水、重车和三个人的值班名。入口仍有稳定支架，先从第一段矿道调查。",func():
			if MineState.near_service("entrance") and "transport" in ChapterTwo.completed: ChapterTwo.record("entrance")
		)
	elif id.begins_with("talk:"):
		var person := id.trim_prefix("talk:")
		read("旧事的另一面 · "+Story.data.people[person].name,ChapterTwo.TALKS[person]+"\n"+ChapterTwo.branch_line(),func():
			if near_person(person): ChapterTwo.record(id)
		)
	elif MineState.placements.has(id):
		var entry: Dictionary=MineState.placements[id]
		if entry.kind=="note":
			read(entry.title,entry.text,func():
				if MineState.near_id(id):
					ChapterTwo.record(entry.fact)
					Events.world_inspected.emit(id)
					StarTrials.observe_note(id)
			)
		elif entry.kind=="memory":
			var text := "这张副页记着河水与星辉晶石的对照。小京还未和你分享这些笔记。"
			for memory in Xiaojing.data.memories:
				if memory.id==entry.memory and Xiaojing.state.unlocked:
					text=memory.text+"\n\n"+{"b_memory":"小京在副页上画了一条高出水面的退路，旁边留着两种脚印。她没有写‘跟着我’，只写‘各自确认好出口，再一起出发’。河岸的旧约定在这里有了刻度。","c_memory":"晶石底座夹着两份不同的测量计划。小京在自己的归期旁留出一个空格：不是要你跟她走同一条路，而是回来后可以交换发现。你把风车簿上的水位抄在空格外。"}[id]
			read(entry.title,text,func(): MineState.memory_at(id))
	GameState.set_modal(true)
	show()
	refresh()

func near_person(id: String) -> bool:
	if not is_instance_valid(MineState.game): return false
	for person in get_tree().get_nodes_in_group("interactables"):
		if "person_id" in person and person.person_id==id and person.is_visible_in_tree():
			if person.global_position.distance_to(MineState.game.player.global_position)<=60: return true
	return false

func finish_reading() -> void:
	var callback := pending
	pending=Callable()
	reading=false
	if callback.is_valid(): callback.call()
	context="entrance" if context=="entrance" else "journal"
	refresh()

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if reading:
		words(story_title,23)
		words(story_text,21)
		button("读完并记下",finish_reading)
		button("稍后再读",close_panel)
		return
	if context=="forge": build_forge()
	elif context=="entrance":
		words("入口已加固。矿道内按一次采一次；体力不足时沿原路或阶梯返回地面。")
		button("进入废弃矿道",func(): close_panel(); Events.interaction_requested.emit("mine:enter"))
		if Xiaojing.state.trial.get("id","")=="cave":
			words("矿道试炼：同日探索20格、采四处矿、抵达地下水脉并返回；保留20体力，累计采矿不超过90体力。")
			button("备小麦2 · 开始本轮考察",func(): MineState.start_expedition(); refresh())
		if MineState.diamond_access():
			words("高级勘探补给：小麦8、木8、铁锭1、星纹合金1。只刷新高级矿脉，箱子与机关不重置。")
			button("交付补给 · 勘探新矿脉",func(): MineState.new_survey(); refresh())
	elif context in ["rail_west","rail_east"]:
		words("枕木腐朽，需要木6、石4、铜矿2。修复后还要扳动道岔指向东，两边的手柄都能重试。")
		button("确认修复 · 交付上述材料",func():
			if not MineState.repair_track(context): Events.notice.emit("材料不足或已经修好，没有再次扣费。")
			close_panel()
		)
	elif context=="discussion" and "discussion" in ChapterTwo.completed:
		button("后续开放讨论与交接",func(): close_panel(); Events.interaction_requested.emit("river:council"))
		build_journal()
	elif context=="discussion":
		words("阿禾把三份记录摊在告示板前。林芽先写下农产品车位，周砚留出水闸检修时间。\n"+ChapterTwo.branch_line())
		if ChapterTwo.completed.size()==7:
			for choice in ["rotation","reserve","study"]:
				button({"rotation":"轮换值班，公开运量","reserve":"先保留用水和农产车位","study":"先测量深层支线，再扩大开采"}[choice],func(): ChapterTwo.finish_discussion(choice); refresh())
		else: words("先完成矿道手记中的调查。已选规则不会封锁其他发展方向。")
	else: build_journal()
	button("收起",close_panel)

func costs(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for id in required: parts.append("%s%d/%d" % [Catalog.item_name(id),Inventory.count(id),int(required[id])])
	return " · ".join(parts)

func build_forge() -> void:
	button("周砚 · 住宅改建",func(): close_panel(); Events.interaction_requested.emit("housing:upgrade"))
	button("第二章分流器装配",func(): close_panel(); Events.interaction_requested.emit("river:forge"))
	button("深渊护具升级与勘探计划",func(): close_panel(); Events.interaction_requested.emit("abyss:forge"))
	words("周砚的矿物工台 · "+{1:"普通镐",2:"强化镐",3:"星纹镐"}[int(MineState.state.tool)],23)
	if not MineState.state.furnace:
		words("完成第一段矿道修复后可建熔炼炉。石12、木8、"+DiamondPayments.text(120)+"；确认时一次扣除。")
		button("建造熔炼炉",func():
			DiamondPayments.request(self,120,func():
				if not MineState.build_furnace(): Events.notice.emit("先完成修轨并准备所需材料。")
				refresh()
			)
		)
		return
	if MineState.state.tool<3:
		var upgrade: Dictionary=MineState.data.upgrades[str(int(MineState.state.tool)+1)]
		words(upgrade.name+" · "+costs(upgrade.required)+" · "+DiamondPayments.text(int(upgrade.coins)))
		button("确认升级镐",func():
			DiamondPayments.request(self,int(upgrade.coins),func():
				if not MineState.upgrade_tool(): Events.notice.emit("工具升级材料或金币不足。")
				refresh()
			)
		)
	words("加工每批次日完成，最多4笔队列；满包时保留成品等待领取。")
	for id in MineState.data.recipes:
		var recipe: Dictionary=MineState.data.recipes[id]
		words(recipe.name+" · "+costs(recipe.required)+" · 镐等级%d" % recipe.level,16)
		var row := HBoxContainer.new()
		content.add_child(row)
		for batches in [1,5]:
			row.add_child(FarmUIStyle.button("加工%d批" % batches,func():
				if not MineState.enqueue(id,batches): Events.notice.emit("材料、工具、矿区进度或队列容量不满足；没有扣费。")
				refresh()
			,180))
	for job in MineState.state.queue:
		var ready: bool=GameClock.day>=int(job.ready_day)
		var claim := button("领取%s ×%d · %s" % [MineState.data.recipes[job.recipe].name,job.batches,"已完成" if ready else "第%d天完成" % job.ready_day],func():
			if not MineState.claim_job(int(job.id)): Events.notice.emit("成品尚未完成，或背包已满。队列已保留。")
			refresh()
		)
		claim.disabled=not ready
	if MineState.diamond_access():
		words("高阶实地考察委托：新采三处高级矿脉，间隔三日，交土豆12、小麦12、木20，获得钻石5。",16)
		button("提交实地考察委托",func():
			if not MineState.complete_commission(): Events.notice.emit("考察记录、间隔、材料或容量不满足，没有扣费。")
			refresh()
		)

func build_journal() -> void:
	if Story.stage<8: words("先完成第一章。风车东侧的旧运输单会打开第二章。")
	else:
		var current := ChapterTwo.current()
		words("山谷深处的回声",23)
		words(ChapterTwo.branch_line())
		if current.is_empty(): words("第二章已完成。远途信使的邮袋里有另一座小镇的回执；第三章的路尚未展开。")
		else: words(current.title+"\n"+current.description+"\n"+ChapterTwo.progress(current),21)
		button("检查任务并领取待结算奖励",func(): ChapterTwo.refresh(); refresh())
	for quest in ChapterTwo.definitions: words(quest.title+" · "+ChapterTwo.progress(quest),16)
	words("镐："+{1:"普通",2:"强化",3:"星纹"}[int(MineState.state.tool)]+" · 钻石%d / 1314" % Xiaojing.state.diamonds)
	words("入口：河湾村东北。加工与工具：周砚木作坊南侧。开会：共建板东侧的矿道告示板。",16)

func close_panel() -> void:
	DiamondPayments.cancel(self)
	pending=Callable()
	hide()
	GameState.set_modal(false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
