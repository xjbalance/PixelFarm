extends Node
## 玩家睡眠与午夜分别验证入口；只有此层能提交日结算。
signal changed
signal day_advanced
signal day_ending(reason: String)
var day: int = 1
var minutes: float = 360.0
var running: bool = true
var settling: bool = false
const MINUTES_PER_SECOND: float = 2.0
const TOO_EARLY := "现在还不是睡觉时间，晚上 20:00 后再休息吧。"

func _process(delta: float) -> void:
	# 已经过午夜的结算优先于暂停，不能靠同帧开菜单逃避；正常菜单仍不推进时间。
	if settling: return
	if minutes>=1440:
		_settle("fatigue")
		return
	if not running or GameState.modal: return
	var old_minute := int(minutes)
	minutes=minf(1440,minutes+maxf(0,delta)*MINUTES_PER_SECOND)
	if minutes>=1440: _settle("fatigue")
	elif int(minutes)!=old_minute: changed.emit()

func can_sleep(notify: bool = false) -> bool:
	var allowed: bool=not settling and minutes>=1200 and minutes<1440
	if not allowed and notify: Events.notice.emit(TOO_EARLY if minutes<1200 else "今天已结束，请稍候。")
	return allowed

func request_sleep(expected_day: int) -> bool:
	if expected_day!=day or not can_sleep(true): return false
	return _settle("sleep")

func next_day() -> bool:
	# 保留旧调用名，但它现在同样是受限制的主动睡眠，不能用于任意跳日。
	return request_sleep(day)

func _settle(reason: String) -> bool:
	if settling or day>=999999: return false
	if reason=="sleep" and not can_sleep(): return false
	if reason=="fatigue" and minutes<1440: return false
	if reason not in ["sleep","fatigue"]: return false
	settling=true
	day_ending.emit(reason)
	day+=1
	minutes=360
	GameState.stamina=ceili(GameState.max_stamina()*.6) if reason=="fatigue" else GameState.max_stamina()
	GameState.changed.emit()
	day_advanced.emit()
	changed.emit()
	settling=false
	Playtest.record("day",{"reason":reason})
	Events.notice.emit("你因疲劳睡着了。醒来已是第%d天06:00，恢复了六成体力。" % day if reason=="fatigue" else "早安！第%d天开始了，记得给作物浇水。" % day)
	return true

func clock_text() -> String:
	return "%02d:%02d" % [int(minutes)/60,int(minutes)%60]
