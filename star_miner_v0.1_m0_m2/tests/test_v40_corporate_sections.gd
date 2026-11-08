extends SceneTree
## Stage 5 headless test for independent V4 corporate panel refresh.
## godot --headless --path star_miner_v0.1_m0_m2 --script res://tests/test_v40_corporate_sections.gd

const State = preload("res://scripts/state/game_state.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Renderer = preload("res://scripts/ui/v40_corporate_renderer.gd")

class MockUI:
	extends Control
	var state: GameState
	var v40_corp_box: VBoxContainer

	func _init() -> void:
		v40_corp_box = VBoxContainer.new()
		add_child(v40_corp_box)

	func _clear(target: Node) -> void:
		for child in target.get_children():
			target.remove_child(child)
			child.queue_free()

	func _style(bg: Color, border_color: Color, radius: int = 6, padding: int = 8) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = border_color
		box.set_border_width_all(1)
		box.set_corner_radius_all(radius)
		box.set_content_margin_all(padding)
		return box

	func _label(message: String, font_size: int = 14, color: Color = Color.WHITE) -> Label:
		var out := Label.new()
		out.text = message
		out.add_theme_font_size_override("font_size", font_size)
		out.add_theme_color_override("font_color", color)
		return out

	func _button(message: String, callback: Callable, min_height: int = 26) -> Button:
		var out := Button.new()
		out.text = message
		out.custom_minimum_size.y = min_height
		out.pressed.connect(callback)
		return out

	func _v40_cmd(_command_type: String, _params: Dictionary) -> void:
		pass

	func _show_settlement(_options: Dictionary = {}) -> void:
		pass


func _initialize() -> void:
	var shell := MockUI.new()
	root.add_child(shell)
	shell.state = State.new("A")
	var v40: Dictionary = V40.ensure_v40_state(shell.state)
	var original_cash: int = int(v40["cash_cr"])
	var fin: Dictionary = V40.financial_summary(v40)
	assert(Renderer.render(shell, v40, fin), "First render must build all 8 groups")
	assert(shell.v40_corp_box.get_child_count() == 9, "Header + eight persistent groups")
	for key in Renderer.SECTION_KEYS:
		var slot: Node = shell.v40_corp_box.get_node_or_null(NodePath("Corp_" + str(key)))
		assert(slot != null and slot.get_child_count() > 0, "Empty or missing corporate group: " + str(key))
	var counts: Dictionary = shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {}).duplicate(true)
	assert(counts.size() == 8)
	assert(not Renderer.render(shell, v40, fin), "Unchanged state should rebuild nothing")
	assert(shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {}) == counts)

	v40["cash_cr"] = int(v40["cash_cr"]) - 123
	fin = V40.financial_summary(v40)
	assert(Renderer.render(shell, v40, fin))
	var after_cash: Dictionary = shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {}).duplicate(true)
	assert(int(after_cash["financial"]) == int(counts["financial"]) + 1)
	assert(int(after_cash["inventory"]) == int(counts["inventory"]), "Cash must not rebuild inventory")
	assert(int(after_cash["research"]) == int(counts["research"]), "Cash must not rebuild research")

	var research: Dictionary = v40["research"]
	research["paused"] = not bool(research.get("paused", false))
	assert(Renderer.render(shell, v40, V40.financial_summary(v40)))
	var after_research: Dictionary = shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {}).duplicate(true)
	assert(int(after_research["research"]) == int(after_cash["research"]) + 1)
	assert(int(after_research["inventory"]) == int(after_cash["inventory"]))

	var port: Dictionary = v40["port_inventories"]["dawn_port"]
	port["minerals"]["iron_titanium"] = int(port["minerals"]["iron_titanium"]) + 5
	assert(Renderer.render(shell, v40, V40.financial_summary(v40)))
	var after_inventory: Dictionary = shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {}).duplicate(true)
	assert(int(after_inventory["inventory"]) == int(after_research["inventory"]) + 1)
	assert(int(after_inventory["refining"]) == int(after_research["refining"]) + 1)

	# A loaded/replaced GameState must invalidate all cached panel signatures.
	shell.state = State.new("A")
	var new_v40: Dictionary = V40.ensure_v40_state(shell.state)
	assert(Renderer.render(shell, new_v40, V40.financial_summary(new_v40)))
	var new_counts: Dictionary = shell.v40_corp_box.get_meta(Renderer.COUNTS_KEY, {})
	for key in Renderer.SECTION_KEYS:
		assert(int(new_counts.get(str(key), 0)) == 1)
	assert(shell.v40_corp_box.get_child_count() == 9)
	assert(original_cash == 30000, "Corporate view must not mutate the original cash value")
	print("PASS: eight stable sections; unchanged state skips redraw; targeted cash/research/inventory refresh; state replacement resets cache")
	quit(0)
