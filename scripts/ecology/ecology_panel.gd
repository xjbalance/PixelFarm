extends "res://scripts/ui/mine_panel.gd"
func _ready() -> void:
	super()
	get_child(0).get_child(0).get_child(0).text="湖泊生态 · 水循环与星痕"

func open_panel(_id: String = "lake") -> void:
	if GameState.modal or not LakeEcology.near(): return
	pending=Callable();GameState.set_modal(true);show();refresh()
func refresh() -> void:
	if not visible: return
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	words("同一片湖的水样记录",23)
	words("生态%d / 100 · 水草%d / 6 · 淤积%d / 3\n水循环%s · 恢复研究%s" % [LakeEcology.state.health,LakeEcology.state.plants,LakeEcology.state.debris,"已修复" if LakeEcology.state.cycle else "待修复","已完成" if LakeEcology.state.restored else "进行中"])
	words("鱼栏超过八成容量、差水质和暴雨淤积会缓慢影响生态。控制密度、清理、水草和水循环可恢复，鱼群不会突然消失。生态≥90会提高适宜鱼苗成长，生态<35会放慢成长。",16)
	button("清理湖岸 · 每日一次 / 4体力",func(): outcome(LakeEcology.clean()))
	button("种植水草 · 小麦2 木1 / 2体力",func(): outcome(LakeEcology.plant()))
	if not LakeEcology.state.cycle:
		words("至少种3片水草后可修复水循环：木12 石10 铜锭2，"+DiamondPayments.text(180))
		button("确认材料 · 修复水循环",func(): DiamondPayments.request(self,180,func(): outcome(LakeEcology.repair_cycle())))
	words("环保委托：生态≥90、水草≥3、修复水循环并清淤，记录恢复。奖励80金、草鱼苗2，唯一结算。")
	button("提交恢复记录",func(): outcome(LakeEcology.complete_restoration()))
	button("观察今晚湖面星痕",func(): outcome(LakeEcology.observe_meteor())).disabled=not GameWeather.is_meteor_night() or LakeEcology.state.meteor_seen
	words("小京的后续水样：原三日湖畔合作完成且生态恢复后，在她09–18点做水样时交流；独立信任/羁绊小幅奖励只一次。",16)
	button("和小京比较新旧水样",func(): outcome(LakeEcology.xiaojing_after()))
	words("修复记录是继续调查湖底排水设施的线索；高生态、流星夜与原小京共同照料也是永恒星鲤的条件。",16)
	button("收起水样册",close_panel)
func outcome(ok: bool) -> void:
	if not ok: Events.notice.emit("今天已照料、材料/体力/前置不满足，或不在合适时间；没有重复扣除或发奖。")
	refresh()
