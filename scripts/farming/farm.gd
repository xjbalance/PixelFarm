extends Node2D
## 土地是可序列化数据；绘制与操作规则独立于 TileMapLayer。
signal changed
const BOUNDS := Rect2i(17, 16, 10, 6)
const IRRIGATION := Rect2i(17,16,4,3)
var CROP_TEXTURE = load("res://assets/crops/crops.png")
var SOIL_DRY: Texture2D=preload("res://assets/world_scheme_c/derived/soil_dry.png")
var SOIL_WET: Texture2D=preload("res://assets/world_scheme_c/derived/soil_wet.png")
var plots: Dictionary = {}
var last_growth_day: int = 1
var highlighted := Vector2i(-1, -1)
var committing: bool = false

func _ready() -> void:
	last_growth_day=GameClock.day
	GameClock.day_advanced.connect(advance_day)
	VillageProjects.irrigation_requested.connect(func():
		for plot in plots.values(): plot.watered = true
		changed.emit()
		queue_redraw()
	)
	FarmProgress.upgrade_built.connect(func(id: String):
		if id == "irrigation": apply_irrigation()
	)

func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func can_use_tool(cell: Vector2i, tool: String, notify: bool = true) -> bool:
	var reason := tool_error(cell,tool)
	if reason!="" and notify: Events.notice.emit(reason)
	return reason==""

func tool_error(cell: Vector2i, tool: String) -> String:
	if not BOUNDS.has_point(cell): return "在小屋前的浅色土地上开垦吧。"
	var plot: Dictionary=plots.get(key(cell),{})
	if tool=="hoe":
		if not plot.is_empty(): return "这块土地已翻好，可以播种了。"
		var landscape_error: String=Territory.farm_plot_error(cell)
		if landscape_error!="": return landscape_error
	elif tool.ends_with("_seed"):
		var crop_id:=tool.trim_suffix("_seed")
		if plot.is_empty() or not str(plot.get("crop","")).is_empty(): return "种子需要播在空的、翻过的土地上。"
		if not Catalog.crops.has(crop_id) or Inventory.count(tool)<1: return "种子用完了，去林芽的种子摊看看吧。"
		if not Catalog.crop_grows(crop_id): return "冬季露天土壤不适合这种作物。种子已保留，可以种耐寒小麦。"
	elif tool=="water":
		if plot.is_empty() or bool(plot.get("watered",false)): return "选择翻过的、还未浇水的土地。"
	elif tool=="hand":
		var crop_id: String=str(plot.get("crop",""))
		if crop_id.is_empty() or not is_mature(plot): return "每天浇水，等作物成熟再收获。"
		if Inventory.count(crop_id)>=Inventory.MAX_STACK: return "背包已满，先出售一些收获吧。"
	else: return "这种工具不能在农田使用。"
	if GameState.stamina<Kitchen.energy_cost(2 if tool=="hoe" else 1):
		return "体力不足：去屋东椅歇脚，或在背包吃食物。20:00后可睡。"
	return ""

func use_tool(cell: Vector2i, tool: String) -> bool:
	# 生效帧调用的同步事务；展示/库存/体力信号重入不能再提交另一笔农活。
	if committing: return false
	committing=true
	var success:=_commit_tool(cell,tool)
	committing=false
	return success

func _commit_tool(cell: Vector2i, tool: String) -> bool:
	if not can_use_tool(cell,tool): return false
	var id:=key(cell)
	var plot: Dictionary=plots.get(id,{})
	var crop: String=tool.trim_suffix("_seed") if tool.ends_with("_seed") else str(plot.get("crop",""))
	var required: Dictionary={tool:1} if tool.ends_with("_seed") else {}
	var rewards: Dictionary={crop:1} if tool=="hand" else {}
	# 沿用背包的整笔容量/数量验证；先写完农田、物品、体力，再通知观察者。
	var inventory_change:=Inventory.preview_exchange(required,rewards,0)
	if inventory_change.is_empty(): return false
	GameState.stamina-=Kitchen.energy_cost(2 if tool=="hoe" else 1)
	if not required.is_empty() or not rewards.is_empty(): Inventory.items=inventory_change.items
	var action: String=""
	if tool=="hoe":
		plots[id]={"crop":"","days":0,"watered":GameWeather.is_rainy() or (FarmProgress.has_upgrade("irrigation") and IRRIGATION.has_point(cell))}
		Territory.on_farm_plot_created(cell)
		action="翻土"
	elif tool.ends_with("_seed"):
		plot.crop=crop;plot.days=0;action="播种"
	elif tool=="water":
		plot.watered=true;action="浇水"
	elif tool=="hand":
		plot.crop="";plot.days=0;action="收获"
	Xiaojing.on_farm_commit(action,cell,crop)
	Events.farm_committed.emit(action,cell,crop,int(Xiaojing.state.plant_serial))
	GameState.changed.emit()
	if not required.is_empty() or not rewards.is_empty(): Inventory.changed.emit()
	changed.emit()
	Events.farm_action.emit(action)
	Events.farm_effect.emit(Vector2(cell)*32+Vector2(16,16),action)
	if action=="收获": Events.notice.emit("收获了 1 个%s！" % Catalog.item_name(crop))
	queue_redraw()
	return true

func is_mature(plot: Dictionary) -> bool:
	var crop_id: String = str(plot.get("crop", ""))
	return Catalog.crops.has(crop_id) and int(plot.get("days", 0)) >= Catalog.crops[crop_id].growth_days

func advance_day() -> void:
	if last_growth_day==GameClock.day: return
	last_growth_day=GameClock.day
	for plot in plots.values():
		if bool(plot["watered"]) and not str(plot["crop"]).is_empty() and Catalog.crop_grows(plot["crop"],maxi(1,GameClock.day-1)):
			var maximum: int = Catalog.crops[plot["crop"]].growth_days
			plot["days"] = mini(int(plot["days"]) + 1, maximum)
		plot["watered"] = GameWeather.is_rainy()
	apply_irrigation()
	changed.emit()
	queue_redraw()

func apply_irrigation() -> void:
	if not FarmProgress.has_upgrade("irrigation"): return
	for x in range(IRRIGATION.position.x,IRRIGATION.end.x):
		for y in range(IRRIGATION.position.y,IRRIGATION.end.y):
			var id := key(Vector2i(x,y))
			if plots.has(id): plots[id].watered = true
	queue_redraw()

func highlight(cell: Vector2i) -> void:
	if highlighted != cell:
		highlighted = cell
		queue_redraw()

func _draw() -> void:
	if FarmProgress.has_upgrade("irrigation"):
		draw_rect(Rect2(Vector2(IRRIGATION.position)*32-Vector2(3,3),Vector2(IRRIGATION.size)*32+Vector2(6,6)),Color("7dbdb4"),false,3)
	for id in plots:
		var parts: PackedStringArray = id.split(",")
		var origin := Vector2(int(parts[0]), int(parts[1])) * 32.0
		var plot: Dictionary = plots[id]
		var wet: bool = plot["watered"]
		draw_texture(SOIL_WET if wet else SOIL_DRY,origin)
		var crop_id: String = plot["crop"]
		if not crop_id.is_empty():
			var crop: CropDefinition = Catalog.crops[crop_id]
			var stage: int = mini(int(float(plot["days"]) / crop.growth_days * (crop.stages - 1)), crop.stages - 1)
			draw_texture_rect_region(CROP_TEXTURE, Rect2(origin + Vector2(0, -9), Vector2(32, 40)), Rect2(stage * 32, crop.atlas_row * 40, 32, 40))
		if wet:
			draw_rect(Rect2(origin + Vector2(24, 24), Vector2(4, 4)), Color("91c8da"))
	if BOUNDS.has_point(highlighted):
		draw_rect(Rect2(Vector2(highlighted) * 32 + Vector2.ONE, Vector2(30, 30)), Color("fff2b4"), false, 2)
