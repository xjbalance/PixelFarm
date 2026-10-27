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
		if child.texture and child.texture.resource_path=="res://assets/tilesets/tree.png": trees.append(child)
	Calendar.changed.connect(refresh);GameClock.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var season: int=Calendar.season()
	if season==applied_season: return
	applied_season=season
	ground_detail.texture=load("res://assets/farm06/ground_"+SEASONS[season]+".png")
	for sprite in trees:
		if not is_instance_valid(sprite): continue
		var variant: int=int(str(sprite.get_parent().resource_id).hash()%3) if "resource_id" in sprite.get_parent() else 0
		var suffix: String="" if variant==0 else "_"+str(variant)
		sprite.texture=load("res://assets/farm06/tree_"+SEASONS[season]+suffix+".png")
