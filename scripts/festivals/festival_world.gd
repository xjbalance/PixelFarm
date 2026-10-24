class_name FestivalWorld
extends Node2D
## 节日仅叠加装饰与赛事田标记；不重建地图、碰撞、原风灯或玩家的农田。
var points: Dictionary = {}
var game: Node
func attach(owner_game: Node) -> void:
	game=owner_game;Festival.bind(game);add_to_group("festival_worlds")
	for id in Festival.IDS:
		var event: Dictionary=Festival.data.events[id]
		var point := Node2D.new();point.set_script(preload("res://scripts/festivals/festival_point.gd"))
		point.festival_id=id;point.position=Vector2(event.board[0],event.board[1])
		var parent: Node=game.world.get_node("Actors") if event.area=="farm" else game.village.get_node("Actors")
		parent.add_child(point);points[id]=point
	var patch := Node2D.new();patch.set_script(preload("res://scripts/festivals/festival_patch.gd"))
	game.world.add_child(patch)
	Festival.changed.connect(refresh);Calendar.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var season_id: String=Festival.IDS[Calendar.season()]
	for id in points:
		var run: Dictionary=Festival.run_for(id)
		var pending: bool=not run.is_empty() and run.ready and not run.claimed
		# 同位置秋冬牌只显示当季；面板同时提供所有可在此处领取的待发纪念。
		points[id].visible=id==season_id or (pending and id in ["spring","summer"])
		points[id].queue_redraw()
