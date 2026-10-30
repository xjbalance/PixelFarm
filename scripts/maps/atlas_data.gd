class_name FarmAtlasData
extends RefCounted
## 图纸只读取已经存在的世界状态；各场景拥有独立坐标，地图不传送、不写进度。
const PAPER_SIZE := Vector2(1024,640)
const TITLES := {"pasture_coop":"南庭鸡鸭牧场","pasture_barn":"绿荫牛牧场","pasture_fold":"暖风羊牧场","farm":"玩家农场","home":"我的家","village":"河湾村","lake":"东湖与鱼栏","mist_forest":"迷雾森林","lake_ruins":"湖底遗迹","old_temple":"古老神庙","mine_a":"旧矿道","mine_b":"地下水脉","mine_c":"晶石洞窟","abyss":"百层深渊","greenhouse":"星光温室","east_holding":"河东开发地","lake_holding":"湖畔归属地","forest_holding":"林地开发区","manor_holding":"终局庄园用地"}
const WORLD_POINTS := {"farm":Vector2(428,420),"village":Vector2(514,198),"lake":Vector2(740,442),"mist_forest":Vector2(203,331),"lake_ruins":Vector2(893,505),"old_temple":Vector2(895,282),"mine_a":Vector2(804,131),"greenhouse":Vector2(736,561),"east_holding":Vector2(570,388),"lake_holding":Vector2(840,402),"forest_holding":Vector2(175,500),"manor_holding":Vector2(428,562)}
const WORLD_BRIDGE := Vector2(684,288)
static func bridge_open() -> bool: return Story.stage>=5
static func known(id: String) -> bool:
	if id in RanchLayout.AREAS:
		var site:=RanchLayout.site(id)
		return site in RanchLayout.ENABLED and int(Livestock.building(site).level)>0 and FarmLayout.active(site)
	if id in TerritoryCatalog.ANNEX_AREAS: return Territory.unlocked(id)
	if id in ["farm","home","village","lake"]: return true
	if id in Exploration.AREAS: return Exploration.unlocked(id)
	if id in MineState.AREAS: return id in MineState.state.unlocked
	if id=="abyss": return AbyssState.state.unlocked
	if id=="greenhouse": return Xiaojing.state.unlocked or LegendState.state.greenhouse>0 or Xiaojing.state.married
	return false
static func current_region() -> String: return GameState.location
static func title(id: String) -> String:
	if id in TerritoryCatalog.ANNEX_AREAS: return str(TITLES[id])+("" if known(id) else " · 未开放")
	return str(TITLES.get(id,"区域图纸")) if known(id) else "尚未探索"
static func bounds(id: String) -> Rect2:
	if id in RanchLayout.AREAS: return RanchLayout.world_rect(RanchLayout.site(id))
	if id=="farm": return FarmLayoutCatalog.WORLD
	if id=="lake": return Rect2(Vector2(864,384)+FarmLayout.offset("lake"),Vector2(544,512))
	if id=="home": return HomeLayout.map_rect(int(Housing.state.level)).grow(18)
	return Rect2(0,0,1280,896)
static func world_to_map(id: String, point: Vector2) -> Vector2:
	var rect:=bounds(id)
	return Vector2(64,48)+(point-rect.position)/rect.size*Vector2(896,544)
static func map_to_world(id: String, point: Vector2) -> Vector2:
	var rect:=bounds(id)
	return rect.position+(point-Vector2(64,48))/Vector2(896,544)*rect.size
static func picture(id: String) -> String:
	if id in RanchLayout.AREAS: return "farm_editable_base"
	if id in TerritoryCatalog.ANNEX_AREAS: return "territory"
	if id in ["farm","lake"]: return "farm_editable_base"
	if id in MineState.AREAS or id=="abyss": return "cave"
	return id if id in ["farm","village","lake","home","greenhouse","mist_forest","lake_ruins","old_temple"] else "world"
static func _place(id: String, name_text: String, point: Vector2, region: String, icon: String, text: String, discovered: bool=true) -> Dictionary:
	return {"id":id,"name":name_text,"point":point,"region":region,"icon":icon,"description":text,"discovered":discovered}
static func world_places() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id in WORLD_POINTS:
		var is_known:=known(id)
		var caption: String=title(id)
		var icon: String={"farm":"house_"+str(Housing.state.level),"village":"village","lake":"lake","mist_forest":"forest","lake_ruins":"ruins","old_temple":"temple","mine_a":"mine","greenhouse":"greenhouse"}.get(id,"pin")
		var text:=description(id) if is_known else "雾色遮住了这一角。沿已经开放的道路探索，图纸会随现有发现记录更新。"
		if id in TerritoryCatalog.ANNEX_AREAS:
			text=description(id);icon="field" if is_known else "sign"
		result.append(_place(id,caption,WORLD_POINTS[id],id,icon if is_known else "unknown",text,is_known))
	return result
static func description(id: String) -> String:
	if id in RanchLayout.AREAS:
		var site:=RanchLayout.site(id);var dimensions:=RanchLayout.region(site).size
		return "%s后方的独立自有牧场 · %d×%d格。经舍旁围栏门步行进出；动物与产物使用同一份记录。雨雪、冬季和18:00后回暖舍。图纸只读，不传送。" % [Livestock.data.buildings[site].name,dimensions.x,dimensions.y]
	if id in TerritoryCatalog.ANNEX_AREAS:
		return ("私人领地 · 已开放。可从菜单进入建造模式。" if Territory.unlocked(id) else "未开放 · ")+str(TerritoryCatalog.region(id).hint)+" 图纸仅供查看，请步行到农场东北的领地路牌。"
	match id:
		"farm": return "%s · %d级住宅。96×64格自有土地；原48×32区域坐标不变，东原耕作、南原工坊、果木花园可自由规划。畜舍围栏门通往独立牧场。" % [Housing.level_name(),Housing.state.level]
		"home": return "%s。床、沙发、厨房和收纳位置与玩家已确认的家具布局一致。" % Housing.level_name()
		"village": return "河湾村。旧桥%s；风灯架在广场中央、长椅的右上方。" % ("已经修复" if Story.stage>=5 else "尚未修复，东岸道路暂时阻断")
		"lake": return "农场东侧同一片湖岸，并非独立传送地图。湖泊生态%d/100，%s。" % [LakeEcology.state.health,"循环已恢复" if LakeEcology.state.restored else "仍在照料恢复中"]
		"mist_forest": return "从农场的森林入口进入。林间资源可采集，%s。" % ("深处林径已开放" if Exploration.state.forest.open else "深处林径仍待实地调查")
		"lake_ruins": return "从农场的遗迹检修口进入。%s。图纸只记录已开放区域，不代替机关调查。" % ("检修桥已接通" if Exploration.state.lake.open else "排水检修尚未完成")
		"old_temple": return "从河湾村东岸石门进入。%s。" % ("归航庭光路已接通" if Exploration.state.temple.open else "庭内光路仍待核对")
		"mine_a","mine_b","mine_c": return "%s · 已开放%d/3个矿区。这里只记录出入口；矿脉、宝箱和机关需亲自探索。" % [TITLES[id],MineState.state.unlocked.size()]
		"abyss": return "当前第%d层，已通关%d层，记录检查点第%d层。图纸仅标当前层的返回与下行站位，不提前展开100层。" % [AbyssState.state.depth,AbyssState.state.max_clear,AbyssState.state.checkpoint]
		"greenhouse": return "农场中的星光温室。%s，修复阶段%d/4。" % ["已恢复开放" if LegendState.state.greenhouse>=4 or Xiaojing.state.married else "仍在修复中",mini(4,int(LegendState.state.greenhouse))]
	return "沿真实道路步行前往；这张图纸仅供查看。"
static func region_places(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	if not known(id): return out
	if id in RanchLayout.AREAS:
		var site:=RanchLayout.site(id)
		out.append(_at("pasture_exit","返回自家农场",RanchLayout.entry(site)+Vector2(0,32),id,"sign",description(id),"farm"))
		out.append(_at("shelter","暖舍与照料台",RanchLayout.service(site),id,"barn","每天喂食、抚摸；晴天按原规则开栏，雨雪与傍晚会真正走回暖舍。"))
		out.append(_at("water","饮水盆",RanchLayout.furniture(site).water_basin,id,"lake","围栏内的饮水设施；鸭子不会因此穿过真实湖水。"))
		if site=="coop": out.append(_at("nest","鸡窝 · 鸡蛋与鸭蛋",RanchLayout.nest(site),id,"field","蛋按每只动物安全暂存，点击鸡窝统一收取。满包保留，重复点击不重复领取。"))
	elif id in TerritoryCatalog.ANNEX_AREAS:
		out.append(_at("holding_exit","返回农场",Vector2(640,816),id,"sign","沿入场路牌返回原农场。","farm"))
		out.append(_at("holding_rights",str(TITLES[id])+" · 私人领地",Vector2(320,256),id,"field",description(id)))
		if id=="east_holding": out.append(_at("holding_transition","有限编辑过渡带",Vector2(288,112),id,"sign","允许地表、草簇和花丛；不允许固体物件阻断过渡通路。"))
		for entry in Territory.state.objects:
			if entry.area!=id: continue
			if entry.kind not in ["chest","lamp","bench"]: continue
			var footprint:=TerritoryCatalog.footprint(entry.kind,TerritoryCatalog.to_cell(entry.cell))
			out.append(_at(entry.id,str(TerritoryCatalog.OBJECT_KINDS[entry.kind].name),Vector2(footprint.position)*32+Vector2(footprint.size)*16,id,"lantern" if entry.kind=="lamp" else "house_1" if entry.kind=="chest" else "forest" if entry.kind=="tree" else "field","玩家确认的私人布置；移动后图纸同步，不在图纸上执行编辑。"))
	elif id=="farm":
		out.append(_at("home","住宅 · "+Housing.level_name(),Vector2(656,410),id,"house_"+str(Housing.state.level),"房门在这里，室内厨房与沙发小睡可照常使用。","home"))
		out.append(_at("village_entry","河湾村入口",Vector2(480,216),id,"sign","沿农场北侧道路步行进入河湾村。","village"))
		out.append(_at("shop","林芽的种子摊",Vector2(356,416),id,"market","购买种子、出售农产品与材料；交易仍需到摊位办理。"))
		out.append(_at("plots","农田",Vector2(704,608),id,"field","原有农田地块与作物存档一一对应；地图查看不会播种或收获。"))
		out.append(_at("lake","东湖与鱼栏",Vector2(1104,600),id,"lake",description("lake"),"lake"))
		out.append(_at("forest_entry","西北林径",Vector2(208,320),id,"forest",description("mist_forest"),"mist_forest"))
		out.append(_at("workshop","农场修缮台",Vector2(820,432),id,"workshop","保留已有修缮与卧室升级，查看图纸不会消耗材料。"))
		out.append(_at("board","委托板",Vector2(968,432),id,"sign","在委托板办理或领取原有委托。"))
		for key in Livestock.SITES:
			var name_text: String=str(Livestock.data.buildings[key].name)
			out.append(_at(str(key),name_text,Livestock.SITES[key],id,"barn","%s · 已建%d级。舍旁围栏门连接真实后方牧场；升级只改变原有容量。" % [name_text,Livestock.state.buildings[key].level]))
			if known(RanchLayout.area(str(key))): out.append(_at("pasture_"+str(key),"后方"+str(Livestock.data.species[Livestock.data.buildings[key].species].name)+"牧场",Livestock.gate_point(str(key)),id,"sign",description(RanchLayout.area(str(key))),RanchLayout.area(str(key))))
		var expansion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/farm_layout/expansion082.json"))
		for zone in expansion.zones:
			var data: Dictionary=expansion.zones[zone];var rectangle: Array=data.rect
			out.append(_at("expansion_"+str(zone),str(data.name),Vector2(float(rectangle[0])+float(rectangle[2])*.5,float(rectangle[1])+float(rectangle[3])*.5)*32,id,"field","自有可用土地，可按现有工具开垦、种植、铺路或使用农场DIY。分区是规划参考，不能限制你的布局。"))
		if known("greenhouse"): out.append(_at("greenhouse","星光温室",Vector2(1328,780),id,"greenhouse",description("greenhouse"),"greenhouse"))
		if known("lake_ruins"): out.append(_at("lake_entry","湖东旧阶",Vector2(1296,688),id,"ruins",description("lake_ruins"),"lake_ruins"))
		for area in TerritoryCatalog.ANNEX_AREAS:
			var at: Array=TerritoryCatalog.GATES[area]
			out.append(_at("gate_"+area,title(area),Vector2(at[0],at[1]),id,"sign",description(area),area if known(area) else ""))
	elif id=="village":
		for item in [["tea","禾间茶屋",Vector2(290,357),"market","茶屋与原有阿禾交流地点。"],["workshop","周砚木作",Vector2(520,354),"workshop","周砚提供原有建造与住宅升级服务。"],["lantern","风灯架",Vector2(628,524),"lantern","广场中央、长椅右上方；第一章点灯需18:00后。"],["well","水井",Vector2(370,565),"well","%s。" % ("清泉水井已经建成" if VillageProjects.has_project("well") else "井边的共建计划仍待完成")],["bridge","河湾旧桥",Vector2(868,480),"bridge","%s。" % ("桥已修复，可以步行通过" if Story.stage>=5 else "旧桥尚未修复，不能跨河通行")],["farm_entry","返回农场",Vector2(640,826),"sign","沿南侧主路返回农场。"],["community","共建板",Vector2(680,650),"sign","查看原有水井、共仓和茶座建设。"]]:
			out.append(_at(item[0],item[1],item[2],id,item[3],item[4]))
		out.append(_at("mine_entry","矿道入口" if known("mine_a") else "封闭矿道入口",Vector2(1168,208),id,"mine",description("mine_a") if known("mine_a") else "矿道尚未开放，按第二章调查提示继续。","mine_a" if known("mine_a") else ""))
		if WorldDevelopment.state.dock>0: out.append(_at("dock","河湾码头",Vector2(976,720),id,"dock","已建%d/2级。登记后实际生产再交货；图纸不代替交付。" % WorldDevelopment.state.dock))
		if known("old_temple"): out.append(_at("temple_entry","东岸石门",Vector2(1200,688),id,"temple",description("old_temple"),"old_temple"))
	elif id=="lake":
		out.append(_at("shore","湖岸水样台",LakeEcology.SHORE,id,"well",description("lake")))
		for key in Aquaculture.SITES:
			var at: Vector2=Aquaculture.SITES[key];var pen: Dictionary=Aquaculture.pen(key)
			out.append(_at(key,{"pen_1":"西岸鱼栏","pen_2":"南岸鱼栏","pen_3":"东岸鱼栏","pen_4":"北岸鱼栏"}[key],at,id,"dock","%s · 当前%d尾。" % ["已经建成" if pen.built else "尚未建成",Aquaculture.summary(key).get("total",0)]))
		if known("lake_ruins"): out.append(_at("lake_entry","湖东旧阶",Vector2(1296,688),id,"ruins",description("lake_ruins"),"lake_ruins"))
	elif id=="home":
		for item in Housing.builtin_layout():
			if item.stored or item.id not in HomeLayout.ESSENTIAL: continue
			out.append(_at(str(item.id),str(item.name),item.anchor,id,"bed" if item.id=="bed" else "kitchen" if item.id=="kitchen" else "house_1", "已确认的家具位置；搬动后标记自动更新。"))
		out.append(_at("exit","房门",HomeLayout.ANCHORS.exit,id,"sign","步行回到农场门前。","farm"))
	elif id in Exploration.AREAS:
		var entry: Dictionary=Exploration.data.areas[id]
		out.append(_at(str(entry.exit),"返回"+("农场" if entry.return_area=="farm" else "河湾村"),Exploration.point(entry.exit),id,"sign","沿原入口回到外部地区。",str(entry.return_area)))
		for key in Exploration.state.facts:
			if not Exploration.data.points.has(key) or Exploration.data.points[key].area!=id: continue
			out.append(_at(str(key),str(Exploration.data.points[key].title),Exploration.point(key),id,"sign","这条记录已在实地调查后收录。"))
	elif id in MineState.AREAS:
		var layout: Dictionary=MineState.layouts[id]
		for entry in layout.objects:
			if entry.kind!="exit": continue
			out.append(_at(str(entry.id),"矿区出入口",MineState.point(entry),id,"mine","这是原矿区出入口，按实际通行规则步行使用。"))
		if id=="mine_c" and AbyssState.state.unlocked: out.append(_at("abyss","深渊升降机",Vector2(208,688),id,"mine",description("abyss"),"abyss"))
	elif id=="abyss":
		out.append(_at("entry","本层抵达点",AbyssState.point(AbyssState.layout().entry),id,"mine",description(id)))
		for pair in [["up","返回升降机"],["down","下行站位"]]:
			var map: Node=WorldTravel.maps(AbyssState.game).get("abyss") if is_instance_valid(AbyssState.game) else null
			if is_instance_valid(map) and map.objects.has(pair[0]): out.append(_at(pair[0],pair[1],map.objects[pair[0]].global_position,id,"mine",description(id)))
	elif id=="greenhouse":
		out.append(_at("venue_exit","返回农场",Vector2(640,780),id,"greenhouse",description(id),"farm"))
		out.append(_at("archive","档案与协作桌",Vector2(800,320),id,"workshop","这里承载原有温室档案和协作，地图不会触发剧情或仪式。"))
	if id in ["farm","lake"]:
		var fixtures: Dictionary={"home":"home","village_entry":"village_gate","shop":"shop","lake":"lake","workshop":"workshop","board":"board","forest_entry":"explore:forest_entry","lake_entry":"explore:lake_entry","coop":"coop","barn":"barn","fold":"fold","greenhouse":"greenhouse","shore":"ecology","pen_1":"pen_1","pen_2":"pen_2","pen_3":"pen_3","pen_4":"pen_4"}
		for area in TerritoryCatalog.ANNEX_AREAS: fixtures["gate_"+area]="gate:"+area
		if id=="farm":
			var total:=Vector2.ZERO;var count: int=0
			for y in range(16,22):
				for x in range(17,27):
					var key: String="%d,%d" % [x,y]
					if FarmLayout.stored("plot",key): continue
					total+=Vector2(FarmLayout.cell("plot",key))*32+Vector2(16,16);count+=1
			for item in out.duplicate():
				if item.id!="plots": continue
				if count==0: out.erase(item)
				else: item.world_position=total/count;item.point=world_to_map(id,item.world_position)
		for item in out.duplicate():
			var fixture: String=str(fixtures.get(item.id,""))
			if fixture=="": continue
			if not FarmLayout.active(fixture): out.erase(item);continue
			item.world_position=FarmLayout.point(fixture)
			item.point=world_to_map(id,item.world_position)
	return out
static func _at(id: String, name_text: String, world: Vector2, map_region: String, icon: String, text: String, detail_region: String="") -> Dictionary:
	var info:=_place(id,name_text,world_to_map(map_region,world),detail_region,icon,text)
	info.world_position=world;info.map_region=map_region
	return info
static func player_region_matches(region: String) -> bool: return GameState.location==region or (region=="lake" and GameState.location=="farm")
static func resource_marks(id: String, resources: Dictionary={}) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var area: String="farm" if id=="lake" else id
	if area not in ["farm","village","mist_forest"]: return result
	var placements:=FarmResourceCatalog.placements(area)
	for key in placements:
		var entry: Dictionary=placements[key]
		var point: Vector2=Vector2(entry.cell)*32
		if area=="farm":
			if FarmResourceCatalog.stored(str(key)): continue
			point=FarmResourceCatalog.point(str(key))
		if not bounds(id).has_point(point): continue
		result.append({"id":key,"point":world_to_map(id,point),"kind":entry.kind,"available":int(resources.get(key,{}).get("hp",1))>0})
	return result
static func player_world_region() -> String:
	if GameState.location=="home" or GameState.location in RanchLayout.AREAS: return "farm"
	if GameState.location in MineState.AREAS or GameState.location=="abyss": return "mine_a"
	return GameState.location
