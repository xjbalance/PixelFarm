class_name FarmUIStyle
extends RefCounted
const INK := Color("263e38")
const CREAM := Color("f4e8c9")
const GREEN := Color("466b52")
const GOLD := Color("edcc81")

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

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc")
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("a3ad9a"))
	theme.set_stylebox("normal", "Button", box(INK, Color("6c8265")))
	theme.set_stylebox("hover", "Button", box(GREEN, GOLD))
	theme.set_stylebox("pressed", "Button", box(GOLD, CREAM))
	theme.set_stylebox("disabled", "Button", box(Color("394a40"),Color("526353")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", box(Color("253e38f5")))
	return theme

static func label(text: String, size: int = 18, color: Color = CREAM) -> Label:
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
	return node
