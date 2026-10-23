extends Node2D
## 稀疏植被、岸边波纹与风的细节，以低频重绘减少移动端开销。
var village: bool = false
var clock: float = 0
var accumulator: float = 0
var sprouts: Array[Vector2] = []
var effects: Array[Dictionary] = []
var ground: TileMapLayer
var edges: Array[Dictionary] = []

func _ready() -> void:
	z_index = -2
	ground = get_parent().get_node("Ground")
	var rng := RandomNumberGenerator.new()
	rng.seed = 903 if village else 901
	for i in range(350):
		var point := Vector2(rng.randi_range(45,1230 if village else 1480),rng.randi_range(55,850 if village else 980))
		if ground.get_cell_atlas_coords(Vector2i(point/32)).x < 3: sprouts.append(point)
	if not village: Events.farm_effect.connect(add_effect)
	Story.changed.connect(func(): call_deferred("cache_edges"))
	cache_edges()

func cache_edges() -> void:
	# 地形边界仅在地图变化后重建；动画重绘不再遍历整张 TileMap。
	edges.clear()
	for cell in ground.get_used_cells():
		var tile: int = ground.get_cell_atlas_coords(cell).x
		if tile not in [3,4,5]: continue
		for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var neighbor: int = ground.get_cell_atlas_coords(cell+offset).x
			if neighbor < 0 or neighbor >= 3: continue
			var p := Vector2(cell)*32+Vector2(16,16)+Vector2(offset)*15
			var side := Vector2(-offset.y,offset.x)*16
			edges.append({"a":p-side,"b":p+side,"color":Color("a08d66") if tile in [3,4] else Color("bcc4a0")})
	queue_redraw()

func add_effect(origin: Vector2,kind: String) -> void:
	effects.append({"origin":origin,"kind":kind,"life":0.8,"total":0.8})

func _process(delta: float) -> void:
	clock += delta
	accumulator += delta
	for effect in effects: effect.life -= delta
	effects = effects.filter(func(effect: Dictionary):return effect.life>0)
	if accumulator >= 0.075 or not effects.is_empty():
		accumulator = 0
		queue_redraw()

func _draw() -> void:
	if not ground: return
	for i in range(sprouts.size()):
		var p := sprouts[i]
		var sway := roundf(sin(clock*1.1+p.x)*1.0)
		draw_line(p,p+Vector2(-3+sway,-6),Color("5d8055"),2)
		draw_line(p+Vector2(2,0),p+Vector2(5+sway,-8),Color("a1b37a"),2)
		if i%5==0:
			draw_rect(Rect2(p+Vector2(1+sway,-9),Vector2(4,4)),Color("e7cea3") if i%2 else Color("c99a98"))
	# 接壤地块加一圈细边，避免整片草地与道路像平铺的色块。
	for edge in edges: draw_line(edge.a,edge.b,edge.color,3)
	for i in range(28):
		var p := Vector2(845+(i%4)*20,64+(i/4)*117) if village else Vector2(1010+(i%4)*32,492+(i/4)*28)
		if ground.get_cell_atlas_coords(Vector2i(p/32)).x not in [5,6]: continue
		p.x += sin(clock*0.6+i)*6
		draw_line(p,p+Vector2(10+i%5,0),Color("b4d1bb60"),2)
	# 蝶群以小幅环绕运动增加生气，模态暂停不会改变游戏规则。
	if not GameWeather.is_rainy() and GameClock.minutes < 1140:
		for i in range(8):
			var p := Vector2(240+i*126,620+sin(float(i))*110)+Vector2(sin(clock*0.65+i)*30,cos(clock+i)*12)
			var wing := 3.0 if sin(clock*8+i)>0 else 1.0
			draw_rect(Rect2(p-Vector2(wing,1),Vector2(wing*2,3)),Color("f5d99d"))
	for effect in effects:
		var progress: float = 1.0-effect.life/effect.total
		var tint := Color("8ebecb") if effect.kind=="浇水" else Color("c5a16b")
		if effect.kind == "收获": tint = Color("f7d887")
		tint.a = 1.0-progress
		for i in range(8):
			var direction := Vector2.RIGHT.rotated(float(i)*TAU/8)
			var p: Vector2 = effect.origin+direction*(8+progress*20)+Vector2(0,-sin(progress*PI)*14)
			draw_rect(Rect2(p,Vector2(3,3)),tint)
