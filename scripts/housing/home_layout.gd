class_name HomeLayout
extends RefCounted
## 房屋静态结构和可移动内置家具共用几何；默认锚点保留旧存档/测试坐标。
const ANCHORS := {"sleep":Vector2(786,342),"kitchen":Vector2(848,432),"storage":Vector2(384,496),"exit":Vector2(640,556),"mail":Vector2(720,274),"spouse":Vector2(720,452)}
const SOFA := Vector2(704,492)
const ESSENTIAL := ["bed","sofa","kitchen","storage","mail_desk"]
const STORY_ANCHORS := {"seed_box":Vector2(752,432),"window":Vector2(768,274),"hearth":Vector2(538,275),"spouse":Vector2(720,452)}

static func main_cells() -> Rect2i: return Rect2i(11,7,18,11)
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
	var result:=main_cells();var side:=extension_cells(level)
	return result.merge(side) if side.has_area() else result
static func placement_regions(level: int) -> Array[Rect2i]:
	var result: Array[Rect2i]=[main_cells()]
	if level>=2: result.append(extension_cells(level))
	return result
static func structure_rects(level: int) -> Array[Rect2]:
	var result: Array[Rect2]=[Rect2(928,192,16,400),Rect2(352,192,576,32),Rect2(352,576,576,16)]
	if level==1: result.append(Rect2(336,192,16,400))
	else:
		result.append(Rect2(336,192,16,224));result.append(Rect2(336,512,16,80))
	var side:=extension_cells(level)
	if side.has_area():
		var room:=Rect2(Vector2(side.position)*32,Vector2(side.size)*32)
		result.append(Rect2(room.position-Vector2(12,12),Vector2(room.size.x+12,12)))
		result.append(Rect2(Vector2(room.position.x-12,room.end.y),Vector2(room.size.x+12,12)))
		result.append(Rect2(room.position-Vector2(12,0),Vector2(12,room.size.y)))
	return result
static func _definition(id: String, title: String, art: String, position: Vector2, size: Vector2, sort_y: float, collision: Rect2=Rect2(), action: String="", approach: Vector2=Vector2.INF, layer: int=0) -> Dictionary:
	var reference: Vector2=collision.position if collision.has_area() else position
	return {"id":id,"name":title,"art":art,"position":position,"size":size,"sort_y":sort_y,"collision":collision,"solid":collision.has_area(),"action":action,"anchor":approach if approach!=Vector2.INF else position+size*.5,"layer":layer,"cell":Vector2i((reference/32).floor())}
static func definitions(level: int) -> Dictionary:
	var items: Array[Dictionary]=[
		_definition("bed","原木床","bed",Vector2(800,240),Vector2(96,128),368,Rect2(800,240,96,128),"sleep",ANCHORS.sleep),
		_definition("sofa","田园沙发","sofa",Vector2(660,448),Vector2(88,56),496,Rect2(668,472,72,24),"nap",SOFA),
		_definition("kitchen","小屋厨房","kitchen",Vector2(792,368),Vector2(128,72),418,Rect2(800,384,112,34),"kitchen",ANCHORS.kitchen),
		_definition("storage","储物柜","storage_slim",Vector2(352,432),Vector2(32,64),478,Rect2(360,456,16,22),"storage",ANCHORS.storage),
		_definition("dining_table","田园餐桌","dining_table",Vector2(560,288),Vector2(120,84),362,Rect2(570,304,100,58),"",Vector2(620,386)),
		_definition("chair_left","左餐椅","chair_left",Vector2(540,312),Vector2(28,48),350,Rect2(548,332,16,18),"",Vector2(556,374)),
		_definition("chair_right","右餐椅","chair_right",Vector2(672,312),Vector2(28,48),350,Rect2(676,332,16,18),"",Vector2(684,374)),
		_definition("dresser","原木斗柜","dresser",Vector2(392,216),Vector2(136,80),289,Rect2(400,244,120,45),"",Vector2(460,308)),
		_definition("mail_desk","信件书桌","mail_desk",Vector2(684,224),Vector2(88,56),258,Rect2(692,236,76,22),"mail",ANCHORS.mail),
		_definition("lamp","落地灯","lamp",Vector2(896,238),Vector2(32,48),284,Rect2(904,274,12,12),"",Vector2(904,306)),
		_definition("plant","绿叶盆栽","plant",Vector2(880,504),Vector2(40,64),568,Rect2(896,548,16,14),"",Vector2(904,528)),
		_definition("fireplace","暖炉","fireplace",Vector2(536,156),Vector2(96,112),254,Rect2(548,224,72,30),"",Vector2(584,274)),
		_definition("main_rug","起居地毯","main_rug",Vector2(520,394),Vector2(240,126),520,Rect2(),"",Vector2.INF,-3),
		_definition("dining_rug","餐厅地毯","dining_rug",Vector2(540,280),Vector2(176,104),384,Rect2(),"",Vector2.INF,-3),
		_definition("bed_rug","床边地毯","bed_rug",Vector2(790,232),Vector2(96,144),376,Rect2(),"",Vector2.INF,-3),
		_definition("kitchen_tiles","厨房地垫","kitchen_tiles",Vector2(784,368),Vector2(144,80),448,Rect2(),"",Vector2.INF,-4)
	]
	if level>=2:
		var room:=extension_cells(level);var start:=Vector2(room.position)*32;var extent:=Vector2(room.size)*32
		items.append(_definition("study_desk","侧厅工作桌","study_desk_"+str(level),start+Vector2(8,-16),Vector2(104 if level==2 else 192 if level==3 else 256,64),start.y+24,Rect2(start+Vector2(12,8),Vector2(extent.x-28,16)),"",start+Vector2(extent.x*.5,48)))
		items.append(_definition("study_rug","侧厅地毯","study_rug_2" if level==2 else "study_rug" if level==3 else "study_rug_4",start+Vector2(24 if level<4 else 32,40),Vector2(80,104) if level==2 else Vector2(176,176) if level==3 else Vector2(224,224),start.y+216,Rect2(),"",Vector2.INF,-3))
		items.append(_definition("study_plant","侧厅盆栽","plant",start+Vector2(-2,extent.y-64),Vector2(40,64),start.y+extent.y,Rect2(start+Vector2(14,extent.y-20),Vector2(12,14)),"",start+Vector2(46,extent.y-36)))
		if level>=3: items.append(_definition("bookcase_left","侧厅书柜","bookcase",start+Vector2(24,extent.y-48),Vector2(64,48),start.y+extent.y,Rect2(start+Vector2(28,extent.y-18),Vector2(56,14)),"",start+Vector2(56,extent.y-38)))
		if level>=4: items.append(_definition("bookcase_right","星光书柜","bookcase",start+Vector2(184,extent.y-48),Vector2(64,48),start.y+extent.y,Rect2(start+Vector2(188,extent.y-18),Vector2(56,14)),"",start+Vector2(216,extent.y-38)))
	if level>=3: items.append(_definition("divider","卧室屏风","bedroom_divider",Vector2(744,220),Vector2(56,152),304,Rect2(752,260,12,44),"",Vector2(784,280)))
	var result: Dictionary={}
	for item in items: result[item.id]=item
	return result
static func default_builtins(level: int) -> Dictionary:
	var result: Dictionary={};var all:=definitions(level)
	for id in all:
		var cell: Vector2i=all[id].cell;result[id]={"cell":[cell.x,cell.y]}
	return result
static func builtin_geometry(id: String, record: Dictionary, level: int) -> Dictionary:
	var all:=definitions(level)
	if not all.has(id): return {}
	return _geometry(all[id],record)
static func _geometry(definition: Dictionary, record: Dictionary) -> Dictionary:
	var result: Dictionary=definition.duplicate(true)
	var cell:=Vector2i(record.cell[0],record.cell[1]);var delta:=Vector2(cell-result.cell)*32
	result.cell=cell;result.position+=delta;result.sort_y+=delta.y;result.anchor+=delta
	if result.solid: result.collision.position+=delta
	result.footprint=Rect2(result.position,result.size);result.stored=record.get("stored",false)
	return result
static func builtin_layout(level: int, builtins: Dictionary={}) -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var all:=definitions(level)
	for id in all:
		var reference: Vector2i=all[id].cell
		var record: Dictionary=builtins.get(id,{"cell":[reference.x,reference.y]})
		result.append(_geometry(all[id],record))
	return result
static func anchor(action: String, level: int=1, builtins: Dictionary={}) -> Vector2:
	if action in ["sofa","home:nap"]: action="nap"
	for item in builtin_layout(level,builtins):
		if item.action==action and not item.stored: return item.anchor
	return ANCHORS.get(action,SOFA if action=="nap" else Vector2.INF)
static func blocked_rects(level: int, builtins: Dictionary={}) -> Array[Rect2]:
	var result:=structure_rects(level)
	for item in builtin_layout(level,builtins):
		if item.solid and not item.stored: result.append(item.collision)
	return result
static func floor_encloses(rect: Rect2, level: int) -> bool:
	if not rect.has_area(): return false
	var rooms: Array[Rect2]=[]
	for cells in placement_regions(level): rooms.append(Rect2(Vector2(cells.position)*32,Vector2(cells.size)*32))
	if level>=2: rooms.append(Rect2(336,416,42,96))
	for corner in [rect.position,Vector2(rect.end.x-.01,rect.position.y),rect.end-Vector2(.01,.01),Vector2(rect.position.x,rect.end.y-.01)]:
		var found: bool=false
		for room in rooms:
			if room.has_point(corner): found=true;break
		if not found: return false
	return true
static func clear_ray(from: Vector2, to: Vector2, obstacles: Array[Rect2], ignored: Rect2=Rect2()) -> bool:
	for rect in obstacles:
		if ignored.has_area() and rect==ignored: continue
		if rect.has_point(from) or rect.has_point(to): return false
		var a:=rect.position;var b:=Vector2(rect.end.x,rect.position.y);var c:=rect.end;var d:=Vector2(rect.position.x,rect.end.y)
		for edge in [[a,b],[b,c],[c,d],[d,a]]:
			if Geometry2D.segment_intersects_segment(from,to,edge[0],edge[1])!=null: return false
	return true
static func _clear_foot(rect: Rect2, level: int, obstacles: Array[Rect2]) -> bool:
	if not floor_encloses(rect,level): return false
	for obstacle in obstacles:
		# WorldNavigation的物理形状查询带0.01 margin，恰好贴边也会阻挡。
		# 纯数据校验同样保留微小间隙，不能把20px的零余量窄缝当成通路。
		if rect.grow(.02).intersects(obstacle): return false
	return true
static func routes_valid(level: int, builtins: Dictionary, extra: Array[Rect2]=[], player_position: Vector2=Vector2.INF) -> bool:
	var obstacles:=blocked_rects(level,builtins);obstacles.append_array(extra)
	var region:=navigation_region(level);var walk: Dictionary={}
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var cell:=Vector2i(x,y);var at:=Vector2(cell)*32+Vector2(16,16)
			if _clear_foot(Rect2(at-Vector2(10,10),Vector2(20,20)),level,obstacles): walk[cell]=true
	var exit: Vector2=ANCHORS.exit;var start:=Vector2i((exit/32).floor());var queue: Array[Vector2i]=[];var reached: Dictionary={}
	for y in range(start.y-1,start.y+2):
		for x in range(start.x-1,start.x+2):
			var cell:=Vector2i(x,y);var at:=Vector2(cell)*32+Vector2(16,16)
			if walk.has(cell) and _clear_foot(Rect2(exit,Vector2.ZERO).expand(at).grow(10),level,obstacles): queue.append(cell);reached[cell]=true
	if queue.is_empty(): return false
	var cursor: int=0
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor];cursor+=1
		for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var other: Vector2i=cell+step
			if reached.has(other) or not walk.has(other): continue
			var at:=Vector2(cell)*32+Vector2(16,16);var to:=Vector2(other)*32+Vector2(16,16)
			if _clear_foot(Rect2(at,Vector2.ZERO).expand(to).grow(10),level,obstacles): reached[other]=true;queue.append(other)
	# 每个房间至少有一处站位连到原门；不能把整间侧厅封死。
	for room in placement_regions(level):
		var connected: bool=false
		for cell in queue:
			if room.has_point(cell): connected=true;break
		if not connected: return false
	if player_position!=Vector2.INF:
		var connected: bool=false
		for cell in queue:
			var at:=Vector2(cell)*32+Vector2(16,16)
			if at.distance_to(player_position)<=64 and _clear_foot(Rect2(at,Vector2.ZERO).expand(player_position).grow(10),level,obstacles): connected=true;break
		if not connected: return false
	var targets: Array[Dictionary]=[]
	for at in STORY_ANCHORS.values(): targets.append({"point":at,"ignore":Rect2()})
	for item in builtin_layout(level,builtins):
		if item.id not in ESSENTIAL: continue
		if item.stored: return false
		targets.append({"point":item.anchor,"ignore":item.collision})
	for target in targets:
		var access: bool=false
		for cell in queue:
			var at:=Vector2(cell)*32+Vector2(16,16)
			if at.distance_to(target.point)<=54 and clear_ray(at,target.point,obstacles,target.ignore): access=true;break
		if not access: return false
	return true
static func geometry(level: int, builtins: Dictionary={}) -> Dictionary:
	var anchors:=ANCHORS.duplicate()
	for key in ["sleep","kitchen","storage","mail"]: anchors[key]=anchor(key,level,builtins)
	return {"main_cells":main_cells(),"extension_cells":extension_cells(level),"map_rect":map_rect(level),"navigation_region":navigation_region(level),"blocked_rects":blocked_rects(level,builtins),"anchors":anchors,"sofa":anchor("nap",level,builtins),"builtins":builtin_layout(level,builtins)}
