extends Node2D
var fish_point_id: String = "farm_lake"
var redraw_timer: float = 0
func _ready() -> void:
	add_to_group("interactables")
	Fishing.changed.connect(queue_redraw)
	FarmLayout.changed.connect(refresh_layout);refresh_layout()
func refresh_layout() -> void:
	if fish_point_id=="farm_lake": set_meta("farm_fixture","fishing_farm")
	position=Fishing.point(fish_point_id)
	visible=fish_point_id!="farm_lake" or FarmLayout.active("fishing_farm")
	queue_redraw()
func prompt() -> String:
	if not Fishing.site_has_water(fish_point_id): return "钓鱼点 · 请先布置水池或移到水岸"
	return Fishing.sites[fish_point_id].name+" · 抛竿" if GameState.tool()=="fishing_rod" else "钓鱼点 · 装备鱼竿后抛竿"
func interact() -> void:
	Events.interaction_requested.emit("fishing:"+fish_point_id)
func hit_rect() -> Rect2:
	return Rect2(-20,-36,40,52)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if Fishing.session.site!=fish_point_id or not Fishing.active(): return
	redraw_timer+=delta
	if redraw_timer>=.08: redraw_timer=0;queue_redraw()
func _draw() -> void:
	var water: Vector2=Fishing.point(fish_point_id,true)-position
	draw_rect(Rect2(-4,-7,8,14),Color("7d7355"))
	draw_rect(Rect2(-14,-23,28,15),Color("c7ad73"))
	draw_arc(Vector2(-1,-15),5,0,TAU,10,Color("536f69"),1)
	draw_line(Vector2(3,-14),Vector2(10,-14),Color("536f69"),1)
	draw_line(Vector2(-1,-15),Vector2(-4,-19),Color("536f69"),1)
	if Fishing.session.site!=fish_point_id or not Fishing.active(): return
	var player: Node2D=Fishing.game.player
	var hand: Vector2=to_local(player.global_position)+Vector2(0,-22)
	var tip: Vector2=hand+(water-hand).normalized()*30+Vector2(0,-18)
	draw_line(hand,tip,Color("d9b77d"),2)
	draw_line(tip,water+Vector2(0,sin(Fishing.session.elapsed*5)*2),Color("d5dac8"),1)
	draw_arc(water,9+sin(Fishing.session.elapsed*4)*2,0,TAU,20,Color("b6d4ca99"),1)
	draw_rect(Rect2(water+Vector2(-2,-7),Vector2(4,6)),Color("d86c57"))
	draw_rect(Rect2(water+Vector2(-2,-1),Vector2(4,3)),Color("eee5bd"))
