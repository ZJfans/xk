class_name PlanetCrossSectionView
extends Control

## 《星矿大亨 Rocket Prospectors》V4.0 · 第 6 & 16 章【96×48 逻辑格横向二维矿场剖面视图】
## 严格遵循 V4.0 方案第 6 章「矿场结构、扫描与钻探」与第 16.2–16.4 章「矿场布局与操作预览」：
## - 96 × 48 逻辑格（每格 5 米，480m × 240m 剖面），平滑绘制地形、硬岩夹层、已揭示区域与未知迷雾
## - 展示每个地表钻井平台对应的【地下树形输送网络（主井 → 分支井道 → 采掘头）】
## - 明确展示采掘头【半径 4 格局部连通采掘范围】（不会碰边缘自动抽空整条矿脉）
## - 鼠标悬停在矿体/设施上时，同屏实时预览【施工总费用、穿越软/硬岩格数、预计接入储量】

signal cross_section_action(action_id: String)

const V40 = preload("res://scripts/core/v40_dawn_engine.gd")

const INK: Color = Color("f4fbff")
const MUTED: Color = Color("9bb0be")
const AMBER: Color = Color("f0a04a")
const GOLD: Color = Color("f2b55c")
const CYAN: Color = Color("49d6e4")
const GREEN: Color = Color("83c7a6")
const RED: Color = Color("f08c82")
const PURPLE: Color = Color("b888f8")

var state: GameState
var star_id: String = ""
var hovered_deposit_idx: int = -1
var hovered_facility: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(520, 340)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)


func _process(_delta: float) -> void:
	if visible and state != null:
		queue_redraw()


func _mineral_color(min_id: String) -> Color:
	match min_id:
		"iron_titanium": return AMBER
		"silicon_crystal": return CYAN
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
	var surf_y: float = clampf(h * 0.25, 74.0, 118.0)
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

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if pos.y < surf_y:
			if pos.x >= w * 0.60:
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
				if not bool(d.get("revealed", false)):
					cross_section_action.emit("v40_scan")
				else:
					cross_section_action.emit("v40_head:%d" % idx)
				accept_event()
				return

		# 点击空白未知地层默认执行地面扫描
		cross_section_action.emit("v40_scan")
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
	var surf_y: float = clampf(h * 0.25, 74.0, 118.0)
	var hard_rock_y: float = surf_y + (h - surf_y - 28.0) * 0.58
	var bneck: Dictionary = V40.analyze_mine_bottleneck(v40, mine_id)
	var eff_rate: float = float(bneck.get("effective_rate_t_day", 0.0))
	var lift_cap: float = float(bneck.get("platform_lift_cap_t_day", 60.0))
	var bore_cap: float = float(bneck.get("bore_flow_cap_t_day", 60.0))
	var stock_t: int = int(mine.get("silo_stock_t", 0))
	var cap_t: int = int(mine.get("silo_capacity_t", 300))
	var stalled: bool = stock_t >= cap_t

	# 1. 背景与顶部 96×48 逻辑格标尺栏
	draw_rect(Rect2(0, 0, w, h), Color("07111a"))
	draw_rect(Rect2(0, 0, w, 26), Color("0f2030"))
	var header_txt: String = "【%s · %s】96×48 逻辑格剖面 (480m×240m)  |  状态: %s  |  实际产量: %.0f t/日 (主井上限 %.0f t/日 · 平台提升 %.0f t/日)" % [
		str(mine["cluster_name_zh"]), str(mine["name_zh"]),
		"运行中" if str(mine.get("status", "running")) == "running" else ("已暂停(25%维护)" if str(mine["status"]) == "paused" else "已封存"),
		eff_rate, bore_cap, lift_cap
	]
	_draw_label(Vector2(10, 18), header_txt, 11, GOLD)

	# 2. 地表天空、远景地貌与三大地表设施 (起降场 / 钻井平台 / 地表矿仓)
	draw_rect(Rect2(0, 26, w, surf_y - 26.0), Color("0c1c2c"))
	var ridge: PackedVector2Array = PackedVector2Array([
		Vector2(0, surf_y), Vector2(0, surf_y - 14), Vector2(w * 0.20, surf_y - 24),
		Vector2(w * 0.45, surf_y - 10), Vector2(w * 0.72, surf_y - 26), Vector2(w, surf_y - 14), Vector2(w, surf_y)
	])
	draw_colored_polygon(ridge, Color("172b3a"))
	draw_line(Vector2(0, surf_y), Vector2(w, surf_y), Color("6e8799"), 2.0)

	# 地表左侧：起降设施与运矿船状态
	var pad_x: float = w * 0.14
	draw_rect(Rect2(pad_x - 32, surf_y - 5, 64, 5), Color("4f6678"))
	draw_rect(Rect2(pad_x - 10, surf_y - 36, 14, 31), Color("cfdbe4"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(pad_x - 10, surf_y - 36), Vector2(pad_x + 4, surf_y - 36), Vector2(pad_x - 3, surf_y - 46)
	]), GOLD)
	_draw_label(Vector2(pad_x - 36, surf_y - 50), "🚀 起降设施 (自动装卸)", 11, CYAN)

	# 地表中央：地表钻井平台 (Surface Drill Platform)
	var rig_x: float = w * 0.44
	var plat_cnt: int = int(mine.get("platforms", 0))
	var plat_hover: bool = (hovered_facility == "drill_platform")
	if plat_cnt > 0:
		draw_rect(Rect2(rig_x - 30, surf_y - 10, 60, 10), Color("5b6d7a"))
		draw_line(Vector2(rig_x - 18, surf_y - 10), Vector2(rig_x - 6, surf_y - 50), Color("c4d4de"), 2.5)
		draw_line(Vector2(rig_x + 18, surf_y - 10), Vector2(rig_x + 6, surf_y - 50), Color("c4d4de"), 2.5)
		draw_rect(Rect2(rig_x - 12, surf_y - 56, 24, 8), GOLD if plat_hover else AMBER)
		_draw_label(Vector2(rig_x - 58, surf_y - 60), "⛏ 钻井平台 ×%d (提升 %.0ft/日 · 点此改造)" % [plat_cnt, lift_cap], 11, GOLD if plat_hover else GREEN)
	else:
		draw_rect(Rect2(rig_x - 42, surf_y - 44, 84, 42), GOLD if plat_hover else CYAN, false, 1.6)
		_draw_label(Vector2(rig_x - 38, surf_y - 20), "➕ 建钻井平台(8000Cr)", 11, GOLD if plat_hover else CYAN)

	# 地表右侧：地表矿仓 (Surface Ore Silo)
	var silo_x: float = w * 0.72
	var silo_w: float = minf(130.0, w - silo_x - 14.0)
	var silo_hover: bool = (hovered_facility == "surface_silo")
	draw_rect(Rect2(silo_x, surf_y - 40, silo_w, 40), Color(0.08, 0.15, 0.22, 0.90))
	draw_rect(Rect2(silo_x, surf_y - 40, silo_w, 40), GOLD if silo_hover else (RED if stalled else Color("4a687d")), false, 1.6)
	var fill_ratio: float = clampf(float(stock_t) / float(maxi(1, cap_t)), 0.0, 1.0)
	draw_rect(Rect2(silo_x + 3, surf_y - 4, (silo_w - 6.0) * fill_ratio, -32.0 * fill_ratio), RED if stalled else AMBER)
	_draw_label(Vector2(silo_x - 4, surf_y - 46), "📦 地表矿仓 %d / %d t %s" % [stock_t, cap_t, "(点此扩容+500t)" if not stalled else "⚠满仓停产!"], 11, RED if stalled else (GOLD if silo_hover else INK))

	# 3. 地下软岩层与硬岩夹层 (96×48 逻辑格)
	draw_rect(Rect2(0, surf_y, w, hard_rock_y - surf_y), Color("161d24"))
	draw_rect(Rect2(0, hard_rock_y, w, h - hard_rock_y - 26.0), Color("12141c"))
	# 硬岩夹层分界带 (300 Cr/格 · 需 M1 硬岩钻头)
	draw_rect(Rect2(0, hard_rock_y - 5, w, 10), Color("36404a"))
	_draw_label(Vector2(10, hard_rock_y + 15), "🪨 硬岩夹层分界线（上方软岩井道 100 Cr/格；下方硬岩井道 300 Cr/格，需【M1 · 硬岩钻头】）", 10, MUTED)

	# 逻辑网格暗线 (每 12 格一条参考线)
	for gx_i in range(1, 8):
		var lx: float = w * float(gx_i) / 8.0
		draw_line(Vector2(lx, surf_y), Vector2(lx, h - 26.0), Color(1, 1, 1, 0.03), 1.0)
	for gy_i in range(1, 4):
		var ly: float = surf_y + (h - surf_y - 26.0) * float(gy_i) / 4.0
		draw_line(Vector2(0, ly), Vector2(w, ly), Color(1, 1, 1, 0.03), 1.0)

	# 4. 绘制矿体、树形井道网络与采掘头（半径 4 格局部连通采掘范围）
	var drill_root: Vector2 = Vector2(rig_x, surf_y)
	var main_trunk_bottom: Vector2 = Vector2(rig_x, surf_y + (h - surf_y) * 0.42)
	if plat_cnt > 0:
		draw_line(drill_root, main_trunk_bottom, Color("7e97a8"), 3.6, true)

	var deposits: Array = mine.get("deposits", [])
	for idx in range(deposits.size()):
		var d: Dictionary = deposits[idx]
		var dpos: Vector2 = _grid_to_screen(int(d["gx"]), int(d["gy"]), w, h, surf_y)
		var is_rev: bool = bool(d.get("revealed", false))
		var heads: int = int(d.get("heads", 0))
		var rem_t: int = int(d.get("remaining_t", 0))
		var min_col: Color = _mineral_color(str(d.get("mineral_id", "iron_titanium")))
		var min_name: String = _mineral_name(str(d.get("mineral_id", "iron_titanium")))
		var is_hov: bool = (hovered_deposit_idx == idx)

		if not is_rev:
			# 未知区域：只显示模糊矿化回波，不显示真实矿体轮廓 (第 6.1 & 6.3 节)
			var pulse: float = 0.35 + 0.20 * sin(now_sec * 3.0 + float(idx))
			draw_circle(dpos, 26.0, Color(0.29, 0.84, 0.89, pulse * 0.25))
			draw_arc(dpos, 26.0, 0.0, TAU, 28, Color(0.29, 0.84, 0.89, pulse), 1.5, true)
			_draw_label(dpos + Vector2(-48, 4), "📡 模糊矿化信号 (点击扫描)", 11, GOLD if is_hov else CYAN)
		else:
			# 已揭示矿体：绘制树形分支井道、矿体轮廓与采掘头半径 4 格范围圆
			var branch_junction: Vector2 = Vector2(rig_x, clampf(dpos.y, surf_y + 24.0, h - 42.0))
			if heads > 0 and plat_cnt > 0:
				draw_line(drill_root, branch_junction, Color("9ab2c2"), 3.2, true)
				draw_line(branch_junction, dpos, GREEN if rem_t > 0 else MUTED, 2.8, true)
				if eff_rate > 0.1 and rem_t > 0:
					for p_i in range(3):
						var u_p: float = fmod(now_sec * 0.9 + float(p_i) * 0.33, 1.0)
						var p_pt: Vector2 = dpos.lerp(branch_junction, u_p * 0.6) if u_p < 0.6 else branch_junction.lerp(drill_root, (u_p - 0.6) / 0.4)
						draw_circle(p_pt, 3.8, min_col)
			elif is_hov and plat_cnt > 0:
				# 悬停预览施工路线 (第 6.5 & 16.3 节)
				draw_line(drill_root, branch_junction, Color(0.95, 0.72, 0.35, 0.65), 2.0, true)
				draw_line(branch_junction, dpos, Color(0.95, 0.72, 0.35, 0.65), 2.0, true)

			var rad: float = clampf(14.0 + float(rem_t) / 140.0, 15.0, 32.0)
			draw_circle(dpos, rad + 6.0, Color(min_col.r, min_col.g, min_col.b, 0.22))
			draw_circle(dpos, rad, min_col if rem_t > 0 else DARK_GRAY)
			draw_circle(dpos, rad * 0.45, Color.WHITE)

			if heads > 0:
				# 采掘头半径 4 格采掘范围虚线圆 (第 6.4 节)
				var head_rad_px: float = (4.0 / 96.0) * w
				draw_arc(dpos, maxf(rad + 8.0, head_rad_px), 0.0, TAU, 32, GREEN, 1.6, true)

			var tag_str: String = "%s (%s · 余 %d t)" % [str(d["name_zh"]), min_name, rem_t]
			var sub_str: String = "✓ 采掘头 ×%d (点击增设 +40t/日)" % heads if heads > 0 else "▶ 点击连通井道并装采掘头 (2800 Cr)"
			if bool(d.get("hard_rock", false)) and heads == 0:
				sub_str = "▶ 硬岩深矿：连通井道+采掘头 (4400 Cr · 需M1)"
			_draw_label(dpos + Vector2(-58, rad + 15.0), tag_str, 11, GOLD if is_hov else INK)
			_draw_label(dpos + Vector2(-58, rad + 29.0), sub_str, 10, GREEN if heads > 0 else (GOLD if is_hov else CYAN))

	# 5. 底部实时瓶颈解释与操作预览条 (第 16.3 & 16.4 节)
	draw_rect(Rect2(0, h - 26.0, w, 26.0), Color("0b1824"))
	var preview_line: String = "💡 瓶颈诊断：" + str(bneck.get("bottleneck_text", ""))
	if hovered_deposit_idx >= 0 and hovered_deposit_idx < deposits.size():
		var hd: Dictionary = deposits[hovered_deposit_idx]
		if not bool(hd.get("revealed", false)):
			var scan_c: int = 0 if int(v40.get("free_scans_left", 0)) > 0 else 300
			preview_line = "🔍【地面扫描预览】费用: %d Cr | 范围半径: 8 格 | 立即揭示该区域矿体边界与储量" % scan_c
		else:
			var is_hr: bool = bool(hd.get("hard_rock", false))
			var b_cost: int = (8 * (300 if is_hr else 100)) if int(hd.get("heads", 0)) == 0 else 0
			preview_line = "🔍【钻探与采掘头施工预览】目标: %s | 穿越%s 8 格 (%d Cr) + 采掘头 (2,000 Cr) = 总预算 %d Cr | 预计接入储量: %d t (+40 t/日)" % [
				str(hd["name_zh"]), "硬岩" if is_hr else "软岩", b_cost, b_cost + 2000, int(hd.get("remaining_t", 0))
			]
	_draw_label(Vector2(10, h - 8.0), preview_line, 11, GOLD if hovered_deposit_idx >= 0 else CYAN)


const DARK_GRAY: Color = Color("45525c")

func _draw_label(pos: Vector2, text: String, fsize: int, col: Color) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, Color(0, 0, 0, 0.75))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, col)
