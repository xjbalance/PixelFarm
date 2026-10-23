extends Node
## 剧情规则与对白表现分开；只在读完且条件仍成立时原子提交物品与章节进度。
signal changed
signal chapter_completed(stage: int)
var data: Dictionary = {}
var stage: int = 0
var motive: String = ""
var lantern: String = ""
var seen: Array[String] = []
var assisted_tools: bool = true
const SECRET_IDS := ["well","ribbon","post"]
const NAMES := {"farm":"风芽农场", "home":"你的家", "village":"河湾村"}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/wind_lantern.json"))

func chapter() -> Dictionary:
	return data.chapters[stage]

func has_items(requirements: Dictionary) -> bool:
	for item in requirements:
		if Inventory.count(item) < int(requirements[item]): return false
	return true

func requirement_text() -> String:
	var parts: Array[String] = []
	if stage == 6: parts.append("公共设施 %d/3" % VillageProjects.built.size())
	for item in chapter().get("requirements",{}):
		parts.append("%s %d/%d" % [Catalog.item_name(item),Inventory.count(item),chapter().requirements[item]])
	return " · ".join(parts)

func request(actor: String) -> void:
	var scene := ""
	match actor:
		"mail": scene = "letter" if stage == 0 else "letter_repeat"
		"linya":
			if stage == 1: scene = "welcome"
			elif stage == 2 and has_items({"carrot":3}): scene = "harvest"
			else: scene = "linya_daily"
		"zhou": scene = "carpenter" if stage == 3 else "zhou_daily"
		"bridge":
			if stage == 4 and has_items({"wood":8,"stone":6}): scene = "bridge"
			else: scene = "bridge_hint"
		"mill": scene = "mill" if stage == 5 else "mill_repeat"
		"ahe": scene = "supper" if stage == 6 and VillageProjects.all_built() and has_items({"wheat":2,"carrot":1}) else "ahe_daily"
		"lantern": scene = "festival" if stage == 7 and GameClock.minutes >= 1080 else "lantern_hint"
		"bench": scene = "bench"
		"well": scene = "water_help" if VillageProjects.has_project("well") and "well" in seen else "well"
		_: scene = actor
	Events.story_dialogue_requested.emit(scene)

func scene_data(id: String) -> Dictionary:
	if data.scenes.has(id):
		var result: Dictionary = data.scenes[id].duplicate(true)
		if id == "bench" and VillageProjects.has_project("arbor"):
			result.choices.insert(0,{"id":"tea","text":"喝茶 · 恢复40体力","reply":"藤叶把阳光筛成小块。阿禾给你续上茶，今天还有很长，也可以慢慢来。"})
		return result
	var who := "旁白"
	var portrait := "letter"
	var text: Array = []
	match id:
		"letter_repeat": text = ["信被你收在信箱里，封口那一行字还在：不必照着从前的样子。",chapter().goal]
		"bridge_hint": text = ["木桥已经修好，河的另一边不再遥远。" if stage >= 5 else ("周砚量好了桥脚。需要木材 8 份、石料 6 份，备齐后在这里一起动手。" if stage == 4 else "旧桥的木板松了。先去木作坊，听听周砚怎么说。")]
		"mill_repeat": text = ["记录簿静静躺在风车底下。最后一句话，你已经记得了：留一把空椅子，给还没到的人。"]
		"lantern_hint": text = ["风灯在等傍晚的第一缕风。18:00 后再来，或坐在旁边的长椅上等一等。" if stage == 7 else ("新种子袋在风里轻轻响。明年的春天，会有新的故事。" if lantern == "tomorrow" else "纸鸟转了半圈，灯下的长桌一直留着一把椅子。") if stage == 8 else "空空的风灯架上，留着去年没解开的线结。也许还能重新挂些什么。"]
		"bench_late": text = ["已经是傍晚了。长椅还带着一点白天的暖意，广场就在旁边。"]
		"linya_daily":
			who = "林芽"; portrait = "linya"
			if stage == 0: text = ["屋东的信箱里有你姨婆留的信。我没拆过——那是写给你的。","先安顿下来吧。我就在种子摊边，不着急。"]
			elif stage == 2: text = ["等三个胡萝卜成熟了，带来给我就好。每天浇一次水，回屋睡觉，两个生长日就能收。","味道不必和以前一模一样。这是你种的，就已经很好。"]
			elif stage == 8: text = ["昨天挂灯的时候，我终于没有在想“如果当年”。","那只纸鸟会和新的种子一起留下来。谢谢你没有催我们忘记。" if lantern == "memory" else "种子袋上有你的字。以后每个春天，我们都再加一行吧。"]
			elif GameWeather.is_rainy(): text = ["下雨了，田里的水我就放心啦。今天可以去村里走走。","我把种子袋搬到屋檐下了。雨能照顾土地，纸袋还得我们照顾。"]
			else: text = ["我想让这里重新热闹起来——你那天的话，我偷偷记住了。" if motive == "renew" else "你说想有个能回来的地方。种子也一样，收好了，来年就有家。","清晨的露水很重，午后再收种子，不容易发霉。" if GameClock.minutes < 720 else "今天的新种子都摆在摊上了。路过的时候，别忘了看看树影。"]
		"zhou_daily":
			who = "周砚"; portrait = "zhou"
			text = ["听林芽说起过你。木头可以慢慢修，人也一样。","先照顾好农场吧，有空再来坐坐。"] if stage < 3 else (["桥脚我又检查了一遍。只是习惯……这回我没忍住，也走过去看了看。","下次可以在桥边做个小台阶，给看河水的人坐。"] if stage >= 5 else ["木材要 8 份，石料要 6 份。备齐了，就在东边桥头找我。","这次的桥，会记得不止一个人的力气。"])
			if stage == 8: text = ["风灯昨晚响了一整夜。我没有觉得吵。","你选的旧纸鸟，我给它换了根结实的线。" if lantern == "memory" else "我想再做几个装种子的小木盒。新的事，总得有地方放。"]
		"ahe_daily":
			who = "阿禾"; portrait = "ahe"
			if stage == 6: text = ["共建板就在广场南边。水井、共仓、茶座，先做你觉得最需要的那一件。大家会出手艺和力气，你帮着备材料。","三件都做好了，再带麦子 2 份、胡萝卜 1 个来。我们吃一锅粥，商量接下来怎么让村庄更好。"]
			elif stage == 8: text = ["那把空椅子，昨晚被一只猫占了。也好，它也是后来的人。","风灯会办完了，饭还是要一天一天吃。累了就来这里坐会儿。"]
			else: text = ["你就是农场的新邻居？桌上有热水，自己倒。","大家总说等忙完再来。其实来这里，才是把一天好好忙完。"]
		_: text = ["风从河湾经过，日子还在慢慢往前。"]
	var lines: Array = []
	for line in text: lines.append({"who":who,"portrait":portrait,"text":line})
	return {"title":who,"lines":lines}

func complete(id: String, choice: String = "") -> bool:
	if not data.scenes.has(id): return true
	var scene: Dictionary = scene_data(id)
	if scene.has("stage") and int(scene.stage) != stage: return false
	if id == "supper" and not VillageProjects.all_built(): return false
	if id == "festival" and GameClock.minutes < 1080: return false
	var choices: Array = scene.get("choices",[])
	if not choices.is_empty():
		var valid_choice := false
		for option in choices:
			if option.id == choice: valid_choice = true
		if not valid_choice: return false
	if scene.has("stage"):
		# 回调期间仍可能读档；提交前再次校验阶段、容量与数量，不能跳章或重复拿奖励。
		if not Inventory.exchange(scene.get("requirements",{}),{},int(scene.get("coins",0))):
			Events.notice.emit("物品或金币空间不满足，整理后再来，进度不会丢失。")
			return false
		stage = int(scene.next)
		if id == "letter": motive = choice
		if id == "festival": lantern = choice
		if id not in seen: seen.append(id)
		chapter_completed.emit(stage)
		Events.notice.emit("手记已更新 · "+chapter().title)
	elif id == "bench" and choice == "wait":
		GameClock.minutes = maxf(GameClock.minutes,1080)
		GameClock.changed.emit()
	elif id == "bench" and choice == "tea":
		return VillageProjects.drink_tea()
	elif id == "water_help" and choice == "draw":
		if not VillageProjects.water_fields():
			Events.notice.emit("今天已经引过水了，明天再来吧。")
			return false
	elif id in SECRET_IDS and id not in seen:
		seen.append(id)
		Events.notice.emit("收进河谷手记 · "+scene.title)
	changed.emit()
	Events.progress_committed.emit()
	return true

func snapshot() -> Dictionary:
	return {"stage":stage,"motive":motive,"lantern":lantern,"seen":seen.duplicate(),"assisted_tools":assisted_tools}

func restore(saved: Dictionary) -> void:
	stage = int(saved.get("stage",0))
	motive = saved.get("motive","")
	lantern = saved.get("lantern","")
	assisted_tools = saved.get("assisted_tools",true)
	seen.clear()
	for id in saved.get("seen",[]): seen.append(id)
	changed.emit()

func validate(saved: Variant) -> bool:
	if not saved is Dictionary or not FarmSaveSchema.whole(saved.get("stage"),0,8): return false
	if not saved.get("assisted_tools") is bool: return false
	if saved.get("motive") not in ([""] if saved.stage == 0 else ["renew","home"]): return false
	if saved.get("lantern") not in (["memory","tomorrow"] if saved.stage == 8 else [""]): return false
	if not saved.get("seen") is Array or saved.seen.size() > data.scenes.size(): return false
	var unique := {}
	for id in saved.seen:
		if not id is String or not data.scenes.has(id) or unique.has(id): return false
		if data.scenes[id].has("next") and data.scenes[id].next > saved.stage: return false
		unique[id] = true
	for id in data.scenes:
		if data.scenes[id].has("next") and data.scenes[id].next <= saved.stage and not unique.has(id): return false
	return true
