extends Node2D
var star_id: String = ""
func _ready() -> void:
	add_to_group("interactables")
	Xiaojing.changed.connect(refresh)
	StarStory.changed.connect(refresh)
	FarmLayout.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var fixture: String=StarStory.point_fixture(star_id)
	if fixture!="": set_meta("farm_fixture",fixture)
	position=StarStory.point(star_id)
	visible=Xiaojing.state.unlocked and StarStory.point_active(star_id)
	queue_redraw()
func prompt() -> String:
	return StarStory.data.points[star_id].title
func interact() -> void:
	Events.interaction_requested.emit("star:"+star_id)
func _draw() -> void:
	if star_id=="greenhouse":
		draw_rect(Rect2(-12,-15,24,18),Color("a68464"))
		draw_rect(Rect2(-9,-13,18,5),Color("eee1b5"))
	elif star_id=="seed_box":
		draw_rect(Rect2(-16,-20,32,20),Color("9e754e"))
		for x in [-9,0,9]: draw_circle(Vector2(x,-11),3,Color("ebc878"))
	else:
		draw_rect(Rect2(-21,-17,42,13),Color("ae8f65"))
		draw_line(Vector2(-17,-4),Vector2(-17,6),Color("725139"),3)
		draw_line(Vector2(17,-4),Vector2(17,6),Color("725139"),3)
		draw_rect(Rect2(-13,-15,14,8),Color("ece0b4"))
		if star_id=="desk_right": draw_circle(Vector2(12,-23),5,Color("ffe5a0") if Xiaojing.state.married or StarStory.state.wedding_phase>0 else Color("768988"))
