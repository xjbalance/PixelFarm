class_name GreenhouseVenue
extends Node2D
var ground: TileMapLayer
var actors: Node2D
var objects: Dictionary={}
var game: Node
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var couple: Node2D
var last_step: int=-1
var guests: Array[Sprite2D]=[]
func _ready() -> void:
	name="greenhouse"
	ground=TileMapLayer.new();ground.name="Ground";ground.z_index=-5;add_child(ground)
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	var ts := TileSet.new();ts.tile_size=Vector2i(32,32);ts.add_physics_layer();ts.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new();atlas.texture=preload("res://assets/tilesets/wedding_floor.png");atlas.texture_region_size=Vector2i(32,32);ts.add_source(atlas,0)
	for i in range(2):
		atlas.create_tile(Vector2i(i,0))
		if i==1:
			var t := atlas.get_tile_data(Vector2i(i,0),0);t.set_collision_polygons_count(0,1);t.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	ground.tile_set=ts
	for y in range(28):
		for x in range(40): ground.set_cell(Vector2i(x,y),0,Vector2i(0 if Rect2i(8,5,24,20).has_point(Vector2i(x,y)) else 1,0))
	add_point("ceremony_left","布置两人的研究桌",Vector2(520,520))
	add_point("ceremony_right","点亮星灯 · 最终确认",Vector2(760,520))
	add_point("vows","星灯下的约定",Vector2(640,360))
	add_point("venue_exit","返回农场",Vector2(640,780))
	add_point("archive","温室研究与婚后计划",Vector2(800,320))
	couple=add_point("ceremony_girl","与小京说话",Vector2(690,390))
	couple.person_id="xiaojing"
	couple.add_to_group("xiaojing")
	var bride := Sprite2D.new();bride.texture=preload("res://assets/characters/xiaojing_wedding.png");bride.position.y=-18;couple.add_child(bride)
	for i in range(3):
		var guest := Sprite2D.new();guest.texture=load("res://assets/characters/"+["linya","zhou","ahe"][i]+".png");guest.position=Vector2(520+i*120,650);actors.add_child(guest);guests.append(guest)
	music=AudioStreamPlayer.new();var song: AudioStreamWAV=preload("res://assets/audio/star_vow.wav").duplicate();song.loop_mode=AudioStreamWAV.LOOP_FORWARD;song.loop_begin=0;song.loop_end=int(song.get_length()*song.mix_rate);music.stream=song;music.volume_db=-20;add_child(music)
	ambience=AudioStreamPlayer.new()
	var air: AudioStreamWAV=preload("res://assets/audio/star_chimes.wav").duplicate()
	air.loop_mode=AudioStreamWAV.LOOP_FORWARD;air.loop_begin=0;air.loop_end=int(air.get_length()*air.mix_rate)
	ambience.stream=air;ambience.volume_db=-24;add_child(ambience)
	game.get_node("Audio").extra_channels.append(music)
	game.get_node("Audio").extra_channels.append(ambience)
	Events.location_changed.connect(func(id: String): music.stream_paused=id!="greenhouse";ambience.stream_paused=id!="greenhouse")
	GameClock.changed.connect(refresh)
	River.changed.connect(refresh);StarStory.changed.connect(refresh);refresh()
func add_point(id: String, title: String, at: Vector2) -> Node2D:
	var p := Node2D.new();p.set_script(preload("res://scripts/river/river_point.gd"));p.river_id=id;p.title=title;p.position=at;actors.add_child(p);objects[id]=p;return p
func refresh() -> void:
	if not is_instance_valid(couple): return
	var ceremony: bool=StarStory.state.wedding_phase in [1,2,3]
	couple.visible=ceremony or (Xiaojing.state.married and (GameClock.minutes<540 or (GameClock.minutes>=960 and GameClock.minutes<1080)))
	(couple.get_child(0) as Sprite2D).texture=preload("res://assets/characters/xiaojing_wedding.png") if ceremony else preload("res://assets/characters/xiaojing.png")
	for guest in guests: guest.visible=ceremony
	var step: int=River.state.wedding_step
	if step!=last_step:
		last_step=step
		couple.position=Vector2(690,390) if step<2 else Vector2(658,364)
	queue_redraw()
func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var present: bool=GameState.location=="greenhouse" and not game.backgrounded
	var active: bool=present and not game.get_node("Audio").muted
	if active and not music.playing and DisplayServer.get_name()!="headless": music.play();ambience.play()
	music.stream_paused=not active
	ambience.stream_paused=not active
	if present and River.state.wedding_step==1 and not GameState.modal: couple.position=couple.position.move_toward(Vector2(658,364),24*delta)
func _draw() -> void:
	for x in range(300,1000,48):
		draw_line(Vector2(x,200),Vector2(x,280),Color("849f93"),3)
		draw_circle(Vector2(x,280),4,Color("ffe3a0") if Xiaojing.state.married else Color("8c998b"))
	if Xiaojing.state.married:
		var stars := PackedVector2Array()
		for i in range(1314):
			var at := Vector2(300+(i%73)*9,205+int(i/73)*4)
			stars.append(at);stars.append(at+Vector2(2,0))
		draw_multiline(stars,Color("ffe3a0"),1)
	for at in [Vector2(520,520),Vector2(760,520)]:
		draw_rect(Rect2(at+Vector2(-32,-12),Vector2(64,18)),Color("ac8b69"))
		draw_circle(at+Vector2(-12,-18),5,Color("eadfc0"));draw_circle(at+Vector2(12,-18),5,Color("eadfc0"))
	draw_line(Vector2(640,320),Vector2(640,740),Color("c7b58c"),3)
func _exit_tree() -> void:
	if music: music.stop()
	if ambience: ambience.stop()
