class_name PlanetCrossSectionView
extends Control

## 《星矿大亨 Rocket Prospectors》V4.0 · 第六轮《星际航天 Astra / Orbital Tycoon》2.5D 科幻工业剖面升级版
## 严格遵循 V4.0 方案第 6 章、第 16.1–16.4 章与第 16.8 章「2D / 2.5D 的具体实现方式」：
## - 五大星团专属大气天际线与高清远景融合（晨曦蔚蓝 / 赤沙琥珀 / 霜环极光 / 熔心赤金 / 幽光深紫）
## - 2.5D 高清地表工业设施（起降塔架 + 货舱装卸穿梭车 + 钻井平台高光 + 矿仓液位动态计量表）
## - 地下多层地质纹理（表层风化层 / 软岩沉积带 / 硬岩玄武断层 + 右侧软岩裂隙通道 / 深部地核辉光）
## - 对标《星际航天 Astra》的青色光学追踪圆弧准星 `( | )`、矿体发光脉冲、双拐点折线绕行预览与右上角实时地震波声呐示波器

signal cross_section_action(action_id: String)

const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Assets = preload("res://scripts/services/asset_loader.gd")
const MiningFX = preload("res://scripts/ui/visual/mining_fx_layer.gd")
const RIG_FALLBACK = preload("res://assets/kenney/shooter/playerShip2_orange.png")
const SHIP_FALLBACK = preload("res://assets/kenney/shooter/playerShip3_green.png")

const INK: Color = Color("eef7ff")
const MUTED: Color = Color("8fa8be")
const AMBER: Color = Color("f0a04a")
const GOLD: Color = Color("f5b642")
const CYAN: Color = Color("38b6ff")
const CYAN_BRIGHT: Color = Color("6ce5ff")
const GREEN: Color = Color("4ce096")
const RED: Color = Color("f08c82")
const PURPLE: Color = Color("b888f8")
const DARK_GRAY: Color = Color("45525c")

var state: GameState
var star_id: String = ""
var hovered_deposit_idx: int = -1
var selected_deposit_idx: int = -1
var hovered_facility: String = ""
var _v6_fx: Control


func _ready() -> void:
	custom_minimum_size = Vector2(520, 340)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)
	_v6_fx = MiningFX.new()
	add_child(_v6_fx)
	_v6_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_v6_fx.set("source", self)


func emit_visual_event(command: String) -> void:
	if is_instance_valid(_v6_fx):
		_v6_fx.call("pulse_event", command)


func set_visual_reduced_motion(enabled: bool) -> void:
	if is_instance_valid(_v6_fx):
		_v6_fx.set("reduce_motion", enabled)


func _process(_delta: float) -> void:
	if visible and state != null:
		queue_redraw()


func _mineral_color(min_id: String) -> Color:
	match min_id:
		"iron_titanium": return AMBER
		"silicon_crystal": return CYAN_BRIGHT
		"energy_crystal": return PURPLE
		"phase_ore": return GOLD
		_: return AMBER


func _mineral_name(min_id: String) -> String:
	match min_id:
		"iron_titanium": return "铁钛矿"
		"silicon_crystal": return "晶硅矿"
		"energy_crystal": return "星能晶"
		"phase_ore": return "异相矿"
		_: return "铁钛矿"


func _cluster_sky_palette(cluster_id: String) -> Dictionary:
	match cluster_id:
		"crimson_sands":
			return {"top": Color("160b08"), "horizon": Color("542614"), "glow": Color(0.95, 0.52, 0.22, 0.32), "ridge": Color("2a1610")}
		"frost_ring":
			return {"top": Color("05131e"), "horizon": Color("123e56"), "glow": Color(0.32, 0.88, 0.96, 0.30), "ridge": Color("112938")}
		"molten_core":
			return {"top": Color("180707"), "horizon": Color("621c12"), "glow": Color(0.98, 0.36, 0.18, 0.36), "ridge": Color("2b110d")}
		"glimmer_deep":
			return {"top": Color("090618"), "horizon": Color("28164a"), "glow": Color(0.72, 0.45, 0.98, 0.32), "ridge": Color("19102c")}
		_:
			return {"top": Color("061220"), "horizon": Color("163c5c"), "glow": Color(0.24, 0.72, 1.0, 0.30), "ridge": Color("13283a")}


func _grid_to_screen(gx: int, gy: int, w: float, h: float, surf_y: float) -> Vector2:
	var px: float = clampf(float(gx) / 96.0, 0.08, 0.92) * w
	var py: float = surf_y + clampf(float(gy) / 48.0, 0.12, 0.90) * (h - surf_y - 28.0)
	return Vector2(px, py)


func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return

	var w: float = maxf(size.x, 360.0)
	var h: float = maxf(size.y, 260.0)
	var surf_y: float = clampf(h * 0.25, 78.0, 122.0)
	var deposits: Array = mine.get("deposits", [])

	if event is InputEventMouseMotion:
		var mpos: Vector2 = event.position
		var old_dep: int = hovered_deposit_idx
		var old_fac: String = hovered_facility
		hovered_deposit_idx = -1
		hovered_facility = ""
		if mpos.y < surf_y:
			if mpos.x < w * 0.28:
				hovered_facility = "landing_pad"
			elif mpos.x < w * 0.60:
				hovered_facility = "drill_platform"
			else:
				hovered_facility = "surface_silo"
		else:
			for idx in range(deposits.size()):
				var d: Dictionary = deposits[idx]
				var dpos: Vector2 = _grid_to_screen(int(d["gx"]), int(d["gy"]), w, h, surf_y)
				if mpos.distance_to(dpos) <= 44.0:
					hovered_deposit_idx = idx
					break
		if old_dep != hovered_deposit_idx or old_fac != hovered_facility:
			queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cross_section_action.emit("v40_route_mode")
		accept_event()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if pos.y < surf_y:
			if pos.x < w * 0.28:
				cross_section_action.emit("v40_launch_pad")
			elif pos.x >= w * 0.60:
				cross_section_action.emit("v40_upgrade:silo")
			elif int(mine.get("platforms", 0)) <= 0:
				cross_section_action.emit("v40_build_drill")
			else:
				cross_section_action.emit("v40_upgrade:platform")
			accept_event()
			return

		for idx in range(deposits.size()):
			var d: Dictionary = deposits[idx]
			var dpos: Vector2 = _grid_to_screen(int(d["gx"]), int(d["gy"]), w, h, surf_y)
			if pos.distance_to(dpos) <= 46.0:
				# Selection is free. Scan/build commands come only after explicit approval.
				cross_section_action.emit("v40_select_deposit:%d" % idx)
				accept_event()
				return

		# Empty underground click clears selection; no accidental paid scan.
		cross_section_action.emit("v40_select_deposit:-1")
		accept_event()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 20.0 or h < 20.0 or state == null:
		return

	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var surf_y: float = clampf(h * 0.25, 78.0, 122.0)
	var hard_rock_y: float = surf_y + (h - surf_y - 28.0) * 0.58
	var bneck: Dictionary = V40.analyze_mine_bottleneck(v40, mine_id)
	var eff_rate: float = float(bneck.get("effective_rate_t_day", 0.0))
	var lift_cap: float = float(bneck.get("platform_lift_cap_t_day", 60.0))
	var bore_cap: float = float(bneck.get("bore_flow_cap_t_day", 60.0))
	var stock_t: int = int(mine.get("silo_stock_t", 0))
	var cap_t: int = int(mine.get("silo_capacity_t", 300))
	var stalled: bool = stock_t >= cap_t or bool(mine.get("overflow_locked", false))
	var route_mode: String = str(v40.get("bore_route_mode", "auto"))
	var route_badge: String = "智能路线" if route_mode == "auto" else ("软岩折线绕行" if route_mode == "detour_soft" else "硬岩直穿")
	var sky_pal: Dictionary = _cluster_sky_palette(str(mine.get("cluster_id", "dawn_frontier")))

	# 1. 顶部 Astra 风格黑曜石玻璃标尺栏 + 亮青发光顶边
	draw_rect(Rect2(0, 0, w, h), Color("060e17"))
	draw_rect(Rect2(0, 0, w, 28), Color("091726"))
	draw_line(Vector2(6, 0), Vector2(w - 6, 0), CYAN_BRIGHT, 2.0)
	var header_txt: String = "【%s · %s】96×48剖面 | 路线:%s(右键切) | 产速:%.0ft/日 (主井%.0ft · 平台%.0ft)" % [
		str(mine["cluster_name_zh"]), str(mine["name_zh"]), route_badge, eff_rate, bore_cap, lift_cap
	]
	_draw_label(Vector2(10, 19), header_txt, 11, GOLD)

	# 2. 星团专属大气天际线、瑞利散射辉光与右上角实时地震波声呐示波器
	draw_rect(Rect2(0, 28, w, surf_y - 28.0), sky_pal["top"])
	draw_rect(Rect2(0, surf_y - 26.0, w, 26.0), sky_pal["glow"])
	var ridge: PackedVector2Array = PackedVector2Array([
		Vector2(0, surf_y), Vector2(0, surf_y - 16), Vector2(w * 0.18, surf_y - 28),
		Vector2(w * 0.42, surf_y - 12), Vector2(w * 0.68, surf_y - 26), Vector2(w, surf_y - 14), Vector2(w, surf_y)
	])
	draw_colored_polygon(ridge, sky_pal["ridge"])
	draw_line(Vector2(0, surf_y), Vector2(w, surf_y), CYAN, 2.0)

	# 右上角：实时地质声呐频谱示波器 (Seismic Sonar Oscilloscope)
	var sonar_rect := Rect2(w - 154.0, 32.0, 144.0, 28.0)
	draw_rect(sonar_rect, Color(0.03, 0.08, 0.14, 0.82))
	draw_rect(sonar_rect, Color(0.22, 0.68, 0.95, 0.45), false, 1.0)
	var wave_pts := PackedVector2Array()
	for s_i in range(24):
		var sx: float = sonar_rect.position.x + 6.0 + float(s_i) * 5.7
		var amp: float = (6.5 if eff_rate > 0.1 else 2.0) * sin(now_sec * 6.0 + float(s_i) * 0.65)
		wave_pts.append(Vector2(sx, sonar_rect.position.y + 15.0 + amp))
	draw_polyline(wave_pts, GREEN if eff_rate > 0.1 else CYAN, 1.4, true)
	_draw_label(sonar_rect.position + Vector2(6, 10), "SEISMIC %.1fG" % float(mine.get("gravity_g", 1.0)), 8, MUTED)

	# 地表左侧：对标参考图 2 & 4 的机械脐带发射塔架、低温液氧白雾与装船流光管线 (可点击立即点火发运)
	var pad_x: float = w * 0.14
	var pad_hover: bool = (hovered_facility == "landing_pad")
	draw_rect(Rect2(pad_x - 38, surf_y - 6, 76, 6), Color("58748a") if pad_hover else Color("4f6678"))
	# 机械脐带塔架立柱与横臂
	draw_rect(Rect2(pad_x - 28, surf_y - 48, 5, 42), Color("7390a6"))
	draw_line(Vector2(pad_x - 23, surf_y - 36), Vector2(pad_x - 8, surf_y - 36), CYAN_BRIGHT if pad_hover else Color("8aa8be"), 2.0)
	draw_line(Vector2(pad_x - 23, surf_y - 22), Vector2(pad_x - 8, surf_y - 22), CYAN_BRIGHT if pad_hover else Color("8aa8be"), 2.0)
	var ship_tex: Texture2D = Assets.get_tex("res://assets/custom/rocket_reuse.png", SHIP_FALLBACK)
	if ship_tex != null:
		draw_texture_rect(ship_tex, Rect2(pad_x - 14, surf_y - 48, 32, 43), false)
	# 箭体液氧加注低温白雾粒子
	for vp_i in range(4):
		var vp_u: float = fmod(now_sec * 0.75 + float(vp_i) * 0.25, 1.0)
		draw_circle(Vector2(pad_x - 12.0 - vp_u * 18.0, surf_y - 28.0 + vp_u * 5.0), 3.5 + vp_u * 4.5, Color(0.90, 0.97, 1.0, (1.0 - vp_u) * 0.30))
	if stock_t > 0:
		# 矿仓至起降台装船脉冲光点
		for ld_i in range(2):
			var ld_u: float = fmod(now_sec * 0.8 + float(ld_i) * 0.5, 1.0)
			var ld_x: float = lerpf(w * 0.40, pad_x + 12.0, ld_u)
			draw_circle(Vector2(ld_x, surf_y - 3.0), 2.8, GOLD)
	_draw_label(Vector2(pad_x - 46, surf_y - 54), "🚀 起降台 · 待运%dt [点此点火]" % stock_t if stock_t > 0 else "🚀 起降泊位 [点此点火/调船]", 11, GOLD if pad_hover else CYAN_BRIGHT)

	# 地表中央：2.5D 地表钻井平台 (Surface Drill Platform + 高清贴图)
	var rig_x: float = w * 0.44
	var plat_cnt: int = int(mine.get("platforms", 0))
	var plat_hover: bool = (hovered_facility == "drill_platform")
	if plat_cnt > 0:
		var rig_tex: Texture2D = Assets.get_tex("res://assets/custom/mining_rig_hd.png", RIG_FALLBACK)
		if rig_tex != null:
			draw_texture_rect(rig_tex, Rect2(rig_x - 26, surf_y - 52, 52, 50), false)
		else:
			draw_rect(Rect2(rig_x - 30, surf_y - 10, 60, 10), Color("5b6d7a"))
		if eff_rate > 0.1:
			# 激光钻杆能量脉冲束
			draw_line(Vector2(rig_x, surf_y - 18), Vector2(rig_x, surf_y + 14), GOLD, 3.2)
		_draw_label(Vector2(rig_x - 62, surf_y - 56), "⛏ 钻井台 ×%d (提升%.0ft/日·点此改造)" % [plat_cnt, lift_cap], 11, GOLD if plat_hover else GREEN)
	else:
		draw_rect(Rect2(rig_x - 46, surf_y - 44, 92, 42), GOLD if plat_hover else CYAN_BRIGHT, false, 1.6)
		_draw_label(Vector2(rig_x - 40, surf_y - 20), "➕ 建钻井台(8000Cr)", 11, GOLD if plat_hover else CYAN_BRIGHT)

	# 地表右侧：Astra 风格地表矿仓 (Surface Ore Silo + 液位刻度条)
	var silo_x: float = w * 0.72
	var silo_w: float = minf(138.0, w - silo_x - 14.0)
	var silo_hover: bool = (hovered_facility == "surface_silo")
	draw_rect(Rect2(silo_x, surf_y - 42, silo_w, 42), Color(0.05, 0.12, 0.20, 0.92))
	draw_rect(Rect2(silo_x, surf_y - 42, silo_w, 42), GOLD if silo_hover else (RED if stalled else CYAN), false, 1.6)
	var fill_ratio: float = clampf(float(stock_t) / float(maxi(1, cap_t)), 0.0, 1.0)
	draw_rect(Rect2(silo_x + 4, surf_y - 4, (silo_w - 8.0) * fill_ratio, -34.0 * fill_ratio), RED if stalled else AMBER)
	_draw_label(Vector2(silo_x - 4, surf_y - 48), "📦 矿仓 %d/%dt %s" % [stock_t, cap_t, "(点此+500t)" if not stalled else "⚠满仓/溢出!"], 11, RED if stalled else (GOLD if silo_hover else INK))

	# 地表穿梭运矿车动画 (钻井台 -> 矿仓 -> 起降场)
	if eff_rate > 0.1 and plat_cnt > 0:
		var shuttle_u: float = fmod(now_sec * 0.45, 1.0)
		var shuttle_x: float = lerpf(rig_x + 18.0, silo_x - 12.0, absf(shuttle_u * 2.0 - 1.0))
		draw_rect(Rect2(shuttle_x - 7, surf_y - 7, 14, 6), GOLD)
		draw_circle(Vector2(shuttle_x - 4, surf_y - 1), 2.0, DARK_GRAY)
		draw_circle(Vector2(shuttle_x + 4, surf_y - 1), 2.0, DARK_GRAY)

	# 3. 地下多层地质结构 (96×48 逻辑格：浅层软岩带 / 硬岩玄武断层 / 深层富矿基底)
	draw_rect(Rect2(0, surf_y, w, hard_rock_y - surf_y), Color("111922"))
	draw_rect(Rect2(0, hard_rock_y, w, h - hard_rock_y - 26.0), Color("0c1018"))
	# 岩层沉积纹理线
	for st_i in range(1, 5):
		var sy_line: float = surf_y + (hard_rock_y - surf_y) * float(st_i) / 5.0
		draw_line(Vector2(0, sy_line), Vector2(w, sy_line), Color(0.35, 0.52, 0.68, 0.07), 1.0)

	# 硬岩夹层分界带 + 右侧软岩断层绕行通道
	draw_rect(Rect2(0, hard_rock_y - 6, w * 0.78, 12), Color("323d4a"))
	draw_line(Vector2(0, hard_rock_y - 6), Vector2(w * 0.78, hard_rock_y - 6), Color("5d7185"), 1.2)
	draw_rect(Rect2(w * 0.78, hard_rock_y - 5, w * 0.22, 10), Color(0.22, 0.78, 0.96, 0.20))
	_draw_label(Vector2(10, hard_rock_y + 15), "🪨 硬岩玄武夹层（直穿 8格×300Cr 需M1；或从右侧裂隙折线绕行 14格×100Cr）", 10, MUTED)

	for gx_i in range(1, 8):
		var lx: float = w * float(gx_i) / 8.0
		draw_line(Vector2(lx, surf_y), Vector2(lx, h - 26.0), Color(1, 1, 1, 0.03), 1.0)
	for gy_i in range(1, 4):
		var ly: float = surf_y + (h - surf_y - 26.0) * float(gy_i) / 4.0
		draw_line(Vector2(0, ly), Vector2(w, ly), Color(1, 1, 1, 0.03), 1.0)

	# 4. 绘制矿体、树形井道网络（含折线绕行拐点）与 Astra 光学追踪准星
	var drill_root: Vector2 = Vector2(rig_x, surf_y)
	var main_trunk_bottom: Vector2 = Vector2(rig_x, surf_y + (h - surf_y) * 0.42)
	if plat_cnt > 0:
		draw_line(drill_root, main_trunk_bottom, Color("7e97a8"), 3.8, true)

	var deposits: Array = mine.get("deposits", [])
	for idx in range(deposits.size()):
		var d: Dictionary = deposits[idx]
		var dpos: Vector2 = _grid_to_screen(int(d["gx"]), int(d["gy"]), w, h, surf_y)
		var is_rev: bool = bool(d.get("revealed", false))
		var heads: int = int(d.get("heads", 0))
		var rem_t: int = int(d.get("remaining_t", 0))
		var min_col: Color = _mineral_color(str(d.get("mineral_id", "iron_titanium")))
		var min_name: String = _mineral_name(str(d.get("mineral_id", "iron_titanium")))
		var is_hov: bool = (hovered_deposit_idx == idx or selected_deposit_idx == idx)

		if not is_rev:
			var pulse: float = 0.38 + 0.22 * sin(now_sec * 3.2 + float(idx))
			draw_circle(dpos, 26.0, Color(0.22, 0.75, 1.0, pulse * 0.22))
			draw_arc(dpos, 26.0, 0.0, TAU, 28, Color(0.22, 0.75, 1.0, pulse), 1.6, true)
			if is_hov:
				# 悬停扫描范围半径 8 格预览圈 + 360度声呐扫描旋转扇面
				var scan_rad_px: float = maxf(38.0, (8.0 / 96.0) * w)
				draw_arc(dpos, scan_rad_px, 0.0, TAU, 36, GOLD, 1.5, true)
				var sweep_ang: float = fmod(now_sec * 3.6, TAU)
				draw_line(dpos, dpos + Vector2(cos(sweep_ang), sin(sweep_ang)) * scan_rad_px, Color(0.42, 0.92, 1.0, 0.75), 1.8)
			_draw_label(dpos + Vector2(-48, 4), "📡 模糊矿化信号 (点击选择)", 11, GOLD if is_hov else CYAN_BRIGHT)
		else:
			var plan: Dictionary = V40.calc_bore_plan(v40, mine_id, idx)
			var is_detour_line: bool = bool(d.get("used_detour", false)) if heads > 0 else bool(plan.get("use_detour", false))
			var knee1: Vector2 = Vector2(w * 0.83, hard_rock_y - 14.0)
			var knee2: Vector2 = Vector2(w * 0.83, dpos.y)
			var branch_junction: Vector2 = Vector2(rig_x, clampf(dpos.y, surf_y + 24.0, h - 42.0))

			if heads > 0 and plat_cnt > 0:
				var line_col: Color = GREEN if rem_t > 0 else MUTED
				if is_detour_line:
					draw_line(drill_root, knee1, Color("9ab2c2"), 3.0, true)
					draw_line(knee1, knee2, CYAN_BRIGHT, 3.0, true)
					draw_line(knee2, dpos, line_col, 3.0, true)
					draw_circle(knee1, 4.2, CYAN_BRIGHT)
					draw_circle(knee2, 4.2, CYAN_BRIGHT)
				else:
					draw_line(drill_root, branch_junction, Color("9ab2c2"), 3.4, true)
					draw_line(branch_junction, dpos, line_col, 3.0, true)
				if eff_rate > 0.1 and rem_t > 0:
					for p_i in range(3):
						var u_p: float = fmod(now_sec * 0.95 + float(p_i) * 0.33, 1.0)
						var p_pt: Vector2 = dpos.lerp(branch_junction, u_p * 0.6) if u_p < 0.6 else branch_junction.lerp(drill_root, (u_p - 0.6) / 0.4)
						draw_circle(p_pt, 4.0, min_col)
			elif is_hov and plat_cnt > 0:
				var prev_col: Color = Color(0.42, 0.90, 1.0, 0.85) if is_detour_line else Color(0.96, 0.72, 0.26, 0.82)
				if is_detour_line:
					draw_line(drill_root, knee1, prev_col, 2.4, true)
					draw_line(knee1, knee2, prev_col, 2.4, true)
					draw_line(knee2, dpos, prev_col, 2.4, true)
					draw_circle(knee1, 4.5, GOLD)
					draw_circle(knee2, 4.5, GOLD)
				else:
					draw_line(drill_root, branch_junction, prev_col, 2.4, true)
					draw_line(branch_junction, dpos, prev_col, 2.4, true)

			var rad: float = clampf(14.0 + float(rem_t) / 140.0, 15.0, 32.0)
			draw_circle(dpos, rad + 7.0, Color(min_col.r, min_col.g, min_col.b, 0.25))
			draw_circle(dpos, rad, min_col if rem_t > 0 else DARK_GRAY)
			_draw_vein_facets_and_sparks(dpos, rad, min_col, heads, rem_t, eff_rate, now_sec, idx)

			# Astra 风格青色双圆弧光学锁定准星 `( | )` 与半径 4 格采掘范围
			if heads > 0 or is_hov:
				var head_rad_px: float = maxf(rad + 9.0, (4.0 / 96.0) * w)
				var bracket_col: Color = GOLD if is_hov else (GREEN if rem_t > 0 else RED)
				draw_arc(dpos, head_rad_px, PI * 0.70, PI * 1.30, 20, bracket_col, 2.0, true)
				draw_arc(dpos, head_rad_px, -PI * 0.30, PI * 0.30, 20, bracket_col, 2.0, true)

			var tag_str: String = "%s (%s · 余 %d t)" % [str(d["name_zh"]), min_name, rem_t]
			var sub_str: String = ""
			if heads > 0 and rem_t <= 0:
				sub_str = "⚠ 已采空！可点左侧【迁移采掘头(500Cr)】移往新矿脉"
			elif heads > 0:
				sub_str = "✓ 采掘头 ×%d (点击选择，右栏可增设)" % heads
			else:
				sub_str = "▶ 点击查看方案：%s · %d Cr (%.1f日)" % [str(plan["route_desc_zh"]), int(plan["total_cost_cr"]), float(plan["work_days"])]
			_draw_label(dpos + Vector2(-58, rad + 15.0), tag_str, 11, GOLD if is_hov else INK)
			_draw_label(dpos + Vector2(-58, rad + 29.0), sub_str, 10, RED if (heads > 0 and rem_t <= 0) else (GREEN if heads > 0 else (GOLD if is_hov else CYAN_BRIGHT)))

	# Persistent selected target ring, distinct from transient mouse hover.
	if selected_deposit_idx >= 0 and selected_deposit_idx < deposits.size():
		var chosen_dep: Dictionary = deposits[selected_deposit_idx]
		var chosen_pos: Vector2 = _grid_to_screen(int(chosen_dep["gx"]), int(chosen_dep["gy"]), w, h, surf_y)
		draw_arc(chosen_pos, 40.0, 0.0, TAU, 52, GOLD, 2.2, true)

	# 5. 底部 Astra 风格实时瓶颈解释与操作预览条 (第 16.3 & 16.4 节)
	draw_rect(Rect2(0, h - 26.0, w, 26.0), Color("081523"))
	draw_line(Vector2(6, h - 26.0), Vector2(w - 6, h - 26.0), Color(0.22, 0.72, 0.98, 0.45), 1.2)
	var preview_line: String = "💡 瓶颈诊断：" + str(bneck.get("bottleneck_text", ""))
	if hovered_deposit_idx >= 0 and hovered_deposit_idx < deposits.size():
		var hd: Dictionary = deposits[hovered_deposit_idx]
		if not bool(hd.get("revealed", false)):
			var scan_c: int = 0 if int(v40.get("free_scans_left", 0)) > 0 else 300
			preview_line = "🔍【地面扫描预览】费用: %d Cr | 范围半径: 8 格 | 立即揭示该区域矿体边界与储量" % scan_c
		else:
			var hplan: Dictionary = V40.calc_bore_plan(v40, mine_id, hovered_deposit_idx)
			preview_line = "🔍【钻探预览】%s | 费用 %d Cr | 工期 %.1f 日 | 可连接储量 %d t (+40 t/日)" % [
				str(hplan["route_desc_zh"]), int(hplan["total_cost_cr"]), float(hplan["work_days"]), int(hplan["connect_reserve_t"])
			]
	elif hovered_facility == "landing_pad":
		var win_m: String = str(v40.get("launch_window_mode", "standard"))
		var win_z: String = "☀晴空顺风(运费-8%)" if win_m == "optimal" else ("⛅标准窗口" if win_m == "standard" else "⚡引力快航(周期-15%)")
		preview_line = "🚀【地表起降泊位】当前矿仓待运 %d/%d t | 发射窗口: %s | 左键预览发运操作并确认。" % [stock_t, cap_t, win_z]
	elif hovered_facility == "drill_platform":
		preview_line = "⛏【地表钻井台】当前提升上限 %.0f t/日 | 点击预览平台升级 (60→100 t/日，9,000 Cr)" % lift_cap
	elif hovered_facility == "surface_silo":
		preview_line = "📦【地表矿仓】当前库存 %d/%d t | 点击预览扩建仓容 (+500 t，6,000 Cr)" % [stock_t, cap_t]
	_draw_label(Vector2(10, h - 8.0), preview_line, 11, GOLD if (hovered_deposit_idx >= 0 or hovered_facility != "") else CYAN_BRIGHT)


func _draw_vein_facets_and_sparks(dpos: Vector2, rad: float, min_col: Color, heads: int, rem_t: int, eff_rate: float, now_sec: float, idx: int) -> void:
	# 绘制 2.5D 多面体晶簇切面高光与采掘头激光切削火花粒子 (第 6.8 & 16.8 节)
	if rem_t > 0:
		var facet_pts := PackedVector2Array()
		for f_i in range(6):
			var fang: float = TAU * float(f_i) / 6.0 + float(idx) * 0.5
			var fr: float = rad * (0.58 if f_i % 2 == 0 else 0.38)
			facet_pts.append(dpos + Vector2(cos(fang) * fr, sin(fang) * fr))
		draw_colored_polygon(facet_pts, Color(1.0, 1.0, 1.0, 0.42))
		var glint: float = 0.55 + 0.45 * sin(now_sec * 4.5 + float(idx) * 1.7)
		draw_circle(dpos + Vector2(-rad * 0.22, -rad * 0.22), rad * 0.22, Color(1.0, 1.0, 1.0, glint))
	else:
		draw_circle(dpos, rad * 0.35, Color("2b343c"))

	if heads > 0 and rem_t > 0 and eff_rate > 0.1:
		# 采掘波纹扩散环与飞溅火花微粒子
		var wave_p: float = fmod(now_sec * 1.4 + float(idx) * 0.3, 1.0)
		draw_arc(dpos, rad + wave_p * 14.0, 0.0, TAU, 24, Color(min_col.r, min_col.g, min_col.b, (1.0 - wave_p) * 0.65), 1.4, true)
		for sp_i in range(5):
			var s_phase: float = fmod(now_sec * 3.8 + float(sp_i) * 0.2, 1.0)
			var s_ang: float = -PI * 0.8 + float(sp_i) * 0.42 + sin(now_sec * 5.0 + float(sp_i)) * 0.15
			var s_dist: float = rad * 0.5 + s_phase * 16.0
			var sp_pt: Vector2 = dpos + Vector2(cos(s_ang) * s_dist, sin(s_ang) * s_dist)
			draw_circle(sp_pt, 2.2 * (1.0 - s_phase * 0.5), GOLD if sp_i % 2 == 0 else Color.WHITE)


func _draw_label(pos: Vector2, text: String, fsize: int, col: Color) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0, 0, 0, 0.78))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, col)
