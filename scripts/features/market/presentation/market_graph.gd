extends Control
## Deliberately labeled fictional quote curves for UX comprehension tests.
const UI = preload("res://scripts/ui/design_system.gd")

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO,size),Color("0c1a27"))
	var r := Rect2(24,30,maxf(80,w-48),maxf(90,h-65))
	for i in range(5):
		var y: float = r.position.y+r.size.y*float(i)/4.0
		draw_line(Vector2(r.position.x,y),Vector2(r.position.x+r.size.x,y),Color(0.36,0.51,0.61,0.20),1.0)
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in range(60):
		var f: float = float(i)/59.0
		a.append(Vector2(r.position.x+f*r.size.x,r.position.y+r.size.y*(0.55-0.26*sin(f*10.0+0.5)-0.08*cos(f*27.0))))
		b.append(Vector2(r.position.x+f*r.size.x,r.position.y+r.size.y*(0.44+0.24*sin(f*8.2+0.8))))
	draw_polyline(a,UI.CYAN,2.2,true)
	draw_polyline(b,UI.AMBER,2.2,true)
	var font: Font = get_theme_default_font()
	draw_string(font,Vector2(30,20),"双买方模拟行情   /   青：晨曦    金：赤曜",HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.SUB)
	draw_string(font,Vector2(30,h-12),"时间 →    本图仅展示 UX，不代表引擎报价",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.SUB)
