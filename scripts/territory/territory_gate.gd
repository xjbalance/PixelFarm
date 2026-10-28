class_name TerritoryGate
extends Node2D
## 入口路牌只通过原WorldTravel步行换区，不承担图纸传送。
var game: Node
var destination: String=""
var area_id: String="farm"
var returning: bool=false

func _ready() -> void:
	add_to_group("interactables");add_to_group("territory_gates");texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	Territory.changed.connect(queue_redraw)

func prompt() -> String:
	if returning: return "返回主农场 · 原领地路口"
	var definition: Dictionary=TerritoryCatalog.region(destination)
	return str(definition.get("name",destination))+(" · 步行前往" if Territory.unlocked(destination) else " · 尚未开放")

func hit_rect() -> Rect2: return Rect2(-22,-32,44,50)

func interact() -> void:
	if not is_instance_valid(game) or game.backgrounded or game.closing or GameState.modal or game.player.action_time>0: return
	if game.player.global_position.distance_to(global_position)>54: return
	if returning:
		var entry: Dictionary=TerritoryCatalog.region(area_id)
		var at: Array=entry.return_position
		WorldTravel.change(game,"farm",Vector2(at[0],at[1]));return
	if not Territory.unlocked(destination):
		Events.notice.emit(str(TerritoryCatalog.region(destination).get("hint","这片领地尚未开放。")));return
	WorldTravel.change(game,destination)

func _draw() -> void:
	var opened: bool=returning or Territory.unlocked(destination)
	draw_rect(Rect2(-3,-10,6,22),Color("76563d"))
	draw_rect(Rect2(-20,-30,40,22),Color("7d6040"))
	draw_rect(Rect2(-18,-28,36,18),Color("d5bc8d") if opened else Color("a49d82"))
	var tone:=Color("557650") if opened else Color("785b47")
	if opened:
		draw_line(Vector2(-8,-20),Vector2(7,-20),tone,2)
		draw_line(Vector2(7,-20),Vector2(2,-24),tone,2);draw_line(Vector2(7,-20),Vector2(2,-16),tone,2)
	else:
		draw_rect(Rect2(-5,-23,10,8),tone)
		draw_arc(Vector2(0,-23),4,PI,TAU,8,tone,2)
	# 脚前的短界桩不产生额外地图障碍；真正的未开放区域由Travel和编辑权限双重阻止。
	draw_line(Vector2(-18,15),Vector2(18,15),Color("789c79") if opened else Color("a78460"),2)
