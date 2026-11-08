class_name V40GalaxyMapView
extends Control

## V4-only star map. Economic objects come exclusively from state.stats["v40"]["mines"].
## Positions below are VIEW coordinates, not a second gameplay dataset.
## The legacy StarMapView is kept exclusively for classic challenge campaigns.

signal mine_selected(mine_id: String)
signal mine_activated(mine_id: String)

const MINE_POINTS: Dictionary = {
	"dawn_1": Vector2(0.14, 0.32),
	"dawn_2": Vector2(0.30, 0.44),
	"crimson_1": Vector2(0.46, 0.25),
	"frost_1": Vector2(0.60, 0.55),
	"molten_1": Vector2(0.76, 0.32),
	"glimmer_1": Vector2(0.87, 0.69),
}

const INK := Color("e7f1f7")
const MUTED := Color("9caebc")
const CYAN := Color("4cc9dc")
const GOLD := Color("f0b965")
const GREEN := Color("7bc4a4")
const BG := Color("08131f")

var state: GameState
var selected_mine_id: String = "dawn_1"
var hovered_mine_id: String = ""
var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(400, 260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_text = "左键选择矿区；双击已拥有的矿区进入矿场；滚轮缩放，右键拖动平移。"


func _mines() -> Dictionary:
	if state == null:
		return {}
	var v40: Variant = state.stats.get("v40", {})
	if not (v40 is Dictionary):
		return {}
	var mines: Variant = v40.get("mines", {})
	return mines if mines is Dictionary else {}


func _mine_point(mine_id: String, ordinal: int) -> Vector2:
	if MINE_POINTS.has(mine_id):
		return MINE_POINTS[mine_id]
	# Future generated mines can provide their own normalized position.
	var m: Dictionary = _mines().get(mine_id, {})
	var position: Variant = m.get("map_position", null)
	if position is Array and position.size() == 2:
		return Vector2(clampf(float(position[0]), 0.05, 0.95), clampf(float(position[1]), 0.05, 0.95))
	return Vector2(0.12 + float(ordinal % 5) * 0.18, 0.22 + float(ordinal / 5) * 0.22)


func _map_rect() -> Rect2:
	return Rect2(Vector2(48.0, 34.0), Vector2(maxf(140.0, size.x - 96.0), maxf(100.0, size.y - 150.0)))


func get_mine_screen_position(mine_id: String) -> Vector2:
	var mines: Dictionary = _mines()
	if not mines.has(mine_id):
		return Vector2(-9999.0, -9999.0)
	var ids: Array = mines.keys()
	ids.sort()
	var point: Vector2 = _mine_point(mine_id, ids.find(mine_id))
	return _world_to_screen(point)


func _world_to_screen(point: Vector2) -> Vector2:
	var rect: Rect2 = _map_rect()
	var raw: Vector2 = rect.position + point * rect.size
	var center: Vector2 = rect.get_center()
	return center + (raw - center) * map_zoom + map_offset


func pick_mine_at(position: Vector2) -> String:
	var mines: Dictionary = _mines()
	var nearest: String = ""
	var distance: float = 32.0
	for mine_id in mines:
		var pos: Vector2 = get_mine_screen_position(str(mine_id))
		var d: float = pos.distance_to(position)
		if d < distance:
			distance = d
			nearest = str(mine_id)
	return nearest


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old_zoom: float = map_zoom
			map_zoom = clampf(map_zoom * (1.12 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.7, 2.2)
			map_offset = button.position - (button.position - map_offset - _map_rect().get_center()) * (map_zoom / old_zoom) - _map_rect().get_center()
			queue_redraw()
			accept_event()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var mine_id: String = pick_mine_at(button.position)
			if mine_id != "":
				selected_mine_id = mine_id
				mine_selected.emit(mine_id)
				if button.double_click and bool(_mines()[mine_id].get("license_owned", false)):
					mine_activated.emit(mine_id)
				queue_redraw()
				accept_event()
			return
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			map_offset += motion.relative
			queue_redraw()
			accept_event()
			return
		var next_hover: String = pick_mine_at(motion.position)
		if next_hover != hovered_mine_id:
			hovered_mine_id = next_hover
			if next_hover != "":
				var mine: Dictionary = _mines().get(next_hover, {})
				tooltip_text = "%s | %s | 预计储量 %d–%d t" % [str(mine.get("name_zh", next_hover)), "已拥有" if bool(mine.get("license_owned", false)) else "待获取许可", int(mine.get("estimate_min_t", 0)), int(mine.get("estimate_max_t", 0))]
			else:
				tooltip_text = "左键选择；双击已拥有矿区进入；滚轮缩放，右键拖动。"
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Deterministic light background; no per-frame random allocation or animation.
	for i in range(85):
		var px: float = float((i * 173 + 41) % 997) / 997.0 * size.x
		var py: float = float((i * 311 + 67) % 991) / 991.0 * size.y
		draw_circle(Vector2(px, py), 0.7 if i % 3 else 1.1, Color(0.68, 0.81, 0.94, 0.35))
	var mines: Dictionary = _mines()
	var font: Font = get_theme_default_font()
	if mines.is_empty():
		draw_string(font, Vector2(22, 42), "暂无 V4 矿区数据", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
		return
	var port_pos: Vector2 = _world_to_screen(Vector2(0.05, 0.80))
	draw_circle(port_pos, 10.0, CYAN)
	draw_arc(port_pos, 16.0, 0.0, TAU, 32, CYAN, 1.5)
	draw_string(font, port_pos + Vector2(14, 4), "晨曦贸易港", HORIZONTAL_ALIGNMENT_LEFT, 130, 12, CYAN)
	for mine_id in mines:
		var m: Dictionary = mines[mine_id]
		var target: Vector2 = get_mine_screen_position(str(mine_id))
		var owned: bool = bool(m.get("license_owned", false))
		var selected: bool = str(mine_id) == selected_mine_id
		var hovered: bool = str(mine_id) == hovered_mine_id
		var color: Color = _cluster_color(str(m.get("cluster_id", "")))
		var radius: float = 17.0 if owned else 13.0
		var route_color: Color = Color(CYAN.r, CYAN.g, CYAN.b, 0.35 if owned else 0.13)
		draw_line(port_pos, target, route_color, 1.5)
		draw_circle(target, radius + 5.0, Color(color.r, color.g, color.b, 0.14))
		draw_circle(target, radius, color.darkened(0.30))
		draw_arc(target, radius, PI * 0.35, PI * 1.35, 30, color.lightened(0.25), 2.0)
		if selected or hovered:
			draw_arc(target, radius + 9.0, 0.0, TAU, 42, GOLD if selected else CYAN, 2.0)
		var label: String = str(m.get("name_zh", mine_id))
		draw_string(font, target + Vector2(-80, radius + 20), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, INK if owned else MUTED)
		var status: String = "%dt 库存" % int(m.get("silo_stock_t", 0)) if owned else "待许可"
		draw_string(font, target + Vector2(-62, radius + 35), status, HORIZONTAL_ALIGNMENT_CENTER, 124, 11, GREEN if owned else MUTED)
	var selected_mine: Dictionary = mines.get(selected_mine_id, {})
	if not selected_mine.is_empty():
		var info_rect: Rect2 = Rect2(Vector2(12, size.y - 74), Vector2(maxf(100.0, size.x - 24), 64))
		draw_rect(info_rect, Color(0.04, 0.10, 0.16, 0.95))
		var line1: String = "%s  ·  %s  ·  航程 L=%.1f" % [str(selected_mine.get("name_zh", selected_mine_id)), str(selected_mine.get("cluster_name_zh", "未知星团")), float(selected_mine.get("distance_l", 0.0))]
		var line2: String = "已拥有 · 双击进入矿场" if bool(selected_mine.get("license_owned", false)) else "尚未取得许可 · 使用下方矿区卡片勘探或购买"
		draw_string(font, info_rect.position + Vector2(12, 24), line1, HORIZONTAL_ALIGNMENT_LEFT, info_rect.size.x - 24, 14, INK)
		draw_string(font, info_rect.position + Vector2(12, 48), line2, HORIZONTAL_ALIGNMENT_LEFT, info_rect.size.x - 24, 12, GREEN if bool(selected_mine.get("license_owned", false)) else GOLD)


func _cluster_color(cluster_id: String) -> Color:
	match cluster_id:
		"dawn_frontier": return Color("4cc9dc")
		"crimson_sands": return Color("ed8b61")
		"frost_ring": return Color("81c6e9")
		"molten_core": return Color("eac36c")
		"glimmer_deep": return Color("be98ed")
		_: return CYAN
