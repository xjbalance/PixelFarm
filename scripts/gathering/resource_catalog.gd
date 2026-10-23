class_name FarmResourceCatalog
extends RefCounted
## 稳定 ID 来自地块坐标，调整显示节点名称不会让旧存档失效。
const TREES := [Vector2i(5,8),Vector2i(7,20),Vector2i(9,24),Vector2i(12,6),Vector2i(27,8),Vector2i(29,11),Vector2i(41,13),Vector2i(40,23),Vector2i(30,26),Vector2i(19,26),Vector2i(4,15),Vector2i(37,6),Vector2i(42,27),Vector2i(25,5)]
const ROCKS := [Vector2i(11,19),Vector2i(28,24),Vector2i(30,9),Vector2i(39,24),Vector2i(8,13)]
const TYPES := {
	"tree": {"name":"河谷树", "tool":"axe", "item":"wood", "amount":4, "hits":3, "energy":3, "regrow":3, "texture":"res://assets/tilesets/tree.png"},
	"rock": {"name":"矿石堆", "tool":"pickaxe", "item":"stone", "amount":3, "hits":2, "energy":3, "regrow":2, "texture":"res://assets/tilesets/rock.png"}
}

static func placements() -> Dictionary:
	var result := {}
	for kind in ["tree","rock"]:
		for cell in TREES if kind == "tree" else ROCKS:
			result["%s_%d_%d" % [kind,cell.x,cell.y]] = {"kind":kind,"cell":cell}
	return result
