extends "res://tests/runner.gd"
const Touch=preload("res://tests/touch_navigation.gd")
const UI=preload("res://tests/story.gd")
var view: BackpackView
var density: bool=false
func run() -> void:
	density="--dpi480" in OS.get_cmdline_user_args()
	get_window().size=Vector2i(1280,720)
	if density: UIMetrics.screen_provider=func(): return {"dpi":480.0,"physical":Vector2(1920,1080),"canvas":Vector2(1280,720)}
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/ux083/before/fixture.json"))
	var restored: bool=FarmSaveStore.restore(game,fixture)
	check(restored,"新背包从旧版同一份物品和世界夹具打开")
	if not restored: await finish();return
	GameClock.running=false;GameWeather.enabled=false;game.tutorial.restore(GameTutorial.defaults(true));await frames(6)
	game.hud.inventory_panel.open_panel(false);await frames(12);view=game.hud.inventory_panel.backpack
	check(view.live() and GameState.modal,"真实背包入口打开新格子界面")
	check(game.hud.safe.get_global_rect().encloses(game.hud.inventory_panel.get_global_rect()),"背包实际边框位于横屏安全区域内")
	var adequate: bool=true
	for cell in view.cells: adequate=adequate and cell.size.x>=UIMetrics.minimum_target() and cell.size.y>=UIMetrics.minimum_target()
	check(adequate,"物品格满足当前设备密度的触摸尺寸")
	check(view.category_buttons.size()==10,"实际提供全部、工具、种子等十类筛选")
	await shot("inventory")
	await tap_button(view.category_buttons.materials)
	var wood:=uid_for("wood");await tap_cell(wood)
	check(view.selected_uid==wood and view.filter=="materials","原生触点按真实物品UID选择木材")
	await shot("materials")
	await tap_button(view.category_buttons.seeds)
	check(view.selected_uid==wood and view.selected_item=="wood","切换分类保留所选物品身份，不误换另一个格子")
	await tap_button(view.category_buttons.materials)
	var source:=Inventory.snapshot_layout();var items:=Inventory.items.duplicate(true);var coins: int=Inventory.coins
	await UI.touch_button(self,view,"拆分数量");await frames(5)
	check(view.overlay.visible and view.quantity_mode=="split","拆分从实际详情操作打开数量面板")
	if not view.overlay.visible: await finish();return
	await slide(17)
	check(view.quantity_value==17 and Inventory.snapshot_layout()==source and Inventory.items==items,"实际触摸滑块精确预览17份，确认前库存不改变")
	await shot("split-preview")
	var selection: int=view.selected_uid
	Touch.finger(self,Vector2(220,220),true,86);Touch.finger(self,Vector2(220,220),false,86);await frames(3)
	check(view.selected_uid==selection and view.overlay.visible,"弹层空白处不会点穿到背包筛选或物品")
	await UI.touch_button(self,view.popup,"取消")
	check(not view.overlay.visible and Inventory.snapshot_layout()==source,"取消数量面板恢复原分组和数量")
	await UI.touch_button(self,view,"拆分数量");await slide(17)
	var confirm: Button=UI.find_button(view.popup,"确认拆分")
	var stale: Callable=confirm.pressed.get_connections()[0].callable
	await tap_button(confirm)
	check(Inventory.stack(wood).amount==59 and Inventory.count("wood")==76,"确认后实际得到59与17两组，原木材总量76")
	var part:=uid_for("wood",wood)
	check(part>0 and Inventory.stack(part).amount==17,"拆分结果是可操作的独立真实分组")
	await UI.touch_button(self,view,"拆分数量");var untouched:=Inventory.snapshot_layout();stale.call();await frames(3)
	check(Inventory.snapshot_layout()==untouched and view.overlay.visible,"旧确认回调不能提交新拆分面板")
	await UI.touch_button(self,view.popup,"取消")
	await shot("split-complete")
	var stone:=uid_for("stone");var stone_index:=Inventory.stack_index(stone)
	await mouse_drag(part,cell_for(stone).get_global_rect().get_center())
	check(Inventory.stack_index(part)==stone_index and Inventory.items==items,"桌面鼠标拖动交换真实木材与石头分组")
	var empty: InventorySlotView
	for cell in view.cells:
		if cell.entry.is_empty() and cell.slot_index>=0: empty=cell;break
	check(empty!=null,"分页内有可放置的真实空格")
	if empty:
		var at: int=empty.slot_index
		await touch_drag(part,empty.get_global_rect().get_center())
		check(Inventory.stack_index(part)==at and Inventory.items==items,"Android单指长按拖动整组到空格")
	await shot("drag-moved")
	untouched=Inventory.snapshot_layout();var position: Vector2=game.player.position
	await touch_drag(part,Vector2(4,704))
	check(Inventory.snapshot_layout()==untouched and game.player.position==position and game.auto_move.target.is_empty(),"拖出背包返回原位，不移动角色或触发农田")
	await touch_drag(part,cell_for(wood).get_global_rect().get_center())
	check(Inventory.stack(part).is_empty() and Inventory.stack(wood).amount==76 and Inventory.items==items,"长按拖到同类分组合并，数量守恒")
	await tap_cell(stone);await UI.touch_button(self,view,"锁定位置");await frames(4)
	stone_index=Inventory.stack_index(stone)
	await tap_button(view.sort_button)
	check(Inventory.stack_index(stone)==stone_index and Inventory.stack_locked(stone) and Inventory.items==items and Inventory.coins==coins,"一键整理保留锁定位置、数量、金币与快捷绑定")
	await shot("sorted")
	await tap_cell(wood)
	var center:=cell_for(wood).get_global_rect().get_center()
	Touch.finger(self,center,true,88);OS.delay_msec(BackpackView.HOLD_MS+20);Touch.finger(self,center,false,88);await frames(5)
	check(view.overlay.visible and UI.find_button(view.popup,"移动整组")!=null,"长按不拖动打开操作菜单")
	await shot("context-menu");await UI.touch_button(self,view.popup,"取消")
	view.open_quantity(wood,"discard");await frames(4);await slide(3)
	var discard_preview:=Inventory.items.duplicate(true)
	await UI.touch_button(self,view.popup,"取消")
	check(Inventory.items==discard_preview,"取消丢弃预览不扣物品")
	view.open_quantity(wood,"discard");await frames(4);await slide(3)
	await UI.touch_button(self,view.popup,"确认丢弃")
	check(Inventory.count("wood")==73,"明确确认后仅丢弃三份真实木材")
	var old_items:=Inventory.items.duplicate(true)
	game.hud.inventory_panel.close_panel();await frames(4)
	check(not GameState.modal and game.auto_move.target.is_empty() and Inventory.items==old_items,"关闭背包清理悬挂手势且不补发世界操作")
	var save:=FarmSaveStore.snapshot(game)
	check(FarmSaveStore.restore(game,JSON.parse_string(JSON.stringify(save))) and Inventory.snapshot_layout()==save.inventory_layout,"真实界面整理后可以存档恢复同一分组与锁定")
	await finish()

func finish() -> void:
	print("UX083 BACKPACK WINDOW RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(6);UIMetrics.screen_provider=Callable();get_tree().quit(1 if failed else 0)

func uid_for(id: String, except_uid: int=0) -> int:
	for entry in Inventory.layout.slots:
		if not entry.is_empty() and entry.item==id and int(entry.uid)!=except_uid: return int(entry.uid)
	return 0
func cell_for(uid: int) -> InventorySlotView:
	for cell in view.cells:
		if not cell.entry.is_empty() and int(cell.entry.uid)==uid: return cell
	return null
func tap_button(button: Button) -> void:
	check(button!=null and not button.disabled,"可见触摸按钮可用")
	if button: UI.touch(self,button)
	await frames(6)
func tap_cell(uid: int) -> void:
	var cell:=cell_for(uid);check(cell!=null,"实际格子可见 "+str(uid))
	if cell:
		var at:=cell.get_global_rect().get_center();Touch.finger(self,at,true,72);Touch.finger(self,at,false,72)
	await frames(5)
func slide(value: int) -> void:
	await frames(5)
	var slider: HSlider=view.quantity_slider;var rect:=slider.get_global_rect()
	var ratio: float=float(value-1)/maxf(1,slider.max_value-1)
	var at:=Vector2(rect.position.x+12+(rect.size.x-24)*ratio,rect.get_center().y)
	Touch.finger(self,at,true,90);Touch.finger(self,at,false,90);await frames(5)
func mouse_drag(uid: int, destination: Vector2) -> void:
	var cell:=cell_for(uid);check(cell!=null,"鼠标拖动物品来源可见")
	if cell==null: return
	var at:=cell.get_global_rect().get_center()
	var down:=InputEventMouseButton.new();down.position=at;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;get_viewport().push_input(down,true)
	var motion:=InputEventMouseMotion.new();motion.position=destination;motion.relative=destination-at;get_viewport().push_input(motion,true);await frames(3)
	down=down.duplicate();down.position=destination;down.pressed=false;get_viewport().push_input(down,true);await frames(6)
func touch_drag(uid: int, destination: Vector2) -> void:
	var cell:=cell_for(uid);check(cell!=null,"触摸拖动物品来源可见")
	if cell==null: return
	var at:=cell.get_global_rect().get_center();Touch.finger(self,at,true,74);OS.delay_msec(BackpackView.HOLD_MS+20)
	var drag:=InputEventScreenDrag.new();drag.index=74;drag.position=destination;drag.relative=destination-at;get_viewport().push_input(drag,true);await frames(3)
	Touch.finger(self,destination,false,74);await frames(6)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute("res://docs/ux083/stage-a")
	await frames(5);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ux083/stage-a/"+("dpi480-" if density else "")+label+".png")
