extends PanelContainer
## 只覆盖调色板/确认栏的实际矩形；世界手势由控制器单独仲裁。
var controller: Node

func open_panel() -> void:
	controller.open()

func close_panel() -> void:
	controller.cancel()
