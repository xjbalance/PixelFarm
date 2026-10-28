class_name SchemeCAssets
extends RefCounted
## User-supplied native 32px art. These helpers change presentation only.
const SEASONS: Array[String]=["spring","summer","autumn","winter"]
const ROOT: String="res://assets/world_scheme_c/"
static var _manifest: Dictionary={}
static var _textures: Dictionary={}
static var _animations: Dictionary={}

static func catalog() -> Dictionary:
	if _manifest.is_empty():
		var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if raw is Dictionary: _manifest=raw.get("assets",{})
	return _manifest

static func definition(id: String) -> Dictionary:
	return catalog().get(id,{})

static func texture(id: String, season: int=-1) -> Texture2D:
	var info:=definition(id)
	if info.is_empty(): return null
	var path: String=str(info.path)
	if season>=0 and season<4:
		var seasonal: String=ROOT+"seasons/"+SEASONS[season]+"/"+id+".png"
		if ResourceLoader.exists(seasonal): path=seasonal
	if not _textures.has(path): _textures[path]=load(path)
	return _textures[path]

static func offset(id: String) -> Vector2:
	var info:=definition(id)
	if info.is_empty(): return Vector2.ZERO
	var size: Array=info.size;var anchor: Array=info.anchor
	return Vector2(float(size[0])*.5-float(anchor[0]),float(size[1])*.5-float(anchor[1]))

static func animation(id: String) -> SpriteFrames:
	if _animations.has(id): return _animations[id]
	var info:=definition(id)
	var result: SpriteFrames=load(str(info.animation)) if info.has("animation") else null
	_animations[id]=result
	return result

static func make_sprite(id: String, season: int=-1) -> Node2D:
	var frames:=animation(id)
	var result: Node2D
	if frames:
		var animated:=AnimatedSprite2D.new();animated.sprite_frames=frames;animated.play("loop");result=animated
	else:
		var still:=Sprite2D.new();still.texture=texture(id,season);result=still
	result.position=offset(id);result.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	result.set_meta("scheme_c_id",id)
	return result

static func home_texture(id: String) -> Texture2D:
	var path: String=ROOT+"derived/home_"+id+".png"
	return load(path) if ResourceLoader.exists(path) else null

static func furniture_texture(kind: String) -> Texture2D:
	var path: String=ROOT+"derived/furniture_"+kind+".png"
	return load(path) if ResourceLoader.exists(path) else null

static func has_repeat(id: String) -> bool:
	return ResourceLoader.exists(ROOT+"modules/"+id+".png")

static func placed_texture(id: String, extent: Vector2, season: int=-1) -> Texture2D:
	if not has_repeat(id): return texture(id,season)
	var key: String="module:"+id+":"+str(extent)+":"+str(season)
	if not _textures.has(key):
		var path: String=ROOT+"seasons/"+SEASONS[season]+"/modules/"+id+".png" if season>=0 and season<4 else ROOT+"modules/"+id+".png"
		var module: Texture2D=load(path)
		var image:=Image.create(int(extent.x),int(extent.y),false,Image.FORMAT_RGBA8)
		var tile: Image=module.get_image()
		for y in range(0,int(extent.y),32):
			for x in range(0,int(extent.x),32): image.blit_rect(tile,Rect2i(0,0,32,32),Vector2i(x,y))
		_textures[key]=ImageTexture.create_from_image(image)
	return _textures[key]

static func draw(node: CanvasItem, id: String, at: Vector2=Vector2.ZERO, season: int=-1, scale: Vector2=Vector2.ONE) -> bool:
	var art:=texture(id,season)
	if not art: return false
	var top_left: Vector2=offset(id)-art.get_size()*.5
	node.draw_texture_rect(art,Rect2(at+top_left*scale,art.get_size()*scale),false)
	return true
