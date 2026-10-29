extends Node
## 仅debug且启用时记录本地试玩；不进入游戏存档，不读取个人/设备信息，不联网。
const DIRECTORY := "user://diagnostics"
const LOG := DIRECTORY+"/playtest.jsonl"
const SUMMARY := DIRECTORY+"/summary.json"
const LIMIT := 5*1024*1024
const EVENTS := ["session","loaded","background","day","plant","unlock","diamonds","relationship","task","trial_start","trial_fail","trial_cancel","trial_finish","mine_enter","mine_exit","rescue","wedding","navigation_fail","save"]
const FIELDS := ["source","id","delta","depth","day","plants","affection","trust","bond","reason","version","schema","mode","backup","segment","value"]
var enabled: bool=false
var game: Node
var buffer: Array[String]=[]
var last_tick: int=0
var flush_at: int=0
var session: String=""
var segment: int=0
var in_background: bool=false
var attempts: Dictionary={}
var failures: Dictionary={}
var summary: Dictionary={}
var lifetime_base: Dictionary={}
func defaults() -> Dictionary:
	return {"foreground_s":0.0,"active_s":0.0,"paused_s":0.0,"background_s":0.0,"days_advanced":0,"plants":0,"fatigue":0,"mine_entries":0,"mine_exits":0,"rescues":0,"trial_failures":0,"trial_starts":0,"trial_retries":0,"areas_s":{},"floors_s":{},"diamonds":{},"relationships":{},"milestones":{},"last_day":0}
func _ready() -> void:
	summary=defaults();last_tick=Time.get_ticks_usec()
	if not OS.is_debug_build():
		set_process(false)
		return
	var preference := true
	var path := DIRECTORY+"/settings.json"
	if FileAccess.file_exists(path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("enabled") is bool: preference=parsed.enabled
	if preference and DisplayServer.get_name()!="headless" and "--no-diagnostics" not in OS.get_cmdline_user_args(): start()
func bind(owner_game: Node) -> void: game=owner_game
func start() -> bool:
	if not OS.is_debug_build(): return false
	if enabled: return true
	if DirAccess.make_dir_recursive_absolute(DIRECTORY)!=OK: return false
	summary=defaults()
	lifetime_base=defaults()
	if FileAccess.file_exists(SUMMARY):
		var old=JSON.parse_string(FileAccess.get_file_as_string(SUMMARY))
		if old is Dictionary and old.get("lifetime") is Dictionary: lifetime_base=combine(defaults(),old.lifetime)
		if old is Dictionary and old.get("failure_keys") is Array:
			for id in old.failure_keys:
				if id is String and id.length()<160: failures[id]=true
		if old is Dictionary and old.get("attempts") is Array:
			for id in old.attempts:
				if id is String and id.length()<96: attempts[id]=true
	enabled=true;segment=0;session=Crypto.new().generate_random_bytes(8).hex_encode();last_tick=Time.get_ticks_usec();flush_at=last_tick
	record("session",{"version":ProjectSettings.get_setting("application/config/version"),"schema":FarmSaveStore.VERSION})
	return true
func toggle() -> void:
	if not OS.is_debug_build(): return
	if enabled: flush();enabled=false
	else: start()
	var file := FileAccess.open(DIRECTORY+"/settings.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"enabled":enabled}));file.close()
func record(kind: String, details: Dictionary = {}) -> void:
	if not enabled or not OS.is_debug_build() or kind not in EVENTS: return
	var safe := {}
	for key in details:
		if key not in FIELDS: continue
		var value=details[key]
		if value is String: safe[key]=value.left(96)
		elif value is bool or value is int or (value is float and is_finite(value)): safe[key]=value
	var row := {"event":kind,"session":session,"segment":segment,"active_s":snappedf(float(summary.active_s),.001),"foreground_s":snappedf(float(summary.foreground_s),.001),"game_day":GameClock.day,"minute":snappedf(GameClock.minutes,.01),"data":safe}
	buffer.append(JSON.stringify(row))
	summary.last_day=GameClock.day
	match kind:
		"day": summary.days_advanced+=1;summary.fatigue+=1 if safe.get("reason")=="fatigue" else 0
		"plant": summary.plants+=1
		"mine_enter": summary.mine_entries+=1
		"mine_exit": summary.mine_exits+=1
		"rescue": summary.rescues+=1
		"trial_fail": summary.trial_failures+=1
		"trial_start":
			failures.clear()
			summary.trial_starts+=1
			var id: String=safe.get("id","")
			if attempts.has(id): summary.trial_retries+=1
			attempts[id]=true
		"diamonds": add(summary.diamonds,str(safe.get("source","unknown")),float(safe.get("delta",0)))
		"relationship":
			var source: String=safe.get("source","unknown")
			if not summary.relationships.has(source): summary.relationships[source]={"affection":0,"trust":0,"bond":0}
			for key in ["affection","trust","bond"]: summary.relationships[source][key]+=int(safe.get(key,0))
		"task","unlock","wedding","trial_finish":
			var key := "%s:%d:%s:%s" % [session,segment,kind,safe.get("id",kind)]
			if not summary.milestones.has(key): summary.milestones[key]=float(lifetime_base.get("active_s",0))+float(row.active_s)
	if buffer.size()>=64: flush()
func add(target: Dictionary, key: String, amount: float) -> void:
	target[key]=float(target.get(key,0))+amount
func loaded() -> void:
	if not enabled: return
	segment+=1
	record("loaded",{"plants":Xiaojing.state.plants,"affection":Xiaojing.state.affection,"trust":Xiaojing.state.trust,"bond":Xiaojing.state.bond,"mode":GameState.control_mode})
func account(seconds: float, background: bool, paused: bool, floor_id: int = 0, area: String = "") -> void:
	if not enabled or not OS.is_debug_build() or seconds<0 or not is_finite(seconds): return
	if background: summary.background_s+=seconds;return
	summary.foreground_s+=seconds
	if paused: summary.paused_s+=seconds
	else:
		summary.active_s+=seconds
		if floor_id>0: add(summary.floors_s,str(floor_id),seconds)
		if area!="": add(summary.areas_s,area,seconds)
func sample_time() -> void:
	var now: int=Time.get_ticks_usec()
	var seconds: float=float(now-last_tick)/1000000.0
	last_tick=now
	if not enabled or not is_instance_valid(game): return
	account(seconds,in_background or game.backgrounded,GameState.modal or not GameClock.running,int(AbyssState.state.depth) if GameState.location=="abyss" else 0,GameState.location)
func _process(_delta: float) -> void:
	sample_time()
	var now: int=Time.get_ticks_usec()
	if enabled and now-flush_at>=5000000: flush();flush_at=now
func trial_failure(id: String, reason: String) -> void:
	if not enabled or reason=="": return
	var key := "%s:%s" % [id,reason]
	if failures.has(key): return
	failures[key]=true;record("trial_fail",{"id":id,"reason":reason})
func flush() -> bool:
	if not enabled or not OS.is_debug_build(): return false
	var file: FileAccess
	if FileAccess.file_exists(LOG):
		file=FileAccess.open(LOG,FileAccess.READ_WRITE)
		if file and file.get_length()>LIMIT:
			file.close()
			if FileAccess.file_exists(LOG+".previous"): DirAccess.remove_absolute(LOG+".previous")
			if DirAccess.rename_absolute(LOG,LOG+".previous")!=OK: return false
			file=FileAccess.open(LOG,FileAccess.WRITE)
	else: file=FileAccess.open(LOG,FileAccess.WRITE)
	if not file: return false
	file.seek_end()
	file.store_line(JSON.stringify({"event":"time","session":session,"segment":segment,"active_s":summary.active_s,"foreground_s":summary.foreground_s,"paused_s":summary.paused_s,"background_s":summary.background_s}))
	for row in buffer: file.store_line(row)
	file.flush();var ok: bool=file.get_error()==OK;file.close()
	if not ok: return false
	buffer.clear()
	var out := FileAccess.open(SUMMARY+".tmp",FileAccess.WRITE)
	if not out: return false
	var report := summary.duplicate(true)
	report.session=session;report.lifetime=combine(lifetime_base,summary);report.attempts=attempts.keys();report.failure_keys=failures.keys()
	out.store_string(JSON.stringify(report,"\t"));out.flush();ok=out.get_error()==OK;out.close()
	return ok and DirAccess.rename_absolute(SUMMARY+".tmp",SUMMARY)==OK
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		sample_time();in_background=true;flush()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		sample_time();in_background=false
	elif what==NOTIFICATION_WM_CLOSE_REQUEST: sample_time();flush()
func _exit_tree() -> void: flush()

func combine(base: Dictionary, current: Dictionary) -> Dictionary:
	# 诊断侧文件损坏不影响游戏；只吸收有界、有限的已知数值。
	var result := base.duplicate(true)
	for key in defaults():
		var value=current.get(key)
		if defaults()[key] is Dictionary:
			if not value is Dictionary or value.size()>5000: continue
			for id in value:
				if not id is String or id.length()>160: continue
				var v=value[id]
				if key=="relationships":
					if not v is Dictionary: continue
					if not result[key].has(id): result[key][id]={"affection":0,"trust":0,"bond":0}
					for attr in ["affection","trust","bond"]:
						if v.get(attr) is int or v.get(attr) is float:
							if is_finite(float(v[attr])): result[key][id][attr]+=float(v[attr])
				elif v is int or v is float:
					if not is_finite(float(v)): continue
					if key=="milestones": result[key][id]=v
					else: add(result[key],id,float(v))
		elif value is int or value is float:
			if not is_finite(float(value)) or value<0: continue
			result[key]=value if key=="last_day" else float(result[key])+float(value)
	return result
