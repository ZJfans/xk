extends RefCounted

const CrossSection = preload("res://scripts/ui/planet_cross_section.gd")
const AuctionHall = preload("res://scripts/ui/auction_hall.gd")
const LaunchView = preload("res://scripts/ui/launch_recovery_view.gd")

## 《星矿大亨 Rocket Prospectors》V4.0 · 严格遵循第 3.2 & 16.2 章标准界面布局：
## - 顶栏：公司现金、冻结金额入口、游戏时间、速度 + 三大主界面统一导航（1.矿场 / 2.星图 / 3.集团总览）
## - 左侧 (158px)：扫描、钻井、采掘头、采掘头迁移(500Cr)、主井/平台扩容、仓储与矿区运行/暂停/封存/共享船池工具栏
## - 中央 (约 66% 可用面积)：96×48 逻辑格二维矿场剖面 / 破晓星域星图 / 集团总览大面板
## - 右侧 (314px)：当前主要瓶颈与下一班运输、火箭起降实况窗、三船型采购调配与晨曦港销售策略/合同交付
## - 底部 (46px)：实际产量、矿仓占用、预计运输能力与已知矿体剩余可采寿命（含 15日/5日预警）

static func mount(ui: Control) -> void:
	var old_background: Node = ui.get_child(0)
	if old_background is CanvasItem:
		(old_background as CanvasItem).hide()
	var board: Control = Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(board)
	var background: PanelContainer = PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", ui._style(Color("050a12"), Color("162636"), 0, 0))
	board.add_child(background)

	# =========================================================================
	# 1. 顶栏 (52px)：公司现金、冻结金额入口、三大界面切换、游戏时间与速度 (第 16.2 节)
	# =========================================================================
	var top: PanelContainer = PanelContainer.new()
	board.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 52
	top.add_theme_stylebox_override("panel", ui._style(Color("0a121c"), Color("1f3347"), 0, 8))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)

	for label in [ui.map_label, ui.cash_label, ui.debt_label, ui.port_label]:
		label.reparent(row)
		label.add_theme_font_size_override("font_size", 13)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# 三大主要界面导航 (第 3.2 & 16.2 节：矿场 / 星图 / 集团总览)
	var tab_mine: Button = ui._button("⛏ 1.矿场剖面", ui._switch_v10_screen.bind("mining"), 30)
	row.add_child(tab_mine)
	ui.v10_tab_mining_btn = tab_mine

	var tab_map: Button = ui._button("🗺 2.破晓星图", ui._switch_v10_screen.bind("starmap"), 30)
	row.add_child(tab_map)
	ui.v10_tab_map_btn = tab_map

	var tab_corp: Button = ui._button("🏢 3.集团总览(研究/合同/精炼)", ui._switch_v10_screen.bind("corp"), 30)
	row.add_child(tab_corp)
	ui.v10_tab_launch_btn = tab_corp

	var tab_astra: Button = ui._button("🚀 4.发射与回收(Astra)", ui._switch_v10_screen.bind("astra_hud"), 30)
	row.add_child(tab_astra)
	ui.v40_tab_astra_btn = tab_astra

	ui.day_label.reparent(row)
	ui.day_label.add_theme_font_size_override("font_size", 15)
	for item in [["暂停", 0], ["1×", 1], ["2×", 2], ["4×", 4]]:
		row.add_child(ui._button(item[0], ui._set_speed.bind(item[1]), 28))
	row.add_child(ui._button("+半日", ui._advance_one, 28))

	# 次级通知与瓶颈关注条 (28px，第 16.5 节：信息/关注/紧急分级合并通知)
	var hint: PanelContainer = PanelContainer.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 52
	hint.offset_bottom = 80
	hint.add_theme_stylebox_override("panel", ui._style(Color("0d1722"), Color("1b2d3e"), 0, 4))
	board.add_child(hint)
	ui.tutorial_bar = hint
	var hint_row: HBoxContainer = HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 10)
	hint.add_child(hint_row)
	ui.tutorial_label.reparent(hint_row)
	ui.tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.tutorial_label.add_theme_font_size_override("font_size", 12)
	ui.objective_label.reparent(hint_row)
	if ui.get("complexity_toggle_btn") != null:
		ui.complexity_toggle_btn.visible = false
	ui.tutorial_button.reparent(hint_row)

	# =========================================================================
	# 2. 左侧工具栏 (158px 宽，第 16.2 节：扫描、钻井、采掘头、迁移、仓储等当前工具)
	# =========================================================================
	var left_dock: PanelContainer = PanelContainer.new()
	board.add_child(left_dock)
	left_dock.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left_dock.offset_left = 6
	left_dock.offset_top = 84
	left_dock.offset_right = 164
	left_dock.offset_bottom = -52
	left_dock.add_theme_stylebox_override("panel", ui._style(Color("0b141f"), Color("22384c"), 6, 8))

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_dock.add_child(left_scroll)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left_vbox)

	left_vbox.add_child(ui._label("📍 旗下矿区切换", 12, Color("f2b55c")))
	var zone_switch_col: VBoxContainer = VBoxContainer.new()
	zone_switch_col.add_theme_constant_override("separation", 4)
	left_vbox.add_child(zone_switch_col)
	ui.v10_zone_selector_box = zone_switch_col

	left_vbox.add_child(ui._label("🛠 矿场建设工具", 12, Color("49d6e4")))
	left_vbox.add_child(ui._button("📡 地面扫描(300Cr)", ui._v40_cmd.bind("ScanArea", {}), 27))
	left_vbox.add_child(ui._button("🏗 建钻井台(8000)", ui._v40_cmd.bind("BuildDrill", {}), 27))
	left_vbox.add_child(ui._button("⛏ 装采掘头(2000+)", ui._v10_drill_next_shallow_pocket, 27))
	left_vbox.add_child(ui._button("🔀 迁移采掘头(500)", ui._v40_cmd.bind("RelocateMiningHead", {}), 26))
	left_vbox.add_child(ui._button("📐 路线(绕行/直穿)", ui._v40_cmd.bind("ToggleBoreRouteMode", {}), 26))
	left_vbox.add_child(ui._button("↩ 撤单退款(100%)", ui._v40_cmd.bind("CancelLastOrder", {}), 26))
	left_vbox.add_child(ui._button("⬆ 平台改造(9000)", ui._v40_cmd.bind("UpgradeFacility", {"kind": "platform"}), 27))
	left_vbox.add_child(ui._button("⬆ 主井扩容(120t)", ui._v40_cmd.bind("UpgradeFacility", {"kind": "bore"}), 27))
	left_vbox.add_child(ui._button("📦 矿仓扩容(6000)", ui._v40_cmd.bind("UpgradeFacility", {"kind": "silo"}), 27))

	left_vbox.add_child(ui._label("⚙ 运营状态与回收", 12, Color("83c7a6")))
	left_vbox.add_child(ui._button("▶ 正常生产", ui._v40_cmd.bind("SetMineStatus", {"status": "running"}), 25))
	left_vbox.add_child(ui._button("⏸ 暂停(25%维护)", ui._v40_cmd.bind("SetMineStatus", {"status": "paused"}), 25))
	left_vbox.add_child(ui._button("🔒 封存(15Cr/日)", ui._v40_cmd.bind("SetMineStatus", {"status": "mothballed"}), 25))
	left_vbox.add_child(ui._button("♻ 拆售采掘头(60%)", ui._v40_cmd.bind("SellEquipment", {}), 25))
	left_vbox.add_child(ui._button("🌐 共享船池开关", ui._v40_cmd.bind("ToggleSharedFleetPool", {}), 24))
	left_vbox.add_child(ui._button("📋 存地表预设", ui._v40_cmd.bind("SaveSurfacePreset", {}), 24))
	left_vbox.add_child(ui._button("⚡ 应用地表预设", ui._v40_cmd.bind("ApplySurfacePreset", {}), 24))

	# 隐藏旧版已归并按钮，保持引用有效
	ui.scan_button.visible = false
	if ui.get("deep_drill_button") != null:
		ui.deep_drill_button.visible = false
	if ui.get("pipe_upgrade_button") != null:
		ui.pipe_upgrade_button.visible = false
	if ui.get("discover_star_button") != null:
		ui.discover_star_button.visible = false

	# =========================================================================
	# 3. 中央主舞台 (约 66% 可用面积，第 16.2 节：中央用于矿场 / 星图 / 集团总览)
	# =========================================================================
	var main_stage: Control = Control.new()
	main_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_stage.offset_left = 170
	main_stage.offset_top = 84
	main_stage.offset_right = -324
	main_stage.offset_bottom = -52
	board.add_child(main_stage)
	ui.v10_main_stage = main_stage

	# 视图 1：矿场剖面主视图
	var mining_stage_card: PanelContainer = PanelContainer.new()
	mining_stage_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mining_stage_card.add_theme_stylebox_override("panel", ui._style(Color("08131d"), Color("254057"), 6, 8))
	main_stage.add_child(mining_stage_card)
	ui.v10_mining_stage = mining_stage_card

	var mining_vbox: VBoxContainer = VBoxContainer.new()
	mining_vbox.add_theme_constant_override("separation", 5)
	mining_stage_card.add_child(mining_vbox)

	var m_top_row: HBoxContainer = HBoxContainer.new()
	mining_vbox.add_child(m_top_row)
	ui.board_title = ui._label("晨曦一号矿区", 16, Color("f2b55c"))
	ui.board_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_top_row.add_child(ui.board_title)
	ui.board_inventory = ui._label("", 13, Color("9adce8"))
	m_top_row.add_child(ui.board_inventory)

	ui.board_stock = ProgressBar.new()
	ui.board_stock.custom_minimum_size.y = 7
	ui.board_stock.show_percentage = false
	ui.board_stock.add_theme_stylebox_override("fill", ui._style(Color("4cc9dc"), Color("4cc9dc"), 2, 0))
	mining_vbox.add_child(ui.board_stock)

	var cs_view: Control = CrossSection.new()
	cs_view.cross_section_action.connect(ui._on_cross_section_action)
	cs_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cs_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mining_vbox.add_child(cs_view)
	ui.cross_section_view = cs_view

	ui.star_details.visible = false

	# 视图 2：破晓星域星图与勘探/许可视图
	var map_wrap: VBoxContainer = VBoxContainer.new()
	map_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_wrap.add_theme_constant_override("separation", 6)
	map_wrap.visible = false
	main_stage.add_child(map_wrap)
	ui.v40_map_wrap = map_wrap

	ui.star_map.reparent(map_wrap)
	ui.star_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.star_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.star_map.custom_minimum_size = Vector2(400, 260)

	var cluster_bar: PanelContainer = PanelContainer.new()
	cluster_bar.add_theme_stylebox_override("panel", ui._style(Color("0b1622"), Color("2b4860"), 6, 8))
	map_wrap.add_child(cluster_bar)
	var cluster_vbox: VBoxContainer = VBoxContainer.new()
	cluster_vbox.add_theme_constant_override("separation", 4)
	cluster_bar.add_child(cluster_vbox)
	cluster_vbox.add_child(ui._label("🌌 破晓星域五大星团 · 轨道勘探(10日发现者排他期) 与 采矿许可购买/竞拍", 13, Color("f2b55c")))
	var cluster_cards_row: HBoxContainer = HBoxContainer.new()
	cluster_cards_row.add_theme_constant_override("separation", 6)
	cluster_vbox.add_child(cluster_cards_row)
	ui.v40_cluster_cards_box = cluster_cards_row

	# 视图 3：集团总览大面板 (第 3.2, 9, 10, 12, 14, 15.6 章：合同、20项研究、单步精炼、星港投资、三口径财务与终局工程)
	var corp_panel: PanelContainer = PanelContainer.new()
	corp_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corp_panel.add_theme_stylebox_override("panel", ui._style(Color("09131e"), Color("28445c"), 6, 10))
	corp_panel.visible = false
	main_stage.add_child(corp_panel)
	ui.v10_full_launch_view = corp_panel

	var corp_scroll: ScrollContainer = ScrollContainer.new()
	corp_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corp_panel.add_child(corp_scroll)
	var corp_vbox: VBoxContainer = VBoxContainer.new()
	corp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corp_vbox.add_theme_constant_override("separation", 8)
	corp_scroll.add_child(corp_vbox)
	ui.v40_corp_box = corp_vbox

	# =========================================================================
	# 4. 右侧详情与物流交易栏 (314px 宽，第 16.2 节：瓶颈诊断、下一班运输、船队采购与晨曦港交易)
	# =========================================================================
	var side: PanelContainer = PanelContainer.new()
	board.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -318
	side.offset_top = 84
	side.offset_right = -6
	side.offset_bottom = -52
	side.add_theme_stylebox_override("panel", ui._style(Color("0b141f"), Color("264057"), 6, 8))
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	side_scroll.add_child(body)

	body.add_child(ui._label("🎬 起降与运输实况 (2.5D 演出层)", 12, Color("49d6e4")))
	var astra_full: Control = LaunchView.new()
	astra_full.set("compact_mode", false)
	astra_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	astra_full.visible = false
	astra_full.trigger_quick_dispatch.connect(ui._smart_dispatch_now)
	astra_full.trigger_ship_overhaul.connect(ui._on_astra_overhaul_ship)
	astra_full.trigger_launch_window_cycle.connect(ui._on_astra_cycle_launch_window)
	main_stage.add_child(astra_full)
	ui.v40_astra_hud_view = astra_full

	var mini_launch: Control = LaunchView.new()
	mini_launch.set("compact_mode", true)
	mini_launch.custom_minimum_size = Vector2(292, 148)
	mini_launch.request_fullscreen_hud.connect(ui._switch_v10_screen.bind("astra_hud"))
	body.add_child(mini_launch)
	ui.v10_mini_launch_view = mini_launch

	# 三类船型采购与航线比较 (第 8.2 & 8.3 & 11.5 节：隼式轻型 / 游隼中型 / 巨鲸重型)
	var ship_card: PanelContainer = PanelContainer.new()
	ship_card.add_theme_stylebox_override("panel", ui._style(Color("101e2b"), Color("345772"), 5, 6))
	body.add_child(ship_card)
	var ship_vbox: VBoxContainer = VBoxContainer.new()
	ship_vbox.add_theme_constant_override("separation", 4)
	ship_card.add_child(ship_vbox)
	ship_vbox.add_child(ui._label("🚀 船队采购与每船日贡献 (第 8 章)", 12, Color("f2b55c")))
	var rockets_box: VBoxContainer = VBoxContainer.new()
	rockets_box.add_theme_constant_override("separation", 4)
	ship_vbox.add_child(rockets_box)
	ui.v10_rockets_box = rockets_box

	# 晨曦贸易港四矿物行情与销售/合同交付 (第 9 章)
	var trade_card: PanelContainer = PanelContainer.new()
	trade_card.add_theme_stylebox_override("panel", ui._style(Color("0e1d2b"), Color("2f526b"), 5, 6))
	body.add_child(trade_card)
	var trade_vbox: VBoxContainer = VBoxContainer.new()
	trade_vbox.add_theme_constant_override("separation", 4)
	trade_card.add_child(trade_vbox)
	trade_vbox.add_child(ui._label("📈 晨曦港需求与销售策略 (常规600t/高价100t)", 12, Color("83c7a6")))
	ui.v10_market_status_label = ui._label("", 11, Color("9adce8"))
	ui.v10_market_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_vbox.add_child(ui.v10_market_status_label)

	var sell_grid: VBoxContainer = VBoxContainer.new()
	sell_grid.add_theme_constant_override("separation", 4)
	trade_vbox.add_child(sell_grid)
	ui.v40_market_buttons_box = sell_grid

	ui.once_dispatch_btn = Button.new()
	ui.smart_dispatch_btn = Button.new()
	ui.hold_policy_btn = Button.new()
	ui.left_dump_btn = Button.new()
	ui.right_dump_btn = Button.new()

	# =========================================================================
	# 5. 底部遥测栏 (46px，第 16.2 节：底部显示实际产量、矿仓占用、预计运输能力与矿体寿命)
	# =========================================================================
	var bottom: PanelContainer = PanelContainer.new()
	board.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -46
	bottom.add_theme_stylebox_override("panel", ui._style(Color("0a121c"), Color("1f3347"), 0, 6))
	var navigation: HBoxContainer = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	bottom.add_child(navigation)

	ui.v40_bottom_telemetry_label = ui._label("实际产量: 40 t/日  |  矿仓占用: 60/300 t  |  预计运力: 50 t/日  |  已知矿体寿命: 23.8 日", 13, Color("49d6e4"))
	ui.v40_bottom_telemetry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(ui.v40_bottom_telemetry_label)

	navigation.add_child(ui._button("🔨 商业矿区竞拍", ui._open_auction_hall, 32))
	navigation.add_child(ui._button("💳 授信借贷(+10000Cr)", ui._v40_cmd.bind("BorrowLoan", {"amount_cr": 10000}), 32))
	navigation.add_child(ui._button("还款(-10000Cr)", ui._v40_cmd.bind("RepayLoan", {"amount_cr": 10000}), 32))
	navigation.add_child(ui._button("💾 存档/设置", ui._open_menu_tab.bind(3), 32))
	navigation.add_child(ui._button("🏠 主菜单", ui._show_front_menu_again, 32))
	ui.speed_label.reparent(navigation)

	# 挂载竞拍大厅
	var auction_modal: Control = AuctionHall.new()
	auction_modal.auction_updated.connect(ui._on_auction_updated)
	auction_modal.close_requested.connect(ui._on_auction_closed)
	ui.add_child(auction_modal)
	ui.auction_hall_modal = auction_modal

	ui.board_window = Window.new()
	ui.board_window.title = "《星矿大亨 V4.0》旧版兼容与存档终端"
	ui.board_window.size = Vector2i(920, 700)
	ui.board_window.min_size = Vector2i(680, 500)
	ui.board_window.transient = true
	ui.board_window.exclusive = true
	ui.board_window.visible = false
	ui.board_window.close_requested.connect(ui._close_board_panel)
	ui.add_child(ui.board_window)
	ui.board_window.hide()
	ui.board_tabs = TabContainer.new()
	ui.board_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.board_window.add_child(ui.board_tabs)
	for tab_name in ["配装兼容", "市场兼容", "船队日志", "设置与存档", "科技兼容", "生涯成就"]:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.board_tabs.add_child(scroll)
		var content: VBoxContainer = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		scroll.add_child(content)
	ui.mission_panel.reparent(ui.board_tabs.get_child(0).get_child(0))
	ui.status_label.reparent(ui.board_tabs.get_child(0).get_child(0))
	ui.market_panel.reparent(ui.board_tabs.get_child(1).get_child(0))
	ui.fleet_box.get_parent().get_parent().reparent(ui.board_tabs.get_child(2).get_child(0))
	ui.log_label.get_parent().get_parent().reparent(ui.board_tabs.get_child(2).get_child(0))
	var management: Node = ui.board_tabs.get_child(3).get_child(0)
	ui.scenario_options.reparent(management)
	for pair in [["新开采季", ui._ask_new_season], ["读取存档", ui._load_saved], ["最近结算", ui._show_recent_settlement], ["提前结算", ui._ask_finish]]:
		management.add_child(ui._button(pair[0], pair[1], 40))
	ui.auto_pause_check.reparent(management)
	ui.sound_check.reparent(management)
	if ui.get("settings_box") != null:
		ui.settings_box.reparent(management)
	if ui.get("tech_box") != null:
		ui.tech_box.reparent(ui.board_tabs.get_child(4).get_child(0))
	if ui.get("achievements_box") != null:
		ui.achievements_box.reparent(ui.board_tabs.get_child(5).get_child(0))
