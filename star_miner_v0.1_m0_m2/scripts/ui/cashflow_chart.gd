class_name CashflowChart
extends Control

## 工业遥测实时资产曲线图组件 (Telemetry Net-Worth Sparkline)
## 在市场与财务面板直观绘制本季资金与货值随时间演化的动态曲线

var history: Array = []
var starting_cents: int = 100000

func _init(points: Array = [], start_val: int = 100000) -> void:
	history = points
	starting_cents = start_val
	custom_minimum_size = Vector2(360, 96)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _draw() -> void:
	var area: Vector2 = size
	if area.x < 20.0 or area.y < 20.0:
		return
	draw_rect(Rect2(Vector2.ZERO, area), Color("0a1622"))
	draw_rect(Rect2(Vector2.ZERO, area), Color("2b4558"), false, 1.0)
	if history.is_empty():
		return

	var min_val: int = starting_cents
	var max_val: int = starting_cents + 50000
	for v in history:
		var iv: int = int(v)
		min_val = mini(min_val, iv)
		max_val = maxi(max_val, iv)
	var span: float = maxf(10000.0, float(max_val - min_val))
	var pad_left: float = 10.0
	var pad_right: float = 10.0
	var pad_top: float = 20.0
	var pad_bottom: float = 14.0
	var chart_w: float = maxf(10.0, area.x - pad_left - pad_right)
	var chart_h: float = maxf(10.0, area.y - pad_top - pad_bottom)

	# 绘制开局基准线 ($1,000)
	var base_ratio: float = clampf(float(starting_cents - min_val) / span, 0.0, 1.0)
	var base_y: float = pad_top + chart_h * (1.0 - base_ratio)
	draw_line(Vector2(pad_left, base_y), Vector2(area.x - pad_right, base_y), Color(0.94, 0.71, 0.36, 0.35), 1.0, true)

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
		draw_colored_polygon(poly, Color(0.29, 0.84, 0.89, 0.14))
		draw_polyline(pts, Color("49d6e4"), 2.0, true)
		var last_pt: Vector2 = pts[pts.size() - 1]
		var latest_val: int = int(history[count - 1])
		var dot_col: Color = Color("83c7a6") if latest_val >= starting_cents else Color("f08c82")
		draw_circle(last_pt, 3.5, dot_col)

	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font != null:
		var latest_cents: int = int(history[count - 1])
		var header_txt: String = "实时流动资产曲线 (峰值 $%d · 当前 $%d)" % [max_val / 100, latest_cents / 100]
		draw_string(font, Vector2(10, 14), header_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("91a5b4"))
