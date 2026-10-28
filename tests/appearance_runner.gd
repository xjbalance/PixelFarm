extends "res://tests/runner.gd"
## 外观/旧档迁移与新开局写入保护；所有文件均写调用者提供的临时用户目录。
var original: Dictionary

func canonical(raw: Dictionary) -> Dictionary:
	return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(raw)))

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
	game.tutorial.restore(GameTutorial.defaults(true));original=FarmSaveStore.snapshot(game)
	contract_checks()
	await migration_checks()
	await files_and_confirmation()
	check(FarmSaveStore.restore(game,original),"外观专项结束仍可完整恢复原经营和人物数据")
	print("APPEARANCE STATE RESULT: %d checks, %d failures" % [checked,failed])
	game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(1 if failed else 0)

func contract_checks() -> void:
	check(CharacterAppearance.defaults()=={"scheme":"C","player_gender":"male","xiaojing_gender":"female"},"核验过的旧默认男主对应女小京")
	check(CharacterAppearance.defaults("female")=={"scheme":"C","player_gender":"female","xiaojing_gender":"male"},"女主只对应同一小京的男性外观")
	for chosen in ["male","female"]:
		var raw:=CharacterAppearance.defaults(chosen);var copy: Dictionary=raw.duplicate(true)
		check(CharacterAppearance.validate(raw) and CharacterAppearance.normalize(raw)==raw and raw==copy,"合法外观规范化幂等且不改输入："+chosen)
		var paths:=CharacterAppearance.preview_paths(chosen)
		check(paths.player_variant=="player_"+chosen and paths.xiaojing_variant=="xiaojing_"+CharacterAppearance.opposite(chosen),"两位角色的精灵/头像/仪式路径统一由主角选择推导："+chosen)
		check(str(paths.player_asset).contains("compact_32x48/spritesheet.png") and str(paths.companion_wedding).ends_with("compact_32x48/ceremony.png"),"行走和仪式使用已锁定的同一资源命名："+chosen)
	var mismatch: Dictionary={"scheme":"C","player_gender":"female","xiaojing_gender":"female"}
	check(not CharacterAppearance.validate(mismatch) and CharacterAppearance.normalize(mismatch)==CharacterAppearance.defaults("female") and mismatch.xiaojing_gender=="female","只修复性别错配的冗余小京字段，不改主角或输入")
	check(CharacterAppearance.normalize({"scheme":"C","player_gender":"male"})==CharacterAppearance.defaults(),"合法主角缺少冗余小京字段时可安全补齐")
	for invalid in [null,[],{}, {"scheme":"other","player_gender":"male"},{"scheme":"C","player_gender":1},{"scheme":"C","player_gender":"other"},{"scheme":"C","player_gender":"male","future":true}]:
		check(CharacterAppearance.normalize(invalid).is_empty(),"未知方案/主角/额外字段不被洗成默认外观："+str(invalid))
	var isolated:=CharacterAppearance.new();var signals: Array[int]=[0]
	isolated.changed.connect(func(): signals[0]+=1)
	check(isolated.set_player_gender("male") and signals[0]==0,"重复确认相同外观不重复发变更信号")
	check(isolated.set_player_gender("female") and signals[0]==1 and isolated.gender()=="male","外观确认只改变一份状态且只发一次变更")
	var copy: Dictionary=isolated.snapshot();copy.player_gender="male"
	check(isolated.gender("player")=="female" and not isolated.set_player_gender("invalid"),"快照是深拷贝，非法设置不覆盖既有外观")
	check(isolated.resolve_text("林芽说她会来；{xiaojing_pronoun}是你的{xiaojing_spouse}。")=="林芽说她会来；他是你的丈夫。","显式称谓token正确，其他女性NPC的她不被全局替换")
	isolated.free()

func migration_checks() -> void:
	var Arrange=load("res://tests/home_arrange_runner.gd")
	check(await Arrange.setup_married_home(self,game),"迁移夹具沿真实规则形成三级已婚住宅、原柜存与家具")
	var saved: Dictionary=canonical(FarmSaveStore.snapshot(game))
	var old: Dictionary=saved.duplicate(true);old.version=24;old.erase("appearance");old.erase("territory");old.erase("farm_layout")
	var before: Dictionary=old.duplicate(true)
	var migrated: Dictionary=FarmSaveSchema.normalize(old)
	check(not migrated.is_empty() and migrated.version==FarmSaveStore.VERSION and migrated.appearance==CharacterAppearance.defaults(),"真实v24结构只补方案C默认外观并迁入v25")
	var protected: bool=true
	for key in old:
		if key!="version" and canonical({"value":migrated.get(key)})!=canonical({"value":old[key]}): protected=false
	check(protected and old==before,"所有原钱物、农田、房屋、矿洞、三属性和婚姻逐字段保留，迁移不改旧字典")
	check(FarmSaveSchema.normalize(migrated)==migrated,"v24迁入后的当前存档重复规范化完全相同")
	check(FarmSaveStore.restore(game,migrated) and Xiaojing.state.married and Xiaojing.state.diamonds==1314 and GameState.max_stamina()==130,"旧已婚和卧室升级不会因默认外观补齐重新结算")
	for chosen in ["male","female"]:
		var base: Dictionary=canonical(FarmSaveStore.snapshot(game))
		Appearance.set_player_gender(chosen)
		var now: Dictionary=canonical(FarmSaveStore.snapshot(game));base.appearance=CharacterAppearance.defaults(chosen)
		check(now==base and FarmSaveStore.valid(now),"切换外观只改变appearance，不复制另一份小京或其他进度："+chosen)
		var altered: Dictionary=now.duplicate(true);altered.appearance.xiaojing_gender=chosen
		var repaired: Dictionary=FarmSaveSchema.normalize(altered)
		check(repaired==now and altered.appearance.xiaojing_gender==chosen,"当前v25只修复错配小京，不触经营和选择："+chosen)
	var invalid: Dictionary=canonical(FarmSaveStore.snapshot(game));invalid.appearance.player_gender="invalid"
	check(FarmSaveSchema.normalize(invalid).is_empty(),"当前格式非法主角外观使该主档拒绝读取，允许沿原备份回退")
	invalid=canonical(FarmSaveStore.snapshot(game));invalid.erase("appearance")
	check(FarmSaveSchema.normalize(invalid).is_empty(),"v25缺必要外观字段不被冒充为历史旧档")
	invalid=canonical(FarmSaveStore.snapshot(game));invalid.version=FarmSaveStore.VERSION+1
	check(FarmSaveSchema.normalize(invalid).is_empty(),"未知未来版本继续拒绝，不能降级覆盖未来存档")

func files_and_confirmation() -> void:
	Appearance.set_player_gender("female")
	var before: Dictionary=canonical(FarmSaveStore.snapshot(game));var path: String="user://appearance-test.json"
	check(FarmSaveStore.write(game,path) and FarmSaveStore.write(game,path),"女性主角与男性小京可写入完整v25主档及备份")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	check(FarmSaveStore.backup_before_new_game(path) and FileAccess.get_file_as_bytes(path+".before_new_game.bak")==bytes,"新开局前另存完整原字节，不覆盖现有主档")
	check(FarmSaveStore.backup_before_new_game(path) and FileAccess.get_file_as_bytes(path+".before_new_game.1.bak")==bytes and FileAccess.get_file_as_bytes(path+".before_new_game.bak")==bytes,"重复新开局备份使用不同文件名，唯一旧备份不被覆盖")
	game.set("awaiting_character_choice",true)
	check(not FarmSaveStore.write(game,path) and FileAccess.get_file_as_bytes(path)==bytes,"外观选择未确认期间任何写入入口都拒绝覆盖旧进度")
	game.set("awaiting_character_choice",false)
	Appearance.set_player_gender("male")
	var loaded: Dictionary=FarmSaveStore.read(path)
	check(FarmSaveStore.restore(game,loaded) and Appearance.gender("player")=="female" and Appearance.gender()=="male","保存读取恢复已确认外观，不使用节点初始化的默认男女")
	await frames(4)
	check(canonical(FarmSaveStore.snapshot(game))==before,"读回女主档逐字段保留原已婚住宅、钱物和其他进度")
	var corrupt:=FileAccess.open(path,FileAccess.WRITE);corrupt.store_string("interrupted appearance save");corrupt.close()
	check(FarmSaveStore.backup_before_new_game(path) and FileAccess.get_file_as_bytes(path+".before_new_game.2.bak")==bytes,"主档损坏时先保留有效备份原字节，仍不覆盖前两份备份")
	check(FarmSaveStore.read(path).appearance==CharacterAppearance.defaults("female"),"坏主档沿原.bak回退，保留已确认女性主角")
	var broken: String="user://appearance-invalid.json";corrupt=FileAccess.open(broken,FileAccess.WRITE);corrupt.store_string("no valid old game");corrupt.close()
	check(not FarmSaveStore.backup_before_new_game(broken) and not FileAccess.file_exists(broken+".before_new_game.bak"),"存在但完全无效的旧档不会被默认为可以安全覆盖")
	check(FarmSaveStore.backup_before_new_game("user://appearance-no-game.json"),"首次新开局没有旧档时无需生成伪备份")
