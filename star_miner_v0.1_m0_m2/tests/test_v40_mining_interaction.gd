extends SceneTree

# Godot 4.x headless regression for the stage-3 V4 mining selection flow.
# godot --headless --path star_miner_v0.1_m0_m2 -s res://tests/test_v40_mining_interaction.gd
const State = preload("res://scripts/state/game_state.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Inspector = preload("res://scripts/ui/v40_mining_inspector.gd")
const CrossSection = preload("res://scripts/ui/planet_cross_section.gd")

var observed_action: String = ""
var observed_command: String = ""
var observed_params: Dictionary = {}


func _record_action(action_id: String) -> void:
	observed_action = action_id


func _record_command(cmd_type: String, params: Dictionary) -> void:
	observed_command = cmd_type
	observed_params = params


func _initialize() -> void:
	var state: GameState = State.new("A")
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine: Dictionary = v40["mines"]["dawn_1"]
	var deposits: Array = mine["deposits"]
	assert(not bool(deposits[1]["revealed"]))
	assert(not bool(deposits[2]["revealed"]))

	var cash_before: int = int(v40["cash_cr"])
	var scans_before: int = int(v40["free_scans_left"])
	var bad: Dictionary = V40.execute_command(state, "ScanArea", {"mine_id": "dawn_1", "deposit_index": 999})
	assert(not bool(bad.get("ok", false)))
	assert(int(v40["cash_cr"]) == cash_before)
	assert(int(v40["free_scans_left"]) == scans_before)

	# Previously ScanArea always revealed index 1, regardless of clicked index 2.
	var scanned: Dictionary = V40.execute_command(state, "ScanArea", {"mine_id": "dawn_1", "deposit_index": 2})
	assert(bool(scanned.get("ok", false)))
	assert(bool(deposits[2]["revealed"]))
	assert(not bool(deposits[1]["revealed"]))
	assert(int(v40["free_scans_left"]) == scans_before - 1)
	assert(int(v40["cash_cr"]) == cash_before)

	var inspector: V40MiningInspector = Inspector.new()
	get_root().add_child(inspector)
	inspector.update_target(state, "dawn_1", 2)
	assert(inspector.deposit_index == 2)
	assert(not inspector.action_button.disabled)
	assert(inspector.quote_label.text.contains("Cr"))
	inspector.action_requested.connect(_record_command)
	inspector._on_action_pressed()
	assert(observed_command == "PlaceMiningHead")
	assert(int(observed_params["deposit_index"]) == 2)
	assert(int(v40["cash_cr"]) == cash_before) # Selection and preview never pay.
	assert(int(deposits[2]["heads"]) == 0)

	# Click a known deposit: cross-section must emit a selection action only.
	var cross: PlanetCrossSectionView = CrossSection.new()
	get_root().add_child(cross)
	cross.size = Vector2(900, 460)
	cross.set("state", state)
	cross.cross_section_action.connect(_record_action)
	var surf_y: float = clampf(cross.size.y * 0.25, 78.0, 122.0)
	var d: Dictionary = deposits[2]
	var pos: Vector2 = cross._grid_to_screen(int(d["gx"]), int(d["gy"]), 900.0, 460.0, surf_y)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pos
	cross._gui_input(click)
	assert(observed_action == "v40_select_deposit:2")
	assert(int(v40["cash_cr"]) == cash_before)
	assert(int(deposits[2]["heads"]) == 0)

	# Legacy (unspecified index) ScanArea keeps working for toolbar/API callers.
	var classic_scan: Dictionary = V40.execute_command(state, "ScanArea", {"mine_id": "dawn_1"})
	assert(bool(classic_scan.get("ok", false)))
	assert(bool(deposits[1]["revealed"]))
	print("PASS: targeted scan / invalid target no charge / inspector read-only / click selects only / legacy fallback")
	quit(0)
