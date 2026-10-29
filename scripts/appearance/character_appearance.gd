class_name CharacterAppearance
extends Node
## 方案C的唯一外观选择。只记录显示身份，不保存第二份小京关系或玩法进度。
signal changed
const SCHEME: String="C"
const GENDERS: Array[String]=["male","female"]
const ROOT: String="res://assets/characters/scheme_c/"
const FIELDS: Array[String]=["scheme","player_gender","xiaojing_gender"]
var state: Dictionary=defaults()

static func opposite(gender: String) -> String:
	return "female" if gender=="male" else ("male" if gender=="female" else "")

static func defaults(player_gender: String="male") -> Dictionary:
	if player_gender not in GENDERS: return {}
	return {"scheme":SCHEME,"player_gender":player_gender,"xiaojing_gender":opposite(player_gender)}

static func validate(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size()!=FIELDS.size(): return false
	for key in FIELDS:
		if not raw.get(key) is String: return false
	return raw.scheme==SCHEME and raw.player_gender in GENDERS and raw.xiaojing_gender==opposite(raw.player_gender)

static func normalize(raw: Variant) -> Dictionary:
	# 唯一权威是合法的主角选择；缺失或错配的小京冗余字段只做局部修复。
	# 未知方案、主角非法或未来额外字段不能静默重建成默认档。
	if not raw is Dictionary or raw.get("scheme")!=SCHEME or not raw.get("player_gender") is String or raw.player_gender not in GENDERS: return {}
	for key in raw:
		if key not in FIELDS: return {}
	return defaults(str(raw.player_gender))

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(raw: Dictionary) -> bool:
	var selected:=normalize(raw)
	if selected.is_empty(): return false
	if selected!=state:
		state=selected;changed.emit()
	return true

func set_player_gender(gender: String) -> bool:
	var selected:=defaults(gender)
	if selected.is_empty(): return false
	return restore(selected)

static func preview_paths(player_gender: String) -> Dictionary:
	var selected:=defaults(player_gender)
	if selected.is_empty(): return {}
	var player: String="player_"+player_gender
	var companion: String="xiaojing_"+str(selected.xiaojing_gender)
	return {
		"scheme":SCHEME,"player_gender":player_gender,"xiaojing_gender":selected.xiaojing_gender,
		"player_variant":player,"xiaojing_variant":companion,
		"player_asset":ROOT+player+"/compact_32x48/spritesheet.png",
		"companion_asset":ROOT+companion+"/compact_32x48/spritesheet.png",
		"player_portrait":ROOT+player+"/portrait.png","companion_portrait":ROOT+companion+"/portrait.png",
		"player_standing":ROOT+player+"/standing.png","companion_standing":ROOT+companion+"/standing.png",
		"player_wedding":ROOT+player+"/compact_32x48/ceremony.png",
		"companion_wedding":ROOT+companion+"/compact_32x48/ceremony.png"
	}

static func preview_asset(gender: String, role: String="player", ceremony: bool=false) -> String:
	var paths:=preview_paths(gender)
	if paths.is_empty() or role not in ["player","xiaojing","companion"]: return ""
	return str(paths[("player_" if role=="player" else "companion_")+("wedding" if ceremony else "asset")])

static func preview_texture(gender: String, role: String="player", ceremony: bool=false) -> Texture2D:
	var path:=preview_asset(gender,role,ceremony)
	# 资源未接入时明确返回空，不把旧男主或女小京混作对应外观。
	return load(path) if path!="" and ResourceLoader.exists(path) else null

func player_variant() -> String: return str(preview_paths(str(state.player_gender)).player_variant)
func companion_variant() -> String: return str(preview_paths(str(state.player_gender)).xiaojing_variant)
func player_asset(ceremony: bool=false) -> String: return preview_asset(str(state.player_gender),"player",ceremony)
func companion_asset(ceremony: bool=false) -> String: return preview_asset(str(state.player_gender),"xiaojing",ceremony)
func portrait_asset(person: String="xiaojing") -> String:
	if person not in ["player","xiaojing","companion"]: return ""
	return str(preview_paths(str(state.player_gender))["player_portrait" if person=="player" else "companion_portrait"])
func standing_asset(person: String="xiaojing") -> String:
	if person not in ["player","xiaojing","companion"]: return ""
	return str(preview_paths(str(state.player_gender))["player_standing" if person=="player" else "companion_standing"])
func gender(person: String="xiaojing") -> String:
	if person=="player": return str(state.player_gender)
	return opposite(str(state.player_gender)) if person in ["xiaojing","companion"] else ""
func pronoun(person: String="xiaojing") -> String:
	var selected:=gender(person)
	return "她" if selected=="female" else ("他" if selected=="male" else "")
func spouse_title(person: String="xiaojing") -> String:
	var selected:=gender(person)
	return "妻子" if selected=="female" else ("丈夫" if selected=="male" else "爱人")
func resolve_text(text: String) -> String:
	# 只替换显式称谓token；绝不把林芽/阿禾等人物的“她”全局改成“他”。
	var terms: Dictionary={"{player_pronoun}":pronoun("player"),"{xiaojing_pronoun}":pronoun(),"{xiaojing_spouse}":spouse_title(),"{xiaojing_name}":"小京"}
	var result: String=text
	for key in terms: result=result.replace(key,str(terms[key]))
	return result
