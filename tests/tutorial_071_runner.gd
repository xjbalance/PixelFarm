extends "res://tests/runner.gd"
const Tutorial = preload("res://scripts/tutorial/game_tutorial.gd")
var tutorial: Node
var clicks: int = 0
var scroll: ScrollContainer
var control: Button

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(6)
	await tutorial_state()
	await native_buttons()
	while game.hud.close_active_panel(): pass
	GameState.set_control_mode("tap",false)
	print("TUTORIAL UI 071 RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func tutorial_state() -> void:
	var fresh: Dictionary=Tutorial.normalize(null,false)
	var legacy: Dictionary=Tutorial.normalize(null,true)
	check(fresh.seen.is_empty() and legacy.seen.size()==Tutorial.TOPICS.size(),"新玩家待学；旧档缺字段默认已读全部主题，不重放教学")
	check(Tutorial.normalize({"seen":["tap_move","day_rest"]}).seen==["tap_move","day_rest"],"稳定教学ID可独立保存恢复")
	check(Tutorial.normalize({"seen":["tap_move","tap_move"]}).is_empty(),"重复教学ID拒绝")
	check(Tutorial.normalize({"seen":["bad"]}).is_empty() and Tutorial.normalize({"seen":{}}).is_empty(),"异常教学数据不污染存档")
	check(Tutorial.help_text().contains("20:00") and Tutorial.help_text().contains("每天3次") and Tutorial.help_text().contains("每季28日"),"帮助包括睡眠、恢复及季节实用规则")
	tutorial=Tutorial.new();game.add_child(tutorial);tutorial.attach(game)
	tutorial.restore(fresh)
	tutorial.offer("tap_move");tutorial.offer("tap_move");tutorial.offer("bad")
	check(tutorial.pending==["tap_move"],"同主题只排队一次；未知主题忽略")
	tutorial.cooldown=0;game.hud.toast_time=0;tutorial._process(.01)
	check(tutorial.seen==["tap_move"] and tutorial.panel.visible and tutorial.body.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"安全游戏帧显示换行轻提示并记录一次")
	check(game.touch_input.ui_at(tutorial.panel.get_global_rect().get_center()),"教学卡在HUD根内拦截地图点击")
	tutorial.offer("tap_move")
	check(tutorial.pending.is_empty(),"已显示主题不再次排队")
	var snapshot: Dictionary=tutorial.snapshot();tutorial.restore(snapshot)
	check(tutorial.seen==["tap_move"] and not tutorial.panel.visible,"恢复已读状态清除运行中的提示卡")
	tutorial.offer("day_rest");GameState.set_modal(true);tutorial.cooldown=0;tutorial._process(2)
	check(tutorial.seen==["tap_move"] and not tutorial.panel.visible and tutorial.pending==["day_rest"],"模态期间不弹教学、不消耗未读主题")
	GameState.set_modal(false);game.backgrounded=true;tutorial._process(2)
	check(not tutorial.panel.visible and tutorial.pending==["day_rest"],"后台不显示也不结算教学")
	game.backgrounded=false;game.hud.toast_time=0;tutorial._process(.01)
	check("day_rest" in tutorial.seen and tutorial.panel.visible,"回到正常游戏后显示原待学主题")
	tutorial.hide_hint();check(not tutorial.panel.visible and "day_rest" in tutorial.seen,"关闭卡片不重置已读进度")
	tutorial.restore(legacy);tutorial.offer("tap_move");tutorial.offer("fishing");tutorial._process(60)
	check(tutorial.pending.is_empty() and not tutorial.panel.visible,"旧玩家恢复后不会被新版本全部重教")
	tutorial.queue_free();await frames(1)

func touch(index: int,point: Vector2,pressed: bool,canceled: bool=false) -> void:
	var event := InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;event.canceled=canceled
	get_viewport().push_input(event,true)

func drag(index: int,point: Vector2) -> void:
	var event := InputEventScreenDrag.new();event.index=index;event.position=point
	get_viewport().push_input(event,true)

func native_buttons() -> void:
	var panel := PanelContainer.new();panel.position=Vector2(400,280);panel.size=Vector2(400,180);panel.add_to_group("modal_panels");game.hud.safe.add_child(panel)
	scroll=ScrollContainer.new();scroll.set_script(load("res://scripts/ui/touch_scroll.gd"));panel.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	control=FarmUIStyle.button("测试触点",func(): clicks+=1,30);column.add_child(control)
	for i in range(12): column.add_child(FarmUIStyle.label("可滚动内容"+str(i),20))
	await frames(3)
	check(control.custom_minimum_size.x>=48 and control.size.y>=48,"主要按钮最小触点至少48×48逻辑像素")
	var point: Vector2=control.get_global_rect().get_center()
	touch(1,point,true);touch(1,point,false);touch(1,point,false)
	check(clicks==1,"原生触点短点执行一次，重复释放不重复回调")
	touch(2,point,true);touch(2,point+Vector2(24,0),false)
	check(clicks==1,"缺少Drag事件时大幅移动后释放也不误点宽按钮")
	touch(3,point,true);panel.hide()
	check(not control.is_processing_input() and not scroll.is_processing_input(),"隐藏界面停止原生输入扫描，避免逐事件遍历无用控件")
	panel.show()
	check(control.is_processing_input() and scroll.is_processing_input(),"重新显示界面恢复原生输入")
	touch(3,point,false)
	check(clicks==1 and control.finger==-1,"隐藏再显示不会恢复旧按钮触点")
	touch(4,point,true);touch(4,point,false,true)
	check(clicks==1 and control.finger==-1,"系统取消不执行按钮")
	touch(5,point,true);drag(5,point+Vector2(0,-50));touch(5,point+Vector2(0,-50),false)
	await frames(1)
	check(clicks==1 and scroll.scroll_vertical>0,"从按钮开始拖动可真实滚动，不误执行按钮")
	scroll.scroll_vertical=0;await frames(1);point=control.get_global_rect().get_center()
	touch(6,point,true);GameState.set_control_mode("joystick",false);touch(6,point,false)
	check(clicks==1 and scroll.finger==-1 and control.finger==-1,"切换输入模式清除按钮与滚动触点")
	GameState.set_control_mode("tap",false)
	scroll.begin_touch(7,point);scroll.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(scroll.finger==-1,"后台暂停清理滚动所有权")
	touch(8,point,true);control.notification(NOTIFICATION_APPLICATION_FOCUS_OUT);touch(8,point,false)
	check(clicks==1 and control.finger==-1,"应用失焦后释放不执行旧按钮")
	panel.queue_free();await frames(2)
