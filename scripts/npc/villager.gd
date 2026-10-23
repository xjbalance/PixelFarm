extends CharacterBody2D
## 对话从 JSON 加载，为后续好感度、日程和任务保留独立 NPC 节点。
var lines: Array = []
var station := Vector2.INF
var route := PackedVector2Array()
var cursor: int = 0
var needs_route: bool = false
var stalled: float = 0
var retries: int = 0
var previous := Vector2.ZERO
var animation_time: float = 0
var speaker: String = "林芽 · 种子收集师"
@export var person_id: String = "linya"

func _ready() -> void:
	add_to_group("interactables")
	if person_id == "xiaojing": add_to_group("xiaojing")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/dialogue/linya.json"))
	if data is Dictionary:
		lines = data.get("lines", [])

func interact() -> void:
	if person_id == "xiaojing":
		Events.interaction_requested.emit("xiaojing")
		return
	if (StarStory.has("proposal") and person_id not in StarStory.state.invited) or StarTrials.active("joint") or LegendTrials.active("joint"):
		Events.interaction_requested.emit("star:person:"+person_id)
		return
	if River.needs_talk(person_id):
		Events.interaction_requested.emit("river:talk:"+person_id)
		return
	if person_id == "linya": FarmProgress.talk()
	if Story.stage == 0 and person_id == "linya":
		Events.dialogue_requested.emit(speaker,["屋东的信箱里有你姨婆留的信。先看看吧，那是写给你的。","我就在这里，不着急。种子摊和田地都等着你。"])
	else: Story.request(person_id)

func prompt() -> String:
	return "与小京聊聊" if person_id == "xiaojing" else "与%s聊聊" % Story.data.people[person_id].name

func set_station(point: Vector2) -> void:
	if station == point: return
	station = point
	needs_route = true
	retries = 0

func _physics_process(delta: float) -> void:
	if GameState.modal or not GameClock.running or not is_visible_in_tree():
		velocity = Vector2.ZERO
		return
	if needs_route:
		route = VillagerNavigation.route(self,station)
		cursor = 0
		needs_route = false
		stalled = 0
	while cursor < route.size() and global_position.distance_to(route[cursor]) < 2: cursor += 1
	if cursor >= route.size():
		velocity = Vector2.ZERO
		return
	var offset := route[cursor]-global_position
	velocity = offset.normalized()*minf(48,offset.length()/delta)
	move_and_slide()
	if global_position.distance_to(previous) < 0.1: stalled += delta
	else: stalled = 0
	previous = global_position
	if stalled > 0.8:
		retries += 1
		needs_route = retries < 3
		if not needs_route: route.clear()
	animation_time += delta
	# 原有 NPC 只有单张站姿，整数像素的步幅表现复用素材。
	get_node("Sprite2D").position.y = -18+int(sin(animation_time*10))

func reset_station() -> void:
	# 读档按日期、建设与时段重建日程；不保存一条可能已经失效的路线。
	route.clear()
	needs_route = true
	retries = 0
