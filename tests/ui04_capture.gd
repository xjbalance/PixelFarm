extends Node
## 只捕获实际运行的界面，供视觉阶段对照；不伪造地图或向正式存档写入。
var game: Node
var phase: String="before"
var captures: Array=[]
var failures: int=0

func _ready() -> void: call_deferred("run")

func frames(count: int=4) -> void:
	for i in range(count): await get_tree().physics_frame

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("UI04截图需要实际窗口，不能使用headless冒充画面验收。")
		get_tree().quit(1);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase=argument.trim_prefix("--phase=")
	if phase.length()>32 or phase.is_empty() or phase.validate_filename()!=phase or "/" in phase or "\\" in phase:
		push_error("UI04 phase只允许单个安全文件名标签。")
		get_tree().quit(1);return
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	GameClock.minutes=990
	Inventory.coins=12345
	Inventory.items={"carrot_seed":8,"potato_seed":6,"wheat_seed":12,"carrot":12,"potato":8,"wheat":10,"wood":20,"stone":16,"fish_feed":8,"fishing_bait":7,"fish_soup":3,"potato_bread":3}
	Inventory.changed.emit();GameClock.changed.emit();GameState.select_tool(3)
	game.change_location("farm",Vector2(656,480));await frames(8)
	await capture("farm-hud",game.hud.safe)
	game.hud.inventory_panel.open_panel(false);await frames(5)
	if game.hud.inventory_panel.has_method("select_item"): game.hud.inventory_panel.select_item("carrot")
	await capture("inventory",game.hud.inventory_panel)
	game.hud.inventory_panel.close_panel()
	for id in ["linya","zhou","ahe","xiaojing"]:
		await npc_dialogue(id)
	var x: Dictionary=Xiaojing.defaults()
	x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=52;x.trust=50;x.bond=45
	Xiaojing.restore(x)
	game.change_location("village",Vector2(1088,656));await frames(6)
	game.hud.xiaojing_panel.open_panel();await frames(4)
	await capture("xiaojing-relationship",game.hud.xiaojing_panel)
	game.hud.xiaojing_panel.close_panel()
	game.change_location("home",Vector2(816,464));await frames(6)
	game.hud.kitchen_panel.open_panel();await frames(4)
	await capture("kitchen",game.hud.kitchen_panel)
	game.hud.kitchen_panel.close_panel()
	var manifest:=FileAccess.open("res://builds/ui04-"+phase+"-manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"phase":phase,"platform":"Linux actual Godot window; not Android","viewport":[1280,720],"captures":captures,"failures":failures},"\t"));manifest.close()
	print("UI04 CAPTURE ",phase,": ",captures.size()," frames, ",failures," failures")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failures else 0)

func npc_dialogue(id: String) -> void:
	while game.hud.close_active_panel(): pass
	var area: String="farm" if id=="linya" else "village"
	game.change_location(area,Vector2(464,496) if area=="farm" else Vector2(640,600));await frames(5)
	var names: Dictionary={"linya":"林芽","zhou":"周砚","ahe":"阿禾","xiaojing":"小京"}
	var words: String=SeasonalDialogue.line(id)
	# 复用原对白入口、原季节台词和原头像ID，不提交剧情或选择结算。
	Events.dialogue_requested.emit(names[id],[{"who":names[id],"portrait":id,"text":words}])
	await frames(4)
	await capture("dialogue-"+id,game.hud.dialogue)
	game.hud.dialogue.close_dialogue()

func capture(label: String, control: Control) -> void:
	game.hud.toast_time=0
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var path: String="res://builds/ui04-"+phase+"-"+label+".png"
	var result: Error=get_viewport().get_texture().get_image().save_png(path)
	var bounds: Rect2=control.get_global_rect()
	var within: bool=game.hud.safe.get_global_rect().grow(.5).encloses(bounds)
	if result!=OK:
		failures+=1;push_error("UI04截图失败："+path)
	captures.append({"name":label,"path":path,"visible":control.is_visible_in_tree(),"panel":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"inside_safe_area":within,"saved":result==OK})
	print("UI04 FRAME ",path," saved=",result==OK," within_safe_area=",within)
