extends RefCounted
## 旧正向婚礼回归的显式前置夹具；新增目标本身由独立集成测试实操验证。

static func satisfy(_game: Node) -> void:
	max_home(_game)
	caught_eternal()

static func max_home(_game: Node) -> void:
	var house: Dictionary=Housing.snapshot()
	house.level=4;house.construction={};house.upgrade_serial=3
	house.completed_jobs=[1,2,3];house.last_settled_day=GameClock.day
	var layout: Dictionary=Housing.reconciled_furniture(house)
	house.placed=layout.placed;house.recovered=layout.recovered;house.builtins=layout.builtins
	Housing.restore(house)

static func caught_eternal() -> void:
	var fishing: Dictionary=Fishing.snapshot()
	fishing.pending="";fishing.pending_day=0
	fishing.rod=3
	if int(fishing.counts.get("eternal",0))<1: fishing.counts.eternal=1
	if "eternal" not in fishing.collection: fishing.collection.append("eternal")
	# 保留已有钓获；此夹具只补齐对应的经验与真实尝试元数据，不发放鱼物品。
	fishing.total=0;fishing.xp=0
	for species in fishing.counts:
		fishing.total+=int(fishing.counts[species])
		fishing.xp+=int(fishing.counts[species])*int(Fishing.data.species[species].xp)
	# 对应实际可钓传说鱼的星纹竿，并补足其已钓获经验门槛。
	var required: int=160 if fishing.rod==3 else (40 if fishing.rod==2 else 0)
	if fishing.xp<required:
		var extra: int=ceili(float(required-int(fishing.xp))/3.0)
		fishing.counts.crucian=int(fishing.counts.get("crucian",0))+extra
		if "crucian" not in fishing.collection: fishing.collection.append("crucian")
		fishing.total+=extra;fishing.xp+=extra*3
	fishing.serial=maxi(int(fishing.serial),int(fishing.total))
	fishing.casts_day=maxi(int(fishing.casts_day),ceili(float(fishing.serial)/12.0))
	fishing.casts=maxi(1,int(fishing.serial)-(int(fishing.casts_day)-1)*12)
	fishing.casts=mini(12,int(fishing.casts))
	fishing.legend_season=Calendar.season_serial()
	Fishing.restore(fishing)
	Fishing.update_achievements()
