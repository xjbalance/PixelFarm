extends Node
## 实际窗口对照与常驻HUD占位。只写builds；不向正式存档写入，不提交剧情结算。
var game: Node
var phase: String="before"
var shots: Array=[]
var failures: int=0
var resolution:=Vector2i(1280,720)

func _ready() -> void: call_deferred("run")

func frames(count: int=4) -> void:
	for i in range(count): await get_tree().physics_frame

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("UI05捕获要求真实窗口，不能使用headless。")
		get_tree().quit(1);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase=argument.trim_prefix("--phase=")
	if phase.is_empty() or phase.length()>32 or phase.validate_filename()!=phase or "/" in phase or "\\" in phase:
		push_error("UI05 phase必须是安全的单文件名标签。")
		get_tree().quit(1);return
	get_window().size=resolution
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	GameClock.minutes=990
	Inventory.coins=12345
	Inventory.items={"carrot_seed":8,"potato_seed":6,"wheat_seed":12,"carrot":12,"potato":8,"wheat":10,"wood":20,"stone":16,"fish_feed":8,"fishing_bait":7,"fish_soup":3,"potato_bread":3}
	Inventory.changed.emit();GameClock.changed.emit();GameState.select_tool(3)
	var x: Dictionary=Xiaojing.defaults()
	x.plants=520;x.plant_serial=520;x.unlocked=true;x.affection=52;x.trust=50;x.bond=45
	Xiaojing.restore(x)
	for size in [Vector2i(1280,720),Vector2i(1600,720)]:
		resolution=size;get_window().size=size;await frames(6);game.hud.update_safe_area();await frames(4)
		await capture_set()
	var file:=FileAccess.open("res://builds/ui05-"+phase+"-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":phase,"platform":"Linux actual Godot window, not Android","hud_metric":"Union of visible non-IGNORE persistent HUD control rectangles, clipped to viewport/ancestors. Excludes root/safe/scrim and modal panel subtrees; not alpha-pixel coverage.","captures":shots,"failures":failures},"\t"));file.close()
	print("UI05 CAPTURE ",phase,": ",shots.size()," frames, ",failures," failures")
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failures else 0)

func place(area: String, point: Vector2) -> void:
	while game.hud.close_active_panel(): pass
	game.auto_move.cancel();game.change_location(area,point)
	if game.hud.has_method("collapse_hotbar"): game.hud.collapse_hotbar()
	await frames(6)

func capture_set() -> void:
	await place("farm",Vector2(656,480))
	await capture("hud",game.hud.safe)
	if game.hud.has_method("expand_hotbar"): game.hud.expand_hotbar()
	await capture("hotbar-expanded",game.hud.toolbar)
	if game.hud.has_method("collapse_hotbar"): game.hud.collapse_hotbar()
	game.hud.inventory_panel.open_panel(false);await frames(4)
	if game.hud.inventory_panel.has_method("select_item"): game.hud.inventory_panel.select_item("carrot")
	await capture("inventory",game.hud.inventory_panel)
	game.hud.inventory_panel.close_panel()
	Events.dialogue_requested.emit("阿禾",[{"who":"阿禾","portrait":"ahe","text":SeasonalDialogue.line("ahe")}])
	await capture("dialogue",game.hud.dialogue);game.hud.dialogue.close_dialogue()
	game.hud.inventory_panel.open_panel(true)
	await capture("shop",game.hud.inventory_panel);game.hud.inventory_panel.close_panel()
	game.hud.progress_panel.open_panel("journal",false)
	await capture("quests",game.hud.progress_panel);game.hud.progress_panel.close_panel()
	game.hud.xiaojing_panel.open_panel()
	await capture("xiaojing",game.hud.xiaojing_panel);game.hud.xiaojing_panel.close_panel()
	await place("home",Vector2(816,464))
	game.hud.kitchen_panel.open_panel()
	await capture("kitchen",game.hud.kitchen_panel);game.hud.kitchen_panel.close_panel()
	await place("farm",Aquaculture.SITES.pen_1+Vector2(-32,0))
	game.hud.aquaculture_panel.open_panel("pen_1")
	await capture("fishpen",game.hud.aquaculture_panel);game.hud.aquaculture_panel.close_panel()

func capture(label: String, control: Control) -> void:
	game.hud.toast_time=0
	# 等转场横幅结束；所有before/after采用同一稳定帧等待。
	await get_tree().create_timer(2.9).timeout
	await RenderingServer.frame_post_draw
	var path: String="res://builds/ui05-"+phase+"-"+str(resolution.x)+"x"+str(resolution.y)+"-"+label+".png"
	var saved: Error=get_viewport().get_texture().get_image().save_png(path)
	var viewport: Rect2=get_viewport().get_visible_rect()
	var entries: Array=[]
	collect_intercepts(game.hud.root,viewport,entries)
	var rectangles: Array[Rect2]=[]
	for entry in entries: rectangles.append(Rect2(entry.rect[0],entry.rect[1],entry.rect[2],entry.rect[3]))
	var area: float=union_area(rectangles)
	var rect: Rect2=control.get_global_rect()
	var inside: bool=game.hud.safe.get_global_rect().grow(.5).encloses(rect)
	if saved!=OK or not control.is_visible_in_tree():
		failures+=1;push_error("UI05截图失败或目标未显示："+path)
	shots.append({"name":label,"path":path,"resolution":[resolution.x,resolution.y],"viewport":[viewport.size.x,viewport.size.y],"panel":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"panel_inside_safe_area":inside,"modal":GameState.modal,"hud_intercept_rectangles":entries,"hud_union_area":area,"hud_area_fraction":area/(viewport.size.x*viewport.size.y),"hotbar_expand_api":game.hud.has_method("expand_hotbar"),"saved":saved==OK})
	print("UI05 FRAME ",label," ",resolution," saved=",saved==OK," HUD fraction=",snappedf(area/(viewport.size.x*viewport.size.y),.0001)," panel_safe=",inside)

func collect_intercepts(node: Node, clip: Rect2, out: Array) -> void:
	if node==game.hud.scrim or node.is_in_group("modal_panels"): return
	if node is Control:
		if not node.is_visible_in_tree(): return
		var visible_rect: Rect2=node.get_global_rect().intersection(clip)
		if node.clip_contents:
			clip=visible_rect
			if not clip.has_area(): return
		if node!=game.hud.root and node!=game.hud.safe and node.mouse_filter!=Control.MOUSE_FILTER_IGNORE and visible_rect.has_area():
			out.append({"node":str(game.hud.get_path_to(node)),"mouse_filter":node.mouse_filter,"rect":[visible_rect.position.x,visible_rect.position.y,visible_rect.size.x,visible_rect.size.y]})
	for child in node.get_children(): collect_intercepts(child,clip,out)

func union_area(rectangles: Array[Rect2]) -> float:
	var xs: Array[float]=[]
	for rect in rectangles:
		if rect.position.x not in xs: xs.append(rect.position.x)
		if rect.end.x not in xs: xs.append(rect.end.x)
	xs.sort()
	var area: float=0
	for i in range(xs.size()-1):
		var left: float=xs[i];var right: float=xs[i+1]
		var strips: Array[Vector2]=[]
		for rect in rectangles:
			if rect.position.x<right and rect.end.x>left: strips.append(Vector2(rect.position.y,rect.end.y))
		strips.sort_custom(func(a: Vector2,b: Vector2): return a.x<b.x)
		var length: float=0;var top: float=0;var bottom: float=0;var active: bool=false
		for strip in strips:
			if not active: top=strip.x;bottom=strip.y;active=true
			elif strip.x<=bottom: bottom=maxf(bottom,strip.y)
			else: length+=bottom-top;top=strip.x;bottom=strip.y
		if active: length+=bottom-top
		area+=(right-left)*length
	return area
