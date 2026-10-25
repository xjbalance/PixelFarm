extends Node2D
## 单次农活的只读工具呈现。复用原图集，位置取整；不拥有计时、碰撞或结算。
var tools_texture: Texture2D = load("res://assets/ui/tools.png")
var seed_texture: Texture2D = load("res://assets/ui/seed.png")
var tool_id: String = ""
var direction := Vector2.DOWN
var target := Vector2.ZERO
var elapsed: float = 0.0
var duration: float = 0.24
var impact: float = 0.10

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=1
	hide()

func display(tool: String, facing: Vector2, target_local: Vector2, action_elapsed: float, action_duration: float = 0.24, impact_time: float = 0.10) -> void:
	if tool not in ["hoe","water","hand"] and not tool.ends_with("_seed"):
		clear();return
	if action_elapsed<0 or action_duration<=0 or action_elapsed>=action_duration:
		clear();return
	tool_id=tool
	direction=Vector2(signf(facing.x),0) if absf(facing.x)>absf(facing.y) else Vector2(0,signf(facing.y))
	if direction==Vector2.ZERO: direction=Vector2.DOWN
	target=target_local.round()
	elapsed=action_elapsed
	duration=action_duration
	impact=clampf(impact_time,0.001,duration)
	show();queue_redraw()

func clear() -> void:
	tool_id=""
	hide()
	queue_redraw()

func hand_position() -> Vector2:
	if direction==Vector2.UP: return Vector2(9,-25)
	if direction==Vector2.DOWN: return Vector2(-7,-8)
	return Vector2(direction.x*9,-15)

func tool_position() -> Vector2:
	var hand := hand_position()
	var end := target+Vector2(0,-8)
	if tool_id.ends_with("_seed"): end=hand+direction*8
	elif tool_id=="water": end=hand+direction*9
	var before: float=clampf(elapsed/impact,0.0,1.0)
	if elapsed<=impact:
		return (hand.lerp(end,before*before)+Vector2(0,-sin(before*PI)*(7 if tool_id=="hoe" else 3))).round()
	var after: float=clampf((elapsed-impact)/maxf(.001,duration-impact),0.0,1.0)
	return end.lerp(hand,after*after*(3-2*after)).round()

func tool_angle() -> float:
	if tool_id.ends_with("_seed"): return 0.0
	# 原采收图的指尖朝上，水壶喷嘴朝右，不能共享同一基准朝向。
	if tool_id=="hand": return direction.angle()+PI/2
	return direction.angle()

func _draw() -> void:
	if tool_id=="": return
	var at := tool_position()
	var angle := tool_angle()
	draw_set_transform(at,angle)
	if tool_id.ends_with("_seed"):
		draw_texture_rect(seed_texture,Rect2(-8,-8,16,16),false)
	else:
		var index: int={"hoe":0,"water":1,"hand":2}[tool_id]
		var size: int=16 if tool_id=="hand" else 32
		draw_texture_rect_region(tools_texture,Rect2(-size/2,-size/2,size,size),Rect2(index*32,0,32,32))
	draw_set_transform(Vector2.ZERO)
	# 生效帧后才出现短水线/种子落点，最终像素始终落在锁定格心。
	if elapsed>=impact and elapsed<minf(duration,impact+.07):
		if tool_id=="water":
			var tip: Vector2=(at+Vector2(13,-5).rotated(angle)).round()
			for i in range(1,4):
				var p: Vector2=tip.lerp(target,float(i)/3.0).round()
				draw_rect(Rect2(p-Vector2.ONE,Vector2(2,2)),Color("afd8db"))
		elif tool_id.ends_with("_seed"):
			for offset in [Vector2(-3,-2),Vector2(3,1),Vector2(0,3)]:
				draw_rect(Rect2(target+offset,Vector2(2,2)),Color("ddbc7f"))
