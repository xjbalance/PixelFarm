extends "res://tests/runner.gd"
## Every catalog object is placed, moved and removed through the real build editor.
## Run with -- --capture-placement in an actual window for representative screenshots.
const FIRST_CELL:=Vector2i(24,10)
const MOVED_CELL:=Vector2i(29,16)
var editor: TerritoryEditor
var captures: Array=[]
var capture_mode: bool=false
var original: Dictionary={}
var baseline: Dictionary={}
var decorative_calls: Array=[]

func run() -> void:
	capture_mode="--capture-placement" in OS.get_cmdline_user_args()
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(9)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	load("res://tests/star_runner.gd").fixture(game,false);Territory.refresh_unlocks(false)
	GameClock.minutes=720;GameClock.changed.emit();await frames(5)
	check(Territory.unlocked("east_holding"),"用既有章节夹具开放河东，未直接写入自授权限")
	game.change_location("east_holding",Vector2(640,800));game.auto_move.cancel();await frames(6)
	editor=game.territory_editor;baseline=FarmSaveStore.snapshot(game)
	check(editor.open(),"实际进入领地建造模式后才测试新目录")
	await frames(3)
	await catalog_buttons()
	var kinds: Array=TerritoryCatalog.OBJECT_KINDS.keys()
	check(kinds.size()==98,"98种新旧放置目录全部纳入实际场景回归")
	for kind in kinds: await exercise(str(kind))
	check(Territory.state.objects.is_empty() and game.territory_world.objects.is_empty(),"全目录拆除后没有遗留实体或碰撞")
	await shared_storage()
	editor.cancel()
	check(FarmSaveStore.restore(game,baseline),"全目录确认后仍可恢复原完整经营快照")
	await frames(5)
	check(Territory.snapshot()==baseline.territory and Housing.snapshot()==baseline.housing and Inventory.items==baseline.items,"恢复后领地、家具收纳和物品均逐项一致")
	check(FarmSaveStore.restore(game,original),"退出测试时恢复真正初始进度，没有把夹具作为玩家进度")
	await frames(4)
	var report:=FileAccess.open("res://builds/scheme-c-placement-"+("render" if DisplayServer.get_name()!="headless" else "state")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checked,"failures":failed,"catalog_kinds":kinds.size(),"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));report.close()
	print("SCHEME C PLACEMENT RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func catalog_buttons() -> void:
	var covered: Dictionary={}
	for category in ["vegetation","objects"]:
		editor.choose_category(category);await frames(2)
		var all_buttons: Dictionary=editor.tool_buttons.duplicate()
		var groups: Array[String]=editor.group_keys()
		var total: int=0
		for kind in TerritoryCatalog.OBJECT_KINDS:
			var definition: Dictionary=TerritoryCatalog.OBJECT_KINDS[kind]
			if definition.category!=category: continue
			total+=1;covered[kind]=true
			check(all_buttons.has(kind) and all_buttons[kind].text==str(definition.name) and groups.has(str(definition.group)),"实际分类按钮包含素材、中文名称及可达分组："+str(kind))
		check(all_buttons.size()==total,"分类默认列表没有遗漏或夹入其他目录："+category)
		for group in groups:
			if group=="all": continue
			editor.subgroup=group;editor._populate_tools();await frames(2)
			var matches: bool=not editor.tool_buttons.is_empty()
			for kind in editor.tool_buttons: matches=matches and str(TerritoryCatalog.OBJECT_KINDS[kind].group)==group
			check(matches,"分组按钮仅展示对应内容："+category+" / "+group)
	check(covered.size()==TerritoryCatalog.OBJECT_KINDS.size(),"同一套滚动分类和分组可以选择全部目录")

func economy() -> Dictionary:
	return {"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"diamonds":Xiaojing.state.diamonds,"housing":Housing.snapshot(),"resources":game.resource_world.snapshot(),"plots":game.farm.plots.duplicate(true)}

func exercise(kind: String) -> void:
	var definition: Dictionary=TerritoryCatalog.OBJECT_KINDS[kind]
	var art: String=str(definition.art)
	var before: Dictionary=Territory.snapshot()
	var funds: Dictionary=economy()
	var interactions: int=get_tree().get_nodes_in_group("interactables").size()
	editor.choose_category(str(definition.category));editor.choose_tool(kind)
	var preview_ok: bool=editor.preview_at(FIRST_CELL)
	check(preview_ok and Territory.snapshot()==before,"合法真实预览不改存档："+kind+" / "+str(editor.preview_plan.get("reason","")))
	if not preview_ok: return
	var preview: Texture2D=editor.preview_texture()
	var bounds: Array[Rect2]=editor.preview_rects()
	check(preview!=null and bounds.size()==1 and bounds[0].size==Vector2(TerritoryCatalog.footprint(kind,FIRST_CELL).size)*32,"预览采用对应贴图和原目录占地："+kind)
	check(editor.confirm(),"确认只放置一个目录对象："+kind)
	await frames(5)
	if Territory.state.objects.is_empty(): return
	var id: String=str(Territory.state.objects[-1].id)
	var node: TerritoryObject=game.territory_world.objects.get(id)
	if not is_instance_valid(node): check(false,"实际目录实体已生成："+kind);return
	check(node.entry.kind==kind and node.definition.art==art and Territory.state.objects.size()==before.objects.size()+1,"对象索引、来源与唯一记录匹配："+kind)
	var extent: Vector2=Vector2(TerritoryCatalog.footprint(kind,FIRST_CELL).size)*32
	check(node.sprite.texture==preview and node.sprite.scale==Vector2.ONE and node.sprite.position==TerritoryObject.art_position(art,extent),"预览与落地共用源贴图，原生比例和脚底锚点一致："+kind)
	if SchemeCAssets.has_repeat(art):
		var module_path: String=SchemeCAssets.ROOT+"seasons/"+SchemeCAssets.SEASONS[Calendar.season()]+"/modules/"+art+".png"
		var module: Texture2D=load(module_path)
		var result: Image=node.sprite.texture.get_image()
		var expected: Image=module.get_image()
		var same: bool=result.get_size()==Vector2i(extent)
		for y in range(result.get_height()):
			for x in range(result.get_width()):
				if result.get_pixel(x,y)!=expected.get_pixel(x%32,y%32): same=false
		check(same,"连接围栏使用逐像素重复模块，未压缩原素材："+kind)
	else:
		var source: Dictionary=SchemeCAssets.definition(art)
		check(not source.is_empty() and node.sprite.texture.get_size()==Vector2(source.size[0],source.size[1]) and node.sprite.texture.resource_path.contains("/world_scheme_c/"),"实体使用对应来源原生画布尺寸："+kind)
	var animated: bool=SchemeCAssets.animation(art)!=null
	check((node.animated.visible and not node.sprite.visible and node.animated.sprite_frames.get_frame_count("loop")==4 and node.animated.sprite_frames.get_animation_speed("loop")==4 and node.animated.position==node.sprite.position) if animated else (node.sprite.visible and not node.animated.visible),"静态或四帧动画状态与目录一致："+kind)
	var solid: bool=bool(definition.solid)
	var collision_ok: bool=node.body.collision_layer==(1 if solid else 0)
	if solid: collision_ok=collision_ok and node.body.get_child_count()==1 and node.body.get_child(0).shape.size==extent-Vector2(4,4)
	else: collision_ok=collision_ok and node.body.get_child_count()==0
	game.auto_move.navigation.rebuild()
	check(collision_ok and game.auto_move.navigation.walkable(FIRST_CELL)==not solid,"实体真实碰撞和导航同步且保留目录占地："+kind)
	check(get_tree().get_nodes_in_group("interactables").size()==interactions+1 and bool(definition.get("decorative",false)),"景观仅增加自身交互点，没有复制旧建筑功能："+kind)
	if str(definition.group)=="buildings":
		check(str(definition.name).contains("景观") and bool(definition.decorative),"建筑、门和窗明确标注为纯景观："+kind)
		await decorative_interaction(node,kind)
	if kind in ["oak_tree","large_pond","picnic_table","wood_fence","farmhouse","windmill","star_spring"]: await capture(kind)
	var old_serial: int=int(Territory.state.serial)
	editor.choose_tool("move");editor.preview_at(FIRST_CELL)
	var moved: bool=editor.preview_at(MOVED_CELL)
	check(moved and editor.confirm(),"通过实际编辑器预览并确认移动："+kind)
	await frames(5)
	check(Territory.object(id).get("cell")==[MOVED_CELL.x,MOVED_CELL.y] and int(Territory.state.serial)==old_serial and Territory.state.objects.size()==before.objects.size()+1 and game.territory_world.objects.get(id)==node,"移动保持唯一ID，不生成副本："+kind)
	editor.choose_tool("remove")
	var removable: bool=editor.preview_at(MOVED_CELL)
	check(removable and editor.confirm(),"通过实际编辑器拆除："+kind)
	await frames(5)
	check(Territory.object(id).is_empty() and not game.territory_world.objects.has(id) and Territory.state.objects.size()==before.objects.size() and get_tree().get_nodes_in_group("interactables").size()==interactions,"拆除后无幽灵碰撞、重复实体或残留交互："+kind)
	check(economy()==funds,"放置、移动、拆除不改经济、原资源、作物和家具库存："+kind)

func decorative_interaction(node: TerritoryObject, kind: String) -> void:
	editor.cancel();game.player.position=node.global_position+Vector2(0,48);game.auto_move.cancel();await frames(3)
	decorative_calls.clear()
	if not Events.interaction_requested.is_connected(record_interaction): Events.interaction_requested.connect(record_interaction)
	var at: String=GameState.location
	node.interact();await frames(3)
	check(decorative_calls.is_empty() and GameState.location==at and not GameState.modal,"点击景观建筑不切图、不打开烹饪畜牧等业务入口："+kind)
	Events.interaction_requested.disconnect(record_interaction)
	game.player.position=Vector2(640,800);await frames(3)
	check(editor.open(),"景观交互后继续正常进入建造模式："+kind)
	await frames(3)

func record_interaction(kind: String) -> void: decorative_calls.append(kind)

func add(kind: String, cell: Vector2i) -> String:
	if not editor.active: check(editor.open(),"共享收纳测试进入建造模式")
	editor.choose_tool(kind)
	var valid: bool=editor.preview_at(cell)
	check(valid and editor.confirm(),"实际放置共享箱子："+kind)
	await frames(5)
	return str(Territory.state.objects[-1].id) if not Territory.state.objects.is_empty() else ""

func approach(id: String) -> TerritoryObject:
	editor.cancel()
	var node: TerritoryObject=game.territory_world.objects[id]
	game.player.position=node.global_position+Vector2(0,40);game.auto_move.cancel();await frames(4)
	check(node.storage_accessible() and Housing.near_storage(),"原住宅收纳认可这个真实箱子站位："+str(node.entry.kind))
	return node

func shared_storage() -> void:
	var storage_before: Dictionary=Housing.state.storage.duplicate(true)
	var capacity: int=Housing.slot_count()
	var old_id: String=await add("chest",Vector2i(24,12))
	var new_id: String=await add("wood_crate",Vector2i(28,12))
	if old_id=="" or new_id=="": return
	var old_box: TerritoryObject=await approach(old_id)
	check(old_box.is_in_group("territory_storage") and old_box.definition.storage and game.territory_world.objects[new_id].is_in_group("territory_storage"),"旧chest与新wood_crate均接入同一住宅收纳入口")
	old_box.interact();await frames(3)
	check(game.hud.housing_panel.visible and game.hud.housing_panel.context=="territory_storage" and game.hud.housing_panel.page=="storage","旧箱子打开原住宅收纳界面")
	game.hud.housing_panel.close_panel();await frames(2)
	Housing.state.storage={};Inventory.items={}
	var ids: Array=Catalog.items.keys()
	var filled: bool=true
	for index in range(capacity+1): Inventory.items[str(ids[index])]=20
	for index in range(capacity): filled=Housing.deposit(str(ids[index]),5) and filled
	check(filled and Housing.state.storage.size()==capacity and Housing.slot_count()==capacity,"通过旧箱子存满原住宅容量，不新增槽位")
	var expected: Dictionary=Housing.state.storage.duplicate(true)
	var inventory: Dictionary=Inventory.items.duplicate(true)
	var new_box: TerritoryObject=await approach(new_id)
	new_box.interact();await frames(3)
	check(game.hud.housing_panel.visible and game.hud.housing_panel.context=="territory_storage" and Housing.state.storage==expected,"新木箱打开同一个原收纳界面，内容不是副本")
	game.hud.housing_panel.close_panel();await frames(2)
	check(not Housing.deposit(str(ids[capacity]),1) and Housing.state.storage==expected and Inventory.items==inventory,"第二个箱子无法绕过原住宅种类容量")
	check(Housing.withdraw(str(ids[0]),2) and int(Housing.state.storage[str(ids[0])])==3 and Inventory.count(str(ids[0]))==17,"从新箱子取出会修改同一份原收纳数量")
	var after_withdraw: Dictionary=Housing.state.storage.duplicate(true)
	await approach(old_id)
	check(Housing.state.storage==after_withdraw and Housing.slot_count()==capacity,"返回旧箱子看到相同余额，容量不扩大")
	game.player.position=Vector2(640,800);await frames(3);check(editor.open(),"箱子操作后可继续移动和拆除")
	var moved:=Territory.plan_move(new_id,Vector2i(30,14))
	check(moved.valid and Territory.apply_plan(moved),"移动新木箱保持原共享库存")
	await frames(5)
	var inventory_after: Dictionary=Inventory.items.duplicate(true)
	for id in [old_id,new_id]:
		var remove:=Territory.plan_remove(id)
		check(remove.valid and Territory.apply_plan(remove),"拆除共享箱子只删除入口："+str(id));await frames(5)
	check(Housing.state.storage==after_withdraw and Inventory.items==inventory_after and Housing.slot_count()==capacity,"移动和拆除两箱不复制、不丢失储物，也不返还额外资源")
	check(not Housing.near_storage(),"所有箱子移除后不能从远处访问住宅库存")
	Housing.state.storage=storage_before

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	# The player's entry is near the south edge. Frame the placed object explicitly
	# so the actual image proves the art, rather than accidentally photographing it offscreen.
	game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK
	game.camera_rig.view_center=game.camera_rig.clamp_center(Vector2(800,440));game.camera_rig.apply_camera()
	await frames(3);await RenderingServer.frame_post_draw
	var path: String="res://builds/scheme-c-placement-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
