extends SceneTree
## Run: godot --headless --path star_miner_v0.1_m0_m2 -s res://tests/test_v40_corporate_renderer.gd
## Focus: standalone corporate renderer builds its view using original V4 data
## and wires controls without mutating the economic model.

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
    var state: GameState = State.new("A")
    shell.state = state
    var v40: Dictionary = V40.ensure_v40_state(state)
    var cash_before: int = int(v40["cash_cr"])
    var fin: Dictionary = V40.financial_summary(v40)
    Renderer.render(shell, v40, fin)
    var first_count: int = shell.v40_corp_box.get_child_count()
    assert(first_count >= 5, "Corporate view should contain financial/research/contract sections")
    assert(int(v40["cash_cr"]) == cash_before, "Rendering must not spend money")
    Renderer.render(shell, v40, fin)
    assert(shell.v40_corp_box.get_child_count() == first_count, "A second render must not accumulate panels")
    assert(int(v40["cash_cr"]) == cash_before)
    print("PASS: V4 corporate renderer remains functional outside main_screen")
    quit(0)
