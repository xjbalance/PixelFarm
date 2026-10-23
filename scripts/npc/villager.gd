extends StaticBody2D
## 对话从 JSON 加载，为后续好感度、日程和任务保留独立 NPC 节点。
var lines: Array = []
var speaker: String = "林芽 · 种子收集师"
@export var person_id: String = "linya"

func _ready() -> void:
	add_to_group("interactables")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/dialogue/linya.json"))
	if data is Dictionary:
		lines = data.get("lines", [])

func interact() -> void:
	if person_id == "linya": FarmProgress.talk()
	if Story.stage == 0 and person_id == "linya":
		Events.dialogue_requested.emit(speaker,["屋东的信箱里有你姨婆留的信。先看看吧，那是写给你的。","我就在这里，不着急。种子摊和田地都等着你。"])
	else: Story.request(person_id)

func prompt() -> String:
	return "与%s聊聊" % Story.data.people[person_id].name
