class_name RanchLayout
extends RefCounted
## Immutable geometry shared by rendering, collisions, AI, save validation and area audit.
const ENABLED: Array[String]=["coop","barn","fold"]
const AREAS: Array[String]=["pasture_coop","pasture_barn","pasture_fold"]
static var _catalog: Dictionary={}
static func catalog() -> Dictionary:
	if _catalog.is_empty(): _catalog=AbyssSaveSchema.canonical(JSON.parse_string(FileAccess.get_file_as_string("res://resources/livestock/pastures.json")))
	return _catalog
static func area(site: String) -> String: return "pasture_"+site
static func site(area_id: String) -> String: return area_id.trim_prefix("pasture_") if area_id in AREAS else ""
static func definition(site_id: String) -> Dictionary: return catalog().maps.get(site_id,{})
static func region(site_id: String) -> Rect2i:
	var size: Array=definition(site_id).get("size",[32,24]);return Rect2i(0,0,int(size[0]),int(size[1]))
static func world_rect(site_id: String) -> Rect2: return Rect2(Vector2.ZERO,Vector2(region(site_id).size)*32)
static func shelter(site_id: String) -> Rect2:
	var center: float=world_rect(site_id).size.x*.5
	return Rect2(center-128,64,256,160)
static func indoor(site_id: String) -> Rect2: return shelter(site_id).grow(-20)
static func home(site_id: String,index: int) -> Vector2:
	var room:=shelter(site_id);return Vector2(room.get_center().x-64+(index%3)*64,112+(index/3)*48)
static func entry(site_id: String) -> Vector2: return Vector2(world_rect(site_id).size.x*.5,world_rect(site_id).size.y-96)
static func service(site_id: String) -> Vector2: return Vector2(world_rect(site_id).size.x*.5,240)
static func nest(site_id: String) -> Vector2: return service(site_id)+Vector2(-96,-32)
static func furniture(site_id: String) -> Dictionary:
	var room:=shelter(site_id)
	return {"trough":Vector2(room.position.x-64,176),"water_basin":Vector2(room.end.x+64,176)}
static func obstacles(site_id: String) -> Array[Rect2]:
	var size:=world_rect(site_id).size;var room:=shelter(site_id)
	var result: Array[Rect2]=[Rect2(0,0,size.x,32),Rect2(0,size.y-32,size.x,32),Rect2(0,32,32,size.y-64),Rect2(size.x-32,32,32,size.y-64)]
	result.append(Rect2(room.position,Vector2(room.size.x,10)))
	result.append(Rect2(room.position,Vector2(10,room.size.y)))
	result.append(Rect2(Vector2(room.end.x-10,room.position.y),Vector2(10,room.size.y)))
	for at in furniture(site_id).values(): result.append(Rect2(at+Vector2(-22,-12),Vector2(44,16)))
	# A single clear trunk provides shade. Canopies have no navigation footprint.
	result.append(Rect2(Vector2(size.x-176,160)-Vector2(12,10),Vector2(24,20)))
	return result
static func point_legal(site_id: String, point: Vector2) -> bool:
	if not point.is_finite() or not world_rect(site_id).grow(-38).has_point(point): return false
	var foot:=Rect2(point+Vector2(-12,-10),Vector2(24,18))
	for rect in obstacles(site_id):
		if rect.intersects(foot): return false
	return true
