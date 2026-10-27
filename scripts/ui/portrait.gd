class_name FarmPortrait
extends Control
## 同一色板的原生像素头像；头像身份和对白发言者同步切换。
var person: String = "letter":
	set(value):
		person = value
		queue_redraw()
var avatar_missing: bool=false
var _avatar_path: String=""
var _avatar_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(132,148)
	var appearance:=get_node_or_null("/root/Appearance")
	if appearance and appearance.has_signal("changed"): appearance.changed.connect(refresh_avatar)

func refresh_avatar() -> void:
	_avatar_path="";_avatar_texture=null;queue_redraw()

func current_avatar_path() -> String:
	var role: String="player" if person in ["player","you","farmer"] else "xiaojing" if person in ["xiaojing","companion"] else ""
	var appearance:=get_node_or_null("/root/Appearance")
	return str(appearance.portrait_asset(role)) if role!="" and appearance and appearance.has_method("portrait_asset") else ""

func draw_character_avatar() -> void:
	var path:=current_avatar_path()
	if path!=_avatar_path or (_avatar_texture==null and path!="" and ResourceLoader.exists(path)):
		_avatar_path=path;_avatar_texture=load(path) if path!="" and ResourceLoader.exists(path) else null
	avatar_missing=_avatar_texture==null
	draw_rect(Rect2(Vector2.ZERO,size),Color("ead8ae"))
	draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("b68a59"),false,1)
	if _avatar_texture:
		var factor:=minf((size.x-8)/_avatar_texture.get_width(),(size.y-8)/_avatar_texture.get_height())
		var extent: Vector2=(_avatar_texture.get_size()*factor).floor()
		draw_texture_rect(_avatar_texture,Rect2(((size-extent)*.5).floor(),extent),false)
	else:
		# 缺少正式头像时明确留空，不绘制另一性别或旧小京来冒充。
		var center:=size*.5
		draw_line(center-Vector2(5,5),center+Vector2(5,5),FarmUIStyle.MUTED,2)
		draw_line(center+Vector2(-5,5),center+Vector2(5,-5),FarmUIStyle.MUTED,2)

func _draw() -> void:
	if person in ["player","you","farmer","xiaojing","companion"]:
		draw_character_avatar();return
	var zoom := minf(size.x/44.0,size.y/48.0)
	draw_set_transform(Vector2((size.x-44*zoom)/2,(size.y-48*zoom)/2),0,Vector2(zoom,zoom))
	draw_rect(Rect2(0,0,44,48),Color("344c49"))
	draw_rect(Rect2(2,2,40,44),Color("47615a"))
	for i in range(7): draw_rect(Rect2(4+i*5,5+(i%3)*4,2,2),Color("678269"))
	if person == "letter":
		draw_rect(Rect2(10,10,24,29),Color("8f7354"))
		draw_rect(Rect2(8,8,24,29),Color("eee0b9"))
		for y in [15,19,23]: draw_rect(Rect2(12,y,15 if y!=19 else 12,1),Color("a58c68"))
		draw_rect(Rect2(17,29,7,4),Color("b86b51"))
		draw_rect(Rect2(19,27,3,8),Color("b86b51"))
		return
	var skin := Color("e8b98c")
	var hair := Color("564343")
	var coat := Color("a585aa")
	if person == "xiaojing": hair = Color("4d424c"); coat = Color("668c91")
	elif person == "zhou": hair = Color("4a4944"); coat = Color("739798")
	elif person == "ahe": hair = Color("c8c2af"); coat = Color("be8e67")
	draw_rect(Rect2(9,35,28,11),coat.darkened(0.3))
	draw_rect(Rect2(11,33,24,13),coat)
	draw_rect(Rect2(18,32,8,7),skin.darkened(0.15))
	draw_rect(Rect2(17,39,10,7),Color("e3c99c"))
	draw_rect(Rect2(11,12,23,19),hair)
	draw_rect(Rect2(14,18,17,16),skin)
	draw_rect(Rect2(12,22,3,7),skin.darkened(0.1))
	draw_rect(Rect2(31,22,3,7),skin.darkened(0.1))
	draw_rect(Rect2(15,15,16,6),hair)
	draw_rect(Rect2(15,20,3,3),hair)
	draw_rect(Rect2(19,24,2,2),Color("3b3e3a"))
	draw_rect(Rect2(27,24,2,2),Color("3b3e3a"))
	draw_rect(Rect2(16,28,4,2),Color("d9967c"))
	draw_rect(Rect2(28,28,3,2),Color("d9967c"))
	draw_rect(Rect2(23,31,3,1),Color("aa765e"))
	if person == "linya":
		draw_rect(Rect2(13,8,18,8),Color("9d8bab"))
		draw_rect(Rect2(7,15,30,3),Color("cab3c3"))
		draw_rect(Rect2(14,12,16,2),Color("e6cba5"))
		draw_rect(Rect2(30,11,4,4),Color("edcb91"))
		draw_rect(Rect2(10,28,4,10),hair)
	elif person == "xiaojing":
		draw_rect(Rect2(30,17,5,23),hair)
		draw_rect(Rect2(29,14,6,3),Color("b6c98e"))
	elif person == "zhou":
		draw_rect(Rect2(13,11,18,7),hair)
		draw_rect(Rect2(15,11,6,2),Color("72766b"))
		draw_rect(Rect2(17,30,13,4),hair.lightened(0.1))
		draw_rect(Rect2(22,30,4,1),skin)
	elif person == "ahe":
		draw_rect(Rect2(9,7,10,9),hair)
		draw_rect(Rect2(13,10,18,8),hair)
		for x in [17,25]: draw_rect(Rect2(x,22,6,5),Color("8b7a66"),false,1)
		draw_rect(Rect2(23,24,2,1),Color("8b7a66"))
