extends RefCounted
## Observes the original story assertions; never completes quests or mutates fixtures.
var suite: String
var started: bool=false
var events: Array[Dictionary]=[]
var female_categories: Dictionary={}
var visual_faults: Array[Dictionary]=[]
var unexpected_pair_losses: Array[Dictionary]=[]
var maximum_companion_sprites: int=0

func _init(suite_id: String) -> void:
	suite=suite_id

func categories(title: String) -> Array[String]:
	var result: Array[String]=[]
	if "记忆" in title or "收藏唯一" in title or "拓片" in title: result.append("memories")
	if "试炼" in title or "合约" in title or "制作链" in title: result.append("trials")
	if "婚礼" in title or "求婚" in title or "誓言" in title or "最终星灯仪式" in title or "最终确认一次消耗1314" in title: result.append("wedding")
	if "婚后" in title or "回信" in title or "两张桌" in title or "双水样" in title: result.append("postlife")
	if "519" in title and ("婚后" in title or "回信" in title): result.append("letter_519")
	if "520" in title and ("婚后" in title or "回信" in title or "当日可以读取" in title or "读档立即阅读" in title): result.append("letter_520")
	if "521" in title and ("回信" in title or "重复结算" in title): result.append("letter_521")
	return result

func legacy_title(title: String) -> bool:
	for phrase in ["旧", "迁移", "幂等", "损坏", "坏"]:
		if phrase in title: return true
	return false

func sprite_record(sprite: Sprite2D) -> Dictionary:
	if not is_instance_valid(sprite): return {"missing":true}
	return {"path":str(sprite.get_path()),"visible":sprite.is_visible_in_tree(),
		"variant":str(sprite.get_meta("appearance_variant","")),"scheme_c":bool(sprite.get_meta("scheme_c",false)),
		"texture":sprite.texture.resource_path if sprite.texture else "","frame":sprite.frame,
		"hframes":sprite.hframes,"vframes":sprite.vframes}

func observe(owner_test: Node, passed: bool, title: String) -> void:
	var labels: Array[String]=categories(title)
	if labels.is_empty() and legacy_title(title): labels.append("legacy_save_probe")
	if labels.is_empty() or not is_instance_valid(owner_test.game): return
	var game: Node=owner_test.game
	var current: Dictionary=Appearance.snapshot()
	var requested: bool=current.player_gender=="female" and current.xiaojing_gender=="male"
	var player: Dictionary=sprite_record(game.player.get_node_or_null("Sprite2D"))
	var companions: Array[Dictionary]=[]
	for person in owner_test.get_tree().get_nodes_in_group("xiaojing"):
		if not game.is_ancestor_of(person): continue
		for child in person.get_children():
			if child is Sprite2D: companions.append(sprite_record(child))
	maximum_companion_sprites=maxi(maximum_companion_sprites,companions.size())
	var matching: bool=player.get("scheme_c",false) and player.get("variant","")==Appearance.player_variant() and str(player.get("texture","")).contains("/"+Appearance.player_variant()+"/")
	for companion in companions:
		matching=matching and companion.scheme_c and companion.variant==Appearance.companion_variant() and str(companion.texture).contains("/"+Appearance.companion_variant()+"/")
	var sample: Dictionary={"assertion_index":owner_test.checked,"title":title,"assertion_passed":passed,"categories":labels,
		"appearance":current,"requested_female_pair_active":requested,"legacy_test":legacy_title(title),
		"player":player,"companion_sprites":companions,"all_visuals_match_current_pair":matching,
		"location":GameState.location,"day":GameClock.day,"save_version":FarmSaveStore.VERSION,
		"memory_count":Xiaojing.state.memories.size(),"trial_count":Xiaojing.state.trials.size(),
		"legend_trial_count":LegendState.state.trials.size(),"wedding_phase":StarStory.state.wedding_phase,
		"married":Xiaojing.state.married,"wedding_day":Xiaojing.state.wedding_day,"post_events":Xiaojing.state.post_events.duplicate()}
	events.append(sample)
	if not matching: visual_faults.append({"assertion_index":owner_test.checked,"title":title,"appearance":current,"player":player,"companions":companions})
	if not requested and not legacy_title(title): unexpected_pair_losses.append({"assertion_index":owner_test.checked,"title":title,"appearance":current})
	if requested:
		for label in labels: female_categories[label]=int(female_categories.get(label,0))+1

func validations(required: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	result.append({"ok":started,"text":"方案C女主/男小京深测成功选择女主："+suite})
	result.append({"ok":visual_faults.is_empty(),"text":"所有记录到的小京与主角精灵metadata及纹理均与实际外观一致："+suite})
	result.append({"ok":unexpected_pair_losses.is_empty(),"text":"除明确旧档迁移用例外，深层剧情始终保持女主/男小京："+suite})
	result.append({"ok":maximum_companion_sprites>=4,"text":"证据覆盖三图小京与独立温室小京四个精灵："+suite})
	for label in required:
		result.append({"ok":int(female_categories.get(label,0))>0,"text":"原真实断言确在女主/男小京下执行："+suite+" / "+str(label)})
	return result

func write_evidence(original_checks: int, original_failures: int, extra_checks: int, extra_failures: int) -> void:
	var record: Dictionary={"suite":suite,"requested_pair":{"player":"player_female","xiaojing":"xiaojing_male"},
		"source_assertions":original_checks,"source_failures":original_failures,"additional_evidence_checks":extra_checks,"additional_evidence_failures":extra_failures,
		"female_categories":female_categories,"maximum_companion_sprites":maximum_companion_sprites,
		"visual_faults":visual_faults,"unexpected_pair_losses":unexpected_pair_losses,"events":events,
		"note":"Original gameplay assertions run unchanged; evidence assertions are separately counted. Explicit legacy-save probes may legitimately restore the historical default pair."}
	var file:=FileAccess.open("res://builds/scheme-c-female-"+suite+"-evidence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"));file.close()
