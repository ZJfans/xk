extends Control
## Interactive 2.5D light/particle overlay for PlanetCrossSectionView.
## Reads the authoritative V4 mine state but never mutates it.

const CYAN := Color("58dfff")
const GOLD := Color("f4b666")
const PURPLE := Color("b88bff")
const GREEN := Color("73edb9")

var source: Control
var _clock: float = 0.0
var _events: Array[Dictionary] = []
var reduce_motion: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func pulse_event(command: String) -> void:
	_events.append({"kind": command, "age": 0.0})
	if _events.size() > 6:
		_events.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if source == null or not is_instance_valid(source) or not is_visible_in_tree():
		return
	_clock += minf(delta, 0.10)
	for i in range(_events.size() - 1, -1, -1):
		_events[i]["age"] = float(_events[i]["age"]) + delta
		if float(_events[i]["age"]) > 1.5:
			_events.remove_at(i)
	if not reduce_motion or not _events.is_empty():
		queue_redraw()

func _mineral_color(id: String) -> Color:
	match id:
		"silicon_crystal": return CYAN
		"energy_crystal": return PURPLE
		"phase_ore": return GOLD
		_: return Color("ef9f59")

func _draw() -> void:
	if source == null or not is_instance_valid(source):
		return
	var state: Variant = source.get("state")
	if state == null:
		return
	var v40: Dictionary = state.stats.get("v40", {})
	var mine_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	if mine.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	if w < 90.0 or h < 90.0:
		return
	var surf_y: float = clampf(h * 0.25, 78.0, 122.0)
	var px: float = w * 0.44
	var py: float = surf_y - 38.0
	var active: bool = str(mine.get("status", "running")) == "running"
	var platforms: int = int(mine.get("platforms", 0))
	var selected: int = int(source.get("selected_deposit_idx"))
	var revs: Array = mine.get("deposits", [])

	# Rack motors, warning beacons and a drive-shaft energy trace.
	if platforms > 0:
		var gain: float = 0.35 + 0.45 * (0.5 + 0.5 * sin(_clock * 8.0))
		draw_circle(Vector2(px, py), 19.0, Color(CYAN.r, CYAN.g, CYAN.b, gain * 0.13))
		for j in range(4):
			var lamp_y: float = surf_y - 45.0 + float(j) * 8.0
			var lamp_col: Color = GOLD if j % 2 == 0 else CYAN
			draw_circle(Vector2(px + 16.0, lamp_y), 1.7 + gain * 1.0, Color(lamp_col.r, lamp_col.g, lamp_col.b, 0.65 * gain))
		if active:
			var shaft_y: float = surf_y + 14.0 + fmod(_clock * 62.0, maxf(15.0, (h - surf_y) * 0.40))
			draw_line(Vector2(px - 2.0, surf_y), Vector2(px - 2.0, shaft_y), Color(CYAN.r, CYAN.g, CYAN.b, 0.25), 1.2)
			draw_circle(Vector2(px, shaft_y), 3.3, Color(CYAN.r, CYAN.g, CYAN.b, 0.66))

	for dep_index in range(revs.size()):
		var dep: Dictionary = revs[dep_index]
		var cx: float = clampf(float(dep.get("gx", 48)) / 96.0, 0.08, 0.92) * w
		var cy: float = surf_y + clampf(float(dep.get("gy", 20)) / 48.0, 0.12, 0.90) * (h - surf_y - 28.0)
		var pt := Vector2(cx, cy)
		var revealed: bool = bool(dep.get("revealed", false))
		var heads: int = int(dep.get("heads", 0))
		var col: Color = _mineral_color(str(dep.get("mineral_id", "")))
		if dep_index == selected:
			# Two animated targeting arcs; these respond to the player's actual selection.
			var ang: float = 0.0 if reduce_motion else _clock * 0.65
			var tc := Color(GOLD.r, GOLD.g, GOLD.b, 0.58)
			draw_arc(pt, 36.0, ang, ang + PI * 0.70, 25, tc, 2.3, true)
			draw_arc(pt, 36.0, ang + PI, ang + PI * 1.70, 25, tc, 2.3, true)
			draw_line(pt + Vector2(-45, 0), pt + Vector2(-31, 0), tc, 1.5)
			draw_line(pt + Vector2(31, 0), pt + Vector2(45, 0), tc, 1.5)
		if not revealed:
			var scan_a: float = fmod(_clock * 0.55 + float(dep_index) * 0.17, 1.0)
			draw_arc(pt, 20.0 + 28.0 * scan_a, -PI * 0.85, PI * 0.22, 27,
				Color(CYAN.r, CYAN.g, CYAN.b, (1.0 - scan_a) * 0.24), 1.4, true)
			continue
		if heads <= 0 or not active or int(dep.get("remaining_t", 0)) <= 0:
			continue
		# Laser extraction, moving ore glints and scatter sparks tied to active heads.
		var flicker: float = 0.72 + 0.28 * sin(_clock * 17.0 + float(dep_index) * 4.0)
		draw_circle(pt, 24.0, Color(col.r, col.g, col.b, 0.09 * flicker))
		draw_circle(pt, 10.0, Color(col.r, col.g, col.b, 0.15 * flicker))
		var spark_count: int = mini(11, 3 + heads * 2)
		for k in range(spark_count):
			var phi: float = float(k) * 2.3999 + float(dep_index)
			var motion: float = fmod(_clock * (0.8 + float(k % 3) * 0.22) + float(k) * 0.239, 1.0)
			var rad: float = 9.0 + motion * 24.0
			var spos: Vector2 = pt + Vector2(cos(phi), sin(phi)) * rad
			draw_circle(spos, 1.0 + (1.0 - motion) * 1.8, Color(col.r, col.g, col.b, (1.0 - motion) * 0.65))
		var flow: float = fmod(_clock * 0.36 + float(dep_index) * 0.33, 1.0)
		var source_pt: Vector2 = Vector2(px, surf_y)
		var flow_pt: Vector2 = pt.lerp(source_pt, flow)
		draw_circle(flow_pt, 2.4, Color(col.r, col.g, col.b, 0.55))

	# Transient commissioning / scanning effect when a command has actually succeeded.
	for ev in _events:
		var age: float = clampf(float(ev["age"]) / 1.5, 0.0, 1.0)
		var radius: float = (30.0 + age * 190.0)
		var event_col: Color = GOLD if str(ev["kind"]) != "ScanArea" else CYAN
		var origin: Vector2 = Vector2(px, surf_y) if str(ev["kind"]) == "BuildDrill" else Vector2(w * 0.5, h * 0.60)
		draw_arc(origin, radius, 0.0, TAU, 48, Color(event_col.r, event_col.g, event_col.b, (1.0 - age) * 0.65), 1.6, true)
