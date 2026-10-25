extends Node
## 调用者必须给独立临时XDG目录；写入和读取必须是两个Godot进程。
const Touch=preload("res://tests/touch_navigation.gd")
var checked: int=0
var failed: int=0
var game: Node
func check(ok: bool, message: String) -> void:
	checked+=1
	if ok: print("PASS: ",message)
	else: failed+=1;push_error("FAIL: "+message)
func _ready() -> void: call_deferred("run")
func frames(count: int=3) -> void:
	for i in range(count): await get_tree().physics_frame
func run() -> void:
	var writing: bool="--write-touch-polish" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if writing:
		game.change_location("farm",Vector2(656,480));await frames(5)
		GameState.set_control_mode("joystick",false)
		check(FarmSaveStore.write(game),"独立写进程保存原结构和备用摇杆模式")
		var data:=FarmSaveStore.read()
		check(data.version==FarmSaveStore.VERSION and not data.has("target") and not data.has("path"),"原存档版本不变，运行中目标和路线不写入存档")
	else:
		check(GameState.control_mode=="joystick" and game.hud.joystick.visible,"独立重启恢复所选备用操作模式")
		check(game.auto_move.target.is_empty() and game.auto_move.path.is_empty() and game.player.auto_direction==Vector2.ZERO,"独立重启无陈旧路径、待执行操作和自动速度")
		GameState.set_control_mode("tap",false)
		Touch.tap(self,game,Vector2(784,496));await Touch.finish(self,game)
		check(game.player.position.distance_to(Vector2(784,496))<1.1 and game.auto_move.target.is_empty(),"独立重启后切回点击可正常抵达与停止")
	print("TOUCH POLISH PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
