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
const NAMES := {"farm":"农场", "home":"你的家", "village":"河湾村","mine_a":"废弃矿道","mine_b":"地下水脉","mine_c":"晶石洞窟","abyss":"深渊勘探","greenhouse":"星光温室"}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/story/wind_lantern.json"))

func chapter() -> Dictionary:
	var result: Dictionary = data.chapters[stage].duplicate(true)
	if stage in [1,2] and GameClock.minutes >= 1080:
		result.location = "village"
		result.target = [704,592] if VillageProjects.has_project("arbor") else [610,442]
		result.goal += " 林芽傍晚在河湾村广场或茶座。"
	if stage == 8:
		var task := Letters.next_task()
		if not task.is_empty(): result.goal = task.description
	return result

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
	if stage==8 and ChapterTwo.completed.size()>=6 and actor in ["linya","zhou","ahe"] and not ChapterTwo.knows("talk:"+actor):
		Events.interaction_requested.emit("mine:talk:"+actor)
		return
	var scene := ""
	match actor:
		"mail": scene = "letter" if stage == 0 else ("review_letter" if Letters.legacy_review else "letter_repeat")
		"linya":
			if stage == 1: scene = "welcome"
			elif stage == 2 and has_items({"carrot":3}): scene = "harvest"
			else: scene = "linya_daily"
		"zhou": scene = "carpenter" if stage == 3 else "zhou_daily"
		"bridge":
			if stage == 4 and has_items({"wood":8,"stone":6}): scene = "bridge"
			else: scene = "bridge_hint"
		"mill": scene = "mill" if stage == 5 else "mill_repeat"
		"ahe": scene = "guestbook" if stage >= 4 and not Letters.knows("guestbook") else ("supper" if stage == 6 and VillageProjects.all_built() else "ahe_daily")
		"lantern": scene = "future" if stage == 8 and Letters.direction == "" else ("festival" if stage == 7 and GameClock.minutes >= 1080 else "lantern_hint")
		"bench": scene = "bench"
		"well": scene = "water_help" if VillageProjects.has_project("well") and "well" in seen else "well"
		_: scene = actor
	if data.scenes.has(scene) and not Letters.can_finish(data.scenes[scene]): scene = "investigation_hint"
	Events.story_dialogue_requested.emit(scene)

func scene_data(id: String) -> Dictionary:
	if data.scenes.has(id):
		var result: Dictionary = data.scenes[id].duplicate(true)
		if id=="bench" and (stage!=7 or "bench" in seen or GameClock.minutes>=1080):
			result.choices=result.choices.filter(func(option: Dictionary): return option.id!="wait")
			result.lines[0].text="河水慢慢经过，茶屋飘来麦香。这里可以歇脚喝茶，今天的事仍按自己的节奏继续。"
		if id == "bench" and VillageProjects.has_project("arbor"):
			result.choices.insert(0,{"id":"tea","text":"喝茶 · 恢复40体力","reply":"藤叶把阳光筛成小块。阿禾给你续上茶，今天还有很长，也可以慢慢来。"})
		return result
	var who := "旁白"
	var portrait := "letter"
	var text: Array = []
	match id:
		"investigation_hint":
			text = [chapter().goal,"线索会记进手记。看完调查点的最后一句，再回来聊聊。"]
		"letter_repeat": text = ["信与地图收在小屋的木盒里。",chapter().goal]
		"bridge_hint": text = ["桥已通行。检查簿挂在桥头，水位线每年都要再看。" if stage >= 5 else chapter().goal]
		"mill_repeat": text = ["货运簿记录着东岸三户人的行李。旁边的货箱里，还有未寄出的便条。"]
		"lantern_hint": text = ["18:00 后再来，或在长椅等到傍晚。" if stage == 7 else ("灯还亮着。下一步先做"+Letters.DIRECTIONS.get(Letters.direction,"邻里商量的事")+"，别的方向也随时能开始。" if stage == 8 else "空风灯架上留着去年没解开的线结。")]
		"bench_late": text = ["已经到傍晚了。广场的风灯架就在旁边。"]
		"linya_daily":
			who = "林芽"; portrait = "linya"
			text = [chapter().goal,"我想恢复收菜的车铃，也想让离开的人有一张回程订单。"]
			if VillageProjects.has_project("cooperative"): text = ["共仓今天有人留种、有人取种。每袋都写着名字，种子仍按八折卖。","先试一张小订单吧。" if Letters.direction == "trade" else "有空种点新东西。别的方向忙完了，贸易这页也给你留着。"]
		"zhou_daily":
			who = "周砚"; portrait = "zhou"
			text = [chapter().goal,"父亲留下的不是一座永远不会坏的桥，是提醒后来人检查的记号。"]
			if stage >= 5: text = ["今天又量过桥脚，水位还低于新刻线。过桥慢一点。","要沿河调查，我替你看水位。" if Letters.direction == "explore" else "有人推着种子车过桥了。修好的东西，得让人真正用起来。"]
		"ahe_daily":
			who = "阿禾"; portrait = "ahe"
			text = [chapter().goal,"留言册里写过离开的原因，也该留一页写回来的打算。"]
			if VillageProjects.has_project("well"): text.append("午间我去井边洗杯子。今天不用再借谁家的水了。")
			if VillageProjects.has_project("arbor"): text.append("傍晚在公共茶座等你。" if Letters.direction == "life" else "忙完就来茶座，值日表还留着空格。")
		_: text = ["河水经过桥下，纸上的名字留了下来。"]
	if id in ["linya_daily","zhou_daily","ahe_daily"]:
		text.append(SeasonalDialogue.line(portrait))
	var lines: Array = []
	for line in text: lines.append({"who":who,"portrait":portrait,"text":line})
	return {"title":who,"lines":lines}

func complete(id: String, choice: String = "") -> bool:
	if not data.scenes.has(id):
		if id in ["linya_daily","zhou_daily","ahe_daily"]: Letters.record("talk:"+id.trim_suffix("_daily"))
		return true
	var scene: Dictionary = scene_data(id)
	if scene.has("stage") and int(scene.stage) != stage: return false
	if stage < int(scene.get("min_stage",0)): return false
	if not Letters.can_finish(scene):
		Events.notice.emit("先完成调查和交流，线索会保存在手记中。")
		return false
	if id == "future" and (stage != 8 or Letters.direction != ""): return false
	if id == "supper" and not VillageProjects.all_built(): return false
	if id == "festival" and GameClock.minutes < 1080: return false
	var choices: Array = scene.get("choices",[])
	if not choices.is_empty():
		var valid_choice := false
		for option in choices:
			if option.id == choice: valid_choice = true
		if not valid_choice: return false
	if scene.has("stage") or id == "future":
		# 回调期间仍可能读档；提交前再次校验阶段、容量与数量，不能跳章或重复拿奖励。
		var reward: Dictionary = {"trade":{"carrot_seed":3},"explore":{"wheat_seed":6},"life":{"potato_seed":3}}.get(choice,{}) if id in ["festival","future"] else {}
		if not Inventory.exchange(scene.get("requirements",{}),reward,int(scene.get("coins",0))):
			Events.notice.emit("物品或金币空间不满足，整理后再来，进度不会丢失。")
			return false
		if scene.has("next"): stage = int(scene.next)
		if id == "letter": motive = choice
		if id in ["festival","future"]:
			Letters.direction = choice
			if id == "festival": lantern = choice
		if id not in seen: seen.append(id)
		Playtest.record("task",{"id":"chapter1:"+id})
		chapter_completed.emit(stage)
		Events.notice.emit("手记已更新 · "+chapter().title)
	elif id == "bench" and choice == "wait":
		if stage!=7 or "bench" in seen or GameClock.minutes>=1080: return false
		seen.append("bench")
		GameClock.minutes = 1080
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
	Letters.record("scene:"+id)
	if id in ["bridge_survey","repair_record","guestbook","cargo_note"]: Letters.record(id)
	if id == "cargo_note": Letters.record("cargo_departure" if choice == "ask_departure" else "cargo_name")
	if id == "water_help" and choice == "draw": Letters.record("water_help")
	if id == "supper": Letters.record("talk:ahe")
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
	if saved.get("lantern") not in (["memory","tomorrow","trade","explore","life"] if saved.stage == 8 else [""]): return false
	if not saved.get("seen") is Array or saved.seen.size() > data.scenes.size(): return false
	var unique := {}
	for id in saved.seen:
		if not id is String or not data.scenes.has(id) or unique.has(id): return false
		if data.scenes[id].has("next") and data.scenes[id].next > saved.stage: return false
		unique[id] = true
	for id in data.scenes:
		if data.scenes[id].has("next") and data.scenes[id].next <= saved.stage and not unique.has(id): return false
	return true
