extends Node
## 白天恢复与睡眠分离；没有跳日路径、离线恢复或无成本无限补给。
signal changed
const BENCH := Vector2(784,464)
const REST_LIMIT := 3
const SNACK_LIMIT := 3
const FOOD := {"carrot":8,"potato":12,"wheat":4}
var state: Dictionary={"day":1,"rests":0,"snacks":0}
var busy: bool=false
var game: Node
func _ready() -> void:
	state=defaults(GameClock.day)
	GameClock.day_advanced.connect(func(): state=defaults(GameClock.day);changed.emit())
func defaults(day: int = GameClock.day) -> Dictionary:
	return {"day":day,"rests":0,"snacks":0}
func snapshot() -> Dictionary:
	return state.duplicate(true) if state.day==GameClock.day else defaults()
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false;changed.emit()
func validate(raw: Variant, day: int) -> bool:
	if not raw is Dictionary or raw.size()!=3: return false
	return FarmSaveSchema.whole(raw.get("day"),1,day) and FarmSaveSchema.whole(raw.get("rests"),0,REST_LIMIT) and FarmSaveSchema.whole(raw.get("snacks"),0,SNACK_LIMIT)
func near_bench() -> bool:
	return is_instance_valid(game) and GameState.location=="farm" and game.player.global_position.distance_to(BENCH)<=54
func can_rest() -> bool:
	return not busy and not GameClock.settling and near_bench() and GameClock.minutes+20<1440 and int(snapshot().rests)<REST_LIMIT and GameState.stamina<GameState.max_stamina()
func rest(expected_day: int = GameClock.day, expected_used: int = -1) -> bool:
	if expected_day!=GameClock.day or not can_rest():
		Events.notice.emit("请到屋东休息椅边；每天可歇三次，午夜前留够20分钟，满体力不消耗次数。")
		return false
	var current := snapshot()
	if expected_used>=0 and expected_used!=current.rests: return false
	busy=true;state=current;state.rests+=1
	GameClock.minutes+=20
	GameState.stamina=mini(GameState.max_stamina(),GameState.stamina+15)
	GameClock.changed.emit();GameState.changed.emit();changed.emit();Events.progress_committed.emit()
	Events.notice.emit("在休息椅坐了20分钟，恢复15体力。今天还可休息%d次。" % (REST_LIMIT-int(state.rests)))
	busy=false
	return true
func eat_crop(id: String) -> bool:
	if busy or GameClock.settling or not FOOD.has(id) or GameState.stamina>=GameState.max_stamina() or int(snapshot().snacks)>=SNACK_LIMIT: return false
	busy=true
	if not Inventory.exchange({id:1},{},0): busy=false;return false
	state=snapshot();state.snacks+=1
	GameState.stamina=mini(GameState.max_stamina(),GameState.stamina+int(FOOD[id]))
	GameState.changed.emit();changed.emit();Events.progress_committed.emit()
	Events.notice.emit("吃了%s，恢复%d体力。今天还可吃%d份零食。" % [Catalog.item_name(id),FOOD[id],SNACK_LIMIT-int(state.snacks)])
	busy=false;return true
