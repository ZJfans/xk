class_name LaunchRecoveryView
extends Control

## 《星矿大亨 Rocket Prospectors》V1.0 · 写实科技风【火箭发射、级间分离与海上/塔架回收画面】
## 严格遵循 V1.0 设计方案：
## - 承担高冲击力的 SpaceX 写实航天视觉反馈（点火起飞、Max-Q 穿云、级间热分离、星表着陆装货、助推器海上回收/筷子塔捕获）
## - 纯自动视觉演出，不增加玩家手动操控火箭姿态的操作负担！

const INK: Color = Color("e6f0f6")
const MUTED: Color = Color("8fa5b5")
const GOLD: Color = Color("f2b55c")
const AMBER: Color = Color("f08c42")
const GREEN: Color = Color("83c7a6")
const RED: Color = Color("f08c82")
const CYAN: Color = Color("49d6e4")
const STEEL: Color = Color("c8d6e2")
const DARK_STEEL: Color = Color("3a4d5e")

var state: GameState
var compact_mode: bool = true
var last_launch_msec: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(360, 172) if compact_mode else Vector2(880, 520)
	clip_contents = true
	set_process(true)


func notify_launch() -> void:
	last_launch_msec = Time.get_ticks_msec()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 20.0 or h < 20.0:
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var since_launch: float = float(Time.get_ticks_msec() - last_launch_msec) / 1000.0 if last_launch_msec > 0 else 999.0

	# 统计当前船队状态，决定主演出镜头阶段
	var outbound_ships: Array[Dictionary] = []
	var waiting_ships: Array[Dictionary] = []
	var inbound_ships: Array[Dictionary] = []
	var refurb_ships: Array[Dictionary] = []
	if state != null:
		for s in state.ships:
			var st: String = str(s.get("state", ""))
			if st == "outbound":
				outbound_ships.append(s)
			elif st == "waiting":
				waiting_ships.append(s)
			elif st == "inbound":
				inbound_ships.append(s)
			elif st in ["refurbishing", "port"]:
				refurb_ships.append(s)

	# 判定当前视觉镜头阶段：
	# 1. "liftoff" (刚点击发射 4.5 秒内：展示点火起飞与级间分离)
	# 2. "outbound" (有火箭正飞往矿区：展示级间分离入轨与深空巡航)
	# 3. "recovery" (有火箭返航或刚降落：展示一子级海上平台着陆 / 筷子塔机械臂夹持回收)
	# 4. "standby" (发射台整备待命：展示博卡湾发射塔与待命星舰蒸汽泄压)
	var stage_mode: String = "standby"
	var active_ship: Dictionary = {}
	if since_launch < 4.2:
		stage_mode = "liftoff"
		if not outbound_ships.is_empty():
			active_ship = outbound_ships[outbound_ships.size() - 1]
	elif not inbound_ships.is_empty():
		stage_mode = "recovery"
		active_ship = inbound_ships[0]
	elif not outbound_ships.is_empty():
		stage_mode = "outbound"
		active_ship = outbound_ships[0]
	elif not waiting_ships.is_empty():
		stage_mode = "loading"
		active_ship = waiting_ships[0]
	elif not refurb_ships.is_empty():
		stage_mode = "recovery"
		active_ship = refurb_ships[0]

	# 1. 绘制深空与平流层渐变背景
	draw_rect(Rect2(0, 0, w, h), Color("050b14"))
	var horizon_y: float = h * 0.74
	draw_rect(Rect2(0, horizon_y - 28.0, w, 28.0), Color(0.11, 0.25, 0.42, 0.45))
	draw_rect(Rect2(0, horizon_y, w, h - horizon_y), Color("081523"))
	draw_line(Vector2(0, horizon_y), Vector2(w, horizon_y), Color(0.28, 0.68, 0.92, 0.65), 1.6)

	# 绘制背景测量网格线与弹道轨迹曲线
	for gx in range(1, 6):
		var x_pos: float = w * float(gx) / 6.0
		draw_line(Vector2(x_pos, 24), Vector2(x_pos, horizon_y), Color(1, 1, 1, 0.04), 1.0)
	for gy in range(1, 4):
		var y_pos: float = horizon_y * float(gy) / 4.0
		draw_line(Vector2(0, y_pos), Vector2(w, y_pos), Color(1, 1, 1, 0.04), 1.0)

	# 左侧：写实发射基地筷子塔 (Mechazilla Launch Tower)
	var pad_x: float = w * 0.22
	_draw_mechazilla_tower(Vector2(pad_x, horizon_y), h * 0.46)

	# 右侧：大西洋无人回收驳船 (Autonomous Spaceport Drone Ship)
	var barge_x: float = w * 0.76
	_draw_recovery_barge(Vector2(barge_x, horizon_y + 10.0), now_sec)

	# 绘制抛物线弹道遥测包线
	var arc_pts: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var u: float = float(i) / 24.0
		var ax: float = lerpf(pad_x, barge_x, u)
		var ay: float = horizon_y - 24.0 - sin(u * PI) * (h * 0.52)
		arc_pts.append(Vector2(ax, ay))
	draw_polyline(arc_pts, Color(0.29, 0.84, 0.89, 0.28), 1.3, true)

	# 根据当前阶段绘制写实火箭演出
	var mode_str: String = str(active_ship.get("mode", "medium_reuse"))
	var is_reusable: bool = mode_str in ["medium_reuse", "heavy_reuse"]
	var is_heavy: bool = mode_str == "heavy_reuse"

	if stage_mode == "liftoff":
		var p: float = clampf(since_launch / 4.2, 0.0, 1.0)
		var r_pos: Vector2 = Vector2(
			lerpf(pad_x + 12.0, w * 0.48, pow(p, 1.4)),
			lerpf(horizon_y - 18.0, h * 0.22, pow(p, 0.85))
		)
		var tilt: float = lerpf(0.0, 0.42, p)
		# 起飞浓烟与烈焰冲击波
		for c_i in range(6):
			var spread: float = (float(c_i) - 2.5) * 14.0 * (1.0 - p * 0.4)
			draw_circle(Vector2(pad_x + 12.0 + spread, horizon_y - 4.0), 12.0 - float(c_i) * 1.2, Color(0.85, 0.88, 0.92, 0.35 * (1.0 - p * 0.6)))
		if p < 0.62:
			_draw_realistic_rocket(r_pos, tilt, is_heavy, true, true, now_sec)
		else:
			# 级间热分离演出 (Stage Separation!)
			var sep_p: float = (p - 0.62) / 0.38
			var upper_pos: Vector2 = r_pos + Vector2(sep_p * 28.0, -sep_p * 16.0)
			var booster_pos: Vector2 = r_pos + Vector2(-sep_p * 14.0, sep_p * 22.0)
			draw_circle(r_pos, 14.0 * (1.0 - sep_p * 0.5), Color(0.95, 0.68, 0.32, 0.55))
			_draw_upper_stage(upper_pos, tilt + 0.15, is_heavy, true, now_sec)
			_draw_booster_stage(booster_pos, tilt - sep_p * 0.35, true, now_sec)
	elif stage_mode == "outbound":
		var cyc: float = fmod(now_sec * 0.38, 1.0)
		var upper_pos2: Vector2 = Vector2(lerpf(w * 0.36, w * 0.82, cyc), lerpf(h * 0.32, h * 0.18, sin(cyc * PI)))
		_draw_upper_stage(upper_pos2, 0.55, is_heavy, true, now_sec)
		if is_reusable:
			var b_pos: Vector2 = Vector2(lerpf(w * 0.48, barge_x, cyc), lerpf(h * 0.28, horizon_y - 12.0, pow(cyc, 1.2)))
			_draw_booster_stage(b_pos, 0.05 * sin(now_sec * 4.0), cyc > 0.65, now_sec)
	elif stage_mode == "recovery":
		var land_cyc: float = fmod(now_sec * 0.45, 1.0)
		var target_x: float = pad_x + 12.0 if is_heavy else barge_x
		var target_y: float = horizon_y - 22.0 if is_heavy else horizon_y - 6.0
		var desc_pos: Vector2 = Vector2(
			lerpf(target_x - 24.0, target_x, land_cyc),
			lerpf(h * 0.18, target_y, pow(land_cyc, 0.82))
		)
		_draw_booster_stage(desc_pos, (1.0 - land_cyc) * 0.12, true, now_sec)
		if land_cyc > 0.78:
			draw_circle(Vector2(target_x, target_y + 12.0), 12.0, Color(0.95, 0.65, 0.25, 0.55))
	elif stage_mode == "loading":
		_draw_realistic_rocket(Vector2(pad_x + 12.0, horizon_y - 22.0), 0.0, is_heavy, false, false, now_sec)
		var orbit_pos: Vector2 = Vector2(w * 0.62 + cos(now_sec * 1.4) * 18.0, h * 0.24 + sin(now_sec * 1.4) * 6.0)
		_draw_upper_stage(orbit_pos, 1.57, is_heavy, false, now_sec)
	else:
		# 待命状态：火箭矗立在发射架上，伴随低温液氧白雾飘散
		_draw_realistic_rocket(Vector2(pad_x + 12.0, horizon_y - 22.0), 0.0, false, false, false, now_sec)
		var vent_x: float = pad_x + 16.0 + fmod(now_sec * 14.0, 22.0)
		draw_circle(Vector2(vent_x, horizon_y - 34.0), 6.0, Color(0.85, 0.92, 0.98, 0.25))

	# 顶部写实航天遥测 HUD 叠加层
	draw_rect(Rect2(0, 0, w, 24), Color(0.03, 0.07, 0.12, 0.88))
	var status_badge: String = "● LIVE TELEMETRY · 发射台待命"
	var badge_col: Color = CYAN
	if stage_mode == "liftoff":
		status_badge = "🔥 LIFTOFF & STAGE SEP · 点火升空与级间分离"
		badge_col = GOLD
	elif stage_mode == "outbound":
		status_badge = "🚀 ORBITAL TRANSIT · 二子级入轨巡航 & 助推器回收"
		badge_col = GREEN
	elif stage_mode == "recovery":
		status_badge = "♻ LANDING BURN · 助推器反推着陆与塔架/驳船回收"
		badge_col = GOLD
	elif stage_mode == "loading":
		status_badge = "⛏ SURFACE LOADING · 星表矿仓装货作业中"
		badge_col = CYAN
	_draw_text(Vector2(8, 16), status_badge, 11, badge_col)

	var alt_km: float = 0.0 if stage_mode == "standby" else (68.5 + 42.0 * sin(now_sec * 0.9))
	var vel_kms: float = 0.0 if stage_mode == "standby" else (2.45 + 1.15 * cos(now_sec * 0.7))
	var tele_txt: String = "ALT %.1f km  |  VEL %.2f km/s  |  在轨舰队: %d" % [
		absf(alt_km), absf(vel_kms), state.ships.size() if state != null else 0
	]
	_draw_text(Vector2(w - 235, 16), tele_txt, 10, MUTED)


func _draw_mechazilla_tower(base: Vector2, tower_h: float) -> void:
	var tx: float = base.x
	var ty: float = base.y
	# 发射台混凝土导流槽底座
	draw_rect(Rect2(tx - 16, ty - 6, 40, 6), DARK_STEEL)
	# 黑色钢铁桁架塔身
	draw_rect(Rect2(tx - 8, ty - tower_h, 12, tower_h), Color("1b2836"))
	draw_rect(Rect2(tx - 8, ty - tower_h, 12, tower_h), Color("567189"), false, 1.2)
	var steps: int = 7
	var step_h: float = tower_h / float(steps)
	for i in range(steps):
		var y1: float = ty - float(i) * step_h
		var y2: float = y1 - step_h
		draw_line(Vector2(tx - 8, y1), Vector2(tx + 4, y2), Color("496278"), 1.0)
		draw_line(Vector2(tx + 4, y1), Vector2(tx - 8, y2), Color("496278"), 1.0)
	# 筷子捕获机械臂 (Chopsticks)
	var arm_y: float = ty - tower_h * 0.62
	draw_rect(Rect2(tx - 9, arm_y - 3, 14, 6), GOLD)
	draw_line(Vector2(tx + 4, arm_y - 1), Vector2(tx + 24, arm_y - 1), STEEL, 2.2)
	draw_line(Vector2(tx + 4, arm_y + 2), Vector2(tx + 24, arm_y + 2), DARK_STEEL, 1.6)
	draw_circle(Vector2(tx - 2, ty - tower_h - 3), 2.2, RED)


func _draw_recovery_barge(pos: Vector2, now_sec: float) -> void:
	var bob: float = sin(now_sec * 2.2) * 1.5
	var bx: float = pos.x
	var by: float = pos.y + bob
	var hull: PackedVector2Array = PackedVector2Array([
		Vector2(bx - 28, by),
		Vector2(bx + 28, by),
		Vector2(bx + 22, by + 7),
		Vector2(bx - 22, by + 7)
	])
	draw_colored_polygon(hull, Color("283848"))
	draw_line(Vector2(bx - 28, by), Vector2(bx + 28, by), GOLD, 1.6)
	draw_circle(Vector2(bx, by - 1), 3.0, Color(0.95, 0.72, 0.30, 0.65))
	_draw_text(Vector2(bx - 26, by + 18), "OCISLY 回收船", 9, MUTED)


func _draw_realistic_rocket(pos: Vector2, angle: float, is_heavy: bool, firing: bool, full_stack: bool, now_sec: float) -> void:
	var up: Vector2 = Vector2(sin(angle), -cos(angle))
	var right: Vector2 = Vector2(cos(angle), sin(angle))
	var body_col: Color = Color("d8e3ec") if not is_heavy else Color("b8c7d4")
	var w_half: float = 4.5 if is_heavy else 3.4
	var h_len: float = 34.0 if full_stack else 18.0

	if firing:
		var flame_len: float = (18.0 + 5.0 * sin(now_sec * 28.0))
		var f_tip: Vector2 = pos - up * flame_len
		var f_poly: PackedVector2Array = PackedVector2Array([
			pos - right * (w_half * 0.9),
			pos + right * (w_half * 0.9),
			f_tip
		])
		draw_colored_polygon(f_poly, AMBER)
		var core_poly: PackedVector2Array = PackedVector2Array([
			pos - right * (w_half * 0.45),
			pos + right * (w_half * 0.45),
			pos - up * (flame_len * 0.65)
		])
		draw_colored_polygon(core_poly, CYAN if is_heavy else Color.WHITE)

	var p1: Vector2 = pos - right * w_half
	var p2: Vector2 = pos + right * w_half
	var p3: Vector2 = pos + right * w_half + up * h_len
	var p4: Vector2 = pos - right * w_half + up * h_len
	draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), body_col)
	# 级间黑环
	var mid_p: Vector2 = pos + up * (h_len * 0.55)
	draw_line(mid_p - right * w_half, mid_p + right * w_half, Color("18222c"), 2.5)
	# 整流罩鼻锥
	var nose_tip: Vector2 = pos + up * (h_len + 9.0)
	draw_colored_polygon(PackedVector2Array([p4, p3, nose_tip]), body_col)


func _draw_upper_stage(pos: Vector2, angle: float, is_heavy: bool, firing: bool, now_sec: float) -> void:
	_draw_realistic_rocket(pos, angle, is_heavy, firing, false, now_sec)


func _draw_booster_stage(pos: Vector2, angle: float, landing_burn: bool, now_sec: float) -> void:
	var up: Vector2 = Vector2(sin(angle), -cos(angle))
	var right: Vector2 = Vector2(cos(angle), sin(angle))
	var w_half: float = 3.2
	var h_len: float = 20.0
	if landing_burn:
		var flame_l: float = 13.0 + 4.0 * sin(now_sec * 30.0)
		draw_colored_polygon(PackedVector2Array([
			pos - right * 2.2, pos + right * 2.2, pos - up * flame_l
		]), AMBER)
	var b1: Vector2 = pos - right * w_half
	var b2: Vector2 = pos + right * w_half
	var b3: Vector2 = pos + right * w_half + up * h_len
	var b4: Vector2 = pos - right * w_half + up * h_len
	draw_colored_polygon(PackedVector2Array([b1, b2, b3, b4]), Color("cfdbe4"))
	# 顶部栅格翼 (Grid Fins)
	draw_line(b4 - right * 3.0, b4, DARK_STEEL, 2.0)
	draw_line(b3, b3 + right * 3.0, DARK_STEEL, 2.0)
	# 底部着陆腿 (Landing Legs)
	draw_line(b1, b1 - right * 4.0 - up * 3.0, DARK_STEEL, 1.6)
	draw_line(b2, b2 + right * 4.0 - up * 3.0, DARK_STEEL, 1.6)


func _draw_text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
