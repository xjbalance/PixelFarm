extends "res://tests/runner.gd"
var capture_mode: bool=false
var captures: Array=[]

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	var atlas: FarmAtlasCanvas=game.hud.atlas_panel.map_canvas
	check(FarmAtlasData.world_places().size()==12,"世界总览有八个原地区和四张实际制作的私人领地")
	for area in TerritoryCatalog.ANNEX_AREAS:
		check(not FarmAtlasData.known(area) and FarmAtlasData.title(area).contains("未开放"),"初始图纸明确标记待开放领地："+area)
		check(FarmAtlasData.description(area).contains("图纸仅供查看"),"图纸不提供领地传送："+area)
	check(game.hud.atlas_panel.open_panel(),"新版羊皮纸地图正常展开")
	await frames(20);await capture("atlas_locked")
	var origin: Vector2=game.player.global_position
	var execution: int=game.auto_move.execution_count
	for area in TerritoryCatalog.ANNEX_AREAS:
		atlas.show_region(area);check(atlas.layer_id=="world","未开放领地不能提前查看可编辑详图："+area)
	check(game.player.global_position==origin and game.auto_move.execution_count==execution,"查看未开放领地不移动角色或派发寻路")
	game.hud.atlas_panel.close_panel()
	Story.stage=5;Story.changed.emit()
	check(FarmAtlasData.bridge_open() and not Territory.unlocked("east_holding"),"修桥图纸同步，但第一章尚未完成时领地仍锁定")
	Story.stage=8;Story.changed.emit()
	check(Territory.unlocked("east_holding") and not Territory.unlocked("lake_holding"),"第一章完成后只开放河东领地")
	LakeEcology.state.restored=true;LakeEcology.changed.emit()
	check(not Territory.unlocked("lake_holding"),"仅湖泊修复不能跳过第二章对应任务")
	ChapterTwo.completed.append("water");ChapterTwo.changed.emit()
	check(Territory.unlocked("lake_holding") and not Territory.unlocked("forest_holding"),"第二章任务与湖泊修复共同同步湖畔授权")
	Exploration.state.forest.open=true;Exploration.state.facts.append("forest_archive");Exploration.changed.emit()
	check(Territory.unlocked("forest_holding") and not Territory.unlocked("manor_holding"),"森林实际清障及档案同步开放林地")
	River.state.facts.append("closing_scene");River.changed.emit()
	check(Territory.unlocked("manor_holding"),"现有终章完成后图纸与庄园权限同步")
	check(WorldTravel.change(game,"east_holding"),"实际步行换区进入已开放的河东领地")
	await frames(6)
	check(game.territory_editor.open(),"在真实河东区域打开建造模式")
	var plan:=Territory.plan_terrain("east_holding",[Vector2i(10,10),Vector2i(11,10),Vector2i(12,10)],"stone_path")
	check(plan.valid and Territory.apply_plan(plan),"真实铺路结果写入领地差异")
	await frames(5)
	plan=Territory.plan_place("east_holding","lamp",Vector2i(10,12))
	check(plan.valid and Territory.apply_plan(plan),"地图地标来源是实际确认的小型设施")
	var lamp_id: String=Territory.state.objects[-1].id
	game.territory_editor.cancel();await frames(4)
	check(game.hud.atlas_panel.open_panel(),"改造后可正常打开世界图纸")
	game.hud.atlas_panel.show_current();await frames(18)
	check(atlas.region_id=="east_holding" and atlas.player_map_position()==FarmAtlasData.world_to_map("east_holding",game.player.global_position),"新增场景使用独立坐标显示真实玩家位置")
	var lamp: Dictionary={}
	for item in atlas.places:
		if item.id==lamp_id: lamp=item
	check(not lamp.is_empty() and lamp.world_position==Vector2(336,400),"设施图纸位置对应真实放置格")
	var protected: Dictionary={"items":Inventory.items.duplicate(true),"coins":Inventory.coins,"stamina":GameState.stamina,"player":game.player.position,"territory":Territory.snapshot(),"mine":MineState.snapshot(),"xiaojing":Xiaojing.snapshot()}
	atlas.zoom_by(2);atlas.pan_by(Vector2(80,-35));atlas.center_player();await frames(4)
	check(atlas.screen_to_map(atlas.map_to_screen(atlas.player_map_position())).distance_to(atlas.player_map_position())<2,"领地详图缩放拖动后坐标映射准确")
	atlas.zoom_by(.5);atlas.pan=Vector2.ZERO;atlas.refresh_state();await frames(4)
	await capture("atlas_east_detail")
	game.hud.atlas_panel.show_world();await frames(5);await capture("atlas_unlocked")
	check(Inventory.items==protected.items and Inventory.coins==protected.coins and GameState.stamina==protected.stamina and game.player.position==protected.player and Territory.snapshot()==protected.territory and MineState.snapshot()==protected.mine and Xiaojing.snapshot()==protected.xiaojing,"地图查看保留钱物体力、改造、地下和关系数据")
	for size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1600,720),Vector2i(1280,960)]:
		get_window().size=size;await frames(6);game.hud.atlas_panel.layout_panel();await frames(5)
		check(game.hud.safe.get_global_rect().grow(.5).encloses(game.hud.atlas_panel.get_global_rect()),"领地图纸适配横屏："+str(size))
		await capture("atlas_"+str(size.x)+"x"+str(size.y))
	game.hud.atlas_panel.close_panel();await frames(3)
	check(not GameState.modal and game.player.position==protected.player,"图纸关闭恢复游戏且不执行地图传送")
	var output:=FileAccess.open("res://builds/territory-atlas-"+("render" if capture_mode else "state")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checked,"failures":failed,"captures":captures,"platform":DisplayServer.get_name(),"android_device_tested":false},"\t"));output.close()
	print("TERRITORY ATLAS "+("RENDER" if capture_mode else "STATE")+" RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func capture(label: String) -> void:
	if not capture_mode or DisplayServer.get_name()=="headless": return
	game.hud.toast_time=0;await frames(4);await RenderingServer.frame_post_draw
	var path: String="res://builds/territory-"+label+".png"
	get_viewport().get_texture().get_image().save_png(path);captures.append({"name":label,"path":path})
