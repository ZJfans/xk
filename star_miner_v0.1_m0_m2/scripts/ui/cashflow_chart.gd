class_name CashflowChart
extends Control

## 《星矿大亨 Rocket Prospectors》V4.0 · 对标《星际航天 Astra》双轨财务遥测趋势图
## 同时绘制：
## 1. 估计净资产曲线 (Estimated Net Worth · 琥珀金 #f5b642)
## 2. 可支配现金曲线 (Available Cash · 亮青 #6ce5ff)
## 严格兼容旧版构造参数 (points, start_val) 与新版 V4.0 状态注入

const GOLD: Color = Color("f5b642")
const CYAN_BRIGHT: Color = Color("6ce5ff")
const GREEN: Color = Color("4ce096")
const RED: Color = Color("f08c82")
const MUTED: Color = Color("8fa8be")
const INK: Color = Color("eef7ff")

var history: Array = []
var net_worth_history: Array = []
var starting_cents: int = 100000
var is_v40_mode: bool = false


func _init(points: Array = [], start_val: int = 100000, nw_points: Array = [], use_v40: bool = false) -> void:
	history = points
	net_worth_history = nw_points
	starting_cents = start_val
	is_v40_mode = use_v40
	custom_minimum_size = Vector2(360, 104)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var area: Vector2 = size
	if area.x < 20.0 or area.y < 20.0:
		return

	# Astra 黑曜石玻璃背景与顶部亮青发光条
	draw_rect(Rect2(Vector2.ZERO, area), Color("07121e"))
	draw_rect(Rect2(Vector2.ZERO, area), Color(0.22, 0.65, 0.92, 0.45), false, 1.2)
	draw_line(Vector2(8, 0), Vector2(area.x - 8, 0), CYAN_BRIGHT, 2.0)

	if history.is_empty():
		return

	var pad_left: float = 12.0
	var pad_right: float = 12.0
	var pad_top: float = 24.0
	var pad_bottom: float = 14.0
	var chart_w: float = maxf(10.0, area.x - pad_left - pad_right)
	var chart_h: float = maxf(10.0, area.y - pad_top - pad_bottom)

	# 水平网格参考线
	for g_i in range(1, 4):
		var gy: float = pad_top + chart_h * float(g_i) / 4.0
		draw_line(Vector2(pad_left, gy), Vector2(area.x - pad_right, gy), Color(1, 1, 1, 0.05), 1.0)

	var min_val: int = starting_cents
	var max_val: int = starting_cents + (15000 if is_v40_mode else 50000)
	for v in history:
		var iv: int = int(v)
		min_val = mini(min_val, iv)
		max_val = maxi(max_val, iv)
	for nv in net_worth_history:
		var inv: int = int(nv)
		min_val = mini(min_val, inv)
		max_val = maxi(max_val, inv)

	var span: float = maxf(5000.0, float(max_val - min_val))

	# 开局基准虚线
	var base_ratio: float = clampf(float(starting_cents - min_val) / span, 0.0, 1.0)
	var base_y: float = pad_top + chart_h * (1.0 - base_ratio)
	draw_line(Vector2(pad_left, base_y), Vector2(area.x - pad_right, base_y), Color(0.95, 0.72, 0.28, 0.30), 1.0, true)

	# 1. 若有净资产曲线，先绘制琥珀金净资产轨迹
	if net_worth_history.size() >= 2:
		var nw_cnt: int = net_worth_history.size()
		var nw_pts := PackedVector2Array()
		for i in range(nw_cnt):
			var nx: float = pad_left + (chart_w * float(i) / float(maxi(1, nw_cnt - 1)))
			var n_ratio: float = clampf(float(int(net_worth_history[i]) - min_val) / span, 0.0, 1.0)
			var ny: float = pad_top + chart_h * (1.0 - n_ratio)
			nw_pts.append(Vector2(nx, ny))
		draw_polyline(nw_pts, GOLD, 2.0, true)
		draw_circle(nw_pts[nw_pts.size() - 1], 3.5, GOLD)

	# 2. 绘制可支配现金主曲线與半透明渐变填充
	var count: int = history.size()
	var pts := PackedVector2Array()
	for i in range(count):
		var x: float = pad_left + (chart_w * float(i) / float(maxi(1, count - 1)))
		var ratio: float = clampf(float(int(history[i]) - min_val) / span, 0.0, 1.0)
		var y: float = pad_top + chart_h * (1.0 - ratio)
		pts.append(Vector2(x, y))

	if pts.size() >= 2:
		var poly: PackedVector2Array = pts.duplicate()
		poly.append(Vector2(pts[pts.size() - 1].x, area.y - pad_bottom))
		poly.append(Vector2(pts[0].x, area.y - pad_bottom))
		draw_colored_polygon(poly, Color(0.22, 0.75, 1.0, 0.16))
		draw_polyline(pts, CYAN_BRIGHT, 2.2, true)
		var last_pt: Vector2 = pts[pts.size() - 1]
		var latest_val: int = int(history[count - 1])
		var dot_col: Color = GREEN if latest_val >= starting_cents else RED
		draw_circle(last_pt, 4.0, dot_col)

	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		var latest_v: int = int(history[count - 1])
		if is_v40_mode:
			var latest_nw: int = int(net_worth_history[net_worth_history.size() - 1]) if not net_worth_history.is_empty() else latest_v
			var hdr: String = "📈 双轨财务遥测曲线  |  ● 可支配现金: %d Cr   ● 估计净资产: %d Cr (峰值 %d Cr)" % [
				latest_v, latest_nw, max_val
			]
			draw_string(font, Vector2(12, 16), hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		else:
			var header_txt: String = "实时流动资产曲线 (峰值 $%d · 当前 $%d)" % [max_val / 100, latest_v / 100]
			draw_string(font, Vector2(10, 15), header_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
