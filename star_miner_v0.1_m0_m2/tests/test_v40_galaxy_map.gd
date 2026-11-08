extends SceneTree

# godot --headless --path star_miner_v0.1_m0_m2 -s res://tests/test_v40_galaxy_map.gd
const State = preload("res://scripts/state/game_state.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const GalaxyMap = preload("res://scripts/ui/v40_galaxy_map.gd")

var selected: String = ""
var activated: String = ""


func _record_selected(mine_id: String) -> void:
	selected = mine_id


func _record_activated(mine_id: String) -> void:
	activated = mine_id


func _initialize() -> void:
	var state: GameState = State.new("A")
	var v40: Dictionary = V40.ensure_v40_state(state)
	var map: V40GalaxyMapView = GalaxyMap.new()
	get_root().add_child(map)
	map.size = Vector2(900, 430)
	map.set("state", state)
	map.mine_selected.connect(_record_selected)
	map.mine_activated.connect(_record_activated)
	var points: Array[Vector2] = []
	for mine_id in v40["mines"]:
		var id: String = str(mine_id)
		var pos: Vector2 = map.get_mine_screen_position(id)
		assert(pos.x > 0.0 and pos.y > 0.0)
		assert(map.pick_mine_at(pos) == id)
		for old_point in points:
			assert(old_point.distance_to(pos) > 64.0)
		points.append(pos)

	var cash_before: int = int(v40["cash_cr"])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.get_mine_screen_position("crimson_1")
	map._gui_input(click)
	assert(selected == "crimson_1")
	assert(activated == "") # Unowned mine click must not enter.
	assert(int(v40["cash_cr"]) == cash_before) # Selection is not a purchase.

	click.position = map.get_mine_screen_position("dawn_1")
	click.double_click = true
	map._gui_input(click)
	assert(selected == "dawn_1")
	assert(activated == "dawn_1")
	assert(int(v40["cash_cr"]) == cash_before)
	print("PASS: 6 V4 mines / hit testing / selection / license gate / no economic mutation")
	quit(0)
