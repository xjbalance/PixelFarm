extends Node2D
## 剖面暖舍的地板层放在动物后方，前后棚口保持可见且可通行。
var site: String="coop"
func _draw() -> void:
	if Livestock.building(site).level==0: return
	draw_rect(Rect2(-14,-66,28,25),Color("897357"))
	draw_rect(Rect2(-58,-47,116,80),Color("655d49"))
	draw_rect(Rect2(-54,-43,108,72),Color("aa996d"))
	for x in range(-48,50,16):
		for y in [-34,-10,16]:
			draw_line(Vector2(x,y),Vector2(x+7,y+3),Color("d0bd85"),1)
	draw_rect(Rect2(-50,-42,22,6),Color("787354"))
	draw_rect(Rect2(30,-42,20,6),Color("86a1a0"))
