extends "res://scripts/ui/mine_panel.gd"
var ecology_section: VBoxContainer
func _ready() -> void:
	super()
	content_cards=false
	FacilityLayout.set_title(self,"湖泊生态 · 水循环与星痕")
	FacilityLayout.decorate(self,"ecology","从一片水草开始，慢慢照料湖水的呼吸。")

func words(text: String, size: int=18) -> void:
	FacilityLayout.text(ecology_section if is_instance_valid(ecology_section) else content,text,size)

func button(text: String, callback: Callable) -> Button:
	var control:=FarmUIStyle.button(text,callback,180)
	(ecology_section if is_instance_valid(ecology_section) else content).add_child(control)
	return control

func open_panel(_id: String = "lake") -> void:
	if GameState.modal or not LakeEcology.near(): return
	pending=Callable();GameState.set_modal(true);show();refresh()
func refresh() -> void:
	ecology_section=null
	if not visible: return
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	words("同一片湖的水样记录",23)
	FacilityLayout.metrics(content,[["湖泊生态",str(LakeEcology.state.health)+" / 100",FarmUIStyle.SUCCESS],["水草",str(LakeEcology.state.plants)+" / 6"],["淤积",str(LakeEcology.state.debris)+" / 3"],["水循环","已修复" if LakeEcology.state.cycle else "待修复"]])
	words("恢复研究："+("已完成" if LakeEcology.state.restored else "进行中"),16)
	words("鱼栏超过八成容量、差水质和暴雨淤积会缓慢影响生态。控制密度、清理、水草和水循环可恢复，鱼群不会突然消失。生态≥90会提高适宜鱼苗成长，生态<35会放慢成长。",16)
	ecology_section=FacilityLayout.card(content,"lake_care")
	words("日常照料",21)
	button("清理湖岸 · 每日一次 / 4体力",func(): outcome(LakeEcology.clean()))
	button("种植水草 · 小麦2 木1 / 2体力",func(): outcome(LakeEcology.plant()))
	if not LakeEcology.state.cycle:
		words("至少种3片水草后可修复水循环：木12 石10 铜锭2，"+DiamondPayments.text(180))
		button("确认材料 · 修复水循环",func(): DiamondPayments.request(self,180,func(): outcome(LakeEcology.repair_cycle())))
	ecology_section=FacilityLayout.card(content,"lake_record")
	words("恢复记录",21)
	words("环保委托：生态≥90、水草≥3、修复水循环并清淤，记录恢复。奖励80金、草鱼苗2，唯一结算。")
	button("提交恢复记录",func(): outcome(LakeEcology.complete_restoration()))
	ecology_section=FacilityLayout.card(content,"lake_nights")
	words("月夜与星痕",21)
	button("记录满月倒影 · 月影笺",func(): outcome(Exploration.observe_moon())).disabled=not GameWeather.is_moon_night() or "moon_reflection" in Exploration.state.facts
	if "moon_reflection" in Exploration.state.facts: words("月亮的倒影被水纹轻轻分开。你把清楚的那一刻画在纸上，留作湖面月影笺。",18)
	words("季内15日晴朗或薄云，20:00后有特殊满月夜。到湖岸现场记录倒影，可得唯一月影收藏。",16)
	button("观察今晚湖面星痕",func(): outcome(LakeEcology.observe_meteor())).disabled=not GameWeather.is_meteor_night() or LakeEcology.state.meteor_seen
	ecology_section=FacilityLayout.card(content,"lake_research")
	words("共同研究",21)
	words("小京的后续水样：原三日湖畔合作完成且生态恢复后，在她09–18点做水样时交流；独立信任/羁绊小幅奖励只一次。",16)
	button("和小京比较新旧水样",func(): outcome(LakeEcology.xiaojing_after()))
	words("修复记录是继续调查湖底排水设施的线索；高生态、流星夜与原小京共同照料也是永恒星鲤的条件。",16)
	button("收起水样册",close_panel)
	ecology_section=null
func outcome(ok: bool) -> void:
	if not ok: Events.notice.emit("今天已照料、材料/体力/前置不满足，或不在合适时间；没有重复扣除或发奖。")
	refresh()
