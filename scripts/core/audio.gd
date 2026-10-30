extends Node
## 多播放器避免快速操作切断上一声；所有提示音均为本项目生成。
var players: Array[AudioStreamPlayer] = []
var extra_channels: Array[AudioStreamPlayer] = []
var next_player: int = 0
var muted: bool = false
var music: AudioStreamPlayer
var rain: AudioStreamPlayer
var in_background: bool = false
var SOUNDS = {
	"action": load("res://assets/audio/action.wav"),
	"harvest": load("res://assets/audio/harvest.wav"),
	"day": load("res://assets/audio/day.wav")
}

func _ready() -> void:
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		players.append(player)
	Events.farm_action.connect(func(kind: String): play_sound("harvest" if kind == "收获" else "action"))
	GameClock.day_advanced.connect(func(): play_sound("day"))
	Events.resource_hit.connect(func(depleted: bool): play_sound("harvest" if depleted else "action"))
	Events.livestock_collected.connect(func(_site: String): play_sound("harvest"))
	music = loop_player(load("res://assets/audio/river_theme.wav"),-23.0)
	rain = loop_player(load("res://assets/audio/rain.wav"),-40.0)

func loop_player(source: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	# 无显示服务用于自动化规则测试，不启动常驻混音；实际窗口与 Android 正常循环。
	if DisplayServer.get_name() != "headless": player.play()
	return player

func _process(delta: float) -> void:
	for channel in extra_channels:
		if is_instance_valid(channel): channel.stream_paused=muted or in_background or GameState.location!="greenhouse"
	if not music or not rain: return
	music.stream_paused = muted or in_background or GameState.location=="greenhouse"
	rain.stream_paused = muted or in_background
	var rain_level := -24.0 if GameWeather.is_rainy() and GameState.location not in ["home","mine_a","mine_b","mine_c","abyss","greenhouse"] else -65.0
	rain.volume_db = move_toward(rain.volume_db,rain_level,delta*24)
	music.volume_db = move_toward(music.volume_db,-27.0 if GameState.modal else -23.0,delta*8)

func play_sound(id: String) -> void:
	if muted or in_background: return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = SOUNDS[id]
	player.play()

func stop_all() -> void:
	for channel in extra_channels:
		if is_instance_valid(channel): channel.stop()
	for player in players: player.stop()
	if music: music.stop()
	if rain: rain.stop()

func _exit_tree() -> void:
	stop_all()
	extra_channels.clear()
