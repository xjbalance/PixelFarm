class_name FarmVisual06
extends Node2D
## 原地面碰撞层上方的一张缓存像素图纸；只换显示，不改TileMap格、实体或进度。
const SEASONS: Array[String]=["spring","summer","autumn","winter"]
var ground_detail: Sprite2D
var trees: Array[Sprite2D]=[]
var applied_season: int=-1
var dirty: bool=true
var refresh_queued: bool=false
func _ready() -> void:
	name="GroundDetail06";z_index=-4
	ground_detail=Sprite2D.new();ground_detail.centered=false;ground_detail.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(ground_detail)
	for child in get_parent().find_children("*","Sprite2D",true,false):
		if child.get_parent() is StaticBody2D and "resource_id" in child.get_parent() and child.get_parent().kind=="tree": trees.append(child)
	Calendar.changed.connect(refresh);GameClock.changed.connect(refresh)
	Territory.changed.connect(invalidate);FarmLayout.changed.connect(invalidate)
	refresh()
func invalidate() -> void:
	dirty=true
	# Tile collision changes are synchronous; only the bitmap rebuild is deferred.
	FarmTerrain.apply(get_parent())
	if refresh_queued: return
	refresh_queued=true;call_deferred("refresh")
func refresh() -> void:
	refresh_queued=false
	var season: int=Calendar.season()
	if season==applied_season and not dirty: return
	applied_season=season;dirty=false
	FarmTerrain.apply(get_parent())
	ground_detail.texture=FarmTerrain.texture(season)
	ground_detail.set_meta("season",season);ground_detail.set_meta("effective_farm_terrain",true)
	for sprite in trees:
		if not is_instance_valid(sprite): continue
		sprite.get_parent().refresh_art()
