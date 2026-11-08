extends Control
## Full-screen eight-second 2.5D transport-launch presentation.
## Visual only: the actual dispatch has already been accepted by V40DawnEngine.
## Press Esc or click to skip. No fake physical telemetry is presented as simulation data.

signal cinematic_finished

const BACKDROP = preload("res://assets/custom/bg_launch_sunset_clean.png")
const CYAN := Color("50ddfa")
const GOLD := Color("ffbc66")
const WHITE := Color("eaf7ff")
const RED := Color("ff7866")
const LENGTH: float = 8.4

var elapsed: float = 0.0
var mine_name: String = "晨曦一号矿区"
var _running: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)

func play_launch(from_mine: String) -> void:
	mine_name = from_mine
	elapsed = 0.0
	_running = true
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _running:
		return
	elapsed += minf(delta, 0.15)
	queue_redraw()
	if elapsed >= LENGTH:
		finish()

func finish() -> void:
	if not _running:
		return
	_running = false
	visible = false
	set_process(false)
	cinematic_finished.emit()

func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		finish()
		get_viewport().set_input_as_handled()

func _cover_image(tex: Texture2D, dest: Rect2) -> void:
	var source: Vector2 = tex.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale: float = maxf(dest.size.x / source.x, dest.size.y / source.y)
	var visible_src: Vector2 = dest.size / scale
	var rect := Rect2((source - visible_src) * 0.5, visible_src)
	draw_texture_rect_region(tex, dest, rect)

func _draw() -> void:
	if not _running:
		return
	var w: float = size.x
	var h: float = size.y
	if w < 120.0 or h < 120.0:
		return
	var t: float = elapsed
	var ignition: float = clampf((t - 1.1) / 1.3, 0.0, 1.0)
	var ascent: float = clampf((t - 2.2) / 3.5, 0.0, 1.0)
	ascent = ascent * ascent * (3.0 - 2.0 * ascent)
	var orbital: float = clampf((t - 5.5) / 2.0, 0.0, 1.0)
	var fade_in: float = clampf(t / 0.35, 0.0, 1.0)
	var font: Font = get_theme_default_font()
	var is_large: bool = w >= 1000.0
	var shake: Vector2 = Vector2.ZERO
	if t > 1.2 and t < 4.5:
		var power: float = ignition * (1.0 - clampf((t - 3.0) / 1.5, 0.0, 1.0))
		shake = Vector2(sin(t * 78.0) * 3.0, cos(t * 67.0) * 2.0) * power

	# Scene background (project-owned image) with cold, extraterrestrial grade.
	draw_rect(Rect2(Vector2.ZERO, size), Color("07101f"))
	if orbital < 0.98:
		_cover_image(BACKDROP, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.10, 0.56))
	for y in range(0, 24):
		var fy: float = float(y) / 24.0
		var upper_col := Color(0.005, 0.016, 0.048, (1.0 - fy) * 0.50 + orbital * 0.45)
		draw_rect(Rect2(0.0, fy * h, w, h / 24.0 + 1.0), upper_col)
	for s in range(90):
		var sx: float = float((s * 173 + 71) % 991) / 991.0 * w
		var sy: float = float((s * 311 + 19) % 997) / 997.0 * h * 0.78
		var star_alpha: float = 0.10 + orbital * 0.85
		draw_circle(Vector2(sx, sy), 1.0 if s % 3 != 0 else 1.7, Color(0.62, 0.84, 1.0, star_alpha))

	# Landing field, support towers, warning beacons and industrial mast.
	var ground_y: float = h * 0.84
	if orbital < 0.8:
		draw_rect(Rect2(0.0, ground_y, w, h - ground_y), Color(0.024, 0.052, 0.075, 0.88))
		draw_line(Vector2(0.0, ground_y), Vector2(w, ground_y), Color("64c8e5"), 2.0)
		for k in range(7):
			var bx: float = float(k) / 6.0 * w
			var by: float = ground_y - (18.0 + float((k * 29) % 75))
			draw_rect(Rect2(bx, by, 14, ground_y - by), Color("102333"))
			draw_line(Vector2(bx + 7, by), Vector2(bx + 7, by - 9), Color("749baa"), 1.0)
			if fmod(t + float(k) * 0.3, 1.2) < 0.65:
				draw_circle(Vector2(bx + 7, by - 8), 2.8, RED)
		var tower_x: float = w * 0.64
		draw_rect(Rect2(tower_x - 105, ground_y - h * 0.35, 8, h * 0.35), Color("566d7b"))
		for rail in range(5):
			var yy: float = ground_y - h * (0.06 + float(rail) * 0.055)
			draw_line(Vector2(tower_x - 105.0, yy), Vector2(tower_x - 60.0, yy + 9.0), Color("83a5b0"), 2.0)
		# Vapor release, rolling clouds, ring blast and particulate ejecta.
		if t > 0.8:
			for i in range(32):
				var seed: float = float(i)
				var age: float = fmod(t * (0.18 + 0.03 * float(i % 3)) + seed * 0.13, 1.0)
				var spread: float = 16.0 + 175.0 * age * maxf(0.45, ignition)
				var cx: float = tower_x + sin(seed * 2.4) * spread * (1.0 + age)
				var cy: float = ground_y - 2.0 - (12.0 + age * 90.0) * (0.4 + ignition)
				var smoke_alpha: float = (1.0 - age) * (0.10 + ignition * 0.15) * (1.0 - orbital)
				draw_circle(Vector2(cx, cy), 10.0 + age * 52.0, Color(0.46, 0.67, 0.73, smoke_alpha))

	var rocket_x: float = w * 0.64 + shake.x
	var rocket_height: float = minf(h * 0.46, 340.0)
	var rocket_width: float = rocket_height * 0.15
	var rocket_y: float = ground_y - rocket_height * 0.72 - ascent * h * 1.18 + shake.y
	var rocket_scale: float = 1.0 - 0.34 * orbital
	var rocket_len: float = rocket_height * rocket_scale
	var base: float = rocket_y + rocket_len * 0.48
	if ascent < 0.95 or t < 6.4:
		# Main engine plume: layered radiation, shock diamonds and luminous core.
		if ignition > 0.01:
			var plume: float = (20.0 + 175.0 * ignition) * (1.0 + 0.14 * sin(t * 32.0))
			var flare_spread: float = rocket_width * (0.4 + 1.4 * ignition)
			for j in range(5, 0, -1):
				var jf: float = float(j) / 5.0
				var flare_col: Color = Color(1.0, 0.32 + (1.0 - jf) * 0.6, 0.07 + (1.0 - jf) * 0.65, 0.13 + (1.0 - jf) * 0.55)
				var vv := PackedVector2Array([
					Vector2(rocket_x - rocket_width * 0.34, base),
					Vector2(rocket_x + rocket_width * 0.34, base),
					Vector2(rocket_x + flare_spread * jf, base + plume * jf),
					Vector2(rocket_x + sin(t * 25.0) * rocket_width * 0.3, base + plume * (1.3 - jf * 0.16)),
					Vector2(rocket_x - flare_spread * jf, base + plume * jf)
				])
				draw_colored_polygon(vv, flare_col)
			for i in range(24):
				var fi: float = float(i)
				var drift: float = fmod(t * (1.8 + 0.09 * float(i % 5)) + fi * 0.17, 1.0)
				var sxp: float = rocket_x + sin(fi * 4.2) * drift * flare_spread * 2.8
				var syp: float = base + 12.0 + plume * drift * 1.4
				draw_circle(Vector2(sxp, syp), 0.9 + 2.8 * (1.0 - drift), Color(1.0, 0.61, 0.14, (1.0 - drift) * 0.78))
		# Physically legible rocket silhouette, fins, tank seams, nose and gantry lighting.
		var left: float = rocket_x - rocket_width * 0.5
		var top: float = rocket_y - rocket_len * 0.52
		draw_rect(Rect2(left, top + rocket_len * 0.13, rocket_width, rocket_len * 0.87), Color("d0dce5"))
		draw_rect(Rect2(left + rocket_width * 0.14, top + rocket_len * 0.13, rocket_width * 0.12, rocket_len * 0.87), Color("7995a9"))
		draw_rect(Rect2(left + rocket_width * 0.75, top + rocket_len * 0.13, rocket_width * 0.08, rocket_len * 0.87), Color("faf3df"))
		draw_colored_polygon(PackedVector2Array([Vector2(left, top + rocket_len * 0.15), Vector2(rocket_x, top - rocket_len * 0.05), Vector2(left + rocket_width, top + rocket_len * 0.15)]), Color("f1f2e8"))
		draw_rect(Rect2(left, top + rocket_len * 0.28, rocket_width, rocket_len * 0.055), Color("1b344b"))
		draw_rect(Rect2(left, top + rocket_len * 0.68, rocket_width, rocket_len * 0.065), Color("283a4c"))
		draw_rect(Rect2(left - rocket_width * 0.19, top + rocket_len * 0.82, rocket_width * 0.22, rocket_len * 0.14), Color("8c9da9"))
		draw_rect(Rect2(left + rocket_width * 0.97, top + rocket_len * 0.82, rocket_width * 0.22, rocket_len * 0.14), Color("8c9da9"))
		for slit in range(3):
			draw_rect(Rect2(left + rocket_width * 0.10, top + rocket_len * (0.40 + float(slit) * 0.06), rocket_width * 0.20, 2.0), CYAN)

	# Dynamic frame, mission phase badges and industrial timecode.
	draw_rect(Rect2(0.0, 0.0, w, 84.0), Color(0.015, 0.035, 0.062, 0.82))
	draw_line(Vector2(0, 84), Vector2(w, 84), Color(CYAN.r, CYAN.g, CYAN.b, 0.65), 1.5)
	var phase: String = "发射授权 / PRE-LAUNCH"
	if t >= 1.1: phase = "点火与增压 / IGNITION"
	if t >= 2.2: phase = "动力升空 / ASCENT"
	if t >= 5.5: phase = "轨道交会 / ORBITAL TRANSFER"
	if t >= 7.0: phase = "调度成功 / DISPATCH CONFIRMED"
	var headline: String = "ROCKET PROSPECTORS  //  深空物流发射"
	draw_string(font, Vector2(32, 32), headline, HORIZONTAL_ALIGNMENT_LEFT, w - 64.0, 23 if is_large else 17, WHITE)
	draw_string(font, Vector2(32, 58), phase, HORIZONTAL_ALIGNMENT_LEFT, w - 64.0, 13, CYAN if t < 7.0 else GOLD)
	var countdown: String = "T - %02d" % maxi(0, int(3.0 - t)) if t < 2.2 else "T + %04.1f" % maxf(0.0, t - 2.2)
	draw_string(font, Vector2(w - 210.0, 54), countdown, HORIZONTAL_ALIGNMENT_LEFT, 180, 25, GOLD)

	var plate: Rect2 = Rect2(32, h - 118, minf(w * 0.55, 650.0), 92)
	draw_rect(plate, Color(0.01, 0.05, 0.09, 0.87))
	draw_rect(plate, Color(CYAN.r, CYAN.g, CYAN.b, 0.5), false, 1.0)
	draw_rect(Rect2(plate.position, Vector2(3.0, plate.size.y)), GOLD)
	draw_string(font, plate.position + Vector2(16, 29), mine_name + "   /   晨曦贸易港", HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 32, 16, WHITE)
	draw_string(font, plate.position + Vector2(16, 59), "运输调度演出 · 实际成本与交付以集团账本为准", HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 32, 12, Color("a7c8da"))
	var bar_y: float = h - 11.0
	draw_rect(Rect2(0.0, bar_y, w, 3.0), Color(0.12, 0.24, 0.35, 0.9))
	draw_rect(Rect2(0.0, bar_y, w * clampf(t / LENGTH, 0.0, 1.0), 3.0), GOLD)
	draw_string(font, Vector2(w - 164, h - 25), "点击 / ESC 跳过", HORIZONTAL_ALIGNMENT_LEFT, 155, 12, Color("acc8d7"))
	# Crossfade bright orbital transition, but keep it below the text HUD in draw order.
	if orbital > 0.12 and orbital < 0.95:
		var sweep: float = sin((orbital - 0.12) / 0.83 * PI)
		draw_rect(Rect2(w * 0.48, h * 0.13, 2.0, h * 0.66), Color(CYAN.r, CYAN.g, CYAN.b, sweep * 0.19))
