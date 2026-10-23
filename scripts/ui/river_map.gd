class_name FarmRiverMap
extends Control
## 地图按真实世界坐标绘制地标、玩家和目标，不传送、不改变游戏状态。
var location: String = "farm"
var area := Rect2()
var world_size := Vector2(1536,1024)
var timer: float = 0
const FONT = preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc")

func _ready() -> void:
	custom_minimum_size = Vector2(570,350)
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	timer += delta
	if timer > 0.2:
		timer = 0
		queue_redraw()

func point(p: Vector2) -> Vector2:
	return area.position + p / world_size * area.size

func region(rect: Rect2,color: Color) -> void:
	draw_rect(Rect2(point(rect.position),rect.size/world_size*area.size),color)

func mark(p: Vector2,label: String,color: Color = Color("ede0af"),offset: Vector2 = Vector2(8,-5)) -> void:
	var anchor := point(p)
	draw_circle(anchor,4,color)
	draw_string(FONT,anchor+offset,label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)

func _draw() -> void:
	world_size = Vector2(1280,896) if location == "village" else Vector2(1536,1024)
	area = Rect2(12,12,size.x-24,size.y-24)
	draw_rect(area,Color("72896b"))
	draw_rect(area,Color("adbb8c"),false,2)
	if location == "farm":
		region(Rect2(448,192,64,770),Color("bea678"))
		region(Rect2(448,416,550,64),Color("bea678"))
		region(Rect2(544,512,320,192),Color("a28b65"))
		region(Rect2(992,480,192,224),Color("648f96"))
		region(Rect2(565,295,175,105),Color("80695b"))
		mark(Vector2(480,216),"↑ 河湾村")
		mark(Vector2(640,380),"家",Color("ede0af"),Vector2(-12,-17))
		mark(Vector2(430,441),"林芽 / 种子摊",Color("ede0af"),Vector2(-116,8))
		mark(Vector2(748,440),"信箱",Color("ede0af"),Vector2(8,-12))
		mark(Vector2(704,608),"农田")
		mark(Vector2(1070,592),"池塘")
	else:
		region(Rect2(608,288,64,550),Color("bea678"))
		region(Rect2(80,448,1110,64),Color("bea678"))
		region(Rect2(832,0,96,896),Color("648f96"))
		if Story.stage >= 5: region(Rect2(824,448,115,64),Color("d1b68b"))
		region(Rect2(218,280,144,68),Color("8f7661"))
		region(Rect2(448,273,144,68),Color("7e7870"))
		mark(Vector2(290,357),"阿禾 / 茶屋",Color("ede0af"),Vector2(-90,-7))
		mark(Vector2(488,400),"周砚 / 木作坊",Color("ede0af"),Vector2(-20,-27))
		mark(Vector2(790,450),"旧桥",Color("ede0af"),Vector2(-12,-16))
		mark(Vector2(1090,350),"风车",Color("ede0af"),Vector2(-16,-18))
		mark(Vector2(370,565),"水井",Color("ede0af"),Vector2(-42,12))
		mark(Vector2(628,524),"风灯广场")
		mark(Vector2(540,610),"茶座",Color("ede0af"),Vector2(-45,10))
		mark(Vector2(680,650),"共建板")
		mark(Vector2(640,826),"↓ 风芽农场",Color("ede0af"),Vector2(8,0))
	var objective: Dictionary = Story.chapter()
	if objective.location == location and Story.stage < 8:
		var p := point(Vector2(objective.target[0],objective.target[1]))
		draw_arc(p,10,0,TAU,24,Color("ffdf84"),3)
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if player != null and GameState.location == location:
		var p := point(player.global_position)
		draw_circle(p,7,Color("283e3a"))
		draw_circle(p,4,Color("ffffff"))
