extends Node
## 绝对日期仍由GameClock唯一管理；派生日历和天气查询不推进日期、不结算奖励。
signal changed
signal season_changed(previous_season: int, current_season: int, current_year: int)
signal year_changed(current_year: int)
const DAYS_PER_SEASON: int = 28
const DAYS_PER_YEAR: int = 112
const DEFAULT_SEED: int = 70701
const SEASON_IDS := ["spring","summer","autumn","winter"]
const SEASON_NAMES := ["春","夏","秋","冬"]
const WEATHER_IDS := ["clear","cloudy","rain","heavy_rain","storm","snow","blizzard","fog","meteor"]
var data: Dictionary = {}
var world_seed: int = DEFAULT_SEED
var legacy_weather: Dictionary = {}
var last_observed_day: int = 1

func _ready() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://resources/seasons/climate.json"))
	last_observed_day=GameClock.day
	GameClock.day_advanced.connect(advance_day)

func year(day: int = GameClock.day) -> int:
	return int((maxi(1,day)-1)/DAYS_PER_YEAR)+1

func season(day: int = GameClock.day) -> int:
	return int((maxi(1,day)-1)/DAYS_PER_SEASON)%4

func day_of_season(day: int = GameClock.day) -> int:
	return (maxi(1,day)-1)%DAYS_PER_SEASON+1

func season_serial(day: int = GameClock.day) -> int:
	return int((maxi(1,day)-1)/DAYS_PER_SEASON)

func date(day: int = GameClock.day) -> Dictionary:
	return {"absolute":day,"year":year(day),"season":season(day),"season_day":day_of_season(day)}

func label(day: int = GameClock.day) -> String:
	return "第%d年 · %s%d日" % [year(day),SEASON_NAMES[season(day)],day_of_season(day)]

func legacy_weather_id(day: int) -> String:
	if day%7 in [4,0]: return "rain"
	return "cloudy" if day%7==5 else "clear"

func predicted_weather(day: int, seed_value: int = world_seed) -> String:
	# 第一个春天保留现有河谷气候节律；之后四季有稳定可预报的天气窗口。
	if day<=DAYS_PER_SEASON: return legacy_weather_id(day)
	var index := season(day)
	var local_day := day_of_season(day)
	var anchor: Dictionary=data.anchors[SEASON_IDS[index]]
	if anchor.has(str(local_day)): return str(anchor[str(local_day)])
	# 不触碰全局随机数生成器，重启/存档读取/查看预报均得到同一结果。
	var hash_value: int=(day*1103515245+seed_value*2654435761+year(day)*12345)&0x7fffffff
	var roll: int=hash_value%100
	var accumulated := 0
	for id in data.seasons[index].weights:
		accumulated+=int(data.seasons[index].weights[id])
		if roll<accumulated: return str(id)
	return "clear"

func weather_id(day: int = GameClock.day) -> String:
	if not legacy_weather.is_empty() and int(legacy_weather.day)==day: return str(legacy_weather.id)
	return predicted_weather(day)

func advance_day() -> void:
	var today: int=GameClock.day
	if today<=last_observed_day: return
	last_observed_day=today
	# 当日日结算消费者还会查询昨天天气；迁移日的旧气候至少保留到次日结算完。
	if not legacy_weather.is_empty() and int(legacy_weather.day)<today-1: legacy_weather.clear()
	if day_of_season(today)==1:
		season_changed.emit(season(today-1),season(today),year(today))
		if season(today)==0: year_changed.emit(year(today))
	changed.emit()

func snapshot(day: int = GameClock.day) -> Dictionary:
	var origin: String="legacy" if not legacy_weather.is_empty() and int(legacy_weather.day)==day else "seasonal"
	return {"seed":world_seed,"date":date(day),"weather":{"day":day,"id":weather_id(day),"origin":origin}}

func migrate(day: int) -> Dictionary:
	# 迁移仅保留旧当天的晴雨，不凭空补作物成长或重新触发换季。
	return {"seed":DEFAULT_SEED,"date":date(day),"weather":{"day":day,"id":legacy_weather_id(day),"origin":"legacy"}}

func restore(raw: Dictionary) -> void:
	world_seed=int(raw.seed)
	last_observed_day=int(raw.date.absolute)
	legacy_weather={"day":int(raw.weather.day),"id":str(raw.weather.id)} if raw.weather.origin=="legacy" else {}
	changed.emit()

func validate(raw: Variant, day: int) -> bool:
	if not whole(day,1,999999) or not exact(raw,["seed","date","weather"]): return false
	if not whole(raw.seed,0,2147483647) or not exact(raw.date,["absolute","year","season","season_day"]): return false
	var expected := date(day)
	for key in expected:
		if not whole(raw.date[key],int(expected[key]),int(expected[key])): return false
	if not exact(raw.weather,["day","id","origin"]) or not whole(raw.weather.day,day,day): return false
	if raw.weather.id not in WEATHER_IDS or raw.weather.origin not in ["legacy","seasonal"]: return false
	if raw.weather.origin=="legacy": return raw.weather.id==legacy_weather_id(day)
	return raw.weather.id==predicted_weather(day,int(raw.seed))

func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

func exact(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true
