class_name LaunchRecoveryView
extends Control

## 《星矿大亨 Rocket Prospectors》V4.0 · 对标《星际航天 Astra / Orbital Tycoon》写实级起降与回收指挥中心
## 严格遵循 V4.0 方案第 8.2、8.4、16.1、16.8 与 18.10 节及用户参考图美学：
## - 三大写实视角无缝切换：📷 主视角(暮光海上驳船回收) / 🎥 跟随视角(落日海滨重型发射台) / ⚓ 平台视角(晴空海滨整备场)
## - 顶部五节点任务时序轴（发射 → 分离 → 返回 → 着陆 → 完成）与右侧 T+ 精确任务时序表
## - 中央箭体光学追踪圆弧准星、四角锁定框与高度刻度标尺
## - 左侧助推器回收遥测卡（回收燃料 8.6%、着陆姿态 0.8°、结构损耗 4.2%、复用次数 N/10）与双半球姿态仪 (Navball)
## - 右侧回收成功率圆环、载荷/燃料加注条、控制指令盒 + 底部发射窗口与气象评估三联牌 (对标参考图 2 & 4)

signal request_fullscreen_hud()
signal trigger_quick_dispatch()
signal trigger_ship_overhaul(ship_id: int)
signal trigger_launch_window_cycle()

const Assets = preload("res://scripts/services/asset_loader.gd")
const FALLBACK_BG = preload("res://assets/concept/lunar_base_reference.png")

const INK: Color = Color("eef7ff")
const MUTED: Color = Color("8fa8be")
const GOLD: Color = Color("f5b642")
const AMBER: Color = Color("f08c42")
const GREEN: Color = Color("4ce096")
const RED: Color = Color("f08c82")
const CYAN: Color = Color("38b6ff")
const CYAN_BRIGHT: Color = Color("6ce5ff")
const PANEL_BG: Color = Color(0.03, 0.08, 0.14, 0.84)
const PANEL_BORDER: Color = Color(0.22, 0.65, 0.92, 0.55)

var state: GameState
var compact_mode: bool = true
var camera_mode: String = "main" # "main" (暮光海上回收), "follow" (落日重型发射), "pad" (晴空海滨整备)
var selected_ship_index: int = 0
var last_launch_msec: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(292, 148) if compact_mode else Vector2(880, 520)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)


func notify_launch() -> void:
	last_launch_msec = Time.get_ticks_msec()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		var w: float = size.x
		var h: float = size.y
		if compact_mode:
			# 在右侧紧凑实况窗点击底部可切换视角，点击上半部可一键展开全屏 Astra 指挥中心
			if pos.y > h - 28.0:
				_cycle_camera()
			else:
				request_fullscreen_hud.emit()
			accept_event()
			return

		# 全屏模式下：点击左上角助推器回收遥测卡 (x <= 268, y in 56..274) 可切换查看旗下不同在役运矿船的独立遥测档案
		if pos.x <= 268.0 and pos.y >= 56.0 and pos.y <= 274.0:
			selected_ship_index += 1
			queue_redraw()
			accept_event()
			return

		# 全屏模式下：检测左下角视角切换按钮 (主视角 / 跟随视角 / 平台视角)
		if pos.x <= 156.0 and pos.y >= h - 132.0:
			var rel_y: float = pos.y - (h - 108.0)
			if rel_y < 32.0:
				camera_mode = "main"
			elif rel_y < 64.0:
				camera_mode = "follow"
			else:
				camera_mode = "pad"
			queue_redraw()
			accept_event()
			return

		# 全屏模式下：检测底部居中右侧「发射窗口与天气状况 [点此切窗口]」区域 (对标参考图 2 & 4)
		var bot_w: float = 540.0
		var bot_x: float = (w - bot_w) * 0.5
		if pos.x >= bot_x + 250.0 and pos.x <= bot_x + bot_w and pos.y >= h - 68.0:
			trigger_launch_window_cycle.emit()
			accept_event()
			return

		# 全屏模式下：检测右中「任务与回收评估」面板底部的发射窗口切换条
		if pos.x >= w - 252.0 and pos.y >= 384.0 and pos.y <= 426.0:
			trigger_launch_window_cycle.emit()
			accept_event()
			return

		# 全屏模式下：检测右中下「控制指令：✥ 姿态微调与结构检修 (-1200Cr)」按钮区域
		if pos.x >= w - 252.0 and pos.y >= h - 148.0 and pos.y < h - 72.0:
			var v40_s: Dictionary = state.stats.get("v40", {}) if (state != null and state.stats.has("v40")) else {}
			var ships_list: Array = v40_s.get("ships", [])
			var sid_emit: int = 1
			if not ships_list.is_empty():
				var idx_sel: int = posmod(selected_ship_index, ships_list.size())
				sid_emit = int(ships_list[idx_sel].get("id", 1))
			trigger_ship_overhaul.emit(sid_emit)
			accept_event()
			return

		# 全屏模式下：检测右下角金色【🚀 发射 / 调度航次】按钮
		if pos.x >= w - 252.0 and pos.y >= h - 72.0:
			notify_launch()
			trigger_quick_dispatch.emit()
			accept_event()
			return


func _cycle_camera() -> void:
	if camera_mode == "main":
		camera_mode = "follow"
	elif camera_mode == "follow":
		camera_mode = "pad"
	else:
		camera_mode = "main"
	queue_redraw()


func _active_backdrop() -> Texture2D:
	match camera_mode:
		"follow":
			return Assets.get_tex("res://assets/custom/bg_launch_sunset_clean.png", FALLBACK_BG)
		"pad":
			return Assets.get_tex("res://assets/custom/bg_pad_daylight_clean.png", FALLBACK_BG)
		_:
			return Assets.get_tex("res://assets/custom/bg_recovery_dusk_clean.png", FALLBACK_BG)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 20.0 or h < 20.0:
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var v40: Dictionary = state.stats.get("v40", {}) if (state != null and state.stats.has("v40")) else {}
	var v40_ships: Array = v40.get("ships", [])
	var active_mine_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var active_mine: Dictionary = v40.get("mines", {}).get(active_mine_id, {})
	var mine_name: String = str(active_mine.get("name_zh", "晨曦一号矿区"))
	var grav_g: float = float(active_mine.get("gravity_g", 1.0))
	var dist_l: float = float(active_mine.get("distance_l", 0.5))
	var primary_min: String = str(active_mine.get("primary_mineral", "iron_titanium"))
	var port_name: String = "晨曦贸易港" if str(v40.get("active_port_id", "dawn_port")) == "dawn_port" else "赤曜深空港"
	var win_mode: String = str(v40.get("launch_window_mode", "standard"))

	var featured_ship: Dictionary = {}
	if not v40_ships.is_empty():
		if compact_mode:
			featured_ship = v40_ships[v40_ships.size() - 1]
			for s in v40_ships:
				if str(s.get("assigned_mine_id", "")) == active_mine_id:
					featured_ship = s
					break
		else:
			var idx_s: int = posmod(selected_ship_index, v40_ships.size())
			featured_ship = v40_ships[idx_s]
			var s_mine_id: String = str(featured_ship.get("assigned_mine_id", active_mine_id))
			if v40.get("mines", {}).has(s_mine_id):
				active_mine = v40["mines"][s_mine_id]
				mine_name = str(active_mine.get("name_zh", mine_name))
				grav_g = float(active_mine.get("gravity_g", grav_g))
				dist_l = float(active_mine.get("distance_l", dist_l))
				primary_min = str(active_mine.get("primary_mineral", primary_min))

	var min_names: Dictionary = {
		"iron_titanium": "铁钛矿",
		"silicon_crystal": "晶硅矿",
		"energy_crystal": "星能晶",
		"phase_ore": "异相矿"
	}
	var payload_min_zh: String = str(min_names.get(primary_min, "铁钛矿"))

	var ship_id_num: int = int(featured_ship.get("id", 7))
	var ship_name: String = str(featured_ship.get("name_zh", "游隼可回收 B-7"))
	var ship_cap: int = int(featured_ship.get("capacity_t", 350))
	var trips_done: int = int(featured_ship.get("trips_completed", 3))
	var since_overhaul: int = maxi(0, trips_done - int(featured_ship.get("wear_reset_trips", 0)))
	var is_overhauled: bool = bool(featured_ship.get("overhauled", false))
	var reuse_count: int = clampi((since_overhaul % 10) + (0 if is_overhauled and since_overhaul == 0 else 1), 0, 10)
	var fuel_left_pct: float = clampf(12.4 - dist_l * 1.8 - (grav_g - 1.0) * 4.5 + (0.8 if win_mode == "optimal" else 0.0) + 0.4 * sin(now_sec * 1.3), 4.2, 18.0)
	var tilt_deg: float = absf((0.3 if is_overhauled else 0.6) + 0.2 * sin(now_sec * 1.7))
	var roll_deg: float = absf((0.5 if is_overhauled else 1.1) + 0.2 * cos(now_sec * 1.4))
	var wear_pct: float = 0.4 if (is_overhauled and since_overhaul == 0) else clampf(float(reuse_count) * 1.4, 1.4, 14.0)
	var base_rec_rate: float = 98.5 if is_overhauled else 96.8
	if win_mode == "optimal":
		base_rec_rate = minf(99.4, base_rec_rate + 0.8)
	elif win_mode == "express":
		base_rec_rate = maxf(94.2, base_rec_rate - 1.2)
	var rec_rate_str: String = "%.1f%%" % base_rec_rate
	var v_spd: float = -1.2 - 4.5 * absf(sin(now_sec * 0.6)) if camera_mode == "main" else (142.0 + 38.0 * sin(now_sec * 0.8))
	var h_spd: float = 0.3 + 0.2 * absf(cos(now_sec * 1.1))
	var alt_m: float = 6.8 + 42.0 * absf(sin(now_sec * 0.5)) if camera_mode == "main" else (550.0 + 180.0 * absf(cos(now_sec * 0.4)))

	var win_time_str: String = "今晚 21:36 - 22:14" if win_mode == "optimal" else ("明日 15:10 - 16:00" if win_mode == "standard" else "清晨 09:20 - 09:55")
	var win_weather_str: String = "☀ 晴 | 风速 3.8m/s (运费-8%)" if win_mode == "optimal" else ("⛅ 多云 | 风速 6.2m/s (标准)" if win_mode == "standard" else "⚡ 切变风 9.4m/s (周期-15%)")
	var win_badge_str: String = "适宜发射" if win_mode == "optimal" else ("常规窗口" if win_mode == "standard" else "极速快航")
	var win_badge_col: Color = GREEN if win_mode == "optimal" else (CYAN_BRIGHT if win_mode == "standard" else GOLD)

	# 1. 绘制高清写实背景底图 (Cover 满幅自适应裁剪)
	draw_rect(Rect2(0, 0, w, h), Color("050b14"))
	var bg_tex: Texture2D = _active_backdrop()
	if bg_tex != null:
		_draw_texture_cover(bg_tex, Rect2(0, 0, w, h))

	# 叠加柔和暗角，突出前景光学准星与遥测卡片
	draw_rect(Rect2(0, 0, w, 30 if compact_mode else 44), Color(0.02, 0.05, 0.10, 0.78))
	draw_rect(Rect2(0, h - (24 if compact_mode else 58), w, 24 if compact_mode else 58), Color(0.02, 0.05, 0.10, 0.78))

	# 2. 绘制动态反推尾焰马赫环、甲板热浪水雾与中央光学追踪圆弧准星 (对标参考图 1 & 3)
	var center_pt: Vector2 = Vector2(w * 0.50, h * (0.46 if compact_mode else 0.45))
	var hud_r: float = minf(w, h) * (0.28 if compact_mode else 0.26)
	_draw_dynamic_plume_and_vapor(center_pt, hud_r, now_sec, compact_mode)
	_draw_optical_tracking_reticle(center_pt, hud_r, now_sec, compact_mode)

	if compact_mode:
		_draw_compact_overlay(w, h, ship_name, ship_cap, mine_name, grav_g, port_name, fuel_left_pct, tilt_deg, v_spd, alt_m, win_badge_str)
		return

	# =========================================================================
	# 全屏《星际航天 Astra / Orbital Tycoon》指挥中心 HUD (compact_mode == false)
	# =========================================================================

	# 3. 顶部五节点任务时序轴：发射 ── 分离 ── 返回 ── 着陆 ── 完成 (对标参考图 3)
	_draw_top_timeline_bar(w, now_sec, mine_name, port_name)

	# 4. 左上角：自适应双模遥测卡 —— 回收视角显示「助推器回收 B-7」(参考图 1)，整备/发射视角显示「发射准备五项自检」(参考图 4)
	var left_card_rect := Rect2(18, 56, 250, 218)
	var ship_idx_disp: int = posmod(selected_ship_index, maxi(1, v40_ships.size())) + 1
	var ship_total_disp: int = maxi(1, v40_ships.size())
	if camera_mode == "pad":
		_draw_sci_fi_panel(left_card_rect, "发射准备 · L-%d [点此切船 %d/%d]" % [ship_id_num, ship_idx_disp, ship_total_disp])
		var prep_rows: Array = [
			["✓ 火箭装配完成", "已锁定", GREEN],
			["✓ 载荷已安装", "%s %dt" % [payload_min_zh, ship_cap], GREEN],
			["✓ 燃料加注", "100% (液氧过冷)", GREEN],
			["✓ 发射窗口可用", win_badge_str, win_badge_col],
			["✓ 天气评估", "符合起飞标准", CYAN_BRIGHT]
		]
		for pr_i in range(prep_rows.size()):
			var pry: float = left_card_rect.position.y + 46.0 + float(pr_i) * 28.0
			draw_line(Vector2(left_card_rect.position.x + 14, pry + 7), Vector2(left_card_rect.end.x - 14, pry + 7), Color(1, 1, 1, 0.07), 1.0)
			_draw_text(Vector2(left_card_rect.position.x + 14, pry), str(prep_rows[pr_i][0]), 12, prep_rows[pr_i][2])
			_draw_text(Vector2(left_card_rect.end.x - 102, pry), str(prep_rows[pr_i][1]), 11, INK)
		_draw_text(Vector2(left_card_rect.position.x + 14, left_card_rect.end.y - 14), "🎯 目标：%s → %s (%.1fL)" % [mine_name, port_name, dist_l], 11, GOLD)
	else:
		_draw_sci_fi_panel(left_card_rect, "助推器回收 B-%d · %s [切船 %d/%d]" % [ship_id_num, ship_name, ship_idx_disp, ship_total_disp])
		var rows_l: Array = [
			["⛽ 回收燃料", "%.1f%%" % fuel_left_pct, CYAN_BRIGHT],
			["📐 着陆姿态", "%.1f°" % tilt_deg, INK],
			["⚙ 结构损耗", "%.1f%%" % wear_pct, GOLD if wear_pct > 8.0 else INK],
			["♻ 复用次数", "%d / 10" % reuse_count, INK]
		]
		for r_i in range(rows_l.size()):
			var ry: float = left_card_rect.position.y + 48.0 + float(r_i) * 30.0
			draw_line(Vector2(left_card_rect.position.x + 14, ry + 8), Vector2(left_card_rect.end.x - 14, ry + 8), Color(1, 1, 1, 0.07), 1.0)
			_draw_text(Vector2(left_card_rect.position.x + 16, ry), str(rows_l[r_i][0]), 12, MUTED)
			_draw_text(Vector2(left_card_rect.end.x - 74, ry), str(rows_l[r_i][1]), 13, rows_l[r_i][2])

		# 绿色回收成功徽章
		var badge_y: float = left_card_rect.end.y - 38.0
		draw_arc(Vector2(left_card_rect.position.x + 36, badge_y + 6), 13.0, 0.0, TAU, 24, GREEN, 2.0, true)
		_draw_text(Vector2(left_card_rect.position.x + 30, badge_y + 11), "✓", 14, GREEN)
		_draw_text(Vector2(left_card_rect.position.x + 58, badge_y + 4), "回收成功 · 闭环就绪", 14, GREEN)
		_draw_text(Vector2(left_card_rect.position.x + 58, badge_y + 21), "可自动整备后再次投入航线", 11, MUTED)

	# 5. 左中角：双半球姿态仪 (Artificial Horizon Navball，对标参考图 3)
	var nav_rect := Rect2(18, 286, 176, 152)
	_draw_sci_fi_panel(nav_rect, "姿态遥测 (NAVBALL)")
	var nav_center := Vector2(nav_rect.position.x + nav_rect.size.x * 0.5, nav_rect.position.y + 76.0)
	var nav_r: float = 40.0
	_draw_navball(nav_center, nav_r, tilt_deg, roll_deg)
	_draw_text(Vector2(nav_rect.position.x + 16, nav_rect.end.y - 12), "倾角 %.1f°   滚转 %.1f°" % [tilt_deg, roll_deg], 11, INK)

	# 6. 左下角：三视角切换器 (主视角 / 跟随视角 / 平台视角，对标参考图 1)
	var cam_rect := Rect2(18, h - 126, 134, 110)
	_draw_sci_fi_panel(cam_rect, "视角切换")
	var cam_modes: Array = [
		["main", "📷 主视角 (回收)"],
		["follow", "🎥 跟随视角 (发射)"],
		["pad", "⚓ 平台视角 (整备)"]
	]
	for cm_i in range(cam_modes.size()):
		var cm_id: String = str(cam_modes[cm_i][0])
		var cm_lbl: String = str(cam_modes[cm_i][1])
		var btn_r := Rect2(cam_rect.position.x + 8, cam_rect.position.y + 26 + float(cm_i) * 26.0, cam_rect.size.x - 16, 22)
		var is_sel: bool = (camera_mode == cm_id)
		draw_rect(btn_r, Color(0.12, 0.42, 0.68, 0.75) if is_sel else Color(0.06, 0.12, 0.20, 0.65))
		draw_rect(btn_r, CYAN_BRIGHT if is_sel else Color(0.25, 0.42, 0.58, 0.45), false, 1.2)
		_draw_text(btn_r.position + Vector2(8, 15), cm_lbl, 11, INK if is_sel else MUTED)

	# 7. 右上角：T+ 精确任务时序表 (对标参考图 1)
	var right_top_rect := Rect2(w - 252, 56, 234, 152)
	_draw_sci_fi_panel(right_top_rect, "航次时序遥测")
	var t_events: Array = [
		["☑ 发射升空", "✓ T+ 00:00:00", GREEN],
		["   级间分离", "✓ T+ 00:02:49", INK],
		["   再入点火", "✓ T+ 00:06:21", INK],
		["   着陆点火", "✓ T+ 00:08:37", INK],
		["☑ 着陆完成", "✓ T+ 00:09:02", GREEN]
	]
	for te_i in range(t_events.size()):
		var ty: float = right_top_rect.position.y + 42.0 + float(te_i) * 22.0
		_draw_text(Vector2(right_top_rect.position.x + 12, ty), str(t_events[te_i][0]), 12, t_events[te_i][2])
		_draw_text(Vector2(right_top_rect.end.x - 104, ty), str(t_events[te_i][1]), 12, t_events[te_i][2])

	# 8. 右中角：回收成功率圆环 + 载荷/燃料加注进度条 + 四项绿勾清单 (对标参考图 2, 3, 4)
	var right_mid_rect := Rect2(w - 252, 214, 234, 212)
	_draw_sci_fi_panel(right_mid_rect, "任务载荷与回收评估")
	var ring_center := Vector2(right_mid_rect.position.x + 62.0, right_mid_rect.position.y + 68.0)
	draw_arc(ring_center, 28.0, PI * 0.85, PI * 2.15, 28, Color(0.15, 0.28, 0.38, 0.8), 5.5, true)
	draw_arc(ring_center, 28.0, PI * 0.85, PI * 2.08, 28, GREEN, 5.5, true)
	_draw_text(ring_center + Vector2(-24, 5), rec_rate_str, 15, GREEN if is_overhauled else INK)
	_draw_text(Vector2(right_mid_rect.position.x + 104, right_mid_rect.position.y + 52), "📦 载荷: %s %dt" % [payload_min_zh, ship_cap], 11, GOLD)
	_draw_text(Vector2(right_mid_rect.position.x + 104, right_mid_rect.position.y + 70), "⛽ 加注: 100% |||||", 11, GREEN)
	_draw_text(Vector2(right_mid_rect.position.x + 104, right_mid_rect.position.y + 88), "🎯 轨道: %.1fL / %.1fG" % [dist_l, grav_g], 11, CYAN_BRIGHT)

	var checks: Array = [
		"✓ 再入减速与热防护   正常",
		"✓ 栅格翼姿态控制     稳定",
		"✓ 天气与发射窗口     %s" % win_badge_str
	]
	for ck_i in range(checks.size()):
		_draw_text(Vector2(right_mid_rect.position.x + 14, right_mid_rect.position.y + 114.0 + float(ck_i) * 19.0), str(checks[ck_i]), 11, GREEN)

	# 对标参考图 4 右侧「发射窗口切换胶囊条」
	var win_bar_r := Rect2(right_mid_rect.position.x + 10, right_mid_rect.end.y - 34, right_mid_rect.size.x - 20, 24)
	draw_rect(win_bar_r, Color(0.08, 0.24, 0.38, 0.85))
	draw_rect(win_bar_r, win_badge_col, false, 1.2)
	_draw_text(win_bar_r.position + Vector2(8, 16), "🕒 窗口: %s [点此切换]" % win_badge_str, 11, win_badge_col)

	# 8b. 右下控制指令台 (对标参考图 3 右下角「控制指令：🎯 自动回收 / ✥ 姿态微调与结构检修」)
	var cmd_rect := Rect2(w - 252, h - 146, 234, 72)
	_draw_sci_fi_panel(cmd_rect, "控制指令 (COMMAND)")
	var auto_btn_r := Rect2(cmd_rect.position.x + 10, cmd_rect.position.y + 34, 102, 28)
	draw_rect(auto_btn_r, Color(0.10, 0.38, 0.64, 0.80))
	draw_rect(auto_btn_r, CYAN_BRIGHT, false, 1.2)
	_draw_text(auto_btn_r.position + Vector2(8, 19), "🎯 自动回收:开", 11, INK)
	var trim_btn_r := Rect2(cmd_rect.position.x + 118, cmd_rect.position.y + 34, 106, 28)
	draw_rect(trim_btn_r, Color(0.14, 0.28, 0.22, 0.85) if is_overhauled else Color(0.18, 0.24, 0.34, 0.85))
	draw_rect(trim_btn_r, GREEN if is_overhauled else GOLD, false, 1.2)
	_draw_text(trim_btn_r.position + Vector2(6, 19), "✓已检修校准" if is_overhauled else "✥姿态检修(1200)", 10, GREEN if is_overhauled else GOLD)

	# 9. 右下角：琥珀金斜纹【🚀 发射 / 增派运矿船】大按钮 (对标参考图 2 & 4)
	var launch_btn_rect := Rect2(w - 252, h - 68, 234, 50)
	draw_rect(launch_btn_rect, Color("e6981e"))
	draw_rect(Rect2(launch_btn_rect.position, Vector2(launch_btn_rect.size.x, 22)), Color(1.0, 0.85, 0.45, 0.35))
	draw_rect(launch_btn_rect, Color("ffd27a"), false, 2.0)
	_draw_text(launch_btn_rect.position + Vector2(46, 31), "🚀 点火发射 / 增派", 16, Color("0b131e"))

	# 10. 底部居中：五联遥测与发射窗口气象台 (对标参考图 1 底部三联表 + 参考图 2 底部「发射窗口 + 天气状况：适宜发射」)
	var bot_w: float = 540.0
	var bot_rect := Rect2((w - bot_w) * 0.5, h - 64.0, bot_w, 48.0)
	_draw_sci_fi_panel(bot_rect, "")
	_draw_text(bot_rect.position + Vector2(14, 18), "垂直速度", 10, MUTED)
	_draw_text(bot_rect.position + Vector2(12, 38), "%.1f m/s" % v_spd, 13, INK)
	_draw_text(bot_rect.position + Vector2(102, 18), "水平速度", 10, MUTED)
	_draw_text(bot_rect.position + Vector2(102, 38), "%.1f m/s" % h_spd, 13, INK)
	_draw_text(bot_rect.position + Vector2(188, 18), "高度", 10, MUTED)
	_draw_text(bot_rect.position + Vector2(184, 38), "%.1f m" % alt_m, 13, CYAN_BRIGHT)
	draw_line(bot_rect.position + Vector2(252, 8), bot_rect.position + Vector2(252, 40), Color(0.25, 0.55, 0.80, 0.4), 1.0)
	_draw_text(bot_rect.position + Vector2(262, 18), "发射窗口: " + win_time_str, 10, MUTED)
	_draw_text(bot_rect.position + Vector2(262, 38), win_weather_str, 11, INK)
	var pill_rect := Rect2(bot_rect.end.x - 74, bot_rect.position.y + 8, 66, 16)
	draw_rect(pill_rect, Color(0.10, 0.36, 0.24, 0.85) if win_mode == "optimal" else Color(0.12, 0.28, 0.44, 0.85))
	draw_rect(pill_rect, win_badge_col, false, 1.0)
	_draw_text(pill_rect.position + Vector2(6, 12), win_badge_str, 10, win_badge_col)


func _draw_compact_overlay(w: float, h: float, ship_name: String, ship_cap: int, mine_name: String, grav_g: float, port_name: String, fuel_pct: float, tilt_deg: float, v_spd: float, alt_m: float, win_badge_str: String) -> void:
	# 右侧边栏紧凑版实况窗：展示高清写实底图 + 光学准星 + 顶部航线与底部三联遥测
	var cam_tag: String = "回收视角" if camera_mode == "main" else ("发射视角" if camera_mode == "follow" else "整备视角")
	_draw_text(Vector2(6, 14), "🚀 %s(%dt) · %s(%.1fG)→%s" % [ship_name, ship_cap, mine_name, grav_g, port_name], 10, GOLD)
	_draw_text(Vector2(6, 26), "✓ 窗口:%s | 燃料 %.1f%% | 姿态 %.1f° [点此全屏]" % [win_badge_str, fuel_pct, tilt_deg], 9, GREEN)
	var bot_txt: String = "V-SPD %.1fm/s | ALT %.1fm | [📷点此切:%s]" % [v_spd, alt_m, cam_tag]
	_draw_text(Vector2(6, h - 7.0), bot_txt, 9, CYAN_BRIGHT)


func _draw_top_timeline_bar(w: float, now_sec: float, mine_name: String, port_name: String) -> void:
	_draw_text(Vector2(18, 26), "🚀 星际航天指挥中心  //  %s ⇄ %s" % [mine_name, port_name], 14, GOLD)
	var steps: Array = ["发射", "分离", "返回", "着陆", "完成"]
	var active_idx: int = int(floor(fmod(now_sec * 0.4, 5.0)))
	var start_x: float = w * 0.36
	var step_span: float = minf(78.0, (w * 0.36) / 4.0)
	for i in range(steps.size()):
		var sx: float = start_x + float(i) * step_span
		var sy: float = 18.0
		if i < steps.size() - 1:
			var line_col: Color = GREEN if i < active_idx else Color(0.25, 0.42, 0.55, 0.6)
			draw_line(Vector2(sx + 9, sy), Vector2(sx + step_span - 9, sy), line_col, 2.0)
		var node_col: Color = GREEN if i < active_idx else (CYAN_BRIGHT if i == active_idx else MUTED)
		draw_circle(Vector2(sx, sy), 7.5, Color("07131e"))
		draw_arc(Vector2(sx, sy), 7.5, 0.0, TAU, 20, node_col, 2.0, true)
		if i <= active_idx:
			draw_circle(Vector2(sx, sy), 3.2, node_col)
		_draw_text(Vector2(sx - 12, sy + 20), str(steps[i]), 10, INK if i == active_idx else MUTED)


func _draw_dynamic_plume_and_vapor(center: Vector2, r: float, now_sec: float, is_compact: bool) -> void:
	# 若处于晴空发射台整备视角 (camera_mode == "pad"，对标参考图 4)，绘制箭体液氧加注低温泄压白雾 (LOX Cryo Venting)
	if camera_mode == "pad":
		var vent_origins: Array = [center + Vector2(-8.0, -r * 0.18), center + Vector2(-6.0, r * 0.15)]
		for vo in vent_origins:
			for vp_i in range(6):
				var v_phase: float = fmod(now_sec * 0.65 + float(vp_i) / 6.0, 1.0)
				var vx: float = -v_phase * r * (0.45 if is_compact else 0.65)
				var vy: float = sin(v_phase * PI) * 6.0 + v_phase * 8.0
				var vr: float = (4.0 if is_compact else 9.0) * (0.4 + v_phase * 0.8)
				draw_circle(vo + Vector2(vx, vy), vr, Color(0.92, 0.97, 1.0, (1.0 - v_phase) * 0.32))
		return

	# 绘制动态呼吸尾焰核心、马赫环 (Shock Diamonds) 与甲板受热膨胀水雾粒子
	var nozzle_pt: Vector2 = center + Vector2(0.0, r * (0.34 if camera_mode == "main" else 0.28))
	var deck_pt: Vector2 = center + Vector2(0.0, r * 0.92)
	var flicker: float = 0.88 + 0.12 * sin(now_sec * 34.0)
	var plume_w: float = (8.0 if is_compact else 16.0) * flicker
	var plume_h: float = (deck_pt.y - nozzle_pt.y) * (0.95 + 0.05 * cos(now_sec * 27.0))

	# 外层琥珀金光晕与内层白炽核心
	draw_colored_polygon(PackedVector2Array([
		nozzle_pt + Vector2(-plume_w * 0.55, 0),
		nozzle_pt + Vector2(plume_w * 0.55, 0),
		nozzle_pt + Vector2(plume_w * 1.15, plume_h),
		nozzle_pt + Vector2(-plume_w * 1.15, plume_h)
	]), Color(0.98, 0.56, 0.18, 0.34 * flicker))
	draw_colored_polygon(PackedVector2Array([
		nozzle_pt + Vector2(-plume_w * 0.28, 0),
		nozzle_pt + Vector2(plume_w * 0.28, 0),
		nozzle_pt + Vector2(0.0, plume_h * 0.86)
	]), Color(1.0, 0.96, 0.86, 0.52 * flicker))

	# 超音速尾焰马赫环节点
	for md_i in range(3):
		var my: float = nozzle_pt.y + plume_h * (0.22 + float(md_i) * 0.24)
		draw_circle(Vector2(nozzle_pt.x, my), (3.0 if is_compact else 5.5) * (1.0 - float(md_i) * 0.2), Color(1.0, 0.98, 0.92, 0.55))

	# 甲板/海面翻滚热浪烟尘粒子
	var puff_cnt: int = 5 if is_compact else 9
	for p_i in range(puff_cnt):
		var phase: float = fmod(now_sec * 0.85 + float(p_i) / float(puff_cnt), 1.0)
		var dir_sign: float = -1.0 if p_i % 2 == 0 else 1.0
		var spread_x: float = dir_sign * pow(phase, 0.75) * r * (0.75 if is_compact else 0.95)
		var lift_y: float = -sin(phase * PI) * (8.0 if is_compact else 18.0)
		var puff_r: float = (6.0 if is_compact else 14.0) * (0.5 + phase * 0.9)
		var alpha: float = (1.0 - phase) * 0.26
		draw_circle(deck_pt + Vector2(spread_x, lift_y), puff_r, Color(0.96, 0.76, 0.58, alpha))


func _draw_optical_tracking_reticle(center: Vector2, r: float, now_sec: float, is_compact: bool) -> void:
	var arc_col: Color = Color(0.22, 0.75, 1.0, 0.62)
	# 左右双圆弧括号 (对标参考图 1 & 3)
	draw_arc(center, r, PI * 0.72, PI * 1.28, 28, arc_col, 1.5, true)
	draw_arc(center, r, -PI * 0.28, PI * 0.28, 28, arc_col, 1.5, true)
	# 左右三角锁定游标
	var pulse_y: float = sin(now_sec * 2.0) * (4.0 if is_compact else 8.0)
	var left_pt := center + Vector2(-r - 2.0, pulse_y)
	var right_pt := center + Vector2(r + 2.0, -pulse_y)
	draw_colored_polygon(PackedVector2Array([left_pt, left_pt + Vector2(-7, -4), left_pt + Vector2(-7, 4)]), CYAN_BRIGHT)
	draw_colored_polygon(PackedVector2Array([right_pt, right_pt + Vector2(7, -4), right_pt + Vector2(7, 4)]), CYAN_BRIGHT)

	# 内部垂直高度刻度尺
	var tick_x_l: float = center.x - r * 0.62
	var tick_x_r: float = center.x + r * 0.62
	var tick_count: int = 7 if is_compact else 11
	for t_i in range(tick_count):
		var ty: float = center.y + (float(t_i) - float(tick_count - 1) * 0.5) * (r * 1.1 / float(tick_count))
		var tw: float = 8.0 if t_i % 2 == 0 else 4.0
		draw_line(Vector2(tick_x_l - tw, ty), Vector2(tick_x_l, ty), Color(0.6, 0.85, 1.0, 0.45), 1.0)
		draw_line(Vector2(tick_x_r, ty), Vector2(tick_x_r + tw, ty), Color(0.6, 0.85, 1.0, 0.45), 1.0)


func _draw_navball(center: Vector2, r: float, tilt_deg: float, _roll_deg: float) -> void:
	# 上半天球 (深海蓝) 与下半地球 (赭石棕)
	draw_circle(center, r, Color("17467a"))
	var lower_pts := PackedVector2Array()
	for i in range(19):
		var ang: float = PI * float(i) / 18.0
		lower_pts.append(center + Vector2(cos(ang) * r, sin(ang) * r))
	if lower_pts.size() >= 3:
		draw_colored_polygon(lower_pts, Color("6e4720"))
	draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), Color.WHITE, 1.4)
	for step_y in [-18.0, -9.0, 9.0, 18.0]:
		draw_line(center + Vector2(-12, step_y), center + Vector2(12, step_y), Color(1, 1, 1, 0.55), 1.0)
	draw_arc(center, r, 0.0, TAU, 32, CYAN_BRIGHT, 1.8, true)
	# 中央火箭姿态指针
	var offset_x: float = clampf(tilt_deg * 2.0, -8.0, 8.0)
	draw_line(center + Vector2(offset_x, -16), center + Vector2(offset_x, 16), Color.WHITE, 2.4)


func _draw_sci_fi_panel(rect: Rect2, title: String) -> void:
	draw_rect(rect, PANEL_BG)
	draw_rect(rect, PANEL_BORDER, false, 1.2)
	# 顶部亮青科幻高光横条 (对标参考图 1–4 面板顶边发光效果)
	draw_line(rect.position + Vector2(8, 0), Vector2(rect.end.x - 8, rect.position.y), CYAN_BRIGHT, 2.0)
	if title != "":
		_draw_text(rect.position + Vector2(12, 22), title, 13, INK)
		draw_line(rect.position + Vector2(10, 30), Vector2(rect.end.x - 10, rect.position.y + 30), Color(0.25, 0.65, 0.90, 0.30), 1.0)


func _draw_texture_cover(tex: Texture2D, rect: Rect2) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 1.0 or th <= 1.0:
		return
	var scale_f: float = maxf(rect.size.x / tw, rect.size.y / th)
	var src_w: float = rect.size.x / scale_f
	var src_h: float = rect.size.y / scale_f
	var src_x: float = (tw - src_w) * 0.5
	var src_y: float = (th - src_h) * 0.5
	draw_texture_rect_region(tex, rect, Rect2(src_x, src_y, src_w, src_h))


func _draw_text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, 0.72))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
