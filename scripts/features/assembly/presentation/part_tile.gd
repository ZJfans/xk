extends Button
## Godot-native drag source. Part and slot are explicit to avoid illegal placement.
var slot_id: String = ""
var part_name: String = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_id == "" or part_name == "":
		return null
	var preview := Label.new()
	preview.text = "  " + part_name + "  "
	preview.add_theme_color_override("font_color", Color("59dced"))
	preview.add_theme_font_size_override("font_size", 17)
	set_drag_preview(preview)
	return {"slot": slot_id, "part": part_name}
