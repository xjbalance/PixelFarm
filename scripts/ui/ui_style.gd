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
	style.texture=load("res://assets/ui/river/"+role+".png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,8)
		style.set_content_margin(side,16 if side in [SIDE_LEFT,SIDE_RIGHT] else 8)
	return style

static func make_theme() -> Theme:
	return load("res://resources/ui/river_theme.tres").duplicate() as Theme

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
	node.custom_minimum_size = Vector2(maxf(48, width), 48)
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	if "×" in text or text.begins_with("取消") or text.begins_with("返回"):
		node.add_theme_stylebox_override("normal",surface("secondary"))
	elif text.begins_with("确认"):
		node.add_theme_stylebox_override("normal",surface("selected"))
	return node
