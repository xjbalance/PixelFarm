class_name FarmResourceCatalog
extends RefCounted
## 稳定 ID 来自地块坐标，调整显示节点名称不会让旧存档失效。
const TREES := [Vector2i(5,8),Vector2i(7,20),Vector2i(9,24),Vector2i(12,6),Vector2i(27,8),Vector2i(29,11),Vector2i(41,13),Vector2i(40,23),Vector2i(30,26),Vector2i(19,26),Vector2i(4,15),Vector2i(37,6),Vector2i(42,27),Vector2i(25,5),Vector2i(3,4),Vector2i(7,4),Vector2i(10,3),Vector2i(18,3),Vector2i(31,3),Vector2i(35,4),Vector2i(41,5),Vector2i(45,8),Vector2i(45,12),Vector2i(44,21),Vector2i(45,29),Vector2i(3,12),Vector2i(10,8),Vector2i(3,18),Vector2i(16,3),Vector2i(43,3)]
const ROCKS := [Vector2i(11,19),Vector2i(28,24),Vector2i(30,9),Vector2i(39,24),Vector2i(8,13),Vector2i(4,22),Vector2i(10,10),Vector2i(23,3),Vector2i(32,6),Vector2i(45,25),Vector2i(4,6),Vector2i(42,9)]
const VILLAGE_TREES := [Vector2i(3,6),Vector2i(7,6),Vector2i(12,5),Vector2i(18,5),Vector2i(23,6),Vector2i(31,5),Vector2i(3,19),Vector2i(34,24),Vector2i(3,22),Vector2i(12,24)]
const VILLAGE_ROCKS := [Vector2i(4,11),Vector2i(21,5),Vector2i(36,26),Vector2i(34,22),Vector2i(8,21),Vector2i(37,10)]
const FOREST_TREES := [Vector2i(5,2),Vector2i(7,2),Vector2i(11,2),Vector2i(15,2),Vector2i(3,4),Vector2i(11,4),Vector2i(17,4),Vector2i(19,4),Vector2i(31,4),Vector2i(33,4),Vector2i(3,6),Vector2i(6,6),Vector2i(29,6),Vector2i(33,7),Vector2i(7,8),Vector2i(11,8),Vector2i(3,9),Vector2i(8,10),Vector2i(36,10),Vector2i(3,11),Vector2i(20,11),Vector2i(22,11),Vector2i(7,12),Vector2i(9,12),Vector2i(11,13),Vector2i(13,13),Vector2i(19,13),Vector2i(23,13),Vector2i(3,15),Vector2i(19,15),Vector2i(7,16),Vector2i(9,16),Vector2i(13,17),Vector2i(15,17),Vector2i(2,19),Vector2i(25,20),Vector2i(2,21),Vector2i(12,21),Vector2i(2,23),Vector2i(13,2),Vector2i(34,24),Vector2i(36,24),Vector2i(16,25),Vector2i(18,25),Vector2i(22,25)]
const FOREST_ROCKS := [Vector2i(3,2),Vector2i(9,2),Vector2i(19,2),Vector2i(15,4),Vector2i(29,4),Vector2i(36,4),Vector2i(10,6),Vector2i(36,7),Vector2i(29,8),Vector2i(33,10),Vector2i(14,11),Vector2i(27,11),Vector2i(3,13),Vector2i(15,13),Vector2i(7,14),Vector2i(21,15),Vector2i(2,17),Vector2i(17,17),Vector2i(27,20),Vector2i(25,22),Vector2i(32,24),Vector2i(14,25),Vector2i(20,25),Vector2i(24,25),Vector2i(26,25)]
const TYPES := {
	"tree": {"name":"河谷树", "tool":"axe", "item":"wood", "amount":4, "hits":3, "energy":3, "regrow":3, "texture":"res://assets/tilesets/tree.png"},
	"rock": {"name":"矿石堆", "tool":"pickaxe", "item":"stone", "amount":3, "hits":2, "energy":3, "regrow":2, "texture":"res://assets/tilesets/rock.png"}
}

static func placements(area: String = "farm") -> Dictionary:
	var result := {}
	if area not in ["farm","village","mist_forest"]: return result
	var trees: Array=TREES if area=="farm" else VILLAGE_TREES if area=="village" else FOREST_TREES
	var rocks: Array=ROCKS if area=="farm" else VILLAGE_ROCKS if area=="village" else FOREST_ROCKS
	for kind in ["tree","rock"]:
		for cell in trees if kind=="tree" else rocks:
			# 农场保留所有旧ID；其他地图显式命名空间避免同坐标互相覆盖。
			var id: String=("" if area=="farm" else area+"_")+"%s_%d_%d" % [kind,cell.x,cell.y]
			result[id]={"kind":kind,"cell":cell,"area":area}
	return result

static func all_placements() -> Dictionary:
	var result := {}
	for area in ["farm","village","mist_forest"]: result.merge(placements(area))
	return result

static func current_placements(area: String="farm") -> Dictionary:
	# Stable IDs and defaults above remain the legacy save catalog. Physical positions
	# are a separate layout mapping; moving a tree never creates another resource ID.
	var result:=placements(area)
	if area=="farm":
		for id in result:
			result[id].cell=FarmLayout.cell("resource",str(id))
			result[id].stored=FarmLayout.stored("resource",str(id))
	return result

static func current_footprint(id: String, at: Variant=null) -> Rect2i:
	var entry: Dictionary=placements("farm").get(id,{})
	if entry.is_empty() or (at==null and FarmLayout.stored("resource",id)): return Rect2i()
	var cell: Vector2i=FarmLayout.cell("resource",id) if at==null else TerritoryCatalog.to_cell(at)
	if cell==TerritoryCatalog.INVALID_CELL: return Rect2i()
	var extent:=Vector2(22,19) if entry.kind=="tree" else Vector2(30,16)
	var rect:=Rect2(Vector2(cell)*32+Vector2(0,-5)-extent*.5,extent)
	var start:=Vector2i((rect.position/32).floor());var end:=Vector2i((rect.end/32).ceil())
	return Rect2i(start,end-start)
