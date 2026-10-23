extends Node
## 天气由日期决定，读档不会重新抽签；雨水在昨夜成长结算之后补给新一天。
signal changed
var enabled: bool = true

func _ready() -> void:
	GameClock.day_advanced.connect(func(): changed.emit())

func is_rainy(day: int = GameClock.day) -> bool:
	return enabled and day % 7 in [4,0]

func label() -> String:
	return "细雨" if is_rainy() else ("薄云" if GameClock.day % 7 == 5 else "晴朗")

func tomorrow() -> String:
	return "细雨" if is_rainy(GameClock.day+1) else "晴朗"
