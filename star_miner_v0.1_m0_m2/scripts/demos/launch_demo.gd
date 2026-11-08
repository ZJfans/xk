extends Control

## 03 航天与发射回收视觉独立调试台 (launch_demo.tscn)
## 供「火箭发射与回收电影演出 AI」独立预览 8.4 秒火箭升空过场与 Astra 全景起降遥测舱，无需启动完整经营流程。

const Contracts = preload("res://scripts/contracts/shared_contracts.gd")
const Kernel = preload("res://scripts/kernel/game_kernel.gd")
const LaunchView = preload("res://scripts/ui/launch_recovery_view.gd")
const LaunchCinematic = preload("res://scripts/ui/visual/launch_cinematic.gd")
const VisualTheme = preload("res://scripts/ui/visual/visual_theme.gd")

var state: GameState
var kernel := Kernel.new()
var hud_view: Control
var cinematic: Control


func _ready() -> void:
	var t := Theme.new()
	VisualTheme.polish(t)
	theme = t
	state = Contracts.build_mock_state("busy_launch_pad")

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	vbox.add_child(toolbar)

	var play_btn := Button.new()
	play_btn.text = "🎬 播放 8.4 秒全屏点火升空电影过场"
	play_btn.pressed.connect(func() -> void:
		cinematic.call("play_launch", "晨曦一号矿区 · 独立视觉调试")
	)
	toolbar.add_child(play_btn)

	var win_btn := Button.new()
	win_btn.text = "🕒 切换发射窗口气象 (SelectLaunchWindow)"
	win_btn.pressed.connect(func() -> void:
		kernel.dispatch(state, "SelectLaunchWindow", {})
		hud_view.queue_redraw()
	)
	toolbar.add_child(win_btn)

	var ovh_btn := Button.new()
	ovh_btn.text = "✥ 助推器姿态微调检修 (OverhaulShip)"
	ovh_btn.pressed.connect(func() -> void:
		kernel.dispatch(state, "OverhaulShip", {"ship_id": 1})
		hud_view.queue_redraw()
	)
	toolbar.add_child(ovh_btn)

	hud_view = LaunchView.new()
	hud_view.set("compact_mode", false)
	hud_view.set("state", state)
	hud_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hud_view)

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	cinematic = LaunchCinematic.new()
	layer.add_child(cinematic)
	cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
