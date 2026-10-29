extends RefCounted
## 旧正向婚礼回归的显式前置夹具；新增目标本身由独立集成测试实操验证。

static func satisfy(_game: Node) -> void:
	max_home(_game)
	life_milestones()
	caught_catalogue()

static func life_milestones() -> void:
	var rules: Dictionary=load("res://scripts/story/marriage_preparation.gd").data()
	var social: Dictionary=Social.snapshot()
	for id in rules.villager_stories:
		var quest: Dictionary=Social.definition(str(id))
		if id not in social.completed: social.completed.append(id)
		social.choices[id]=quest.choices.keys()[0]
		social.active.erase(quest.person)
	Social.restore(social)
	var kitchen: Dictionary=Kitchen.snapshot()
	for id in rules.recipes: kitchen.cooked[id]=maxi(1,int(kitchen.cooked.get(id,0)))
	Kitchen.restore(kitchen)
	var lake: Dictionary=LakeEcology.snapshot()
	lake.restored=true;lake.cycle=true;lake.plants=maxi(3,int(lake.plants));lake.health=maxi(90,int(lake.health));lake.debris=0
	LakeEcology.restore(lake)

static func caught_catalogue(except_eternal: bool=false) -> void:
	var species: Array=[]
	for id in load("res://scripts/story/marriage_preparation.gd").data().fish_species:
		if not except_eternal or id!="eternal": species.append(id)
	caught_species(species)

static func max_home(_game: Node) -> void:
	var house: Dictionary=Housing.snapshot()
	house.level=4;house.construction={};house.upgrade_serial=3
	house.completed_jobs=[1,2,3];house.last_settled_day=GameClock.day
	var layout: Dictionary=Housing.reconciled_furniture(house)
	house.placed=layout.placed;house.recovered=layout.recovered;house.builtins=layout.builtins
	Housing.restore(house)

static func caught_eternal() -> void:
	caught_species(["eternal"])

static func next_weighted_cast(species: String, site: String="farm_lake") -> bool:
	# Select a reproducible ordinary weighted draw for an integration fixture.
	# The shipped game has no forced encounter or test-only RNG override.
	if Fishing.active() or Fishing.state.pending!="" or species not in Fishing.available_species(site): return false
	var first: int=int(Fishing.state.serial)+1
	var limit: int=mini(first+1024,GameClock.day*12+1)
	for serial in range(first,limit):
		if Fishing.choose_species(site,serial)!=species: continue
		var fishing: Dictionary=Fishing.snapshot()
		fishing.serial=serial-1;fishing.casts_day=GameClock.day
		fishing.casts=mini(11,maxi(1,int(fishing.serial)-(GameClock.day-1)*12))
		Fishing.restore(fishing)
		return Fishing.validate(Fishing.snapshot(),GameClock.day)
	return false

static func caught_species(species: Array) -> void:
	var fishing: Dictionary=Fishing.snapshot()
	fishing.pending="";fishing.pending_day=0
	fishing.rod=3
	for id in species:
		if int(fishing.counts.get(id,0))<1: fishing.counts[id]=1
		if id not in fishing.collection: fishing.collection.append(id)
	# 保留已有钓获；此夹具只补齐对应的经验与真实尝试元数据，不发放鱼物品。
	fishing.total=0;fishing.xp=0
	for id in fishing.counts:
		fishing.total+=int(fishing.counts[id])
		fishing.xp+=int(fishing.counts[id])*int(Fishing.data.species[id].xp)
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
	if int(fishing.counts.get("eternal",0))>0: fishing.legend_season=Calendar.season_serial()
	Fishing.restore(fishing)
	Fishing.update_achievements()
