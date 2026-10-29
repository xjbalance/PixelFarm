extends "res://tests/runner.gd"
## 真实窗口四方向单次农活：使用原触点入口、生效事务和原声音，截图仅记录实跑。
const Touch=preload("res://tests/touch_navigation.gd")
const CELL:=Vector2i(20,18)
const POINT:=Vector2(656,592)
const DIRECTIONS: Dictionary={"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}
var visual: Node2D
var captures: Array=[]
var timings: Array=[]
var commits: int=0
var effects: Array=[]

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	for child in game.player.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://scripts/farming/tool_action_visual.gd": visual=child
	check(visual!=null,"四方向工具视觉节点已接入真实玩家")
	if visual==null: await finish();return
	Events.farm_committed.connect(func(_kind: String,_cell: Vector2i,_crop: String,_serial: int): commits+=1)
	Events.farm_effect.connect(func(origin: Vector2,kind: String): effects.append({"origin":origin,"kind":kind}))
	for tool in ["hoe","carrot_seed","water","hand"]:
		for name in DIRECTIONS:
			await action_case(tool,name,DIRECTIONS[name])
	await cancel_case()
	var report:=FileAccess.open("res://builds/farming-visual-evidence.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"platform":"Linux rendered Godot window; not Android","timings":timings,"captures":captures},"\t"));report.close()
	print("FARMING VISUAL RESULT: %d checks, %d failures" % [checked,failed])
	await finish()

func finish() -> void:
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func prepare(tool: String,facing: Vector2) -> void:
	while game.hud.close_active_panel(): pass
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	await Touch.place(self,game,"farm",POINT-facing*32)
	GameClock.running=false;GameState.stamina=100
	GameState.select_tool(GameState.tools.find(tool))
	game.player.facing=-facing
	game.farm.plots.clear()
	if tool!="hoe":
		game.farm.plots["20,18"]={"crop":"carrot" if tool in ["water","hand"] else "","days":Catalog.crops.carrot.growth_days if tool=="hand" else 0,"watered":false}
	Inventory.items.carrot_seed=20;Inventory.items.erase("carrot")
	game.farm.queue_redraw();game.hud.toast_time=0
	# 先结束原地图转场，再观察短工具动作本身，避免颜色变化干扰像素判断。
	await frames(30)

func step() -> void:
	await frames(1)
	await get_tree().process_frame

func action_case(tool: String,label: String,facing: Vector2) -> void:
	await prepare(tool,facing)
	var before: Dictionary=game.farm.plots.duplicate(true)
	var at: Vector2=game.player.position
	var before_commits: int=commits
	var before_effects: int=effects.size()
	var audio: Node=game.get_node("Audio");audio.muted=false
	var sound: int=audio.next_player
	Touch.tap(self,game,POINT)
	for i in range(12):
		await step()
		if game.player.action_time>0: break
	var started: int=Engine.get_physics_frames()
	var name: String=tool+"_"+label
	check(game.player.action_time>0 and game.farm.plots==before and GameState.stamina==100 and commits==before_commits and audio.next_player==sound,name+"：起手已锁定，但尚未生效、扣资源或播放成功音效")
	var steady:=true
	var tool_aligned: bool=visual.visible and visual.direction==facing and visual.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST
	var effect_frame: int=-1
	if label=="right": await capture(name+"_start")
	for i in range(28):
		await step()
		if game.player.action_time>0:
			steady=steady and game.player.position==at and game.player.facing==facing and game.player.sprite.position==game.player.visual_offset()
			tool_aligned=tool_aligned and visual.visible and visual.direction==facing and visual.tool_position()==visual.tool_position().round()
			if tool=="hand": tool_aligned=tool_aligned and Vector2.UP.rotated(visual.tool_angle()).dot(facing)>.99
		if commits>before_commits and effect_frame<0:
			effect_frame=Engine.get_physics_frames()-started
			await capture(name+"_impact")
		if game.player.action_time<=0: break
	var elapsed_frames: int=Engine.get_physics_frames()-started
	check(steady and tool_aligned,name+"：身体与碰撞脚底固定，独立工具按正确方向及整数像素绘制")
	check(commits==before_commits+1 and effects.size()==before_effects+1 and effects[-1].origin==POINT and effect_frame>0 and effect_frame<=8,name+"：生效帧只有一笔事务与准确格心水花/收获反馈")
	check(game.player.action_time==0 and not visual.visible and game.player.velocity==Vector2.ZERO and game.player.sprite.frame%4 in [0,2],name+"：结束收起工具并恢复待机，无残留锁定")
	var expected_sound: String="harvest" if tool=="hand" else "action"
	check(audio.next_player==(sound+1)%audio.players.size() and audio.players[sound].stream==audio.SOUNDS[expected_sound],name+"：成功生效只播放一次原有对应音效")
	if label=="right": await capture(name+"_end")
	timings.append({"tool":tool,"direction":label,"impact_after_start_frames":effect_frame,"end_after_start_frames":elapsed_frames})
	audio.muted=true

func cancel_case() -> void:
	await prepare("water",Vector2.UP)
	var before: int=commits
	Touch.tap(self,game,POINT)
	for i in range(12):
		await step()
		if game.player.action_time>0: break
	game.hud.inventory_panel.open_panel(false)
	await frames(20)
	check(not visual.visible and game.player.action_time==0 and commits==before and not game.farm.plots["20,18"].watered,"菜单打断起手后收起工具，不留下悬空水壶或迟到水花")
	game.hud.close_active_panel()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://builds/farm02-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	var foot: Vector2=game.player.get_canvas_transform()*game.player.global_position
	captures.append({"name":label,"path":path,"screen_foot":[foot.x,foot.y],"sprite_frame":game.player.sprite.frame,"sprite_offset":[game.player.sprite.position.x,game.player.sprite.position.y],"tool":visual.tool_id,"tool_offset":[visual.tool_position().x,visual.tool_position().y]})
