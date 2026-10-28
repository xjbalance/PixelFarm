extends "res://scripts/ui/mine_panel.gd"
func _ready() -> void:
	super._ready()
	panel_title.text="百层深渊 · 探索与试炼"
func open_panel(id: String = "legend") -> void:
	if GameState.modal: return
	context=id
	reading=false
	pending=Callable()
	if id=="note":
		var d: Dictionary=AbyssState.layout()
		read("第%d层 · %s" % [AbyssState.state.depth,d.title],d.record+"\n机关刻痕："+d.clue+"。\n"+AbyssRules.inspect_text()+"\n手柄依次标作风、水、灯、人；错误复位，先对照记录。",func(): AbyssState.read_note())
	GameState.set_modal(true)
	show()
	refresh()
func act(callback: Callable) -> void:
	if not callback.call(): Events.notice.emit("条件、现场或物资尚未满足；记录保留，没有多扣资源。")
	refresh()
func refresh() -> void:
	if reading:
		super.refresh()
		return
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	if context=="entrance":
		words("深渊升降机 · 五区开放1–100层",23)
		words("五个区域各二十层，每十层检查点，每二十层独立档案机关。先完成矿道讨论会并取得星纹镐、开启共鸣门。")
		if not AbyssState.state.unlocked: button("检查升降机并登记探索",func(): act(AbyssState.unlock))
		else:
			for depth in AbyssState.checkpoints():
				if depth<=maxi(1,int(AbyssState.state.max_clear)):
					button("从%d层检查点继续" % depth,func(): close_panel(); AbyssState.enter(depth))
			button("旧16–20层支线补给：十矿全尽且间隔三日 · 麦6木6铁2",func(): act(AbyssState.survey))
	elif context=="passage":
		words("原检修路仍可走。木材2可固定侧廊支架，缩短到补给匣的路；留意廊中的预警，也可先在入口固定安全设施。")
		button("确认固定支架 · 木材2",func(): act(AbyssRules.open_passage))
	elif context=="up":
		words("第%d层 %s · 空气%d/160 · 护具%d" % [AbyssState.state.depth,AbyssState.layout().title,AbyssState.state.air,AbyssState.state.gear],22)
		words("升降绳始终保留，错误机关不会封住退路。护具可减少新格空气消耗，采矿另耗空气；预警后可绕行或固定本层护栏。21–100层矿脉三日自然更新，箱子不刷新。")
		button("固定安全护栏/滤网 · 木1晶1（本层一次）",func(): act(AbyssRules.secure))
		button("沿安全绳回晶石洞窟",func(): close_panel(); AbyssState.leave())
		button("营地整备 · 麦2木2，每日一次（检查点层）",func(): act(AbyssState.camp))
		button("补给 · 麦3土豆1，恢复36空气，每趟最多3次",func(): act(AbyssState.ration))
	elif context=="forge":
		words("勘探护具%d/7 · 已完成%d/100层" % [AbyssState.state.gear,AbyssState.state.max_clear],23)
		if AbyssState.state.gear<7:
			var r: Dictionary=AbyssState.config.gear[str(int(AbyssState.state.gear)+1)]
			words("完成第%d层后升级：" % r.depth+costs(r.required)+" · "+DiamondPayments.text(int(r.coins)))
			button("确认升级深渊护具",func(): DiamondPayments.request(self,int(r.coins),func(): act(AbyssState.upgrade)))
	elif context=="conduit":
		words("回路分工："+("5→12→20" if River.state.legacy_rules or River.state.old_contract=="mechanism" else "20→60→100")+"层依次校准；先完成七记忆与最终推理。")
		button("按本层原件校准实体回路",func(): act(LegendTrials.conduit))
	else: build_legend()
	button("收起",close_panel)
func build_legend() -> void:
	words("第1314颗星星 · 传说约定",24)
	words("温室%d/5阶段 · 最终推理%d/3 · 强化试炼%d/5 · 深渊%d/100层\n好感来自交流与礼物，信任来自调查与践行，羁绊来自共同活动和守约。" % [LegendState.state.greenhouse,LegendState.state.deduction,LegendState.state.trials.size(),AbyssState.state.max_clear])
	if LegendState.state.legacy_vow:
		words("旧档已确认的婚约与已完成任务保留；已经结婚不受影响。尚未结婚仍需完成当前住宅与传说鱼准备。")
	if not Xiaojing.state.married: words(Xiaojing.marriage_goals_text(),17)
	for i in range(5):
		var stage: Dictionary=LegendState.data.greenhouse[i]
		words(("✓ " if i<int(LegendState.state.greenhouse) else "○ ")+stage.title+" · "+costs(stage.required)+(" · 1314钻石，仅婚礼最终确认" if i==4 else " · "+DiamondPayments.text(int(stage.coins))),17)
	words("清理需先修气窗；结构需12约定；水源需水井和12层原件；能源核心需最终推理、20层与制作链试炼。")
	if LegendState.state.greenhouse<4:
		var r: Dictionary=LegendState.data.greenhouse[int(LegendState.state.greenhouse)]
		button("确认下一阶段温室修复",func(): DiamondPayments.request(self,int(r.coins),func(): act(LegendState.repair)))
	if LegendState.state.deduction==3 and LegendState.state.choice=="":
		button("决定：清水优先，保留居民灌溉位置",func(): act(func(): return LegendState.choose("water_first")))
		button("决定：公开档案，让检修与用水共同登记",func(): act(func(): return LegendState.choose("open_records")))
	words("最终推理：桥上水线对10层账，池岸退路对12层水管，茶屋名单对20层签名。先集齐七记忆，再亲读这三份原件。错证需回原件复核，不能连续乱按。")
	for pair in [["bridge",10],["pond",12],["post",20],["window",20]]:
		button("拼接 %s ↔ 第%d层原件" % [pair[0],pair[1]],func(): act(func(): return LegendState.infer(pair[0],pair[1])))
	if not LegendTrials.active():
		for id in LegendTrials.IDS:
			if id not in LegendState.state.trials: button("开始强化试炼 · "+trial_label(id),func(): act(func(): return LegendTrials.begin(id)))
	else:
		var c: Dictionary=LegendState.state.contract
		words(trial_label(c.id)+"\n"+trial_rules(c.id)+"\n"+"第%d天接取 · 新播%d · 标准种值%d · 新田销售%d\n作物记录%s · 已加工%s\n层数%d（旧约11/新约21） · 回路%d/3 · 协作%d/3" % [c.day,c.plants,c.budget,c.sales,items_text(c.harvest),items_text(c.crafted),c.depths.size(),c.conduits.size(),c.coop.size()],16)
		button("安装本轮制作的供水分流器",func(): act(LegendTrials.fabricate))
		button("返回温室核对并结算强化试炼",func(): act(LegendTrials.finish))
		button("取消本轮试炼（完成徽记不清除）",LegendTrials.cancel)
	words("强化版完成也认可同类型原试炼，无需重复做基础版。")
	words("守约：先到小京身边约次日晚间茶座。联合考察：当面拜访林芽/周砚/阿禾，在原交谈中选择分工。1314钻石始终只在右桌的婚礼最终确认扣除一次。")
func trial_label(id: String) -> String:
	return {"management":"三作轮作经营","planning":"有限物资制作链","cave":"80至100层归航考察","mechanism":"风水灯三段回路","joint":"种源与居民联合考察"}[id]
func trial_rules(id: String) -> String:
	var deep: String="10–20" if River.state.legacy_rules or River.state.old_contract=="cave" else "80–100"
	var lamps: String="5→12→20" if River.state.legacy_rules or River.state.old_contract=="mechanism" else "20→60→100"
	var joint: String="20" if River.state.legacy_rules or River.state.old_contract=="joint" else "100"
	return {"management":"12日内≤120种子、种值≤2800，三种各新收24，净销售≥3500。","planning":"四日内本轮加工铜锭2铁锭3合金1，现场制作分流器，用木≤24石≤16。","cave":"实际完成"+deep+"各层出口记录，不被救援，余空气≥10。","mechanism":"完成最终推理，按"+lamps+"顺序步行校准三处实体回路。","joint":"本轮三作各收12交林芽；周砚核检修方案；本轮重访"+joint+"层向阿禾核对，并完成守约。"}[id]

func items_text(values: Dictionary) -> String:
	var parts: Array[String]=[]
	for id in values: parts.append(Catalog.item_name(id)+"×"+str(values[id]))
	return "、".join(parts) if not parts.is_empty() else "尚无"
