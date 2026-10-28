extends Node2D
## 权限网格仅在状态变化时缓存；预览没有碰撞、物品或存档副作用。
var controller: Node

func _draw() -> void:
	if not is_instance_valid(controller) or not controller.active: return
	for entry in controller.permission_overlay:
		draw_rect(entry.rect,entry.color)
		draw_rect(entry.rect,Color(entry.color,0.20),false,1)
	var plan: Dictionary=controller.preview_plan
	if plan.is_empty(): return
	var color:=Color("c2dd91") if plan.get("valid",false) else Color("dc795b")
	var rectangles: Array[Rect2]=controller.preview_rects()
	for rect in rectangles:
		draw_rect(rect,Color(color,0.25));draw_rect(rect.grow(-1),color,false,2)
	var texture: Texture2D=controller.preview_texture()
	if texture and not rectangles.is_empty():
		var rect: Rect2=rectangles[0]
		# 原生像素尺寸与同一脚底锚点，预览不拉伸树冠或池塘。
		var art: String=str(TerritoryCatalog.OBJECT_KINDS[str(plan.kind)].art)
		var extent: Vector2=texture.get_size()
		var origin: Vector2=rect.get_center()+TerritoryObject.art_position(art,rect.size)-extent*.5
		draw_texture_rect(texture,Rect2(origin,extent),false,Color(1,1,1,0.58))
