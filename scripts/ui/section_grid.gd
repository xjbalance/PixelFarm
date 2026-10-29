extends GridContainer
## 设施列表按可用宽度排成两列；只改变视觉容器，原按钮与事务不变。
func _ready() -> void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation",16)
	add_theme_constant_override("v_separation",16)
	resized.connect(reflow)
	minimum_size_changed.connect(func(): call_deferred("reflow"))
	reflow()
func reflow() -> void:
	var available: float=size.x
	var ancestor:=get_parent()
	while ancestor:
		if ancestor is ScrollContainer:
			available=minf(available,ancestor.size.x-16)
			break
		ancestor=ancestor.get_parent()
	var widest: float=0
	for child in get_children():
		if child is Control: widest=maxf(widest,child.get_combined_minimum_size().x)
	var desired: int=2 if available>=760 and widest*2+16<=available else 1
	if columns!=desired: columns=desired
