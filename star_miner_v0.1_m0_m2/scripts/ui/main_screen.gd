extends Control

const State = preload("res://scripts/state/game_state.gd")
const Rules = preload("res://scripts/core/mission_rules.gd")
const Sim = preload("res://scripts/core/simulation.gd")
const Save = preload("res://scripts/services/save_service.gd")
const Synth = preload("res://scripts/services/audio_synth.gd")
const StarMap = preload("res://scripts/ui/star_map.gd")
const Chart = preload("res://scripts/ui/cashflow_chart.gd")
const Perks = preload("res://scripts/core/contractor_perks.gd")
const Tycoon = preload("res://scripts/core/galactic_tycoon.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const CONCEPT_BG = preload("res://assets/concept/lunar_base_reference.png")
const BoardLayout = preload("res://scripts/ui/board_layout.gd")
const CorporateRenderer = preload("res://scripts/ui/v40_corporate_renderer.gd")
const VisualTheme = preload("res://scripts/ui/visual/visual_theme.gd")
const CyberFXDirector = preload("res://scripts/ui/visual/cyber_fx_director.gd")
const LaunchCinematic = preload("res://scripts/ui/visual/launch_cinematic.gd")

var board_title: Label
var board_stock: ProgressBar
var board_inventory: Label
var board_window: Window
var board_tabs: TabContainer
var cross_section_view: Control
var v40_mining_inspector: Control
var v40_mining_feedback: Label
var v40_mining_confirm_dialog: ConfirmationDialog
var v40_selected_deposit_idx: int = -1
var v40_selected_mine_id: String = ""
var v40_selection_state: GameState
var v40_pending_mining_action: Dictionary = {}
var advanced_star_ops_box: Control
var complexity_toggle_btn: Button
var once_dispatch_btn: Button
var smart_dispatch_btn: Button
var hold_policy_btn: Button
var left_dump_btn: Button
var right_dump_btn: Button
var auction_hall_modal: Control
var v10_tab_mining_btn: Button
var v10_tab_map_btn: Button
var v10_tab_launch_btn: Button
var v10_main_stage: Control
var v10_mining_stage: Control
var v10_zone_selector_box: BoxContainer
var v10_shallow_drill_btn: Button
var v10_full_launch_view: Control
var v10_mini_launch_view: Control
var v10_rockets_box: VBoxContainer
var v10_market_status_label: Label
var v10_expand_warehouse_btn: Button
var v10_active_screen: String = "mining"
var v40_map_wrap: Control
var v40_galaxy_map_view: Control
var v40_cluster_cards_box: HBoxContainer
var v40_corp_box: VBoxContainer
var v40_market_buttons_box: VBoxContainer
var v40_bottom_telemetry_label: Label
var v40_tab_astra_btn: Button
var v40_astra_hud_view: Control
var visual_director: CanvasLayer
var launch_cinematic: Control
var _resume_speed_after_launch: int = 0
var nav_buttons: Dictionary = {}
var dev_full_access: bool = true

const INK := Color("e5edf1")
const MUTED := Color("91a5b4")
const GOLD := Color("f2b55c")
const GREEN := Color("83c7a6")
const RED := Color("f08c82")
const CYAN := Color("49d6e4")
const PANEL := Color("142333")
const EDGE := Color("304659")

var state: GameState
var selected_star_id: String = "near_metal"
var speed: int = 0
var resume_speed: int = 0
var editing: bool = false
var accumulated: float = 0.0
var refreshing: bool = false
# Only update settings when V4's compatibility popup opens or a slot changes.
var _v40_settings_refresh_pending: bool = true
# Section-level invalidation now lives in CorporateRenderer.
var test_mode: bool = false
var save_blocked: bool = false
var pending_scenario_id: String = "A"
var selected_perk_id: String = "standard"
var status_text: String = "准备就绪：先选择矿区，配置第一趟任务。"
var sounds: Dictionary = {}
var audio_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer

var day_label: Label
var cash_label: Label
var debt_label: Label
var port_label: Label
var status_label: Label
var tutorial_label: Label
var tutorial_button: Button
var tutorial_bar: Control
var recent_notices: Array[String] = []
var cash_flash_until: int = 0
var map_label: Label
var objective_label: Label
var front_menu: Control
var pending_challenge: String = ""
var campaign: Campaign
var session_has_run: bool = false
var objective_announced: bool = false
var speed_label: Label
var star_list: VBoxContainer
var star_map
var star_details: Label
var scan_button: Button
var discover_star_button: Button
var deep_drill_button: Button
var pipe_upgrade_button: Button
var mode_options: OptionButton
var mission_target_label: Label
var miner_check: CheckBox
var silo_check: CheckBox
var cargo_spin: SpinBox
var quote_label: Label
var mass_gauge: ProgressBar
var mass_gauge_label: Label
var slot_gauge: ProgressBar
var slot_gauge_label: Label
var launch_button: Button
var cancel_button: Button
var market_box: VBoxContainer
var fleet_box: HBoxContainer
var log_label: Label
var log_toggle: Button
var log_expanded: bool = false
var mission_panel: Control
var market_panel: Control
var right_scroll: ScrollContainer
var scenario_options: OptionButton
var auto_pause_check: CheckButton
var sound_check: CheckButton
var tech_box: VBoxContainer
var achievements_box: VBoxContainer
var settings_box: VBoxContainer
var finish_dialog: ConfirmationDialog
var new_dialog: ConfirmationDialog
var result_dialog: AcceptDialog


func _ready() -> void:
	test_mode = "--ui-test" in OS.get_cmdline_user_args()
	if test_mode:
		Save.folder = "user://ui_smoke/"
		Campaign.file_path = "user://ui_smoke/campaign.json"
	else:
		SettingsService.load_settings()
		SteamService.init_steam()
		I18nService.init_i18n()
	state = State.new("A")
	var saved_game: Dictionary = {}
	if not test_mode and Save.has_save():
		saved_game = Save.load_game()
		if not saved_game.get("ok", false):
			Save.quarantine()
			status_text = str(saved_game.get("error", "旧存档读不了。")) + " 原文件已复制为 season_save.quarantine.json，没有被盖掉。"
	if test_mode:
		state.sound_enabled = false
	selected_star_id = str(state.stars.keys()[0])
	pending_scenario_id = state.scenario_id
	campaign = Campaign.load()
	_install_theme()
	_build_ui()
	BoardLayout.mount(self)
	_install_cyber_visuals()
	_prepare_audio()
	_suggest_miner()
	_refresh_all()
	_ensure_launchable()
	if not test_mode:
		_show_front_menu(saved_game)
	elif state.season_ended:
		call_deferred("_show_settlement")


func _install_cyber_visuals() -> void:
	visual_director = CyberFXDirector.new()
	add_child(visual_director)
	var cinema_layer := CanvasLayer.new()
	cinema_layer.layer = 90
	add_child(cinema_layer)
	launch_cinematic = LaunchCinematic.new()
	cinema_layer.add_child(launch_cinematic)
	launch_cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	launch_cinematic.cinematic_finished.connect(_on_launch_cinematic_finished)


func _play_dispatch_cinematic() -> void:
	if test_mode or not is_instance_valid(launch_cinematic):
		return
	if visual_director != null and bool(visual_director.get("reduce_motion")):
		return
	var v40: Dictionary = state.stats.get("v40", {})
	var mid: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40.get("mines", {}).get(mid, {})
	_resume_speed_after_launch = speed
	speed = 0
	launch_cinematic.call("play_launch", str(mine.get("name_zh", "星际矿业基地")))


func _on_launch_cinematic_finished() -> void:
	if state != null and not editing and _resume_speed_after_launch > 0:
		speed = _resume_speed_after_launch
	_resume_speed_after_launch = 0


func _toggle_visual_motion() -> void:
	if not is_instance_valid(visual_director):
		return
	var reduced: bool = not bool(visual_director.get("reduce_motion"))
	visual_director.call("set_reduced_motion", reduced)
	if is_instance_valid(cross_section_view):
		cross_section_view.call("set_visual_reduced_motion", reduced)
	if is_instance_valid(v40_galaxy_map_view):
		v40_galaxy_map_view.set("reduce_motion", reduced)
	if is_instance_valid(launch_cinematic) and bool(launch_cinematic.get("_running")) and reduced:
		launch_cinematic.call("finish")
	status_text = "已降低视觉动效（F8 再次切换）" if reduced else "已启用完整视觉特效（F8 切换）"
	visual_director.call("notify_operation", status_text, true, "MotionPreference")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if front_menu != null and front_menu.visible:
		return
	match event.keycode:
		KEY_F8:
			_toggle_visual_motion()
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			if board_window != null and board_window.visible:
				return
			_set_speed(1 if speed == 0 else 0)
			get_viewport().set_input_as_handled()
		KEY_1:
			_set_speed(1)
			get_viewport().set_input_as_handled()
		KEY_2:
			_set_speed(2)
			get_viewport().set_input_as_handled()
		KEY_3:
			_set_speed(4)
			get_viewport().set_input_as_handled()
		KEY_4, KEY_F:
			_switch_v10_screen("astra_hud" if v10_active_screen != "astra_hud" else "mining")
			get_viewport().set_input_as_handled()
		KEY_R:
			_v40_cmd("ToggleBoreRouteMode", {})
			get_viewport().set_input_as_handled()
		KEY_TAB:
			var order_scr: Array = ["mining", "starmap", "corp", "astra_hud"]
			var cur_i: int = maxi(0, order_scr.find(v10_active_screen))
			_switch_v10_screen(str(order_scr[(cur_i + 1) % order_scr.size()]))
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if board_window != null and board_window.visible:
				_close_board_panel()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if speed <= 0 or editing or state.season_ended:
		return
	accumulated += delta * float(speed)
	while accumulated >= float(state.balance["seconds_per_tick"]) and speed > 0 and not state.season_ended:
		accumulated -= float(state.balance["seconds_per_tick"])
		_advance()
	if is_instance_valid(star_map):
		star_map.tick_fraction = accumulated / float(state.balance["seconds_per_tick"])
		if state.challenge_id != "" and star_map.visible:
			star_map.queue_redraw()


func _install_theme() -> void:
	var chosen_font := SystemFont.new()
	chosen_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "WenQuanYi Micro Hei", "Noto Sans CJK SC", "Droid Sans Fallback", "Arial"])
	var app_theme := Theme.new()
	app_theme.default_font = chosen_font
	app_theme.default_font_size = 15
	for control in ["Button", "OptionButton", "CheckBox", "CheckButton", "Label", "SpinBox"]:
		app_theme.set_color("font_color", control, INK)
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_color("font_disabled_color", "Button", Color("70808a"))
	app_theme.set_stylebox("normal", "Button", _style(Color("24394a"), EDGE, 5))
	app_theme.set_stylebox("hover", "Button", _style(Color("355064"), Color("6a889d"), 5))
	app_theme.set_stylebox("pressed", "Button", _style(Color("475341"), GOLD, 5))
	app_theme.set_stylebox("disabled", "Button", _style(Color("1a2832"), Color("30404b"), 5))
	app_theme.set_stylebox("normal", "OptionButton", _style(Color("24394a"), EDGE, 5))
	app_theme.set_stylebox("hover", "OptionButton", _style(Color("355064"), Color("6a889d"), 5))
	app_theme.set_stylebox("pressed", "OptionButton", _style(Color("3a4b4e"), GOLD, 5))
	app_theme.set_stylebox("panel", "TabContainer", _style(Color("0d1b27"), Color("3c6278"), 6, 16))
	app_theme.set_stylebox("tab_selected", "TabContainer", _style(Color("1c3548"), GOLD, 5, 12))
	app_theme.set_stylebox("tab_hovered", "TabContainer", _style(Color("243f54"), Color("52b6c5"), 5, 12))
	app_theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("101e2b"), EDGE, 5, 10))
	app_theme.set_color("font_selected_color", "TabContainer", GOLD)
	app_theme.set_color("font_unselected_color", "TabContainer", MUTED)
	app_theme.set_stylebox("panel", "AcceptDialog", _style(Color("0e1d2a"), GOLD, 8, 16))
	app_theme.set_stylebox("panel", "ConfirmationDialog", _style(Color("0e1d2a"), Color("52b6c5"), 8, 16))
	app_theme.set_stylebox("panel", "Window", _style(Color("0c1824"), Color("49d6e4"), 6, 12))
	app_theme.set_stylebox("panel", "PopupMenu", _style(Color("0f202e"), Color("49d6e4"), 5, 8))
	app_theme.set_stylebox("hover", "PopupMenu", _style(Color("234056"), GOLD, 4, 6))
	app_theme.set_color("font_color", "PopupMenu", INK)
	app_theme.set_stylebox("normal", "LineEdit", _style(Color("0c1824"), EDGE, 4, 6))
	app_theme.set_stylebox("focus", "LineEdit", _style(Color("132638"), GOLD, 4, 6))
	app_theme.set_stylebox("background", "ProgressBar", _style(Color("09131d"), EDGE, 3, 0))
	app_theme.set_stylebox("fill", "ProgressBar", _style(Color("49d6e4"), Color("49d6e4"), 3, 0))
	VisualTheme.polish(app_theme)
	theme = app_theme


func _style(fill: Color, border: Color, radius: int = 6, margin: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_top = 2
	box.set_corner_radius_all(mini(radius, 3))
	box.shadow_color = Color(border.r, border.g, border.b, 0.12)
	box.shadow_size = 3
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


func _label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _paragraph(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var label: Label = _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(text: String, callback: Callable, minimum_height: int = 34) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = minimum_height
	button.pressed.connect(callback)
	return button


func _section(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, EDGE, 8, 12))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)
	body.add_child(_label(title, 16, GOLD))
	return {"panel": panel, "body": body}


func _scrolling_column(width: int) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return {"scroll": scroll, "body": body}


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _style(Color("0a1520"), Color("0a1520"), 0, 14))
	add_child(background)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	background.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	root.add_child(header)
	var title: Label = _label("星矿大亨", 26, GOLD)
	title.custom_minimum_size.x = 158
	header.add_child(title)
	day_label = _label("", 17)
	map_label = _label("现在：A · 稳定矿区", 15, GOLD)
	cash_label = _label("", 17, GREEN)
	debt_label = _label("", 15, MUTED)
	port_label = _label("", 15, MUTED)
	objective_label = _label("", 14, Color("f0d48a"))
	for item in [map_label, day_label, cash_label, debt_label, port_label]:
		header.add_child(item)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	auto_pause_check = CheckButton.new()
	auto_pause_check.text = "事件暂停"
	auto_pause_check.button_pressed = state.auto_pause
	auto_pause_check.toggled.connect(_on_auto_pause)
	header.add_child(auto_pause_check)
	sound_check = CheckButton.new()
	sound_check.text = "音效与音乐"
	sound_check.button_pressed = state.sound_enabled
	sound_check.toggled.connect(_on_sound)
	header.add_child(sound_check)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 7)
	root.add_child(controls)
	scenario_options = OptionButton.new()
	scenario_options.custom_minimum_size.x = 180
	for item in [
		["A · 稳定矿区", "A"],
		["B · 抢运窗口", "B"],
		["C · 未知矿区 ①", "C2"],
		["C · 未知矿区 ②", "C20"],
		["G · 高重力", "G"],
		["S · 随机深空矿区", "S"],
		["X · 庞大星系霸权", "X"],
		["E · 无尽开拓矿区", "E"],
		["D · 多星矿区", "D"]
	]:
		scenario_options.add_item(item[0])
		scenario_options.set_item_metadata(scenario_options.item_count - 1, item[1])
	scenario_options.item_selected.connect(_scenario_selected)
	controls.add_child(scenario_options)
	controls.add_child(_button("新开采季", _ask_new_season))
	controls.add_child(_button("读取存档", _load_saved))
	controls.add_child(_button("最近结算", _show_recent_settlement))
	var control_spacer := Control.new()
	control_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(control_spacer)
	speed_label = _label("已暂停", 14, MUTED)
	controls.add_child(speed_label)
	controls.add_child(_button("暂停", _set_speed.bind(0)))
	controls.add_child(_button("1×", _set_speed.bind(1)))
	controls.add_child(_button("2×", _set_speed.bind(2)))
	var step_button: Button = _button("推进半日", _advance_one)
	step_button.tooltip_text = "暂停时精确推进半个游戏日。"
	controls.add_child(step_button)
	controls.add_child(_button("提前结算", _ask_finish))

	var tutor_panel := PanelContainer.new()
	tutor_panel.add_theme_stylebox_override("panel", _style(Color("23382f"), Color("426651"), 6, 7))
	root.add_child(tutor_panel)
	var tutor_row := HBoxContainer.new()
	tutor_panel.add_child(tutor_row)
	tutorial_label = _paragraph("", 14, Color("c6e8d1"))
	tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutor_row.add_child(tutorial_label)
	tutor_row.add_child(objective_label)
	complexity_toggle_btn = _button("🔓 全功能已开放 (点击切换新手渐进模式)", _toggle_ui_complexity_mode, 28)
	tutor_row.add_child(complexity_toggle_btn)
	tutorial_button = _button("跳过提示", _dismiss_tutorial, 28)
	tutor_row.add_child(tutorial_button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var left: Dictionary = _scrolling_column(265)
	var center: Dictionary = _scrolling_column(460)
	var right: Dictionary = _scrolling_column(425)
	right_scroll = right["scroll"]
	center["scroll"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center["body"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	for column in [left, center, right]:
		columns.add_child(column["scroll"])

	var stars_section: Dictionary = _section("01  /  星域与矿区")
	left["body"].add_child(stars_section["panel"])
	star_list = VBoxContainer.new()
	star_list.add_theme_constant_override("separation", 7)
	stars_section["body"].add_child(star_list)
	star_details = _label("", 14, MUTED)
	stars_section["body"].add_child(star_details)
	pipe_upgrade_button = _button("星轨弹射导轨 Lv.2 · $90", _upgrade_pipe, 36)
	stars_section["body"].add_child(pipe_upgrade_button)
	deep_drill_button = _button("凿穿深岩核 · $120", _upgrade_deep_drill, 36)
	stars_section["body"].add_child(deep_drill_button)
	scan_button = _button("🛰 发射探矿卫星 · $60", _scan, 36)
	stars_section["body"].add_child(scan_button)
	discover_star_button = _button("🔭 搜寻新矿星 · $100", _discover_star, 36)
	stars_section["body"].add_child(discover_star_button)

	var map_section: Dictionary = _section("02  /  太空航道")
	map_section["panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	center["body"].add_child(map_section["panel"])
	star_map = StarMap.new()
	star_map.custom_minimum_size = Vector2(420, 390)
	star_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	star_map.star_selected.connect(_select_star)
	star_map.facility_selected.connect(_on_facility_selected)
	map_section["body"].add_child(star_map)
	left["body"].add_child(_paragraph("采矿与运输分开进行。仓满时矿机会暂停，腾出空间后继续。", 13, MUTED))

	var mission_section: Dictionary = _section("03  /  配置星舰与火箭任务")
	mission_panel = mission_section["panel"]
	right["body"].add_child(mission_section["panel"])
	mission_target_label = _label("", 16, GREEN)
	mission_section["body"].add_child(mission_target_label)
	mission_section["body"].add_child(_label("火箭/星舰船型与回收方式", 14, MUTED))
	mode_options = OptionButton.new()
	mode_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_options.custom_minimum_size.y = 36
	mode_options.item_selected.connect(_on_config_select)
	mission_section["body"].add_child(mode_options)
	var module_row := HBoxContainer.new()
	mission_section["body"].add_child(module_row)
	miner_check = CheckBox.new()
	miner_check.text = "基础矿机  $140"
	miner_check.toggled.connect(_on_config_toggle)
	module_row.add_child(miner_check)
	silo_check = CheckBox.new()
	silo_check.text = "扩展仓  $60"
	silo_check.toggled.connect(_on_config_toggle)
	module_row.add_child(silo_check)
	var cargo_row := HBoxContainer.new()
	mission_section["body"].add_child(cargo_row)
	cargo_row.add_child(_label("计划返程箱数", 14, MUTED))
	var cargo_spacer := Control.new()
	cargo_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_row.add_child(cargo_spacer)
	cargo_spin = SpinBox.new()
	cargo_spin.min_value = 0
	cargo_spin.max_value = 8
	cargo_spin.step = 1
	cargo_spin.value = 4
	cargo_spin.custom_minimum_size.x = 95
	cargo_spin.value_changed.connect(_on_cargo_changed)
	cargo_row.add_child(cargo_spin)
	mission_section["body"].add_child(_button("寻找可行火箭", _find_feasible_rocket, 34))
	var gauges_box := VBoxContainer.new()
	gauges_box.add_theme_constant_override("separation", 4)
	mission_section["body"].add_child(gauges_box)
	mass_gauge_label = _label("起飞总重负荷", 12, MUTED)
	gauges_box.add_child(mass_gauge_label)
	mass_gauge = ProgressBar.new()
	mass_gauge.custom_minimum_size.y = 10
	mass_gauge.show_percentage = false
	gauges_box.add_child(mass_gauge)
	slot_gauge_label = _label("货舱格数占用", 12, MUTED)
	gauges_box.add_child(slot_gauge_label)
	slot_gauge = ProgressBar.new()
	slot_gauge.custom_minimum_size.y = 10
	slot_gauge.show_percentage = false
	gauges_box.add_child(slot_gauge)
	var quote_panel := PanelContainer.new()
	quote_panel.add_theme_stylebox_override("panel", _style(Color("0c1a27"), Color("294154"), 5, 10))
	mission_section["body"].add_child(quote_panel)
	quote_label = _paragraph("", 14)
	quote_panel.add_child(quote_label)
	var launch_row := HBoxContainer.new()
	mission_section["body"].add_child(launch_row)
	launch_button = _button("点火发射", _launch, 42)
	launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_button.add_theme_stylebox_override("normal", _style(Color("735328"), GOLD, 5))
	launch_row.add_child(launch_button)
	cancel_button = _button("结束配装", _end_editing, 42)
	launch_row.add_child(cancel_button)
	right["body"].add_child(_button("查看订单与贷款  ↓", _jump_market, 30))
	status_label = _paragraph("", 13, MUTED)
	right["body"].add_child(status_label)
	right["body"].add_child(_paragraph("运输计划不会预占未来矿产或订单额度。其他火箭可能先一步取货。", 13, MUTED))

	var market_section: Dictionary = _section("04  /  市场与资金")
	market_panel = market_section["panel"]
	right["body"].add_child(market_section["panel"])
	market_box = VBoxContainer.new()
	market_box.add_theme_constant_override("separation", 7)
	market_section["body"].add_child(market_box)
	var bank_row := HBoxContainer.new()
	market_section["body"].add_child(bank_row)
	bank_row.add_child(_button("借 $100", _borrow))
	bank_row.add_child(_button("还 $100 + 利息", _repay))
	market_section["body"].add_child(_button("返回火箭配置  ↑", _jump_mission, 30))
	right["body"].add_child(_paragraph("订单先于常驻商成交。选择留货时，母港仓满会阻止船只卸货。", 13, MUTED))

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 10)
	lower.custom_minimum_size.y = 155
	root.add_child(lower)
	var fleet_section: Dictionary = _section("05  /  船队动态")
	fleet_section["panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(fleet_section["panel"])
	fleet_box = HBoxContainer.new()
	fleet_box.add_theme_constant_override("separation", 8)
	fleet_section["body"].add_child(fleet_box)
	var log_section: Dictionary = _section("运行记录")
	log_section["panel"].custom_minimum_size.x = 340
	lower.add_child(log_section["panel"])
	log_label = _paragraph("", 12, MUTED)
	log_label.custom_minimum_size.x = 300
	log_section["body"].add_child(log_label)
	log_toggle = _button("展开记录", _toggle_log, 30)
	log_section["body"].add_child(log_toggle)

	tech_box = VBoxContainer.new()
	tech_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_box.add_theme_constant_override("separation", 10)
	root.add_child(tech_box)

	achievements_box = VBoxContainer.new()
	achievements_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_box.add_theme_constant_override("separation", 10)
	root.add_child(achievements_box)

	settings_box = VBoxContainer.new()
	settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_box.add_theme_constant_override("separation", 10)
	root.add_child(settings_box)

	finish_dialog = ConfirmationDialog.new()
	finish_dialog.title = "提前结算"
	finish_dialog.confirmed.connect(_confirm_finish)
	add_child(finish_dialog)
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = "开始新开采季"
	new_dialog.dialog_text = "当前开采季会被新局替换。确定开始所选地图吗？"
	new_dialog.confirmed.connect(_new_season)
	add_child(new_dialog)
	result_dialog = AcceptDialog.new()
	result_dialog.title = "开采季结算"
	result_dialog.min_size = Vector2i(640, 520)
	add_child(result_dialog)


func _prepare_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -14.0
	add_child(audio_player)
	sounds = Synth.build_sound_bank()

	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -21.0
	bgm_player.stream = Synth.build_ambient_drone()
	add_child(bgm_player)
	if not test_mode and state.sound_enabled:
		bgm_player.play()


func _cue(name: String) -> void:
	if state.sound_enabled and sounds.has(name):
		audio_player.stream = sounds[name]
		audio_player.play()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_all() -> void:
	refreshing = true
	# The legacy tabs remain in the tree for classic challenges and compatibility,
	# but must be disabled in V4: otherwise users can still open the old checkout
	# from the TabContainer itself and mutate a second economic ledger.
	if is_instance_valid(board_tabs):
		var v40_mode: bool = state.challenge_id == ""
		if v40_mode and board_tabs.current_tab != 3:
			board_tabs.current_tab = 3
		for legacy_index in [0, 1, 2, 4, 5]:
			board_tabs.set_tab_disabled(legacy_index, v40_mode)
	star_map.state = state
	star_map.selected_star_id = selected_star_id
	star_map.tick_fraction = accumulated / float(state.balance["seconds_per_tick"])
	if state.challenge_id != "" and star_map.visible:
		star_map.queue_redraw()
	if is_instance_valid(cross_section_view):
		cross_section_view.set("state", state)
		cross_section_view.set("star_id", selected_star_id)
		cross_section_view.queue_redraw()
	if state.endless_mode:
		day_label.text = "Day %.1f / ∞" % (float(state.current_tick) / 2.0)
	else:
		day_label.text = "Day %.1f / %d" % [float(state.current_tick) / 2.0, int(state.balance["season_ticks"]) / 2]
	if is_instance_valid(map_label):
		map_label.text = "现在：" + _map_title(state.scenario_id)
	if is_instance_valid(objective_label):
		objective_label.text = Campaign.describe(state.challenge_id)
		objective_label.visible = state.challenge_id != ""
	cash_label.text = "现金  " + Rules.money(state.cash_cents)
	debt_label.text = "债务  %s + 利息 %s" % [Rules.money(state.principal_cents), Rules.money(state.accrued_interest_cents)]
	port_label.text = "母港仓  %d / %d" % [state.port_total(), int(state.balance["port_capacity"])]
	var port_full: bool = state.port_total() >= int(state.balance["port_capacity"])
	port_label.add_theme_color_override("font_color", RED if port_full else MUTED)
	var cash_hot: bool = Time.get_ticks_msec() < cash_flash_until
	cash_label.add_theme_color_override("font_color", GOLD if cash_hot else GREEN)
	speed_label.text = "配装中 · 已暂停" if editing else ("已暂停" if speed == 0 else "%d× 运行中" % speed)
	auto_pause_check.set_pressed_no_signal(state.auto_pause)
	sound_check.set_pressed_no_signal(state.sound_enabled)
	for index in range(scenario_options.item_count):
		if str(scenario_options.get_item_metadata(index)) == pending_scenario_id:
			scenario_options.select(index)
			break
	_refresh_tutorial()
	if state.challenge_id != "":
		# Old campaign still needs its legacy economy panels.
		_refresh_stars()
		_refresh_modes()
		_refresh_market()
		_refresh_fleet()
		_refresh_log()
		_refresh_tech()
		_refresh_achievements()
		_refresh_settings()
		_refresh_progressive_visibility()
	elif _v40_settings_refresh_pending and is_instance_valid(board_window) and board_window.visible and board_tabs.current_tab == 3:
		# Settings/save is the only permitted legacy popup in V4.
		_refresh_settings()
		_v40_settings_refresh_pending = false
	if is_instance_valid(board_title) and state.stars.has(selected_star_id):
		var selected: Dictionary = state.stars[selected_star_id]
		var zone_name: String = str(selected.get("zone", "太阳系内环星系"))
		board_title.text = "%s · %s" % [str(selected["name"]), zone_name]
		board_stock.max_value = Sim.star_capacity(state, selected)
		board_stock.value = int(selected["stock"])
		var ore_color: Color = Color("49d6e4") if str(selected["ore"]) == "crystal" else Color("f0a04a")
		board_stock.add_theme_stylebox_override("fill", _style(ore_color, ore_color, 2, 0))
		var ore_label: String = "赤铁钛合金矿" if str(selected["ore"]) == "metal" else "高能暗物质晶簇"
		board_inventory.text = "%s  ·  星仓 %d / %d 箱" % [ore_label, int(selected["stock"]), Sim.star_capacity(state, selected)]
	_refresh_turmoil_quick_bar()
	status_label.text = status_text
	cancel_button.disabled = not editing
	refreshing = false
	if state.challenge_id != "":
		_refresh_quote()


func _refresh_progressive_visibility() -> void:
	if is_instance_valid(complexity_toggle_btn):
		complexity_toggle_btn.text = "🔓 全权限模式 (点击预览新手精简视图)" if dev_full_access else "🌱 新手渐进视图 (点击恢复全权限)"
	var show_advanced: bool = dev_full_access or int(state.stats.get("completed_trips", 0)) >= 1 or state.scenario_id in ["X", "S", "E", "D"]
	if is_instance_valid(advanced_star_ops_box):
		advanced_star_ops_box.visible = show_advanced
	if is_instance_valid(deep_drill_button):
		deep_drill_button.visible = show_advanced
	if is_instance_valid(discover_star_button):
		discover_star_button.visible = show_advanced


func _toggle_ui_complexity_mode() -> void:
	dev_full_access = not dev_full_access
	status_text = "已切换为【开发者全权限模式】：全部高阶功能、深岩钻探与全地图均已直接开放。" if dev_full_access else "已切换为【新手渐进引导视图】：首趟矿石返港前自动收起高阶改造按钮，降低新玩家认知负担。"
	_refresh_all()


func _dev_grant_cash() -> void:
	var bonus: int = 500000
	state.cash_cents += bonus
	state.stats["salvage_revenue"] = int(state.stats.get("salvage_revenue", 0)) + bonus
	state.add_log("【测试特权】已注入 $5,000 专项开拓资金。")
	if is_instance_valid(star_map):
		star_map.spawn_floating_text("trade", "+$5,000 特权金", GOLD)
	_cue("cash")
	_persist()
	_refresh_all()


func _dev_unlock_all_techs() -> void:
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	for tid in TechTree.TECH_ORDER:
		if not TechTree.is_unlocked(unlocked, tid):
			unlocked.append(tid)
	state.stats["unlocked_techs"] = unlocked
	TechTree.apply_tech_effects(state)
	state.add_log("【测试特权】已一键掌握全部 8 项航天科技（含重型全复用不锈钢星舰）！")
	if is_instance_valid(star_map):
		star_map.spawn_floating_text("hangar", "★ 全科技已解锁!", GOLD)
	_cue("tech")
	_persist()
	_refresh_all()


func _dev_reveal_all_stars() -> void:
	for sid in state.stars:
		var s: Dictionary = state.stars[sid]
		s["revealed"] = true
		if not bool(s.get("vein_prospected", false)):
			s["vein_prospected"] = true
			s["reserve"] = int(s["reserve"]) + 8
			s["initial_reserve"] = int(s["initial_reserve"]) + 8
	state.active_scan = {}
	state.add_log("【测试特权】全星系深空地质雷达扫描完成！所有星球储量与富矿夹层已探明！")
	if is_instance_valid(star_map):
		star_map.spawn_floating_text(selected_star_id, "🛰 全星系已探明!", CYAN)
	_cue("scan")
	_persist()
	_refresh_all()


func _on_cross_section_action(action_id: String) -> void:
	if action_id == "v40_launch_pad":
		_v40_request_mining_action("LaunchPadDispatch", {})
		return
	if action_id == "v40_scan":
		_v40_request_mining_action("ScanArea", {})
		return
	if action_id.begins_with("v40_select_deposit:"):
		_v40_select_mining_target(int(action_id.trim_prefix("v40_select_deposit:")))
		return
	if action_id == "v40_route_mode":
		_v40_cmd("ToggleBoreRouteMode", {})
		return
	if action_id == "v40_build_drill":
		_v40_request_mining_action("BuildDrill", {})
		return
	if action_id.begins_with("v40_head:"):
		_v40_select_mining_target(int(action_id.substr(9)))
		return
	if action_id.begins_with("v40_upgrade:"):
		var u_kind: String = action_id.substr(12)
		_v40_request_mining_action("UpgradeFacility", {"kind": u_kind})
		return
	if action_id.begins_with("pocket:"):
		var p_idx: int = int(action_id.substr(7))
		var res_p: Dictionary = Tycoon.drill_vein_pocket(state, selected_star_id, p_idx)
		if res_p.get("ok", false):
			if not bool(res_p.get("aimed_only", false)):
				_cue("tech")
				if is_instance_valid(star_map):
					star_map.spawn_floating_text(selected_star_id, "🎯 定向爆矿+%d箱!" % int(res_p.get("added", 4)), GOLD)
				_push_notice("定向激光击穿%s：储量 +%d 箱%s！" % [str(res_p.get("pocket_name", "矿囊")), int(res_p.get("added", 4)), "，立得 1 箱现矿入仓" if int(res_p.get("instant", 0)) > 0 else ""], "cash")
			else:
				status_text = str(res_p.get("msg", "已调整钻头方向。"))
			_persist()
		else:
			status_text = str(res_p.get("error", "操作失败。"))
		_refresh_all()
		return
	match action_id:
		"scan":
			_scan()
		"deep_drill":
			_upgrade_deep_drill()
		"deploy_miner":
			_smart_dispatch_now()
		"upgrade_rig":
			_upgrade_pipe()
		"expand_silo":
			_board_expand()


func _refresh_tutorial() -> void:
	if state.tutorial_dismissed:
		tutorial_label.text = ""
		tutorial_button.visible = false
		if tutorial_bar != null:
			tutorial_bar.visible = state.challenge_id != "" or not test_mode
		return
	if tutorial_bar != null:
		tutorial_bar.visible = true
	tutorial_button.visible = true
	tutorial_label.text = _coach_line()
	tutorial_button.text = "知道了" if state.tutorial_stage >= 3 else "跳过"


func _coach_line() -> String:
	match state.tutorial_stage:
		0:
			if editing:
				var paid: String = ""
				if mode_options != null and mode_options.item_count > 0:
					var quote: Dictionary = Rules.quote_mission(state, _request())
					if quote.has("total_cents"):
						paid = Rules.money(int(quote["total_cents"]))
				if state.scenario_id == "B":
					return "2/5  本次付 %s。仓里已有货，先抢运。" % paid if paid != "" else "2/5  用轻型箭把仓里的货先抢回来。"
				return "2/5  本次付 %s。先建矿，再运货。" % paid if paid != "" else "2/5  轻型箭加矿机。先建矿，再运货。"
			if state.scenario_id == "B":
				return "1/5  遗留仓已有晶体。点它，用轻型箭先抢回来。"
			if state.scenario_id in ["D", "S", "E", "X"]:
				return "1/5  天上有多颗星。近星便宜，中距更贵。"
			return "1/5  铁砾星：金属，地下 48 箱，每天 2 箱。"
		1:
			return "3/5  矿机留在星上产矿，火箭装满会自己回来。"
		2:
			return "4/5  货款到账。矿机还在工作，下一趟不用重买。"
		_:
			return "5/5  轻型更快。中型复用少买箭体，但回港要翻修。"


func _refresh_stars() -> void:
	_clear(star_list)
	if not state.stars.has(selected_star_id) and not state.stars.is_empty():
		selected_star_id = str(state.stars.keys()[0])
	for star_id in state.stars:
		var star: Dictionary = state.stars[star_id]
		var stock: int = int(star["stock"])
		var cap: int = Sim.star_capacity(state, star)
		var suffix: String = " · 高重力" if star["environment"] == "high_g" else ""
		var label_text: String = "%s%s\n%s · 星仓 %d/%d" % [star["name"], suffix, Sim.ore_name(str(star["ore"])), stock, cap]
		var btn: Button = _button(label_text, _select_star.bind(str(star_id)), 68)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if str(star_id) == selected_star_id:
			btn.add_theme_stylebox_override("normal", _style(Color("294338"), Color("7aaf8b"), 5))
		star_list.add_child(btn)
	var star: Dictionary = state.stars[selected_star_id]
	var known: Dictionary = state.public_reserve(star)
	var reserve_text: String = "%d 箱" % int(known["min"]) if bool(known["exact"]) else "%d–%d 箱" % [int(known["min"]), int(known["max"])]
	var r_key: String = str(star["route"])
	var route_text: String = "太阳系内环(近轨)" if r_key == "near" else ("天鹅座星云(远距)" if r_key == "far" else "半人马双星系(中距)")
	var prod_ticks: int = int(state.balance["production_ticks"][star["ore"]])
	var rate: String = "2箱/日" if prod_ticks == 1 else "1箱/日"
	var miner_status: String = "运行中" if bool(star["has_miner"]) else "未部署"
	if bool(star["has_miner"]) and int(star["stock"]) >= Sim.star_capacity(state, star) and (not bool(known["exact"]) or int(known["max"]) > 0):
		miner_status = "仓满停工"
	var p_lvl: int = int(star.get("pipe_level", 1))
	var deep_info: String = "✓已并入主矿脉" if bool(star.get("deep_unlocked", false)) else ("未凿通 (+%d箱)" % int(star.get("deep_reserve", 24)))
	star_details.text = "%s  /  %s\n表层储量：%s  ·  深层岩芯：%s\n地表钻机：%s (%s)  ·  弹射轨：Lv.%d/3" % [route_text, "高重力" if star["environment"] == "high_g" else "标准重力", reserve_text, deep_info, miner_status, rate, p_lvl]
	var collection_status: String = ""
	for ship in state.ships:
		if str(ship.get("star_id", "")) != selected_star_id:
			continue
		if str(ship.get("state", "")) == "outbound":
			collection_status = "火箭 #%d 正在前往，Day %.1f 抵达" % [int(ship["id"]), float(int(ship["event_tick"])) / 2.0]
			break
		if str(ship.get("state", "")) == "waiting":
			collection_status = "火箭 #%d 等待装货，计划 %d 箱" % [int(ship["id"]), int(ship["planned_cargo"])]
			break
	if not collection_status.is_empty():
		star_details.text += "\n" + collection_status
	elif int(star["stock"]) > 0:
		star_details.text += "\n星仓有矿，派遣星舰/火箭即可运回地球基地变现。"

	var scanning: bool = not state.active_scan.is_empty()
	var vein_done: bool = bool(star.get("vein_prospected", false))
	var scan_cost: String = Rules.money(int(state.balance["scan_price"]))
	if not bool(known["exact"]):
		scan_button.disabled = scanning or state.season_ended
		scan_button.text = "🛰 卫星扫描中..." if scanning else ("🛰 探明矿脉 · %s" % scan_cost)
	else:
		scan_button.disabled = vein_done or scanning or state.season_ended
		scan_button.text = "✓ 富矿脉已探明" if vein_done else ("🛰 深度探矿 · %s" % scan_cost)

	if is_instance_valid(discover_star_button):
		var max_stars_reached: bool = state.stars.size() >= 9
		discover_star_button.disabled = max_stars_reached or state.season_ended
		discover_star_button.text = "✓ 星域已全探明" if max_stars_reached else "🔭 搜寻新星 · $100"

	if is_instance_valid(deep_drill_button):
		var deep_done: bool = bool(star.get("deep_unlocked", false))
		var d_amt: int = int(star.get("deep_reserve", 24))
		deep_drill_button.disabled = deep_done or not bool(star.get("has_miner", false)) or state.season_ended
		deep_drill_button.text = "✓ 深层地核已凿通" if deep_done else ("🔥 凿穿深岩核 (+%d箱) · $120" % d_amt if bool(star.get("has_miner", false)) else "🔒 凿穿深岩核 (需先部署矿机)")
	if is_instance_valid(pipe_upgrade_button):
		var cur_p: int = int(star.get("pipe_level", 1))
		var p_cost: String = "$90" if cur_p == 1 else "$150"
		pipe_upgrade_button.disabled = cur_p >= 3 or state.season_ended
		pipe_upgrade_button.text = "✓ 弹射轨 Lv.3" if cur_p >= 3 else ("⚡ 弹射轨 Lv.%d · %s" % [cur_p + 1, p_cost])


func _refresh_modes() -> void:
	var selected_data: Variant = mode_options.get_selected_metadata() if mode_options.item_count > 0 and mode_options.selected >= 0 else null
	mode_options.clear()
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var has_heavy: bool = TechTree.is_unlocked(unlocked, "starship_heavy")
	cargo_spin.max_value = 10 if has_heavy else 8
	var base_modes: Array = [
		["猎鹰轻型运载火箭 (一次性)  ·  4 格", "light", 0],
		["猎鹰重型运载火箭 (一次性)  ·  8 格", "medium_once", 0],
		["新购猎鹰9号可回收复用箭  ·  6 格", "medium_reuse", 0]
	]
	if has_heavy:
		base_modes.append(["★ 新购304L不锈钢全复用星舰 (Starship)  ·  10 格", "heavy_reuse", 0])
	for item in base_modes:
		mode_options.add_item(str(item[0]))
		mode_options.set_item_metadata(mode_options.item_count - 1, {"mode": str(item[1]), "owned_ship_id": int(item[2])})
	for ship in state.ships:
		if Rules.is_reusable_mode(str(ship["mode"])) and str(ship["state"]) == "idle":
			var slots_txt: String = "10 格" if str(ship["mode"]) == "heavy_reuse" else "6 格"
			mode_options.add_item("派遣待命%s #%d  ·  %s" % [Sim.mode_name(str(ship["mode"])), int(ship["id"]), slots_txt])
			mode_options.set_item_metadata(mode_options.item_count - 1, {"mode": str(ship["mode"]), "owned_ship_id": int(ship["id"])})
	var found: bool = false
	for index in range(mode_options.item_count):
		if selected_data != null and mode_options.get_item_metadata(index) == selected_data:
			mode_options.select(index)
			found = true
			break
	if not found:
		mode_options.select(0)


func _refresh_market() -> void:
	_clear(market_box)
	market_box.add_child(Chart.new(state.cash_history, int(state.balance["starting_cash"])))
	var m_price: String = Rules.money(Rules.current_ore_price(state, "metal"))
	var c_price: String = Rules.money(Rules.current_ore_price(state, "crystal"))
	market_box.add_child(_label("当前地球市场最优收购报价：  金属 %s / 箱     晶簇 %s / 箱" % [m_price, c_price], 15, GREEN))

	if state.stats.has("tycoon"):
		var tycoon: Dictionary = state.stats["tycoon"]
		var lb: Dictionary = tycoon["left_buyer"]
		var rb: Dictionary = tycoon["right_buyer"]
		var l_arrow: String = "▲" if int(lb.get("trend", 1)) >= 0 else "▼"
		var r_arrow: String = "▲" if int(rb.get("trend", 1)) >= 0 else "▼"

		var dual_panel: PanelContainer = PanelContainer.new()
		dual_panel.add_theme_stylebox_override("panel", _style(Color("0e1e2c"), Color("3d6a7a"), 6, 10))
		market_box.add_child(dual_panel)
		var dual_box: VBoxContainer = VBoxContainer.new()
		dual_box.add_theme_constant_override("separation", 6)
		dual_panel.add_child(dual_box)
		dual_box.add_child(_label("📈 地球双采购商动态报价（受市场周期、供需变化与竞争对手抛售影响）", 14, GOLD))
		dual_box.add_child(_label("• 采购商 A [西盟航天重工] %s   金属 %s/箱   |   晶簇 %s/箱" % [l_arrow, Rules.money(int(lb["metal_price"])), Rules.money(int(lb["crystal_price"]))], 13, INK))
		dual_box.add_child(_label("• 采购商 B [东联星际矿业] %s   金属 %s/箱   |   晶簇 %s/箱" % [r_arrow, Rules.money(int(rb["metal_price"])), Rules.money(int(rb["crystal_price"]))], 13, INK))
		dual_box.add_child(_label("📡 市场供需动态：" + str(tycoon.get("rival_activity", "两家采购商正在根据矿石到港量调整报价")), 12, CYAN))

		# 三家 AI 矿业财团竞争态势 (V1.0 第五节)
		var ledgers: Dictionary = Tycoon.ensure_rival_ledgers(state)
		var rival_panel: PanelContainer = PanelContainer.new()
		rival_panel.add_theme_stylebox_override("panel", _style(Color("111c28"), GOLD, 6, 10))
		market_box.add_child(rival_panel)
		var rival_box: VBoxContainer = VBoxContainer.new()
		rival_box.add_theme_constant_override("separation", 5)
		rival_panel.add_child(rival_box)
		rival_box.add_child(_label("🏢 行业竞争对手实时动态（受同等资金、仓储与运力约束）", 14, GOLD))
		for r_id in ["rex", "victoria", "otto"]:
			var rd: Dictionary = ledgers[r_id]
			rival_box.add_child(_label("• %s（%s） — 预计净利润: %s | 囤矿: %d箱" % [
				str(rd["name"]), str(rd["strategy"]), Rules.money(int(rd["net_profit_cents"])), int(rd["ore_stock"])
			], 12, INK))

	market_box.add_child(_label("地球仓库库存与销售策略（立即出售 vs 暂时囤货等待高价）", 14, GOLD))
	for ore in ["metal", "crystal"]:
		var planet_stock: int = 0
		var in_transit: int = 0
		for star in state.stars.values():
			if str(star["ore"]) == ore:
				planet_stock += int(star["stock"])
		for ship in state.ships:
			var star: Dictionary = state.stars[ship["star_id"]]
			if str(star["ore"]) == ore and str(ship["state"]) == "inbound":
				in_transit += int(ship["cargo"])
		var row: HBoxContainer = HBoxContainer.new()
		market_box.add_child(row)
		var current: String = "到港立即出售" if state.sale_policies[ore] == "immediate" else "暂时囤货(承担仓储费)"
		var text: String = "%s  地球仓库 %d 箱  (矿区待运 %d · 在途 %d 箱)  ·  策略：%s" % [
			Sim.ore_name(ore), int(state.port_storage[ore]), planet_stock, in_transit, current
		]
		var label: Label = _label(text, 13, MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var sell_button: Button = _button("立即出售库存", _sell_port_stock.bind(ore), 28)
		sell_button.disabled = state.season_ended or int(state.port_storage[ore]) == 0
		row.add_child(sell_button)
		var next_policy: String = "hold" if state.sale_policies[ore] == "immediate" else "immediate"
		var caption: String = "切为暂时囤货" if state.sale_policies[ore] == "immediate" else "切为立即出售"
		var button: Button = _button(caption, _change_policy.bind(ore, next_policy), 28)
		button.disabled = state.season_ended
		row.add_child(button)


func _refresh_fleet() -> void:
	_clear(fleet_box)
	if state.ships.is_empty():
		fleet_box.add_child(_label("舰队空闲。配置一枚猎鹰火箭或不锈钢星舰，开始第一趟深空运输。", 14, MUTED))
		return
	for ship in state.ships:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _style(Color("0c1a27"), EDGE, 5, 7))
		fleet_box.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var star: Dictionary = state.stars[ship["star_id"]]
		var status: String = ""
		match str(ship["state"]):
			"outbound": status = "前往%s · Day %.1f抵达" % [star["name"], float(int(ship["event_tick"])) / 2.0]
			"waiting": status = "%s 等待装货 · 星仓 %d / 计划 %d 箱" % [star["name"], int(star["stock"]), int(ship["planned_cargo"])]
			"inbound": status = "从%s返航 · %s %d 箱 · Day %.1f到港" % [star["name"], Sim.ore_name(str(star["ore"])), int(ship["cargo"]), float(int(ship["event_tick"])) / 2.0]
			"port": status = "母港待卸 · %s %d 箱" % [Sim.ore_name(str(star["ore"])), int(ship["cargo"])]
			"refurbishing": status = "筷子塔整备翻修中 · Day %.1f完成" % (float(int(ship["event_tick"])) / 2.0)
			_: status = "星舰巨湾待命"
		var b_tier: int = int(ship.get("block_tier", 1))
		var tier_label: String = " [Block %d]" % b_tier if Rules.is_reusable_mode(str(ship["mode"])) else ""
		box.add_child(_label("#%d  %s%s" % [int(ship["id"]), Sim.mode_name(str(ship["mode"])), tier_label], 14, GOLD if b_tier >= 2 else GREEN))
		box.add_child(_label(status, 13, MUTED))
		var action_row := HBoxContainer.new()
		box.add_child(action_row)
		if ship["state"] == "waiting" and not state.season_ended:
			action_row.add_child(_button("现在返航", _return_now.bind(int(ship["id"])), 28))
		if Rules.is_reusable_mode(str(ship["mode"])) and not state.season_ended:
			if ship["state"] == "idle":
				action_row.add_child(_button("一键复飞", _quick_relaunch.bind(int(ship["id"])), 28))
				action_row.add_child(_button("改配装", _select_owned.bind(int(ship["id"])), 28))
			if b_tier < 3:
				var upg_cost: String = "$70" if b_tier == 1 else "$110"
				var upg_txt: String = "🔧升Block %d(%s)" % [b_tier + 1, upg_cost]
				action_row.add_child(_button(upg_txt, _upgrade_ship_block.bind(int(ship["id"])), 28))
			var loop_on: bool = bool(ship.get("auto_loop", false))
			action_row.add_child(_button("自动巡航: 开" if loop_on else "自动巡航: 关", _toggle_ship_loop.bind(int(ship["id"])), 28))
			if ship["state"] in ["idle", "refurbishing"]:
				var resale_amt: String = Rules.money(Sim.ship_resale_value(state, str(ship["mode"])))
				action_row.add_child(_button("变卖 " + resale_amt, _sell_ship.bind(int(ship["id"])), 28))


func _refresh_log() -> void:
	var lines := PackedStringArray()
	var start: int = 0 if log_expanded else maxi(0, state.event_log.size() - 4)
	for index in range(state.event_log.size() - 1, start - 1, -1):
		var item: Dictionary = state.event_log[index]
		lines.append("D%.1f  %s" % [float(int(item["tick"])) / 2.0, item["text"]])
	log_label.text = "\n".join(lines)
	log_toggle.text = "收起记录" if log_expanded else "展开记录"


func _refresh_tech() -> void:
	if tech_box == null:
		return
	_clear(tech_box)
	var defs: Dictionary = TechTree.get_tech_definitions()
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	tech_box.add_child(_label("地球星舰基地 · 永久航天科技研发中心", 20, GOLD))
	var explain_card := PanelContainer.new()
	explain_card.add_theme_stylebox_override("panel", _style(Color("0e2230"), CYAN, 6, 10))
	tech_box.add_child(explain_card)
	explain_card.add_child(_paragraph("💡【关于科技树与存档机制的说明】\n本作采用对标《石油大亨 (Turmoil)》的「长线生涯存档 + 分季星区开拓」模式：每一个开采季是一次星区远征；而您在此处研发突破的【8 大航天科技】、【火星星城殖民阶段】与【地球星舰母港股权】将永久保存在您的生涯档案 (career_profile.json) 中，在后续所有新航季中永久继承生效！", 13, Color("b9f6f3")))

	for tech_id in TechTree.TECH_ORDER:
		if not defs.has(tech_id):
			continue
		var node: Dictionary = defs[tech_id]
		var is_done: bool = TechTree.is_unlocked(unlocked, tech_id)
		var check: Dictionary = TechTree.can_research(unlocked, tech_id, state.cash_cents)
		var card := PanelContainer.new()
		var border_col: Color = GREEN if is_done else (GOLD if bool(check.get("ok", false)) else EDGE)
		card.add_theme_stylebox_override("panel", _style(Color("10202e"), border_col, 6, 12))
		tech_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title_str: String = "%s  (%s)" % [str(node["name_zh"]), Rules.money(int(node["cost_cents"]))]
		if is_done:
			title_str = "✓ " + str(node["name_zh"]) + " [生涯永久掌握]"
		info.add_child(_label(title_str, 16, GREEN if is_done else GOLD))
		info.add_child(_paragraph(str(node["desc_zh"]), 13, INK))
		var prereqs: Array = node.get("requires", [])
		if not prereqs.is_empty():
			var req_names := PackedStringArray()
			for r in prereqs:
				req_names.append(str(defs.get(str(r), {}).get("name_zh", r)))
			info.add_child(_label("前置需求：" + "、".join(req_names), 12, MUTED))
		var btn_label: String = "已掌握" if is_done else ("立即研发 · " + Rules.money(int(node["cost_cents"])))
		if not is_done and not bool(check.get("ok", false)):
			btn_label = str(check.get("reason", "不可研发"))
		var r_btn: Button = _button(btn_label, _research_tech.bind(tech_id), 38)
		r_btn.disabled = is_done or not bool(check.get("ok", false)) or state.season_ended
		row.add_child(r_btn)


func _research_tech(tech_id: String) -> void:
	var res: Dictionary = TechTree.research(state, tech_id)
	if res.get("ok", false):
		_cue("tech")
		var t_name: String = str(res.get("tech_name", ""))
		_push_notice("科技突破：%s 已永久生效！" % t_name, "order")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("trade", "★ " + t_name, GOLD)
		_persist()
	else:
		status_text = str(res.get("error", "研发失败。"))
	_refresh_all()


func _refresh_achievements() -> void:
	if achievements_box == null:
		return
	_clear(achievements_box)
	var unlocked_cnt: int = SteamService.unlocked_count()
	var total_cnt: int = SteamService.total_count()
	var mode_str: String = "Steamworks 云同步已激活 (%s)" % SteamService.user_name if SteamService.is_steam_active else "本地脱机生涯荣誉馆（连接 Steam 后自动同步）"
	achievements_box.add_child(_label("星际承包商生涯档案与荣誉成就  (%d / %d)" % [unlocked_cnt, total_cnt], 20, GOLD))
	achievements_box.add_child(_label(mode_str, 13, GREEN if SteamService.is_steam_active else MUTED))
	var records: Dictionary = Save.read_records() if not test_mode else {}
	var career: Dictionary = Save.read_career() if not test_mode else {}
	var career_summary: String = "生涯已掌握科技：%d/8 项  ·  星舰母港持股：%d%%  ·  火星星城：Lv.%d/5" % [(career.get("unlocked_techs", []) as Array).size(), int(career.get("player_shares", 5)), int(career.get("mars_stage", 0))]
	if records.has("best_net"):
		career_summary += "  ·  单季最高净利：" + Rules.money(int(records["best_net"]))
	achievements_box.add_child(_label(career_summary, 15, GOLD))
	for ach_id in SteamService.ACHIEVEMENTS:
		var info: Dictionary = SteamService.ACHIEVEMENTS[ach_id]
		var done: bool = SteamService.is_unlocked(ach_id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("132634") if done else Color("0c1722"), GREEN if done else EDGE, 5, 10))
		achievements_box.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		var badge: String = "🏆 [已达成] " if done else "🔒 [未解锁] "
		box.add_child(_label("%s%s  /  %s" % [badge, str(info["title_zh"]), str(info["title_en"])], 15, GREEN if done else MUTED))
		box.add_child(_label(str(info["desc_zh"]), 13, INK if done else MUTED))


func _refresh_settings() -> void:
	if settings_box == null:
		return
	_clear(settings_box)
	settings_box.add_child(_label("三槽位生涯存档管理 (Multi-Slot Save Manager)", 18, GOLD))
	for s_idx in [1, 2, 3]:
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 10)
		settings_box.add_child(slot_row)
		var sum_lbl: Label = _label(Save.slot_summary(s_idx), 14, INK)
		sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_child(sum_lbl)
		slot_row.add_child(_button("💾 存入槽位 #%d" % s_idx, _save_to_slot.bind(s_idx), 32))
		slot_row.add_child(_button("📂 读取槽位 #%d" % s_idx, _load_from_slot.bind(s_idx), 32))

	settings_box.add_child(_label("高级商业版设置与测试特权", 18, GOLD))
	var ev_check := CheckButton.new()
	ev_check.text = "启用深空动态事件（耀斑爆发 / 市场暴涨 / 富矿发现 / 废墟打捞）"
	ev_check.button_pressed = state.events_enabled
	ev_check.toggled.connect(_on_events_toggled)
	settings_box.add_child(ev_check)

	var shake_check := CheckButton.new()
	shake_check.text = "星舰点火屏幕震动特效 (Screen Shake)"
	shake_check.button_pressed = bool(SettingsService.data.get("graphics", {}).get("screen_shake", true))
	shake_check.toggled.connect(_on_shake_toggled)
	settings_box.add_child(shake_check)

	var win_row := HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 10)
	settings_box.add_child(win_row)
	win_row.add_child(_label("显示模式：", 14, INK))
	win_row.add_child(_button("窗口化 (1440×900)", _set_window_mode.bind(0), 34))
	win_row.add_child(_button("全屏模式", _set_window_mode.bind(1), 34))
	win_row.add_child(_button("窗口最大化", _set_window_mode.bind(2), 34))

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	settings_box.add_child(vol_row)
	vol_row.add_child(_label("主音量调节：", 14, INK))
	for pct in [25, 50, 75, 100]:
		vol_row.add_child(_button("%d%%" % pct, _set_master_vol.bind(pct), 32))

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	settings_box.add_child(lang_row)
	lang_row.add_child(_label("界面语言 (Language)：", 14, INK))
	lang_row.add_child(_button("简体中文", _switch_lang.bind("zh_CN"), 32))
	lang_row.add_child(_button("English", _switch_lang.bind("en_US"), 32))


func _save_to_slot(slot_idx: int) -> void:
	var res: Dictionary = Save.save_slot(slot_idx, state)
	_v40_settings_refresh_pending = true
	status_text = "已成功保存至存档槽位 #%d！" % slot_idx if res.get("ok", false) else str(res.get("error", "保存失败。"))
	_refresh_all()


func _load_from_slot(slot_idx: int) -> void:
	var res: Dictionary = Save.load_slot(slot_idx)
	_v40_settings_refresh_pending = true
	if not res.get("ok", false):
		status_text = str(res.get("error", "读取槽位失败。"))
	else:
		state = res["state"]
		pending_scenario_id = state.scenario_id
		selected_star_id = str(state.stars.keys()[0])
		speed = 0
		editing = false
		_suggest_miner()
		status_text = "已从存档槽位 #%d 恢复进度！" % slot_idx
		board_window.hide()
	_refresh_all()


func _on_events_toggled(pressed: bool) -> void:
	if not refreshing:
		state.events_enabled = pressed
		_persist()


func _on_shake_toggled(pressed: bool) -> void:
	if not refreshing:
		SettingsService.data["graphics"]["screen_shake"] = pressed
		SettingsService.save_settings()


func _set_window_mode(mode: int) -> void:
	SettingsService.data["graphics"]["window_mode"] = mode
	SettingsService.apply_graphics()
	SettingsService.save_settings()


func _toggle_log() -> void:
	log_expanded = not log_expanded
	_refresh_log()


func _request() -> Dictionary:
	var selected: Dictionary = mode_options.get_selected_metadata()
	return {"mode": selected["mode"], "owned_ship_id": selected["owned_ship_id"],
		"star_id": selected_star_id, "miner": miner_check.button_pressed,
		"silo": silo_check.button_pressed, "cargo": int(cargo_spin.value)}


func _refresh_quote() -> void:
	if refreshing or mode_options.item_count == 0:
		return
	var target: Dictionary = state.stars[selected_star_id]
	mission_target_label.text = "任务目标：%s · 星仓 %d 箱%s" % [target["name"], int(target["stock"]), " · 高重力" if target["environment"] == "high_g" else ""]
	var req: Dictionary = _request()
	var quote: Dictionary = Rules.quote_mission(state, req)
	if not quote.has("total_cents"):
		quote_label.text = "请选择目标和火箭。"
		launch_button.disabled = true
		return
	var maximum: int = Rules.max_feasible_cargo(state, req)
	var estimate: Dictionary = Rules.estimate_mission(state, quote)
	var timing: String = "Day %.1f" % (float(int(estimate.get("min_tick", 60))) / 2.0)
	if int(estimate.get("min_tick", 60)) != int(estimate.get("max_tick", 60)):
		timing += "–%.1f" % (float(int(estimate["max_tick"])) / 2.0)
	var range_text: String = "%d" % int(estimate.get("min_cargo", 0))
	if int(estimate.get("min_cargo", 0)) != int(estimate.get("max_cargo", 0)):
		range_text += "–%d" % int(estimate["max_cargo"])
	var lines := PackedStringArray([
		"本次支付  %s    ·    最大可带  %s" % [Rules.money(int(quote["total_cents"])), "%d 箱" % maximum if maximum >= 0 else "不可行"],
		"抵达目标  Day %.1f" % (float(state.current_tick + int(quote["travel_ticks"])) / 2.0),
		"预计返港  %s    ·    可能带回  %s 箱" % [timing, range_text],
		"常驻价预计收入  %s – %s" % [Rules.money(int(estimate.get("min_revenue", 0))), Rules.money(int(estimate.get("max_revenue", 0)))],
		"去 / 返燃料  %d / %d    ·    重量  %d/%d  →  %d/%d" % [int(quote["out_fuel"]), int(quote["ret_fuel"]), int(quote["out_mass"]), int(quote["out_cap"]), int(quote["return_mass"]), int(quote["return_cap"])],
		"货舱  去 %d/%d  ·  返 %d/%d" % [int(quote["out_slots"]), int(quote["slot_cap"]), int(quote["return_slots"]), int(quote["slot_cap"])]
	])
	var cost_names: Dictionary = {"hull": "箭体", "return_equipment": "返回设备", "miner": "矿机", "silo": "扩展仓", "license": "许可", "fuel": "燃料", "launch": "发射", "refit": "翻修"}
	var cost_parts := PackedStringArray()
	for key in ["hull", "return_equipment", "miner", "silo", "license", "fuel", "launch", "refit"]:
		var amount: int = int(quote["costs"][key])
		if amount > 0:
			cost_parts.append("%s %s" % [cost_names[key], Rules.money(amount)])
	lines.append("费用明细：" + " · ".join(cost_parts))
	for order in state.orders:
		if str(order["ore"]) != str(target["ore"]) or int(order["announce_tick"]) > state.current_tick or bool(order["closed"]) or int(order["sold"]) >= int(order["quantity"]):
			continue
		lines.append("已公告订单：%s/箱 · Day %.1f–%.1f · 剩余 %d 箱" % [Rules.money(int(order["price"])), float(int(order["open_tick"])) / 2.0, float(int(order["close_tick"])) / 2.0, int(order["quantity"]) - int(order["sold"])])
	if bool(estimate.get("competition", false)):
		lines.append("已有船只可能先取货；上述时间与收入仅供参考。")
	else:
		lines.append("按当前库存、产速及常驻价估算，不保证订单额度。")
	if bool(quote["ok"]):
		lines.append("本次支付会立刻扣款。上面的收入是估价，真正到账要等货物卖掉。")
	else:
		lines.append("起飞重量 %d，上限 %d。返航重量 %d，上限 %d。" % [int(quote["out_mass"]), int(quote["out_cap"]), int(quote["return_mass"]), int(quote["return_cap"])])
		lines.append("下一步：减少返程箱数，或按「寻找可行火箭」。重量是实际限制，不是估价。")
	for error in quote["errors"]:
		lines.append("!  " + str(error))
	if is_instance_valid(mass_gauge):
		var om: int = int(quote["out_mass"])
		var oc: int = maxi(1, int(quote["out_cap"]))
		var rm: int = int(quote["return_mass"])
		var rc: int = maxi(1, int(quote["return_cap"]))
		mass_gauge.max_value = float(oc)
		mass_gauge.value = float(mini(om, oc))
		var m_over: bool = om > oc or rm > rc
		var m_col: Color = RED if m_over else (GOLD if om == oc else GREEN)
		mass_gauge.add_theme_stylebox_override("fill", _style(m_col, m_col, 3, 0))
		mass_gauge_label.text = "起飞重量 %d/%d  ·  返航重量 %d/%d" % [om, oc, rm, rc]
	if is_instance_valid(slot_gauge):
		var os: int = int(quote["out_slots"])
		var rs: int = int(quote["return_slots"])
		var sc: int = maxi(1, int(quote["slot_cap"]))
		slot_gauge.max_value = float(sc)
		slot_gauge.value = float(mini(maxi(os, rs), sc))
		var s_over: bool = os > sc or rs > sc
		var s_col: Color = RED if s_over else (GOLD if maxi(os, rs) == sc else Color("49d6e4"))
		slot_gauge.add_theme_stylebox_override("fill", _style(s_col, s_col, 3, 0))
		slot_gauge_label.text = "去程舱位 %d/%d 格  ·  返程舱位 %d/%d 格" % [os, sc, rs, sc]
	quote_label.text = "\n".join(lines)
	quote_label.add_theme_color_override("font_color", INK if bool(quote["ok"]) else RED)
	launch_button.disabled = not bool(quote["ok"])
	launch_button.text = "点火发射  ·  %s" % Rules.money(int(quote["total_cents"]))


func _find_feasible_rocket() -> void:
	_begin_editing()
	var desired: int = int(cargo_spin.value)
	var best_index: int = -1
	var best_cargo: int = -1
	var best_cost: int = 9223372036854775807
	for index in range(mode_options.item_count):
		var selected: Dictionary = mode_options.get_item_metadata(index)
		var candidate: Dictionary = {"mode": selected["mode"], "owned_ship_id": selected["owned_ship_id"], "star_id": selected_star_id,
			"miner": miner_check.button_pressed, "silo": silo_check.button_pressed, "cargo": desired}
		var maximum: int = Rules.max_feasible_cargo(state, candidate)
		if maximum < 0:
			continue
		candidate["cargo"] = mini(desired, maximum)
		var quote: Dictionary = Rules.quote_mission(state, candidate, false)
		var cost: int = int(quote["total_cents"])
		if int(candidate["cargo"]) > best_cargo or (int(candidate["cargo"]) == best_cargo and cost < best_cost):
			best_index = index
			best_cargo = int(candidate["cargo"])
			best_cost = cost
	if best_index < 0:
		status_text = "当前设备组合没有可行火箭，请检查是否重复部署设施、船队已满或本季时间不足。"
	else:
		mode_options.select(best_index)
		cargo_spin.set_value_no_signal(best_cargo)
		status_text = "已选择可行配装，计划运回 %d 箱，预计支付 %s。" % [best_cargo, Rules.money(best_cost)]
		if best_cargo < desired:
			status_text += " 因载量限制，已减少返程箱数。"
		if best_cost > state.cash_cents:
			status_text += " 资金还差 %s。" % Rules.money(best_cost - state.cash_cents)
	_refresh_all()


func _suggest_miner() -> void:
	if not state.stars.has(selected_star_id) and not state.stars.is_empty():
		selected_star_id = str(state.stars.keys()[0])
	var star: Dictionary = state.stars[selected_star_id]
	var pending: bool = false
	for ship in state.ships:
		if ship["state"] == "outbound" and ship["star_id"] == selected_star_id and bool(ship["deliver_miner"]):
			pending = true
	var public: Dictionary = state.public_reserve(star)
	miner_check.set_pressed_no_signal(not bool(star["has_miner"]) and not pending and (not bool(public["exact"]) or int(public["max"]) > 0))
	silo_check.set_pressed_no_signal(false)


func _select_star(star_id: String) -> void:
	if not state.stars.has(star_id):
		return
	_begin_editing()
	selected_star_id = star_id
	_suggest_miner()
	_refresh_all()
	_ensure_launchable()


func _select_owned(ship_id: int) -> void:
	_begin_editing()
	_refresh_modes()
	for index in range(mode_options.item_count):
		var item: Dictionary = mode_options.get_item_metadata(index)
		if int(item["owned_ship_id"]) == ship_id:
			mode_options.select(index)
			break
	_refresh_all()


func _begin_editing() -> void:
	if refreshing or state.season_ended or editing:
		return
	resume_speed = speed
	speed = 0
	editing = true


func _end_editing() -> void:
	if editing:
		editing = false
		speed = resume_speed
	_refresh_all()


func _on_config_select(_index: int) -> void:
	if refreshing:
		return
	_begin_editing()
	_refresh_all()


func _on_config_toggle(_pressed: bool) -> void:
	if refreshing:
		return
	_begin_editing()
	_refresh_all()


func _on_cargo_changed(_value: float) -> void:
	if refreshing:
		return
	_begin_editing()
	_refresh_all()


func _launch() -> void:
	var result: Dictionary = Sim.dispatch_mission(state, _request())
	if not result.get("ok", false):
		status_text = str(result.get("error", "发射失败。"))
	else:
		status_text = "发射成功。矿机抵达后开始工作；按 1× 推进时间。"
		board_window.hide()
		_cue("launch")
		if is_instance_valid(star_map):
			star_map.trigger_shake(6.5)
			star_map.spawn_launch_blast()
			var spent: int = int(result.get("quote", {}).get("total_cents", 0))
			if spent > 0:
				star_map.spawn_floating_text("pad", "-" + Rules.money(spent), RED)
		_suggest_miner()
		if editing:
			speed = resume_speed
		editing = false
		_persist()
	_refresh_all()


func _advance() -> void:
	# Keep the old time-limited campaign as an explicitly isolated legacy path.
	if state.challenge_id != "":
		var result: Dictionary = Sim.advance_tick(state)
		var v10_rep: Dictionary = Tycoon.tick_v10_economy(state)
		if str(v10_rep.get("ai_dump_msg", "")) != "":
			status_text = str(v10_rep["ai_dump_msg"])
		if result.get("pause", false) and state.auto_pause:
			speed = 0
			accumulated = 0.0
		_present_tick(result)
		_check_objective_hint()
		if state.season_ended:
			speed = 0
			if not test_mode:
				Save.save_record(state)
			_show_settlement()
		_persist()
		_refresh_all()
		return

	# V4 is the sole simulation and accounting authority for long-run play.
	# DO NOT call Sim.advance_tick() / Tycoon.tick_v10_economy() here:
	# they modify the legacy cash/ship balances and can force day-30 settlement.
	state.current_tick += 1 # Compatibility clock for save files / debug records.
	var v40_step: Dictionary = V40.step_v40_simulation(state, 0.5)
	if bool(v40_step.get("auto_pause", false)) and state.auto_pause:
		speed = 0
		accumulated = 0.0
		status_text = "【现金严重短缺保护】已自动暂停：请出售库存、封存矿区、拆售设备或申请授信借款。"
	_persist()
	_refresh_all()


func _present_tick(result: Dictionary) -> void:
	for item in result.get("notices", []):
		if item is Dictionary:
			var raw_txt: String = str(item.get("text", ""))
			var kind: String = str(item.get("kind", ""))
			if kind == "cash" and is_instance_valid(star_map):
				star_map.spawn_floating_text("warehouse", "+" + raw_txt.trim_prefix("到账 "), GREEN)
			_push_notice(raw_txt, kind)
	for name in ["achievement", "tech", "cash", "portfull", "stall", "partial", "arrive", "return", "order", "scan", "finish"]:
		var found: bool = false
		for cue in result.get("cues", []):
			if str(cue) == name:
				found = true
				break
		if found:
			_cue("stall" if name == "portfull" else name)
			return


func _push_notice(text: String, kind: String) -> void:
	if text == "":
		return
	if kind == "cash":
		text += "。下一步：矿机还在星上，下一趟不用重买。"
	elif kind == "stall":
		text += "。下一步：派船把货运走，矿机就会继续挖。"
	elif kind == "portfull":
		text += "。下一步：先卖掉或留出母港仓位。"
	recent_notices.append(text)
	if recent_notices.size() > 8:
		recent_notices.pop_front()
	status_text = text
	if kind == "cash":
		cash_flash_until = Time.get_ticks_msec() + 4500
	if is_instance_valid(star_map):
		star_map.flashes.append({"text": text, "kind": kind, "born": Time.get_ticks_msec()})
		if star_map.flashes.size() > 3:
			star_map.flashes.pop_front()


func _advance_one() -> void:
	editing = false
	speed = 0
	accumulated = 0.0
	_advance()


func _set_speed(value: int) -> void:
	if state.season_ended:
		return
	editing = false
	speed = value
	accumulated = 0.0
	_refresh_all()


func _set_master_vol(pct: int) -> void:
	SettingsService.set_volume("master", pct)
	status_text = "主音量已设为 %d%%。" % pct
	_refresh_all()


func _switch_lang(lang_code: String) -> void:
	I18nService.set_language(lang_code)
	status_text = "Language switched to English." if lang_code == "en_US" else "已切换为简体中文。"
	_refresh_all()


func _toggle_ship_loop(ship_id: int) -> void:
	var res: Dictionary = Sim.toggle_auto_loop(state, ship_id)
	var on: bool = bool(res.get("auto_loop", false))
	_apply_result(res, "复用箭 #%d 自动往返巡航已%s。" % [ship_id, "开启" if on else "关闭"])


func _quick_relaunch(ship_id: int) -> void:
	var res: Dictionary = Sim.relaunch_ship_now(state, ship_id)
	if res.get("ok", false):
		_cue("launch")
		if is_instance_valid(star_map):
			star_map.trigger_shake(5.5)
			star_map.spawn_launch_blast()
			var spent: int = int(res.get("quote", {}).get("total_cents", 0))
			if spent > 0:
				star_map.spawn_floating_text("pad", "-" + Rules.money(spent), RED)
	_apply_result(res, "复用箭 #%d 已按上趟航线一键复飞！" % ship_id)


func _upgrade_deep_drill() -> void:
	var res: Dictionary = Tycoon.upgrade_deep_drill(state, selected_star_id)
	if res.get("ok", false):
		_cue("tech")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text(selected_star_id, "深核+" + str(res.get("added", 24)) + "箱!", GOLD)
	_apply_result(res, "深岩穿甲钻头改造完成，深层地核富矿脉已并入！")


func _upgrade_pipe() -> void:
	var res: Dictionary = Tycoon.upgrade_star_pipe(state, selected_star_id)
	if res.get("ok", false):
		_cue("tech")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text(selected_star_id, "弹射轨 Lv." + str(res.get("level", 2)), GREEN)
	_apply_result(res, "星轨电磁弹射导轨升级完成！星仓扩容 +6 箱，去程燃料降低。")


func _bribe_saloon() -> void:
	var res: Dictionary = Tycoon.bribe_saloon_official(state)
	if res.get("ok", false):
		_cue("cash")
	_apply_result(res, "星港沙龙密约已达成：未来 4 日左右双港收购价锁定高位溢价！")


func _sign_futures() -> void:
	var res: Dictionary = Tycoon.sign_futures_contract(state)
	if res.get("ok", false):
		_cue("order")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("trade", "📈 期货高价锁定!", CYAN)
	_apply_result(res, "已签署 5 日远期高价期货交割合约，无惧市场波动！")


func _upgrade_orbital_depot() -> void:
	var res: Dictionary = Tycoon.upgrade_orbital_depot(state)
	if res.get("ok", false):
		_cue("tech")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("pad", "🛰 在轨加注站 Lv.%d!" % int(res.get("level", 1)), CYAN)
	_apply_result(res, "地球近地轨道星舰加注站升级完成！中远距航程缩短且燃料减耗！")


func _launch_starlink() -> void:
	var res: Dictionary = Tycoon.launch_starlink_batch(state)
	if res.get("ok", false):
		_cue("launch")
		if is_instance_valid(star_map):
			star_map.trigger_shake(4.5)
			star_map.spawn_launch_blast()
			star_map.spawn_floating_text("pad", "📡 星链 %d 颗在轨!" % int(res.get("satellites", 12)), CYAN)
	_apply_result(res, "星链 V2 Mini 一箭12星成功入轨！每日自动产生宽带现金流分红并自动揭盲星球！")


func _upgrade_ship_block(ship_id: int) -> void:
	var res: Dictionary = Tycoon.upgrade_ship_block(state, ship_id)
	if res.get("ok", false):
		_cue("tech")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("hangar", "🔧 #%d 升至 Block %d!" % [ship_id, int(res.get("block_tier", 2))], GOLD)
	_apply_result(res, "星舰巨湾改装完成：#" + str(ship_id) + " 已升级至 Block " + str(res.get("block_tier", 2)) + "！")


func _invest_mars() -> void:
	var res: Dictionary = Tycoon.invest_mars_colony(state)
	if res.get("ok", false):
		_cue("achievement")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("trade", "🪐 火星星城 Lv.%d!" % int(res.get("stage", 1)), GOLD)
	_apply_result(res, "火星阿瑞斯星城里程碑推进成功！全港矿石收购牌价永久上浮！")


func _smelt_port_stock(ore: String) -> void:
	var res: Dictionary = Tycoon.smelt_and_sell_port_ore(state, ore)
	var gain: int = int(res.get("proceeds", 0))
	if gain > 0 and is_instance_valid(star_map):
		star_map.spawn_floating_text("warehouse", "🔥精炼+" + Rules.money(gain), GOLD)
		_cue("cash")
	_apply_result(res, "电弧精炼出厂：卖出 %d 箱「%s」，溢价 +35%% 到账 %s！" % [int(res.get("quantity", 0)), str(res.get("product", "")), Rules.money(gain)])


func _buy_shares() -> void:
	var res: Dictionary = Tycoon.buy_starport_shares(state)
	if res.get("ok", false):
		_cue("achievement")
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("trade", "股权 %d%%!" % int(res.get("player_shares", 10)), GOLD)
	_apply_result(res, "成功增持 5% 地球星舰母港永久股权！")


func _return_now(ship_id: int) -> void:
	_apply_result(Sim.return_now(state, ship_id), "已按当前库存提前返航。")


func _scan() -> void:
	var star: Dictionary = state.stars.get(selected_star_id, {})
	if not bool(star.get("revealed", true)):
		var days: float = float(int(state.balance["scan_ticks"])) / 2.0
		var res: Dictionary = Sim.start_scan(state, selected_star_id)
		if res.get("ok", false):
			_cue("scan")
			if is_instance_valid(star_map):
				star_map.spawn_floating_text(selected_star_id, "🛰 探星扫描中...", CYAN)
		_apply_result(res, "探测卫星已发射，%.1f日后揭晓地下矿脉准确储量。" % days)
	else:
		var res_vein: Dictionary = Tycoon.prospect_star_veins(state, selected_star_id)
		if res_vein.get("ok", false):
			_cue("scan")
			var bonus_amt: int = int(res_vein.get("bonus", 8))
			if is_instance_valid(star_map):
				star_map.spawn_floating_text(selected_star_id, "🛰 发现富矿+%d箱!" % bonus_amt, GOLD)
			_push_notice("深度探矿完成：发现%s +%d 箱！" % [str(res_vein.get("ore_label", "伴生富矿")), bonus_amt], "scan")
		_apply_result(res_vein, "深度地质声呐扫描完成！已发现伴生富矿夹层！")


func _discover_star() -> void:
	var res: Dictionary = Tycoon.discover_new_star(state)
	if res.get("ok", false):
		_cue("achievement")
		var new_id: String = str(res.get("star_id", ""))
		var new_name: String = str(res.get("star_name", "新矿星"))
		selected_star_id = new_id
		if is_instance_valid(star_map):
			star_map.spawn_floating_text(new_id, "🔭 新发现：" + new_name, GOLD)
		_push_notice("巡天望远镜发现新天体：【%s】！" % new_name, "order")
	_apply_result(res, "深空巡天望远镜成功在星系中发现新矿星！")


func _borrow() -> void:
	_apply_result(Sim.borrow(state, 10000), "已借入 $100；本金和利息将在结算时计入。")


func _repay() -> void:
	_apply_result(Sim.repay(state, 10000), "已偿还 $100 本金及全部未付利息。")


func _sell_ship(ship_id: int) -> void:
	_apply_result(Sim.sell_ship(state, ship_id), "复用箭已变卖，释放一个船队席位。")


func _change_policy(ore: String, policy: String) -> void:
	var before_cash: int = state.cash_cents
	var result: Dictionary = Sim.set_sale_policy(state, ore, policy)
	var gain: int = state.cash_cents - before_cash
	var message: String = "已开启%s自动出售" % Sim.ore_name(ore) if policy == "immediate" else "已切换为留货等单"
	if gain > 0:
		message += "，本次到账 %s" % Rules.money(gain)
		if is_instance_valid(star_map):
			star_map.spawn_floating_text("warehouse", "+" + Rules.money(gain), GREEN)
	_apply_result(result, message + "。")


func _sell_port_stock(ore: String) -> void:
	var result: Dictionary = Sim.sell_port_stock(state, ore)
	var gain: int = int(result.get("proceeds", 0))
	if gain > 0 and is_instance_valid(star_map):
		star_map.spawn_floating_text("warehouse", "+" + Rules.money(gain), GREEN)
		_cue("cash")
	var message: String = "已卖出 %d 箱%s，到账 %s；销售模式不变。" % [int(result.get("quantity", 0)), Sim.ore_name(ore), Rules.money(gain)]
	_apply_result(result, message)


func _on_facility_selected(facility_id: String) -> void:
	if state.season_ended:
		return
	match facility_id:
		"warehouse":
			status_text = "星链矿产立体仓。返航卸下的矿石在这里出售，也可留货进行 +35% 电弧精炼。"
			_jump_market()
		"trade":
			status_text = "火星殖民与股权大厅。查看双港跳价、签署期货、推进火星星城建设与母港股权并购。"
			_jump_market()
		"tanks":
			status_text = "液氧甲烷低温储罐群。推进剂随发射按航程、箭体和载重自动结算。"
			_jump_mission()
		_:
			status_text = "筷子发射回收塔与星舰巨湾。先在天空选中矿星，再在这里配装并发射。"
			_jump_mission()


func _jump_market() -> void:
	_open_board_panel(1)


func _jump_mission() -> void:
	_open_board_panel(0)


func _open_board_panel(tab_index: int) -> void:
	# Only settings/save remains available from the legacy popup in V4 mode.
	# Legacy financial controls must not mutate cash independent of V4DawnEngine.
	if state.challenge_id == "" and tab_index != 3:
		_switch_v10_screen("astra_hud" if tab_index == 0 else "corp")
		return
	_begin_editing()
	board_tabs.current_tab = tab_index
	if state.challenge_id == "" and tab_index == 3:
		_v40_settings_refresh_pending = true
	board_window.popup_centered()
	_refresh_all()


func _close_board_panel() -> void:
	board_window.hide()
	_end_editing()


func _board_expand() -> void:
	_open_board_panel(0)
	silo_check.button_pressed = true


func _board_reset_view() -> void:
	if is_instance_valid(star_map):
		star_map.focused_galaxy_id = ""
		star_map.map_zoom = 1.0
		star_map.map_offset = Vector2.ZERO
		star_map.queue_redraw()


func _apply_result(result: Dictionary, success: String) -> void:
	status_text = success if result.get("ok", false) else str(result.get("error", "操作失败。"))
	if result.get("ok", false):
		_persist()
	_refresh_all()


func _on_auto_pause(pressed: bool) -> void:
	if not refreshing:
		state.auto_pause = pressed
		_persist()


func _on_sound(pressed: bool) -> void:
	if not refreshing:
		state.sound_enabled = pressed
		if is_instance_valid(bgm_player):
			if pressed and not test_mode:
				bgm_player.play()
			else:
				bgm_player.stop()
		_persist()


func _dismiss_tutorial() -> void:
	V40.execute_command(state, "ToggleFamiliarMode", {})
	_persist()
	_refresh_all()


func _ask_finish() -> void:
	board_window.hide()
	if state.season_ended:
		_show_settlement()
		return
	speed = 0
	editing = false
	var preview: Dictionary = Sim.preview_settlement(state)
	var active: int = 0
	for ship in state.ships:
		if str(ship["state"]) in ["outbound", "waiting", "inbound"]:
			active += 1
	finish_dialog.dialog_text = "现在结算预计净收益 %s。\n还有 %d 艘火箭未回港，其货物与资产不计入本季清算。\n确定结束本季吗？" % [Rules.money(int(preview["net"])), active]
	finish_dialog.popup_centered()
	_refresh_all()


func _confirm_finish() -> void:
	Sim.finish_season(state)
	if not test_mode:
		Save.save_record(state)
	_persist()
	_show_settlement()
	_refresh_all()


func _show_settlement(saved_result: Dictionary = {}) -> void:
	board_window.hide()
	var result: Dictionary = saved_result if not saved_result.is_empty() else Sim.preview_settlement(state)
	var records: Dictionary = Save.read_records() if not test_mode else {}
	var expenses: Dictionary = result["stats"]["expenses"]
	var research_spent: int = int(expenses.get("research", 0))
	var net_val: int = int(result["net"])
	var grade_str: String = "C 级 · 边缘淘金客"
	if net_val >= 500000:
		grade_str = "S+ 级 · 星际传奇大亨"
	elif net_val >= 340000:
		grade_str = "S 级 · 银河矿业巨头"
	elif net_val >= 200000:
		grade_str = "A 级 · 资深航运专家"
	elif net_val > 0:
		grade_str = "B 级 · 合格矿运承包商"
	var perk_info: Dictionary = Perks.get_perk(state.perk_id)
	# 计算 V1.0 四大核心诊断指标：矿区投资回报率、运输效率、未售库存、矿产开采率
	var total_initial_ore: int = 0
	var total_remaining_ore: int = 0
	var total_unshipped_stock: int = 0
	for sid in state.stars:
		var st_d: Dictionary = state.stars[sid]
		total_initial_ore += maxi(1, int(st_d.get("initial_reserve", 20)))
		total_remaining_ore += int(st_d.get("reserve", 0))
		total_unshipped_stock += int(st_d.get("stock", 0))
	var extraction_rate: int = clampi(int(round(float(total_initial_ore - total_remaining_ore) * 100.0 / float(maxi(1, total_initial_ore)))), 0, 100)
	var mining_invest: int = maxi(10000, int(expenses["miner"]) + int(expenses["silo"]) + int(expenses["license"]) + int(expenses["scan"]))
	var total_rev: int = int(state.stats.get("regular_revenue", 0)) + int(state.stats.get("order_revenue", 0)) + int(result["ore_value"])
	var roi_pct: int = int(round(float(total_rev - mining_invest) * 100.0 / float(mining_invest)))
	var trips_done: int = int(result["stats"]["completed_trips"])
	var partials: int = int(result["stats"]["partial_returns"])
	var transport_eff: int = 100 if trips_done == 0 else clampi(int(round(float(trips_done - partials) * 100.0 / float(trips_done))), 0, 100)

	# 计算与三家 AI 财团的赛季净利润排名
	var ledgers: Dictionary = Tycoon.ensure_rival_ledgers(state)
	var rank_entries: Array[Dictionary] = [
		{"name": "★ 您的航天矿业公司", "net": net_val},
		{"name": str(ledgers["rex"]["name"]), "net": int(ledgers["rex"]["net_profit_cents"])},
		{"name": str(ledgers["victoria"]["name"]), "net": int(ledgers["victoria"]["net_profit_cents"])},
		{"name": str(ledgers["otto"]["name"]), "net": int(ledgers["otto"]["net_profit_cents"])}
	]
	rank_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["net"]) > int(b["net"]))
	var rank_lines: PackedStringArray = PackedStringArray()
	for r_i in range(rank_entries.size()):
		rank_lines.append("第 %d 名：%s  （净利润 %s）" % [r_i + 1, str(rank_entries[r_i]["name"]), Rules.money(int(rank_entries[r_i]["net"]))])

	var v40_rep: Dictionary = V40.ensure_v40_state(state)
	var v40_fin: Dictionary = V40.financial_summary(v40_rep)
	var v40_rivals: Dictionary = v40_rep.get("rivals", {})
	var v40_ranks: Array[Dictionary] = [
		{"name": "★ 您的破晓星域矿业集团", "nw": int(v40_fin.get("estimated_net_worth_cr", 60000))},
		{"name": "🔴 赤曜矿业", "nw": int(v40_rivals.get("crimson_mining", {}).get("net_worth_cr", 68000))},
		{"name": "🔵 星环运输", "nw": int(v40_rivals.get("starring_transit", {}).get("net_worth_cr", 72000))},
		{"name": "🟠 银穹资本", "nw": int(v40_rivals.get("silver_dome", {}).get("net_worth_cr", 75000))}
	]
	v40_ranks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["nw"]) > int(b["nw"]))
	var v40_rank_strs := PackedStringArray()
	for idx_r in range(v40_ranks.size()):
		v40_rank_strs.append("#%d %s (%d Cr)" % [idx_r + 1, str(v40_ranks[idx_r]["name"]), int(v40_ranks[idx_r]["nw"])])

	var lines := PackedStringArray([
		"🏛 【V4.0 破晓星域 30 日集团财报 · 三口径账本汇总】",
		"• 可支配现金：%d Cr  （总现金 %d Cr | 冻结保证金 %d Cr）" % [int(v40_fin["available_cash_cr"]), int(v40_fin["cash_cr"]), int(v40_fin["reserved_cash_cr"])],
		"• 经营结余 (Operating Surplus)：%d Cr   |   • 估计净资产 (Net Worth)：%d Cr" % [int(v40_fin["operating_surplus_cr"]), int(v40_fin["estimated_net_worth_cr"])],
		"• 破晓星域四大矿业财团净资产排名：" + "  |  ".join(v40_rank_strs),
		"",
		"★ 赛季综合评级：" + grade_str + "  （" + str(perk_info["name_zh"]) + "）",
		"📊 【V1.0 四大核心经营诊断指标】",
		"• 矿区投资回报率 (ROI)：%d%%   |   • 矿产开采率：%d%%" % [roi_pct, extraction_rate],
		"• 火箭满载运输效率：%d%%       |   • 未售/滞留库存：母港 %s + 矿区滞留 %d 箱" % [transport_eff, Rules.money(int(result["ore_value"])), total_unshipped_stock],
		"",
		"🏆 【本赛季矿业公司净利润排行榜】",
		"  " + "  |  ".join(rank_lines),
		"",
		"赚了多少",
		"%s。净收益 %s。结束于 Day %.1f。" % ["本季盈利" if int(result["net"]) > 0 else "本季亏损或持平", Rules.money(int(result["net"])), float(int(result["tick"])) / 2.0],
		"现金 %s，母港矿石清算 %s，火箭残值 %s。" % [Rules.money(int(result["cash"])), Rules.money(int(result["ore_value"])), Rules.money(int(result["resale"]))],
		"减去未还本金 %s、未付利息 %s、开局资金 %s。" % [Rules.money(int(result["principal"])), Rules.money(int(result["interest"])), Rules.money(int(result["starting_cash"]))],
		"",
		"钱花在哪",
		"箭体 %s，返回设备 %s，矿机与扩仓 %s。" % [Rules.money(int(expenses["hull"])), Rules.money(int(expenses["return_equipment"])), Rules.money(int(expenses["miner"]) + int(expenses["silo"]))],
		"许可 %s，燃料 %s，发射 %s，翻修 %s。" % [Rules.money(int(expenses["license"])), Rules.money(int(expenses["fuel"])), Rules.money(int(expenses["launch"])), Rules.money(int(expenses["refit"]))],
		"探测 %s，已付利息 %s，科技/火星/股权 %s。" % [Rules.money(int(expenses["scan"])), Rules.money(int(expenses["interest"])), Rules.money(research_spent)],
		"",
		"运回与留下",
		"卖掉金属 %d 箱、晶体 %d 箱，其中订单 %d 箱。" % [int(result["stats"]["sold"]["metal"]), int(result["stats"]["sold"]["crystal"]), int(result["stats"]["order_sold"])]
	])
	for star_id in result["remaining"]:
		var star: Dictionary = result["remaining"][star_id]
		lines.append("%s：星上还剩 %d 箱，地下 %d 箱。" % [star["name"], int(star["stock"]), int(star["reserve"])])
	lines.append("")
	lines.append("瓶颈")
	lines.append("完成 %d 航次，少装返航 %d 次。" % [int(result["stats"]["completed_trips"]), int(result["stats"]["partial_returns"])])
	var trip_counts: Dictionary = result["stats"].get("trips_by_mode", {})
	if not trip_counts.is_empty():
		lines.append("航次：轻型 %d / 中型一次性 %d / 中型复用 %d / 星舰 %d。" % [int(trip_counts.get("light", 0)), int(trip_counts.get("medium_once", 0)), int(trip_counts.get("medium_reuse", 0)), int(trip_counts.get("heavy_reuse", 0))])
	for order in result.get("orders", []):
		lines.append("订单 %s Day %.1f–%.1f：成交 %d / %d 箱。" % [Sim.ore_name(str(order["ore"])), float(int(order["open_tick"])) / 2.0, float(int(order["close_tick"])) / 2.0, int(order["sold"]), int(order["quantity"])])
	for star_id in result["remaining"]:
		var left: Dictionary = result["remaining"][star_id]
		if int(left["stalled_ticks"]) > 0:
			lines.append("%s仓满停工 %.1f 日。" % [left["name"], float(int(left["stalled_ticks"])) / 2.0])
	if records.has("best_net"):
		lines.append("\n最佳净收益：" + Rules.money(int(records["best_net"])))
	if saved_result.is_empty() and state.challenge_id != "":
		var verdict: Dictionary = Campaign.judge(state)
		lines.append("")
		lines.append(str(verdict.get("text", "")))
		if bool(verdict.get("cleared", false)) and not test_mode:
			campaign.mark(state.challenge_id, int(verdict.get("net", 0)))
			lines.append("战役进度已记录。回主菜单即可查看。")
	result_dialog.dialog_text = "\n".join(lines)
	result_dialog.popup_centered()


func _show_recent_settlement() -> void:
	var records: Dictionary = Save.read_records()
	if not records.has("last_settlement"):
		status_text = "还没有上一季结算记录。"
		_refresh_all()
		return
	speed = 0
	editing = false
	_show_settlement(records["last_settlement"])
	_refresh_all()


func _ask_new_season() -> void:
	board_window.hide()
	speed = 0
	editing = false
	new_dialog.dialog_text = "将开始「%s」。\n当前这一局会被换掉（已解锁的生涯科技、火星星城进度与母港股权会自动保留）。\n确定开始吗？" % _map_title(pending_scenario_id)
	new_dialog.popup_centered()
	_refresh_all()


func _scenario_selected(index: int) -> void:
	if not refreshing:
		pending_scenario_id = str(scenario_options.get_item_metadata(index))


func _new_season() -> void:
	var new_id: String = str(scenario_options.get_selected_metadata())
	var pause_preference: bool = state.auto_pause
	var sound_preference: bool = state.sound_enabled
	var active_perk: String = "standard" if (test_mode or pending_challenge != "") else selected_perk_id
	state = State.new(new_id, 0, active_perk)
	pending_scenario_id = new_id
	state.auto_pause = pause_preference
	state.sound_enabled = sound_preference
	selected_star_id = str(state.stars.keys()[0])
	save_blocked = false
	speed = 0
	editing = false
	accumulated = 0.0
	cargo_spin.set_value_no_signal(4)
	mode_options.clear()
	state.challenge_id = pending_challenge
	pending_challenge = ""
	objective_announced = false
	session_has_run = true
	if not test_mode:
		Save.apply_career_to_state(state)
	_board_reset_view()
	_suggest_miner()
	status_text = "新开采季已开始：%s。已继承生涯科技、火星星城与股权。" % _map_title(new_id)
	if not test_mode:
		Save.keep_previous()
	_persist()
	_refresh_all()
	_ensure_launchable()


func _load_saved() -> void:
	var loaded: Dictionary = Save.load_game()
	if not loaded.get("ok", false):
		status_text = str(loaded.get("error", "读取失败。"))
	else:
		state = loaded["state"]
		pending_scenario_id = state.scenario_id
		selected_star_id = str(state.stars.keys()[0])
		save_blocked = false
		speed = 0
		editing = false
		_suggest_miner()
		status_text = "已读取上次保存的完整局面。"
		if state.season_ended:
			_show_settlement()
	_refresh_all()


func _map_title(map_id: String) -> String:
	match map_id:
		"A": return "A · 稳定矿区"
		"B": return "B · 抢运窗口"
		"C2": return "C · 未知矿区 ①"
		"C20": return "C · 未知矿区 ②"
		"G": return "G · 高重力"
		"X": return "X · 庞大三星系霸权 (8星三大恒星系)"
		"S": return "S · 随机深空矿区"
		"E": return "E · 无尽开拓矿区"
		"D": return "D · 多星矿区"
		_: return map_id


func _ensure_launchable() -> void:
	if mode_options == null or mode_options.item_count == 0 or refreshing:
		return
	var before: int = int(cargo_spin.value)
	var quote: Dictionary = Rules.quote_mission(state, _request())
	if quote.get("ok", false):
		return
	var maximum: int = Rules.max_feasible_cargo(state, _request())
	if maximum < 0:
		_find_feasible_rocket()
		_push_notice(status_text, "partial")
		return
	if maximum >= before:
		status_text = "这趟目前飞不了。请减少返程箱数，或按「寻找可行火箭」。"
		_refresh_all()
		_push_notice(status_text, "partial")
		return
	cargo_spin.set_value_no_signal(maximum)
	status_text = "原计划 %d 箱会超重。已改为 %d 箱，现在可以发射。" % [before, maximum]
	_refresh_all()
	_push_notice(status_text, "partial")


func _show_front_menu_again() -> void:
	_show_front_menu(Save.load_game() if not test_mode else {})


func _show_front_menu(saved_game: Dictionary) -> void:
	if front_menu != null:
		front_menu.queue_free()
	campaign = Campaign.load()
	front_menu = PanelContainer.new()
	front_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_menu.add_theme_stylebox_override("panel", _style(Color("060d15"), Color("2a4a55"), 0, 0))
	add_child(front_menu)
	var menu_bg_tex: Texture2D = load("res://assets/custom/bg_launch_sunset_clean.png") if ResourceLoader.exists("res://assets/custom/bg_launch_sunset_clean.png") else CONCEPT_BG
	if menu_bg_tex != null:
		var bg_tex := TextureRect.new()
		bg_tex.texture = menu_bg_tex
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_tex.modulate = Color(0.42, 0.50, 0.58, 0.90)
		front_menu.add_child(bg_tex)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	front_menu.add_child(scroll)
	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left", 42)
	outer.add_theme_constant_override("margin_right", 42)
	outer.add_theme_constant_override("margin_top", 24)
	outer.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(outer)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	outer.add_child(body)

	var hero_card := PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", _style(Color(0.05, 0.11, 0.17, 0.94), Color("49d6e4"), 8, 16))
	body.add_child(hero_card)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 6)
	hero_card.add_child(hero_box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	hero_box.add_child(title_row)
	title_row.add_child(_label("星矿大亨  ROCKET PROSPECTORS", 30, GOLD))
	var version_badge: Label = _label("V4.0  DAWN SECTOR · FULL GDD ARCHITECTURE EDITION", 13, Color("49d6e4"))
	title_row.add_child(version_badge)
	var hero_spacer := Control.new()
	hero_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(hero_spacer)
	var career_data: Dictionary = Save.read_career() if not test_mode else {}
	var ach_summary: String = "🏆 成就 %d/%d  ·  🔬 生涯科技 %d/8  ·  🪐 火星星城 Lv.%d/5  ·  🏛 股权 %d%%" % [SteamService.unlocked_count(), SteamService.total_count(), (career_data.get("unlocked_techs", []) as Array).size(), int(career_data.get("mars_stage", 0)), int(career_data.get("player_shares", 5))]
	title_row.add_child(_label(ach_summary, 14, GREEN))
	hero_box.add_child(_paragraph("破晓星域五大星团  ·  晨曦贸易港与赤曜深空港  ·  96×48 逻辑格树形井道与半径4格局部采掘  ·  三船型共享船池、单步精炼与二十项总部研究！", 13, MUTED))

	if saved_game.get("ok", false):
		var saved: GameState = saved_game["state"]
		var cont_txt: String = "▶ 继续上次进行中的航季  ·  %s  ·  Day %.1f" % [_map_title(saved.scenario_id), float(saved.current_tick) / 2.0]
		if saved.stats.has("v40") and (saved.stats["v40"] is Dictionary):
			var sv40: Dictionary = saved.stats["v40"]
			var sfin: Dictionary = V40.financial_summary(sv40)
			cont_txt = "🚀 继续破晓星域集团存档  ·  Day %.1f  ·  可支配 %d Cr  ·  估计净资产 %d Cr" % [
				float(sv40.get("game_day", 0.0)), int(sfin.get("available_cash_cr", 30000)), int(sfin.get("estimated_net_worth_cr", 60000))
			]
		var continue_button: Button = _button(cont_txt, _continue_saved.bind(saved), 46)
		continue_button.add_theme_stylebox_override("normal", _style(Color("c47f16"), Color("ffd27a"), 6))
		hero_box.add_child(continue_button)
	elif not test_mode and Save.has_save():
		hero_box.add_child(_paragraph(status_text, 14, RED))

	var deck := HBoxContainer.new()
	deck.add_theme_constant_override("separation", 18)
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(deck)

	var left_card := PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.add_theme_stylebox_override("panel", _style(Color(0.06, 0.12, 0.18, 0.92), EDGE, 8, 16))
	deck.add_child(left_card)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 9)
	left_card.add_child(left_col)
	left_col.add_child(_label("01  //  五季战役挑战 (已为您开启最高权限·全关卡直接畅玩)", 17, GOLD))
	left_col.add_child(_paragraph("所有战役关卡已全部开放！您可以直接点击任意一季测试体验。", 13, GREEN))
	for item in Campaign.CHALLENGES:
		var cid: String = str(item["id"])
		var unlocked: bool = campaign.is_unlocked(cid)
		var is_cleared: bool = bool(campaign.cleared.get(cid, false))
		var prefix: String = "✓ " if is_cleared else "🔓 "
		var caption: String = "%s%s  —  %s" % [prefix, item["title"], item["blurb"]]
		if not unlocked:
			caption = "🔒 %s  ·  完成上一季后解锁" % item["title"]
		var button: Button = _button(caption, _begin_run.bind(str(item["map"]), cid), 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not unlocked
		if is_cleared:
			button.add_theme_stylebox_override("normal", _style(Color("1c342e"), Color("5a9e7c"), 5))
		left_col.add_child(button)

	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.add_theme_stylebox_override("panel", _style(Color(0.06, 0.12, 0.18, 0.92), EDGE, 8, 16))
	deck.add_child(right_card)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 9)
	right_card.add_child(right_col)
	right_col.add_child(_label("02  //  星际财团流派与庞大恒星系远征 (生涯科技/火星/股权永久继承)", 17, GOLD))
	var perk_grid := HBoxContainer.new()
	perk_grid.add_theme_constant_override("separation", 6)
	right_col.add_child(perk_grid)
	for p_item in Perks.PERKS:
		var pid: String = str(p_item["id"])
		var p_btn: Button = _button(str(p_item["name_zh"]), _select_perk.bind(pid), 34)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if pid == selected_perk_id:
			p_btn.add_theme_stylebox_override("normal", _style(Color("26463b"), GREEN, 5))
		perk_grid.add_child(p_btn)
	var cur_perk: Dictionary = Perks.get_perk(selected_perk_id)
	var perk_banner := PanelContainer.new()
	perk_banner.add_theme_stylebox_override("panel", _style(Color("0b1924"), Color("3d6a60"), 5, 10))
	right_col.add_child(perk_banner)
	perk_banner.add_child(_paragraph("流派特性：" + str(cur_perk["desc_zh"]), 13, GREEN))

	right_col.add_child(_label("推荐直接体验（点击即可从地球博卡星舰基地点火起航）：", 14, Color("49d6e4")))
	for mode_pair in [
		["🌌  X · 庞大三星系霸权（旗舰模式：三大恒星系8星 + 三靶点定向剖面钻探 + 轨道加注站 + 火星星城 + 股权并购）", "X"],
		["🎲  S · 随机深空星系（7星三大恒星系程序化生成 + 动态太阳耀斑/富矿天象）", "S"],
		["∞  E · 无尽开拓沙盒（7星三大恒星系 + 无限时长 + 自由建成 5 阶火星星城）", "E"],
		["★  D · 经典四星矿区（紧凑多星并行调度 + 隐秘晶带探测）", "D"]
	]:
		var s_btn: Button = _button(mode_pair[0], _begin_run.bind(mode_pair[1], ""), 38)
		s_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if mode_pair[1] == "X":
			s_btn.add_theme_stylebox_override("normal", _style(Color("3b2d18"), GOLD, 5))
		right_col.add_child(s_btn)

	right_col.add_child(_label("单项专项测试图", 12, MUTED))
	var practice := HBoxContainer.new()
	practice.add_theme_constant_override("separation", 6)
	right_col.add_child(practice)
	for map_id in ["A", "B", "C2", "C20", "G"]:
		var p_map_btn: Button = _button(_map_title(map_id), _begin_run.bind(map_id, ""), 30)
		p_map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		practice.add_child(p_map_btn)

	var extra_row := HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 12)
	body.add_child(extra_row)
	extra_row.add_child(_button("🏆 生涯与荣誉成就馆", _open_menu_tab.bind(5), 40))
	extra_row.add_child(_button("🔬 永久航天科技树", _open_menu_tab.bind(4), 40))
	extra_row.add_child(_button("💾 三槽位存档与系统设置", _open_menu_tab.bind(3), 40))
	if session_has_run:
		var resume_cur: Button = _button("↩ 回到当前运行中的星图", _close_front_menu, 40)
		resume_cur.add_theme_stylebox_override("normal", _style(Color("294338"), GOLD, 5))
		extra_row.add_child(resume_cur)


func _select_perk(pid: String) -> void:
	selected_perk_id = pid
	_show_front_menu_again()


func _open_menu_tab(tab_idx: int) -> void:
	_close_front_menu()
	_open_board_panel(tab_idx)


func _close_front_menu() -> void:
	if front_menu != null:
		front_menu.hide()


func _continue_saved(saved: GameState) -> void:
	state = saved
	pending_scenario_id = state.scenario_id
	selected_star_id = str(state.stars.keys()[0])
	save_blocked = false
	speed = 0
	editing = false
	_suggest_miner()
	session_has_run = true
	status_text = "已继续上次的局面。"
	_refresh_all()
	_ensure_launchable()
	_close_front_menu()


func _check_objective_hint() -> void:
	if objective_announced or state.challenge_id == "" or state.season_ended:
		return
	var remembered: Dictionary = state.settlement
	state.settlement = Sim.preview_settlement(state)
	var verdict: Dictionary = Campaign.judge(state)
	state.settlement = remembered
	if bool(verdict.get("cleared", false)):
		objective_announced = true
		_push_notice("本季目标已经达成，可以提前结算。", "order")


func _begin_run(map_id: String, challenge_id: String) -> void:
	pending_challenge = challenge_id
	pending_scenario_id = map_id
	for index in range(scenario_options.item_count):
		if str(scenario_options.get_item_metadata(index)) == map_id:
			scenario_options.select(index)
			break
	_new_season()
	_close_front_menu()


func _persist() -> void:
	if test_mode or save_blocked:
		return
	var saved: Dictionary = Save.save_game(state)
	if not saved.get("ok", false):
		status_text = str(saved.get("error", "保存失败。"))


func _refresh_turmoil_quick_bar() -> void:
	if state == null:
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	# One canonical V4 mine dictionary drives both selection and map drawing.
	# Do not use state.stars or selected_star_id for V4 exploration.
	if is_instance_valid(v40_galaxy_map_view):
		v40_galaxy_map_view.set("state", state)
		v40_galaxy_map_view.set("selected_mine_id", str(v40.get("active_mine_id", "dawn_1")))
		v40_galaxy_map_view.visible = v10_active_screen == "starmap" and state.challenge_id == ""
		if v40_galaxy_map_view.visible:
			v40_galaxy_map_view.queue_redraw()
	if is_instance_valid(star_map):
		star_map.visible = v10_active_screen == "starmap" and state.challenge_id != ""
	var fin: Dictionary = V40.financial_summary(v40)
	var active_m_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var active_mine: Dictionary = v40["mines"].get(active_m_id, {})
	var bneck: Dictionary = V40.analyze_mine_bottleneck(v40, active_m_id)
	# The inspector selection is UI-only: never store it in the economy ledger.
	if v40_selection_state != state or v40_selected_mine_id != active_m_id:
		v40_selection_state = state
		v40_selected_mine_id = active_m_id
		v40_selected_deposit_idx = -1
	if is_instance_valid(v40_mining_inspector):
		v40_mining_inspector.call("update_target", state, active_m_id, v40_selected_deposit_idx)
		v40_mining_inspector.visible = v10_active_screen == "mining" and state.challenge_id == ""
	if is_instance_valid(v40_mining_feedback):
		v40_mining_feedback.visible = v10_active_screen == "mining" and state.challenge_id == ""
	if is_instance_valid(cross_section_view):
		cross_section_view.set("selected_deposit_idx", v40_selected_deposit_idx)
		cross_section_view.queue_redraw()

	# 1. 顶栏与通知栏：严格按照第 10.1, 10.2 & 16.2 节显示可支配现金、冻结资金、经营结余与估计净资产
	map_label.text = "破晓星域 · " + str(active_mine.get("name_zh", "晨曦一号矿区"))
	cash_label.text = "可支配 %d Cr (总现金 %d | 冻结 %d Cr)" % [
		int(fin["available_cash_cr"]), int(fin["cash_cr"]), int(fin["reserved_cash_cr"])
	]
	debt_label.text = "经营结余 %d Cr | 净资产 %d Cr | 贷款 %d Cr" % [
		int(fin["operating_surplus_cr"]), int(fin["estimated_net_worth_cr"]), int(fin["debt_cr"])
	]
	var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
	var port_used: int = V40._port_used_tonnes(pinv_dawn)
	port_label.text = "晨曦港仓 %d/%d t" % [port_used, int(pinv_dawn.get("capacity_t", 500))]
	day_label.text = "Day %.1f" % float(v40.get("game_day", 0.0))

	if is_instance_valid(tutorial_label):
		var guide: Dictionary = V40.get_contextual_guidance(v40)
		var top_note: String = "【%s】%s  |  💡 %s" % [
			str(guide.get("title_zh", "经营引导")),
			str(guide.get("hint_zh", "")),
			str(bneck.get("bottleneck_text", status_text))
		]
		tutorial_label.text = top_note
	if is_instance_valid(tutorial_button):
		tutorial_button.visible = true
		tutorial_button.text = "标准引导" if bool(v40.get("familiar_player_mode", false)) else "我熟悉经营游戏" 

	if is_instance_valid(board_title) and not active_mine.is_empty():
		board_title.text = "%s · %s (%s)" % [
			str(active_mine["cluster_name_zh"]), str(active_mine["name_zh"]), str(active_mine["archetype_zh"])
		]
		var s_stock: int = int(active_mine.get("silo_stock_t", 0))
		var s_cap: int = maxi(1, int(active_mine.get("silo_capacity_t", 300)))
		board_stock.max_value = float(s_cap)
		board_stock.value = float(s_stock)
		var pool_str: String = " [共享船池:开]" if bool(v40.get("shared_fleet_pool", false)) else ""
		board_inventory.text = "地表矿仓 %d / %d t  |  在役运矿船 %d 艘%s" % [s_stock, s_cap, (v40["ships"] as Array).size(), pool_str]

	# 2. 更新底部遥测栏 (第 16.2 节：实际产量、矿仓占用、预计运输能力与矿体寿命)
	if is_instance_valid(v40_bottom_telemetry_label) and not active_mine.is_empty():
		var dep_days: float = float(bneck.get("depletion_days", 999.0))
		var life_str: String = ("%.1f 日" % dep_days) if dep_days < 500.0 else "充裕 (>100日)"
		var alert_lv: String = str(bneck.get("depletion_alert", "normal"))
		if alert_lv == "urgent":
			life_str += " [🚨不足5日紧急预警!]"
		elif alert_lv == "warning":
			life_str += " [⚠不足15日关注]"
		v40_bottom_telemetry_label.text = "实际产量: %.0f t/日  |  矿仓占用: %d/%d t  |  预计运力: %.0f t/日  |  已知可采储量: %d t (寿命 %s)" % [
			float(bneck.get("effective_rate_t_day", 0.0)),
			int(active_mine.get("silo_stock_t", 0)), int(active_mine.get("silo_capacity_t", 300)),
			float(bneck.get("daily_transport_t_day", 50.0)),
			int(bneck.get("known_remaining_t", 0)), life_str
		]
		v40_bottom_telemetry_label.add_theme_color_override(
			"font_color", RED if alert_lv == "urgent" else (GOLD if alert_lv == "warning" else CYAN)
		)

	# 3. 更新三大视图导航高亮
	if is_instance_valid(v10_tab_mining_btn):
		v10_tab_mining_btn.add_theme_stylebox_override("normal", _style(Color("1e4236") if v10_active_screen == "mining" else Color("182836"), GREEN if v10_active_screen == "mining" else EDGE, 5, 8))
	if is_instance_valid(v10_tab_map_btn):
		v10_tab_map_btn.add_theme_stylebox_override("normal", _style(Color("1e4236") if v10_active_screen == "starmap" else Color("182836"), GREEN if v10_active_screen == "starmap" else EDGE, 5, 8))
	if is_instance_valid(v10_tab_launch_btn):
		v10_tab_launch_btn.add_theme_stylebox_override("normal", _style(Color("1e4236") if v10_active_screen == "corp" else Color("182836"), GREEN if v10_active_screen == "corp" else EDGE, 5, 8))
	if is_instance_valid(v40_tab_astra_btn):
		v40_tab_astra_btn.add_theme_stylebox_override("normal", _style(Color("123854") if v10_active_screen == "astra_hud" else Color("182836"), CYAN if v10_active_screen == "astra_hud" else EDGE, 5, 8))

	# 4. 更新左侧矿区切换栏
	if is_instance_valid(v10_zone_selector_box):
		_clear(v10_zone_selector_box)
		for mid in v40["mines"]:
			var m_item: Dictionary = v40["mines"][mid]
			var owned_tag: String = "✓" if bool(m_item.get("license_owned", false)) else "🔒"
			var is_cur: bool = (str(mid) == active_m_id)
			var m_btn: Button = _button("%s %s (%dt)" % [owned_tag, str(m_item["name_zh"]), int(m_item.get("silo_stock_t", 0))], _v40_select_mine.bind(str(mid)), 26)
			if is_cur:
				m_btn.add_theme_stylebox_override("normal", _style(Color("28463a"), GOLD, 4, 4))
			v10_zone_selector_box.add_child(m_btn)

	# 5. 更新右侧三类船型采购与每船日贡献比较面板 (第 8.2 & 8.3 & 11.5 节)
	if is_instance_valid(v10_rockets_box) and not active_mine.is_empty():
		_clear(v10_rockets_box)
		var dist_l: float = float(active_mine.get("distance_l", 0.5))
		var grav_g: float = float(active_mine.get("gravity_g", 1.0))
		var prim_min: String = str(active_mine.get("primary_mineral", "iron_titanium"))
		var m_cfg: Dictionary = V40.get_config().get("minerals", {}).get(prim_min, {})
		var ref_p: int = int(m_cfg.get("base_price_cr", 100))
		var var_c: int = int(m_cfg.get("mining_var_cost_cr", 8))

		var ship_tex_map: Dictionary = {
			"falcon_light": "res://assets/custom/rocket_light.png",
			"peregrine_med": "res://assets/custom/rocket_reuse.png",
			"leviathan_heavy": "res://assets/custom/rocket_heavy.png"
		}
		for stype in ["falcon_light", "peregrine_med", "leviathan_heavy"]:
			var met: Dictionary = V40.calc_ship_route_metrics(stype, dist_l, grav_g, ref_p, var_c, v40)
			var s_card: PanelContainer = PanelContainer.new()
			s_card.add_theme_stylebox_override("panel", _style(Color("0b1826"), GOLD if stype == "peregrine_med" else Color("2b4a66"), 5, 5))
			v10_rockets_box.add_child(s_card)
			var s_hbox: HBoxContainer = HBoxContainer.new()
			s_hbox.add_theme_constant_override("separation", 6)
			s_card.add_child(s_hbox)
			var tex_path: String = str(ship_tex_map.get(stype, ""))
			if ResourceLoader.exists(tex_path):
				var s_icon := TextureRect.new()
				s_icon.texture = load(tex_path)
				s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				s_icon.custom_minimum_size = Vector2(28, 48)
				s_hbox.add_child(s_icon)
			var s_row: VBoxContainer = VBoxContainer.new()
			s_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_row.add_theme_constant_override("separation", 1)
			s_hbox.add_child(s_row)
			s_row.add_child(_label("%s (%dt · %.1f日)" % [str(met["name_zh"]), int(met["capacity_t"]), float(met["cycle_days"])], 11, GOLD if stype == "peregrine_med" else INK))
			s_row.add_child(_label("单趟%dCr(%.1f/t) | 贡献%dCr/船日" % [
				int(met["trip_cost_cr"]), float(met["cost_per_tonne_cr"]), int(met["ship_day_contribution_cr"])
			], 10, MUTED))
			var buy_s_btn: Button = _button("🚀 采购部署 (%d Cr)" % int(met["price_cr"]), _v40_cmd.bind("PurchaseShip", {"ship_type_id": stype, "mine_id": active_m_id}), 24)
			if stype == "peregrine_med":
				buy_s_btn.add_theme_stylebox_override("normal", _style(Color("4a3514"), GOLD, 4, 4))
			s_row.add_child(buy_s_btn)

	# 6. 更新右侧晨曦港四矿物双买方报价、销售策略切换与一键出售面板 (第 9.2–9.4 节)
	if is_instance_valid(v40_market_buttons_box):
		_clear(v40_market_buttons_box)
		var mkt: Dictionary = v40["market"]
		var min_defs: Dictionary = V40.get_config().get("minerals", {})
		if is_instance_valid(v10_market_status_label):
			var fee_r: float = 0.25 if ("C2" in (v40["research"]["unlocked"] as Array)) else 0.50
			v10_market_status_label.text = "晨曦港租用仓: %d/%d t (囤货费 %.2f Cr/t/日)" % [port_used, int(pinv_dawn.get("capacity_t", 500)), fee_r]
		var pol_short: Dictionary = {"direct": "直售", "target": "目标价", "priority": "优先合同"}
		for min_id in ["iron_titanium", "silicon_crystal", "energy_crystal", "phase_ore"]:
			var mdef: Dictionary = min_defs.get(min_id, {})
			var p_stock: int = int(pinv_dawn["minerals"].get(min_id, 0))
			var base_p: float = float(mdef.get("base_price_cr", 100))
			var ref_now: float = float(mkt["reference_prices"].get(min_id, base_p))
			var trend_tag: String = "▲" if ref_now > base_p * 1.02 else ("▼" if ref_now < base_p * 0.98 else "━")
			var reg_p: int = int(mkt["regular_quotes"].get(min_id, 95))
			var spot_p: int = int(mkt["spot_quotes"].get(min_id, 110))
			var spot_q: int = int(mkt["spot_quotas_left"].get(min_id, 100))
			var spot_max: int = maxi(1, int(mdef.get("daily_spot_quota_t", 100)))
			var cur_pol: String = str(pinv_dawn["sale_policy"].get(min_id, "direct"))
			var m_icon: String = str(mdef.get("icon", "•"))
			var m_col: Color = Color(str(mdef.get("color", "e5edf1")))

			var m_card_p: PanelContainer = PanelContainer.new()
			m_card_p.add_theme_stylebox_override("panel", _style(Color("0b1724"), m_col if p_stock > 0 else Color("223a4e"), 4, 4))
			v40_market_buttons_box.add_child(m_card_p)
			var m_vbox: VBoxContainer = VBoxContainer.new()
			m_vbox.add_theme_constant_override("separation", 2)
			m_card_p.add_child(m_vbox)

			var m_row: HBoxContainer = HBoxContainer.new()
			m_row.add_theme_constant_override("separation", 3)
			m_vbox.add_child(m_row)
			var m_lbl: Label = _label("%s%s %dt | %s常%d 高%d(%dt)" % [
				m_icon, str(mdef.get("name_zh", min_id)), p_stock, trend_tag, reg_p, spot_p, spot_q
			], 10, m_col if p_stock > 0 else INK)
			m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_row.add_child(m_lbl)
			var pol_b: Button = _button(str(pol_short.get(cur_pol, "直售")), _v40_cmd.bind("SetSalePolicy", {"port_id": "dawn_port", "mineral_id": min_id}), 22)
			m_row.add_child(pol_b)
			var sell_b: Button = _button("出售", _v40_cmd.bind("SellMineralNow", {"port_id": "dawn_port", "mineral_id": min_id, "buyer_type": "best"}), 22)
			m_row.add_child(sell_b)

			var q_bar: ProgressBar = ProgressBar.new()
			q_bar.custom_minimum_size.y = 4
			q_bar.max_value = float(spot_max)
			q_bar.value = clampf(float(spot_q), 0.0, float(spot_max))
			q_bar.show_percentage = false
			q_bar.add_theme_stylebox_override("background", _style(Color("050c14"), Color("162838"), 2, 0))
			q_bar.add_theme_stylebox_override("fill", _style(m_col, m_col, 2, 0))
			m_vbox.add_child(q_bar)

		var emg_on: bool = bool(v40.get("emergency_sale_authorized", false))
		var emg_b: Button = _button("🚨 应急自动出售授权: %s" % ("已开启" if emg_on else "已关闭"), _v40_cmd.bind("ToggleEmergencySale", {}), 24)
		v40_market_buttons_box.add_child(emg_b)
		var upg_port_b: Button = _button("🏭 扩建晨曦港租用仓 (+500t · 6000Cr)", _v40_cmd.bind("UpgradeFacility", {"kind": "port_warehouse"}), 24)
		v40_market_buttons_box.add_child(upg_port_b)
		var port_row_b: HBoxContainer = HBoxContainer.new()
		port_row_b.add_theme_constant_override("separation", 4)
		v40_market_buttons_box.add_child(port_row_b)
		var cur_pid: String = str(v40.get("active_port_id", "dawn_port"))
		var port_sw_b: Button = _button("⚓ 港口:%s" % ("晨曦港" if cur_pid == "dawn_port" else "赤曜港"), _v40_cmd.bind("SwitchActivePort", {}), 24)
		port_sw_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		port_row_b.add_child(port_sw_b)
		var hub_tr_b: Button = _button("🔄 中转干线联运", _v40_cmd.bind("TransferViaHub", {}), 24)
		hub_tr_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		port_row_b.add_child(hub_tr_b)

	# 7. 更新视图 2：破晓星域五大星团勘探、第 10.4 节项目投资对比与第 4.5 节商业竞拍卡片
	if is_instance_valid(v40_cluster_cards_box) and v10_active_screen == "starmap":
		_clear(v40_cluster_cards_box)
		for mid in v40["mines"]:
			var m_card_data: Dictionary = v40["mines"][mid]
			var cmp: Dictionary = V40.calc_expansion_comparison(v40, str(mid))
			var c_panel: PanelContainer = PanelContainer.new()
			c_panel.custom_minimum_size.x = 235
			var card_border: Color = CYAN if str(mid) == active_m_id else (GOLD if bool(m_card_data.get("license_owned", false)) else EDGE)
			c_panel.add_theme_stylebox_override("panel", _style(Color("0e1b28"), card_border, 5, 6))
			v40_cluster_cards_box.add_child(c_panel)
			var cv: VBoxContainer = VBoxContainer.new()
			cv.add_theme_constant_override("separation", 2)
			c_panel.add_child(cv)
			cv.add_child(_label("%s [%s]" % [str(m_card_data["name_zh"]), str(m_card_data["cluster_name_zh"])], 11, GOLD))
			cv.add_child(_label("储量 %d–%dt (%s) | L=%.1f\n起步需 %dCr | 回本≈%.1f日\n改派损 -%.0ft/日" % [
				int(m_card_data["estimate_min_t"]), int(m_card_data["estimate_max_t"]),
				str(m_card_data["confidence_zh"]), float(m_card_data["distance_l"]),
				int(cmp.get("initial_cash_needed_cr", 10800)), float(cmp.get("static_payback_days", 5.0)),
				float(cmp.get("reassignment_loss_t_day", 50.0))
			], 9, MUTED))
			if bool(m_card_data.get("license_owned", false)):
				cv.add_child(_button("⛏ 进入矿场", _v40_enter_mine.bind(str(mid)), 24))
			else:
				if int(m_card_data.get("survey_stage", 1)) < 2:
					cv.add_child(_button("🛰 轨道勘探(10日排他)", _v40_cmd.bind("OrbitalSurvey", {"mine_id": str(mid)}), 22))
				if str(m_card_data.get("license_type", "open")) == "commercial":
					var cur_b: int = int(m_card_data.get("current_bid_cr", m_card_data.get("license_price_cr", 9500)))
					var auto_b: int = int(m_card_data.get("max_auto_bid_cr", 0))
					cv.add_child(_button("✋ 出价冻结(%dCr)" % (cur_b + 1000), _v40_cmd.bind("PlaceBid", {"mine_id": str(mid), "bid_cr": cur_b + 1000}), 22))
					cv.add_child(_button("⚙ 自动上限:%s" % ("关" if auto_b <= 0 else "%dCr" % auto_b), _v40_cmd.bind("SetAutoBidLimit", {"mine_id": str(mid)}), 22))
					cv.add_child(_button("🔨 竞拍落槌结算", _v40_cmd.bind("SettleCommercialAuction", {"mine_id": str(mid)}), 22))
				else:
					cv.add_child(_button("📜 取得许可(%dCr)" % int(m_card_data["license_price_cr"]), _v40_cmd.bind("AcquireLicense", {"mine_id": str(mid)}), 24))

	# 8. 更新视图 3：集团总览大面板 (三口径财务、合同可行性、单步精炼、星港投资、20项研究、竞争财团与三大终局路线)
	if is_instance_valid(v40_corp_box) and v10_active_screen == "corp":
		# Renderer holds a per-section snapshot cache and updates only dirty panels.
		_refresh_v40_corporate_overview(v40, fin)

	if is_instance_valid(v10_mini_launch_view):
		v10_mini_launch_view.set("state", state)
		v10_mini_launch_view.queue_redraw()
	if is_instance_valid(v40_astra_hud_view):
		v40_astra_hud_view.set("state", state)
		v40_astra_hud_view.queue_redraw()


func _refresh_v40_corporate_overview(v40: Dictionary, fin: Dictionary) -> void:
	if not is_instance_valid(v40_corp_box):
		return
	# Preserve reading position when periodic model updates rebuild the panel.
	var scroll_view: ScrollContainer = v40_corp_box.get_parent() as ScrollContainer
	var old_scroll: int = scroll_view.scroll_vertical if scroll_view != null else 0
	if CorporateRenderer.render(self, v40, fin) and scroll_view != null:
		scroll_view.set_deferred("scroll_vertical", old_scroll)


func _v40_select_mine(mine_id: String) -> void:
	if state == null or state.challenge_id != "":
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	if not v40["mines"].has(mine_id):
		return
	v40["active_mine_id"] = mine_id
	var m_dict: Dictionary = v40["mines"].get(mine_id, {})
	status_text = "已切换至矿区：「%s」。" % str(m_dict.get("name_zh", mine_id))
	if is_instance_valid(bgm_player) and state.sound_enabled and not test_mode:
		bgm_player.stream = Synth.build_cluster_ambient_drone(str(m_dict.get("cluster_id", "dawn_frontier")))
		bgm_player.play()
	_cue("mining_hum")
	_persist() # Persist the selected V4 mine without requiring an economic tick.
	_refresh_all()


func _v40_enter_mine(mine_id: String) -> void:
	if state == null or state.challenge_id != "":
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return
	_v40_select_mine(mine_id)
	if not bool(mine.get("license_owned", false)):
		status_text = "该矿区尚未取得开采许可。请先在星图下方勘探并申请许可。"
		return
	_switch_v10_screen("mining")


func _v40_cmd(cmd_type: String, params: Dictionary) -> void:
	if state == null:
		return
	# A classic campaign owns its legacy ledger; do not issue V4 economic commands.
	if state.challenge_id != "":
		status_text = "经典战役请使用旧版配装与市场终端；不能混用 V4 经营命令。"
		_refresh_all()
		return
	var res: Dictionary = V40.execute_command(state, cmd_type, params)
	if bool(res.get("ok", false)):
		status_text = str(res.get("msg", "操作已执行。"))
		if cmd_type in ["ScanArea", "OrbitalSurvey"]:
			_cue("scan")
		elif cmd_type in ["BuildDrill", "PlaceMiningHead", "RelocateMiningHead"]:
			_cue("drill_hit")
		elif cmd_type in ["PurchaseShip", "LaunchPadDispatch"]:
			_cue("launch")
			if is_instance_valid(v10_mini_launch_view):
				v10_mini_launch_view.call("notify_launch")
			if is_instance_valid(v40_astra_hud_view):
				v40_astra_hud_view.call("notify_launch")
		elif cmd_type in ["AssignRoute", "TransferViaHub", "DeliverContract", "DeliverEndgame"]:
			_cue("load_done")
		elif cmd_type in ["SelectLaunchWindow", "OverhaulShip"]:
			_cue("window_lock")
		elif cmd_type in ["UpgradeFacility", "StartResearch", "InvestStarport", "ApplySurfacePreset"]:
			_cue("tech")
		else:
			_cue("cash")
		_persist()
	else:
		status_text = str(res.get("error", "操作未通过校验。"))
		_cue("stall")
	_v40_show_mining_message(status_text, not bool(res.get("ok", false)))
	if is_instance_valid(visual_director):
		visual_director.call("notify_operation", status_text, bool(res.get("ok", false)), cmd_type)
	if bool(res.get("ok", false)):
		if cmd_type == "LaunchPadDispatch":
			_play_dispatch_cinematic()
		elif cmd_type in ["ScanArea", "BuildDrill", "PlaceMiningHead", "UpgradeFacility", "RelocateMiningHead"]:
			if is_instance_valid(cross_section_view):
				cross_section_view.call("emit_visual_event", cmd_type)
	_refresh_all()


func _switch_v10_screen(screen_id: String) -> void:
	v10_active_screen = screen_id
	if is_instance_valid(v10_mining_stage):
		v10_mining_stage.visible = (screen_id == "mining")
	if is_instance_valid(v40_map_wrap):
		v40_map_wrap.visible = (screen_id == "starmap")
	if is_instance_valid(star_map):
		star_map.visible = screen_id == "starmap" and state.challenge_id != ""
	if is_instance_valid(v40_galaxy_map_view):
		v40_galaxy_map_view.visible = screen_id == "starmap" and state.challenge_id == ""
	if is_instance_valid(v10_full_launch_view):
		v10_full_launch_view.visible = (screen_id == "corp")
	if is_instance_valid(v40_astra_hud_view):
		v40_astra_hud_view.visible = (screen_id == "astra_hud")
	if is_instance_valid(v40_mining_inspector):
		v40_mining_inspector.visible = screen_id == "mining" and state.challenge_id == ""
	if is_instance_valid(v40_mining_feedback):
		v40_mining_feedback.visible = screen_id == "mining" and state.challenge_id == ""
	if screen_id == "astra_hud":
		_cue("recovery")
	if is_instance_valid(visual_director):
		visual_director.call("focus_scene", screen_id)
	_refresh_all()


func _v40_show_mining_message(message: String, is_error: bool = false) -> void:
	status_text = message
	if is_instance_valid(v40_mining_feedback):
		v40_mining_feedback.text = ("⚠ " if is_error else "✓ ") + message
		v40_mining_feedback.add_theme_color_override("font_color", RED if is_error else GREEN)


func _v40_select_mining_target(idx: int) -> void:
	if state == null or state.challenge_id != "":
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	var deposits: Array = mine.get("deposits", [])
	if idx < -1 or idx >= deposits.size():
		return
	v40_selected_mine_id = mine_id
	v40_selection_state = state
	v40_selected_deposit_idx = idx
	if is_instance_valid(cross_section_view):
		cross_section_view.set("selected_deposit_idx", idx)
		cross_section_view.queue_redraw()
	if is_instance_valid(v40_mining_inspector):
		v40_mining_inspector.call("update_target", state, mine_id, idx)
	if idx >= 0:
		_v40_show_mining_message("已选中「%s」，在右侧查看路线、费用及工期。" % str(deposits[idx].get("name_zh", "矿体")))
	else:
		_v40_show_mining_message("已清除采矿目标选择。")


func _v40_clear_mining_target() -> void:
	_v40_select_mining_target(-1)


func _v40_route_preview_selected(route_mode: String) -> void:
	if route_mode not in ["auto", "detour_soft", "direct_hard"]:
		return
	# Route preference is free to change; construction requires explicit approval.
	_v40_cmd("ToggleBoreRouteMode", {"mode": route_mode})


func _v40_mining_quote(cmd_type: String, params: Dictionary) -> Dictionary:
	if state == null or state.challenge_id != "":
		return {"ok": false, "error": "当前模式不支持 V4 矿场操作。"}
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mid: String = str(v40.get("active_mine_id", "dawn_1"))
	var mine: Dictionary = v40.get("mines", {}).get(mid, {})
	if mine.is_empty():
		return {"ok": false, "error": "矿区不存在。"}
	if not bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "请先在星图取得该矿区的开采许可。"}
	var cfg: Dictionary = V40.get_config().get("facilities", {})
	var cost: int = -1
	var detail: String = ""
	match cmd_type:
		"PlaceMiningHead":
			var head_index: int = int(params.get("deposit_index", -1))
			var head_deposits: Array = mine.get("deposits", [])
			if head_index < 0 or head_index >= head_deposits.size():
				return {"ok": false, "error": "请先选择一处有效矿体。"}
			var dep: Dictionary = head_deposits[head_index]
			if not bool(dep.get("revealed", false)):
				return {"ok": false, "error": "矿体尚未扫描揭示。"}
			if int(dep.get("remaining_t", 0)) <= 0:
				return {"ok": false, "error": "该矿体已采空。"}
			var plan: Dictionary = V40.calc_bore_plan(v40, mid, head_index)
			if not bool(plan.get("can_build", false)):
				return {"ok": false, "error": str(plan.get("error", "当前路线无法施工。"))}
			cost = int(plan["total_cost_cr"])
			detail = "在「%s」安装采掘头。\n路线：%s\n井道 %d Cr + 采掘头 %d Cr；总计 %d Cr。\n预计工期 %.1f 天，剩余储量 %d t。" % [
				str(dep.get("name_zh", "矿体")), str(plan["route_desc_zh"]), int(plan["bore_cost_cr"]),
				int(plan["head_cost_cr"]), cost, float(plan["work_days"]), int(dep["remaining_t"])]
		"ScanArea":
			cost = 0 if int(v40.get("free_scans_left", 0)) > 0 else int(cfg.get("ground_scan", {}).get("cost_cr", 300))
			var scan_index: int = int(params.get("deposit_index", -1))
			var scan_deposits: Array = mine.get("deposits", [])
			if scan_index >= 0:
				if scan_index >= scan_deposits.size():
					return {"ok": false, "error": "扫描目标无效。"}
				if bool(scan_deposits[scan_index].get("revealed", false)):
					return {"ok": false, "error": "矿体已经揭示。"}
				detail = "定点扫描「%s」：费用 %d Cr。" % [str(scan_deposits[scan_index].get("name_zh", "未知矿体")), cost]
			else:
				detail = "扫描该矿区下一处尚未揭示的矿体：费用 %d Cr。" % cost
		"BuildDrill":
			cost = int(cfg.get("drill_platform", {}).get("cost_cr", 8000))
			detail = "在当前矿区新增 1 座钻井平台，预估花费 %d Cr。" % cost
		"UpgradeFacility":
			var kind: String = str(params.get("kind", ""))
			match kind:
				"silo":
					cost = int(cfg.get("silo_expand", {}).get("cost_cr", 6000))
					detail = "当前矿区仓容 +500 t；花费 %d Cr。" % cost
				"platform":
					if bool(mine.get("platform_upgraded", false)):
						return {"ok": false, "error": "钻井平台已改造。"}
					cost = int(cfg.get("platform_upgrade", {}).get("cost_cr", 9000))
					detail = "平台单位提升能力从 60 t/日改造至 100 t/日；花费 %d Cr。" % cost
				"bore":
					if bool(mine.get("bore_upgraded", false)):
						return {"ok": false, "error": "主干井道已改造。"}
					cost = int(round(float(maxi(24, int(mine.get("bore_cells", 24))) * 100) * 0.60))
					detail = "主干井道输送上限扩容至 120 t/日；花费 %d Cr。" % cost
				_:
					return {"ok": false, "error": "不支持从矿场预览该升级。"}
		"RelocateMiningHead":
			detail = "自动选取可迁移采掘头并迁入已揭示矿脉；基础费 500 Cr，另按需要收取支线钻井费。最终金额以系统校验为准。"
		"SellEquipment":
			detail = "将拆售当前矿区一台采掘头，按规则收回 60% 购置残值。此操作不可直接撤销。"
		"CancelLastOrder":
			detail = "撤销最近一笔施工工单；退款取决于是否开工，已完成部分不退。"
		"ApplySurfacePreset":
			detail = "将现有地表设施升级到已保存的预设目标；最终费用由引擎实时校验。"
		"LaunchPadDispatch":
			detail = "按当前舰队和发射窗口执行运输调度；可能产生运输成本。"
		_:
			return {"ok": false, "error": "此操作暂未接入采矿确认面板。"}
	if cost >= 0 and V40.available_cash_cr(v40) < cost:
		return {"ok": false, "error": "可支配现金不足：当前 %d Cr，操作至少需要 %d Cr。" % [V40.available_cash_cr(v40), cost]}
	return {"ok": true, "cost_cr": cost, "description": detail, "mine_id": mid}


func _v40_request_mining_action(cmd_type: String, params: Dictionary) -> void:
	if not is_instance_valid(v40_mining_confirm_dialog):
		return
	var quote: Dictionary = _v40_mining_quote(cmd_type, params)
	if not bool(quote.get("ok", false)):
		_v40_show_mining_message(str(quote.get("error", "无法执行矿场操作。")), true)
		return
	var command_params: Dictionary = params.duplicate(true)
	command_params["mine_id"] = str(quote["mine_id"])
	v40_pending_mining_action = {
		"cmd_type": cmd_type,
		"params": command_params,
		"mine_id": str(quote["mine_id"]),
		"quoted_cost_cr": int(quote["cost_cr"]),
		"state_ref": state
	}
	v40_mining_confirm_dialog.dialog_text = "%s\n\n操作对象：%s\n确认后才会正式执行。" % [
		str(quote["description"]), str(quote["mine_id"])]
	_begin_editing()
	v40_mining_confirm_dialog.popup_centered()


func _v40_cancel_pending_mining_action() -> void:
	v40_pending_mining_action = {}
	_end_editing()


func _v40_confirm_pending_mining_action() -> void:
	var pending: Dictionary = v40_pending_mining_action.duplicate()
	v40_pending_mining_action = {}
	if pending.is_empty() or pending.get("state_ref") != state:
		_end_editing()
		return
	var v40: Dictionary = V40.ensure_v40_state(state)
	if str(v40.get("active_mine_id", "")) != str(pending.get("mine_id", "")):
		_v40_show_mining_message("矿区已变化；请重新选择并确认操作。", true)
		_end_editing()
		return
	var cmd_type: String = str(pending["cmd_type"])
	var command_params: Dictionary = pending["params"]
	# Reject a stale quote if money-relevant inputs changed before approval.
	var refreshed: Dictionary = _v40_mining_quote(cmd_type, command_params)
	if not bool(refreshed.get("ok", false)) or int(refreshed.get("cost_cr", -2)) != int(pending.get("quoted_cost_cr", -1)):
		_v40_show_mining_message("施工信息或价格已变化，请重新预览后确认。", true)
		_end_editing()
		return
	_v40_cmd(cmd_type, command_params)
	_end_editing()


func _v10_drill_next_shallow_pocket() -> void:
	# The left-side quick tool selects a target; it must not bypass confirmation.
	var v40: Dictionary = V40.ensure_v40_state(state)
	var mine: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
	var deps: Array = mine.get("deposits", [])
	for i in range(deps.size()):
		if bool(deps[i].get("revealed", false)) and int(deps[i].get("heads", 0)) == 0 and int(deps[i].get("remaining_t", 0)) > 0:
			_v40_select_mining_target(i)
			return
	_v40_select_mining_target(-1)
	_v40_show_mining_message("暂无适合直接建造的已揭示矿体，请先扫描。", true)


func _v10_expand_earth_warehouse() -> void:
	_v40_cmd("UpgradeFacility", {"kind": "port_warehouse"})


func _smart_dispatch_now() -> void:
	_v40_cmd("LaunchPadDispatch", {})


func _on_astra_overhaul_ship(ship_id: int) -> void:
	_v40_cmd("OverhaulShip", {"ship_id": ship_id})


func _on_astra_cycle_launch_window() -> void:
	_v40_cmd("SelectLaunchWindow", {})


func _dispatch_expendable_now() -> void:
	_smart_dispatch_now()


func _dispatch_reusable_now() -> void:
	_v40_cmd("PurchaseShip", {"ship_type_id": "peregrine_med"})


func _toggle_global_hold_policy() -> void:
	var v40: Dictionary = V40.ensure_v40_state(state)
	var pols: Dictionary = v40["port_inventories"]["dawn_port"]["sale_policy"]
	var cur: String = str(pols.get("iron_titanium", "direct"))
	var next_p: String = "target" if cur == "direct" else "direct"
	for k in pols:
		pols[k] = next_p
	status_text = "已切换晨曦港销售策略为：%s。" % ("目标价囤货出售 (承担 0.5 Cr/t/日 仓储费)" if next_p == "target" else "到港直接出售")
	_refresh_all()


func _dump_to_buyer(_side_key: String) -> void:
	var v40: Dictionary = V40.ensure_v40_state(state)
	var active_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
	var min_id: String = str(active_m.get("primary_mineral", "iron_titanium"))
	_v40_cmd("SellMineralNow", {"port_id": "dawn_port", "mineral_id": min_id, "buyer_type": "best"})


func _open_auction_hall() -> void:
	if state == null:
		return
	# V4 license auctions belong to V40DawnEngine, not the legacy cash auction.
	if state.challenge_id == "":
		_switch_v10_screen("starmap")
		return
	if not is_instance_valid(auction_hall_modal):
		return
	if board_window != null and board_window.visible:
		board_window.hide()
	resume_speed = speed
	speed = 0
	editing = true
	auction_hall_modal.call("open_hall", state, selected_star_id)


func _on_auction_updated(msg: String, cue_name: String) -> void:
	status_text = msg
	if cue_name != "":
		_cue(cue_name)
	_persist()
	_refresh_all()


func _on_auction_closed() -> void:
	if editing:
		editing = false
		speed = resume_speed
	_refresh_all()
