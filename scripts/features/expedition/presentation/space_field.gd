extends Control
## Spatial UX mock: asteroid selection + drag probe from base dock to body.
## No domain write. Emits intention for expedition_screen to route through shell.
signal body_selected(body_id: String)
signal probe_dropped(body_id: String)
const UI = preload("res://scripts/ui/design_system.gd")
const BODIES := [
	{"id":"A-03","p":Vector2(0.28,0.32),"r":33.0,"t":"晶硅碎星"},
	{"id":"B-07","p":Vector2(0.67,0.25),"r":26.0,"t":"红岩小行星"},
	{"id":"C-12","p":Vector2(0.76,0.65),"r":41.0,"t":"冰质卫星"}
]
var selected_body: String = "A-03"
var drag_probe: bool = false
var cursor_pos: Vector2 = Vector2.ZERO
var phase: float = 0.0
var surveyed: bool = false
var deployed: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)

func _process(delta: float) -> void:
	if visible:
		phase += delta
		queue_redraw()

func _dock() -> Vector2:
	return Vector2(92.0, size.y - 94.0)

func _body_at(pos: Vector2) -> String:
	for entry in BODIES:
		var point: Vector2 = entry["p"] * size
		if pos.distance_to(point) < float(entry["r"]) + 24.0:
			return str(entry["id"])
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_pos = event.position
			if event.position.distance_to(_dock()) < 72.0:
				drag_probe = true
				accept_event()
			else:
				var body: String = _body_at(event.position)
				if body != "":
					selected_body = body
					body_selected.emit(body)
					accept_event()
		else:
			if drag_probe:
				drag_probe = false
				var body: String = _body_at(event.position)
				if body != "":
					selected_body = body
					probe_dropped.emit(body)
				accept_event()
	elif event is InputEventMouseMotion and drag_probe:
		cursor_pos = event.position
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("071321"))
	for i in range(110):
		var star: Vector2 = Vector2(float((i*197+29)%997)/997.0*size.x, float((i*263+71)%991)/991.0*size.y)
		var alpha: float = 0.20 + 0.23 * float(i%3) / 3.0
		draw_circle(star, 0.7 if i%5 else 1.3, Color(0.76,0.91,1.0,alpha))
	var font: Font = get_theme_default_font()
	var dock: Vector2 = _dock()
	draw_line(dock, Vector2(size.x*0.28,size.y*0.32),Color(0.25,0.65,0.80,0.16),1.0)
	draw_circle(dock, 35.0, Color(0.10,0.35,0.46,0.40))
	draw_circle(dock, 20.0, Color("3a8dab"))
	draw_string(font, dock + Vector2(-50,57), "探测器发射坞", HORIZONTAL_ALIGNMENT_LEFT,140,13,UI.TEXT)
	draw_string(font, Vector2(22,32), "可交互星域  /  拖动探测器发射坞到目标天体", HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.CYAN)
	for entry in BODIES:
		var p: Vector2 = entry["p"]*size
		var r: float = float(entry["r"])
		var is_selected: bool = selected_body == str(entry["id"])
		var c: Color = UI.CYAN if is_selected else UI.AMBER
		draw_circle(p,r+18.0,Color(c.r,c.g,c.b,0.09))
		draw_circle(p,r+7.0,Color(c.r,c.g,c.b,0.11))
		draw_circle(p,r,Color("294759") if is_selected else Color("655445"))
		draw_arc(p,r+11.0+sin(phase*2.0)*1.8,0.0,TAU,48,Color(c.r,c.g,c.b,0.75 if is_selected else 0.25),2.0)
		draw_string(font,p+Vector2(-62,r+28),str(entry["t"]),HORIZONTAL_ALIGNMENT_CENTER,125,13,UI.TEXT)
		if is_selected:
			draw_string(font,p+Vector2(-52,-r-20),"◆ 目标锁定",HORIZONTAL_ALIGNMENT_CENTER,108,12,UI.CYAN)
	if surveyed:
		var target := _body_at_position(selected_body)
		draw_arc(target,57.0+sin(phase*3.0)*3.0,0.0,TAU,64,Color(0.35,0.9,0.8,0.42),1.5)
	if deployed:
		var target := _body_at_position(selected_body)
		draw_circle(target+Vector2(18.0,-12.0),6.0+sin(phase*5.0),UI.GREEN)
		draw_line(dock,target,Color(0.33,0.85,0.65,0.52),2.0)
	if drag_probe:
		draw_line(dock,cursor_pos,UI.CYAN,2.5)
		draw_circle(cursor_pos,7.0,UI.CYAN)

func _body_at_position(body_id: String) -> Vector2:
	for entry in BODIES:
		if str(entry["id"]) == body_id:
			return entry["p"]*size
	return size*0.5
