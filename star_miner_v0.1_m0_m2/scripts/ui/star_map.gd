class_name StarMapView
extends Control

## 《星矿大亨》v5.0 深空美学重构版 (Deep Cosmos & Turmoil-Inspired Minimalist Edition)：
## 1. 85% 宇宙留白与「近大远小」三维透视：近轨行星 (56px)、中距双星系 (46px)、远距深空星云 (38px)，彻底告别拥挤感。
## 2. 极简微缩胶囊铭牌：移除原本遮挡星空的 114x72 四行大黑框與右下角雷达框，仅在星球正下方显示轻盈单行胶囊（选中/悬停时展开精密测控环）。
## 3. 4K 超采样体积星云与地球蔚蓝弧形瑞利散射地平线，搭配微缩精致的博卡湾星舰基地五建筑与近地轨道星链/加注站。

signal star_selected(star_id: String)
signal facility_selected(facility_id: String)

const Assets = preload("res://scripts/services/asset_loader.gd")
const SKY_TEX := preload("res://assets/kenney/shooter/blue.png")
const STAR_TEX := preload("res://assets/kenney/shooter/star1.png")
const HOME := preload("res://assets/kenney/planets/planet00.png")
const METAL := preload("res://assets/kenney/planets/planet02.png")
const CRYSTAL := preload("res://assets/kenney/planets/planet09.png")
const DANGER := preload("res://assets/kenney/planets/planet06.png")
const LIGHT_SHIP := preload("res://assets/kenney/shooter/playerShip1_blue.png")
const MEDIUM_SHIP := preload("res://assets/kenney/shooter/playerShip2_orange.png")
const REUSE_SHIP := preload("res://assets/kenney/shooter/playerShip3_green.png")
const ASTEROID := preload("res://assets/kenney/shooter/meteorBrown_big1.png")
const BASE_FALLBACK := preload("res://assets/concept/lunar_base_reference.png")

const HIT_STAR := 68.0
const HIT_FACILITY := 56.0
const HORIZON_RATIO := 0.57
const SEPARATION := 182.0

const INK := Color("e6eff5")
const MUTED := Color("8ca2b4")
const STEEL := Color("cfdbe4")
const STEEL_DIM := Color("7d8e9b")
const PANEL := Color("0b141e")
const PANEL_DARK := Color("070d14")
const CYAN := Color("4cc9dc")
const AMBER := Color("eba04e")
const GOLD := Color("f0b965")
const GREEN := Color("7bc4a4")
const RED := Color("eb867c")
const PURPLE := Color("b48cf2")
const WINDOW := Color("9be7f5")
const SKY_TOP := Color("02040a")

var state: GameState
var selected_star_id: String = ""
var focused_galaxy_id: String = ""
var hovered_item: String = ""
var tick_fraction: float = 0.0
var locations: Dictionary = {}
var facility_spots: Dictionary = {}
var galaxy_centers: Dictionary = {}
var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var flashes: Array = []
var floating_texts: Array = []
var launch_particles: Array = []
var shake_intensity: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "点击深空中的矿星查看地下矿脉剖面并派遣星舰；点击地球博卡星舰基地建筑打开对应终端。右键拖动，滚轮缩放。"
	set_process(true)


func trigger_shake(amount: float = 6.0) -> void:
	if not SettingsService.data.get("graphics", {}).get("screen_shake", true):
		return
	shake_intensity = maxf(shake_intensity, amount)


func spawn_launch_blast() -> void:
	var now: int = Time.get_ticks_msec()
	for i in range(18):
		var angle: float = -PI * 0.15 - _unit(i * 7 + now % 97) * PI * 0.70
		if i < 6:
			angle = (-0.25 if i % 2 == 0 else -PI + 0.25) + (_unit(i * 13) - 0.5) * 0.35
		var speed_val: float = 24.0 + _unit(i * 11 + 3) * 52.0
		launch_particles.append({
			"vel": Vector2(cos(angle), sin(angle)) * speed_val,
			"radius": 4.0 + _unit(i * 19) * 5.0,
			"hot": i % 3 == 0,
			"born": now
		})


func spawn_floating_text(anchor_key: String, text: String, color: Color = Color("7bc4a4")) -> void:
	floating_texts.append({
		"anchor": anchor_key,
		"text": text,
		"color": color,
		"born": Time.get_ticks_msec()
	})


func focus_galaxy(gal_id: String) -> void:
	if focused_galaxy_id == gal_id or gal_id == "":
		focused_galaxy_id = ""
		map_zoom = 1.0
		map_offset = Vector2.ZERO
	else:
		focused_galaxy_id = gal_id
		if galaxy_centers.has(gal_id):
			var center_pt: Vector2 = galaxy_centers[gal_id]
			map_zoom = 1.22
			map_offset = size * 0.42 - center_pt * map_zoom
	queue_redraw()


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if shake_intensity > 0.05:
		shake_intensity = maxf(0.0, shake_intensity - delta * 22.0)
		var angle: float = float(now) * 0.09
		shake_offset = Vector2(cos(angle), sin(angle * 1.37)) * shake_intensity
	else:
		shake_intensity = 0.0
		shake_offset = Vector2.ZERO

	var kept: Array = []
	for item in flashes:
		if item is Dictionary and now - int(item.get("born", 0)) < 5500:
			kept.append(item)
	flashes = kept

	var kept_floats: Array = []
	for ft in floating_texts:
		if ft is Dictionary and now - int(ft.get("born", 0)) < 2400:
			kept_floats.append(ft)
	floating_texts = kept_floats

	var kept_blast: Array = []
	for bp in launch_particles:
		if bp is Dictionary and now - int(bp.get("born", 0)) < 1300:
			kept_blast.append(bp)
	launch_particles = kept_blast

	if visible and state != null:
		queue_redraw()


func scene_layout(canvas: Vector2 = Vector2.ZERO) -> Dictionary:
	var area: Vector2 = canvas
	if area.x < 8.0 or area.y < 8.0:
		area = size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(960, 640)
	return _compose(area)


func pick_world(world: Vector2, canvas: Vector2 = Vector2.ZERO) -> String:
	return _identify(world, scene_layout(canvas))


func route_point(origin: Vector2, target: Vector2, amount: float) -> Vector2:
	var control: Vector2 = _route_control(origin, target)
	var t: float = clampf(amount, 0.0, 1.0)
	var u: float = 1.0 - t
	return u * u * origin + 2.0 * u * t * control + t * t * target


func route_tangent(origin: Vector2, target: Vector2, amount: float) -> Vector2:
	var control: Vector2 = _route_control(origin, target)
	var t: float = clampf(amount, 0.0, 1.0)
	var delta: Vector2 = 2.0 * (1.0 - t) * (control - origin) + 2.0 * t * (target - control)
	if delta.length() < 0.001:
		return Vector2.UP
	return delta.normalized()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var before: Vector2 = (event.position - map_offset) / map_zoom
		var factor: float = 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
		map_zoom = clampf(map_zoom * factor, 0.55, 2.2)
		map_offset = event.position - before * map_zoom
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			map_offset += event.relative
			queue_redraw()
			accept_event()
			return
		var layout: Dictionary = scene_layout()
		var world: Vector2 = (event.position - map_offset) / map_zoom
		var next_hover: String = _identify(world, layout)
		if next_hover != hovered_item:
			hovered_item = next_hover
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var layout: Dictionary = scene_layout()
		locations = layout["locations"]
		facility_spots = layout["facilities"]
		var world: Vector2 = (event.position - map_offset) / map_zoom
		var hit: String = _identify(world, layout)
		if hit.begins_with("star:"):
			star_selected.emit(hit.substr(5))
			accept_event()
		elif hit.begins_with("facility:"):
			facility_selected.emit(hit.substr(9))
			accept_event()
		elif hit.begins_with("galaxy:"):
			focus_galaxy(hit.substr(7))
			accept_event()


func _draw() -> void:
	var canvas: Vector2 = size
	if canvas.x < 2.0 or canvas.y < 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, canvas), SKY_TOP)
	if state == null:
		return
	var layout: Dictionary = scene_layout(canvas)
	locations = layout["locations"]
	facility_spots = layout["facilities"]
	_set_board_transform()
	_draw_sky_and_panorama(layout)
	_draw_galaxy_clusters(layout)
	_draw_leo_orbital_depot(layout)
	_draw_routes(layout)
	_draw_base_overlays(layout)
	_draw_targets(layout)
	_draw_hover_reticle(layout)
	_draw_ai_rival_ships(layout)
	_draw_traffic(layout)
	_draw_floating_texts(layout)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_caption()


func _compose(area: Vector2) -> Dictionary:
	var horizon: float = area.y * HORIZON_RATIO
	var ground_y: float = area.y * 0.808
	var unit: float = clampf(area.x / 1080.0, 0.78, 1.2)
	var anchors: Dictionary = {
		"hangar": Vector2(area.x * 0.205, ground_y),
		"pad": Vector2(area.x * 0.422, ground_y),
		"tanks": Vector2(area.x * 0.555, ground_y),
		"warehouse": Vector2(area.x * 0.668, ground_y),
		"trade": Vector2(area.x * 0.855, ground_y),
	}
	var facilities: Dictionary = {
		"hangar": anchors["hangar"] + Vector2(0, -48.0 * unit),
		"pad": anchors["pad"] + Vector2(0, -14.0 * unit),
		"tanks": anchors["tanks"] + Vector2(0, -48.0 * unit),
		"warehouse": anchors["warehouse"] + Vector2(0, -36.0 * unit),
		"trade": anchors["trade"] + Vector2(0, -46.0 * unit),
	}
	return {
		"size": area,
		"horizon_y": horizon,
		"ground_y": ground_y,
		"unit": unit,
		"anchors": anchors,
		"facilities": facilities,
		"port": anchors["pad"] + Vector2(0.0, -12.0 * unit),
		"locations": _place_stars(area, horizon),
	}


func _place_stars(area: Vector2, horizon: float) -> Dictionary:
	var placed: Dictionary = {}
	if state == null:
		return placed
	var ids: Array[String] = []
	var points: Array[Vector2] = []
	var near_index: int = 0
	var mid_index: int = 0
	for star_id in state.stars:
		var star: Dictionary = state.stars[star_id]
		var point := Vector2.ZERO
		var custom: Variant = star.get("map_position", null)
		if custom is Array and (custom as Array).size() >= 2:
			var coordinate: Array = custom
			# 将所有星球优雅分布在开阔的深空画布内（无需缩小镜头即可一眼尽览浩瀚星空）
			point = Vector2(
				lerpf(96.0, area.x - 86.0, clampf(float(coordinate[0]), 0.08, 0.92)),
				lerpf(56.0, horizon - 74.0, clampf(float(coordinate[1]) / 0.44, 0.06, 0.94))
			)
		elif str(star.get("route", "near")) == "mid":
			point = Vector2(area.x * (0.68 + 0.12 * float(mid_index)), area.y * (0.26 - 0.03 * float(mid_index)))
			mid_index += 1
		else:
			point = Vector2(area.x * (0.34 + 0.22 * float(near_index)), area.y * (0.22 + 0.03 * float(near_index)))
			near_index += 1
		ids.append(str(star_id))
		points.append(_clamp_sky(point, area, horizon))
	_separate_points(points, area, horizon)
	for index in range(ids.size()):
		placed[ids[index]] = points[index]
	return placed


func _clamp_sky(point: Vector2, area: Vector2, horizon: float) -> Vector2:
	var max_x: float = maxf(140.0, area.x - 78.0)
	var max_y: float = maxf(88.0, horizon - 74.0)
	return Vector2(clampf(point.x, 86.0, max_x), clampf(point.y, 52.0, max_y))


func _separate_points(points: Array[Vector2], area: Vector2, horizon: float) -> void:
	var min_sep: float = 142.0 if points.size() >= 6 else SEPARATION
	for _step in range(16):
		for i in range(points.size()):
			for j in range(i):
				var delta: Vector2 = points[i] - points[j]
				var dist: float = delta.length()
				if dist >= min_sep:
					continue
				var push: Vector2 = Vector2.RIGHT if dist < 0.01 else delta / maxf(dist, 0.01)
				var amount: float = (min_sep - dist) * 0.55
				points[i] = _clamp_sky(points[i] + push * amount, area, horizon)
				points[j] = _clamp_sky(points[j] - push * amount, area, horizon)


func _identify(world: Vector2, layout: Dictionary) -> String:
	var spots: Dictionary = layout["locations"]
	for star_id in spots:
		if world.distance_to(spots[star_id]) < HIT_STAR:
			return "star:" + str(star_id)
	var facilities: Dictionary = layout["facilities"]
	var best: String = ""
	var best_distance: float = HIT_FACILITY
	for facility_id in facilities:
		var distance: float = world.distance_to(facilities[facility_id])
		if distance <= best_distance:
			best = "facility:" + str(facility_id)
			best_distance = distance
	if best != "":
		return best
	for gal_id in galaxy_centers:
		var g_center: Vector2 = galaxy_centers[gal_id]
		if world.distance_to(g_center + Vector2(0, -34)) < 44.0:
			return "galaxy:" + str(gal_id)
	return ""


## 按星球轨道深度返回精致微缩半径（近轨 28px / 中距 23px / 远距深空 19px），营造真正的宇宙近大远小纵深感
func _planet_radius(star: Dictionary) -> float:
	match str(star.get("route", "near")):
		"far": return 19.0
		"mid": return 23.0
		_: return 28.0


func _claim_point(target: Vector2) -> Vector2:
	return target + Vector2(22, 14)


func _route_control(origin: Vector2, target: Vector2) -> Vector2:
	var crest: float = minf(origin.y, target.y) - 68.0
	return Vector2(lerpf(origin.x, target.x, 0.46), crest)


func _set_board_transform() -> void:
	draw_set_transform(map_offset + shake_offset, 0.0, Vector2(map_zoom, map_zoom))


func _draw_sky_and_panorama(layout: Dictionary) -> void:
	var area: Vector2 = layout["size"]
	var horizon: float = layout["horizon_y"]
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	draw_rect(Rect2(-900, -700, area.x + 1800, 705 + horizon), SKY_TOP)
	draw_rect(Rect2(-900, horizon, area.x + 1800, area.y - horizon + 500), Color("0a1017"))

	var pano_tex: Texture2D = Assets.get_tex("res://assets/custom/earth_starbase_panoramic.png", BASE_FALLBACK)
	if pano_tex != null:
		var is_flare: bool = str(state.active_event.get("type", "")) == "solar_flare"
		var tint: Color = Color(1.06, 0.92, 0.88, 1.0) if is_flare else Color.WHITE
		draw_texture_rect(pano_tex, Rect2(0, 0, area.x, area.y), false, tint)

	# 仅绘制 36 颗极细微的动态呼吸星芒点缀，不破坏 4K 预渲染深空背景的深邃纯净感
	for i in range(36):
		var x: float = lerpf(24.0, area.x - 24.0, _unit(i * 7 + 1))
		var y: float = lerpf(18.0, horizon - 48.0, _unit(i * 7 + 2))
		var twinkle: float = 0.45 + 0.55 * sin(now_sec * (1.2 + _unit(i * 3) * 1.8) + float(i))
		var alpha: float = (0.18 + 0.38 * _unit(i * 5 + 3)) * twinkle
		draw_circle(Vector2(x, y), 1.0, Color(0.90, 0.96, 1.0, alpha))


func _draw_leo_orbital_depot(layout: Dictionary) -> void:
	var area: Vector2 = layout["size"]
	var horizon: float = layout["horizon_y"]
	var tycoon: Dictionary = state.stats.get("tycoon", {})
	var depot_lvl: int = int(tycoon.get("orbital_depot_level", 0))
	var sl_batches: int = int(tycoon.get("starlink_batches", 0))
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var leo_y: float = horizon - 26.0

	if sl_batches > 0:
		var sat_dots: int = sl_batches * 5
		var train_head_x: float = fmod(now_sec * 56.0, area.x + 180.0) - 90.0
		for s_i in range(sat_dots):
			var sx: float = train_head_x - float(s_i) * 12.0
			var sy: float = leo_y - 8.0 + sin(sx * 0.012) * 3.0
			if sx > 20.0 and sx < area.x - 20.0:
				draw_circle(Vector2(sx, sy), 1.5, Color(0.75, 0.96, 1.0, 0.72))

	if depot_lvl <= 0:
		return
	var depot_x: float = lerpf(area.x * 0.28, area.x * 0.68, 0.5 + 0.42 * sin(now_sec * 0.20))
	var depot_pos := Vector2(depot_x, leo_y)
	draw_line(depot_pos + Vector2(-18, -7), depot_pos + Vector2(18, 7), _fade(CYAN, 0.75), 1.6, true)
	draw_line(depot_pos + Vector2(-18, 7), depot_pos + Vector2(18, -7), _fade(CYAN, 0.75), 1.6, true)
	draw_rect(Rect2(depot_pos - Vector2(12, 3.5), Vector2(24, 7)), STEEL)
	draw_rect(Rect2(depot_pos - Vector2(4, 3.5), Vector2(8, 7)), AMBER)
	_draw_text(depot_pos + Vector2(-48, -10), "🛰在轨加注站 Lv.%d" % depot_lvl, 10, _fade(CYAN, 0.82))


## 极简天文学星系轨道与轻盈水印（去除生硬矩形框，让星系自然融于深邃星云）
func _draw_galaxy_clusters(layout: Dictionary) -> void:
	var spots: Dictionary = layout["locations"]
	galaxy_centers.clear()

	var groups: Dictionary = {
		"near": {"title": "☀ 太阳系内环", "color": AMBER, "pts": []},
		"mid": {"title": "✦ 半人马 α 双星系", "color": CYAN, "pts": []},
		"far": {"title": "🌀 天鹅座深空", "color": PURPLE, "pts": []}
	}
	for sid in spots:
		var star: Dictionary = state.stars[sid]
		var r_key: String = str(star.get("route", "near"))
		if not groups.has(r_key):
			r_key = "near"
		var pt_list: Array = groups[r_key]["pts"]
		pt_list.append(spots[sid])

	for g_key in ["near", "mid", "far"]:
		var g_info: Dictionary = groups[g_key]
		var pts: Array = g_info["pts"]
		if pts.is_empty():
			continue
		var center := Vector2.ZERO
		for p in pts:
			var pv: Vector2 = p
			center += pv
		center /= float(pts.size())
		galaxy_centers[g_key] = center
		var g_col: Color = g_info["color"]

		# 极其克制、纤细的星系引力等势椭圆弧线 (alpha = 0.08)
		for p in pts:
			var pv: Vector2 = p
			var dist_x: float = maxf(32.0, absf(pv.x - center.x) + 12.0)
			var dist_y: float = maxf(18.0, absf(pv.y - center.y) + 8.0)
			_draw_ellipse_outline(center, dist_x, dist_y, _fade(g_col, 0.08), 1.0)

		# 轻盈无边框的天文学星区水印标题
		var is_focused: bool = (focused_galaxy_id == g_key)
		var label_alpha: float = 0.85 if is_focused else 0.42
		_draw_text(center + Vector2(-48, -36), str(g_info["title"]), 11, _fade(GOLD if is_focused else g_col, label_alpha))


func _draw_routes(layout: Dictionary) -> void:
	var port: Vector2 = layout["port"]
	var spots: Dictionary = layout["locations"]

	var active_flight_stars: Dictionary = {}
	for ship in state.ships:
		var st: String = str(ship.get("state", ""))
		if st in ["outbound", "inbound", "waiting"]:
			active_flight_stars[str(ship.get("star_id", ""))] = true

	for star_id in spots:
		var sid_str: String = str(star_id)
		var is_selected: bool = (sid_str == selected_star_id)
		var has_flight: bool = active_flight_stars.has(sid_str)
		if not is_selected and not has_flight:
			continue
		var star: Dictionary = state.stars[star_id]
		var trace_col: Color = AMBER if str(star["ore"]) == "metal" else CYAN
		_draw_telemetry_trajectory(port, _claim_point(spots[star_id]), trace_col, is_selected)


func _draw_telemetry_trajectory(origin: Vector2, target: Vector2, col: Color, emphasized: bool) -> void:
	var steps: int = 40
	var shift: float = fmod(float(Time.get_ticks_msec()) / 1000.0, 1.0)
	for i in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var dash_on: bool = fmod(t0 * 12.0 - shift * 2.0 + 12.0, 1.0) < 0.42
		if dash_on:
			var p0: Vector2 = route_point(origin, target, t0)
			var p1: Vector2 = route_point(origin, target, t1)
			var alpha: float = 0.38 if emphasized else 0.18
			draw_line(p0, p1, _fade(col, alpha), 1.4 if emphasized else 1.0, true)


func _draw_base_overlays(layout: Dictionary) -> void:
	var anchors: Dictionary = layout["anchors"]
	var unit: float = layout["unit"]
	_draw_hangar_overlay(anchors["hangar"], unit)
	_draw_tanks_overlay(anchors["tanks"], unit)
	_draw_warehouse_overlay(anchors["warehouse"], unit)
	_draw_trade_overlay(anchors["trade"], unit)
	var show_ready: bool = state.ships.is_empty() and not state.season_ended
	_draw_pad_overlay(anchors["pad"], unit, show_ready)


func _draw_hangar_overlay(anchor: Vector2, unit: float) -> void:
	var repairing: Array = _ships_in("refurbishing")
	var slot: int = 0
	for ship in repairing:
		var texture: Texture2D = _ship_texture(ship)
		draw_texture_rect(texture, Rect2(anchor + Vector2(-18 + slot * 20, -46) * unit, Vector2(22, 30) * unit), false, Color(1, 1, 1, 0.90))
		slot += 1
		if slot >= 2:
			break
	var idle: int = _ships_in("idle").size()
	var label_txt: String = "星舰巨湾 (%d)" % idle if idle > 0 else "星舰巨湾"
	_draw_facility_badge(anchor + Vector2(0, 20), label_txt, CYAN if idle > 0 else MUTED, hovered_item == "facility:hangar")


func _draw_tanks_overlay(anchor: Vector2, unit: float) -> void:
	var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) / 500.0)
	draw_circle(anchor + Vector2(-12, -52) * unit, 2.2 * unit, _fade(CYAN, pulse))
	draw_circle(anchor + Vector2(12, -52) * unit, 2.2 * unit, _fade(AMBER, pulse))
	_draw_facility_badge(anchor + Vector2(0, 20), "甲烷储罐", MUTED, hovered_item == "facility:tanks")


func _draw_warehouse_overlay(anchor: Vector2, unit: float) -> void:
	var metal: int = int(state.port_storage.get("metal", 0))
	var crystal: int = int(state.port_storage.get("crystal", 0))
	var shown: int = 0
	for index in range(mini(metal, 5)):
		_draw_crate(anchor + Vector2(-32 + (shown % 5) * 13, -12 if shown >= 5 else -2) * unit, AMBER, unit)
		shown += 1
	for index in range(mini(crystal, 5)):
		_draw_crate(anchor + Vector2(-32 + (shown % 5) * 13, -12 if shown >= 5 else -2) * unit, CYAN, unit)
		shown += 1
	var total: int = metal + crystal
	var capacity: int = int(state.balance["port_capacity"])
	var port_full: bool = capacity > 0 and total >= capacity
	var warehouse_text: String = "立体仓 %d/%d" % [total, capacity]
	_draw_facility_badge(anchor + Vector2(0, 20), warehouse_text, RED if port_full else MUTED, hovered_item == "facility:warehouse")


func _draw_trade_overlay(anchor: Vector2, unit: float) -> void:
	var active: bool = _trade_open()
	var mars_stage: int = int(state.stats.get("tycoon", {}).get("mars_stage", 0))
	if mars_stage > 0:
		_draw_text(anchor + Vector2(-42, -82) * unit, "🪐火星星城 Lv.%d" % mars_stage, 10, GOLD)
	_draw_facility_badge(anchor + Vector2(0, 20), "火星交易所", GOLD if active else MUTED, hovered_item == "facility:trade")


func _draw_pad_overlay(anchor: Vector2, unit: float, show_rocket: bool) -> void:
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var chop_open: float = sin(now_sec * 1.4) * 3.5 * unit
	var tower_top: Vector2 = anchor + Vector2(-24, -76) * unit
	draw_line(tower_top, anchor + Vector2(14, -76) * unit + Vector2(0, -chop_open), STEEL, 2.2, true)
	draw_line(tower_top + Vector2(0, 5 * unit), anchor + Vector2(14, -71) * unit + Vector2(0, chop_open), STEEL_DIM, 1.8, true)

	var now_ms: int = Time.get_ticks_msec()
	for bp in launch_particles:
		if not (bp is Dictionary):
			continue
		var age: float = float(now_ms - int(bp.get("born", 0))) / 1300.0
		if age < 0.0 or age > 1.0:
			continue
		var vel: Vector2 = bp.get("vel", Vector2.UP * 28.0)
		var p_pos: Vector2 = anchor + Vector2(0, -10) * unit + vel * age
		var p_rad: float = float(bp.get("radius", 5.0)) * (0.65 + age * 1.2)
		var base_c: Color = Color("ff9e3d") if bool(bp.get("hot", false)) and age < 0.45 else Color("b8c6ce")
		draw_circle(p_pos, p_rad, _fade(base_c, (1.0 - age) * 0.62))
	if show_rocket:
		var unlocked: Array = state.stats.get("unlocked_techs", [])
		var has_heavy: bool = TechTree.is_unlocked(unlocked, "starship_heavy")
		var r_path: String = "res://assets/custom/rocket_heavy.png" if has_heavy else "res://assets/custom/rocket_light.png"
		var r_tex: Texture2D = Assets.get_tex(r_path, LIGHT_SHIP)
		_draw_ship_sprite(r_tex, anchor + Vector2(0, -32) * unit, Vector2.UP, false, 0.92)
		for v_i in range(3):
			var vp: float = fmod(now_sec * 0.70 + float(v_i) * 0.33, 1.0)
			var vx: float = anchor.x + (8.0 + vp * 20.0) * unit
			var vy: float = anchor.y - (38.0 - float(v_i) * 4.0 - vp * 8.0) * unit
			draw_circle(Vector2(vx, vy), (2.4 + vp * 3.5) * unit, Color(0.88, 0.96, 1.0, (1.0 - vp) * 0.30))
	_draw_facility_badge(anchor + Vector2(0, 20), "筷子发射塔", AMBER if show_rocket else MUTED, hovered_item == "facility:pad")


func _draw_facility_badge(center_pos: Vector2, text: String, col: Color, is_hovered: bool = false) -> void:
	var box := Rect2(center_pos - Vector2(46, 11), Vector2(92, 19))
	draw_rect(box, Color(0.04, 0.08, 0.13, 0.85 if is_hovered else 0.55))
	if is_hovered:
		draw_rect(Rect2(box.position, Vector2(box.size.x, 1.5)), CYAN)
	_draw_text(box.position + Vector2(0, 14), text, 11, INK if is_hovered else col, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_crate(at: Vector2, color: Color, unit: float) -> void:
	draw_rect(Rect2(at + Vector2(-5, -8) * unit, Vector2(10, 8) * unit), color)
	draw_rect(Rect2(at + Vector2(-5, -8) * unit, Vector2(10, 1.5) * unit), STEEL)


## 《石油大亨 Turmoil》与《群星 Stellaris》极简高颜值天体绘制：
## - 星球按远近呈宝石般微缩比例 (直径 38px ~ 56px)，留出浩瀚深邃的宇宙空间；
## - 星球正下方仅挂一枚轻盈半透明的单行胶囊铭牌（无笨重四行大黑框）；
## - 选中或悬停时呈现精密双层测控光环与矿种副标题。
func _draw_targets(layout: Dictionary) -> void:
	var spots: Dictionary = layout["locations"]
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var has_isru: bool = TechTree.is_unlocked(unlocked, "isru_refinery")
	for star_id in spots:
		var star: Dictionary = state.stars[star_id]
		var target: Vector2 = spots[star_id]
		var selected: bool = (str(star_id) == selected_star_id)
		var is_hovered: bool = (hovered_item == "star:" + str(star_id))
		var is_metal: bool = str(star["ore"]) == "metal"
		var ore_color: Color = AMBER if is_metal else CYAN
		var p_rad: float = _planet_radius(star)

		# 仅在选中或悬停时呈现极细精密轨道环，让未选中星球纯粹悬浮于深邃天鹅绒宇宙中

		if selected:
			draw_arc(target, p_rad + 8.0, 0, TAU, 48, GOLD, 1.8, true)
			draw_arc(target, p_rad + 13.0, now_sec * 0.6, now_sec * 0.6 + PI * 1.4, 32, _fade(GOLD, 0.45), 1.0, true)
		elif is_hovered:
			draw_arc(target, p_rad + 7.0, 0, TAU, 40, CYAN, 1.4, true)
		elif str(star["environment"]) == "high_g":
			draw_arc(target, p_rad + 5.0, 0, TAU, 36, _fade(RED, 0.45), 1.1, true)

		# 卫星探矿雷达扫描波
		if not state.active_scan.is_empty() and str(state.active_scan.get("star_id", "")) == str(star_id):
			var sweep: float = fmod(float(Time.get_ticks_msec()) / 700.0, 1.0) * TAU
			draw_arc(target, p_rad + 14.0, sweep, sweep + 1.2, 20, CYAN, 2.2, true)

		# 环绕星球的微缩探矿卫星
		if bool(star["revealed"]) or bool(star["has_miner"]) or bool(star.get("vein_prospected", false)):
			var sat_angle: float = now_sec * 0.95 + float(star_id.hash() % 100) * 0.1
			var sat_pos: Vector2 = target + Vector2(cos(sat_angle) * (p_rad + 11.0), sin(sat_angle) * (p_rad * 0.45))
			draw_circle(sat_pos, 1.8, GOLD if bool(star.get("vein_prospected", false)) else CYAN)
			draw_line(sat_pos + Vector2(-4.5, 0), sat_pos + Vector2(4.5, 0), STEEL, 1.1, true)

		# 绘制宝石级 3D 球体行星纹理
		var texture: Texture2D = _planet_texture(star)
		var d_size := Vector2(p_rad * 2.15, p_rad * 2.15)
		draw_texture_rect(texture, Rect2(target - d_size * 0.5, d_size), false)

		# 微缩精致的星表钻机模块
		_draw_rig(target + Vector2(p_rad * 0.72, p_rad * 0.42), star, ore_color, has_isru)

		# 星球正下方极简微缩胶囊铭牌 (高仅 18px，不挡星空！)
		var capacity: int = _star_capacity(star)
		var stock: int = int(star["stock"])
		var stalled: bool = bool(star["has_miner"]) and capacity > 0 and stock >= capacity and int(star["reserve"]) > 0
		var pill_w: float = 104.0
		var pill_pos: Vector2 = target + Vector2(-pill_w * 0.5, p_rad + 7.0)
		var pill_rect := Rect2(pill_pos, Vector2(pill_w, 18.0))
		draw_rect(pill_rect, Color(0.03, 0.07, 0.12, 0.78 if (selected or is_hovered) else 0.52))
		draw_circle(pill_pos + Vector2(7.0, 9.0), 3.0, RED if stalled else ore_color)

		var status_short: String = "%d/%d" % [stock, capacity] if (bool(star["has_miner"]) or stock > 0) else ("?" if not bool(star["revealed"]) else "%d箱" % int(star["reserve"]))
		var pill_txt: String = "%s · %s" % [str(star["name"]).split(" · ")[0], status_short]
		_draw_text(pill_pos + Vector2(14.0, 13.5), pill_txt, 11, GOLD if selected else INK, pill_w - 16.0, HORIZONTAL_ALIGNMENT_LEFT)

		# 底部 2px 迷你库存进度细线
		if bool(star["has_miner"]) or stock > 0:
			var ratio: float = clampf(float(stock) / float(maxi(1, capacity)), 0.0, 1.0)
			draw_rect(Rect2(pill_pos + Vector2(0, 16.5), Vector2(pill_w * ratio, 1.5)), RED if stalled else ore_color)

		# 仅在选中或悬停时显示第二行精密遥测副标题
		if selected or is_hovered:
			var ore_name_short: String = "赤铁钛矿" if is_metal else "高能晶簇"
			var sub_txt: String = "%s · %s" % [ore_name_short, ("余%d箱" % int(star["reserve"])) if bool(star["revealed"]) else "待发射卫星探矿"]
			if str(star["environment"]) == "high_g":
				sub_txt += " · ⚠高重"
			_draw_text(pill_pos + Vector2(-12.0, 30.0), sub_txt, 10, ore_color, pill_w + 24.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_hover_reticle(_layout: Dictionary) -> void:
	pass


func _draw_rig(deck: Vector2, star: Dictionary, ore_color: Color, has_isru: bool = false) -> void:
	var running: bool = bool(star["has_miner"])
	var rig_tex: Texture2D = Assets.get_tex("res://assets/custom/mining_rig_hd.png", null)
	if rig_tex != null and (running or bool(star["has_silo"])):
		draw_texture_rect(rig_tex, Rect2(deck + Vector2(-8, -16), Vector2(26, 22)), false, Color.WHITE if running else Color(0.7, 0.78, 0.85, 0.75))
	if running:
		var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
		var pulse: float = 0.5 + 0.5 * sin(now_sec * 5.5)
		var drill_top: Vector2 = deck + Vector2(4, -5)
		var drill_bot: Vector2 = deck + Vector2(-10, -8)
		draw_line(drill_top, drill_bot, _fade(ore_color, 0.75 + 0.25 * pulse), 1.8, true)
		draw_circle(drill_top, 2.2, GOLD if pulse > 0.5 else CYAN)
	if has_isru and bool(star["licensed"]):
		_draw_ellipse(deck + Vector2(-6, 2), 4.0, 3.0, CYAN)
	if bool(star.get("deep_unlocked", false)):
		draw_circle(deck + Vector2(12, -8), 2.2, GOLD)


func _draw_ai_rival_ships(layout: Dictionary) -> void:
	if state == null or state.stars.size() < 4 or not state.events_enabled:
		return
	var spots: Dictionary = layout["locations"]
	var anchors: Dictionary = layout["anchors"]
	var trade_port: Vector2 = anchors["trade"] + Vector2(0, -28)
	var star_keys: Array = spots.keys()
	if star_keys.is_empty():
		return
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var cycle: float = fmod(now_sec * 0.07, 1.0)
	var rival_idx: int = int(now_sec / 14.0) % 3
	var target_sid: String = str(star_keys[rival_idx % star_keys.size()])
	var star_pt: Vector2 = spots[target_sid] + Vector2(22, -16)
	var outbound: bool = cycle < 0.5
	var t: float = (cycle * 2.0) if outbound else ((1.0 - cycle) * 2.0)
	var pos: Vector2 = route_point(trade_port, star_pt, t)
	var dir: Vector2 = route_tangent(trade_port, star_pt, t) if outbound else -route_tangent(trade_port, star_pt, t)
	var rival_names: Array[String] = ["雷克斯号", "星环号", "奥托号"]
	var rival_cols: Array[Color] = [RED, CYAN, GOLD]
	draw_circle(pos, 3.2, rival_cols[rival_idx])
	draw_line(pos - dir * 8.0, pos + dir * 5.0, rival_cols[rival_idx], 1.8, true)
	_draw_text(pos + Vector2(-18, -10), rival_names[rival_idx], 9, _fade(rival_cols[rival_idx], 0.78))


func _draw_traffic(layout: Dictionary) -> void:
	var port: Vector2 = layout["port"]
	var spots: Dictionary = layout["locations"]
	var anchors: Dictionary = layout["anchors"]
	var lane: Dictionary = {}
	for ship in state.ships:
		var status: String = str(ship.get("state", ""))
		var star_id: String = str(ship.get("star_id", ""))
		var b_tier: int = int(ship.get("block_tier", 1))
		var tier_suffix: String = ("·B%d" % b_tier) if b_tier >= 2 else ""
		if status in ["outbound", "waiting", "inbound"] and spots.has(star_id):
			var target: Vector2 = _claim_point(spots[star_id])
			var progress: float = 0.0
			if status != "waiting":
				var travel: int = maxi(1, int(ship["travel_ticks"]))
				var start_tick: int = int(ship["event_tick"]) - travel
				progress = clampf((float(state.current_tick) + tick_fraction - float(start_tick)) / float(travel), 0.0, 1.0)
			var t: float = progress if status == "outbound" else (0.0 if status == "waiting" else 1.0 - progress)
			if status == "waiting":
				t = 1.0
			var tangent: Vector2 = route_tangent(port, target, t)
			var used: int = int(lane.get(star_id, 0))
			lane[star_id] = used + 1
			var offset_vec: Vector2 = Vector2(-tangent.y, tangent.x) * float(used) * 14.0
			var pos: Vector2 = route_point(port, target, t) + offset_vec
			if status == "waiting":
				pos = target + Vector2(6, 18)
				tangent = Vector2.UP
			var flying: bool = status != "waiting"
			if status == "inbound":
				tangent = -route_tangent(port, target, t)
			if flying:
				for p_idx in range(1, 5):
					var dt: float = float(p_idx) * 0.020 * (1.0 if status == "outbound" else -1.0)
					var trail_t: float = clampf(t - dt, 0.0, 1.0)
					var trail_pos: Vector2 = route_point(port, target, trail_t) + offset_vec
					var alpha: float = (1.0 - float(p_idx) / 5.0) * 0.52
					var puff_radius: float = 4.2 - float(p_idx) * 0.6
					var puff_col: Color = Color("ffbb5a") if p_idx <= 2 else Color("7cdbf5")
					draw_circle(trail_pos, puff_radius, _fade(puff_col, alpha))
			var ship_scale: float = 0.96 if str(ship.get("mode", "")) == "heavy_reuse" else 0.82
			_draw_ship_sprite(_ship_texture(ship), pos, tangent, flying, ship_scale)
			var tag_str: String = "#%d%s%s" % [int(ship["id"]), tier_suffix, "↻" if bool(ship.get("auto_loop", false)) else ""]
			_draw_text(pos + Vector2(-12, -20), tag_str, 10, GOLD if b_tier >= 2 else INK)
		elif status == "idle":
			var index: int = int(lane.get("idle", 0))
			lane["idle"] = index + 1
			var idle_pos: Vector2 = anchors["hangar"] + Vector2(-14 + index * 22, -12)
			_draw_ship_sprite(_ship_texture(ship), idle_pos, Vector2.UP, false, 0.76)
		elif status == "port":
			var index: int = int(lane.get("port", 0))
			lane["port"] = index + 1
			var dock_pos: Vector2 = anchors["warehouse"] + Vector2(20 + index * 18, -10)
			_draw_ship_sprite(_ship_texture(ship), dock_pos, Vector2.UP, false, 0.76)


func _draw_ship_sprite(texture: Texture2D, pos: Vector2, direction: Vector2, flying: bool, scale_val: float) -> void:
	var angle: float = direction.angle() + PI / 2.0
	draw_set_transform(map_offset + shake_offset + pos * map_zoom, angle, Vector2.ONE * map_zoom * scale_val)
	if flying:
		var flicker: float = 26.0 + 6.0 * sin(float(Time.get_ticks_msec()) * 0.045)
		draw_colored_polygon(PackedVector2Array([Vector2(-5.5, 14), Vector2(0, flicker), Vector2(5.5, 14)]), Color("ff9e3d"))
		draw_colored_polygon(PackedVector2Array([Vector2(-2.8, 14), Vector2(0, flicker * 0.76), Vector2(2.8, 14)]), Color("fff6c4"))
	draw_texture_rect(texture, Rect2(-18, -22, 36, 44), false)
	_set_board_transform()


func _draw_floating_texts(layout: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	var anchors: Dictionary = layout["anchors"]
	var spots: Dictionary = layout["locations"]
	for item in floating_texts:
		if not (item is Dictionary):
			continue
		var age: float = float(now - int(item.get("born", 0))) / 2400.0
		if age < 0.0 or age > 1.0:
			continue
		var key: String = str(item.get("anchor", "warehouse"))
		var base_pos: Vector2 = anchors.get("warehouse", Vector2(450, 450))
		if anchors.has(key):
			base_pos = anchors[key] + Vector2(-20, -56)
		elif spots.has(key):
			base_pos = spots[key] + Vector2(-20, -38)
		var pos: Vector2 = base_pos + Vector2(0, -age * 40.0)
		var col: Color = item.get("color", Color("7bc4a4"))
		col.a = clampf(1.0 - pow(age, 1.5), 0.0, 1.0)
		_draw_text(pos, str(item.get("text", "")), 14, col)


func _draw_caption() -> void:
	_draw_text(Vector2(16, 22), "EARTH STARBASE BOCA  //  地球博卡星舰基地", 13, _fade(INK, 0.72))
	if not state.active_event.is_empty():
		var ev_title: String = str(state.active_event.get("title", "深空天象"))
		var rem_ticks: int = maxi(0, int(state.active_event.get("end_tick", 0)) - state.current_tick)
		var badge := Rect2(size.x - 248, 10, 234, 26)
		draw_rect(badge, Color(0.14, 0.09, 0.05, 0.82))
		draw_rect(Rect2(badge.position, Vector2(3, badge.size.y)), AMBER)
		_draw_text(badge.position + Vector2(10, 18), "⚡ %s (余 %.1f 日)" % [ev_title, float(rem_ticks) / 2.0], 12, AMBER, 220)
	var row: int = 0
	for item in flashes:
		if not (item is Dictionary):
			continue
		var kind: String = str(item.get("kind", ""))
		var color: Color = INK
		match kind:
			"cash": color = Color("b6f3c4")
			"stall", "portfull": color = Color("ffb0a8")
			"arrive", "return", "partial": color = Color("f0d48a")
			"order", "scan": color = CYAN
		var plate := Rect2(16, 34 + row * 28, 380, 24)
		draw_rect(plate, Color(0.03, 0.06, 0.10, 0.76))
		draw_rect(Rect2(plate.position, Vector2(3, plate.size.y)), color)
		_draw_text(plate.position + Vector2(10, 17), str(item.get("text", "")), 12, color, 364)
		row += 1
	if hovered_item != "":
		var tip_str: String = _hover_description(hovered_item)
		if tip_str != "":
			var tip_rect := Rect2(16, size.y - 34, minf(560.0, size.x - 32.0), 24)
			draw_rect(tip_rect, Color(0.04, 0.08, 0.13, 0.82))
			draw_rect(Rect2(tip_rect.position, Vector2(3, tip_rect.size.y)), CYAN)
			_draw_text(tip_rect.position + Vector2(10, 17), tip_str, 12, INK, tip_rect.size.x - 16.0)


func _hover_description(key: String) -> String:
	if key.begins_with("star:"):
		var sid: String = key.substr(5)
		if state.stars.has(sid):
			var s: Dictionary = state.stars[sid]
			var ore_n: String = "赤铁钛合金矿" if str(s["ore"]) == "metal" else "高能暗物质晶簇"
			return "【%s】%s · 星仓 %d/%d 箱 · 点击查看地下三靶点矿脉剖面并派遣星舰" % [str(s["name"]), ore_n, int(s["stock"]), _star_capacity(s)]
	if key.begins_with("galaxy:"):
		return "【恒星系聚焦】左键点击该星系名称可放大聚焦此星系，再次点击恢复全景。"
	match key:
		"facility:pad":
			return "【筷子发射回收塔 (Mech-Tower)】配置猎鹰/不锈钢星舰、投放星表钻机与返程矿箱"
		"facility:hangar":
			return "【星舰总装巨湾 (MegaBay)】管理可回收星舰整备、Block 2/3 模块化升级与自动巡航"
		"facility:tanks":
			return "【液氧甲烷低温储罐群】按航程与载重自动结算去返程推进剂（可建设近地轨道加注站减耗）"
		"facility:warehouse":
			return "【星链矿产立体仓】当前 %d/%d 箱 · 点击可启动电弧精炼 (+35%% 溢价) 或发射星链组网" % [state.port_total(), int(state.balance["port_capacity"])]
		"facility:trade":
			return "【火星殖民与股权大厅】查看双港跳价、发射星链组网、推进火星星城建设与 100% 控股权收购"
	return ""


func _draw_text(at: Vector2, text: String, font_size: int, color: Color, width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font: Font = _font()
	if font == null or text == "":
		return
	draw_string(font, at + Vector2(1, 1), text, alignment, width, font_size, Color(0, 0, 0, 0.65))
	draw_string(font, at, text, alignment, width, font_size, color)


func _font() -> Font:
	var font: Font = get_theme_default_font()
	if font == null:
		return ThemeDB.fallback_font
	return font


func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments: int = 28
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points: PackedVector2Array = _ellipse_points(center, radius_x, radius_y)
	if points.size() >= 3:
		draw_colored_polygon(points, color)


func _draw_ellipse_outline(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = _ellipse_points(center, radius_x, radius_y)
	if points.is_empty():
		return
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _unit(n: int) -> float:
	var value: float = sin(float(n) * 12.9898) * 43758.5453
	return value - floor(value)


func _star_capacity(star: Dictionary) -> int:
	var pipe_bonus: int = (int(star.get("pipe_level", 1)) - 1) * 6
	return int(state.balance["planet_capacity"]) + (int(state.balance["modules"]["silo"]["extra_capacity"]) if bool(star["has_silo"]) else 0) + pipe_bonus


func _ships_in(ship_state: String) -> Array:
	var matched: Array = []
	for ship in state.ships:
		if str(ship.get("state", "")) == ship_state:
			matched.append(ship)
	return matched


func _trade_open() -> bool:
	for order in state.orders:
		if not bool(order["closed"]) and int(order["open_tick"]) <= state.current_tick and state.current_tick <= int(order["close_tick"]) and int(order["sold"]) < int(order["quantity"]):
			return true
	return false


func _planet_texture(star: Dictionary) -> Texture2D:
	var sid: String = str(star.get("id", ""))
	if sid == "far_abyss":
		return Assets.get_tex("res://assets/custom/planet_far_abyss.png", DANGER)
	if sid == "far_titan":
		return Assets.get_tex("res://assets/custom/planet_far_titan.png", CRYSTAL)
	if str(star.get("environment", "")) == "high_g":
		return Assets.get_tex("res://assets/custom/planet_highg_metal.png", DANGER)
	if str(star.get("ore", "")) == "crystal":
		var c_path: String = "res://assets/custom/planet_crystal_2.png" if sid.hash() % 2 == 0 else "res://assets/custom/planet_crystal_1.png"
		return Assets.get_tex(c_path, CRYSTAL)
	var m_path: String = "res://assets/custom/planet_iron_2.png" if sid.hash() % 2 == 0 else "res://assets/custom/planet_iron_1.png"
	return Assets.get_tex(m_path, METAL)


func _ship_texture(ship: Dictionary) -> Texture2D:
	match str(ship.get("mode", "light")):
		"light":
			return Assets.get_tex("res://assets/custom/rocket_light.png", LIGHT_SHIP)
		"medium_once":
			return Assets.get_tex("res://assets/custom/rocket_medium.png", MEDIUM_SHIP)
		"heavy_reuse":
			return Assets.get_tex("res://assets/custom/rocket_heavy.png", REUSE_SHIP)
		_:
			return Assets.get_tex("res://assets/custom/rocket_reuse.png", REUSE_SHIP)
