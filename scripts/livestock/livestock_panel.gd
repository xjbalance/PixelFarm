extends PanelContainer
## 当面确认后请求状态层；只有一个待确认回调，关闭和加载会清空。
var content: VBoxContainer
var context: String = "coop"
var pending := Callable()
var confirm_text: String = ""
var quantity: int = 1
var section: VBoxContainer

func _ready() -> void:
	add_to_group("modal_panels");hide()
	var column := VBoxContainer.new();add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := FarmUIStyle.label("南庭畜舍 · 周砚的饲养手册",24,FarmUIStyle.TITLE)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(FarmUIStyle.button("收起 ×",close_panel,100))
	DiamondPayments.controls(column,refresh)
	var scroll := ScrollContainer.new();scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll);content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12);scroll.add_child(content)
	FacilityLayout.decorate(self,"livestock","为动物安排住处、干草与每天的照料。")

func words(text: String, size: int = 18) -> void:
	FacilityLayout.text(section if is_instance_valid(section) else content,text,size)

func button(text: String, action: Callable) -> Button:
	var control := FarmUIStyle.button(text,action,160);(section if is_instance_valid(section) else content).add_child(control);return control

func open_panel(id: String) -> void:
	if GameState.modal: return
	if id.begins_with("animal:"):
		if not Livestock.near_animal(id.trim_prefix("animal:")): return
	elif not Livestock.near_site(id): return
	context=id;quantity=1;pending=Callable();confirm_text=""
	GameState.set_modal(true);show();refresh()

func close_panel() -> void:
	pending=Callable();confirm_text=""
	lock_payment(false);DiamondPayments.cancel(self)
	hide();GameState.set_modal(false)

func lock_payment(locked: bool) -> void:
	for control in get_tree().get_nodes_in_group("payment_toggle"):
		if is_ancestor_of(control): control.disabled=locked

func ask(text: String, callback: Callable) -> void:
	if pending.is_valid(): return
	confirm_text=text;pending=callback;refresh()

func accept() -> void:
	var callback := pending
	pending=Callable();confirm_text=""
	if visible and callback.is_valid(): callback.call()
	refresh()

func result(success: bool) -> void:
	if not success: Events.notice.emit("条件不满足、今天已办理或资源不足；动物与材料已保留。")
	refresh()

func costs(required: Dictionary) -> String:
	var parts: Array[String]=[]
	for item in required: parts.append("%s%d（持有%d）" % [Catalog.item_name(item),int(required[item]),Inventory.count(item)])
	return "、".join(parts)

func refresh() -> void:
	section=null
	if not visible: return
	lock_payment(pending.is_valid())
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if pending.is_valid():
		words("确认本次操作",23);words(confirm_text,21)
		button("确认",accept);button("取消",func(): pending=Callable();confirm_text="";refresh());return
	words("第%d天 · %d金 · 干草%d · 钻石%d" % [GameClock.day,Inventory.coins,Inventory.count("hay"),Xiaojing.state.diamonds],16)
	if context.begins_with("animal:"):
		show_animal(context.trim_prefix("animal:"));return
	show_building(context)

func show_building(site: String) -> void:
	var b: Dictionary=Livestock.building(site)
	var definition: Dictionary=Livestock.data.buildings[site]
	section=FacilityLayout.card(content,"animal_housing")
	words(definition.name,23)
	if b.level==0:
		words("周砚：‘屋后的南庭不挡耕地，窝棚的门朝着草坪。先把吃的和住的准备好，再接幼畜回来。’")
		words("一级容量2只。建造需要"+costs(definition.required)+"、"+DiamondPayments.text(int(definition.coins))+"。")
		button("建造"+definition.name,func(): ask("消耗"+costs(definition.required)+"与"+DiamondPayments.text(int(definition.coins))+"建造？",func(): DiamondPayments.request(self,int(definition.coins),func(): result(Livestock.build(site)))))
		section=null;show_feed_shop();return
	var s: Dictionary=Livestock.summary(site)
	var species: Dictionary=Livestock.data.species[definition.species]
	FacilityLayout.metrics(section,[["畜舍等级",str(b.level)],["动物",str(s.count)+" / "+str(s.capacity)],["成年动物",str(s.adults)],["待收产物",str(s.products),FarmUIStyle.SUCCESS]])
	words("%s需%d个足食成长日成年；成年后每%d个合格照料日生产%s。每只每天%d份干草，每只最多暂存3份产物。" % [species.name,species.growth_days,species.cycle,Catalog.item_name(species.product),species.feed],16)
	button("接回一只"+species.young_name+" · "+DiamondPayments.text(int(species.price)),func(): ask("接回一只%s？费用%s，幼畜从零成长，容量满时不会扣款。" % [species.young_name,DiamondPayments.text(int(species.price))],func(): DiamondPayments.request(self,int(species.price),func(): result(Livestock.buy_animal(site))))).disabled=s.count>=s.capacity
	if b.level<3:
		var upgrade: Dictionary=Livestock.data.upgrades[str(int(b.level)+1)]
		button("升级 · "+upgrade.name,func(): ask("保留全部动物与产物，扩容至%d只。消耗%s与%s？" % [upgrade.capacity,costs(upgrade.required),DiamondPayments.text(int(upgrade.coins))],func(): DiamondPayments.request(self,int(upgrade.coins),func(): result(Livestock.upgrade(site)))))
	section=FacilityLayout.card(content,"animal_care")
	words("放牧与繁育",21)
	words(Livestock.data.rules.description,16)
	button("打开栏门放牧",func(): result(Livestock.graze(site))).disabled=not Livestock.can_graze(site) or b.grazing_day==GameClock.day
	words("繁育：至少两只成年、亲密35、心情60、今日喂好；空位1，间隔%d日。消耗干草%d与%s，幼畜仍需独立照料。" % [species.breed_days,species.breed_hay,DiamondPayments.text(int(species.breed_coins))],16)
	button("确认办理繁育",func(): ask("本次繁育消耗干草%d与%s，满足全部条件才会扣除。继续？" % [species.breed_hay,DiamondPayments.text(int(species.breed_coins))],func(): DiamondPayments.request(self,int(species.breed_coins),func(): result(Livestock.breed(site)))))
	section=null
	words("点击庭院里的动物可抚摸、喂食和收集产物；下列记录用于查看，离得太远时请先收起面板走近。",16)
	for entry in Livestock.animals_at(site):
		section=FacilityLayout.card(content,"animal_record")
		words("%s · 成长%d/%d · 饥饿%d · 心情%d · 亲密%d · 产物%d" % [Livestock.display_name(entry.id),entry.age,species.growth_days,entry.hunger,entry.mood,entry.bond,entry.product],16)
		var id: String=entry.id
		button("照料 "+Livestock.display_name(id),func():
			if Livestock.near_animal(id): context="animal:"+id;refresh()
			else: Events.notice.emit("这只动物在庭院里，先走近它再照料。")
		)
	section=null
	show_feed_shop()

func show_animal(id: String) -> void:
	var entry: Dictionary=Livestock.animal(id)
	if entry.is_empty(): words("动物尚未在这里安顿。请收起后重新查看。");return
	var species: Dictionary=Livestock.data.species[entry.species]
	section=FacilityLayout.card(content,"animal_detail")
	words(Livestock.display_name(id),23)
	FacilityLayout.metrics(section,[["成长",str(entry.age)+" / "+str(species.growth_days)],["饥饿（越低越好）",str(entry.hunger)],["心情",str(entry.mood)],["亲密",str(entry.bond)]])
	words("待收%s%d" % [Catalog.item_name(species.product),entry.product],18)
	words("每天投喂与抚摸各一次；产物只在真正跨日时生成。忘记喂食会慢长、停产，可以恢复，不会删除动物。",16)
	button("投喂 · 干草%d份" % species.feed,func(): result(Livestock.feed(id))).disabled=entry.fed_day==GameClock.day
	button("抚摸 · 1体力",func(): result(Livestock.pet(id))).disabled=entry.pet_day==GameClock.day
	button("收集%s ×%d" % [Catalog.item_name(species.product),entry.product],func(): ask("收取全部%d份%s？背包满时整笔取消，产物仍留给动物。" % [entry.product,Catalog.item_name(species.product)],func(): result(Livestock.collect(id)))).disabled=entry.product<1
	var site: String=entry.site
	button("返回畜舍记录",func(): context=site;refresh()).disabled=not Livestock.near_site(site)
	section=null

func show_feed_shop() -> void:
	section=FacilityLayout.card(content,"feed_supply")
	words("干草补给与制备",21)
	var row := HBoxContainer.new();section.add_child(row)
	row.add_child(FarmUIStyle.label("数量%d" % quantity,18))
	for amount in [-5,-1,1,5]: row.add_child(FarmUIStyle.button(("+" if amount>0 else "")+str(amount),func(): quantity=clampi(quantity+amount,1,99);refresh(),64))
	var amount: int=quantity
	button("购买干草%d份 · %s" % [amount,DiamondPayments.text(amount*4)],func(): ask("购买干草%d份，花费%s？" % [amount,DiamondPayments.text(amount*4)],func(): DiamondPayments.request(self,amount*4,func(): result(Livestock.buy_hay(amount)))))
	button("小麦%d → 干草%d" % [amount,amount*5],func(): ask("使用小麦%d制备干草%d？需附近有已建畜舍，满包则不扣料。" % [amount,amount*5],func(): result(Livestock.make_hay(amount))))
	section=null

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
