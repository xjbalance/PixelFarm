extends Node
## 统一世界变化视图。原建设分区继续拥有权威进度，记录不再次结算物品/奖励。
signal changed
const LABELS := {"bridge":"河湾旧桥已修复","well":"清泉水井建成","warehouse":"种子共仓建成","arbor":"公共茶座建成","lanterns":"庆典风灯长留村庄","trade":"公开矿道贸易规则","community":"社区公共规则","water":"农业用水优先规则","greenhouse_frame":"温室结构恢复","greenhouse_water":"温室水源恢复","greenhouse_core":"温室能源核心恢复","greenhouse_stars":"温室星灯点亮","lake_care":"湖畔共同研究完成","lake_restored":"湖泊生态恢复与水循环修复","dock":"河湾岸上码头","trade_market":"码头交易棚","community_lights":"社区路灯与花坛","community_gathering":"社区晚间活动桌","home_extension":"家中扩建侧间","home_large":"宽敞住宅工作间"}
var observed: Dictionary = {}
var restoring: bool = false

func _ready() -> void:
	for source in [Story,VillageProjects,River,LegendState,Xiaojing,Aquaculture,LakeEcology]: source.changed.connect(refresh)

func features() -> Dictionary:
	return derive({"story":Story.snapshot(),"village":VillageProjects.snapshot(),"river":River.snapshot(),"legend":LegendState.snapshot(),"xiaojing":Xiaojing.snapshot(),"aquaculture":Aquaculture.snapshot(),"ecology":LakeEcology.snapshot(),"world_development":WorldDevelopment.snapshot(),"housing":Housing.snapshot()})

static func derive(data: Dictionary) -> Dictionary:
	# Migration can see malformed old sections before the full schema rejects them.
	for section in ["story","village","river","legend","aquaculture","ecology","world_development","housing"]:
		if not data.get(section,{}) is Dictionary: return {}
	if not data.get("village",{}).get("built",[]) is Array: return {}
	if not FarmSaveSchema.whole(data.get("story",{}).get("stage",0),0,8): return {}
	if not FarmSaveSchema.whole(data.get("legend",{}).get("greenhouse",0),0,5): return {}
	if not data.get("aquaculture",{}).get("xiaojing",{}) is Dictionary: return {}
	if not data.get("river",{}).get("policy","") is String: return {}
	for feature in ["dock","community"]:
		if not FarmSaveSchema.whole(data.get("world_development",{}).get(feature,0),0,2): return {}
	if not FarmSaveSchema.whole(data.get("housing",{}).get("level",1),1,3): return {}
	var built: Array=data.get("village",{}).get("built",[])
	var stage: int=int(data.get("story",{}).get("stage",0))
	var policy: String=data.get("river",{}).get("policy","")
	var greenhouse: int=int(data.get("legend",{}).get("greenhouse",0))
	return {"bridge":stage>=5,"well":"well" in built,"warehouse":"cooperative" in built,"arbor":"arbor" in built,"lanterns":stage>=8,"trade":policy=="rotation","community":policy=="commons","water":policy=="water","greenhouse_frame":greenhouse>=2,"greenhouse_water":greenhouse>=3,"greenhouse_core":greenhouse>=4,"greenhouse_stars":greenhouse>=5,"lake_care":data.get("aquaculture",{}).get("xiaojing",{}).get("stage",0)==2,"lake_restored":data.get("ecology",{}).get("restored",false),"dock":int(data.get("world_development",{}).get("dock",0))>=1,"trade_market":int(data.get("world_development",{}).get("dock",0))>=2,"community_lights":int(data.get("world_development",{}).get("community",0))>=1,"community_gathering":int(data.get("world_development",{}).get("community",0))>=2,"home_extension":int(data.get("housing",{}).get("level",1))>=2,"home_large":int(data.get("housing",{}).get("level",1))>=3}

func has_feature(id: String) -> bool:
	return bool(features().get(id,false))

func refresh() -> void:
	if restoring: return
	var actual := features()
	for id in LABELS:
		# 只观察已有结算的结果，绝不调用原设施建造或奖励接口。
		if actual.get(id,false) and not observed.has(id): observed[id]=GameClock.day
	changed.emit()

func snapshot() -> Dictionary:
	var result := {}
	var actual := features()
	for id in LABELS:
		if actual.get(id,false): result[id]=mini(GameClock.day,int(observed.get(id,GameClock.day)))
	return {"observed":result}

func restore(raw: Dictionary) -> void:
	observed=raw.observed.duplicate(true)
	changed.emit()

static func migrate(data: Dictionary) -> Dictionary:
	var result := {}
	var actual := derive(data)
	for id in LABELS:
		if actual.get(id,false): result[id]=int(data.day)
	return {"observed":result}

static func validate(raw: Variant, data: Dictionary) -> bool:
	if not raw is Dictionary or raw.size()!=1 or not raw.get("observed") is Dictionary: return false
	var actual := derive(data)
	if raw.observed.size()>LABELS.size(): return false
	for id in raw.observed:
		if not LABELS.has(id) or not actual.get(id,false) or not FarmSaveSchema.whole(raw.observed[id],1,int(data.day)): return false
	return true
