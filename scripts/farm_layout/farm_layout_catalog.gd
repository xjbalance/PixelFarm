class_name FarmLayoutCatalog
extends RefCounted
## 原农场实体的固定身份与默认位置。这里只描述布局，不保存等级、物品或任务。
const GRID := Rect2i(0,0,96,64)
const WORLD := Rect2(0,0,3072,2048)
const INVALID_CELL := Vector2i(-1000000,-1000000)
const EXTRA_FIXTURES := "res://resources/farm_layout/fixtures.json"
const KINDS: Array[String]=["fixture","resource","plot"]
const FIELDS := {"fixture":"fixtures","resource":"resources","plot":"plots"}
const MAIN_FIXTURES := {
	"home":[656,410],"shop":[356,416],"workshop":[820,432],"board":[968,432],"mail":[748,440],"village_gate":[480,216],
	"recovery":[784,464],"yard":[464,752],"berry":[240,560],"coop":[176,880],"barn":[400,912],"fold":[816,912],
	"greenhouse":[1328,780],"pen_1":[944,592],"pen_2":[1104,752],"pen_3":[1264,592],"pen_4":[1104,432],
	"ecology":[912,688],"fishing_farm":[976,464],"festival_spring":[880,496],"festival_summer":[1168,800],"lake":[1104,592]
}
const NAMES := {"home":"玩家住宅","shop":"种子摊","workshop":"修缮工台","board":"委托板","mail":"信箱","village_gate":"河湾村路口","recovery":"休息长椅","yard":"庭院与收纳","berry":"浆果丛","coop":"鸡舍","barn":"牛棚","fold":"羊圈","greenhouse":"星光温室","pen_1":"西岸鱼栏","pen_2":"南岸鱼栏","pen_3":"东岸鱼栏","pen_4":"北岸鱼栏","ecology":"湖泊生态台","fishing_farm":"湖岸垂钓台","festival_spring":"春季活动牌","festival_summer":"夏季活动牌","lake":"原有湖泊"}
const BOUNDS := {
	"home":[-72,-76,144,58],"shop":[-52,-56,104,30],"workshop":[-26,-31,52,20],"board":[-26,-31,52,20],
	"coop":[-56,-116,112,48],"barn":[-56,-116,112,48],"fold":[-56,-116,112,48],"greenhouse":[-52,-64,104,64],"lake":[-144,-144,288,288]
}
const ASSOCIATED := {"home":[[656,402],[656,440]],"greenhouse":[[1280,780],[1280,848],[1376,848]],"lake":[[896,752],[950,800]]}
static var _fixtures: Dictionary={}
static var _resources: Dictionary={}

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floorf(float(value))

static func parse_cell(raw: Variant) -> Vector2i:
	if raw is Vector2i: return raw
	if raw is Array and raw.size()==2 and whole(raw[0],-2048,2048) and whole(raw[1],-2048,2048): return Vector2i(int(raw[0]),int(raw[1]))
	return INVALID_CELL

static func cell_key(at: Vector2i) -> String: return "%d,%d" % [at.x,at.y]

static func plot_cell(id: String) -> Vector2i:
	var parts:=id.split(",")
	if parts.size()!=2 or parts[0].length()>3 or parts[1].length()>3 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return INVALID_CELL
	var at:=Vector2i(parts[0].to_int(),parts[1].to_int())
	return at if GRID.has_point(at) and cell_key(at)==id else INVALID_CELL

static func _point(raw: Variant, fallback: Vector2=Vector2.ZERO) -> Vector2:
	if raw is Vector2 and raw.is_finite(): return raw
	if raw is Array and raw.size()==2 and (raw[0] is float or raw[0] is int) and (raw[1] is float or raw[1] is int):
		var at:=Vector2(float(raw[0]),float(raw[1]))
		if at.is_finite(): return at
	return fallback

static func _rect(raw: Variant, fallback: Rect2) -> Rect2:
	if raw is Rect2: return raw
	if raw is Array and raw.size()==4:
		for number in raw:
			if not (number is float or number is int) or not is_finite(float(number)): return fallback
		if float(raw[2])>=0 and float(raw[3])>=0: return Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	return fallback

static func _ensure_fixtures() -> void:
	if not _fixtures.is_empty(): return
	for id in MAIN_FIXTURES:
		_fixtures[id]={"id":id,"name":str(NAMES.get(id,id)),"point":MAIN_FIXTURES[id],"bounds":BOUNDS.get(id,[-10,-10,20,20]),"associated_points":ASSOCIATED.get(id,[])}
	if FileAccess.file_exists(EXTRA_FIXTURES):
		var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(EXTRA_FIXTURES))
		if source is Dictionary:
			var entries: Variant=source.get("fixtures",source)
			if entries is Dictionary:
				for id in entries:
					if not id is String or not entries[id] is Dictionary: continue
					var info: Dictionary=_fixtures.get(id,{}).duplicate(true)
					info.merge(entries[id],true);info.id=id
					if not info.has("point"): continue
					_fixtures[id]=info
	for id in _fixtures:
		var entry: Dictionary=_fixtures[id]
		entry.point=_point(entry.get("point"));entry.cell=Vector2i((entry.point/32).floor())
		entry.bounds=_rect(entry.get("bounds"),Rect2(-10,-10,20,20))
		entry.display_rect=_rect(entry.get("display_rect"),entry.bounds)
		entry.name=str(entry.get("name",id))
		var linked: Array[Vector2]=[]
		if entry.get("associated_points") is Array:
			for raw in entry.associated_points: linked.append(_point(raw))
		entry.associated_points=linked

static func fixtures(_raw_save: Dictionary={}) -> Dictionary:
	_ensure_fixtures();return _fixtures.duplicate(true)
static func definitions() -> Dictionary: return fixtures()
static func fixture(id: String, _raw_save: Dictionary={}) -> Dictionary:
	_ensure_fixtures();return _fixtures.get(id,{}).duplicate(true)
static func base_point(id: String) -> Vector2:
	_ensure_fixtures();return _fixtures[id].point if _fixtures.has(id) else Vector2.INF

static func _ensure_resources() -> void:
	if not _resources.is_empty(): return
	var placements:=FarmResourceCatalog.placements("farm")
	for id in placements:
		var raw: Dictionary=placements[id]
		if raw.has("fixture"): continue
		var size:=Vector2(22,19) if raw.kind=="tree" else Vector2(46,28) if raw.kind=="boulder" else Vector2(30,16)
		_resources[id]={"id":id,"name":str(FarmResourceCatalog.TYPES[raw.kind].name),"cell":raw.cell,"point":Vector2(raw.cell)*32,"bounds":Rect2(Vector2(0,-5)-size*.5,size)}

static func definition(kind: String, id: String) -> Dictionary:
	if kind=="fixture": return fixture(id)
	if kind=="resource":
		_ensure_resources();return _resources.get(id,{}).duplicate(true)
	if kind=="plot":
		var at:=plot_cell(id)
		if at!=INVALID_CELL: return {"id":id,"name":"生产田地 "+id,"cell":at,"point":Vector2(at)*32+Vector2(16,16),"bounds":Rect2(-16,-16,32,32)}
	return {}

static func valid_id(kind: String, id: String) -> bool:
	if kind=="plot": return plot_cell(id)!=INVALID_CELL
	if kind=="fixture": _ensure_fixtures();return _fixtures.has(id)
	if kind=="resource": _ensure_resources();return _resources.has(id)
	return false

static func ids(kind: String) -> Array[String]:
	var result: Array[String]=[]
	if kind=="fixture": _ensure_fixtures();result.assign(_fixtures.keys())
	elif kind=="resource": _ensure_resources();result.assign(_resources.keys())
	elif kind=="plot":
		for y in range(GRID.size.y):
			for x in range(GRID.size.x): result.append(cell_key(Vector2i(x,y)))
	return result

static func default_cell(kind: String, id: String) -> Vector2i:
	var info:=definition(kind,id)
	return info.cell if not info.is_empty() else INVALID_CELL

static func default_record(kind: String, id: String) -> Dictionary:
	var at:=default_cell(kind,id)
	return {"cell":[at.x,at.y],"stored":false} if at!=INVALID_CELL else {}

static func world_point(kind: String, id: String, at: Vector2i) -> Vector2:
	var info:=definition(kind,id)
	return info.point+Vector2(at-info.cell)*32 if not info.is_empty() else Vector2.INF

static func world_rect(kind: String, id: String, at: Vector2i) -> Rect2:
	var info:=definition(kind,id)
	return Rect2(world_point(kind,id,at)+info.bounds.position,info.bounds.size) if not info.is_empty() else Rect2()

static func associated_fixture(original: Vector2) -> String:
	_ensure_fixtures()
	# 精确主点优先于附属点，不用距离猜测把两个可独立移动的设施绑在一起。
	for id in _fixtures:
		if original==_fixtures[id].point: return str(id)
	for id in _fixtures:
		if original in _fixtures[id].associated_points: return str(id)
	return ""
