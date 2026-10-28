class_name FarmVisual06
extends Node2D
## 原地面碰撞层上方的一张缓存像素图纸；只换显示，不改TileMap格、实体或进度。
const SEASONS: Array[String]=["spring","summer","autumn","winter"]
var ground_detail: Sprite2D
var trees: Array[Sprite2D]=[]
var applied_season: int=-1
func _ready() -> void:
	name="GroundDetail06";z_index=-4
	ground_detail=Sprite2D.new();ground_detail.centered=false;ground_detail.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(ground_detail)
	for child in get_parent().find_children("*","Sprite2D",true,false):
		if child.get_parent() is StaticBody2D and "resource_id" in child.get_parent() and child.get_parent().kind=="tree": trees.append(child)
	Calendar.changed.connect(refresh);GameClock.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var season: int=Calendar.season()
	if season==applied_season: return
	applied_season=season
	ground_detail.texture=load("res://assets/world_scheme_c/derived/farm_ground_"+SEASONS[season]+".png")
	for sprite in trees:
		if not is_instance_valid(sprite): continue
		sprite.get_parent().refresh_art()
