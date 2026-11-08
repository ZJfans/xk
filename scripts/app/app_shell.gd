extends Control
## UX shell owns navigation. All feature screens are isolated and replaceable.
## Neither shell nor screens write the legacy V4 save or directly run V40DawnEngine.
const UI = preload("res://scripts/ui/design_system.gd")
const Session = preload("res://scripts/core/ux_session.gd")
const Screens := {
	"hq": preload("res://scenes/screens/hq_screen.tscn"),
	"auction": preload("res://scenes/screens/auction_screen.tscn"),
	"expedition": preload("res://scenes/screens/expedition_screen.tscn"),
	"assembly": preload("res://scenes/screens/assembly_screen.tscn"),
	"market": preload("res://scenes/screens/market_screen.tscn"),
	"settlement": preload("res://scenes/screens/settlement_screen.tscn")
}
const NAV := [
	["hq", "总部"], ["auction", "矿区竞拍"], ["expedition", "太空采矿"],
	["assembly", "火箭装配"], ["market", "市场"], ["settlement", "结算"]
]
var session: UXSession = Session.new()
var stage: Control
var active_screen: UXScreen
var balance_label: Label
var objective_label: Label
var toast_label: Label
var nav_buttons: Dictionary = {}
var active_id: String = "hq"

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei", "Arial"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 15
	theme = t
	var background := ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var root := UI.column(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_make_header(root)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 15)
	root.add_child(margin)
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(stage)
	_make_footer(root)
	_navigate("hq")

func _make_header(root: VBoxContainer) -> void:
	var top := UI.pane(UI.SURFACE, 8)
	root.add_child(top)
	var r := UI.row(18)
	top.add_child(r)
	var brand := UI.txt("ROCKET PROSPECTORS   /   星矿大亨", 17, UI.AMBER)
	brand.custom_minimum_size.x = 300
	r.add_child(brand)
	for link in NAV:
		var id: String = link[0]
		var btn := UI.action(link[1], _navigate.bind(id), false)
		btn.custom_minimum_size = Vector2(100, 38)
		r.add_child(btn)
		nav_buttons[id] = btn
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(spacer)
	balance_label = UI.txt("", 15, UI.GREEN)
	r.add_child(balance_label)

func _make_footer(root: VBoxContainer) -> void:
	var foot := UI.pane(UI.SURFACE, 9)
	root.add_child(foot)
	var r := UI.row()
	foot.add_child(r)
	objective_label = UI.txt("", 13, UI.SUB)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(objective_label)
	toast_label = UI.txt("UX PROTOTYPE · 非正式经济规则", 12, UI.AMBER)
	r.add_child(toast_label)

func _navigate(screen_id: String) -> void:
	if not Screens.has(screen_id):
		return
	active_id = screen_id
	if is_instance_valid(active_screen):
		stage.remove_child(active_screen)
		active_screen.queue_free()
	active_screen = Screens[screen_id].instantiate() as UXScreen
	active_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(active_screen)
	active_screen.route_requested.connect(_navigate)
	active_screen.action_requested.connect(_apply_action)
	active_screen.mount(session)
	_refresh_shell()

func _apply_action(action_id: String, payload: Dictionary) -> void:
	var result: Dictionary = session.apply(action_id, payload)
	toast_label.text = str(result.get("message", ""))
	toast_label.add_theme_color_override("font_color", UI.GREEN if bool(result.get("ok", false)) else UI.RED)
	var route: String = str(result.get("route", ""))
	if route != "":
		_navigate(route)
	elif is_instance_valid(active_screen):
		active_screen.render()
	_refresh_shell()

func _refresh_shell() -> void:
	balance_label.text = "%s Cr" % _commas(session.cash)
	objective_label.text = session.objective()
	for id in nav_buttons:
		nav_buttons[id].add_theme_color_override("font_color", UI.CYAN if id == active_id else UI.SUB)

func _commas(n: int) -> String:
	var s: String = str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
