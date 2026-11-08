class_name V40MiningInspector
extends PanelContainer

## Read-only mining target inspector. Never pays for mining or changes game state.
## Clicking a deposit selects it; only an explicit confirmation in MainScreen
## can dispatch the corresponding V40DawnEngine command.

signal route_requested(mode: String)
signal action_requested(command_type: String, params: Dictionary)
signal clear_requested()

const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const INK := Color("e5edf1")
const MUTED := Color("91a5b4")
const GOLD := Color("f2b55c")
const GREEN := Color("83c7a6")
const RED := Color("f08c82")
const CYAN := Color("49d6e4")
const ROUTES := ["auto", "detour_soft", "direct_hard"]

var state: GameState
var mine_id: String = ""
var deposit_index: int = -1
var title_label: Label
var mineral_label: Label
var quote_label: Label
var hint_label: Label
var route_choice: OptionButton
var action_button: Button
var clear_button: Button


func _ready() -> void:
	custom_minimum_size.y = 182.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101f2c")
	panel_style.border_color = Color("315873")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(9)
	add_theme_stylebox_override("panel", panel_style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	add_child(stack)

	var top := HBoxContainer.new()
	stack.add_child(top)
	title_label = _text("采矿目标 / 施工预览", 14, GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	clear_button = Button.new()
	clear_button.text = "清除选择"
	clear_button.pressed.connect(_on_clear_pressed)
	top.add_child(clear_button)

	mineral_label = _text("点击剖面中的矿体进行选择", 12, INK)
	stack.add_child(mineral_label)

	route_choice = OptionButton.new()
	route_choice.add_item("智能路线", 0)
	route_choice.add_item("软岩绕行", 1)
	route_choice.add_item("硬岩直穿（需 M1）", 2)
	route_choice.item_selected.connect(_on_route_selected)
	stack.add_child(route_choice)

	quote_label = _text("选择后展示井道费用、施工工期和目标储量。", 12, MUTED)
	stack.add_child(quote_label)
	hint_label = _text("选择目标本身不会扣费。", 12, CYAN)
	stack.add_child(hint_label)

	action_button = Button.new()
	action_button.text = "先选择矿脉"
	action_button.disabled = true
	action_button.pressed.connect(_on_action_pressed)
	stack.add_child(action_button)
	refresh_preview()


func _text(content: String, point_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label


func update_target(game_state: GameState, active_mine_id: String, selected_index: int) -> void:
	state = game_state
	mine_id = active_mine_id
	deposit_index = selected_index
	refresh_preview()


func refresh_preview() -> void:
	if not is_instance_valid(title_label):
		return
	route_choice.visible = false
	clear_button.disabled = deposit_index < 0
	action_button.disabled = true
	action_button.text = "先选择矿脉"
	title_label.text = "采矿目标 / 施工预览"
	mineral_label.text = "点击地下矿体：选中后查看成本及施工路线。"
	quote_label.text = "左键选择矿体；右键可循环切换全局井道路线。"
	hint_label.text = "仅选择目标不会扣除资金。"
	hint_label.add_theme_color_override("font_color", CYAN)
	if state == null:
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	if mine.is_empty():
		return
	var deposits: Array = mine.get("deposits", [])
	if deposit_index < 0 or deposit_index >= deposits.size():
		return

	var dep: Dictionary = deposits[deposit_index]
	var revealed: bool = bool(dep.get("revealed", false))
	var remaining: int = int(dep.get("remaining_t", 0))
	var owned: bool = bool(mine.get("license_owned", false))
	var heads: int = int(dep.get("heads", 0))
	var mine_name: String = str(mine.get("name_zh", mine_id))
	title_label.text = "%s · 施工预览" % mine_name
	mineral_label.text = "%s | %s | %s | 当前采掘头 %d" % [
		str(dep.get("name_zh", "未知矿体")),
		"硬岩" if bool(dep.get("hard_rock", false)) else "软岩",
		"剩余 %d t" % remaining if revealed else "储量尚未揭示",
		heads
	]
	if not owned:
		quote_label.text = "该矿区尚未取得开采许可。"
		hint_label.text = "先到星图购买或竞拍许可证。"
		return

	if not revealed:
		var scan_cost: int = 0 if int(v40.get("free_scans_left", 0)) > 0 else 300
		quote_label.text = "定点地面扫描费用：%d Cr（%s）" % [scan_cost, "免费次数可用" if scan_cost == 0 else "收费扫描"]
		action_button.text = "预览并确认扫描"
		action_button.disabled = V40.available_cash_cr(v40) < scan_cost
		hint_label.text = "只揭示当前选中矿体，不会扫描其他目标。"
		return

	if remaining <= 0:
		quote_label.text = "该矿体已采尽。"
		hint_label.text = "考虑迁移已有采掘头，或选择其他矿体。"
		return

	route_choice.visible = true
	var route_mode: String = str(v40.get("bore_route_mode", "auto"))
	var route_idx: int = ROUTES.find(route_mode)
	route_choice.select(maxi(0, route_idx))
	var plan: Dictionary = V40.calc_bore_plan(v40, mine_id, deposit_index)
	quote_label.text = "%s\n井道 %d Cr + 采掘头 %d Cr = 总计 %d Cr | 工期 %.1f 日" % [
		str(plan.get("route_desc_zh", "")),
		int(plan.get("bore_cost_cr", 0)),
		int(plan.get("head_cost_cr", 0)),
		int(plan.get("total_cost_cr", 0)),
		float(plan.get("work_days", 0.0))
	]
	if not bool(plan.get("can_build", false)):
		hint_label.text = str(plan.get("error", "当前路线无法施工。"))
		hint_label.add_theme_color_override("font_color", RED)
	elif V40.available_cash_cr(v40) < int(plan.get("total_cost_cr", 0)):
		hint_label.text = "资金不足：可支配 %d Cr。" % V40.available_cash_cr(v40)
		hint_label.add_theme_color_override("font_color", RED)
	else:
		hint_label.text = "可施工。点击下方按钮后还需要再次确认。"
		hint_label.add_theme_color_override("font_color", GREEN)
		action_button.disabled = false
	action_button.text = "预览并确认安装采掘头"


func _on_route_selected(index: int) -> void:
	if index >= 0 and index < ROUTES.size():
		route_requested.emit(str(ROUTES[index]))


func _on_action_pressed() -> void:
	if state == null or deposit_index < 0:
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	var deposits: Array = mine.get("deposits", [])
	if deposit_index >= deposits.size() or action_button.disabled:
		return
	var command_type: String = "PlaceMiningHead" if bool(deposits[deposit_index].get("revealed", false)) else "ScanArea"
	action_requested.emit(command_type, {"mine_id": mine_id, "deposit_index": deposit_index})


func _on_clear_pressed() -> void:
	clear_requested.emit()
