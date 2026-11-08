extends CanvasLayer
## Global nonblocking post-process, scene focus, and command feedback.
## No connection to the simulation; every visual event follows an engine result.

const Overlay = preload("res://scripts/ui/visual/cyber_overlay.gd")
const ScanShader = preload("res://scripts/ui/visual/shaders/ui_scanline.gdshader")
const CYAN := Color("40d9f5")
const GOLD := Color("f5b65d")
const RED := Color("f57a74")
const GREEN := Color("62e3ae")

var _overlay: Control
var _scan: ColorRect
var _toasts: VBoxContainer
var _focus: ColorRect
var reduce_motion: bool = false

func _ready() -> void:
	layer = 70
	_scan = ColorRect.new()
	_scan.color = Color.WHITE
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scan)
	_scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = ScanShader
	_scan.material = mat

	_overlay = Overlay.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_focus = ColorRect.new()
	_focus.color = Color(0.22, 0.76, 0.92, 0.0)
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_focus)
	_focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.offset_left = -458.0
	_toasts.offset_right = -18.0
	_toasts.offset_top = -310.0
	_toasts.offset_bottom = -68.0

func set_reduced_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if is_instance_valid(_scan) and _scan.material is ShaderMaterial:
		(_scan.material as ShaderMaterial).set_shader_parameter("intensity", 0.10 if enabled else 0.35)
	if is_instance_valid(_overlay):
		_overlay.set("reduce_motion", enabled)

func focus_scene(screen_id: String) -> void:
	if reduce_motion or not is_instance_valid(_focus):
		return
	var tint: Color = GOLD if screen_id == "corp" else CYAN
	_focus.color = Color(tint.r, tint.g, tint.b, 0.075)
	var tween := _focus.create_tween()
	tween.tween_property(_focus, "color:a", 0.0, 0.32)
	if is_instance_valid(_overlay):
		_overlay.call("impact", Vector2(34.0, 91.0), false)

func notify_operation(message: String, success: bool, command: String = "") -> void:
	if message.strip_edges().is_empty():
		return
	var col: Color = GREEN if success else RED
	if command in ["BuildDrill", "PlaceMiningHead", "InvestStarport", "StartResearch"] and success:
		col = GOLD
	if is_instance_valid(_overlay):
		_overlay.call("impact", Vector2(90.0, maxf(130.0, get_viewport().get_visible_rect().size.y - 115.0)), not success)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.085, 0.13, 0.94)
	panel.border_color = col
	panel.set_border_width_all(1)
	panel.border_width_left = 3
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(11)
	card.add_theme_stylebox_override("panel", panel)
	var label := Label.new()
	label.text = ("◆ 操作完成  /  " if success else "⚠ 操作未执行  /  ") + message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("e8f5fd"))
	label.add_theme_font_size_override("font_size", 12)
	card.add_child(label)
	_toasts.add_child(card)
	while _toasts.get_child_count() > 4:
		var oldest: Node = _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.16)
	tw.tween_interval(2.8 if success else 4.1)
	tw.tween_property(card, "modulate:a", 0.0, 0.35)
	tw.tween_callback(Callable(card, "queue_free"))
