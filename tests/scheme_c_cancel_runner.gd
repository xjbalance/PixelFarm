extends "res://tests/runner.gd"
## 真正经过主场景关闭流程，确认首次取消不会在退出自动保存时写入默认性别。
func run() -> void:
	var path: String="user://scheme-c-unconfirmed-cancel-%d.json" % Time.get_ticks_usec()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=true;game.save_path=path;add_child(game)
	GameClock.running=false;game.get_node("Audio").muted=true;await frames(8)
	check(game.awaiting_character_choice and game.character_select.visible,"首次无档真正进入角色选择")
	game.character_select.select_gender("female");game.character_select.close_panel();await frames(3)
	check(game.closing and not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"首次取消经历真实退出自动保存分支，仍没有默认男主或草稿存档")
	print("SCHEME C CANCEL RESULT: %d checks, %d failures" % [checked,failed])
	if failed: get_tree().quit(1)
	# 成功时由Main.close_session正常停止音轨并退出，验证真实关闭路径。
