extends Node
## 使用同一隔离用户目录的四个独立进程，验证生效前/后的存档不含半事务。
const CELL:=Vector2i(20,18)
var game: Node
var checked: int=0
var failed: int=0
var commits: int=0
func _ready() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checked+=1
	if ok: print("PASS: ",text)
	else: failed+=1;push_error("FAIL: "+text)
func frames(count: int=3) -> void:
	for i in range(count): await get_tree().physics_frame
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var before: bool="--write-farm-windup" in args or "--read-farm-windup" in args
	var writing: bool="--write-farm-windup" in args or "--write-farm-impact" in args
	Events.farm_committed.connect(func(_kind: String,_cell: Vector2i,_crop: String,_serial: int): commits+=1)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=not writing;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.persistence_enabled=false;game.tutorial.restore(GameTutorial.defaults(true))
	if writing:
		game.change_location("farm",Vector2(624,592));await frames(5)
		GameClock.minutes=600;GameState.stamina=37;Inventory.coins=321;Inventory.items={"carrot_seed":3}
		game.farm.plots={"20,18":{"crop":"","days":0,"watered":false}}
		GameState.select_tool(GameState.tools.find("carrot_seed"))
		check(game.player.begin_farm_action(game.farm,CELL,"carrot_seed"),"独立进程开始可保存的单次播种")
		await frames(3 if before else 9)
		check(Inventory.count("carrot_seed")==3 if before else Inventory.count("carrot_seed")==2,"保存时种子数量符合生效边界")
		check(FarmSaveStore.write(game),"农活动作阶段正常写入原存档格式")
		var data:=FarmSaveStore.read()
		check(data.version==FarmSaveStore.VERSION and not data.has("farm_action") and data.stamina==(37 if before else 36) and data.xiaojing.plants==(0 if before else 1),"阶段存档不保存运行任务且体力和520计数一致")
		game.player.cancel_farm_action()
	else:
		check(Inventory.coins==321 and Inventory.count("carrot_seed")== (3 if before else 2) and GameState.stamina==(37 if before else 36),"独立重启恢复阶段完整金币、种子、体力")
		check(game.farm.plots["20,18"].crop==("" if before else "carrot") and Xiaojing.state.plants==(0 if before else 1),"独立重启土地和成功播种计数严格配套")
		var snapshot:=FarmSaveStore.snapshot(game)
		await frames(30)
		check(FarmSaveStore.snapshot(game)==snapshot and game.player.farm_action.is_empty() and commits==0,"重启等待后不补执行旧动作、不再扣资源或重复播种")
	print("FARMING ACTIONS PERSISTENCE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)
