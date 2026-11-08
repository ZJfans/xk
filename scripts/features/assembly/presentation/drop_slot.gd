extends PanelContainer
## Godot-native drag target. No economy writes; emits assembly intent.
signal part_dropped(slot_id: String, part_name: String)
signal slot_clicked(slot_id: String)
var slot_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Nested labels should not intercept drag/drop or slot click events.
	for child in get_children():
		_disable_child_mouse(child)

func _disable_child_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_child_mouse(child)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("slot", "")) == slot_id

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		part_dropped.emit(slot_id, str(data.get("part", "")))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_id)
		accept_event()
