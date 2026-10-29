class_name WorkshopVisual
extends RefCounted
## Presentation only: native AnimatedSprite2D frames share one atlas, never advance production.
static var definition: Dictionary={}
static var cached_frames: Dictionary={}
static func config() -> Dictionary:
	if definition.is_empty(): definition=JSON.parse_string(FileAccess.get_file_as_string("res://resources/presentation/workshop_visuals.json"))
	return definition
static func frames_for(station: String) -> SpriteFrames:
	if cached_frames.has(station): return cached_frames[station]
	if not config().stations.has(station): return null
	var row: Dictionary=config().stations[station]
	var frames:=SpriteFrames.new();frames.remove_animation("default");frames.add_animation("work");frames.set_animation_speed("work",float(row.fps));frames.set_animation_loop("work",true)
	var atlas: Texture2D=load(str(config().texture))
	for i in range(int(row.frames)):
		var frame:=AtlasTexture.new();frame.atlas=atlas;frame.filter_clip=true;frame.region=Rect2(i*32,int(row.row)*56,32,56);frames.add_frame("work",frame)
	cached_frames[station]=frames;return frames
static func status(id: String) -> String:
	var job: Dictionary=Workshop.state.jobs.get(id,{})
	if job.is_empty(): return "idle"
	return "ready" if Workshop.now_minutes()>=int(job.finish_at) else "working"
static func sync(object: Node2D) -> void:
	if object.entry.is_empty() or not str(object.entry.kind).begins_with("station_"): return
	var station: String=str(object.entry.kind).trim_prefix("station_")
	var frames:=frames_for(station)
	if frames==null: return
	var state:=status(str(object.entry_id))
	var sprite: AnimatedSprite2D=object.animated
	if sprite.sprite_frames!=frames:
		sprite.sprite_frames=frames;sprite.animation="work";sprite.frame=0
		sprite.position=object.sprite.position-Vector2(0,4)
	var active: bool=state=="working"
	object.sprite.visible=not active;sprite.visible=active
	var running: bool=active and object.is_visible_in_tree() and GameClock.running and not GameState.modal and not GameState.restoring and is_instance_valid(Workshop.game) and not Workshop.game.backgrounded
	if running:
		if not sprite.is_playing(): sprite.play("work")
	elif active: sprite.pause()
	else: sprite.stop()
	if object.get_meta("workshop_visual_status","")!=state:
		object.set_meta("workshop_visual_status",state);object.queue_redraw()
