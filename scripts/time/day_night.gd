extends CanvasModulate
## 只调制世界画布，HUD 位于单独 CanvasLayer 保持清晰可读。
func _ready() -> void:
	GameClock.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if (GameState.location in MineState.AREAS or GameState.location=="abyss"):
		color=Color("74869b") if GameState.location=="abyss" and AbyssState.state.depth>=81 else Color("a6aec0")
		return
	if GameState.location in ["home","greenhouse"]:
		color = Color("fff0d5")
		return
	var hour: float = GameClock.minutes / 60.0
	if hour < 8.0:
		color = Color("e6d4b6").lerp(Color.WHITE,(hour-6.0)/2.0)
	elif hour < 17.0:
		color = Color.WHITE
	elif hour < 20.0:
		color = Color.WHITE.lerp(Color("ba9b91"),(hour-17.0)/3.0)
	else:
		color = Color("ba9b91").lerp(Color("66759b"),(hour-20.0)/4.0)
