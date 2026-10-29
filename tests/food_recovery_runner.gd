extends "res://tests/runner.gd"
## 用户追加规则：体力未满且持有食物即可连续食用；共享事务锁与单一增益仍安全。
var initial: Dictionary
const MEALS := {"carrot_stew":22,"potato_bread":18,"egg_meal":20,"milk_porridge":24,"fish_feast":28}

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));initial=FarmSaveStore.snapshot(game)
	await continuous_food()
	await effects_and_caps()
	await reentrant_food()
	await lifecycle_and_storage()
	await inventory_touch_food()
	print("FOOD RECOVERY RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func fresh() -> void:
	FarmSaveStore.restore(game,initial);GameClock.running=false;GameWeather.enabled=false
	GameClock.minutes=600;GameState.stamina=0
	Recovery.restore(Recovery.defaults(GameClock.day));Kitchen.restore(Kitchen.defaults(GameClock.day))
	Aquaculture.state.meal_day=0
	Inventory.items={"carrot":20,"potato":20,"wheat":20,"carrot_stew":20,"potato_bread":20,"egg_meal":20,"milk_porridge":20,"fish_feast":20,"dried_fish":20,"fish_soup":20}
	game.change_location("farm",Recovery.BENCH+Vector2(0,32));await frames(4)

func stamp() -> Dictionary:
	return {"inventory":Inventory.items.duplicate(true),"stamina":GameState.stamina,"recovery":Recovery.snapshot(),"kitchen":Kitchen.snapshot(),"meal_day":Aquaculture.state.meal_day,"day":GameClock.day,"minutes":GameClock.minutes}

func continuous_food() -> void:
	await fresh()
	var ok:=true
	for i in range(5): ok=Recovery.eat_crop("carrot") and ok
	check(ok and GameState.stamina==40 and Inventory.count("carrot")==15,"同一天连续吃五份胡萝卜，每次消耗一份恢复8，取消三份上限")
	check(Recovery.snapshot().snacks==3 and Recovery.validate(Recovery.snapshot(),GameClock.day),"旧snacks字段饱和在3，仅兼容保存，不限制继续食用")
	check(Recovery.eat_crop("potato") and GameState.stamina==52 and Inventory.count("potato")==19,"超过旧零食额度后土豆仍恢复12并消耗一份")
	check(Recovery.eat_crop("wheat") and GameState.stamina==56 and Inventory.count("wheat")==19,"不同基础食物没有隐藏共享日限")
	await fresh()
	check(Kitchen.consume("carrot_stew") and Kitchen.consume("carrot_stew") and GameState.stamina==44 and Inventory.count("carrot_stew")==18,"同一天可连续食用两份厨房料理，每份正常恢复")
	check(Aquaculture.consume_food("dried_fish") and GameState.stamina==62 and Inventory.count("dried_fish")==19,"厨房料理后可继续吃鱼干，不再受共享一餐限制")
	check(Aquaculture.consume_food("fish_soup") and GameState.stamina==92 and Inventory.count("fish_soup")==19,"同一天鱼干和鱼汤分别按原体力值结算")
	check(Aquaculture.state.meal_day==GameClock.day,"meal_day保留最近一次料理日，兼容原增益存档校验")
	var old_day: int=GameClock.day;var old_time: float=GameClock.minutes
	check(Recovery.eat_crop("potato") and GameState.stamina==GameState.max_stamina() and Inventory.count("potato")==19,"不足一份的恢复量也只消耗一份食物，体力封顶")
	check(GameClock.day==old_day and GameClock.minutes==old_time,"连续进食不跳日、不改变游戏分钟")

func effects_and_caps() -> void:
	await fresh()
	GameState.stamina=10
	check(Kitchen.consume("potato_bread") and GameState.stamina==28 and Kitchen.speed_multiplier()==1.15,"第一份面包保留原18体力和15%移速增益")
	GameClock.running=true;Kitchen._process(17);GameClock.running=false
	var buff: Dictionary=Kitchen.snapshot().buff.duplicate(true)
	check(Kitchen.consume("potato_bread") and GameState.stamina==46 and Kitchen.state.buff==buff,"已有增益时再次吃面包可恢复体力，但不叠层、不延长时间")
	check(Kitchen.consume("egg_meal") and GameState.stamina==66 and Kitchen.state.buff==buff and Kitchen.energy_cost(4)==4,"已有移速增益时吃其他料理只恢复体力，不覆盖或叠加增益")
	check(Aquaculture.consume_food("fish_soup") and GameState.stamina==96 and Kitchen.state.buff==buff,"鱼料理恢复体力不会刷新现有厨房增益")
	GameClock.running=true;Kitchen._process(200);GameClock.running=false
	GameState.stamina=20
	check(Kitchen.consume("egg_meal") and Kitchen.state.buff.id=="thrift" and Kitchen.state.buff.remaining==90 and Kitchen.energy_cost(4)==3,"原增益自然到期后下一份料理可获得新的单一增益")
	GameState.stamina=GameState.max_stamina()
	var before:=stamp()
	check(not Recovery.eat_crop("carrot") and not Kitchen.consume("potato_bread") and not Aquaculture.consume_food("fish_soup") and stamp()==before,"满体力三类食物全部拒绝，库存与增益不变")
	GameState.stamina=20;Inventory.items.clear();before=stamp()
	check(not Recovery.eat_crop("carrot") and not Kitchen.consume("carrot_stew") and not Aquaculture.consume_food("fish_soup") and stamp()==before,"缺食材的失败不恢复体力、不改变最近用餐日或增益")
	Inventory.items.carrot=1
	check(Recovery.eat_crop("carrot") and Inventory.count("carrot")==0 and GameState.stamina==28,"失败事务释放共享锁，补齐食物后可正常使用")
	before=stamp()
	check(not Recovery.eat_crop("carrot_seed") and not Kitchen.consume("flour") and not Aquaculture.consume_food("fish_crucian") and stamp()==before,"种子、加工材料与生鱼仍不能冒充已有可食用物品")

func eat(source: String) -> bool:
	match source:
		"crop": return Recovery.eat_crop("carrot")
		"kitchen": return Kitchen.consume("carrot_stew")
		"fish": return Aquaculture.consume_food("fish_soup")
	return false

func reentrant_food() -> void:
	for source in ["crop","kitchen","fish"]:
		await fresh()
		var nested: Array[bool]=[]
		var seen: Array[bool]=[false]
		var again:=func():
			if seen[0]: return
			seen[0]=true
			for other in ["crop","kitchen","fish"]: nested.append(eat(other))
		Inventory.changed.connect(again)
		var accepted: bool=eat(source)
		Inventory.changed.disconnect(again)
		check(accepted and seen[0] and nested.size()==3 and not nested.has(true),"库存同步回调不能重入任何食用入口："+source)
		var item: String={"crop":"carrot","kitchen":"carrot_stew","fish":"fish_soup"}[source]
		var energy: int={"crop":8,"kitchen":22,"fish":30}[source]
		check(Inventory.count(item)==19 and GameState.stamina==energy,"重入被拒绝后只消耗一份且只恢复一次："+source)
		check(Recovery.eat_crop("carrot") and GameState.stamina==energy+8,"事务完成后的下一次独立食用正常接受："+source)
	await fresh()
	var nested: Array[bool]=[]
	var callback:=func(): nested.append(Aquaculture.consume_food("fish_soup"))
	GameState.changed.connect(callback)
	var accepted:=Kitchen.consume("carrot_stew")
	GameState.changed.disconnect(callback)
	check(accepted and nested.size()>0 and not nested.has(true) and GameState.stamina==22 and Inventory.count("fish_soup")==20,"共享食用锁保持到体力通知结束，不被晚阶段同步信号重入")

func lifecycle_and_storage() -> void:
	await fresh()
	for phase in ["background","closing","restoring","midnight"]:
		game.backgrounded=phase=="background";game.closing=phase=="closing";GameState.restoring=phase=="restoring"
		GameClock.minutes=1440 if phase=="midnight" else 600
		var before:=stamp()
		check(not eat("crop") and not eat("kitchen") and not eat("fish") and stamp()==before,"食物取消日限后仍拒绝后台/恢复边界旧回调："+phase)
		game.backgrounded=false;game.closing=false;GameState.restoring=false;GameClock.minutes=600
	GameState.set_modal(true)
	check(eat("crop") and eat("kitchen") and eat("fish") and GameState.stamina==60,"正常暂停菜单仍可依次食用三类食物")
	GameState.set_modal(false)
	Recovery.state.snacks=3;Aquaculture.state.meal_day=GameClock.day
	var saved:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.valid(saved) and saved.version==FarmSaveStore.VERSION,"达到旧食品日限的记录仍是当前格式合法存档")
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(saved))),"旧snacks与meal_day字段可以完整保存恢复")
	await frames(4)
	check(Recovery.eat_crop("carrot") and Kitchen.consume("carrot_stew") and GameState.stamina==90,"重新加载旧额度已满记录后仍允许正常食用")
	await fresh()
	var day: int=GameClock.day
	check(Recovery.rest(day,0) and Recovery.rest(day,1) and Recovery.rest(day,2) and GameState.stamina==45,"休息椅仍只按原三次/每次15体力规则工作")
	var before:=stamp()
	check(not Recovery.rest(day,3) and stamp()==before and Recovery.snapshot().rests==3,"食物放宽不会取消休息椅每日三次限制")
	check(Recovery.eat_crop("carrot") and GameState.stamina==53,"休息额度用完仍可消耗持有食物恢复")

func find_inventory_button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and child.text==caption: return child
		var found:=find_inventory_button(child,caption)
		if found: return found
	return null

func tap_inventory_food() -> bool:
	# UI05明确选择后才展示该物品的使用动作，查看与消费分离。
	game.hud.inventory_panel.select_item("carrot")
	var button:=find_inventory_button(game.hud.inventory_panel,"吃1个\n+8体力")
	if not is_instance_valid(button): return false
	var ancestor: Node=button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await frames(2)
	if not button.contains_touch(button.get_global_rect().get_center()): return false
	load("res://tests/story.gd").touch(self,button)
	await frames(3)
	return true

func inventory_touch_food() -> void:
	await fresh()
	GameState.stamina=0;Inventory.items.carrot=20
	game.hud.inventory_panel.open_panel(false);await frames(4)
	var at: Vector2=game.player.position
	var executions: int=game.auto_move.execution_count
	var all_five:=true
	for i in range(5):
		var tapped: bool=await tap_inventory_food()
		all_five=all_five and tapped and GameState.stamina==(i+1)*8 and Inventory.count("carrot")==20-i-1
	check(all_five and GameState.stamina==40 and Inventory.count("carrot")==15,"背包五次真实原生触点每次重新找到食物按钮，正确恢复40体力并仅吃5个胡萝卜")
	GameState.stamina=GameState.max_stamina();GameState.changed.emit()
	var tapped: bool=await tap_inventory_food()
	check(tapped and GameState.stamina==GameState.max_stamina() and Inventory.count("carrot")==15,"背包满体力时继续点击食用不扣物品")
	var close_button:=find_inventory_button(game.hud.inventory_panel,"关闭 ×")
	if close_button: load("res://tests/story.gd").touch(self,close_button)
	await frames(4)
	check(not game.hud.inventory_panel.visible and not GameState.modal and game.player.position==at and game.auto_move.target.is_empty() and game.auto_move.execution_count==executions,"连续吃食物及原生关闭背包后不产生地图移动或交互穿透")
