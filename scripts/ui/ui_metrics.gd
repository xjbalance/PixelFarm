class_name UIMetrics
extends RefCounted
## dp是物理密度单位，必须先按设备DPI和Viewport缩放换成Control逻辑尺寸。
static var screen_provider: Callable
static func logical_touch_size(dpi: float, physical: Vector2, canvas: Vector2, dp: float = 48) -> float:
	if dpi<=0 or physical.x<=0 or physical.y<=0 or canvas.x<=0 or canvas.y<=0: return dp
	var pixels_per_unit: float=minf(physical.x/canvas.x,physical.y/canvas.y)
	return ceilf(dp*(dpi/160.0)/pixels_per_unit)

static func minimum_target() -> float:
	# 同一换算可注入校准样本做桌面布局验证；正常游戏直接读取设备。
	if screen_provider.is_valid():
		var screen: Dictionary=screen_provider.call()
		return maxf(48,logical_touch_size(screen.dpi,screen.physical,screen.canvas))
	if OS.get_name()!="Android": return 48
	var tree:=Engine.get_main_loop() as SceneTree
	if tree==null: return 48
	return maxf(48,logical_touch_size(DisplayServer.screen_get_dpi(),Vector2(DisplayServer.window_get_size()),tree.root.get_visible_rect().size))

static func drag_threshold() -> float:
	if screen_provider.is_valid():
		var screen: Dictionary=screen_provider.call()
		return logical_touch_size(screen.dpi,screen.physical,screen.canvas,UILayout.DRAG_THRESHOLD_DP)
	if OS.get_name()!="Android": return UILayout.DRAG_THRESHOLD_DP
	var tree:=Engine.get_main_loop() as SceneTree
	if tree==null: return UILayout.DRAG_THRESHOLD_DP
	var dpi: int=DisplayServer.screen_get_dpi()
	if dpi<=0: return UILayout.DRAG_THRESHOLD_DP
	return logical_touch_size(dpi,Vector2(DisplayServer.window_get_size()),tree.root.get_visible_rect().size,UILayout.DRAG_THRESHOLD_DP)
