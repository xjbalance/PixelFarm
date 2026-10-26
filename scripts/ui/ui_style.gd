class_name FarmUIStyle
extends RefCounted
const INK := Color("263e38")
const CREAM := Color("f4e8c9")
const GREEN := Color("466b52")
const GOLD := Color("e7b96b")
const PAPER := Color("f4e7cd")
const WOOD := Color("d7b98a")
const BROWN := Color("754b36")
const TEXT := Color("35291f")
const TITLE := Color("66442f")
const MUTED := Color("705e4c")
const SUCCESS := Color("496a43")
const DANGER := Color("984b3e")
const STAR := Color("66639b")
const STAR_FILL := Color("7775b4")
static var surface_textures: Dictionary={}

static func box(color: Color, border: Color = Color("ae9469"), radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func surface(role: String = "paper") -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	# 原创UI04素材仅在首次使用时最近邻缩半，细化边框；不处理字体/世界纹理。
	if not surface_textures.has(role):
		var source: Texture2D=load("res://assets/ui/river/"+role+".png")
		var pixels: Image=source.get_image()
		pixels.resize(pixels.get_width()/2,pixels.get_height()/2,Image.INTERPOLATE_NEAREST)
		var texture:=ImageTexture.create_from_image(pixels)
		texture.set_meta("ui_role",role)
		surface_textures[role]=texture
	style.texture=surface_textures[role]
	if role=="paper":
		style.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,4)
		style.set_content_margin(side,UILayout.PANEL_PADDING if side in [SIDE_LEFT,SIDE_RIGHT] else 8)
	return style

static func make_theme() -> Theme:
	var theme: Theme=load("res://resources/ui/river_theme.tres").duplicate() as Theme
	for entry in [["PanelContainer","panel","paper"],["PopupPanel","panel","paper"],["Window","embedded_border","paper"],["Button","normal","button"],["Button","hover","hover"],["Button","pressed","pressed"],["Button","disabled","disabled"],["Button","focus","focus"],["ProgressBar","background","track"],["ProgressBar","fill","fill"]]:
		theme.set_stylebox(entry[1],entry[0],surface(entry[2]))
	for type in ["VScrollBar","HScrollBar"]:
		for entry in [["scroll","track"],["grabber","button"],["grabber_highlight","selected"],["grabber_pressed","nature"]]:
			theme.set_stylebox(entry[0],type,surface(entry[1]))
	theme.set_constant("separation","HBoxContainer",int(UILayout.GAP))
	theme.set_constant("separation","VBoxContainer",int(UILayout.GAP))
	return theme

static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable, width: float = 80) -> Button:
	var node := Button.new()
	node.set_script(preload("res://scripts/ui/touch_button.gd"))
	node.text = text
	var target: float=UIMetrics.minimum_target()
	node.custom_minimum_size = Vector2(maxf(target, width), target)
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	if "×" in text or text.begins_with("取消") or text.begins_with("返回"):
		node.add_theme_stylebox_override("normal",surface("secondary"))
	elif text.begins_with("确认"):
		node.add_theme_stylebox_override("normal",surface("selected"))
	return node

static func section_grid(parent: Node) -> GridContainer:
	var grid:=GridContainer.new()
	grid.set_script(preload("res://scripts/ui/section_grid.gd"))
	parent.add_child(grid)
	return grid

static func section(parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("efe0c1")
	style.border_color=Color("d7b98a")
	style.border_width_bottom=1
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,12)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	return column
