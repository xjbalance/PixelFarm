class_name LakeEcologyWorld
extends Node2D
var game: Node
var timer: float=0
func attach(owner_game: Node) -> void:
	game=owner_game;LakeEcology.game=game
	reparent(game.world,false);z_index=-4
	var point := Node2D.new();point.set_script(preload("res://scripts/ecology/ecology_point.gd"));point.position=LakeEcology.SHORE;game.world.get_node("Actors").add_child(point)
	LakeEcology.changed.connect(queue_redraw)
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not GameClock.running or GameState.modal: return
	timer+=delta
	if timer>=1: timer=0;queue_redraw()
func _draw() -> void:
	if not is_instance_valid(game): return
	var healthy: float=float(LakeEcology.state.health)/100
	var tint := Color("827e57").lerp(Color("5badae"),healthy);tint.a=.15
	for cell in game.world.ground.get_used_cells():
		if game.world.ground.get_cell_atlas_coords(cell).x in [5,6]: draw_rect(Rect2(Vector2(cell)*32,Vector2(32,32)),tint)
	for i in range(int(LakeEcology.state.plants)*2):
		var angle: float=float(i)*TAU/12
		var p := Vector2(1104,592)+Vector2(cos(angle),sin(angle))*102
		draw_line(p,p+Vector2(-3,-9),Color("507b58"),2);draw_line(p,p+Vector2(4,-11),Color("8cab6d"),2)
	if LakeEcology.state.health>=85:
		for p in [Vector2(1060,575),Vector2(1128,615),Vector2(1148,560)]:
			draw_rect(Rect2(p,Vector2(8,3)),Color("c2d5ac"));draw_line(p,p+Vector2(-3,2),Color("789c92"),2)
	for i in range(int(LakeEcology.state.debris)): draw_rect(Rect2(1032+i*32,650,10,5),Color("88735a"))
