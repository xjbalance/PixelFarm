extends Control
## 屏幕天气仅呈现。固定绘制预算、无动态光源、不捕获触点；玩法影响由GameWeather控制。
const INDOORS := ["home","mine_a","mine_b","mine_c","abyss","greenhouse","lake_ruins","old_temple"]
var time: float = 0
var accumulator: float = 0
var fade: float = 0
var banner_time: float = 0
var banner: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group("weather_screens")
	GameClock.changed.connect(queue_redraw)
	GameWeather.changed.connect(queue_redraw)
	Calendar.changed.connect(queue_redraw)
	Events.location_changed.connect(func(id: String):
		fade = 0.4
		banner_time = 2.6
		banner = "深渊第%d层 · %s" % [AbyssState.state.depth,AbyssState.layout().title] if id=="abyss" else Story.NAMES[id]
	)
	Story.chapter_completed.connect(func(_stage: int):
		banner_time = 3.2
		banner = Story.chapter().title
	)
	VillageProjects.built_project.connect(func(id: String):
		banner_time = 3.2
		banner = VillageProjects.definitions[id].name+" · 一起建成了"
	)

func _process(delta: float) -> void:
	var had_overlay: bool=fade>0 or banner_time>0
	# 钓鱼、对话等模态及后台暂停时，不积累粒子运行时间。
	if GameClock.running and not GameState.modal: time+=maxf(0,delta)
	accumulator += delta
	fade = maxf(0,fade-delta)
	banner_time = maxf(0,banner_time-delta)
	# 转场结束必须再清除一帧；室内或暂停时不能留下最后一层半透明遮罩。
	if had_overlay and fade<=0 and banner_time<=0:
		queue_redraw()
		accumulator=0
		return
	if not had_overlay and not animation_active():
		accumulator=0
		return
	if accumulator >= 0.05:
		accumulator = 0
		queue_redraw()

func animation_active() -> bool:
	if not GameClock.running or GameState.modal or GameState.location in INDOORS: return false
	var weather: String=GameWeather.weather_id()
	if weather in ["cloudy","rain","heavy_rain","storm","snow","blizzard","fog"]: return true
	if weather=="meteor": return GameWeather.is_meteor_night()
	return weather=="clear" and GameClock.minutes>=1140 and Calendar.season()!=3

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	if GameState.location not in INDOORS:
		var weather: String=GameWeather.weather_id()
		match weather:
			"cloudy":
				draw_rect(Rect2(Vector2.ZERO,size),Color(.45,.52,.57,.04))
				for i in range(5):
					var p := Vector2(fposmod(i*311-time*6,size.x+280)-280,float(i%3)*size.y/3)
					draw_rect(Rect2(p,Vector2(280,36)),Color(.78,.82,.81,.04))
			"rain","heavy_rain","storm": draw_rain(weather)
			"snow","blizzard": draw_snow(weather=="blizzard")
			"fog":
				draw_rect(Rect2(Vector2.ZERO,size),Color(.67,.75,.73,.12))
				for i in range(6):
					var p := Vector2(fposmod(i*263+time*7,size.x+440)-440,float(i)*size.y/6)
					draw_rect(Rect2(p,Vector2(440,64)),Color(.81,.85,.81,.07))
			"meteor":
				if GameWeather.is_meteor_night(): draw_meteors()
		if GameWeather.is_moon_night():
			var moon := Vector2(size.x-100,132)
			draw_circle(moon,27,Color(.78,.85,.91,.10));draw_circle(moon,18,Color("dedfca"))
			draw_rect(Rect2(moon+Vector2(-7,-9),Vector2(7,5)),Color("c2d0c6"))
			draw_rect(Rect2(moon+Vector2(4,5),Vector2(6,4)),Color("c2d0c6"))
		if weather in ["clear","cloudy"] and GameClock.minutes>=1140 and Calendar.season()!=3:
			for i in range(18):
				var p := Vector2(fposmod(i*183+sin(time*.4+i)*28,size.x),fposmod(i*101+cos(time*.6+i)*16,size.y))
				var alpha := (sin(time*1.4+i)+1)*0.16
				draw_rect(Rect2(p,Vector2(2,2)),Color(1,.85,.45,alpha))
	if fade > 0: draw_rect(Rect2(Vector2.ZERO,size),Color(.08,.16,.14,fade*1.6))
	if banner_time > 0 and not GameState.modal:
		var alpha := minf(banner_time,1.0)
		var rect := Rect2(size.x*.5-240,90,480,50)
		draw_rect(rect,Color(.12,.24,.20,alpha*.88))
		draw_line(rect.position+Vector2(24,48),rect.end-Vector2(24,2),Color(.85,.73,.47,alpha),1)
		draw_string(load("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),rect.position+Vector2(16,32),banner,HORIZONTAL_ALIGNMENT_CENTER,448,22,Color(.96,.87,.68,alpha))

func draw_rain(weather: String) -> void:
	var intensity: int={"rain":48,"heavy_rain":96,"storm":128}[weather]
	var speed: float=360.0 if weather=="rain" else 500.0
	draw_rect(Rect2(Vector2.ZERO,size),Color("55788b16") if weather=="rain" else Color("3e60732a"))
	for i in range(intensity):
		var p := Vector2(fposmod(i*163-time*70,size.x),fposmod(i*97+time*speed,size.y))
		draw_line(p,p+Vector2(-4,10 if weather=="rain" else 16),Color("c6d9dd55"),1)
	# Slow, faint illumination with no Light2D, noise, or strobing sequence.
	if weather=="storm":
		var phase: float=fposmod(time,14.0)
		if phase<.16: draw_rect(Rect2(Vector2.ZERO,size),Color(.74,.82,.85,(.16-phase)*.35))

func draw_snow(blizzard: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.71,.80,.82,.10 if blizzard else .035))
	for i in range(100 if blizzard else 56):
		var p := Vector2(fposmod(i*137+sin(time*.6+i)*12-time*(38 if blizzard else 8),size.x),fposmod(i*109+time*(86 if blizzard else 42),size.y))
		draw_rect(Rect2(p,Vector2(3,2) if i%3 else Vector2(2,3)),Color(.87,.92,.91,.65 if blizzard else .55))

func draw_meteors() -> void:
	for i in range(22):
		var p := Vector2(fposmod(i*197+48,size.x),fposmod(i*71+31,size.y*.55))
		draw_rect(Rect2(p,Vector2(2,2)),Color(.96,.88,.66,.35+.22*sin(time+i)))
	for i in range(2):
		var phase: float=fposmod(time+float(i)*4.2,9.0)
		if phase>1.2: continue
		var start := Vector2(size.x*(.35+.35*i),size.y*.08)
		var p := start+Vector2(-120,90)*phase
		draw_line(p,p+Vector2(28,-21),Color(.69,.83,.87,(1.2-phase)*.5),2)
		draw_rect(Rect2(p,Vector2(3,3)),Color("f4e5b8"))
