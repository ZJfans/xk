extends Control
## Independent UX scene sandbox: F6 can run any `scenes/demos/*_demo.tscn`.
@export var screen_id: String = "hq"
const UI = preload("res://scripts/ui/design_system.gd")
const Session = preload("res://scripts/core/ux_session.gd")
const Pages = {
	"hq": preload("res://scenes/screens/hq_screen.tscn"),
	"auction": preload("res://scenes/screens/auction_screen.tscn"),
	"expedition": preload("res://scenes/screens/expedition_screen.tscn"),
	"assembly": preload("res://scenes/screens/assembly_screen.tscn"),
	"market": preload("res://scenes/screens/market_screen.tscn"),
	"settlement": preload("res://scenes/screens/settlement_screen.tscn")
}
var session = Session.new()
var content: Control
var current: UXScreen
var notice: Label

func _ready() -> void:
	if screen_id in ["expedition", "assembly", "market", "settlement"]:
		session.apply("win_lot", {"lot": "F-01", "price": 7600})
	if screen_id in ["market", "settlement"]:
		session.apply("scan", {"body":"A-03"})
		session.apply("deploy")
		session.apply("dispatch")
	if screen_id == "settlement":
		session.apply("sell", {"buyer": "赤曜工业联盟"})
	var backdrop := ColorRect.new()
	backdrop.color = UI.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var layout := UI.column(0)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var top := UI.pane(UI.SURFACE, 8)
	layout.add_child(top)
	var header := UI.row()
	top.add_child(header)
	header.add_child(UI.txt("INDEPENDENT DEMO  /  " + screen_id, 16, UI.AMBER))
	header.add_child(UI.action("返回完整六屏原型", _main))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(space)
	header.add_child(UI.txt("开发专用 · 资金/经营均为模拟数据", 13, UI.SUB))
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	layout.add_child(margin)
	content = Control.new()
	margin.add_child(content)
	notice = UI.txt("独立 Demo", 13, UI.GREEN)
	layout.add_child(notice)
	_navigate(screen_id)

func _navigate(target: String) -> void:
	if not Pages.has(target):
		return
	if is_instance_valid(current):
		content.remove_child(current)
		current.queue_free()
	current = Pages[target].instantiate() as UXScreen
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(current)
	current.route_requested.connect(_navigate)
	current.action_requested.connect(_action)
	current.mount(session)

func _action(id: String, args: Dictionary) -> void:
	var outcome: Dictionary = session.apply(id, args)
	notice.text = str(outcome.get("message",""))
	var destination: String = str(outcome.get("route",""))
	if destination != "":
		_navigate(destination)
	else:
		current.render()

func _main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
