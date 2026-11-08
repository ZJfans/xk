extends RefCounted
## V0.6 Corporate Cyber-Industrial UI theme.
## Runtime-only styling: no changes to the economic simulation or saved data.

const BG := Color("080d18")
const PANEL := Color("101d2c")
const EDGE := Color("2b4c64")
const CYAN := Color("3be0ef")
const GOLD := Color("f5b65d")
const SUCCESS := Color("62e3ae")
const TEXT := Color("e6f4ff")
const SUBTLE := Color("91adbf")

static func _panel(fill: Color, edge: Color, height: int = 2, margin: int = 9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.border_width_left = height
	s.set_corner_radius_all(3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = maxi(5, margin - 2)
	s.content_margin_bottom = maxi(5, margin - 2)
	s.shadow_color = Color(edge.r, edge.g, edge.b, 0.08)
	s.shadow_size = 3
	return s

static func polish(theme: Theme) -> void:
	# Functional contrast and keyboard focus remain more important than glow.
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("718697"))
	theme.set_stylebox("normal", "Button", _panel(Color("12283a"), EDGE, 1, 9))
	theme.set_stylebox("hover", "Button", _panel(Color("1c4050"), CYAN, 2, 9))
	theme.set_stylebox("pressed", "Button", _panel(Color("243743"), GOLD, 2, 9))
	theme.set_stylebox("disabled", "Button", _panel(Color("0b1925"), Color("304354"), 1, 9))
	var focus := _panel(Color(0, 0, 0, 0), GOLD, 2, 7)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)

	for control in ["OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", control, _panel(Color("12283a"), EDGE, 1, 9))
		theme.set_stylebox("hover", control, _panel(Color("1b3b4b"), CYAN, 2, 9))
		theme.set_stylebox("pressed", control, _panel(Color("253848"), GOLD, 2, 9))
		theme.set_color("font_color", control, TEXT)

	theme.set_stylebox("panel", "PanelContainer", _panel(Color("101b2b"), EDGE, 1, 9))
	theme.set_stylebox("panel", "TabContainer", _panel(Color("0b1826"), CYAN.darkened(0.55), 1, 13))
	theme.set_stylebox("tab_selected", "TabContainer", _panel(Color("12364b"), CYAN, 2, 11))
	theme.set_stylebox("tab_hovered", "TabContainer", _panel(Color("1a354a"), GOLD, 1, 11))
	theme.set_stylebox("tab_unselected", "TabContainer", _panel(Color("0b1825"), EDGE, 1, 11))
	theme.set_color("font_selected_color", "TabContainer", TEXT)
	theme.set_color("font_unselected_color", "TabContainer", SUBTLE)

	theme.set_stylebox("normal", "LineEdit", _panel(Color("081521"), EDGE, 1, 7))
	theme.set_stylebox("focus", "LineEdit", _panel(Color("122c3c"), CYAN, 2, 7))
	theme.set_stylebox("background", "ProgressBar", _panel(Color("07121d"), Color("21364b"), 1, 0))
	theme.set_stylebox("fill", "ProgressBar", _panel(CYAN.darkened(0.18), CYAN, 1, 0))
	theme.set_stylebox("panel", "PopupMenu", _panel(Color("0b1b2b"), CYAN, 1, 10))
	theme.set_stylebox("hover", "PopupMenu", _panel(Color("174255"), GOLD, 1, 7))
	theme.set_stylebox("panel", "AcceptDialog", _panel(Color("0b1b29"), CYAN, 2, 13))
	theme.set_stylebox("panel", "ConfirmationDialog", _panel(Color("0c1e2c"), GOLD, 2, 13))
	theme.set_stylebox("panel", "TooltipPanel", _panel(Color("091824"), CYAN, 1, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
