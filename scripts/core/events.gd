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

# 成功事务的只读事实；节日/个人任务订阅，不在加载时补发。
signal farm_committed(kind: String, cell: Vector2i, crop: String, plant_serial: int)
signal fishing_landed(site: String, species: String, serial: int, day: int)
signal aquaculture_harvested(species: String, quantity: int, total: int, day: int)
signal animal_produced(animal_id: String, item: String, day: int)
signal dish_cooked(recipe: String, batches: int, total: int, day: int)
signal processing_claimed(source: String, recipe: String, job_id: int, batches: int)
signal world_inspected(event_id: String)
signal berry_gathered(day: int, quantity: int)
