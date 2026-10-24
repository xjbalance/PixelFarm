extends Node2D
var exploration_id: String=""
func _ready() -> void:
	add_to_group("interactables");Exploration.changed.connect(queue_redraw)
func hit_rect() -> Rect2: return Rect2(-24,-42,48,58)
func prompt() -> String:
	var record: Dictionary=Exploration.definition(exploration_id)
	return str(record.get("title","调查遗址"))
func interact() -> void:
	if Exploration.game.player.action_time>0: return
	Events.interaction_requested.emit("exploration:"+exploration_id)
func _draw() -> void:
	var record: Dictionary=Exploration.definition(exploration_id)
	var kind: String=record.get("kind","entrance")
	var wood := Color("ac9270");var stone := Color("85998a")
	match kind:
		"entrance":
			draw_rect(Rect2(-24,-45,48,49),Color("5f7266"));draw_rect(Rect2(-16,-35,32,39),Color("344e47"))
			for x in [-28,23]: draw_rect(Rect2(x,-48,6,52),wood)
			draw_rect(Rect2(-30,-51,60,8),wood)
		"exit":
			for i in range(4): draw_rect(Rect2(-17,-i*6,34,4),stone)
			draw_line(Vector2(-8,-28),Vector2(8,-28),Color("d7c59a"),2)
		"note":
			draw_rect(Rect2(-13,-31,26,27),Color("76634f"));draw_rect(Rect2(-10,-28,20,20),Color("d6c69d"))
			for y in [-23,-18,-13]: draw_line(Vector2(-6,y),Vector2(6,y),Color("7d8d71"),1)
		"chest":
			draw_rect(Rect2(-17,-22,34,24),Color("75624d"));draw_rect(Rect2(-17,-22,34,6),wood)
			draw_rect(Rect2(-3,-17,6,10),Color("d4c28d") if exploration_id not in Exploration.state.chests else Color("515e51"))
		"plant":
			var previous: int=int(Exploration.state.gathered.get(exploration_id,0))
			var ready: bool=previous==0 or GameClock.day-previous>=int(record.interval)
			for x in [-8,0,8]:
				draw_line(Vector2(x,1),Vector2(x-3,-20),Color("6a8c62"),2)
				if ready: draw_rect(Rect2(x-7,-22,8,5),Color("b1c28a") if record.item=="forest_herb" else Color("c2c8a4"))
		"forest_rune","temple_rune":
			var symbol: int=record.symbol
			var lit: bool=(Exploration.state.forest.step>symbol if kind=="forest_rune" else Exploration.state.temple.step>symbol)
			draw_rect(Rect2(-12,-30,24,32),stone.darkened(.15));draw_rect(Rect2(-9,-28,18,22),stone)
			var color: Color=[Color("a5c881"),Color("71b596"),Color("d3ab67"),Color("d4e0d0")][symbol]
			if kind=="temple_rune": color=[Color("d8c07b"),Color("84bdb9"),Color("b0afe1")][symbol]
			draw_rect(Rect2(-5,-23,10,9),color if lit else color.darkened(.35))
			if lit: draw_circle(Vector2(0,-20),17,Color(color,.10))
		"mirror":
			draw_rect(Rect2(-5,-17,10,20),wood);draw_circle(Vector2(0,-24),16,Color("a9b7aa"));draw_circle(Vector2(0,-24),12,Color("d2d7b8"))
			var direction: Vector2=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT][int(Exploration.state.temple.mirror)]
			draw_line(Vector2(0,-24),Vector2(0,-24)+direction*11,Color("7c896f"),3)
		_:
			draw_rect(Rect2(-10,-13,20,16),Color("718982"))
			var active: bool=Exploration.state.lake.water<2 if kind=="valve_north" else Exploration.state.lake.flow==1 if kind=="flow" else Exploration.state.lake.open
			draw_line(Vector2.ZERO,Vector2(12 if active else -12,-29),wood,4);draw_circle(Vector2(12 if active else -12,-29),5,Color("a8c4ab"))
