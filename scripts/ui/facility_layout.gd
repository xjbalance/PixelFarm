class_name FacilityLayout
extends RefCounted
## 经营页面的只读排版组件；不读取或提交玩法事务。
static func decorate(panel: PanelContainer, identity: String, hint: String="") -> void:
	panel.set_meta("facility_ui07",identity)
	if panel.get_child_count()==0: return
	var column: Node=panel.get_child(0)
	if not column is VBoxContainer or column.get_child_count()==0: return
	column.add_theme_constant_override("separation",10)
	var header: Node=column.get_child(0)
	if header is HBoxContainer:
		header.add_theme_constant_override("separation",12)
		var title:=_first_label(header)
		if title:
			title.add_theme_font_size_override("font_size",24)
			title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			title.set_meta("facility_title",true)
	if hint!="" and not panel.has_meta("facility_caption"):
		var caption:=FarmUIStyle.label(hint,15,FarmUIStyle.MUTED)
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(caption);column.move_child(caption,1);panel.set_meta("facility_caption",caption)

static func _first_label(node: Node) -> Label:
	if node is Label: return node
	for child in node.get_children():
		var found:=_first_label(child)
		if found: return found
	return null

static func set_title(panel: PanelContainer, text: String) -> void:
	if panel.get_child_count()==0: return
	var column: Node=panel.get_child(0)
	if column.get_child_count()==0: return
	var title:=_first_label(column.get_child(0))
	if title: title.text=text

static func text(parent: Node, value: String, size: int=18) -> Label:
	var label: Label
	if size>=21:
		label=FarmUIStyle.heading(parent,value)
	else:
		label=FarmUIStyle.label(value,size,FarmUIStyle.MUTED if size<=16 else FarmUIStyle.TEXT)
		parent.add_child(label)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return label

static func card(parent: Node, identity: String="") -> VBoxContainer:
	var content:=FarmUIStyle.card(parent,"secondary")
	content.set_meta("facility_card",identity)
	return content

static func metrics(parent: Node, values: Array) -> HFlowContainer:
	var flow:=HFlowContainer.new();flow.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation",8);flow.add_theme_constant_override("v_separation",8)
	flow.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(flow)
	for entry in values:
		var frame:=PanelContainer.new();frame.custom_minimum_size.x=128
		frame.add_theme_stylebox_override("panel",FarmUIStyle.surface("secondary"))
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;flow.add_child(frame)
		var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",3);frame.add_child(stack)
		stack.add_child(FarmUIStyle.label(str(entry[0]),15,FarmUIStyle.MUTED))
		var value:=FarmUIStyle.label(str(entry[1]),22,entry[2] if entry.size()>2 else FarmUIStyle.TEXT)
		value.set_meta("facility_metric",str(entry[0]));stack.add_child(value)
	return flow

static func actions(parent: Node) -> HFlowContainer:
	var flow:=HFlowContainer.new();flow.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation",8);flow.add_theme_constant_override("v_separation",8)
	parent.add_child(flow);return flow

static func item_preview(parent: Node, item: String, extent: int=48) -> TextureRect:
	var image:=TextureRect.new();image.texture=ItemPresentation.texture(item)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(extent,extent);image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image

static func tabs(container: HBoxContainer, selected: String) -> void:
	for child in container.get_children():
		if child is Button and child.has_meta("facility_tab"):
			child.toggle_mode=true;child.set_pressed_no_signal(child.get_meta("facility_tab")==selected)
			child.add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if child.button_pressed else "secondary"))
