class_name WorldContactShadow
extends Node2D
## Shared crisp ground contact; no collider or input node.
var extent:=Vector2(32,6)

func _ready() -> void:
	z_index=-1
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	paint(self,Vector2.ZERO,extent)

static func paint(node: CanvasItem, at: Vector2, size: Vector2) -> void:
	var width: float=roundf(size.x)
	var height: float=maxf(2,roundf(size.y))
	# A short stepped contact seats the supplied art on the ground without blur.
	node.draw_rect(Rect2(at+Vector2(-width*.5+6,0),Vector2(width-12,1)),Color("35584025"))
	node.draw_rect(Rect2(at+Vector2(-width*.5+3,1),Vector2(width-6,height-2)),Color("35584025"))
	node.draw_rect(Rect2(at+Vector2(-width*.5+6,height-1),Vector2(width-12,1)),Color("35584025"))
