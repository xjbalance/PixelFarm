class_name FarmLayoutWorld
extends Node
## Moves the original entities as groups. Business state and fixed identities stay owned
## by their existing systems; this adapter only changes presentation and geometry.
var game: Node
var groups: Dictionary={}
var _bodies: Dictionary={}
var _cache: Dictionary={}
var _refreshing: bool=false
var _generation: int=0
var _layout_signature: int=-1

func setup(owner_game: Node) -> void:
	game=owner_game
	collect()
	FarmLayout.bind(game,validate_plan)
	FarmLayout.changed.connect(refresh)
	Events.navigation_changed.connect(invalidate)
	for source in [Housing,Livestock,Aquaculture,FarmProgress,Xiaojing,StarStory]: source.changed.connect(refresh)
	refresh()

func invalidate() -> void:
	_generation+=1;_cache.clear()

func _add(id: String, node: Node2D, original: Vector2, managed: bool=false) -> void:
	if not FarmLayoutCatalog.valid_id("fixture",id): return
	if not groups.has(id): groups[id]=[]
	for item in groups[id]:
		if item.node==node: return
	node.set_meta("farm_fixture",id)
	groups[id].append({"node":node,"original":original,"managed":managed})
	for body in node.find_children("*","CollisionObject2D",true,false):
		if body is CharacterBody2D: continue
		_bodies[body.get_instance_id()]={"node":body,"layer":body.collision_layer if body.collision_layer!=0 else 1,"fixture":id}

func collect() -> void:
	var nodes: Array[Node]=[]
	nodes.append_array(game.world.actors.get_children());nodes.append_array(game.world.get_children())
	for node in nodes:
		if not node is Node2D or node is CharacterBody2D or node is TerritoryObject: continue
		var id: String=str(node.get_meta("farm_fixture",""))
		var original: Vector2=node.position
		var managed: bool=id!=""
		if id!="":
			original=node.position-FarmLayout.offset(id)
		elif "kind" in node and str(node.kind) in ["home","shop","workshop","board","recovery"]:
			id=str(node.kind)
		elif "actor_id" in node:
			id={"mail":"mail","village":"village_gate"}.get(str(node.actor_id),"")
		elif node is TerritoryGate:
			id="gate:"+str(node.destination)
		elif node.get_script() and node.get_script().resource_path=="res://scripts/world/greenhouse.gd":
			id="greenhouse";original=Vector2(1280,780)
		elif node is RiverScenery:
			for key in FarmLayoutCatalog.fixtures():
				if str(key).begins_with("decor:") and FarmLayoutCatalog.base_point(key)==node.position: id=key;break
		else:
			for sprite in node.get_children():
				if not sprite is Sprite2D or not sprite.texture: continue
				var path: String=sprite.texture.resource_path
				if path.contains("/exterior_") or path.ends_with("/buildings/house.png"): id="home";original=Vector2(656,402)
				elif path.ends_with("/derived/market.png"): id="shop";original=Vector2(356,392)
				elif path.ends_with("/sprites/wood_fence.png") and node.position.y==742: id="fence:"+str(int((node.position.x-16)/32))
		if id!="": _add(id,node,original,managed)

func refresh() -> void:
	if _refreshing or not is_instance_valid(game): return
	_refreshing=true
	var signature: int=FarmLayout.state.hash()
	var changed_geometry: bool=signature!=_layout_signature
	_layout_signature=signature
	if changed_geometry: FarmTerrain.apply(game)
	for id in groups:
		for item in groups[id]:
			var node: Node2D=item.node
			if not is_instance_valid(node): continue
			node.position=item.original+FarmLayout.offset(id)
			if not bool(item.managed) or not FarmLayout.active(id): node.visible=FarmLayout.active(id)
			if node is RiverScenery: node._refresh_cover()
	for item in _bodies.values():
		if is_instance_valid(item.node): item.node.collision_layer=int(item.layer) if FarmLayout.active(str(item.fixture)) else 0
	if is_instance_valid(game.resource_world): game.resource_world.fields.farm.refresh_layout()
	game.farm.queue_redraw()
	game.world.refresh_linya()
	# FarmVisual listens directly to layout/terrain revisions. Buying furniture or
	# feeding animals does not require rebuilding the entire 1536x1024 bitmap.
	if is_instance_valid(game.territory_world): game.territory_world.invalidate_geometry()
	if changed_geometry:
		invalidate();Events.navigation_changed.emit()
	_refreshing=false

func entry_name(kind: String, id: String) -> String:
	if kind=="plot":
		var plot: Dictionary=game.farm.plots.get(id,{})
		var at:=FarmLayout.cell(kind,id)
		return (Catalog.item_name(str(plot.crop))+"田" if str(plot.get("crop",""))!="" else "空农田")+"（%d,%d）" % [at.x,at.y]
	if kind=="resource":
		var at:=FarmLayout.cell(kind,id)
		return str(FarmLayoutCatalog.definition(kind,id).get("name","树石"))+"（%d,%d）" % [at.x,at.y]
	return str(FarmLayoutCatalog.definition(kind,id).get("name",id))

func entries(put_away_only: bool=false) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	for kind in ["fixture","resource","plot"]:
		var ids: Array=game.farm.plots.keys() if kind=="plot" else FarmLayoutCatalog.ids(kind)
		for id in ids:
			var stored: bool=FarmLayout.stored(kind,str(id))
			if put_away_only and not stored: continue
			out.append({"kind":kind,"id":str(id),"name":entry_name(kind,str(id)),"stored":stored,"cell":FarmLayout.cell(kind,str(id))})
	for kind in Housing.state.owned:
		if Housing.data.furniture[kind].area!="farm": continue
		out.append({"source":"owned","kind":"fixture","id":str(kind),"name":str(Housing.data.furniture[kind].name)+" ×"+str(Housing.state.owned[kind]),"stored":true,"cell":Vector2i(-1,-1)})
	return out

func pick(cell: Vector2i) -> Dictionary:
	var point:=Vector2(cell)*32+Vector2(16,16)
	var found: Dictionary={};var score: float=INF
	for entry in entries():
		if entry.get("source")=="owned": continue
		if entry.stored: continue
		var rect:=FarmLayoutCatalog.world_rect(entry.kind,entry.id,entry.cell)
		if entry.kind=="fixture":
			var info:=FarmLayoutCatalog.fixture(entry.id)
			rect=rect.merge(Rect2(FarmLayout.point(entry.id)+info.display_rect.position,info.display_rect.size))
		if not rect.grow(6).has_point(point): continue
		var distance: float=FarmLayout.position(entry.kind,entry.id).distance_squared_to(point)
		if entry.kind=="plot": distance-=1000
		if distance<score: found=entry;score=distance
	return found

func _excluded(kind: String, id: String) -> Array[RID]:
	var result: Array[RID]=[]
	if kind=="fixture":
		for item in groups.get(id,[]):
			if is_instance_valid(item.node): result.append_array(game.auto_move.navigation.collider_rids(item.node))
	elif kind=="resource" and game.resource_world.fields.farm.objects.has(id):
		result.append(game.resource_world.fields.farm.objects[id].get_rid())
	elif kind=="housing" and is_instance_valid(Housing.game):
		for node in game.get_tree().get_nodes_in_group("housing_furniture"):
			if node.housing_id==id: result.append_array(game.auto_move.navigation.collider_rids(node))
	elif kind=="territory" and game.territory_world.objects.has(id):
		result.append_array(game.auto_move.navigation.collider_rids(game.territory_world.objects[id]))
	return result

func _actual_rectangles(kind: String, id: String) -> Array[Rect2]:
	var out: Array[Rect2]=[]
	if kind=="fixture":
		for item in groups.get(id,[]):
			if not is_instance_valid(item.node): continue
			for shape in item.node.find_children("*","CollisionShape2D",true,false):
				if shape.disabled or not shape.shape or not shape.get_parent() is CollisionObject2D: continue
				out.append(shape.global_transform*shape.shape.get_rect())
		if out.is_empty() and bool(FarmLayoutCatalog.fixture(id).get("solid",false)):
			out.append(FarmLayoutCatalog.world_rect(kind,id,FarmLayout.cell(kind,id)))
	elif kind=="resource": out.append(FarmLayoutCatalog.world_rect(kind,id,FarmLayout.cell(kind,id)))
	return out

func _baseline(kind: String, id: String) -> Dictionary:
	var key: String=str(_generation)+":"+kind+":"+id
	if _cache.has(key): return _cache[key]
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(20,20)
	query.shape=shape;query.collision_mask=1;query.exclude=_excluded(kind,id)
	var solids: Dictionary={}
	var space=game.player.get_world_2d().direct_space_state
	for y in range(FarmLayoutCatalog.GRID.size.y):
		for x in range(FarmLayoutCatalog.GRID.size.x):
			var cell:=Vector2i(x,y);query.transform=Transform2D(0,Vector2(cell)*32+Vector2(16,16))
			for hit in space.intersect_shape(query,64):
				if hit.collider==game.world.ground: continue
				if game.world.is_ancestor_of(hit.collider): solids[cell]=true;break
	_cache[key]=solids;return solids

func _mark(rect: Rect2, solids: Dictionary) -> void:
	for y in range(maxi(0,floori((rect.position.y-10)/32)),mini(FarmLayoutCatalog.GRID.size.y,ceili((rect.end.y+10)/32))):
		for x in range(maxi(0,floori((rect.position.x-10)/32)),mini(FarmLayoutCatalog.GRID.size.x,ceili((rect.end.x+10)/32))):
			var at:=Vector2i(x,y)
			if rect.grow(10).has_point(Vector2(at)*32+Vector2(16,16)): solids[at]=true

func _flood(solids: Dictionary) -> Dictionary:
	var start:=Vector2i((game.player.position/32).floor());var open: Array[Vector2i]=[];var seen: Dictionary={}
	if FarmLayoutCatalog.GRID.has_point(start) and not solids.has(start): open.append(start);seen[start]=true
	var head: int=0
	while head<open.size():
		var at:=open[head];head+=1
		for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i=at+Vector2i(step)
			if FarmLayoutCatalog.GRID.has_point(next) and not solids.has(next) and not seen.has(next): seen[next]=true;open.append(next)
	return seen

func _segment_hits(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from) or rect.has_point(to): return true
	var a:=rect.position;var b:=Vector2(rect.end.x,rect.position.y);var c:=rect.end;var d:=Vector2(rect.position.x,rect.end.y)
	for pair in [[a,b],[b,c],[c,d],[d,a]]:
		if Geometry2D.segment_intersects_segment(from,to,pair[0],pair[1])!=null: return true
	return false

func _clear_ray(from: Vector2, to: Vector2, goal: String, proposed: Array[Rect2], excluded: Array[RID], water: Variant=null) -> bool:
	for rect in proposed:
		if _segment_hits(from,to,rect): return false
	var low:=Vector2i((from.min(to)/32).floor());var high:=Vector2i((from.max(to)/32).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var at:=Vector2i(x,y)
			var wet: bool=water.has(at) if water is Dictionary else FarmTerrain.effective_index(at) in [5,6]
			if wet and _segment_hits(from,to,Rect2(Vector2(at)*32,Vector2(32,32))): return false
	var skip: Array[RID]=excluded.duplicate()
	for member in groups.get(goal,[]):
		if is_instance_valid(member.node) and member.node.is_in_group("interactables"): skip.append_array(game.auto_move.navigation.collider_rids(member.node))
	var query:=PhysicsRayQueryParameters2D.create(from,to,1);query.exclude=skip
	for _i in range(64):
		var hit: Dictionary=game.player.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return true
		if hit.collider!=game.world.ground: return false
		# Old water bodies may disappear in the candidate. The candidate water
		# grid above is authoritative; skip individual old TileMap body RIDs.
		skip.append(hit.rid);query.exclude=skip
	return false

func _approachable(point: Vector2, seen: Dictionary, goal: String="", proposed: Array[Rect2]=[], excluded: Array[RID]=[], water: Variant=null) -> bool:
	var cell:=Vector2i((point/32).floor())
	if seen.has(cell) and point.distance_squared_to(Vector2(cell)*32+Vector2(16,16))<.01: return true
	for y in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var at:=Vector2i(x,y)
			var stand:=Vector2(at)*32+Vector2(16,16)
			if seen.has(at) and point.distance_to(stand)<=54 and _clear_ray(stand,point,goal,proposed,excluded,water): return true
	return false

func _water_solids(solids: Dictionary, terrain: Variant=null, offset: Vector2=Vector2.INF, active: bool=true) -> Dictionary:
	var result:=solids.duplicate()
	for y in range(FarmLayoutCatalog.GRID.size.y):
		for x in range(FarmLayoutCatalog.GRID.size.x):
			var at:=Vector2i(x,y)
			if FarmTerrain.effective_index(at,terrain,offset,active) in [5,6]: result[at]=true
	return result

func _failure(message: String) -> Dictionary: return {"valid":false,"reason":message}

func validate_plan(plan: Dictionary) -> Dictionary:
	if not is_instance_valid(game) or GameState.location!="farm": return _failure("请回到自己的农场改造。")
	var kind: String=str(plan.get("kind",""));var id: String=str(plan.get("id",""))
	var stored: bool=bool(plan.get("stored",false))
	var cell:=FarmLayoutCatalog.parse_cell(plan.get("cell"))
	var rect:=FarmLayoutCatalog.world_rect(kind,id,cell)
	if not stored and (not rect.has_area() or not FarmLayoutCatalog.WORLD.encloses(rect)): return _failure("实体占地需要完整放在农场范围内。")
	if kind=="fixture" and id=="lake": return _validate_geometry(kind,id,[],FarmTerrain.overrides(),Vector2(cell-FarmLayoutCatalog.default_cell(kind,id))*32,not stored,plan)
	var current:=FarmLayout.cell(kind,id)
	var delta:=Vector2(cell-current)*32
	var rectangles: Array[Rect2]=[]
	if not stored:
		if kind in ["fixture","resource","plot"]:
			var collision_error:=_passive_placement_error(kind,id,rect)
			if collision_error!="": return _failure(collision_error)
		if kind=="fixture" or kind=="resource":
			for old in _actual_rectangles(kind,id): rectangles.append(Rect2(old.position+delta,old.size))
		else: rectangles.append(rect)
		if kind=="plot" or kind=="resource":
			var target:=Rect2(Vector2(cell)*32,Vector2(32,32))
			for key in game.farm.plots:
				if kind=="plot" and key==id: continue
				if not FarmLayout.stored("plot",key) and target.has_point(Vector2(FarmLayout.cell("plot",key))*32+Vector2(16,16)): return _failure("这里已有生产田，请先移动或收纳。")
		for entry in Territory.state.objects:
			if entry.area!="farm": continue
			var occupied:=TerritoryCatalog.footprint(entry.kind,TerritoryCatalog.to_cell(entry.cell))
			if Rect2(Vector2(occupied.position)*32,Vector2(occupied.size)*32).intersects(rect): return _failure("这里已有摆件，请先移走。")
	return _validate_geometry(kind,id,rectangles,null,Vector2.INF,true,plan)

func _passive_placement_error(kind: String, id: String, rect: Rect2) -> String:
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size-Vector2(.1,.1)
	query.shape=shape;query.collision_mask=1;query.exclude=_excluded(kind,id);query.transform=Transform2D(0,rect.get_center())
	for hit in game.player.get_world_2d().direct_space_state.intersect_shape(query,64):
		if hit.collider==game.world.ground or game.world.is_ancestor_of(hit.collider): return "这里与现有实体或水面重叠，请先移动或收纳。"
	for key in game.farm.plots:
		if kind=="plot" and key==id: continue
		if FarmLayout.stored("plot",key): continue
		var field:=Rect2(Vector2(FarmLayout.cell("plot",key))*32,Vector2(32,32))
		if rect.intersects(field): return "先移动或收纳已有生产田，再摆放设施。"
	return ""

func _validate_geometry(kind: String, id: String, rectangles: Array[Rect2], terrain: Variant=null, lake_offset: Vector2=Vector2.INF, lake_active: bool=true, plan: Dictionary={}) -> Dictionary:
	if Engine.get_physics_frames()<game.auto_move.navigation.ready_frame: return _failure("通路正在更新，请稍候再确认。")
	var baseline:=_baseline(kind,id)
	var before:=_flood(_water_solids(_baseline("","")))
	var candidate:=_water_solids(baseline,terrain,lake_offset,lake_active)
	var candidate_water: Dictionary={}
	var water_query:=PhysicsShapeQueryParameters2D.new();var water_shape:=RectangleShape2D.new();water_shape.size=Vector2(31.9,31.9)
	water_query.shape=water_shape;water_query.collision_mask=1;water_query.exclude=_excluded(kind,id)
	# New water is real collision. It must not submerge the player, a crop, or
	# any existing physical entity; moving the lake uses the same rule as a brush.
	for y in range(FarmLayoutCatalog.GRID.size.y):
		for x in range(FarmLayoutCatalog.GRID.size.x):
			var at:=Vector2i(x,y)
			var next_index: int=FarmTerrain.effective_index(at,terrain,lake_offset,lake_active)
			if next_index in [5,6]: candidate_water[at]=true
			if next_index not in [5,6] or FarmTerrain.effective_index(at) in [5,6]: continue
			var tile:=Rect2(Vector2(at)*32,Vector2(32,32))
			if tile.intersects(Rect2(game.player.position-Vector2(10,10),Vector2(20,20))): return _failure("人物脚下不能改成水面，请先站到岸上。")
			if baseline.has(at) or not game.farm.plot_at(at).is_empty(): return _failure("新水面会覆盖建筑、树石或农田，请先移动或收纳。")
			water_query.transform=Transform2D(0,tile.get_center())
			for hit in game.player.get_world_2d().direct_space_state.intersect_shape(water_query,64):
				if hit.collider!=game.world.ground and game.world.is_ancestor_of(hit.collider): return _failure("水面边缘会碰到现有实体，请先移动或收纳。")
			for key in FarmLayoutCatalog.fixtures():
				if key=="lake" or str(key).begins_with("decor:") or str(key).begins_with("fence:") or not FarmLayout.active(key): continue
				var existing:=FarmLayoutCatalog.world_rect("fixture",key,FarmLayout.cell("fixture",key))
				if tile.intersects(existing): return _failure("先移动或收纳这里的入口、工作台或岸边设施，再挖水。")
	for rect in rectangles:
		var overlap:=_passive_placement_error(kind,id,rect)
		if overlap!="": return _failure(overlap)
		if kind!="plot" and rect.grow(10).has_point(game.player.position): return _failure("请先让人物离开这块占地，再确认。")
		for person in game.get_tree().get_nodes_in_group("interactables"):
			if kind!="plot" and person is CharacterBody2D and game.world.is_ancestor_of(person) and person.is_visible_in_tree() and rect.grow(10).has_point(person.global_position): return _failure("人物正在这里，请换个位置或稍后再摆放。")
		for y in range(maxi(0,floori(rect.position.y/32)),mini(FarmLayoutCatalog.GRID.size.y,ceili(rect.end.y/32))):
			for x in range(maxi(0,floori(rect.position.x/32)),mini(FarmLayoutCatalog.GRID.size.x,ceili(rect.end.x/32))):
				var at:=Vector2i(x,y)
				if FarmTerrain.effective_index(at,terrain,lake_offset,lake_active) in [5,6]: return _failure("这里与现有水面重叠。")
		if kind!="plot": _mark(rect,candidate)
	var after:=_flood(candidate)
	if after.is_empty(): return _failure("改造会困住人物，请留出通路。")
	for person in game.get_tree().get_nodes_in_group("interactables"):
		if person is CharacterBody2D and game.world.is_ancestor_of(person) and person.is_visible_in_tree():
			var occupied:=Vector2i((person.global_position/32).floor())
			if before.has(occupied) and not after.has(occupied): return _failure("改造会把人物围在里面，请留出出口。")
	var moving: bool=not bool(plan.get("stored",false))
	var ray_rects: Array[Rect2]=[]
	if kind!="plot": ray_rects.assign(rectangles)
	var excluded:=_excluded(kind,id)
	for key in FarmLayoutCatalog.fixtures():
		if not FarmLayout.active(key) and not (kind=="fixture" and key==id and moving): continue
		if key=="lake" or str(key).begins_with("decor:") or str(key).begins_with("fence:"): continue
		if kind=="fixture" and key==id and bool(plan.get("stored",false)): continue
		var point:=FarmLayout.point(key)
		if kind=="fixture" and key==id: point=FarmLayoutCatalog.world_point(kind,id,FarmLayoutCatalog.parse_cell(plan.cell))
		var rays: Array[Rect2]=[]
		if not (kind=="fixture" and key==id and id not in ["home","shop"]): rays.assign(ray_rects)
		if (key==id or _approachable(FarmLayout.point(key),before,key)) and not _approachable(point,after,key,rays,excluded,candidate_water): return _failure("需要给房门、设施或剧情交互留出可到达的站位。")
		if key in ["home","shop","greenhouse"]:
			var info:=FarmLayoutCatalog.fixture(key)
			for logical: Vector2 in info.associated_points:
				if (key=="home" and logical!=Vector2(656,440)) or (key=="shop" and logical==Vector2(356,392)) or (key=="greenhouse" and logical==Vector2(1280,780)): continue
				var old:=logical+FarmLayout.offset(key);var target:=old
				if kind=="fixture" and key==id: target=logical+Vector2(FarmLayoutCatalog.parse_cell(plan.cell)-info.cell)*32
				if before.has(Vector2i((old/32).floor())) and not after.has(Vector2i((target/32).floor())): return _failure("门前和人物站位需要保留，请留出通路。")
	if kind=="fixture" and moving:
		var info:=FarmLayoutCatalog.fixture(id)
		var offset:=Vector2(FarmLayoutCatalog.parse_cell(plan.cell)-info.cell)*32
		for logical: Vector2 in info.associated_points:
			if id not in ["home","shop","greenhouse"]: continue
			# The visual origin may be inside a building; only actual door/NPC
			# standing points are required to stay on usable land.
			if (id=="home" and logical!=Vector2(656,440)) or (id=="shop" and logical==Vector2(356,392)) or (id=="greenhouse" and logical==Vector2(1280,780)): continue
			var physical:=logical+offset;var at:=Vector2i((physical/32).floor())
			if not FarmLayoutCatalog.WORLD.grow(-10).has_point(physical) or candidate.has(at) or not _approachable(physical,after): return _failure("门前、人物或离场站位需要留出完整空地，请稍微挪开。")
	for object in game.territory_world.objects.values():
		if not object.is_visible_in_tree() or not (str(object.entry.kind).begins_with("station_") or str(object.entry.kind).begins_with("orchard_")): continue
		if kind=="territory" and object.entry_id==id: continue
		var access_skip: Array[RID]=excluded.duplicate();access_skip.append_array(game.auto_move.navigation.collider_rids(object))
		if _approachable(object.global_position,before,"",[],access_skip) and not _approachable(object.global_position,after,"",ray_rects,access_skip,candidate_water): return _failure("请给加工设备和果树留下可到达的操作位置。")
	if kind=="territory" and (str(plan.get("kind","")).begins_with("station_") or str(plan.get("kind","")).begins_with("orchard_")) and not rectangles.is_empty() and not _approachable(rectangles[0].get_center(),after,"",[],excluded,candidate_water): return _failure("新物件旁没有可到达的操作位置。")
	for key in game.farm.plots:
		if FarmLayout.stored("plot",key) or (kind=="plot" and key==id): continue
		var point:=Vector2(FarmLayout.cell("plot",key))*32+Vector2(16,16)
		if _approachable(point,before) and not _approachable(point,after,"",ray_rects,excluded,candidate_water): return _failure("改造会隔断现有农田。请先移动或收纳农田。")
	return {"valid":true,"reason":""}

func validate_terrain(plan: Dictionary) -> Dictionary:
	var terrain:=FarmTerrain.overrides().duplicate()
	for raw in plan.get("cells",[]):
		var cell:=TerritoryCatalog.to_cell(raw);var key:=TerritoryCatalog.key(cell)
		if str(plan.kind)=="natural": terrain.erase(key)
		else: terrain[key]=str(plan.kind)
		if FarmTerrain.effective_index(cell,terrain) in [5,6]:
			if not game.farm.plot_at(cell).is_empty(): return _failure("先移动或收纳这块农田，再改成水面。")
			if _baseline("","").has(cell): return _failure("先移动或收纳这里的建筑、树石或设施，再挖水。")
	return _validate_geometry("","",[],terrain)

func check_housing(kind: String, cell: Vector2i, ignore_id: String="") -> Dictionary:
	var footprint:=Housing.footprint(kind,cell)
	var rect:=Rect2(Vector2(footprint.position)*32+Vector2(2,2),Vector2(footprint.size)*32-Vector2(4,4))
	if not FarmLayoutCatalog.WORLD.encloses(rect): return _failure("家具须放在自己的农场内。")
	for id in game.farm.plots:
		if not FarmLayout.stored("plot",id) and rect.intersects(Rect2(Vector2(FarmLayout.cell("plot",id))*32,Vector2(32,32))): return _failure("这里已有作物，请先移动或收纳田地。")
	return _validate_geometry("housing",ignore_id,[rect])

func check_object(plan: Dictionary) -> Dictionary:
	var cell:=TerritoryCatalog.to_cell(plan.cells[0])
	var footprint:=TerritoryCatalog.footprint(str(plan.kind),cell)
	var rect:=Rect2(Vector2(footprint.position)*32+Vector2(2,2),Vector2(footprint.size)*32-Vector2(4,4))
	var rectangles: Array[Rect2]=[]
	if TerritoryCatalog.is_solid(str(plan.kind)): rectangles.append(rect)
	return _validate_geometry("territory",str(plan.get("id","")),rectangles,null,Vector2.INF,true,plan)

func preview_rect(plan: Dictionary) -> Rect2:
	return FarmLayoutCatalog.world_rect(str(plan.kind),str(plan.id),FarmLayoutCatalog.parse_cell(plan.cell))

func preview_art(plan: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	var kind: String=str(plan.get("kind",""));var id: String=str(plan.get("id",""))
	var at:=FarmLayoutCatalog.parse_cell(plan.get("cell"))
	var delta:=Vector2(at-FarmLayout.cell(kind,id))*32
	if kind=="resource" and game.resource_world.fields.farm.objects.has(id):
		var sprite: Sprite2D=game.resource_world.fields.farm.objects[id].sprite
		out.append({"texture":sprite.texture,"rect":Rect2(sprite.global_position+sprite.get_rect().position+delta,sprite.get_rect().size)})
	elif kind=="plot":
		var plot: Dictionary=game.farm.plots.get(id,{})
		var texture: Texture2D=game.farm.SOIL_WET if plot.get("watered",false) else game.farm.SOIL_DRY
		out.append({"texture":texture,"rect":Rect2(Vector2(at)*32,Vector2(32,32))})
		var crop_id: String=str(plot.get("crop",""))
		if Catalog.crops.has(crop_id):
			var crop: CropDefinition=Catalog.crops[crop_id]
			var stage: int=mini(int(float(plot.days)/crop.growth_days*(crop.stages-1)),crop.stages-1)
			var atlas:=AtlasTexture.new();atlas.atlas=game.farm.CROP_TEXTURE;atlas.region=Rect2(stage*32,crop.atlas_row*40,32,40)
			out.append({"texture":atlas,"rect":Rect2(Vector2(at)*32+Vector2(0,-9),Vector2(32,40))})
	else:
		for item in groups.get(id,[]):
			for node in item.node.get_children():
				if node is Sprite2D and node.texture:
					out.append({"texture":node.texture,"rect":Rect2(node.global_position+node.get_rect().position+delta,node.get_rect().size)})
		if out.is_empty():
			var art: String={"recovery":"wood_bench","workshop":"picnic_table","board":"notice_board","mail":"mailbox","greenhouse":"greenhouse","coop":"chicken_coop","barn":"barn","fold":"barn","berry":"bush","yard":"tool_rack","village_gate":"road_sign"}.get(id,"")
			if id.begins_with("decor:bush:"): art="bush"
			var texture:=SchemeCAssets.texture(art)
			if texture: out.append({"texture":texture,"rect":Rect2(FarmLayoutCatalog.world_point(kind,id,at)+SchemeCAssets.offset(art)-texture.get_size()*.5,texture.get_size())})
	return out

func safe_spawn(preferred: Vector2) -> Vector2:
	var solids:=_water_solids(_baseline("",""))
	var best:=Vector2.INF;var distance: float=INF
	for y in range(FarmLayoutCatalog.GRID.size.y):
		for x in range(FarmLayoutCatalog.GRID.size.x):
			var cell:=Vector2i(x,y)
			if solids.has(cell): continue
			var point:=Vector2(cell)*32+Vector2(16,16);var d:=point.distance_squared_to(preferred)
			if d<distance: best=point;distance=d
	return best if best!=Vector2.INF else Vector2(16,16)
