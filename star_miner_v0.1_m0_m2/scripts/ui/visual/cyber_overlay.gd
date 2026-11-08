extends Control
## Noninteractive HUD ornament and brief action shockwaves.
## Deliberately low opacity so gameplay labels remain readable.

const CYAN := Color("40d9f5")
const GOLD := Color("f9b55a")
const RED := Color("f57a74")

var _clock: float = 0.0
var _rings: Array[Dictionary] = []
var reduce_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += minf(delta, 0.1)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i]["age"] = float(_rings[i]["age"]) + delta
		if float(_rings[i]["age"]) > 1.0:
			_rings.remove_at(i)
	if not reduce_motion or not _rings.is_empty():
		queue_redraw()

func impact(origin: Vector2, is_error: bool = false) -> void:
	if reduce_motion:
		return
	_rings.append({"pos": origin, "age": 0.0, "error": is_error})
	if _rings.size() > 8:
		_rings.pop_front()
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 20.0 or h < 20.0:
		return
	# Minimal industrial datum lines, rather than dense decorative sci-fi clutter.
	var edge := Color(0.20, 0.73, 0.83, 0.16)
	draw_line(Vector2(14, 80), Vector2(14, minf(h - 55.0, 190.0)), edge, 1.0)
	draw_line(Vector2(w - 14, maxf(82.0, h - 170.0)), Vector2(w - 14, h - 56.0), edge, 1.0)
	for corner in [Vector2(14, 84), Vector2(w - 14, h - 55)]:
		var sx: float = 1.0 if corner.x < w * 0.5 else -1.0
		var sy: float = 1.0 if corner.y < h * 0.5 else -1.0
		draw_line(corner, corner + Vector2(sx * 26, 0), Color(CYAN.r, CYAN.g, CYAN.b, 0.27), 1.5)
		draw_line(corner, corner + Vector2(0, sy * 18), Color(CYAN.r, CYAN.g, CYAN.b, 0.27), 1.5)
	# Pulse arcs are anchored to the user's operation, not to decorative random locations.
	for ring in _rings:
		var u: float = clampf(float(ring["age"]), 0.0, 1.0)
		var col: Color = RED if bool(ring["error"]) else GOLD
		col.a = (1.0 - u) * 0.65
		var center: Vector2 = ring["pos"]
		var rad: float = 18.0 + u * 100.0
		draw_arc(center, rad, -PI * 0.45, PI * 0.60, 38, col, 2.5, true)
		draw_arc(center, rad + 8.0, PI * 0.67, PI * 1.56, 38, col * Color(1, 1, 1, 0.6), 1.0, true)
