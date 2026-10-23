extends Control
## 屏幕气氛层只负责呈现；没有鼠标捕获，不影响双指操作或世界碰撞。
var time: float = 0
var accumulator: float = 0
var fade: float = 0
var banner_time: float = 0
var banner: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	Events.location_changed.connect(func(id: String):
		fade = 0.4
		banner_time = 2.6
		banner = Story.NAMES[id]
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
	time += delta
	accumulator += delta
	fade = maxf(0,fade-delta)
	banner_time = maxf(0,banner_time-delta)
	if accumulator >= 0.05:
		accumulator = 0
		queue_redraw()

func _draw() -> void:
	if GameState.location != "home":
		if GameWeather.is_rainy():
			draw_rect(Rect2(Vector2.ZERO,size),Color("55788b16"))
			for i in range(100):
				var p := Vector2(fposmod(i*163-time*70,size.x),fposmod(i*97+time*420,size.y))
				draw_line(p,p+Vector2(-4,13),Color("c6d9dd55"),1.5)
		elif GameClock.minutes >= 1140:
			for i in range(22):
				var p := Vector2(fposmod(i*183+sin(time*.4+i)*28,size.x),fposmod(i*101+cos(time*.6+i)*16,size.y))
				var alpha := (sin(time*1.4+i)+1)*0.16
				draw_circle(p,5,Color(1,.85,.4,alpha*.18))
				draw_rect(Rect2(p,Vector2(2,2)),Color(1,.85,.45,alpha))
	if fade > 0: draw_rect(Rect2(Vector2.ZERO,size),Color(.08,.16,.14,fade*1.6))
	if banner_time > 0 and not GameState.modal:
		var alpha := minf(banner_time,1.0)
		var rect := Rect2(size.x*.5-240,90,480,50)
		draw_rect(rect,Color(.12,.24,.20,alpha*.88))
		draw_line(rect.position+Vector2(24,48),rect.end-Vector2(24,2),Color(.85,.73,.47,alpha),1)
		draw_string(preload("res://assets/ui/fonts/NotoSansCJK-Regular.ttc"),rect.position+Vector2(16,32),banner,HORIZONTAL_ALIGNMENT_CENTER,448,22,Color(.96,.87,.68,alpha))
