class_name UILayout
extends RefCounted
## 经典完整布局与安全区适配。只控制显示，不进入玩法和存档。
const SAFE_EDGE: float = 12.0
const GAP: float = 8.0
const PANEL_PADDING: float = 16.0
const HEADER_HEIGHT: float = 48.0
const TOOL_SIZE: float = 74.0
const TOOL_ICON: int = 26
const BODY_FONT: int = 18
const TITLE_FONT: int = 24
const CAPTION_FONT: int = 16
const POPUP_MAX_WIDTH: float = 960.0
const CAMERA_RETURN_SPEED: float = 12.0
const DRAG_THRESHOLD_DP: float = 12.0
const DRAG_SENSITIVITY: float = 1.0

static func slot_size() -> float:
	return maxf(TOOL_SIZE,UIMetrics.minimum_target())

static func panel_size(canvas: Vector2, kind: String = "default") -> Vector2:
	var extent:=Vector2(920,560)
	match kind:
		"inventory": extent=Vector2(860,530)
		"journal": extent=Vector2(900,540)
		"story": extent=Vector2(960,560)
		"reading": extent=Vector2(860,500)
		"dialogue": extent=Vector2(960,340)
		"system": extent=Vector2(620,540)
		"housing": extent=Vector2(940,580)
	return extent.min(canvas-Vector2.ONE*4*SAFE_EDGE)
