extends Node
## 天气由统一四季预报决定；旧API保留，日结算仍由GameClock唯一触发。
signal changed
var enabled: bool = true

func _ready() -> void:
	Calendar.changed.connect(func(): changed.emit())

func weather_id(day: int = GameClock.day) -> String:
	return Calendar.weather_id(day) if enabled else "clear"

func is_rainy(day: int = GameClock.day) -> bool:
	return weather_id(day) in ["rain","heavy_rain","storm"]

func is_snowy(day: int = GameClock.day) -> bool:
	return weather_id(day) in ["snow","blizzard"]

func is_harsh(day: int = GameClock.day) -> bool:
	return weather_id(day) in ["heavy_rain","storm","blizzard"]

func is_meteor_night() -> bool:
	return weather_id()=="meteor" and GameClock.minutes>=1200 and GameClock.minutes<1440

func lake_water_delta(day: int = GameClock.day) -> int:
	return int(Calendar.data.weather[weather_id(day)].lake_water)

func label(day: int = GameClock.day) -> String:
	var id := weather_id(day)
	if id=="meteor" and day==GameClock.day and GameClock.minutes<1200: return "晴朗 · 今夜流星"
	return str(Calendar.data.weather[id].name)

func tomorrow() -> String:
	return label(GameClock.day+1)

func description(day: int = GameClock.day) -> String:
	return str(Calendar.data.weather[weather_id(day)].description)

func is_moon_night() -> bool:
	return Calendar.day_of_season()==15 and GameClock.minutes>=1200 and GameClock.minutes<1440 and weather_id() in ["clear","cloudy"]
