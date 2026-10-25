extends Control
var rail_style: StyleBox
var fish_texture: Texture2D
func _ready() -> void:
	var species: String=Fishing.session.species
	fish_texture=load("res://assets/fishing/fish_eternal.png" if species=="eternal" else "res://assets/aquaculture/fish_"+species+".png")
	rail_style=FarmUIStyle.surface("secondary")
	custom_minimum_size=Vector2(160,220)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var rail := Rect2(20,8,56,maxf(40,size.y-16))
	draw_style_box(rail_style,rail)
	var available: float=rail.size.y-14
	var origin: float=rail.position.y+7
	var band_height: float=available*float(Fishing.session.band)
	var y: float=origin+available*float(Fishing.session.player)
	draw_rect(Rect2(rail.position.x+5,clampf(y-band_height/2,origin,origin+available-band_height),46,band_height),Color(FarmUIStyle.SUCCESS,.42))
	var fish_y: float=origin+available*float(Fishing.session.fish)
	draw_texture_rect(fish_texture,Rect2(rail.position.x+10,fish_y-11,34,22),false)
	draw_rect(Rect2(86,origin,16,available),FarmUIStyle.MUTED.lightened(.4))
	var filled: float=available*float(Fishing.session.progress)
	draw_rect(Rect2(87,origin+available-filled,14,filled),FarmUIStyle.SUCCESS)
	draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(112,size.y*.5),"让鱼留在",HORIZONTAL_ALIGNMENT_LEFT,-1,18,FarmUIStyle.TEXT)
	draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),Vector2(112,size.y*.5+26),"绿色区域",HORIZONTAL_ALIGNMENT_LEFT,-1,18,FarmUIStyle.TEXT)
