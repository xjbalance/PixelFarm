extends Node
## 系统之间通过信号传递事件，不直接操作别的系统节点。
signal notice(text: String)
signal action_requested
signal dialogue_requested(speaker: String, lines: Array)
signal interaction_requested(kind: String)
signal farm_action(kind: String)
signal tool_changed
signal modal_changed(active: bool)
signal resource_hit(depleted: bool)
signal progress_committed
signal story_dialogue_requested(id: String)
signal location_changed(id: String)
signal farm_effect(position: Vector2, kind: String)
signal navigation_changed
