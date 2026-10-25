extends "res://tests/runner.gd"
## 真实窗口逐帧观察：碰撞拐角、抵达待机、浇水原点。截图只记录实跑场景。
const Touch=preload("res://tests/touch_navigation.gd")
var samples: Array=[]
var captures: Array=[]

func run() -> void:
	get_window().size=Vector2i(1280,720)
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));GameState.set_control_mode("tap",false)
	await Touch.place(self,game,"home",Vector2(530,336))
	Touch.tap(self,game,Vector2(710,336))
	var clean:=true
	var sample_steps: Array[int]=[3,20,45,75]
	for i in range(240):
		await frames(1)
		var p: CharacterBody2D=game.player
		samples.append({"frame":i,"position":[p.position.x,p.position.y],"velocity":[p.velocity.x,p.velocity.y],"facing":[p.facing.x,p.facing.y],"sprite_frame":p.sprite.frame})
		var query:=PhysicsShapeQueryParameters2D.new();query.shape=p.get_node("CollisionShape2D").shape
		query.transform=p.global_transform;query.collision_mask=1
		clean=clean and p.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
		if i in sample_steps: await capture("corner_%03d" % i)
		if game.auto_move.state==game.auto_move.State.IDLE: break
	await frames(3);await capture("corner_stopped")
	check(clean and game.player.position.distance_to(Vector2(720,336))<1.1,"窗口拐角全程物理无穿墙，最终正确停留")
	check(game.player.velocity==Vector2.ZERO and game.player.sprite.frame%4 in [0,2],"窗口抵达后真实速度为零且切到待机帧")
	var facing_matches:=true
	for entry in samples:
		var v:=Vector2(entry.velocity[0],entry.velocity[1])
		if v.length()<1: continue
		var f:=Vector2(entry.facing[0],entry.facing[1])
		facing_matches=facing_matches and f.dot(v.normalized())>.5
	check(facing_matches,"窗口逐帧行走朝向与实际移动方向一致")
	await Touch.place(self,game,"farm",Vector2(624,592))
	game.farm.plots={"20,18":{"crop":"carrot","days":0,"watered":false}}
	GameState.manual_tool=false;GameState.stamina=100
	Touch.tap(self,game,Vector2(656,592));await Touch.finish(self,game)
	var at: Vector2=game.player.position
	var facing: Vector2=game.player.facing
	var anchored:=true
	for i in range(20):
		await frames(1)
		anchored=anchored and game.player.position==at and game.player.facing==facing and absf(game.player.sprite.position.x)<.01
		if i in [0,6,13,19]: await capture("water_%02d" % i)
	check(anchored and game.farm.plots["20,18"].watered,"窗口浇水序列脚底、朝向和横向精灵原点稳定")
	check(game.player.action_time==0,"窗口浇水结束无残留动作锁")
	Touch.tap(self,game,Vector2(784,496));await Touch.finish(self,game)
	await frames(3);await capture("water_move_again")
	check(game.player.position.distance_to(Vector2(784,496))<1.1,"窗口浇水后可以继续点击移动并停步")
	var file:=FileAccess.open("res://builds/touch-polish-visual.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":"Linux rendered window, not Android","samples":samples,"captures":captures},"\t"));file.close()
	print("TOUCH POLISH VISUAL RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout
	game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file: String="res://builds/touch-polish-"+label+".png"
	get_viewport().get_texture().get_image().save_png(file)
	var foot: Vector2=game.player.get_canvas_transform()*game.player.global_position
	captures.append({"name":label,"path":file,"screen_foot":[foot.x,foot.y],"sprite_frame":game.player.sprite.frame,"sprite_offset":[game.player.sprite.position.x,game.player.sprite.position.y]})
