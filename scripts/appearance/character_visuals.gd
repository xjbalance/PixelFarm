class_name CharacterVisuals
extends RefCounted
## 四个方案C角色共用同一帧协议；只设置精灵，不改变脚底物理坐标。
const OFFSET:=Vector2(0,-21)
const ROWS:=4
const COLUMNS:=4
const WALK_FPS:=6.0

static func apply(sprite: Sprite2D, identity: String, ceremony: bool=false) -> bool:
	var path: String=Appearance.player_asset(ceremony) if identity=="player" else Appearance.companion_asset(ceremony)
	if not ResourceLoader.exists(path): return false
	var key: String=identity+":"+path
	if sprite.get_meta("appearance_key","")!=key:
		sprite.texture=load(path);sprite.hframes=COLUMNS;sprite.vframes=ROWS;sprite.frame=0
		sprite.set_meta("appearance_key",key);sprite.set_meta("appearance_variant",Appearance.player_variant() if identity=="player" else Appearance.companion_variant())
		sprite.set_meta("scheme_c",true);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=OFFSET
	return true

static func row(direction: Vector2) -> int:
	if absf(direction.x)>absf(direction.y): return 1 if direction.x<0 else 2
	return 3 if direction.y<0 else 0

static func animate(sprite: Sprite2D, direction: Vector2, moving: bool, time: float) -> void:
	if not sprite.get_meta("scheme_c",false): return
	sprite.frame=row(direction)*4+(int(time*WALK_FPS)%4 if moving else 0)
	sprite.position=OFFSET
