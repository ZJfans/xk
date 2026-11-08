extends Control

## 02 采矿与设施视觉独立调试台 (mining_demo.tscn)
## 供「采矿现场视觉 AI」独立打开测试钻机、矿脉、声呐扫描、路线预览与激光火花特效，无需启动完整经营主界面。

const Contracts = preload("res://scripts/contracts/shared_contracts.gd")
const Kernel = preload("res://scripts/kernel/game_kernel.gd")
const CrossSection = preload("res://scripts/ui/planet_cross_section.gd")
const Inspector = preload("res://scripts/ui/v40_mining_inspector.gd")
const VisualTheme = preload("res://scripts/ui/visual/visual_theme.gd")

var state: GameState
var kernel := Kernel.new()
var cross_view: Control
var inspector: Control


func _ready() -> void:
	var t := Theme.new()
	VisualTheme.polish(t)
	theme = t
	state = Contracts.build_mock_state("midgame_all")

	var split := HBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 10)
	add_child(split)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_col)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	left_col.add_child(toolbar)
	for pair in [
		["🛰 触发扫描波 (ScanArea)", "ScanArea"],
		["⛏ 触发建钻井光环 (BuildDrill)", "BuildDrill"],
		["⚙ 触发下采掘头脉冲 (PlaceMiningHead)", "PlaceMiningHead"],
		["🔄 切换软硬岩路线", "ToggleBoreRouteMode"]
	]:
		var btn := Button.new()
		btn.text = pair[0]
		var cmd_name: String = pair[1]
		btn.pressed.connect(func() -> void:
			kernel.dispatch(state, cmd_name, {"deposit_index": 1})
			cross_view.call("emit_visual_event", cmd_name)
			_refresh()
		)
		toolbar.add_child(btn)

	cross_view = CrossSection.new()
	cross_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cross_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(cross_view)

	inspector = Inspector.new()
	inspector.custom_minimum_size = Vector2(310, 0)
	split.add_child(inspector)
	_refresh()


func _refresh() -> void:
	cross_view.set("state", state)
	cross_view.queue_redraw()
	inspector.call("refresh_from_state", state, 0)
