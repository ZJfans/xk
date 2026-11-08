extends Control

## 09/10 全局赛博工业 UI 与集团总览视觉独立调试台 (corporate_demo.tscn)
## 供「全局赛博工业 UI 视觉 AI」独立预览 8 区块增量局部刷新、三口径财务趋势图、研究树卡片与 CRT 扫描线覆盖层。

const Contracts = preload("res://scripts/contracts/shared_contracts.gd")
const Kernel = preload("res://scripts/kernel/game_kernel.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const CorporateRenderer = preload("res://scripts/ui/v40_corporate_renderer.gd")
const VisualTheme = preload("res://scripts/ui/visual/visual_theme.gd")
const CyberFXDirector = preload("res://scripts/ui/visual/cyber_fx_director.gd")

var state: GameState
var kernel := Kernel.new()
var v40_corp_box: VBoxContainer
var visual_director: CanvasLayer

const INK := Color("e5edf1")
const MUTED := Color("94a7b3")
const EDGE := Color("2b4353")
const GOLD := Color("f2b55c")
const GREEN := Color("83c7a6")
const RED := Color("f08c82")
const CYAN := Color("49d6e4")


func _ready() -> void:
	var t := Theme.new()
	VisualTheme.polish(t)
	theme = t
	state = Contracts.build_mock_state("endgame_corp")

	visual_director = CyberFXDirector.new()
	add_child(visual_director)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	v40_corp_box = VBoxContainer.new()
	v40_corp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v40_corp_box.add_theme_constant_override("separation", 8)
	scroll.add_child(v40_corp_box)

	_refresh()


func _refresh() -> void:
	var v40: Dictionary = V40.ensure_v40_state(state)
	var fin: Dictionary = V40.financial_summary(v40)
	CorporateRenderer.render(self, v40, fin)


func _v40_cmd(cmd_type: String, params: Dictionary) -> void:
	var res: Dictionary = kernel.dispatch(state, cmd_type, params)
	if is_instance_valid(visual_director):
		visual_director.call("notify_operation", str(res.get("msg", res.get("error", cmd_type))), bool(res.get("ok", false)), cmd_type)
	_refresh()


func _v40_request_mining_action(cmd_type: String, params: Dictionary) -> void:
	_v40_cmd(cmd_type, params)


func _show_settlement(_saved: Dictionary = {}) -> void:
	if is_instance_valid(visual_director):
		visual_director.call("notify_operation", "30 日集团财报预览触发成功", true, "FinancialReport")


func _style(bg: Color, border: Color, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_top = 2
	box.set_corner_radius_all(mini(radius, 3))
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	return box


func _label(txt: String, size_px: int = 14, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _button(txt: String, callback: Callable, min_height: int = 34) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size.y = min_height
	b.pressed.connect(callback)
	return b
