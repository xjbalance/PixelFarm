extends Node2D
var kind: String="ecology"
func _ready() -> void:
	add_to_group("interactables");LakeEcology.changed.connect(queue_redraw)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func prompt() -> String: return "湖泊生态 · 水样与循环设施"
func interact() -> void: Events.interaction_requested.emit("ecology")
func _draw() -> void:
	SchemeCAssets.draw(self,"square_table",Vector2(0,3))
	for x in [-8,0,8]: draw_line(Vector2(x,-18),Vector2(x,-9),Color("6b987c"),2)
	if LakeEcology.state.cycle:
		draw_circle(Vector2(-28,-10),11,Color("876c50"));draw_circle(Vector2(-28,-10),8,Color("85b6b1"))
		for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(Vector2(-28,-10),Vector2(-28,-10)+v*10,Color("c4ae77"),2)
