class_name FarmSaveStore
extends RefCounted
## 写临时文件后重命名；保留上一次存档。先完整校验再修改运行状态。
const PATH: String = "user://farm_save.json"
const VERSION: int = 25

static func snapshot(game: Node) -> Dictionary:
	return {
		"appearance": Appearance.snapshot(),
		"tutorial": game.tutorial.snapshot(),
		"world_development": WorldDevelopment.snapshot(), "exploration": Exploration.snapshot(), "housing": Housing.snapshot(), "festival": Festival.snapshot(), "social": Social.snapshot(),
		"kitchen": Kitchen.snapshot(), "ecology": LakeEcology.snapshot(), "fishing": Fishing.snapshot(), "livestock": Livestock.snapshot(),
		"recovery": Recovery.snapshot(), "calendar": Calendar.snapshot(), "world_changes": WorldChanges.snapshot(),
		"version": VERSION, "location": GameState.location,
		"player": [game.player.position.x, game.player.position.y],
		"day": GameClock.day, "minutes": GameClock.minutes,
		"coins": Inventory.coins, "items": Inventory.items.duplicate(true),
		"stamina": GameState.stamina, "selected": GameState.selected,
		"control_mode": GameState.control_mode,
		"plots": game.farm.plots.duplicate(true),
		"progress": FarmProgress.snapshot(), "resources": game.resource_world.snapshot(),
		"story": Story.snapshot(),
		"letters": Letters.snapshot(), "xiaojing": Xiaojing.snapshot(),
		"mines": MineState.snapshot(), "chapter_two": ChapterTwo.snapshot(), "star_story": StarStory.snapshot(), "abyss": AbyssState.snapshot(), "legend": LegendState.snapshot(), "river": River.snapshot(),
		"aquaculture": Aquaculture.snapshot(),
		"village": VillageProjects.snapshot(),
		"journal": game.hud.completed.keys(), "muted": game.get_node("Audio").muted
	}

static func write(game: Node, path: String = PATH) -> bool:
	# 新开局外观尚未确认时不能让自动保存替换已有进度。
	if game.get("awaiting_character_choice")==true: return false
	# 农活生效事务的同步通知尚未结束时，不能把半份跨系统进度写入磁盘。
	if game.farm.committing or Housing.busy or game.resource_world.committing(): return false
	var data := snapshot(game)
	if not valid(data): return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		Events.notice.emit("保存失败：无法写入本地目录。")
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(path):
		# 从备份恢复后，不能用损坏的主档覆盖唯一有效的备份。
		var previous := JSON.new()
		var good: bool=previous.parse(FileAccess.get_file_as_string(path))==OK and valid(previous.data)
		if good:
			if FileAccess.file_exists(path+".bak"):
				if DirAccess.remove_absolute(path+".bak") != OK: return false
			if DirAccess.rename_absolute(path,path+".bak") != OK: return false
		elif DirAccess.rename_absolute(path,path+".corrupt") != OK: return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		if FileAccess.file_exists(path+".bak"):
			DirAccess.rename_absolute(path+".bak",path)
		return false
	Playtest.record("save",{"backup":FileAccess.file_exists(path+".bak")})
	return true

static func backup_before_new_game(path: String = PATH) -> bool:
	# 原字节另存，保留旧版结构与最后一份有效进度；已有备份永不覆盖。
	var exists: bool=false
	for source in [path,path+".bak"]:
		if not FileAccess.file_exists(source): continue
		exists=true
		var file:=FileAccess.open(source,FileAccess.READ)
		if file==null or file.get_length()>8388608: continue
		var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
		var parser:=JSON.new()
		if parser.parse(bytes.get_string_from_utf8())!=OK or not valid(parser.data): continue
		var target: String=path+".before_new_game.bak"
		var sequence: int=1
		while FileAccess.file_exists(target):
			target=path+".before_new_game.%d.bak" % sequence;sequence+=1
		var copy:=FileAccess.open(target,FileAccess.WRITE)
		if copy==null: return false
		copy.store_buffer(bytes);copy.flush();var error: Error=copy.get_error();copy.close()
		if error!=OK or FileAccess.get_file_as_bytes(target)!=bytes:
			DirAccess.remove_absolute(target);return false
		return true
	return not exists

static func read(path: String = PATH) -> Dictionary:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file == null or file.get_length() > 8388608: continue
		var parser := JSON.new()
		var error := parser.parse(file.get_as_text())
		file.close()
		if error != OK: continue
		var data := FarmSaveSchema.normalize(parser.data)
		if not data.is_empty():
			if candidate.ends_with(".bak"): Events.notice.emit("主存档损坏，已恢复上一次备份。")
			return data
	return {}

static func valid(data: Variant) -> bool:
	return not FarmSaveSchema.normalize(data).is_empty()

static func restore(game: Node, raw: Dictionary) -> bool:
	var data := FarmSaveSchema.normalize(raw)
	if data.is_empty(): return false
	GameState.restoring=true
	if game.has_method("cancel_character_creation"): game.cancel_character_creation(false)
	WorldChanges.restoring=true
	game.cancel_pending_save()
	while game.hud.close_active_panel(): pass
	game.touch_input.reset()
	game.auto_move.cancel()
	Appearance.restore(data.appearance)
	GameState.set_control_mode(data.control_mode, false)
	GameState.manual_tool = false
	Inventory.coins = int(data["coins"])
	Inventory.items.clear()
	for id in data["items"]: Inventory.items[id] = int(data["items"][id])
	GameClock.day = int(data["day"])
	GameClock.minutes = float(data["minutes"])
	game.tutorial.restore(data.tutorial)
	Festival.restore(data["festival"])
	Kitchen.restore(data["kitchen"])
	Fishing.restore(data["fishing"])
	Livestock.restore(data["livestock"])
	Recovery.restore(data["recovery"])
	Calendar.restore(data["calendar"])
	WorldChanges.restoring=true
	LakeEcology.restore(data["ecology"])
	FarmProgress.restore(data["progress"])
	Story.restore(data["story"])
	Letters.restore(data["letters"])
	Xiaojing.restore(data["xiaojing"])
	MineState.restore(data["mines"])
	ChapterTwo.restore(data["chapter_two"])
	StarStory.restore(data["star_story"])
	River.restore(data["river"])
	LegendState.restore(data["legend"])
	AbyssState.restore(data["abyss"])
	Aquaculture.restore(data["aquaculture"])
	VillageProjects.restore(data["village"])
	WorldDevelopment.restore(data["world_development"])
	Exploration.restore(data["exploration"])
	Housing.restore(data["housing"])
	Social.restore(data["social"])
	WorldChanges.restoring=false
	WorldChanges.restore(data["world_changes"])
	game.resource_world.restore(data["resources"])
	GameState.stamina = int(data["stamina"])
	GameState.selected = int(data["selected"])
	game.farm.plots = data["plots"].duplicate(true)
	game.farm.last_growth_day=GameClock.day
	for plot in game.farm.plots.values(): plot["days"] = int(plot["days"])
	game.farm.queue_redraw()
	game.hud.completed.clear()
	game.hud.refresh_farm_guide()
	for entry in data.get("journal",[]): game.hud.on_farm_action(entry)
	game.get_node("Audio").muted = data.get("muted",false)
	game.change_location(data["location"],Vector2(data["player"][0],data["player"][1]))
	game.call_deferred("recover_blocked_position")
	GameState.restoring=false
	# 恢复日结算中断时留下的到期工单；不重收材料，也不重放其他系统的跨天逻辑。
	if not Housing.state.construction.is_empty() and int(Housing.state.construction.ready_day)<=GameClock.day:
		Housing.settle_day()
	Inventory.changed.emit()
	GameClock.changed.emit()
	GameState.changed.emit()
	Events.tool_changed.emit()
	Playtest.loaded()
	return true
