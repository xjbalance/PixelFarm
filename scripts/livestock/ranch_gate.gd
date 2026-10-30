extends Node2D
var game: Node
var site: String="coop"
var returning: bool=false
var service: bool=false
var livestock_id: String=""
var label: Label
var art: Texture2D
func _ready() -> void:
	art=load("res://assets/livestock/ranch082/"+("trough" if service else "gate")+".png")
	livestock_id=site if service else "pasture_gate:"+site
	add_to_group("interactables")
	label=FarmUIStyle.label("",12,FarmUIStyle.CREAM);label.position=Vector2(-100,-46);label.size=Vector2(200,20)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
	Livestock.changed.connect(refresh);FarmLayout.changed.connect(refresh);refresh()
func refresh() -> void:
	if not returning and not service: position=Livestock.gate_point(site)
	visible=FarmLayout.active(site) and int(Livestock.building(site).level)>0
	label.text="管理畜舍 · 饲料" if service else "返回自家农场" if returning else "后方牧场 →"
	queue_redraw()
func hit_rect() -> Rect2: return Rect2(-24,-34,48,46)
func prompt() -> String: return label.text
func interact() -> void:
	if service: Events.interaction_requested.emit("livestock:"+site)
	elif returning: game.change_location("farm",Livestock.gate_point(site)+Vector2(0,32))
	else: Livestock.enter_pasture(site)
func _draw() -> void:
	draw_texture(art,Vector2(-24,-34))
