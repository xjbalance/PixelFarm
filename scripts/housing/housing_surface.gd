extends Node2D
## 仅替换原地板/墙纸外观和稀疏室内光影，不改布置记录或碰撞。
var game: Node
var original_floor: Texture2D
var sunlight: Texture2D
var glow_points: Array[Vector2]=[]
func _ready() -> void:
	z_index=0
	var atlas: TileSetAtlasSource=game.home.get_node("Floor").tile_set.get_source(0)
	original_floor=atlas.texture;sunlight=load("res://assets/housing/interior/sunbeam.png")
	GameClock.changed.connect(queue_redraw);refresh()
func refresh() -> void:
	var atlas: TileSetAtlasSource=game.home.get_node("Floor").tile_set.get_source(0)
	if Housing.state.appearance.floor=="floor": atlas.texture=load("res://assets/housing/interior/floor_pale_atlas.png")
	elif int(Housing.state.level)>=4: atlas.texture=load("res://assets/housing/interior/floor_estate_atlas.png")
	elif int(Housing.state.level)>=3: atlas.texture=load("res://assets/housing/interior/floor_polished_atlas.png")
	else: atlas.texture=original_floor
	glow_points.clear()
	for entry in HomeLayout.builtin_layout(int(Housing.state.level),Housing.state.get("builtins",{})):
		if bool(entry.get("stored",false)) or not bool(entry.get("visible",true)): continue
		if str(entry.id)=="lamp": glow_points.append(entry.position+Vector2(16,20))
		elif str(entry.id)=="fireplace": glow_points.append(entry.position+Vector2(48,84))
	queue_redraw()
func _draw() -> void:
	if GameClock.minutes<1140 and GameClock.minutes>=420 and sunlight:
		for point in [Vector2(644,214),Vector2(828,214)]:
			var clipped:=Rect2(point,sunlight.get_size()).intersection(Rect2(352,224,576,352))
			draw_texture_rect_region(sunlight,clipped,Rect2(clipped.position-point,clipped.size))
	if Housing.state.appearance.wallpaper=="wallpaper":
		# 背景墙纸在房间墙面同坐标绘制，窗口与家具单独分层。
		draw_texture(load("res://assets/housing/interior/wallpaper_sage.png"),Vector2(336,160))
	if GameClock.minutes>=1140:
		# 手绘低强度暖光，不增加移动端实时灯光节点。
		for at in glow_points:
			draw_circle(at,42,Color(1,.68,.30,.025));draw_circle(at,27,Color(1,.75,.40,.035))
