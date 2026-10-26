class_name UILayout
extends RefCounted
## UI05共享设计变量。只控制画布布局/镜头，不进入玩法和存档。
const SAFE_EDGE: float = 12.0
const GAP: float = 8.0
const PANEL_PADDING: float = 12.0
const HEADER_HEIGHT: float = 48.0
const TOOL_SIZE: float = 48.0
const TOOL_ICON: int = 24
const BODY_FONT: int = 18
const TITLE_FONT: int = 24
const CAPTION_FONT: int = 16
const POPUP_MAX_WIDTH: float = 1040.0
const CAMERA_RETURN_SPEED: float = 12.0
const DRAG_THRESHOLD_DP: float = 12.0
const DRAG_SENSITIVITY: float = 1.0

static func slot_size() -> float:
	return maxf(TOOL_SIZE,UIMetrics.minimum_target())

static func panel_size(canvas: Vector2, kind: String = "default") -> Vector2:
	var width: float=minf(POPUP_MAX_WIDTH,canvas.x-4*SAFE_EDGE)
	var height: float=minf(600,canvas.y-4*SAFE_EDGE)
	if kind=="inventory": width=minf(1100,canvas.x-4*SAFE_EDGE)
	elif kind=="dialogue":
		width=minf(1020,canvas.x-4*SAFE_EDGE)
		height=minf(canvas.y-4*SAFE_EDGE,240+maxf(0,UIMetrics.minimum_target()-48)*2)
	elif kind=="system": width=minf(680,canvas.x-4*SAFE_EDGE)
	return Vector2(width,height)
