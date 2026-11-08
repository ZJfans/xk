extends RefCounted
## Common UX V1 presentation tokens. No economic state, no game rules.
const BG := Color("08111b")
const SURFACE := Color("101f2d")
const SURFACE_HIGH := Color("172d3e")
const STROKE := Color("2d5166")
const TEXT := Color("e8f3fa")
const SUB := Color("92abbc")
const CYAN := Color("59dced")
const AMBER := Color("f1b464")
const GREEN := Color("75ddb2")
const RED := Color("f18881")

static func skin(fill: Color = SURFACE, outline: Color = STROKE, radius: int = 9, inset: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = outline
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = inset
	s.content_margin_right = inset
	s.content_margin_top = inset
	s.content_margin_bottom = inset
	return s

static func pane(fill: Color = SURFACE, inset: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", skin(fill, STROKE, 8, inset))
	return p

static func txt(value: String, size_pt: int = 16, color: Color = TEXT) -> Label:
	var t := Label.new()
	t.text = value
	t.add_theme_font_size_override("font_size", size_pt)
	t.add_theme_color_override("font_color", color)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return t

static func title(value: String, description: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(txt(value, 27, TEXT))
	if description != "":
		v.add_child(txt(description, 13, SUB))
	return v

static func action(label_text: String, callback: Callable, primary: bool = false, min_width: float = 0.0, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(min_width, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", BG if primary else TEXT)
	b.add_theme_stylebox_override("normal", skin(CYAN if primary else SURFACE_HIGH, CYAN if primary else STROKE, 6, 11))
	b.add_theme_stylebox_override("hover", skin(Color("a0f0f3") if primary else Color("214658"), CYAN, 6, 11))
	b.add_theme_stylebox_override("pressed", skin(AMBER, AMBER, 6, 11))
	b.disabled = not enabled
	b.pressed.connect(callback)
	return b

static func row(sep: int = 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	return r

static func column(sep: int = 12) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", sep)
	return c

static func metric(name: String, value: String, tint: Color = CYAN) -> PanelContainer:
	var p := pane(SURFACE_HIGH, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := column(6)
	p.add_child(v)
	v.add_child(txt(name, 12, SUB))
	v.add_child(txt(value, 22, tint))
	return p

static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 5)
	return s
