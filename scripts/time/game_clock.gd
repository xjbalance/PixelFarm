extends Node
## 游戏一天 06:00—24:00；浇过水的作物只在 day_advanced 时成长一次。
signal changed
signal day_advanced
var day: int = 1
var minutes: float = 360.0
var running: bool = true
const MINUTES_PER_SECOND: float = 2.0

func _process(delta: float) -> void:
	if not running or GameState.modal:
		return
	var old_minute := int(minutes)
	minutes += delta * MINUTES_PER_SECOND
	if minutes >= 1440.0:
		next_day()
	elif int(minutes) != old_minute:
		changed.emit()

func next_day() -> void:
	day += 1
	minutes = 360.0
	GameState.rest()
	day_advanced.emit()
	changed.emit()
	Events.notice.emit("早安！第 %d 天开始了，记得给作物浇水。" % day)

func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]
