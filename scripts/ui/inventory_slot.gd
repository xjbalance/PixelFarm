class_name InventorySlotView
extends Control
var entry: Dictionary={}
var slot_index: int=-1
var selected: bool=false
var drop_state: int=0
var dragging_source: bool=false
var normal: StyleBox
var active: StyleBox
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	normal=FarmUIStyle.surface("secondary");active=FarmUIStyle.surface("selected")
func display(index: int, value: Dictionary, is_selected: bool) -> void:
	slot_index=index;entry=value.duplicate();selected=is_selected
	tooltip_text=ItemTaxonomy.title(str(entry.item)) if not entry.is_empty() else "空格"
	queue_redraw()
func _draw() -> void:
	if normal==null: return
	draw_style_box(active if selected else normal,Rect2(Vector2.ZERO,size))
	if entry.is_empty():
		draw_rect(Rect2(Vector2(6,6),size-Vector2(12,12)),Color(.5,.39,.25,.12),false,1)
	else:
		var icon:=ItemTaxonomy.texture(str(entry.item))
		if icon:
			var original:=icon.get_size();var factor: float=clampf(floorf((minf(size.x,size.y)-14)/maxf(original.x,original.y)),1,2)
			var extent:=original*factor
			draw_texture_rect(icon,Rect2((size-extent)*.5-Vector2(0,4),extent),false,Color(1,1,1,.45 if dragging_source else 1))
		var font:=get_theme_default_font()
		if not ItemTaxonomy.is_permanent_tool(str(entry.item)):
			var caption:=str(entry.amount);var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			draw_rect(Rect2(size.x-width-12,size.y-25,width+8,20),Color("f4e8c9ee"))
			draw_string(font,Vector2(size.x-width-8,size.y-9),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,FarmUIStyle.TEXT)
		if int(entry.uid) in Inventory.layout.locked:
			draw_rect(Rect2(5,5,22,20),FarmUIStyle.GOLD);draw_string(font,Vector2(8,21),"锁",HORIZONTAL_ALIGNMENT_LEFT,-1,14,FarmUIStyle.TEXT)
		var binding: int=GameState.preferences.get("hotbar",[]).find(str(entry.item))
		if binding>=0:
			draw_rect(Rect2(size.x-23,5,18,18),FarmUIStyle.WOOD);draw_string(font,Vector2(size.x-19,19),str(binding+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,FarmUIStyle.TEXT)
	if drop_state>0: draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),FarmUIStyle.SUCCESS if drop_state==1 else FarmUIStyle.DANGER,false,3)
	elif selected: draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),FarmUIStyle.GOLD,false,2)
