extends Node2D
## A real clickable nest backed by the same per-animal safe product inventory.
var site: String="coop"
var area_id: String="farm"
var livestock_id: String="nest:coop"
var effect: float=0
var label: Label
var art: Texture2D=preload("res://assets/livestock/ranch082/nest.png")
func _ready() -> void:
	add_to_group("interactables")
	label=FarmUIStyle.label("",12,FarmUIStyle.CREAM);label.position=Vector2(-52,-40);label.size=Vector2(104,18)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
	Livestock.changed.connect(refresh);FarmLayout.changed.connect(refresh)
	Events.livestock_collected.connect(func(which: String):
		if which==site: effect=.8;set_process(true)
	)
	set_process(false);refresh()
func refresh() -> void:
	position=Livestock.nest_point(site,area_id);visible=FarmLayout.active(site) and int(Livestock.building(site).level)>0
	var count: int=int(Livestock.summary(site).products)
	label.text="鸡窝 · 待收%d枚" % count if count>0 else "鸡窝"
	queue_redraw()
func hit_rect() -> Rect2: return Rect2(-25,-28,50,38)
func prompt() -> String: return "查看鸡窝 · 收取鸡蛋和鸭蛋"
func interact() -> void: Events.interaction_requested.emit("livestock:nest:"+site)
func _process(delta: float) -> void:
	effect=maxf(0,effect-delta);queue_redraw()
	if effect<=0: set_process(false)
func _draw() -> void:
	draw_texture(art,Vector2(-24,-32))
	if effect>0:
		for i in range(6):
			var at:=Vector2.from_angle(i*TAU/6)*(1-effect)*24+Vector2(0,-14-(1-effect)*18)
			draw_rect(Rect2(at,Vector2(3,3)),Color(Color("f7e8a5"),effect))
