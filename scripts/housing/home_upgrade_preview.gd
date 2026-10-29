extends Control
## 清楚标注为布局示意，不把示意图当作游戏截图；实际房屋仍由HomeLayout定义。
var level: int=2
func _ready() -> void:
	custom_minimum_size=Vector2(0,148);mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var bounds:=HomeLayout.map_rect(level)
	var scale: float=minf((size.x-24)/bounds.size.x,(size.y-24)/bounds.size.y)
	var origin: Vector2=(size-bounds.size*scale)/2-bounds.position*scale
	var floor:=HomeLayout.main_cells()
	for rect in [floor,HomeLayout.extension_cells(level)]:
		if not rect.has_area(): continue
		var room:=Rect2(Vector2(rect.position)*32,Vector2(rect.size)*32)
		draw_rect(Rect2(origin+room.position*scale,room.size*scale),FarmUIStyle.WOOD)
		draw_rect(Rect2(origin+room.position*scale,room.size*scale),FarmUIStyle.BROWN,false,2)
	for rect in [Rect2(800,240,96,128),Rect2(800,384,112,34),Rect2(660,456,88,48),Rect2(570,304,100,58)]:
		draw_rect(Rect2(origin+rect.position*scale,rect.size*scale),FarmUIStyle.GREEN if rect.size.y>60 else FarmUIStyle.BROWN)
