class_name FarmUIStyle
extends RefCounted
const INK := Color("263e38")
const CREAM := Color("f4e8c9")
const GREEN := Color("466b52")
const GOLD := Color("e7b96b")
const PAPER := Color("f2e4c5")
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
	# 按素材原尺寸复用像素边框，避免运行时缩小整套界面视觉。
	if not surface_textures.has(role):
		var texture: Texture2D=load("res://assets/ui/river/"+role+".png")
		texture.set_meta("ui_role",role)
		surface_textures[role]=texture
	style.texture=surface_textures[role]
	if role=="paper":
		style.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,8)
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
	grid.columns=1
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	return grid

static func section(parent: Node) -> VBoxContainer:
	return card(parent)

static func card(parent: Node, role: String = "secondary") -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.set_meta("ui07_card",true)
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=surface(role)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,12)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var column:=VBoxContainer.new()
	column.set_meta("ui07_card",true)
	column.add_theme_constant_override("separation",8)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	return column

static func heading(parent: Node, text: String, icon: String = "") -> Label:
	var host: Node=parent
	if icon!="":
		var row:=HBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",8);parent.add_child(row);host=row
		var path: String="res://assets/maps/icon_"+icon+".png"
		if ResourceLoader.exists(path):
			var image:=TextureRect.new();image.texture=load(path);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.custom_minimum_size=Vector2(28,28);image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(image)
	var title:=label(text,20,TITLE)
	title.set_meta("ui07_heading",true);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host.add_child(title)
	return title
