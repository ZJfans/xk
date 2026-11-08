extends SceneTree
## Godot command: godot --headless --path <project> --script res://tests/visual_smoke.gd

func _initialize() -> void:
	var paths: Array[String] = [
		"res://scripts/ui/visual/visual_theme.gd",
		"res://scripts/ui/visual/cyber_fx_director.gd",
		"res://scripts/ui/visual/cyber_overlay.gd",
		"res://scripts/ui/visual/mining_fx_layer.gd",
		"res://scripts/ui/visual/launch_cinematic.gd",
		"res://scripts/ui/visual/shaders/ui_scanline.gdshader",
		"res://scripts/ui/visual/shaders/nebula_field.gdshader",
		"res://scripts/ui/main_screen.gd",
		"res://scripts/ui/planet_cross_section.gd",
		"res://scripts/ui/v40_galaxy_map.gd"
	]
	var bad: int = 0
	for path in paths:
		var res: Resource = load(path)
		if res == null:
			push_error("Visual V0.6 missing or invalid: " + path)
			bad += 1
	print("Visual smoke: %d resources, errors=%d" % [paths.size(), bad])
	quit(1 if bad > 0 else 0)
