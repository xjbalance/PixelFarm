class_name HomeLayout
extends RefCounted
## 室内几何单一来源。原交互坐标与1–3级自由布置区保留，装饰不侵入允许区。
const ANCHORS := {"sleep":Vector2(786,342),"kitchen":Vector2(848,432),"storage":Vector2(384,496),"exit":Vector2(640,556),"mail":Vector2(720,274),"spouse":Vector2(720,452)}
const SOFA := Vector2(704,492)

static func main_cells() -> Rect2i:
	return Rect2i(11,7,18,11)

static func extension_cells(level: int) -> Rect2i:
	if level>=4: return Rect2i(2,7,9,11)
	if level==3: return Rect2i(4,8,7,9)
	if level==2: return Rect2i(7,12,4,5)
	return Rect2i()

static func map_rect(level: int) -> Rect2:
	var result:=Rect2(320,144,640,464)
	var cells:=extension_cells(level)
	if cells.has_area():
		var floor:=Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32)
		result=result.merge(Rect2(floor.position-Vector2(12,48),floor.size+Vector2(24,60)))
	return result

static func navigation_region(level: int) -> Rect2i:
	var result:=main_cells()
	var side:=extension_cells(level)
	return result.merge(side) if side.has_area() else result

static func blocked_rects(level: int) -> Array[Rect2]:
	var result: Array[Rect2]=[
		Rect2(928,192,16,400),Rect2(352,192,576,32),Rect2(352,576,576,16),
		Rect2(800,240,96,128),Rect2(400,244,120,45),Rect2(570,304,100,58),
		Rect2(548,332,16,18),Rect2(676,332,16,18),
		Rect2(800,384,112,34),Rect2(692,236,76,22),Rect2(548,224,72,30),
		Rect2(360,456,16,22),Rect2(904,274,12,12),Rect2(896,548,16,14)
	]
	if level>=3: result.append(Rect2(752,224,12,80))
	if level==1: result.append(Rect2(336,192,16,400))
	else:
		result.append(Rect2(336,192,16,224));result.append(Rect2(336,512,16,80))
	var side:=extension_cells(level)
	if side.has_area():
		var room:=Rect2(Vector2(side.position)*32,Vector2(side.size)*32)
		result.append(Rect2(room.position-Vector2(12,12),Vector2(room.size.x+12,12)))
		result.append(Rect2(Vector2(room.position.x-12,room.end.y),Vector2(room.size.x+12,12)))
		result.append(Rect2(room.position-Vector2(12,0),Vector2(12,room.size.y)))
		# 书桌仅占侧间最上面一排，允许摆放区都从下一排开始。
		result.append(Rect2(room.position+Vector2(12,8),Vector2(room.size.x-28,16)))
		if level>=3: result.append(Rect2(room.position.x+28,room.end.y-18,56,14))
		if level>=4: result.append(Rect2(room.position.x+188,room.end.y-18,56,14))
	return result

static func geometry(level: int) -> Dictionary:
	return {"main_cells":main_cells(),"extension_cells":extension_cells(level),"map_rect":map_rect(level),"navigation_region":navigation_region(level),"blocked_rects":blocked_rects(level),"anchors":ANCHORS.duplicate(),"sofa":SOFA}
