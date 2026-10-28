class_name TerritoryCatalog
extends RefCounted
## 地表领地与原公共场景分开；权利来自剧情里程碑，不相信存档中的自授权限。
const CELL_SIZE: int=32
const ANNEX_AREAS: Array[String]=["east_holding","lake_holding","forest_holding","manor_holding"]
const EDITABLE_AREAS: Array[String]=["farm","east_holding","lake_holding","forest_holding","manor_holding"]
const PUBLIC_AREAS: Array[String]=["home","village","mist_forest","lake_ruins","old_temple","greenhouse","mine_a","mine_b","mine_c","abyss"]
const TERRAIN_KINDS := {
	"soil":{"name":"翻土"},"grass":{"name":"恢复草地"},"dirt_path":{"name":"泥土小路"},
	"stone_path":{"name":"石子小路"},"wood_path":{"name":"木质步道"},"natural":{"name":"恢复自然地表"},
	"flowerbed":{"name":"花圃地面"}
}
const OBJECT_KINDS := {
	"tree":{"name":"观赏树","size":[2,2],"solid":true,"category":"vegetation","art":"tree"},
	"bush":{"name":"圆叶灌木","size":[1,1],"solid":true,"category":"vegetation","art":"bush"},
	"tall_grass":{"name":"自然草簇","size":[1,1],"solid":false,"category":"vegetation","art":"grass"},
	"flowers":{"name":"田园花丛","size":[1,1],"solid":false,"category":"vegetation","art":"flowers"},
	"rock_decor":{"name":"庭园景石","size":[1,1],"solid":true,"category":"objects","art":"rock"},
	"fence":{"name":"小木围栏","size":[1,1],"solid":true,"category":"objects","art":"fence"},
	"lamp":{"name":"庭院灯","size":[1,1],"solid":true,"category":"objects","art":"lamp"},
	"table":{"name":"户外小桌","size":[2,1],"solid":true,"category":"objects","art":"table"},
	"chair":{"name":"木椅","size":[1,1],"solid":true,"category":"objects","art":"chair"},
	"chest":{"name":"共享收纳箱","size":[1,1],"solid":true,"category":"objects","art":"chest"},
	"bench":{"name":"田园长椅","size":[2,1],"solid":true,"category":"objects","art":"bench"}
}
const NAMES := {"farm":"主农场与住宅庭院","east_holding":"河东开发地","lake_holding":"湖畔归属地","forest_holding":"林地开发区","manor_holding":"终局庄园用地","home":"住宅室内","village":"河湾村公共区域","mist_forest":"迷雾森林调查区","lake_ruins":"湖底遗迹","old_temple":"古老神庙","greenhouse":"星光温室礼堂","mine_a":"旧矿道","mine_b":"地下水脉","mine_c":"晶石洞窟","abyss":"地下闯关区域"}
const HINTS := {
	"farm":"初始私人领地；住宅、原农田、公共通路与关键设施保留。",
	"east_holding":"修复河湾旧桥，并完成第一章。",
	"lake_holding":"先开放河东开发地，恢复湖泊循环，并完成第二章「地下水位异常」。",
	"forest_holding":"先开放湖畔归属地，完成森林清障并读到森林排水档案。",
	"manor_holding":"先开放林地开发区，完成第二章终章「第一班回村的车」。"
}
const RETURNS := {"east_holding":[1088,352],"lake_holding":[1152,352],"forest_holding":[1216,352],"manor_holding":[1280,352]}
const GATES := {"east_holding":[1088,304],"lake_holding":[1152,304],"forest_holding":[1216,304],"manor_holding":[1280,304]}
const INVALID_CELL := Vector2i(-1000000,-1000000)
const FARM_BUILDINGS: Array[Rect2]=[Rect2(560,242,192,204),Rect2(288,306,136,146)]
const FARM_SERVICE_POINTS: Array[Vector2]=[Vector2(656,410),Vector2(356,416),Vector2(820,432),Vector2(968,432),Vector2(748,440),Vector2(480,216),Vector2(784,464),Vector2(464,752),Vector2(240,560),Vector2(912,688),Vector2(944,592),Vector2(1104,752),Vector2(1264,592),Vector2(1104,432),Vector2(176,880),Vector2(400,912),Vector2(816,912)]
static var _farm_protected: Dictionary={}
static var _farm_protected_ready: bool=false

static func permissions() -> Dictionary:
	var result: Dictionary={}
	for area in EDITABLE_AREAS: result[area]="private"
	return result

static func region(area: String) -> Dictionary:
	var editable: bool=area in EDITABLE_AREAS
	var result: Dictionary={"id":area,"name":str(NAMES.get(area,"公共区域")),"ownership":"private" if editable else "public","hint":str(HINTS.get(area,"公共、剧情或地下区域不开放领地改造。")),"entry":[640,800],"return_position":RETURNS.get(area,[656,440]).duplicate(),"gate_position":GATES.get(area,[0,0]).duplicate(),"editable_rect":Rect2i(),"protected":[],"semi_open":Rect2i()}
	if area=="farm":
		result.editable_rect=Rect2i(2,5,44,25)
		# 旧经营设施与农田格ID原样保留；动态资源和实际碰撞由场景校验补充。
		result.protected=[Rect2i(2,13,44,2),Rect2i(14,5,2,25),Rect2i(16,15,12,8),Rect2i(16,8,8,5),Rect2i(32,8,10,4),Rect2i(28,10,16,14),Rect2i(36,22,10,8),Rect2i(2,25,7,5),Rect2i(9,25,8,5),Rect2i(22,25,9,5),Rect2i(9,19,6,6)]
	elif area in ANNEX_AREAS:
		result.editable_rect=Rect2i(2,2,36,24)
		result.protected=[Rect2i(19,2,2,24),Rect2i(17,24,6,2)]
		if area=="east_holding": result.semi_open=Rect2i(2,2,36,3)
	return result

static func is_solid(kind: String) -> bool:
	return OBJECT_KINDS.has(kind) and bool(OBJECT_KINDS[kind].solid)

static func footprint(kind: String, cell: Vector2i) -> Rect2i:
	if not OBJECT_KINDS.has(kind): return Rect2i()
	var extent: Array=OBJECT_KINDS[kind].size
	return Rect2i(cell,Vector2i(int(extent[0]),int(extent[1])))

static func key(cell: Vector2i) -> String: return "%d,%d" % [cell.x,cell.y]

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

static func to_cell(value: Variant) -> Vector2i:
	if value is Vector2i: return value
	if value is Array and value.size()==2 and whole(value[0],-2048,2048) and whole(value[1],-2048,2048): return Vector2i(int(value[0]),int(value[1]))
	return INVALID_CELL

static func cell_from_key(value: String) -> Vector2i:
	var pieces: PackedStringArray=value.split(",")
	if pieces.size()!=2 or not pieces[0].is_valid_int() or not pieces[1].is_valid_int(): return INVALID_CELL
	# 限长后再转整数，拒绝恶意巨长数字时也不产生引擎溢出错误。
	if pieces[0].length()>5 or pieces[1].length()>5: return INVALID_CELL
	var cell:=Vector2i(pieces[0].to_int(),pieces[1].to_int())
	return cell if absi(cell.x)<=2048 and absi(cell.y)<=2048 and key(cell)==value else INVALID_CELL

static func ownership(area: String, cell: Vector2i) -> String:
	var info:=region(area)
	if area not in EDITABLE_AREAS or not info.editable_rect.has_point(cell): return "public"
	for reserved: Rect2i in info.protected:
		if reserved.has_point(cell): return "public"
	# 存档校验同样保护原资源的未来再生位置和固定剧情点，不能仅依赖现场物理查询。
	if area=="farm" and farm_protected_cells().has(cell): return "public"
	return "semi_open" if info.semi_open.has_point(cell) else "private"

static func _reserve_farm_rect(rect: Rect2) -> void:
	var start:=Vector2i((rect.position/32).floor())
	var end:=Vector2i((rect.end/32).ceil())
	for y in range(maxi(0,start.y),mini(32,end.y)):
		for x in range(maxi(0,start.x),mini(48,end.x)):
			if rect.intersects(Rect2(x*32,y*32,32,32)): _farm_protected[Vector2i(x,y)]=true

static func farm_protected_cells() -> Dictionary:
	if _farm_protected_ready: return _farm_protected
	_farm_protected_ready=true
	for resource in FarmResourceCatalog.placements("farm").values():
		_reserve_farm_rect(Rect2(Vector2(resource.cell)*32-Vector2(26,32),Vector2(52,52)).grow(8))
	for rect in FARM_BUILDINGS: _reserve_farm_rect(rect)
	for point in FARM_SERVICE_POINTS: _reserve_farm_rect(Rect2(point-Vector2(42,42),Vector2(84,84)))
	# 使用原资源中的固定坐标，包含当前隐藏的节日牌、记忆及检修点；不读取解锁进度。
	for path in ["res://resources/story/star1314.json","res://resources/story/xiaojing.json","res://resources/exploration/exploration.json","res://resources/river/river.json","res://resources/festivals/festivals.json","res://resources/fishing/fishing.json"]:
		var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not source is Dictionary: continue
		for group in ["points","entrances","fishing_sites","events","memories","sites"]:
			var entries: Variant=source.get(group)
			if entries is Dictionary: entries=entries.values()
			if not entries is Array: continue
			for entry in entries:
				if not entry is Dictionary or entry.get("area",entry.get("location",""))!="farm": continue
				var at: Variant=entry.get("position",entry.get("board",entry.get("shore")))
				if not at is Array or at.size()!=2 or not whole(at[0],-2048,2048) or not whole(at[1],-2048,2048): continue
				var point:=Vector2(float(at[0]),float(at[1]))
				_reserve_farm_rect(Rect2(point-Vector2(42,42),Vector2(84,84)))
	return _farm_protected

static func cell_allowed(area: String, cell: Vector2i, operation: String) -> Dictionary:
	var rights:=ownership(area,cell)
	if rights=="public": return {"allowed":false,"reason":"这里是公共通路、关键设施或未授予的地块，不能改造。","ownership":rights}
	if not TERRAIN_KINDS.has(operation) and not OBJECT_KINDS.has(operation) and operation not in ["terrain","move","remove"]:
		return {"allowed":false,"reason":"不支持这种改造工具。","ownership":rights}
	if rights=="semi_open" and OBJECT_KINDS.has(operation) and is_solid(operation):
		return {"allowed":false,"reason":"过渡地带只允许地表与不阻挡通行的花草装饰。","ownership":rights}
	return {"allowed":true,"reason":"","ownership":rights}

static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func earned_regions(raw_save: Dictionary={}) -> Array[String]:
	# 迁移先于完整存档校验运行，损坏的旧子字段必须安全失败，不能抛错打断备份恢复。
	var stage_raw: Variant=Story.stage if raw_save.is_empty() else _dictionary(raw_save.get("story")).get("stage",0)
	var stage: int=int(stage_raw) if whole(stage_raw,0,8) else 0
	var restored_raw: Variant=LakeEcology.state.get("restored",false) if raw_save.is_empty() else _dictionary(raw_save.get("ecology")).get("restored",false)
	var restored: bool=restored_raw is bool and restored_raw
	var chapter_raw: Variant=ChapterTwo.completed if raw_save.is_empty() else _dictionary(raw_save.get("chapter_two")).get("completed",[])
	var chapter: Array=chapter_raw if chapter_raw is Array else []
	var exploration: Dictionary=Exploration.state if raw_save.is_empty() else _dictionary(raw_save.get("exploration"))
	var river: Dictionary=River.state if raw_save.is_empty() else _dictionary(raw_save.get("river"))
	var result: Array[String]=["farm"]
	if stage<8: return result
	result.append("east_holding")
	if not restored or "water" not in chapter: return result
	result.append("lake_holding")
	var forest_open: Variant=_dictionary(exploration.get("forest")).get("open",false)
	var forest_facts: Variant=exploration.get("facts",[])
	if not forest_open is bool or not forest_open or not forest_facts is Array or "forest_archive" not in forest_facts: return result
	result.append("forest_holding")
	var river_facts: Variant=river.get("facts",[])
	if river_facts is Array and "closing_scene" in river_facts: result.append("manor_holding")
	return result
