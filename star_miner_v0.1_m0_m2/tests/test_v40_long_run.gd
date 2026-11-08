extends SceneTree

# Run: godot --headless --path star_miner_v0.1_m0_m2 -s res://tests/test_v40_long_run.gd
const State = preload("res://scripts/state/game_state.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Save = preload("res://scripts/services/save_service.gd")

func _initialize() -> void:
    var state: GameState = State.new("A")
    var v40: Dictionary = V40.ensure_v40_state(state)
    var starting_cash: int = int(v40["cash_cr"])
    assert(starting_cash > 0)

    for i in range(140): # Day 70, beyond legacy Day 30 end-of-season.
        state.current_tick += 1
        var result: Dictionary = V40.step_v40_simulation(state, 0.5)
        assert(bool(result.get("ok", false)))
        assert(not state.season_ended)
        assert(state.cash_cents == int(v40["cash_cr"]) * 100)
    assert(is_equal_approx(float(v40["game_day"]), 70.0))

    var test_folder: String = "user://stage1_v40_regression/"
    var make_dir_err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_folder))
    assert(make_dir_err == OK)
    var previous_folder: String = Save.folder
    Save.folder = test_folder
    var saved: Dictionary = Save.save_game(state)
    assert(bool(saved.get("ok", false)))
    var loaded: Dictionary = Save.load_game()
    assert(bool(loaded.get("ok", false)))
    var restored: GameState = loaded["state"]
    assert(restored.current_tick == 140)
    assert(not restored.season_ended)
    assert(int(restored.stats["v40"]["cash_cr"]) == int(v40["cash_cr"]))

    # A V4 save accidentally settled by the old clock should be recoverable.
    var closed: Dictionary = state.to_dict()
    closed["season_ended"] = true
    var recovered: GameState = State.new("A")
    assert(bool(recovered.load_dict(closed).get("ok", false)))
    assert(not recovered.season_ended)

    # A genuine legacy save should still respect its season duration.
    var legacy: GameState = State.new("A")
    legacy.current_tick = int(legacy.balance["season_ticks"]) + 1
    var legacy_check: GameState = State.new("A")
    assert(not bool(legacy_check.load_dict(legacy.to_dict()).get("ok", false)))
    Save.folder = previous_folder
    print("PASS: V4 time isolation / ledger mirror / long-run save / classic save cap")
    quit(0)
