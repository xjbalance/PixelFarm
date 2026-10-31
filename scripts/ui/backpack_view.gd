class_name BackpackView
extends Control
## One modal inventory view; all mutations are committed by Inventory, never by cells.
const HOLD_MS: int=450
var owner_panel: PanelContainer
var column: VBoxContainer
var categories: HFlowContainer
var category_buttons: Dictionary={}
var body: HBoxContainer
var left: VBoxContainer
var grid: GridContainer
var detail_scroll: ScrollContainer
var detail: VBoxContainer
var balance: Label
var feedback: Label
var page_label: Label
var previous_button: Button
var next_button: Button
var sort_button: Button
var cells: Array[InventorySlotView]=[]
var page: int=0
var page_size: int=32
var selected_uid: int=0
var selected_item: String=""
var filter: String="all"
var session: int=0
var revision: int=-1
var refresh_queued: bool=false
var geometry: Vector2i=Vector2i.ZERO
var visible_entries: Array=[]
var detail_signature: Array=[]
var overlay: Control
var popup: PanelContainer
var popup_content: VBoxContainer
var popup_scroll: ScrollContainer
var ghost: TextureRect
var quantity_mode: String=""
var quantity_uid: int=0
var quantity_revision: int=0
var quantity_value: int=1
var quantity_label: Label
var quantity_slider: TouchQuantitySlider
var quantity_confirm: Button
var overlay_serial: int=0
var finger: int=-1
var mouse_held: bool=false
var origin:=Vector2.ZERO
var pointer:=Vector2.ZERO
var pressed_at: int=0
var source_uid: int=0
var source_revision: int=0
var dragging: bool=false
var scrolling: bool=false
var armed_uid: int=0
var page_hover: float=0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;mouse_filter=Control.MOUSE_FILTER_STOP
	column=VBoxContainer.new();column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.add_theme_constant_override("separation",8);add_child(column)
	var head:=HBoxContainer.new();column.add_child(head)
	var title:=FarmUIStyle.label("随身背包",24,FarmUIStyle.TITLE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	sort_button=FarmUIStyle.button("一键整理",sort_inventory,112);head.add_child(sort_button)
	head.add_child(FarmUIStyle.button("关闭 ×",func(): owner_panel.close_panel(),100))
	balance=FarmUIStyle.label("",16);column.add_child(balance)
	categories=HFlowContainer.new();categories.add_theme_constant_override("h_separation",4);categories.add_theme_constant_override("v_separation",4);column.add_child(categories)
	for id in ItemTaxonomy.CATEGORIES:
		var key: String=id
		var button:=FarmUIStyle.button(ItemTaxonomy.LABELS[id],func(): change_filter(key),76)
		button.add_theme_font_size_override("font_size",16);button.toggle_mode=true;categories.add_child(button);category_buttons[id]=button
	body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);column.add_child(body)
	left=VBoxContainer.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(left)
	body.resized.connect(queue_refresh);left.resized.connect(queue_refresh)
	grid=GridContainer.new();grid.columns=8;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);left.add_child(grid)
	var space:=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(space)
	detail_scroll=ScrollContainer.new();detail_scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));detail_scroll.custom_minimum_size.x=290;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(detail_scroll)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",8);detail_scroll.add_child(detail)
	var footer:=HBoxContainer.new();column.add_child(footer)
	previous_button=FarmUIStyle.button("上一页",func(): turn_page(-1),100);footer.add_child(previous_button)
	page_label=FarmUIStyle.label("",16);page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;footer.add_child(page_label)
	next_button=FarmUIStyle.button("下一页",func(): turn_page(1),100);footer.add_child(next_button)
	feedback=FarmUIStyle.label("轻点查看；长按后拖动，或松手打开操作。",15,FarmUIStyle.MUTED);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(feedback)
	overlay=ModalTouchShield.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;overlay.z_index=90;add_child(overlay);overlay.hide()
	var dim:=ColorRect.new();dim.color=Color(.2,.16,.1,.23);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(dim)
	popup=PanelContainer.new();popup.add_theme_stylebox_override("panel",FarmUIStyle.surface("paper"));overlay.add_child(popup)
	popup_scroll=ScrollContainer.new();popup_scroll.set_script(preload("res://scripts/ui/touch_scroll.gd"));popup_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;popup.add_child(popup_scroll)
	popup_content=VBoxContainer.new();popup_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;popup_content.add_theme_constant_override("separation",8);popup_scroll.add_child(popup_content)
	ghost=TextureRect.new();ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ghost.size=Vector2(64,64);ghost.modulate=Color(1,1,1,.65);ghost.z_index=100;add_child(ghost);ghost.hide()
	Inventory.changed.connect(queue_refresh)
	GameState.preferences_changed.connect(queue_refresh)
	Events.notice.connect(func(message: String):
		if live(): feedback.text=message
	)
	resized.connect(queue_refresh)
	get_viewport().size_changed.connect(func(): cancel_gesture();close_overlay();queue_refresh())
	hide()

func open() -> void:
	session+=1;filter=str(GameState.preferences.bag_category);page=0;revision=-1;feedback.text="轻点查看；长按后拖动，或松手打开操作。";show();cancel_gesture();close_overlay();queue_refresh()
func close() -> void:
	session+=1;cancel_gesture();close_overlay();selected_uid=0;selected_item="";detail_signature=[];hide()
func live() -> bool: return is_visible_in_tree() and is_instance_valid(owner_panel) and owner_panel.visible and not owner_panel.shop_mode
func queue_refresh() -> void:
	if not live() or refresh_queued: return
	refresh_queued=true
func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child);child.queue_free()

func refresh() -> void:
	refresh_queued=false
	if not live(): return
	Inventory.sync_layout()
	if revision!=Inventory.revision:
		if revision>=0 and (dragging or armed_uid>0 or finger>=0 or mouse_held or overlay.visible): cancel_gesture();close_overlay();feedback.text="物品已更新，请重新选择。"
		revision=Inventory.revision
	if selected_uid>0 and Inventory.stack(selected_uid).is_empty():
		selected_uid=0
		for entry in Inventory.layout.slots:
			if not entry.is_empty() and entry.item==selected_item: selected_uid=int(entry.uid);break
		if selected_uid==0: selected_item="";owner_panel.selected_item=""
	var target: float=UIMetrics.minimum_target()
	var slot_size: float=maxf(target,72*float(GameState.preferences.ui_scale))
	for button in category_buttons.values(): button.custom_minimum_size=Vector2(maxf(76,target),target)
	for button in [previous_button,next_button,sort_button]: button.custom_minimum_size.y=target
	detail_scroll.custom_minimum_size.x=clampf(size.x*.27,250,330)
	# Use the outer budget, not a Container size already inflated by its old
	# grid minimum. Otherwise a high-DPI grid cannot shrink back into the panel.
	var width: float=maxf(220,size.x-detail_scroll.custom_minimum_size.x-14)
	var height: float=size.y-8*(column.get_child_count()-1)
	for child in column.get_children():
		if child!=body and child is Control: height-=child.get_combined_minimum_size().y
	height=maxf(slot_size,height)
	var columns: int=clampi(floori((width+6)/(slot_size+6)),2,9)
	var rows: int=clampi(floori((height+6)/(slot_size+6)),1,5)
	var layout:=Vector2i(columns,rows)
	if layout!=geometry:
		if finger>=0 or mouse_held: cancel_gesture()
		geometry=layout;page_size=columns*rows;grid.columns=columns
		clear(grid);cells.clear()
		for i in range(page_size):
			var cell:=InventorySlotView.new();cell.custom_minimum_size=Vector2(slot_size,slot_size);grid.add_child(cell);cells.append(cell)
	for cell in cells: cell.custom_minimum_size=Vector2(slot_size,slot_size)
	visible_entries=entries()
	var pages: int=maxi(1,ceili(visible_entries.size()/float(page_size)));page=clampi(page,0,pages-1)
	for i in range(cells.size()):
		var index: int=page*page_size+i
		var row: Dictionary=visible_entries[index] if index<visible_entries.size() else {"slot":-1,"entry":{}}
		cells[i].display(int(row.slot),row.entry,not row.entry.is_empty() and int(row.entry.uid)==selected_uid)
	for id in category_buttons:
		category_buttons[id].set_pressed_no_signal(id==filter)
		if not category_buttons[id].has_meta("active") or bool(category_buttons[id].get_meta("active"))!=(id==filter):
			category_buttons[id].set_meta("active",id==filter);category_buttons[id].add_theme_stylebox_override("normal",FarmUIStyle.surface("selected" if id==filter else "secondary"))
	balance.text="%d 金 · %d 种随身物品 · 每种最多 %d" % [Inventory.coins,Inventory.items.size(),Inventory.MAX_STACK]
	page_label.text="第 %d / %d 页" % [page+1,pages];previous_button.disabled=page==0;next_button.disabled=page==pages-1
	update_detail()
	if dragging: update_pointer(pointer,mouse_held)

func entries() -> Array:
	var result: Array=[];var slots: Array=Inventory.layout.slots
	if filter=="all":
		var count: int=maxi(page_size,ceili(maxi(1,slots.size())/float(page_size))*page_size)
		for i in range(mini(count,InventorySlots.limit())): result.append({"slot":i,"entry":slots[i] if i<slots.size() else {}})
	else:
		for i in range(slots.size()):
			if not slots[i].is_empty() and ItemTaxonomy.category(str(slots[i].item))==filter: result.append({"slot":i,"entry":slots[i]})
		var target: int=maxi(page_size,ceili(maxi(1,result.size())/float(page_size))*page_size)
		for i in range(InventorySlots.limit()):
			if result.size()>=target: break
			if i>=slots.size() or slots[i].is_empty(): result.append({"slot":i,"entry":{}})
	return result

func select(uid: int) -> void:
	var entry:=Inventory.stack(uid)
	if entry.is_empty(): return
	selected_uid=uid;selected_item=str(entry.item)
	owner_panel.selected_item=selected_item
	for cell in cells: cell.selected=not cell.entry.is_empty() and int(cell.entry.uid)==uid;cell.queue_redraw()
	update_detail()
func select_item(id: String) -> void:
	Inventory.sync_layout()
	for entry in Inventory.layout.slots:
		if entry.is_empty() or entry.item!=id: continue
		if filter!="all" and ItemTaxonomy.category(id)!=filter: filter=ItemTaxonomy.category(id);GameState.set_preference("bag_category",filter)
		visible_entries=entries()
		for i in range(visible_entries.size()):
			if not visible_entries[i].entry.is_empty() and visible_entries[i].entry.uid==entry.uid: page=i/page_size;break
		select(int(entry.uid));queue_refresh();return
func change_filter(id: String) -> void:
	if finger>=0 or mouse_held: return
	cancel_gesture();close_overlay();filter=id;page=0;GameState.set_preference("bag_category",id);queue_refresh()
func turn_page(delta: int) -> void:
	page=clampi(page+delta,0,maxi(0,ceili(visible_entries.size()/float(page_size))-1));queue_refresh()
func sort_inventory() -> void:
	if finger>=0 or mouse_held: return
	cancel_gesture();close_overlay()
	feedback.text="已按种类整理，相同物品已合并。" if Inventory.sort_stacks(Inventory.revision) else "当前无法整理，请稍后再试。"
	queue_refresh()

func action(text: String, callback: Callable, parent: Node=null) -> Button:
	var epoch: int=session;var popup_epoch: int=overlay_serial
	var in_popup: bool=parent!=null and (parent==popup_content or popup_content.is_ancestor_of(parent))
	var button:=FarmUIStyle.button(text,func():
		if not live() or epoch!=session or finger>=0 or mouse_held: return
		if in_popup and (not overlay.visible or popup_epoch!=overlay_serial): return
		callback.call()
	,100)
	button.custom_minimum_size=Vector2(maxf(100,UIMetrics.minimum_target()),UIMetrics.minimum_target());(parent if parent!=null else detail).add_child(button);return button
func update_detail() -> void:
	var signature: Array=[selected_uid,Inventory.revision,GameState.stamina,GameState.preferences.ui_scale]
	if signature==detail_signature: return
	detail_signature=signature
	clear(detail)
	var entry:=Inventory.stack(selected_uid)
	if entry.is_empty(): FacilityLayout.text(detail,"选择一个物品",22);FacilityLayout.text(detail,"轻点格子查看用途。长按后拖动可移动；松手可打开拆分等操作。",16);return
	var id: String=entry.item
	var icon:=TextureRect.new();icon.texture=ItemTaxonomy.texture(id);icon.custom_minimum_size=Vector2(64,64);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail.add_child(icon)
	FacilityLayout.text(detail,ItemTaxonomy.title(id),22)
	FacilityLayout.text(detail,ItemTaxonomy.LABELS[ItemTaxonomy.category(id)]+(" · 随身工具" if ItemTaxonomy.is_permanent_tool(id) else " · 本组%d / 共%d" % [entry.amount,Inventory.count(id)]),16)
	FacilityLayout.text(detail,ItemTaxonomy.description(id),16)
	if Recovery.FOOD.has(id): FacilityLayout.text(detail,"食用恢复最多 %d 体力" % int(Recovery.FOOD[id]),16)
	if not ItemTaxonomy.is_permanent_tool(id): FacilityLayout.text(detail,"单件售价 %d 金" % Catalog.sell_price(id) if Catalog.sell_price(id)>0 else "不可出售",16)
	if ItemTaxonomy.is_protected(id): FacilityLayout.text(detail,"重要物品 · 不可丢弃",15).add_theme_color_override("font_color",FarmUIStyle.MUTED)
	if Inventory.stack_locked(selected_uid): FacilityLayout.text(detail,"已锁定位置",16).add_theme_color_override("font_color",FarmUIStyle.SUCCESS)
	var uid: int=selected_uid
	if ItemTaxonomy.usable(id):
		var equip: bool=ItemTaxonomy.is_permanent_tool(id) or id.ends_with("_seed")
		var use_button:=action("选用" if equip else "装备鱼钩" if id=="fishing_hook" else "食用1份",func(): use(uid))
		use_button.set_meta("inventory_action",id);use_button.set_meta("action_kind","equip" if equip else "eat")
		if not equip and id!="fishing_hook": use_button.disabled=GameState.stamina>=GameState.max_stamina()
	var split:=action("拆分数量",func(): open_quantity(uid,"split"));split.disabled=int(entry.amount)<2 or ItemTaxonomy.is_permanent_tool(id) or Inventory.stack_locked(uid)
	action("解锁位置" if Inventory.stack_locked(uid) else "锁定位置",func(): Inventory.toggle_stack_lock(uid,Inventory.revision))
	action("更多操作",func(): open_context(uid))

func use(uid: int) -> void:
	var entry:=Inventory.stack(uid)
	if entry.is_empty(): return
	var ok:=Inventory.use_stack(uid,Inventory.revision)
	if ok and (ItemTaxonomy.is_permanent_tool(entry.item) or str(entry.item).ends_with("_seed")): owner_panel.close_panel()
	else:
		if not ok: feedback.text="当前不能使用：请检查数量、体力或装备状态。"
		queue_refresh()

func open_overlay() -> void:
	overlay_serial+=1
	clear(popup_content);quantity_mode="";overlay.show();popup.size=Vector2.ZERO;popup_scroll.scroll_vertical=0
	popup.custom_minimum_size=Vector2(minf(440,size.x-24),0)
	call_deferred("position_popup")
func position_popup() -> void:
	if not overlay.visible: return
	var desired:=popup_content.get_combined_minimum_size()+popup.get_theme_stylebox("panel").get_minimum_size()
	popup.size=Vector2(maxf(440,desired.x),desired.y).min(size-Vector2(16,16));popup.position=(size-popup.size)*.5
func close_overlay() -> void:
	overlay_serial+=1
	if is_instance_valid(overlay): overlay.hide()
	quantity_mode="";quantity_uid=0
func handle_back() -> bool:
	if overlay.visible: close_overlay();return true
	if dragging or armed_uid>0 or finger>=0: cancel_gesture();return true
	return false

func open_context(uid: int) -> void:
	var entry:=Inventory.stack(uid)
	if entry.is_empty(): return
	open_overlay();FacilityLayout.text(popup_content,ItemTaxonomy.title(str(entry.item)),22)
	if ItemTaxonomy.usable(entry.item): action("使用 / 选用",func(): close_overlay();use(uid),popup_content)
	var move:=action("移动整组",func(): close_overlay();armed_uid=uid;source_uid=uid;source_revision=Inventory.revision;ghost.texture=ItemTaxonomy.texture(entry.item);ghost.show();feedback.text="点一个目标格放下；点无效位置会返回原处。",popup_content);move.disabled=Inventory.stack_locked(uid)
	var split:=action("拆分",func(): open_quantity(uid,"split"),popup_content);split.disabled=int(entry.amount)<2 or ItemTaxonomy.is_permanent_tool(entry.item) or Inventory.stack_locked(uid)
	action("查看详情",func(): close_overlay();select(uid),popup_content)
	var discard:=action("丢弃…",func(): open_quantity(uid,"discard"),popup_content);discard.disabled=ItemTaxonomy.is_protected(entry.item) or Inventory.stack_locked(uid)
	action("取消",close_overlay,popup_content)

func open_quantity(uid: int, mode: String) -> void:
	var entry:=Inventory.stack(uid)
	if entry.is_empty() or Inventory.stack_locked(uid) or ItemTaxonomy.is_permanent_tool(entry.item): return
	if mode=="discard" and ItemTaxonomy.is_protected(entry.item): return
	open_overlay();quantity_mode=mode;quantity_uid=uid;quantity_revision=Inventory.revision;quantity_value=maxi(1,int(entry.amount)/2)
	var operation: int=overlay_serial
	FacilityLayout.text(popup_content,("拆分 · " if mode=="split" else "丢弃 · ")+ItemTaxonomy.title(entry.item),22)
	quantity_label=FacilityLayout.text(popup_content,"",18)
	quantity_slider=TouchQuantitySlider.new();quantity_slider.min_value=1;quantity_slider.max_value=int(entry.amount);quantity_slider.step=1;quantity_slider.value=quantity_value;quantity_slider.custom_minimum_size=Vector2(380,UIMetrics.minimum_target());popup_content.add_child(quantity_slider)
	quantity_slider.value_changed.connect(func(value: float):
		if operation==overlay_serial and overlay.visible: quantity_value=int(value);update_quantity()
	)
	var presets:=HBoxContainer.new();popup_content.add_child(presets)
	for pair in [["1个",1],["一半",maxi(1,int(entry.amount)/2)],["全部",int(entry.amount)]]:
		var amount: int=pair[1];action(pair[0],func(): quantity_slider.value=amount,presets)
	var adjust:=HBoxContainer.new();popup_content.add_child(adjust)
	action("−1",func(): quantity_slider.value=maxi(1,quantity_value-1),adjust)
	action("+1",func(): quantity_slider.value=mini(int(entry.amount),quantity_value+1),adjust)
	if mode=="discard": FacilityLayout.text(popup_content,"丢弃后无法取回。",16).add_theme_color_override("font_color",FarmUIStyle.DANGER)
	var epoch: int=session
	quantity_confirm=action("确认拆分" if mode=="split" else "确认丢弃",func():
		if not live() or epoch!=session or not overlay.visible or operation!=overlay_serial: return
		var ok: bool=Inventory.split_stack(quantity_uid,quantity_value,quantity_revision) if quantity_mode=="split" else Inventory.discard_stack(quantity_uid,quantity_value,quantity_revision)
		close_overlay();feedback.text="操作完成。" if ok else "物品已变化或位置锁定，本次没有修改数量。";queue_refresh()
	,popup_content)
	quantity_slider.drag_started.connect(func():
		if operation==overlay_serial: quantity_confirm.disabled=true
	)
	quantity_slider.drag_ended.connect(func(_changed: bool):
		if operation==overlay_serial: quantity_confirm.disabled=false
	)
	action("取消",close_overlay,popup_content);update_quantity();call_deferred("position_popup")
func update_quantity() -> void:
	var entry:=Inventory.stack(quantity_uid)
	if entry.is_empty(): close_overlay();return
	quantity_label.text="当前 %d · 本次 %d · 剩余 %d" % [entry.amount,quantity_value,int(entry.amount)-quantity_value]

func slot_at(at: Vector2) -> InventorySlotView:
	if not live() or overlay.visible or not get_global_rect().has_point(at): return null
	for cell in cells:
		if cell.is_visible_in_tree() and cell.get_global_rect().has_point(at): return cell
	return null
func cancel_gesture() -> void:
	finger=-1;mouse_held=false;source_uid=0;dragging=false;scrolling=false;armed_uid=0;page_hover=0
	if is_instance_valid(ghost): ghost.hide()
	for cell in cells: cell.drop_state=0;cell.dragging_source=false;cell.queue_redraw()
func start_pointer(at: Vector2, is_mouse: bool, index: int=-1) -> bool:
	var cell:=slot_at(at)
	if cell==null: return false
	if armed_uid==0 and cell.entry.is_empty(): return false
	origin=at;pointer=at;pressed_at=Time.get_ticks_msec();source_uid=armed_uid if armed_uid>0 else int(cell.entry.uid);source_revision=Inventory.revision
	mouse_held=is_mouse;finger=index if not is_mouse else -1
	select(source_uid)
	if armed_uid>0: dragging=true
	return true
func update_pointer(at: Vector2, immediate: bool) -> void:
	pointer=at
	if source_uid==0: return
	if not immediate and not dragging and at.distance_to(origin)>UIMetrics.drag_threshold() and Time.get_ticks_msec()-pressed_at<HOLD_MS: scrolling=true
	if not dragging and not scrolling and not Inventory.stack_locked(source_uid) and at.distance_to(origin)>UIMetrics.drag_threshold() and (immediate or Time.get_ticks_msec()-pressed_at>=HOLD_MS):
		dragging=true;ghost.texture=ItemTaxonomy.texture(selected_item);ghost.show()
	if dragging:
		ghost.position=at-global_position-ghost.size*.5
		var target:=slot_at(at)
		for cell in cells:
			cell.dragging_source=not cell.entry.is_empty() and int(cell.entry.uid)==source_uid
			cell.drop_state=0 if cell!=target else 2 if not cell.entry.is_empty() and Inventory.stack_locked(int(cell.entry.uid)) else 1
			cell.queue_redraw()
func finish_pointer(at: Vector2, canceled: bool=false) -> void:
	var uid: int=source_uid;var token: int=source_revision;var was_dragging: bool=dragging
	var held: bool=Time.get_ticks_msec()-pressed_at>=HOLD_MS
	var target:=slot_at(at);var moved: bool=at.distance_to(origin)>UIMetrics.drag_threshold()
	var was_scrolling: bool=scrolling;var delta:=at-origin
	cancel_gesture()
	if canceled or uid==0: return
	if was_dragging:
		var ok: bool=target!=null and target.slot_index>=0 and Inventory.move_stack(uid,target.slot_index,token)
		feedback.text="已移动或合并。" if ok else "没有放到合法格子，物品留在原处。";queue_refresh()
	elif was_scrolling:
		turn_page(-1 if (delta.x>0 if absf(delta.x)>absf(delta.y) else delta.y>0) else 1)
	elif not moved:
		select(uid)
		if held: open_context(uid)

func _input(event: InputEvent) -> void:
	if not live(): return
	if event is InputEventScreenTouch:
		if event.pressed:
			if finger>=0 or mouse_held or (is_instance_valid(Kitchen.game) and Kitchen.game.touch_input.fingers.size()>1): cancel_gesture();return
			if start_pointer(event.position,false,event.index): get_viewport().set_input_as_handled()
		elif event.index==finger:
			get_viewport().set_input_as_handled();finish_pointer(event.position,event.canceled)
	elif event is InputEventScreenDrag and event.index==finger:
		get_viewport().set_input_as_handled();update_pointer(event.position,false)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if finger>=0: cancel_gesture();get_viewport().set_input_as_handled();return
			if start_pointer(event.position,true): get_viewport().set_input_as_handled()
		elif mouse_held:
			get_viewport().set_input_as_handled();finish_pointer(event.position)
	elif event is InputEventMouseMotion and mouse_held:
		update_pointer(event.position,true);get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not live(): return
	if refresh_queued: refresh()
	if not dragging: return
	var rect:=grid.get_global_rect()
	if rect.has_point(pointer) and (pointer.x<rect.position.x+18 or pointer.x>rect.end.x-18):
		page_hover+=delta
		if page_hover>.65: turn_page(-1 if pointer.x<rect.position.x+18 else 1);page_hover=0
	else: page_hover=0
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: cancel_gesture();close_overlay()
