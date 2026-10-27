extends PanelContainer
signal save_requested
signal load_requested
signal sleep_requested(expected_day: int)
signal mute_requested
signal bag_requested
signal journal_requested
signal story_requested
signal new_game_requested
var title: Label
var body: Label
var actions: VBoxContainer
var sleep_mode: bool = false
var control_mode_button: Button
var player_avatar: FarmPortrait
var appearance_hint: Label
var _new_game_pending: bool=false
var _view_token: int=0

func _ready() -> void:
	add_to_group("modal_panels")
	hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	player_avatar=FarmPortrait.new();player_avatar.person="player";player_avatar.set_meta("appearance_role","player")
	header.add_child(player_avatar);player_avatar.custom_minimum_size=Vector2(44,52)
	title = FarmUIStyle.heading(header,"像素世界 · 0.7.1 匠心打磨","house_1")
	appearance_hint=FarmUIStyle.label("形象未加载",15,FarmUIStyle.DANGER);header.add_child(appearance_hint)
	var scroll := ScrollContainer.new()
	scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"))
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	body = FarmUIStyle.label("",17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FarmUIStyle.card(content).add_child(body)
	actions = FarmUIStyle.card(content)
	actions.add_theme_constant_override("separation",8)
	var appearance:=get_node_or_null("/root/Appearance")
	if appearance and appearance.has_signal("changed"): appearance.changed.connect(refresh_identity)

func refresh_identity() -> void:
	var path: String=player_avatar.current_avatar_path()
	appearance_hint.visible=not sleep_mode and (path=="" or not ResourceLoader.exists(path))
	player_avatar.visible=not sleep_mode

func open_panel(for_sleep: bool = false) -> void:
	if GameState.modal: return
	if for_sleep and not GameClock.can_sleep(true): return
	_view_token+=1;_new_game_pending=false
	sleep_mode = for_sleep
	refresh_identity()
	GameState.set_modal(true)
	show()
	title.text = "让今天好好结束" if for_sleep else "像素世界 · 0.7.1 匠心打磨"
	body.text = "睡到明天早上 06:00，恢复全部体力。\n今天浇过水且适应季节的作物将成长一天。" if for_sleep else "点击地面行走，点击人物或物件靠近后交互。\n工具栏选择优先用于下一次点击；辅助开关仍有效。\nWASD / 方向键移动 · E 操作 · Q / 1—9 工具\n背包 B · 委托 J · 地图 M · 保存 F5 · 读取 F9"
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	if for_sleep:
		var opened_day: int=GameClock.day
		actions.add_child(FarmUIStyle.button("休息到明天",func():
			if not visible or not sleep_mode: return
			close_panel()
			sleep_requested.emit(opened_day)
		))
	else:
		actions.add_child(FarmUIStyle.button("背包 B",func(): close_panel();bag_requested.emit(),150))
		actions.add_child(FarmUIStyle.button("委托 J",func(): close_panel();journal_requested.emit(),150))
		actions.add_child(FarmUIStyle.button("手记",func(): close_panel();story_requested.emit(),150))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		actions.add_child(row)
		row.add_child(FarmUIStyle.button("保存进度",func(): close_panel(); save_requested.emit(),150))
		row.add_child(FarmUIStyle.button("读取进度",func(): close_panel(); load_requested.emit(),150))
		row.add_child(FarmUIStyle.button("体力恢复",func(): close_panel(); Events.interaction_requested.emit("recovery"),150))
		actions.add_child(FarmUIStyle.button("音乐与环境声 开 / 关",func(): mute_requested.emit()))
		control_mode_button = FarmUIStyle.button(mode_text(),func():
			GameState.set_control_mode("joystick" if GameState.control_mode == "tap" else "tap")
			control_mode_button.text = mode_text()
		)
		actions.add_child(control_mode_button)
		var assist := FarmUIStyle.button("操作辅助："+("开" if Story.assisted_tools else "关"),func():
			Story.assisted_tools = not Story.assisted_tools
			Story.changed.emit()
			Events.progress_committed.emit()
			close_panel()
			open_panel()
		)
		actions.add_child(assist)
		actions.add_child(FarmUIStyle.button("操作与生活指南",func():
			body.text=GameTutorial.help_text()
			for child in actions.get_children(): child.hide()
			actions.add_child(FarmUIStyle.button("返回设置",func(): close_panel();open_panel()))
		))
	if not for_sleep and OS.is_debug_build():
		var diagnostic := FarmUIStyle.button("本地试玩记录："+("开" if Playtest.enabled else "关")+"（不上传）",func(): Playtest.toggle(); close_panel(); open_panel())
		actions.add_child(diagnostic)
	if not for_sleep and GameState.location=="home":
		actions.add_child(FarmUIStyle.button("布置房间",func(): close_panel();Events.interaction_requested.emit("home:arrange")))
	if not for_sleep:
		var restart:=FarmUIStyle.button("新游戏 · 重新开始",ask_new_game,180)
		restart.add_theme_stylebox_override("normal",FarmUIStyle.surface("danger"));actions.add_child(restart)
	if for_sleep: body.text += "\n明天的河湾村："+GameWeather.tomorrow()+"。"
	actions.add_child(FarmUIStyle.button("继续农场生活",close_panel))

func mode_text() -> String:
	return "操作方式：点击移动 → 切换虚拟摇杆" if GameState.control_mode == "tap" else "操作方式：虚拟摇杆 → 切换点击移动"

func close_panel() -> void:
	_view_token+=1;_new_game_pending=false
	hide()
	GameState.set_modal(false)

func ask_new_game() -> void:
	if not visible or sleep_mode or _new_game_pending: return
	_new_game_pending=true;_view_token+=1
	var token: int=_view_token
	title.text="开始新的田园生活？"
	body.text="新游戏会从新的农场开始。当前进度会先保留备份。\n接下来可以选择主角；确认角色前不会覆盖当前进度。"
	for child in actions.get_children(): actions.remove_child(child);child.queue_free()
	var accept:=FarmUIStyle.button("确认进入角色选择",confirm_new_game.bind(token),200)
	accept.add_theme_stylebox_override("normal",FarmUIStyle.surface("danger"));actions.add_child(accept)
	actions.add_child(FarmUIStyle.button("取消，继续当前游戏",func(): close_panel();open_panel(),200))

func confirm_new_game(token: int) -> void:
	if not visible or sleep_mode or not _new_game_pending or token!=_view_token: return
	close_panel();new_game_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
