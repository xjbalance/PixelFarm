extends "res://tests/runner.gd"
## 常用/剧情界面只读展示与原操作安全；所有测试使用外部临时用户目录。
const Touch=preload("res://tests/touch_navigation.gd")
var baseline: bool=false
var captures: Array=[]
var prefix: String=""

func run() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	load("res://tests/star_runner.gd").fixture(game,true);GameClock.running=false;GameWeather.enabled=false
	game.tutorial.restore(GameTutorial.defaults(true));Inventory.coins=3450;Inventory.items={"carrot_seed":18,"carrot":20,"potato_seed":9,"wood":42,"stone":30,"wheat":12,"crystal":16,"fish_soup":3}
	Xiaojing.state.diamonds=1400;Inventory.changed.emit();await frames(4)
	game.hud.toast_time=0;game.hud.toast.hide()
	await panels()
	if not baseline:
		for size in [Vector2i(1600,720),Vector2i(1280,960)]:
			get_window().size=size;await frames(4);game.hud.update_safe_area();await frames(4)
			game.hud.inventory_panel.open_panel(true);await audit(game.hud.inventory_panel,"shop_"+str(size.x)+"x"+str(size.y));game.hud.inventory_panel.close_panel()
			game.hud.system_panel.open_panel();await audit(game.hud.system_panel,"settings_"+str(size.x)+"x"+str(size.y));game.hud.system_panel.close_panel()
	var f:=FileAccess.open("res://builds/story-ui07-"+("before" if baseline else "after")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));f.close()
	print("STORY UI07 "+("BASELINE" if baseline else "RESULT")+": %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func stamp() -> Dictionary: return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(FarmSaveStore.snapshot(game))))

func panels() -> void:
	var before: Dictionary=stamp()
	game.hud.inventory_panel.open_panel(false);game.hud.inventory_panel.select_item("carrot")
	await audit(game.hud.inventory_panel,"inventory");game.hud.inventory_panel.close_panel()
	check(stamp()==before,"背包查看和关闭保留钱物、成功播种、住宅及婚姻")
	game.hud.inventory_panel.open_panel(true);await audit(game.hud.inventory_panel,"shop")
	game.hud.inventory_panel.request_sale_quantity("carrot");game.hud.inventory_panel.set_sale_quantity(5)
	await audit(game.hud.inventory_panel,"sale_confirmation");game.hud.inventory_panel.close_panel()
	check(stamp()==before,"新版出售数量界面只预览，取消保留全部原数据")
	game.hud.dialogue.open_dialogue("阿禾",[{"who":"阿禾","portrait":"ahe","text":"窗台的第一盆花开了。留言册不用换新本，旧页后面还有空白。等你把今天的收获放好，我们再一起核对河岸的记号。每一页都留给亲自走过这些路的人，不必赶着把故事翻完。"}])
	await audit(game.hud.dialogue,"dialogue");game.hud.dialogue.close_dialogue()
	check(stamp()==before,"新版对话视觉不提前提交剧情或消耗资源")
	game.hud.progress_panel.open_panel("journal",false);await audit(game.hud.progress_panel,"quest");game.hud.progress_panel.close_panel()
	game.hud.system_panel.open_panel();await audit(game.hud.system_panel,"settings");game.hud.system_panel.close_panel()
	game.hud.social_panel.open_panel("linya");await audit(game.hud.social_panel,"social");game.hud.social_panel.close_panel()
	game.hud.xiaojing_panel.open_panel();await audit(game.hud.xiaojing_panel,"xiaojing");game.hud.xiaojing_panel.close_panel()
	for entry in [[game.hud.mine_panel,"journal","mine"],[game.hud.abyss_panel,"legend","abyss"],[game.hud.river_panel,"journal","river"],[game.hud.star_panel,"overview","star"]]:
		entry[0].open_panel(entry[1]);await audit(entry[0],entry[2]);entry[0].close_panel()
	check(stamp()==before,"全部关系、试炼和矿洞面板查看关闭保持原进度与钱物")

func buttons(node: Node) -> Array[Button]:
	var out: Array[Button]=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree(): out.append(child)
		out.append_array(buttons(child))
	return out

func cards(node: Node) -> int:
	var count: int=1 if node.get_meta("ui07_card",false) else 0
	for child in node.get_children(): count+=cards(child)
	return count

func audit(panel: Control, label: String) -> void:
	await frames(5)
	check(panel.visible and GameState.modal and game.hud.safe.get_global_rect().grow(.5).encloses(panel.get_global_rect()),label+"完整处于安全区并暂停游戏")
	var touch_ok: bool=true
	for button in buttons(panel): touch_ok=touch_ok and button.size.x>=UIMetrics.minimum_target() and button.size.y>=UIMetrics.minimum_target()
	check(touch_ok,label+"按钮保留适合手指的触区")
	if not baseline: check(cards(panel)>0,label+"使用公共纸卡分组显示，未把内容堆成无层次长列表")
	var position: Vector2=game.player.position;var count: int=game.auto_move.execution_count
	var point: Vector2=panel.get_global_rect().position+Vector2(22,22)
	Touch.finger(self,point,true,621);Touch.finger(self,point,false,621);await frames(2)
	check(game.player.position==position and game.auto_move.execution_count==count and game.auto_move.target.is_empty(),label+"触控不会穿透至农场、人物或资源")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var path: String="res://builds/story-ui07-"+("before-" if baseline else "after-")+label+".png"
		get_viewport().get_texture().get_image().save_png(path);captures.append(path)
