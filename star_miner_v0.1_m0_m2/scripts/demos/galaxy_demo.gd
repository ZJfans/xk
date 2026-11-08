extends Control

## 01 星系与探索视觉独立调试台 (galaxy_demo.tscn)
## 供「深空星图与着色器视觉 AI」独立调试程序化星云 Shader、航线流动信标与星球扫描准星。

const Contracts = preload("res://scripts/contracts/shared_contracts.gd")
const GalaxyMap = preload("res://scripts/ui/v40_galaxy_map.gd")
const VisualTheme = preload("res://scripts/ui/visual/visual_theme.gd")

var state: GameState
var map_view: Control


func _ready() -> void:
	var t := Theme.new()
	VisualTheme.polish(t)
	theme = t
	state = Contracts.build_mock_state("midgame_all")

	map_view = GalaxyMap.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.set("state", state)
	add_child(map_view)
