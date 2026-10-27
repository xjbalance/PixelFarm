extends PanelContainer
## 湖岸事务面板：确认只保留一个回调，关闭/加载立即丢弃待办。
var section: VBoxContainer
var content: VBoxContainer
var context: String = "pen_1"
var page: String = "pen"
var quantity: int = 1
var pending := Callable()
var confirm_text: String = ""

var tab_bar: HBoxContainer
func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := FarmUIStyle.label("湖畔物语 · 岸边养殖",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	tab_bar=HBoxContainer.new()
	column.add_child(tab_bar)
	for entry in [["pen","鱼栏管理"],["shop","补给与鱼谱"],["craft","加工料理"],["quests","湖畔委托"]]:
		var target: String=entry[0]
		var tab:=FarmUIStyle.button(entry[1],func():
			if not pending.is_valid(): page=target; refresh()
		,180)
		tab.set_meta("facility_tab",target);tab_bar.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	FacilityLayout.decorate(self,"fishpen","照料四岸鱼栏，留意鱼群成长与水质。")

func words(text: String, size: int = 18) -> void:
	FacilityLayout.text(section if is_instance_valid(section) else content,text,size)

func button(text: String, callback: Callable) -> Button:
	var control := FarmUIStyle.button(text,callback,160)
	(section if is_instance_valid(section) else content).add_child(control)
	return control

func open_panel(id: String = "pen_1") -> void:
	if GameState.modal or (id!="guide" and not Aquaculture.near_pen(id)): return
	context=id
	page="pen"
	quantity=1
	pending=Callable()
	GameState.set_modal(true)
	show()
	refresh()

func close_panel() -> void:
	pending=Callable()
	confirm_text=""
	lock_payment(false)
	DiamondPayments.cancel(self)
	hide()
	GameState.set_modal(false)

func ask(text: String, callback: Callable) -> void:
	if pending.is_valid(): return
	confirm_text=text
	pending=callback
	refresh()

func accept() -> void:
	var callback := pending
	pending=Callable()
	confirm_text=""
	if visible and Aquaculture.near_pen(context) and callback.is_valid(): callback.call()
	refresh()

func result(success: bool) -> void:
	if not success: Events.notice.emit("条件不满足、材料不足或已完成本次操作；鱼群与资源已保留。")
	refresh()

func quantities() -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	row.add_child(FarmUIStyle.label("本次数量：%d" % quantity,20,FarmUIStyle.TEXT))
	for amount in [-5,-1,1,5]:
		row.add_child(FarmUIStyle.button(("+" if amount>0 else "")+str(amount),func(): quantity=clampi(quantity+amount,1,99);refresh(),72))

func cost_text(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for id in required: parts.append("%s%d（持有%d）" % [Catalog.item_name(id),int(required[id]),Inventory.count(id)])
	return "、".join(parts)

func refresh() -> void:
	section=null
	if not visible: return
	FacilityLayout.tabs(tab_bar,page)
	lock_payment(pending.is_valid())
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认本次操作",23)
		words(confirm_text,21)
		button("确认",accept)
		button("取消",func(): pending=Callable();confirm_text="";refresh())
		return
	words("第%d天 · %d金 · 钻石%d" % [GameClock.day,Inventory.coins,Xiaojing.state.diamonds],16)
	if context=="guide":
		show_guide()
		return
	match page:
		"shop": show_shop()
		"craft": show_craft()
		"quests": show_quests()
		_: show_pen()

func show_pen() -> void:
	var p: Dictionary=Aquaculture.pen(context)
	if not Aquaculture.available(context):
		words("这里是预留湖岸。先将已有鱼栏升级为加固鱼栏，开放东岸；生态鱼栏开放北岸。")
		return
	if not p.built:
		var definition: Dictionary=Aquaculture.data.levels["1"]
		words("周砚留下的鱼栏图纸",23)
		if context in ["pen_3","pen_4"]: words("新增外围栏施工会短时影响湖泊生态−3，种草与清理可以恢复。",16)
		words("‘木架靠岸，网箱留在水里。下雨也不用踩进湖水。’\n建造"+definition.name+"："+cost_text(definition.required)+"，"+DiamondPayments.text(int(definition.coins))+"。初始容量12尾。")
		button("建造鱼栏",func(): ask("建造普通鱼栏，消耗"+cost_text(definition.required)+"与"+DiamondPayments.text(int(definition.coins))+"？",func():
			DiamondPayments.request(self,int(definition.coins),func(): result(Aquaculture.build(context)))
		))
		return
	var s: Dictionary=Aquaculture.summary(context)
	words("%s · %s" % [{"pen_1":"西岸","pen_2":"南岸","pen_3":"东岸","pen_4":"北岸"}[context],Aquaculture.data.levels[str(int(p.level))].name],23)
	FacilityLayout.metrics(content,[["鱼苗",str(s.fry)],["成年鱼",str(p.adults)],["水质",str(p.water)],["健康",str(p.health),FarmUIStyle.SUCCESS]])
	words("%s · 容量%d · 储备饲料%d" % ["空鱼栏" if p.species=="" else Aquaculture.data.species[p.species].name,s.capacity,p.feed_stock],17)
	if p.species!="":
		var fish: Dictionary=Aquaculture.data.species[p.species]
		words("正常照料%d天成熟；本栏按每批鱼苗独立长大。推荐水质≥%d，至少%d尾成年鱼才会繁殖。\n今天%s；下次结算需饲料%d份。饥饿会慢长，不会突然失去鱼群。" % [fish.growth_days,fish.water,fish.min_adults,"已投喂" if p.last_feed_day==GameClock.day else "尚未投喂",s.feed_needed],16)
		for cohort in p.cohorts: words("鱼苗%d尾 · 成长%.2f / %d天" % [cohort.count,float(cohort.age)/4.0,fish.growth_days],16)
		words("繁殖照料进度%d / %d；需要足够水质、健康、空间和适宜季节。" % [p.breeding,fish.breed_days],16)
	quantities()
	for species in Aquaculture.data.species:
		if p.species!="" and p.species!=species: continue
		var fish: Dictionary=Aquaculture.data.species[species]
		var amount := quantity
		if Aquaculture.species_unlocked(species):
			var feed_extra: int=maxi(0,ceili(float(int(s.total)+amount)/8)-ceili(float(p.fed_count)/8)) if p.last_feed_day==GameClock.day else 0
			button("投放%s鱼苗%d尾（持有%d）" % [fish.name,amount,Inventory.count("fry_"+species)],func(): ask("投放%s鱼苗%d尾？需等级%d鱼栏，满栏或混养时不会扣除。%s" % [fish.name,amount,fish.level,"\n今天已投喂，扩大鱼群还需鱼饲料%d份；与鱼苗一起扣除。" % feed_extra if feed_extra>0 else ""],func(): result(Aquaculture.stock(context,species,amount))))
	if int(s.total)>0:
		button("投喂一次 · 鱼饲料%d份" % s.feed_needed,func(): result(Aquaculture.feed(context))).disabled=p.last_feed_day==GameClock.day
		if p.adults>0:
			var amount := mini(quantity,int(p.adults))
			button("收获%d尾成年鱼" % amount,func(): ask("收获%d尾%s？余下成年鱼保留作种鱼。背包不足时整笔取消。" % [amount,Aquaculture.data.species[p.species].name],func(): result(Aquaculture.harvest(context,amount))))
			var all_fish: int=p.adults
			button("收获全部%d尾成年鱼" % all_fish,func(): ask("收获全部%d尾成年鱼？鱼苗保留，繁殖需要重新养大种鱼。" % all_fish,func(): result(Aquaculture.harvest(context,all_fish))))
	button("检查 / 清理网面 · 每日一次（最多2体力）",func(): result(Aquaculture.maintain(context))).disabled=p.last_maintain_day==GameClock.day
	if p.level==3:
		var reserve := quantity
		button("存入自动投喂饲料%d份" % reserve,func(): ask("存入%d份饲料？日结算时缺手动投喂会自动使用。" % reserve,func(): result(Aquaculture.feed_reserve(context,reserve))))
	if p.level<3:
		var next_level: Dictionary=Aquaculture.data.levels[str(int(p.level)+1)]
		button("升级为"+next_level.name,func(): ask("保留全部鱼群，升级消耗"+cost_text(next_level.required)+"与"+DiamondPayments.text(int(next_level.coins))+"。",func():
			DiamondPayments.request(self,int(next_level.coins),func(): result(Aquaculture.upgrade(context)))
		))
	words("西、南两岸最初开放；升级可扩展东、北两岸。每个栏位一次只养一种鱼，收空后可以换种。",16)

func show_shop() -> void:
	words("林芽的湖岸补给 · 鱼谱",23)
	words("普通鱼苗与饲料可用金币或钻石购买；珍稀鱼苗需要实际养殖和矿区探索后培育，材料条件不因支付方式改变。",16)
	quantities()
	var grid:=FarmUIStyle.section_grid(content)
	for species in Aquaculture.data.species:
		section=FarmUIStyle.section(grid)
		var fish: Dictionary=Aquaculture.data.species[species]
		var icon := TextureRect.new()
		icon.texture=load("res://assets/aquaculture/fish_"+species+".png")
		icon.custom_minimum_size=Vector2(64,48)
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		section.add_child(icon)
		words("%s · %s · %d天 · 售价%d金" % [fish.name,fish.rarity,fish.growth_days,fish.sell_price],20)
		words(fish.feature+"\n来源："+fish.source+"\n用途："+fish.use+"\n收藏："+("已亲手收获" if species in Aquaculture.state.collection else "尚未收获"),16)
		if int(fish.fry_price)>0:
			var amount := quantity
			var cost: int=int(fish.fry_price)*amount
			button("购买%d尾鱼苗 · %s" % [amount,DiamondPayments.text(cost)],func(): ask("购入%s鱼苗%d尾，花费%s？" % [fish.name,amount,DiamondPayments.text(cost)],func(): DiamondPayments.request(self,cost,func(): result(Aquaculture.buy("fry_"+species,amount)))))
		else:
			button("培育1尾"+fish.name+"鱼苗",func(): ask("消耗"+cost_text(fish.rare_cost)+"与"+DiamondPayments.text(int(fish.rare_coins))+"培育1尾？",func(): DiamondPayments.request(self,int(fish.rare_coins),func(): result(Aquaculture.collect_rare(species))))).disabled=not Aquaculture.species_unlocked(species)
		var held: int=Inventory.count("fish_"+species)
		if held>0:
			button("出售全部%s ×%d" % [fish.name,held],func(): ask("出售%s ×%d，获得%d金？" % [fish.name,held,held*int(fish.sell_price)],func(): result(FarmEconomy.sell("fish_"+species,held))))
	section=null
	var amount := quantity
	var cost: int=int(Aquaculture.data.items.fish_feed.price)*amount
	button("购买饲料%d份 · %s" % [amount,DiamondPayments.text(cost)],func(): ask("购买%d份饲料？花费%s。" % [amount,DiamondPayments.text(cost)],func(): DiamondPayments.request(self,cost,func(): result(Aquaculture.buy("fish_feed",amount)))))

func show_craft() -> void:
	words("湖岸加工与料理",23)
	words("用已建鱼栏旁的工具制作；加工立即完成，需要相应设施与材料。持有料理且体力未满时可以继续吃，每次消耗1份，满体力时不消耗。",16)
	quantities()
	var grid:=FarmUIStyle.section_grid(content)
	for id in Aquaculture.data.recipes:
		section=FarmUIStyle.section(grid)
		var recipe: Dictionary=Aquaculture.data.recipes[id]
		words(recipe.name+" · "+recipe.description+"\n每批："+cost_text(recipe.required)+" · 需要等级%d" % recipe.level)
		var amount := quantity
		button("制作%d批" % amount,func(): ask("制作%d批%s？消耗每批所列材料。背包不足则不加工。" % [amount,recipe.name],func(): result(Aquaculture.process(id,amount))))
	section=null
	for item in ["dried_fish","fish_soup"]:
		button("食用"+Catalog.item_name(item)+"（持有%d）" % Inventory.count(item),func(): result(Aquaculture.consume_food(item)))

func show_quests() -> void:
	words("河湾村的湖畔委托",23)
	words("周砚：‘先留两尾种鱼，再想下一季的订单。’\n林芽：‘湖鲜是摊位的新客人，田里的老客人也要照料。’\n阿禾：‘你记下水色，我来记下今天谁尝到了鲜鱼。’")
	for id in ["intro","fresh","research"]:
		words(Aquaculture.quest_status(id),18)
		button("办理 · "+{"intro":"初识湖畔养殖","fresh":"河湾鲜鱼订单","research":"珍稀鱼类研究"}[id],func(): ask("按上方委托要求交付并结算？已领取的唯一奖励不会重复发放。",func(): result(Aquaculture.claim_quest(id))))
	words("小京 · 湖面留下的刻度",23)
	var event: Dictionary=Aquaculture.state.xiaojing
	if event.stage==0:
		words("好感50、信任40后，可以邀请小京一起照料有鱼的栏位。小京想比较湖水和温室旧水管里的微光；这是一份可选研究。")
		button("邀请一起照料这个鱼栏",func(): result(Aquaculture.invite_xiaojing(context)))
	elif event.stage==1:
		words("小京：‘我上午会来做水样。你照料网箱，我记下天气；如果今天没空，明天接着做就好。’\n09:00–18:00可在约定鱼栏的岸边见到小京。需在约定鱼栏的3个不同日期各完成投喂与清理，并在邀请后收获至少2尾鱼。")
		words("已共同照料%d / 3天 · 约定鱼栏：%s" % [event.care_days.size(),event.pen])
		button("一起记录今天的水样",func(): result(Aquaculture.observe_xiaojing()))
		button("交流观察并完成湖畔研究",func(): result(Aquaculture.complete_xiaojing()))
	else:
		words("小京把水样放进自己的背包。‘我会带它去和温室的旧记录比一比。你留的种鱼，明年应该还在这里。’\n星辉线索已保存，羁绊奖励已领取一次。星辉鱼仍需完成珍稀研究、矿区探索与生态鱼栏条件。")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func show_guide() -> void:
	words("周砚的湖岸图纸",23)
	words("‘你家东边的湖可以做小鱼栏。先做西岸和南岸，网留在水里，工具箱放岸上。我把各级的料单写在这里，到现场确认再施工。’")
	for level in Aquaculture.data.levels:
		var definition: Dictionary=Aquaculture.data.levels[level]
		words("%s · 容量%d\n%s，%d金" % [definition.name,definition.capacity,cost_text(definition.required),definition.coins])
	words("本页只看图纸。到农场东湖岸点击木牌/鱼栏，或摇杆靠近按交互，办理建造、投苗、投喂与收获。鱼苗和饲料也可在林芽种子摊购买。",18)
	for id in ["intro","fresh","research"]: words(Aquaculture.quest_status(id),16)
	button("收好图纸",close_panel)

func lock_payment(locked: bool) -> void:
	for control in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(control): control.disabled=locked
