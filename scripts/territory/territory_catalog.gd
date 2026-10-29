class_name TerritoryCatalog
extends RefCounted
## 地表领地与原公共场景分开；权利来自剧情里程碑，不相信存档中的自授权限。
const CELL_SIZE: int=32
const ANNEX_AREAS: Array[String]=["east_holding","lake_holding","forest_holding","manor_holding"]
const EDITABLE_AREAS: Array[String]=["farm","east_holding","lake_holding","forest_holding","manor_holding"]
const PUBLIC_AREAS: Array[String]=["home","village","mist_forest","lake_ruins","old_temple","greenhouse","mine_a","mine_b","mine_c","abyss"]
const TERRAIN_KINDS := {
	"soil":{"name":"景观翻土","art":"tilled_soil"},"grass":{"name":"恢复草地","art":"grass"},"dirt_path":{"name":"泥土小路","art":"dirt_path"},
	"stone_path":{"name":"石子小路","art":"stone_path"},"wood_path":{"name":"木质步道","art":"wood_path"},"natural":{"name":"恢复自然地表","art":"grass"},
	"flowerbed":{"name":"花圃地面","art":"tilled_soil"},"sand":{"name":"沙土地面","art":"sand"},"gravel":{"name":"碎石地面","art":"gravel"},
	"water":{"name":"挖浅水池","art":"small_pond"},"deep_water":{"name":"挖深水池","art":"large_pond"}
}
static var OBJECT_KINDS: Dictionary=_object_kinds()
static func _object_kinds() -> Dictionary:
	var result:=BASE_OBJECT_KINDS.duplicate(true);result.merge(HarvestCatalog.placeables());return result
const BASE_OBJECT_KINDS := {
	"tree":{"name":"观赏树","size":[2,2],"solid":true,"category":"vegetation","group":"trees","art":"oak_tree","decorative":true},
	"bush":{"name":"灌木丛","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"bush","decorative":true},
	"tall_grass":{"name":"长草","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"tall_grass","decorative":true},
	"flowers":{"name":"田园花丛","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"flower_patch","decorative":true},
	"rock_decor":{"name":"庭园景石","size":[1,1],"solid":true,"category":"objects","group":"water","art":"shore_rocks","decorative":true},
	"fence":{"name":"小木围栏","size":[1,1],"solid":true,"category":"objects","group":"fences","art":"wood_fence","decorative":true},
	"lamp":{"name":"庭院灯","size":[1,1],"solid":true,"category":"objects","group":"village","art":"street_lamp","decorative":true},
	"table":{"name":"户外小桌","size":[2,1],"solid":true,"category":"objects","group":"furniture","art":"square_table","decorative":true},
	"chair":{"name":"木椅","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"wood_chair","decorative":true},
	"chest":{"name":"共享收纳箱","size":[1,1],"solid":true,"category":"objects","group":"props","art":"wood_crate","decorative":true,"storage":true},
	"bench":{"name":"田园长椅","size":[2,1],"solid":true,"category":"objects","group":"furniture","art":"wood_bench","decorative":true},
	"oak_tree":{"name":"阔叶树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"oak_tree","decorative":true},
	"pine_tree":{"name":"松树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"pine_tree","decorative":true},
	"birch_tree":{"name":"白桦树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"birch_tree","decorative":true},
	"apple_tree":{"name":"果树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"apple_tree","decorative":true},
	"blossom_tree":{"name":"开花树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"blossom_tree","decorative":true},
	"dead_tree":{"name":"枯树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"dead_tree","decorative":true},
	"tree_stump":{"name":"树桩","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"tree_stump","decorative":true},
	"oak_sapling":{"name":"阔叶幼树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"oak_sapling","decorative":true},
	"pine_sapling":{"name":"松树幼苗","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"pine_sapling","decorative":true},
	"birch_sapling":{"name":"白桦幼树","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"birch_sapling","decorative":true},
	"apple_sapling":{"name":"果树幼苗","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"apple_sapling","decorative":true},
	"blossom_sapling":{"name":"开花树幼苗","size":[1,1],"solid":true,"category":"vegetation","group":"trees","art":"blossom_sapling","decorative":true},
	"short_grass":{"name":"短草","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"short_grass","decorative":true},
	"grass_clump":{"name":"草丛","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"grass_clump","decorative":true},
	"clover":{"name":"三叶草","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"clover","decorative":true},
	"white_wildflowers":{"name":"白色野花","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"white_wildflowers","decorative":true},
	"yellow_wildflowers":{"name":"黄色野花","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"yellow_wildflowers","decorative":true},
	"purple_wildflowers":{"name":"紫色野花","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"purple_wildflowers","decorative":true},
	"sunflower":{"name":"向日葵","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"sunflower","decorative":true},
	"flower_patch":{"name":"花丛","size":[1,1],"solid":false,"category":"vegetation","group":"flowers","art":"flower_patch","decorative":true},
	"small_pond":{"name":"小池塘","size":[2,2],"solid":true,"category":"objects","group":"water","art":"small_pond","decorative":true},
	"large_pond":{"name":"大池塘","size":[4,3],"solid":true,"category":"objects","group":"water","art":"large_pond","decorative":true},
	"stream":{"name":"溪流","size":[2,2],"solid":true,"category":"objects","group":"water","art":"stream","decorative":true},
	"spring":{"name":"泉眼","size":[2,2],"solid":true,"category":"objects","group":"water","art":"spring","decorative":true},
	"well":{"name":"水井","size":[1,1],"solid":true,"category":"objects","group":"water","art":"well","decorative":true},
	"waterfall":{"name":"小瀑布","size":[2,1],"solid":true,"category":"objects","group":"water","art":"waterfall","decorative":true},
	"shore_rocks":{"name":"岸边石头","size":[1,1],"solid":true,"category":"objects","group":"water","art":"shore_rocks","decorative":true},
	"reeds":{"name":"芦苇","size":[1,1],"solid":false,"category":"objects","group":"water","art":"reeds","decorative":true},
	"lily_pad":{"name":"荷叶","size":[1,1],"solid":false,"category":"objects","group":"water","art":"lily_pad","decorative":true},
	"water_lily":{"name":"睡莲","size":[1,1],"solid":false,"category":"objects","group":"water","art":"water_lily","decorative":true},
	"wood_chair":{"name":"木椅","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"wood_chair","decorative":true},
	"wood_bench":{"name":"长椅","size":[2,1],"solid":true,"category":"objects","group":"furniture","art":"wood_bench","decorative":true},
	"stump_stool":{"name":"树桩凳","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"stump_stool","decorative":true},
	"round_table":{"name":"圆木桌","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"round_table","decorative":true},
	"square_table":{"name":"方木桌","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"square_table","decorative":true},
	"picnic_table":{"name":"野餐桌","size":[2,1],"solid":true,"category":"objects","group":"furniture","art":"picnic_table","decorative":true},
	"parasol":{"name":"遮阳伞","size":[1,1],"solid":true,"category":"objects","group":"furniture","art":"parasol","decorative":true},
	"garden_swing":{"name":"庭院秋千","size":[2,1],"solid":true,"category":"objects","group":"furniture","art":"garden_swing","decorative":true},
	"wood_fence":{"name":"木栅栏","size":[2,1],"solid":true,"category":"objects","group":"fences","art":"wood_fence","decorative":true},
	"stone_wall":{"name":"矮石墙","size":[2,1],"solid":true,"category":"objects","group":"fences","art":"stone_wall","decorative":true},
	"hedge_fence":{"name":"篱笆","size":[2,1],"solid":true,"category":"objects","group":"fences","art":"hedge_fence","decorative":true},
	"wood_gate":{"name":"木门","size":[1,1],"solid":true,"category":"objects","group":"fences","art":"wood_gate","decorative":true},
	"flower_arch":{"name":"花架拱门","size":[2,1],"solid":true,"category":"objects","group":"fences","art":"flower_arch","decorative":true},
	"wood_bridge":{"name":"小木桥","size":[2,2],"solid":true,"category":"objects","group":"fences","art":"wood_bridge","decorative":true},
	"stone_bridge":{"name":"石桥","size":[2,2],"solid":true,"category":"objects","group":"fences","art":"stone_bridge","decorative":true},
	"wood_steps":{"name":"木台阶","size":[2,1],"solid":true,"category":"objects","group":"fences","art":"wood_steps","decorative":true},
	"wood_fence_vertical":{"name":"纵向木栅栏","size":[1,2],"solid":true,"category":"objects","group":"fences","art":"wood_fence_vertical","decorative":true},
	"stone_wall_vertical":{"name":"纵向矮石墙","size":[1,2],"solid":true,"category":"objects","group":"fences","art":"stone_wall_vertical","decorative":true},
	"hedge_fence_vertical":{"name":"纵向篱笆","size":[1,2],"solid":true,"category":"objects","group":"fences","art":"hedge_fence_vertical","decorative":true},
	"wood_crate":{"name":"木箱 · 共用收纳","size":[1,1],"solid":true,"category":"objects","group":"props","art":"wood_crate","decorative":true,"storage":true},
	"wood_barrel":{"name":"木桶","size":[1,1],"solid":true,"category":"objects","group":"props","art":"wood_barrel","decorative":true},
	"flower_pot":{"name":"花盆","size":[1,1],"solid":true,"category":"objects","group":"props","art":"flower_pot","decorative":true},
	"flower_basket":{"name":"花篮","size":[1,1],"solid":true,"category":"objects","group":"props","art":"flower_basket","decorative":true},
	"burlap_sack":{"name":"麻袋","size":[1,1],"solid":true,"category":"objects","group":"props","art":"burlap_sack","decorative":true},
	"hay_bale":{"name":"干草堆","size":[1,1],"solid":true,"category":"objects","group":"props","art":"hay_bale","decorative":true},
	"firewood_pile":{"name":"柴火堆","size":[1,1],"solid":true,"category":"objects","group":"props","art":"firewood_pile","decorative":true},
	"handcart":{"name":"手推车","size":[2,1],"solid":true,"category":"objects","group":"props","art":"handcart","decorative":true},
	"watering_can":{"name":"浇水壶","size":[1,1],"solid":true,"category":"objects","group":"props","art":"watering_can","decorative":true},
	"tool_rack":{"name":"农具架","size":[1,1],"solid":true,"category":"objects","group":"props","art":"tool_rack","decorative":true},
	"road_sign":{"name":"路牌","size":[1,1],"solid":true,"category":"objects","group":"village","art":"road_sign","decorative":true},
	"mailbox":{"name":"邮箱","size":[1,1],"solid":true,"category":"objects","group":"village","art":"mailbox","decorative":true},
	"notice_board":{"name":"公告栏","size":[2,1],"solid":true,"category":"objects","group":"village","art":"notice_board","decorative":true},
	"street_lamp":{"name":"路灯","size":[1,1],"solid":true,"category":"objects","group":"village","art":"street_lamp","decorative":true},
	"lantern":{"name":"灯笼","size":[1,1],"solid":true,"category":"objects","group":"village","art":"lantern","decorative":true},
	"campfire":{"name":"篝火","size":[1,1],"solid":true,"category":"objects","group":"village","art":"campfire","decorative":true},
	"tent":{"name":"帐篷","size":[2,2],"solid":true,"category":"objects","group":"village","art":"tent","decorative":true},
	"market_stall":{"name":"摊位","size":[3,1],"solid":true,"category":"objects","group":"village","art":"market_stall","decorative":true},
	"clothesline":{"name":"晾衣架","size":[2,1],"solid":true,"category":"objects","group":"village","art":"clothesline","decorative":true},
	"farmhouse":{"name":"农舍（景观）","size":[4,2],"solid":true,"category":"objects","group":"buildings","art":"farmhouse","decorative":true},
	"tool_shed":{"name":"工具棚（景观）","size":[3,2],"solid":true,"category":"objects","group":"buildings","art":"tool_shed","decorative":true},
	"chicken_coop":{"name":"鸡舍（景观）","size":[3,2],"solid":true,"category":"objects","group":"buildings","art":"chicken_coop","decorative":true},
	"barn":{"name":"畜棚（景观）","size":[4,2],"solid":true,"category":"objects","group":"buildings","art":"barn","decorative":true},
	"greenhouse":{"name":"温室（景观）","size":[4,2],"solid":true,"category":"objects","group":"buildings","art":"greenhouse","decorative":true},
	"windmill":{"name":"风车（景观）","size":[3,2],"solid":true,"category":"objects","group":"buildings","art":"windmill","decorative":true},
	"pavilion":{"name":"凉亭（景观）","size":[3,2],"solid":true,"category":"objects","group":"buildings","art":"pavilion","decorative":true},
	"wood_door_closed":{"name":"关闭木门（景观）","size":[1,1],"solid":true,"category":"objects","group":"buildings","art":"wood_door_closed","decorative":true},
	"wood_door_open":{"name":"打开木门（景观）","size":[1,1],"solid":false,"category":"objects","group":"buildings","art":"wood_door_open","decorative":true},
	"window_closed":{"name":"关闭窗户（景观）","size":[1,1],"solid":false,"category":"objects","group":"buildings","art":"window_closed","decorative":true},
	"window_open":{"name":"打开窗户（景观）","size":[1,1],"solid":false,"category":"objects","group":"buildings","art":"window_open","decorative":true},
	"star_tree":{"name":"星辉树","size":[1,1],"solid":true,"category":"objects","group":"star","art":"star_tree","decorative":true},
	"glowing_flowers":{"name":"发光花草","size":[1,1],"solid":false,"category":"objects","group":"star","art":"glowing_flowers","decorative":true},
	"star_stele":{"name":"星纹石碑","size":[1,1],"solid":true,"category":"objects","group":"star","art":"star_stele","decorative":true},
	"star_altar":{"name":"小型祭坛","size":[2,1],"solid":true,"category":"objects","group":"star","art":"star_altar","decorative":true},
	"star_spring":{"name":"星辉泉水","size":[2,2],"solid":true,"category":"objects","group":"star","art":"star_spring","decorative":true},
	"moon_lamp":{"name":"月亮灯","size":[1,1],"solid":true,"category":"objects","group":"star","art":"moon_lamp","decorative":true},
	"star_lamp":{"name":"星形路灯","size":[1,1],"solid":true,"category":"objects","group":"star","art":"star_lamp","decorative":true},
	"star_particles":{"name":"星光粒子","size":[1,1],"solid":false,"category":"objects","group":"star","art":"star_particles","decorative":true}
}
const OBJECT_GROUPS := {"workshop":"加工设备","orchard":"生产果园","all":"全部","trees":"树木与幼苗","flowers":"草地与花草","water":"水景","furniture":"庭院家具","fences":"围栏与桥道","props":"农具与杂物","village":"生活设施","buildings":"建筑景观","star":"星辉装饰"}
const NAMES := {"farm":"主农场与住宅庭院","east_holding":"河东开发地","lake_holding":"湖畔归属地","forest_holding":"林地开发区","manor_holding":"终局庄园用地","home":"住宅室内","village":"河湾村公共区域","mist_forest":"迷雾森林调查区","lake_ruins":"湖底遗迹","old_temple":"古老神庙","greenhouse":"星光温室礼堂","mine_a":"旧矿道","mine_b":"地下水脉","mine_c":"晶石洞窟","abyss":"地下闯关区域"}
const HINTS := {
	"farm":"自己的农场可自由改造；真实农田、建筑、水面和功能入口保留。",
	"east_holding":"修复河湾旧桥，并完成第一章。",
	"lake_holding":"先开放河东开发地，恢复湖泊循环，并完成第二章「地下水位异常」。",
	"forest_holding":"先开放湖畔归属地，完成森林清障并读到森林排水档案。",
	"manor_holding":"先开放林地开发区，完成第二章终章「第一班回村的车」。"
}
const RETURNS := {"east_holding":[1088,352],"lake_holding":[1152,352],"forest_holding":[1216,352],"manor_holding":[1280,352]}
const GATES := {"east_holding":[1088,304],"lake_holding":[1152,304],"forest_holding":[1216,304],"manor_holding":[1280,304]}
const INVALID_CELL := Vector2i(-1000000,-1000000)
const FARM_BUILDINGS: Array[Rect2]=[Rect2(584,334,144,58),Rect2(304,360,104,30),Rect2(120,764,112,48),Rect2(344,796,112,48),Rect2(760,796,112,48),Rect2(1276,720,104,64)]
const FARM_SERVICE_POINTS: Array[Vector2]=[Vector2(656,410),Vector2(356,416),Vector2(820,432),Vector2(968,432),Vector2(748,440),Vector2(480,216),Vector2(784,464),Vector2(464,752),Vector2(240,560),Vector2(912,688),Vector2(944,592),Vector2(1104,752),Vector2(1264,592),Vector2(1104,432),Vector2(176,880),Vector2(400,912),Vector2(816,912)]
static var _farm_protected: Dictionary={}
static var _farm_protected_ready: bool=false
static var _farm_solid_protected: Dictionary={}
static var _farm_resources: Dictionary={}
static var _farm_resource_footprints: Dictionary={}
static var _current_resource_signature: int=-1
static var _current_resource_cells: Dictionary={}

static func permissions() -> Dictionary:
	var result: Dictionary={}
	for area in EDITABLE_AREAS: result[area]="private"
	return result

static func region(area: String) -> Dictionary:
	var editable: bool=area in EDITABLE_AREAS
	var result: Dictionary={"id":area,"name":str(NAMES.get(area,"公共区域")),"ownership":"private" if editable else "public","hint":str(HINTS.get(area,"公共、剧情或地下区域不开放领地改造。")),"entry":[640,800],"return_position":RETURNS.get(area,[656,440]).duplicate(),"gate_position":GATES.get(area,[0,0]).duplicate(),"editable_rect":Rect2i(),"protected":[],"semi_open":Rect2i()}
	if area=="farm":
		result.editable_rect=Rect2i(0,0,48,32)
		# 地表和道路没有大块禁改矩形；实体、水格和真实农田由细格检查保护。
		result.protected=[]
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
	# 只有真实建筑实体和原水格不能改造；资源与农田按当前保存状态细查。
	# All original farm entities can now move or enter recoverable storage.
	return "semi_open" if info.semi_open.has_point(cell) else "private"

static func _mark_farm_rect(target: Dictionary, rect: Rect2) -> void:
	var start:=Vector2i((rect.position/32).floor());var end:=Vector2i((rect.end/32).ceil())
	for y in range(maxi(0,start.y),mini(32,end.y)):
		for x in range(maxi(0,start.x),mini(48,end.x)):
			if rect.intersects(Rect2(x*32,y*32,32,32)): target[Vector2i(x,y)]=true

static func _reserve_anchor(point: Vector2) -> void:
	_mark_farm_rect(_farm_solid_protected,Rect2(point-Vector2(10,10),Vector2(20,20)))
	_mark_farm_rect(_farm_solid_protected,Rect2(point+Vector2(-10,22),Vector2(20,20)))

static func farm_protected_cells() -> Dictionary:
	return {}

static func legacy_farm_protected_cells() -> Dictionary:
	if _farm_protected_ready: return _farm_protected
	_farm_protected_ready=true
	for rect in FARM_BUILDINGS: _mark_farm_rect(_farm_protected,rect)
	for y in range(1,31):
		for x in range(1,47):
			if Vector2(x-34,y-18).length()<4.1: _farm_protected[Vector2i(x,y)]=true
	for id in FarmResourceCatalog.placements("farm"):
		var resource: Dictionary=FarmResourceCatalog.placements("farm")[id]
		var size:=Vector2(22,19) if resource.kind=="tree" else Vector2(30,16)
		var rect:=Rect2(Vector2(resource.cell)*32+Vector2(0,-5)-size*.5,size)
		var start:=Vector2i((rect.position/32).floor());var end:=Vector2i((rect.end/32).ceil())
		_farm_resource_footprints[id]=Rect2i(start,end-start)
		for y in range(start.y,end.y):
			for x in range(start.x,end.x):
				var cell:=Vector2i(x,y)
				if not _farm_resources.has(cell): _farm_resources[cell]=[]
				_farm_resources[cell].append(id)
	for point in FARM_SERVICE_POINTS: _reserve_anchor(point)
	_reserve_anchor(Vector2(656,440))
	for at in GATES.values(): _reserve_anchor(Vector2(at[0],at[1]))
	for at in RETURNS.values(): _reserve_anchor(Vector2(at[0],at[1]))
	# 未来动物也不能生成到新围栏里，只保留原站位而不是整片草地。
	for point in [Vector2(176,880),Vector2(400,912),Vector2(816,912)]:
		for offset in [Vector2(-40,-16),Vector2(-8,-16),Vector2(24,-16),Vector2(-40,16),Vector2(-8,16),Vector2(24,16),Vector2(-88,-40),Vector2(88,-40),Vector2(96,-8),Vector2(-96,-8),Vector2(-88,16),Vector2(88,16)]:
			_mark_farm_rect(_farm_solid_protected,Rect2(point+offset-Vector2(10,10),Vector2(20,20)))
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
				if at is Array and at.size()==2 and whole(at[0],-2048,2048) and whole(at[1],-2048,2048): _reserve_anchor(Vector2(float(at[0]),float(at[1])))
	return _farm_protected

static func farm_solid_protected_cells() -> Dictionary:
	return {}

static func resource_footprint(id: String) -> Rect2i:
	return FarmResourceCatalog.current_footprint(id)

static func resource_ids_at(cell: Vector2i) -> Array:
	var signature: int=FarmLayout.state.resources.hash()
	if signature!=_current_resource_signature:
		_current_resource_signature=signature;_current_resource_cells.clear()
		for id in FarmResourceCatalog.placements("farm"):
			var rect:=FarmResourceCatalog.current_footprint(str(id))
			for y in range(rect.position.y,rect.end.y):
				for x in range(rect.position.x,rect.end.x):
					var at:=Vector2i(x,y)
					if not _current_resource_cells.has(at): _current_resource_cells[at]=[]
					_current_resource_cells[at].append(id)
	return _current_resource_cells.get(cell,[])

static func farm_obstruction(cell: Vector2i, plots: Dictionary, resources: Dictionary) -> String:
	if plots.has(key(cell)): return "这格已有真实农田状态，请保留作物与翻土记录。"
	for id in resource_ids_at(cell):
		var raw: Variant=resources.get(id)
		# 缺少资源记录代表原始活体，不能用缺字段绕过采集。
		if not raw is Dictionary or not whole(raw.get("hp"),0,3) or int(raw.hp)>0: return "这里还有树木或石堆，请先用原工具正常采集。"
	return ""

static func cell_allowed(area: String, cell: Vector2i, operation: String) -> Dictionary:
	var rights:=ownership(area,cell)
	if rights=="public": return {"allowed":false,"reason":"这里是公共通路、关键设施或未授予的地块，不能改造。","ownership":rights}
	if not TERRAIN_KINDS.has(operation) and not OBJECT_KINDS.has(operation) and operation not in ["terrain","move","remove"]:
		return {"allowed":false,"reason":"不支持这种改造工具。","ownership":rights}
	if area!="farm" and operation in ["water","deep_water"]: return {"allowed":false,"reason":"水域重塑只在主农场使用。","ownership":rights}
	if area=="farm" and is_solid(operation) and farm_solid_protected_cells().has(cell):
		return {"allowed":false,"reason":"这里要留给入口、功能操作或原动物站位；可重铺地表，但不能放阻挡物。","ownership":"private"}
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
