class_name RiverScenery
extends Node2D
## 可组合的像素陈设，所有尺寸对齐整数像素；装饰与可通行规则独立。
var kind: String = "bush"
var tone: Color = Color("bd8771")
var phase: float = 0
var caption: String = "河湾村 ↑"
const NEED_ART := {"bush":"bush","flowers":"flower_patch","lantern":"street_lamp","mail":"mailbox","sign":"road_sign","bench":"wood_bench","well":"well","cart":"handcart","table":"picnic_table","post":"notice_board","community":"notice_board","cooperative":"market_stall","fence":"wood_fence","garden":"flower_pot"}
const CJK: Font=preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc")
const REPLACEABLE_DECOR := ["bush","flowers","cart","lantern","garden"]
var _decor_covered: bool=false
var _collision_body: StaticBody2D
var _windmill_art: Node2D

func _ready() -> void:
	Story.changed.connect(queue_redraw)
	VillageProjects.changed.connect(queue_redraw)
	GameClock.changed.connect(queue_redraw)
	Calendar.changed.connect(queue_redraw)
	Territory.changed.connect(_refresh_cover)
	set_process(kind == "windmill")
	var footprints := {"mail":Rect2(-16,-16,32,20),"bench":Rect2(-36,-12,76,16),"well":Rect2(-28,-22,56,26),"cart":Rect2(-30,-20,62,24),"table":Rect2(-50,-23,104,27),"windmill":Rect2(-36,-45,72,49),"post":Rect2(-32,-16,64,20),"community":Rect2(-40,-20,80,24),"cooperative":Rect2(-48,-30,100,34)}
	if footprints.has(kind):
		var rect: Rect2 = footprints[kind]
		var body := StaticBody2D.new()
		_collision_body=body
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	if kind=="windmill" and SchemeCAssets.animation("windmill")!=null:
		_windmill_art=SchemeCAssets.make_sprite("windmill",Calendar.season());add_child(_windmill_art)
		set_process(false)
	_refresh_cover()

func _farm_scenery() -> bool:
	var ancestor: Node=get_parent()
	while ancestor:
		var farm: Variant=ancestor.get("world")
		if farm is Node and is_instance_valid(farm) and farm.is_ancestor_of(self): return true
		ancestor=ancestor.get_parent()
	return false

func _refresh_cover() -> void:
	# 只盖住农场纯装饰，不覆盖外部剧情可见性，也不动功能设施与原采集物。
	_decor_covered=kind in REPLACEABLE_DECOR and _farm_scenery() and Territory.edited_cell("farm",Vector2i((global_position/32).floor()))
	if is_instance_valid(_collision_body): _collision_body.collision_layer=0 if _decor_covered else 1
	queue_redraw()

func _caption_plate(text: String, baseline: float) -> void:
	var width: float=maxf(60,CJK.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12)
	draw_rect(Rect2(-width*.5,baseline-17,width,22),Color("79563b"))
	draw_rect(Rect2(-width*.5+2,baseline-15,width-4,18),Color("cfad79"))
	var text_width: float=CJK.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(CJK,Vector2(-text_width*.5,baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("59452f"))

func _draw_need() -> bool:
	if kind=="windmill":
		return is_instance_valid(_windmill_art) or SchemeCAssets.draw(self,"windmill",Vector2.ZERO,Calendar.season())
	if not NEED_ART.has(kind): return false
	if kind=="cooperative" and not VillageProjects.has_project("cooperative"):
		var drawn: bool=SchemeCAssets.draw(self,"firewood_pile",Vector2(-12,0),Calendar.season())
		SchemeCAssets.draw(self,"wood_crate",Vector2(20,0),Calendar.season())
		return drawn
	if kind=="bench" and VillageProjects.has_project("arbor"):
		SchemeCAssets.draw(self,"pavilion",Vector2.ZERO,Calendar.season())
	if kind=="lantern" and GameClock.minutes>=1080:
		draw_circle(Vector2(0,-42),28,Color("f9d78a12"));draw_circle(Vector2(0,-42),18,Color("f9d78a15"))
	var art_scale: Vector2=Vector2.ONE
	if kind=="mail": art_scale=Vector2(1.25,1.25)
	elif kind=="sign": art_scale=Vector2(2,2)
	elif kind=="bench" or kind=="table": art_scale=Vector2(1.5,1.5)
	elif kind=="well" or kind=="cooperative": art_scale=Vector2(1.35,1.35)
	elif kind=="cart" or kind=="post": art_scale=Vector2(1.4,1.4)
	elif kind=="community": art_scale=Vector2(1.7,1.7)
	elif kind in ["fence","garden"]: art_scale=Vector2(1.25,1.25)
	var id: String=NEED_ART[kind]
	if kind=="well" and not VillageProjects.has_project("well"):
		var art:=SchemeCAssets.texture(id,Calendar.season())
		if not art: return false
		var origin: Vector2=(SchemeCAssets.offset(id)-art.get_size()*.5)*art_scale
		draw_texture_rect(art,Rect2(origin,art.get_size()*art_scale),false,Color(.65,.67,.61))
		_caption_plate("旧井 · 待修",-18)
		return true
	if not SchemeCAssets.draw(self,id,Vector2.ZERO,Calendar.season(),art_scale): return false
	if kind=="sign": _caption_plate(caption,-49)
	elif kind=="community": _caption_plate("共建 %d/3" % VillageProjects.built.size(),-22)
	elif kind=="cooperative": _caption_plate("种子共仓",-38)
	elif kind=="well":
		draw_rect(Rect2(27,1,60,5),Color("6d9690"));draw_rect(Rect2(30,2,55,2),Color("adceba"))
	return true

func _process(delta: float) -> void:
	phase += delta*0.32
	queue_redraw()

func block(x: float,y: float,w: float,h: float,c: String) -> void:
	draw_rect(Rect2(x,y,w,h),Color(c))

func _draw() -> void:
	if _decor_covered or _draw_need(): return
	match kind:
		"bush":
			block(-25,-4,50,8,"345c4940")
			for p in [Vector2(-20,-14),Vector2(-8,-22),Vector2(8,-16)]:
				draw_rect(Rect2(p,Vector2(20,18)),Color("476c52"))
				draw_rect(Rect2(p+Vector2(2,-2),Vector2(14,8)),Color("719260"))
				for i in range(3): draw_rect(Rect2(p+Vector2(4+i*5,4+(i%2)*3),Vector2(3,3)),tone)
		"flowers":
			block(-24,-2,48,5,"405d4430")
			for i in range(7):
				var x := -21+i*7
				var y := -10-(i%3)*5
				block(x,y,2,-y,"4c794d")
				draw_rect(Rect2(x-2,y-4,6,6),tone)
				block(x,y-2,2,2,"f8e6ad")
		"lantern":
			block(-4,-64,8,66,"6e5946")
			block(-3,-64,2,64,"a88860")
			block(-5,-68,32,5,"6e5946")
			block(18,-67,2,8,"604d41")
			if GameClock.minutes >= 1080:
				draw_circle(Vector2(19,-48),35,Color("f9d78a12"))
				draw_circle(Vector2(19,-48),22,Color("f9d78a15"))
			block(10,-60,18,22,"664c3c")
			block(13,-57,12,16,"f6d28d" if GameClock.minutes>=1080 else "d3c5a0")
			block(18,-57,2,16,"b89360")
		"mail":
			block(-3,-25,7,28,"806348")
			block(-17,-48,34,25,"69564b")
			block(-15,-46,30,19,"a98862")
			block(-13,-43,26,5,"d9be87")
			block(-10,-36,18,3,"52473c")
			block(19,-50,3,23,"7e5b47")
			block(19,-50,11,8,"cf7656")
		"sign":
			block(-3,-30,6,34,"79604a")
			block(-33,-54,67,28,"705746")
			block(-31,-52,63,23,"c4a475")
			draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-27,-34),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("594f40"))
		"bench":
			for x in [-30,28]: block(x,-12,6,15,"594e42")
			for y in [-33,-23]: block(-34,y,72,7,"a08359")
			block(-38,-10,80,8,"c3a373")
			block(-35,-8,74,2,"e0bf83")
			if VillageProjects.has_project("arbor"):
				for x in [-47,47]: block(x,-92,5,100,"8f7755")
				for y in [-96,-90,-84]:block(-53,y,112,3,"b89b69")
				for x in range(-50,58,15):
					block(x,-100,10,15,"739968")
					block(x+3,-99,4,6,"a0b57c")
				block(-18,-18,8,8,"e9d4a8")
		"well":
			for y in range(-28,0,8):
				for x in range(-28,28,14):
					block(x,y,13,7,"81938a" if (x+y)%3 else "a8b3a0")
			block(-24,-30,48,5,"b8bd9d")
			block(-18,-30,36,7,"425e59")
			for x in [-31,29]: block(x,-65,5,68,"876b4d")
			block(-36,-66,75,6,"c39a69")
			block(1,-60,2,39,"d5bf91")
			if VillageProjects.has_project("well"):
				block(-40,-76,84,11,"9e7259")
				block(-34,-81,72,8,"c49b6f")
				block(-5,-36,15,13,"8abac0")
				block(27,1,60,5,"6d9690")
				block(30,2,55,2,"adceba")
		"cart":
			for x in [-25,19]:
				block(x,-11,9,15,"4d5145")
				block(x+3,-8,3,9,"bba275")
			block(-32,-38,70,30,"88684a")
			for y in [-35,-25,-15]:block(-30,y,66,7,"ba915f")
			for x in [-24,-4,16]:block(x,-43,16,10,"d3b87d")
		"table":
			for x in [-44,40]:block(x,-16,7,20,"785a43")
			block(-52,-30,108,24,"8d6547")
			block(-54,-34,112,22,"c39b69")
			block(-28,-33,44,21,"e4d5b1")
			for x in [-21,1,30]:
				draw_circle(Vector2(x,-25),7,Color("7f8e70"))
				draw_circle(Vector2(x,-26),4,Color("cba66c"))
		"ribbon":
			block(-3,-62,7,66,"796449")
			block(-3,-43,28,6,"82adb2")
			block(14,-37,5,15,"668e9b")
		"windmill":
			block(-40,-108,80,112,"79634f")
			block(-36,-100,72,99,"c5b28b")
			for y in range(-92,0,14):block(-36,y,72,2,"af9875")
			draw_colored_polygon(PackedVector2Array([Vector2(-51,-107),Vector2(0,-155),Vector2(51,-107)]),Color("69566a"))
			block(-12,-36,24,38,"655344")
			block(-5,-84,12,20,"739a9b")
			var pivot := Vector2(0,-110)
			for i in range(4):
				var angle := phase+float(i)*PI/2.0
				var tip := pivot+Vector2.RIGHT.rotated(angle)*75
				draw_line(pivot,tip,Color("755c48"),6)
				var side := Vector2(0,17).rotated(angle)
				var inner := pivot+Vector2.RIGHT.rotated(angle)*26
				draw_colored_polygon(PackedVector2Array([inner,tip,tip+side,inner+side]),Color("d7c7a0"))
				for k in range(3):
					var cross := inner.lerp(tip,float(k)/3.0)
					draw_line(cross,cross+side,Color("b39e79"),2)
			draw_circle(pivot,7,Color("725b48"))
		"festival":
			for x in [-65,65]:block(x,-85,6,89,"886d4e")
			draw_line(Vector2(-65,-82),Vector2(68,-82),Color("5d6550"),2)
			for x in [-45,-15,15,45]:
				block(x,-82,2,12,"a1946c")
				if Story.stage >= 8:
					draw_circle(Vector2(x,-60),24,Color("ffda8c12"))
					block(x-7,-72,15,22,"eccb88" if Story.lantern=="memory" else "9fcaaf")
					block(x-5,-69,10,15,"fff0b6")
					block(x,-51,2,7,"be7e60")
				else: block(x-3,-70,7,7,"998566")
		"post":
			for x in [-28,24]:block(x,-42,5,44,"82674c")
			block(-36,-70,74,40,"8b6d4b")
			block(-32,-67,66,32,"bfa177")
			for x in [-27,-7,13]:
				block(x,-63,16,22,"e2d6ae")
				block(x+3,-57,10,2,"9a9a78")
		"community":
			for x in [-35,31]:block(x,-60,6,65,"80634b")
			block(-44,-92,92,55,"6e5545")
			block(-40,-88,84,47,"ba9c70")
			for i in range(3):
				block(-33+i*25,-78,20,28,"d2d9ae" if i < VillageProjects.built.size() else "e8d9ae")
				block(-29+i*25,-73,11,2,"948568")
				block(-29+i*25,-66,11,2,"948568")
			draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-30,-28),"一起建河湾",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eed6a1"))
		"cooperative":
			if VillageProjects.has_project("cooperative"):
				block(-49,-67,104,71,"ac8b5d")
				for y in range(-60,0,12): block(-47,y,100,2,"8e7554")
				block(-58,-74,122,12,"506c5b")
				block(-52,-84,110,10,"67886b")
				block(-45,-61,94,9,"d8c9a0")
				for x in [-40,-12,16]:
					block(x,-39,23,31,"795f47")
					block(x+3,-34,17,17,"c9b784")
					block(x+8,-29,5,7,"8caa75")
				draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-27,-51),"种子共仓",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("635540"))
			else:
				for y in [-12,-5,2]:block(-36,y,80,5,"9d8763")
				block(-22,-30,24,18,"827351")
		"shop_sign":
			block(-39,-14,80,20,"6d5647")
			block(-37,-12,76,16,"d5b987")
			draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(-28,1),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("66533f"))
		"fence":
			for y in [-23,-12]:block(-32,y,64,5,"b39b70")
			for x in [-30,26]:block(x,-30,6,33,"cbb284")
		"garden":
			block(-22,-15,43,23,"94724f")
			for x in [-16,-2,12]:
				block(x,-26,3,21,"4d7554")
				block(x-4,-24,11,5,"8aa05f")
				block(x,-32,5,9,"d0b06b")
