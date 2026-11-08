class_name AuctionHallModal
extends PanelContainer

## 《星矿大亨 Rocket Prospectors》v6.0 · 对标《石油大亨 (Turmoil)》双舞台实时举牌拍卖大厅
## 1. 【银河星区采矿特许权竞拍 (3×4 地质热力网格)】：
##    12 个高产星区地块（含矿热力指数 42~98），与三位 AI 财团大佬同台实时举牌抢地！
##    拍下地块立即为我方矿星注入 +10~+28 箱高纯度储量、+3 箱现矿，86 分以上富矿区直接赠送 1 座自动钻机！
## 2. 【地球博卡星舰母港 100% 控股权竞拍 (Mayor Stock Auction)】：
##    每次敲钟开拍 5% 母港股权，四方实时喊价举牌，持股达 50% 晋升母港执政官（全矿石售价永久 +15%）！

signal auction_updated(message: String, sound_cue: String)
signal close_requested()

const Tycoon = preload("res://scripts/core/galactic_tycoon.gd")
const Rules = preload("res://scripts/core/mission_rules.gd")
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")

const INK: Color = Color("e6f0f6")
const MUTED: Color = Color("90a6b6")
const GOLD: Color = Color("f2b55c")
const GREEN: Color = Color("83c7a6")
const RED: Color = Color("f08c82")
const CYAN: Color = Color("49d6e4")
const PURPLE: Color = Color("b888f8")

var state: GameState
var preferred_star_id: String = ""

# 拍卖实时状态机
var active_mode: String = "idle" # "idle", "plot", "stock"
var active_plot_idx: int = -1
var current_bid_cents: int = 0
var highest_bidder: String = "" # "player", "rex", "victoria", "otto"
var rival_max_willing: Dictionary = {"rex": 0, "victoria": 0, "otto": 0}
var gavel_timer: float = 0.0
var gavel_duration: float = 3.2
var ai_think_timer: float = 0.0
var auctioneer_speech: String = "请从左侧 3×4 星区热力网格点选一块富矿区，或点击右侧「敲钟开拍 5% 母港股权」启动竞价！"

# UI 节点引用
var header_cash_label: Label
var share_bar_label: Label
var grid_container: GridContainer
var stage_title_label: Label
var stage_bid_label: Label
var stage_speech_label: Label
var countdown_bar: ProgressBar
var bidder_cards: Dictionary = {}
var bid_plus20_btn: Button
var bid_plus60_btn: Button
var instant_gavel_btn: Button
var start_stock_btn: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_build_ui()
	set_process(true)


func open_hall(game_state: GameState, selected_sid: String) -> void:
	state = game_state
	preferred_star_id = selected_sid
	Tycoon.ensure_auction_plots(state)
	visible = true
	if active_mode == "idle":
		auctioneer_speech = "🔨 欢迎来到星际矿业交易所！点击左侧高热力星区地块（推荐热力 80+ 琥珀/紫晶区）即可举牌开拍！"
	refresh_ui()


func _process(delta: float) -> void:
	if not visible or state == null or active_mode == "idle":
		return
	gavel_timer -= delta
	ai_think_timer -= delta
	if is_instance_valid(countdown_bar):
		countdown_bar.max_value = gavel_duration
		countdown_bar.value = clampf(gavel_timer, 0.0, gavel_duration)

	if ai_think_timer <= 0.0 and gavel_timer > 0.25:
		ai_think_timer = randf_range(0.55, 0.95)
		_try_ai_counter_bid()

	if gavel_timer <= 0.0:
		_finalize_gavel()


func _style(bg: Color, border: Color, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_top = 2
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 4
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	return box


func _label(txt: String, fsize: int = 14, col: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	return l


func _button(txt: String, cb: Callable, min_h: int = 36) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size.y = min_h
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.09, 0.92), Color("2b4a64"), 0, 22))

	var center_wrap: MarginContainer = MarginContainer.new()
	center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_wrap.add_theme_constant_override("margin_left", 36)
	center_wrap.add_theme_constant_override("margin_right", 36)
	center_wrap.add_theme_constant_override("margin_top", 24)
	center_wrap.add_theme_constant_override("margin_bottom", 24)
	add_child(center_wrap)

	var main_card: PanelContainer = PanelContainer.new()
	main_card.add_theme_stylebox_override("panel", _style(Color("0a1520"), GOLD, 8, 16))
	center_wrap.add_child(main_card)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_card.add_child(root_vbox)

	# 顶部标题栏
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(top_row)

	var title_lbl: Label = _label("🔨 星际采矿特许权 & 母港控股权实时拍卖大厅 (TURMOIL LIVE AUCTION HALL)", 20, GOLD)
	top_row.add_child(title_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	header_cash_label = _label("可用竞拍资金：$2,000", 17, GREEN)
	top_row.add_child(header_cash_label)

	var close_btn: Button = _button("✕ 返回深空星图", func() -> void:
		active_mode = "idle"
		visible = false
		close_requested.emit()
	, 34)
	top_row.add_child(close_btn)

	# 股东持股比例横幅
	var share_panel: PanelContainer = PanelContainer.new()
	share_panel.add_theme_stylebox_override("panel", _style(Color("0f2030"), Color("2e4d66"), 6, 8))
	root_vbox.add_child(share_panel)
	share_bar_label = _label("", 14, CYAN)
	share_panel.add_child(share_bar_label)

	# 中央双栏：左侧 3×4 星区地块热力网格 + 右侧实时举牌竞价台
	var split_row: HBoxContainer = HBoxContainer.new()
	split_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(split_row)

	# 左侧：3×4 星区地质热力图
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.35
	left_panel.add_theme_stylebox_override("panel", _style(Color("08111a"), Color("243b4f"), 6, 12))
	split_row.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	left_vbox.add_child(_label("🗺 第一舞台：银河星区富矿采矿权网格（点击任意未拍出地块发起举牌竞标）", 15, GOLD))
	left_vbox.add_child(_label("提示：热力指数越高，拍下后注入对应星球的矿石储量越多；热力 ≥86 的传奇地块额外免费附赠 1 座星表自动钻机！", 12, MUTED))

	grid_container = GridContainer.new()
	grid_container.columns = 4
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("h_separation", 8)
	grid_container.add_theme_constant_override("v_separation", 8)
	left_vbox.add_child(grid_container)

	# 右侧：实时举牌拍卖师讲台与四方大佬席位
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.add_theme_stylebox_override("panel", _style(Color("0d1824"), Color("35546e"), 6, 12))
	split_row.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	right_vbox.add_child(_label("🔔 第二舞台：实时举牌竞价席 & 母港控股权争夺", 15, GOLD))

	var podium_box: PanelContainer = PanelContainer.new()
	podium_box.add_theme_stylebox_override("panel", _style(Color("132436"), GOLD, 6, 10))
	right_vbox.add_child(podium_box)
	var podium_vbox: VBoxContainer = VBoxContainer.new()
	podium_vbox.add_theme_constant_override("separation", 6)
	podium_box.add_child(podium_vbox)

	stage_title_label = _label("当前拍品：待选择拍品", 15, GOLD)
	podium_vbox.add_child(stage_title_label)

	stage_bid_label = _label("当前最高出价：—", 16, GREEN)
	podium_vbox.add_child(stage_bid_label)

	countdown_bar = ProgressBar.new()
	countdown_bar.custom_minimum_size.y = 10
	countdown_bar.show_percentage = false
	countdown_bar.add_theme_stylebox_override("fill", _style(GOLD, GOLD, 3, 0))
	podium_vbox.add_child(countdown_bar)

	stage_speech_label = _label(auctioneer_speech, 12, CYAN)
	stage_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_speech_label.custom_minimum_size.y = 38
	podium_vbox.add_child(stage_speech_label)

	# 四位竞拍人席位卡片
	var bidders_grid: GridContainer = GridContainer.new()
	bidders_grid.columns = 2
	bidders_grid.add_theme_constant_override("h_separation", 8)
	bidders_grid.add_theme_constant_override("v_separation", 8)
	right_vbox.add_child(bidders_grid)

	var bidder_defs: Array[Dictionary] = [
		{"id": "player", "name": "👑 您 (破晓星域开拓集团)", "tag": "晨曦贸易港主承运商", "col": GREEN},
		{"id": "rex", "name": "🔴 赤曜矿业 (泰坦资源)", "tag": "竞拍积极 · 偏好高估值富矿区", "col": RED},
		{"id": "victoria", "name": "🔵 星环运输 (星际航运)", "tag": "干线扩张 · 重视规模与运力", "col": CYAN},
		{"id": "otto", "name": "🟠 银穹资本 (量子投机)", "tag": "择机囤货 · 偏爱高溢价矿区", "col": GOLD}
	]
	for bdef in bidder_defs:
		var bcard: PanelContainer = PanelContainer.new()
		bcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bcard.add_theme_stylebox_override("panel", _style(Color("09131d"), Color("22384a"), 5, 8))
		var bvbox: VBoxContainer = VBoxContainer.new()
		bvbox.add_theme_constant_override("separation", 3)
		bcard.add_child(bvbox)
		var bname: Label = _label(str(bdef["name"]), 13, bdef["col"])
		var bcap_lbl: Label = _label("资金池评估中...", 10, CYAN)
		var bbar: ProgressBar = ProgressBar.new()
		bbar.custom_minimum_size.y = 6
		bbar.max_value = 100.0
		bbar.value = 60.0
		bbar.show_percentage = false
		bbar.add_theme_stylebox_override("background", _style(Color("050b12"), Color("1b3144"), 2, 0))
		bbar.add_theme_stylebox_override("fill", _style(bdef["col"], bdef["col"], 2, 0))
		var bstatus: Label = _label(str(bdef["tag"]), 11, MUTED)
		bvbox.add_child(bname)
		bvbox.add_child(bcap_lbl)
		bvbox.add_child(bbar)
		bvbox.add_child(bstatus)
		bidders_grid.add_child(bcard)
		bidder_cards[str(bdef["id"])] = {"panel": bcard, "cap_lbl": bcap_lbl, "bar": bbar, "status": bstatus, "color": bdef["col"]}

	# 玩家举牌操作按钮组
	var action_row1: HBoxContainer = HBoxContainer.new()
	action_row1.add_theme_constant_override("separation", 8)
	right_vbox.add_child(action_row1)

	bid_plus20_btn = _button("✋ 举牌加价 (+$20)", func() -> void: _player_raise_bid(2000), 40)
	bid_plus20_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_plus20_btn.add_theme_stylebox_override("normal", _style(Color("1e4638"), GREEN, 5))
	action_row1.add_child(bid_plus20_btn)

	bid_plus60_btn = _button("⚡ 霸气截胡 (+$60)", func() -> void: _player_raise_bid(6000), 40)
	bid_plus60_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_plus60_btn.add_theme_stylebox_override("normal", _style(Color("5c4220"), GOLD, 5))
	action_row1.add_child(bid_plus60_btn)

	instant_gavel_btn = _button("🔨 立即落槌定音", _finalize_gavel, 36)
	right_vbox.add_child(instant_gavel_btn)

	var sep_lbl: Label = _label("—— 或者发起《石油大亨》经典市政厅股权竞拍 ——", 12, MUTED)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(sep_lbl)

	start_stock_btn = _button("🏛 敲钟开拍下一批 5% 地球星舰母港永久控股权", _start_stock_auction, 42)
	start_stock_btn.add_theme_stylebox_override("normal", _style(Color("2b2146"), PURPLE, 5))
	right_vbox.add_child(start_stock_btn)


func _start_plot_auction(plot_idx: int) -> void:
	if state == null:
		return
	var plots: Array = Tycoon.ensure_auction_plots(state)
	if plot_idx < 0 or plot_idx >= plots.size():
		return
	var plot: Dictionary = plots[plot_idx]
	if str(plot.get("owner", "")) != "":
		return

	active_mode = "plot"
	active_plot_idx = plot_idx
	current_bid_cents = int(plot["base_price_cents"])
	var rich: int = int(plot["richness"])
	var is_crystal: bool = str(plot["ore"]) == "crystal"

	# 计算三位 AI 大亨对该地块的心理最高出价底线
	rival_max_willing["rex"] = current_bid_cents + (rich - 35) * (95 if not is_crystal else 55) + randi_range(-1500, 2500)
	rival_max_willing["victoria"] = current_bid_cents + (rich - 35) * (105 if is_crystal else 60) + randi_range(-1000, 3500)
	rival_max_willing["otto"] = current_bid_cents + (rich - 40) * 70 + randi_range(-2000, 2000)

	# 如果玩家现金充裕，默认玩家率先举牌起拍价！
	if state.cash_cents >= current_bid_cents:
		highest_bidder = "player"
		auctioneer_speech = "🔔 「%s·%s (热力 %d)」开拍！您率先举牌应价 %s！三位财团正在评估是否加价..." % [
			str(plot["code"]), str(plot["name"]), rich, Rules.money(current_bid_cents)
		]
	else:
		highest_bidder = "rex" if not is_crystal else "victoria"
		auctioneer_speech = "🔔 「%s·%s」开拍！竞争对手率先举牌 %s！" % [
			str(plot["code"]), str(plot["name"]), Rules.money(current_bid_cents)
		]

	gavel_timer = gavel_duration
	ai_think_timer = 0.75
	auction_updated.emit("开始竞拍星区「%s·%s」" % [str(plot["code"]), str(plot["name"])], "order")
	refresh_ui()


func _start_stock_auction() -> void:
	if state == null:
		return
	var tycoon: Dictionary = state.stats["tycoon"]
	var shares: Dictionary = tycoon["shares"]
	if int(shares.get("player", 5)) >= 100:
		auctioneer_speech = "★ 您已 100% 绝对控股地球星舰母港，无需再拍！"
		refresh_ui()
		return

	active_mode = "stock"
	active_plot_idx = -1
	var base_s: int = maxi(28000, int(tycoon.get("share_price_cents", 60000)) - 12000)
	current_bid_cents = base_s
	rival_max_willing["rex"] = base_s + randi_range(4000, 14000)
	rival_max_willing["victoria"] = base_s + randi_range(6000, 18000)
	rival_max_willing["otto"] = base_s + randi_range(2000, 10000)

	if state.cash_cents >= current_bid_cents:
		highest_bidder = "player"
		auctioneer_speech = "🏛 地球星舰母港 5%% 原始控股权敲钟开拍！您首轮举牌 %s！" % Rules.money(current_bid_cents)
	else:
		highest_bidder = "victoria"
		auctioneer_speech = "🏛 母港 5%% 控股权开拍！星际航运财团首轮举牌 %s！" % Rules.money(current_bid_cents)

	gavel_timer = gavel_duration
	ai_think_timer = 0.75
	auction_updated.emit("母港 5% 控股权敲钟开拍！", "order")
	refresh_ui()


func _player_raise_bid(increment_cents: int) -> void:
	if active_mode == "idle" or state == null:
		return
	var next_bid: int = current_bid_cents + increment_cents
	if highest_bidder == "player" and increment_cents <= 2000:
		# 如果玩家已经是最高出价人，点举牌可直接加速落槌成交！
		_finalize_gavel()
		return
	if state.cash_cents < next_bid:
		auctioneer_speech = "⚠ 您的现金不足以加价至 %s（可点击主界面顶部 ⚡+$5000 补充测试资金或先开闸卖矿）！" % Rules.money(next_bid)
		refresh_ui()
		return
	current_bid_cents = next_bid
	highest_bidder = "player"
	gavel_timer = gavel_duration
	ai_think_timer = 0.75
	# 大额加价 (+$60) 具有震慑效果，直接削减 AI 继续跟牌的意愿！
	if increment_cents >= 6000:
		for rk in rival_max_willing:
			rival_max_willing[rk] = int(rival_max_willing[rk]) - 4000
		auctioneer_speech = "⚡ 您霸气加价至 %s！全场震动，竞争对手正在犹豫是否放弃！" % Rules.money(current_bid_cents)
	else:
		auctioneer_speech = "✋ 您举牌加价至 %s！倒计时重置！" % Rules.money(current_bid_cents)
	auction_updated.emit("您举牌出价 %s" % Rules.money(current_bid_cents), "scan")
	refresh_ui()


func _try_ai_counter_bid() -> void:
	var candidates: Array[String] = []
	for rk in ["rex", "victoria", "otto"]:
		if rk != highest_bidder and int(rival_max_willing.get(rk, 0)) >= current_bid_cents + 1500:
			candidates.append(rk)
	if candidates.is_empty():
		return
	var chosen: String = candidates[randi() % candidates.size()]
	current_bid_cents += 1500
	highest_bidder = chosen
	gavel_timer = gavel_duration
	var quotes: Dictionary = {
		"rex": "🔴 泰坦资源财团拍桌喊道：“这块星区我们重工要定了！出价 %s！”" % Rules.money(current_bid_cents),
		"victoria": "🔵 维多利亚优雅举牌：“星环资本跟进 %s，指挥官还要加吗？”" % Rules.money(current_bid_cents),
		"otto": "🟠 量子投机财团举牌：“嘿嘿，这价格还有赚头，我出 %s！”" % Rules.money(current_bid_cents)
	}
	auctioneer_speech = str(quotes.get(chosen, "AI 加价至 %s" % Rules.money(current_bid_cents)))
	refresh_ui()


func _finalize_gavel() -> void:
	if active_mode == "idle" or state == null:
		return
	var finished_mode: String = active_mode
	var finished_plot: int = active_plot_idx
	active_mode = "idle"
	active_plot_idx = -1

	if finished_mode == "plot":
		var res: Dictionary = Tycoon.claim_auction_plot(state, finished_plot, highest_bidder, current_bid_cents, preferred_star_id)
		if bool(res.get("ok", false)):
			if highest_bidder == "player":
				if state.stats.has("v40"):
					var v40_d: Dictionary = state.stats["v40"]
					var act_mid: String = str(v40_d.get("active_mine_id", "dawn_1"))
					var act_m: Dictionary = v40_d.get("mines", {}).get(act_mid, {})
					if not act_m.is_empty():
						act_m["silo_stock_t"] = int(act_m.get("silo_stock_t", 0)) + 80
						var deps_a: Array = act_m.get("deposits", [])
						if not deps_a.is_empty():
							deps_a[0]["remaining_t"] = int(deps_a[0].get("remaining_t", 500)) + int(res.get("added_boxes", 12)) * 50
				var p: Dictionary = res["plot"]
				var gift_str: String = " + 免费自动钻机已就位" if bool(res.get("miner_gifted", false)) else ""
				auctioneer_speech = "🎉 落槌成交！恭喜您以 %s 夺得「%s·%s」采矿权！「%s」储量 +%d 箱、现矿 +3 箱%s！" % [
					Rules.money(current_bid_cents), str(p["code"]), str(p["name"]),
					str(res.get("star_name", "")), int(res.get("added_boxes", 12)), gift_str
				]
				auction_updated.emit(auctioneer_speech, "cash")
			else:
				auctioneer_speech = "🔨 落槌！%s 以 %s 拍下了该星区采矿权。您可继续点选其他高热力星区！" % [
					str(res.get("rival_name", "对手")), Rules.money(current_bid_cents)
				]
				auction_updated.emit(auctioneer_speech, "arrive")
	elif finished_mode == "stock":
		var res_s: Dictionary = Tycoon.award_live_stock_lot(state, highest_bidder, current_bid_cents)
		if bool(res_s.get("ok", false)):
			if highest_bidder == "player":
				if state.stats.has("v40"):
					var v40_s: Dictionary = state.stats["v40"]
					var p_inv: Dictionary = v40_s.get("port_inventories", {}).get("dawn_port", {})
					if not p_inv.is_empty():
						p_inv["fee_discount_ratio"] = minf(0.25, float(p_inv.get("fee_discount_ratio", 0.0)) + 0.02)
				auctioneer_speech = "🎉 落槌成交！恭喜您以 %s 拍下 5%% 星港永久控股权（当前总持股 %d%%，晨曦港运费减免同步提升）！" % [
					Rules.money(current_bid_cents), int(res_s.get("player_shares", 10))
				]
				auction_updated.emit(auctioneer_speech, "achievement")
			else:
				auctioneer_speech = "🔨 落槌！%s 以 %s 拍下 5%% 母港股权。您可再次敲钟开拍下一批股权！" % [
					str(res_s.get("rival_name", "对手")), Rules.money(current_bid_cents)
				]
				auction_updated.emit(auctioneer_speech, "arrive")
	refresh_ui()


func refresh_ui() -> void:
	if state == null or not is_instance_valid(grid_container):
		return
	var plots: Array = Tycoon.ensure_auction_plots(state)
	var tycoon: Dictionary = state.stats["tycoon"]
	var shares: Dictionary = tycoon["shares"]

	var v40_info: Dictionary = V40.ensure_v40_state(state)
	var avail_cr: int = V40.available_cash_cr(v40_info)
	var res_cr: int = int(v40_info.get("reserved_cash_cr", 0))
	header_cash_label.text = "可支配现金：%d Cr (冻结保证金 %d Cr)" % [avail_cr, res_cr]
	var mayor_txt: String = " ★您已晋升星港执政官 (全矿石售价 +15% & 港口费减免！)" if int(shares.get("player", 5)) >= 50 else " (持股达 50% 可晋升执政官享 +15% 溢价与运费减免)"
	share_bar_label.text = "🏛 破晓星港股权与竞拍格局：👑您 %d%%  |  🔴赤曜矿业 %d%%  |  🔵星环运输 %d%%  |  🟠银穹资本 %d%%  |  待拍池 %d%%%s" % [
		int(shares.get("player", 5)), int(shares.get("rex", 5)), int(shares.get("victoria", 5)),
		int(shares.get("otto", 5)), int(shares.get("unowned", 80)), mayor_txt
	]

	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for idx in range(plots.size()):
		var p: Dictionary = plots[idx]
		var rich: int = int(p["richness"])
		var owner: String = str(p.get("owner", ""))
		var is_metal: bool = str(p["ore"]) == "metal"
		var is_active_lot: bool = (active_mode == "plot" and active_plot_idx == idx)

		var bg_col: Color = Color("101d2b")
		var border_col: Color = Color("2b455c")
		if rich >= 88:
			bg_col = Color("241834")
			border_col = PURPLE
		elif rich >= 75:
			bg_col = Color("261e14")
			border_col = GOLD
		if owner == "player":
			bg_col = Color("142c24")
			border_col = GREEN
		elif owner != "":
			bg_col = Color("22161b")
			border_col = RED
		if is_active_lot:
			border_col = Color.WHITE

		var cell: PanelContainer = PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", _style(bg_col, border_col, 6, 8))
		grid_container.add_child(cell)

		var cvbox: VBoxContainer = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		cell.add_child(cvbox)

		var ore_badge: String = "⛏钛铁" if is_metal else "💎晶簇"
		var top_line: Label = _label("%s · %s" % [str(p["code"]), str(p["name"])], 13, GOLD if rich >= 78 else INK)
		cvbox.add_child(top_line)

		var rich_col: Color = PURPLE if rich >= 88 else (GOLD if rich >= 75 else CYAN)
		var err_m: int = int(p.get("error_margin", 20))
		var dist_lbl: String = str(p.get("distance_label", "近轨"))
		if owner == "":
			cvbox.add_child(_label("%s | 预估热力 %d (±%d) | %s" % [ore_badge, rich, err_m, dist_lbl], 11, rich_col))
		else:
			var true_r: int = int(p.get("true_richness", rich))
			var surprise_tag: String = "💎超预期富矿!" if true_r >= rich + 10 else ("⚠岩层贫化" if true_r <= rich - 10 else "符合预期")
			cvbox.add_child(_label("%s | 真实品质 %d (%s · +%d箱)" % [ore_badge, true_r, surprise_tag, int(p["bonus_boxes"])], 11, GREEN if true_r >= rich else GOLD))

		if owner == "":
			var btn_txt: String = "🔥 正在举牌竞拍中..." if is_active_lot else ("🔨 起拍 %s · 点此举牌" % Rules.money(int(p["base_price_cents"])))
			var b: Button = _button(btn_txt, _start_plot_auction.bind(idx), 30)
			b.disabled = is_active_lot
			cvbox.add_child(b)
		elif owner == "player":
			cvbox.add_child(_label("★ 您的专属领地 (成交 %s)" % Rules.money(int(p["final_price_cents"])), 12, GREEN))
		else:
			var r_label: String = "泰坦资源财团" if owner == "rex" else ("星际航运财团" if owner == "victoria" else "量子投机财团")
			cvbox.add_child(_label("🚩 %s 拍得 (%s)" % [r_label, Rules.money(int(p["final_price_cents"]))], 11, RED))

	# 更新右侧拍卖讲台状态
	if active_mode == "idle":
		stage_title_label.text = "当前拍品：未开启（请点选左侧星区地块或下方股权按钮）"
		stage_bid_label.text = "当前最高出价：等待开拍"
		countdown_bar.value = 0
		bid_plus20_btn.disabled = true
		bid_plus60_btn.disabled = true
		instant_gavel_btn.disabled = true
	else:
		if active_mode == "plot":
			var ap: Dictionary = plots[active_plot_idx]
			stage_title_label.text = "正在竞拍星区：【%s·%s】(热力 %d · +%d箱)" % [
				str(ap["code"]), str(ap["name"]), int(ap["richness"]), int(ap["bonus_boxes"])
			]
		else:
			stage_title_label.text = "正在竞拍股权：【地球星舰母港 5% 永久控股权】"
		var holder_names: Dictionary = {
			"player": "👑 您 (星舰指挥官)",
			"rex": "🔴 泰坦资源财团",
			"victoria": "🔵 星际航运财团",
			"otto": "🟠 量子投机财团"
		}
		stage_bid_label.text = "当前最高价：%s  ·  领先方：%s" % [
			Rules.money(current_bid_cents), str(holder_names.get(highest_bidder, "—"))
		]
		stage_bid_label.add_theme_color_override("font_color", GREEN if highest_bidder == "player" else GOLD)
		bid_plus20_btn.disabled = false
		bid_plus20_btn.text = "🔨 无人跟牌·立即落槌拿牌！" if highest_bidder == "player" else "✋ 举牌加价 (+$20)"
		bid_plus60_btn.disabled = false
		instant_gavel_btn.disabled = false

	stage_speech_label.text = auctioneer_speech

	var v40_rivals: Dictionary = v40_info.get("rivals", {})
	var v40_fin: Dictionary = V40.financial_summary(v40_info)
	var rival_map: Dictionary = {
		"player": {"cash": avail_cr, "nw": int(v40_fin.get("estimated_net_worth_cr", 60000)), "ships": (v40_info.get("ships", []) as Array).size()},
		"rex": {"cash": int(v40_rivals.get("crimson_mining", {}).get("cash_cr", 42000)), "nw": int(v40_rivals.get("crimson_mining", {}).get("net_worth_cr", 68000)), "ships": int(v40_rivals.get("crimson_mining", {}).get("ships", 2))},
		"victoria": {"cash": int(v40_rivals.get("starring_transit", {}).get("cash_cr", 48000)), "nw": int(v40_rivals.get("starring_transit", {}).get("net_worth_cr", 72000)), "ships": int(v40_rivals.get("starring_transit", {}).get("ships", 3))},
		"otto": {"cash": int(v40_rivals.get("silver_dome", {}).get("cash_cr", 55000)), "nw": int(v40_rivals.get("silver_dome", {}).get("net_worth_cr", 75000)), "ships": int(v40_rivals.get("silver_dome", {}).get("ships", 1))}
	}
	for bid_id in bidder_cards:
		var cinfo: Dictionary = bidder_cards[bid_id]
		var card_panel: PanelContainer = cinfo["panel"]
		var cap_lbl: Label = cinfo["cap_lbl"]
		var bbar: ProgressBar = cinfo["bar"]
		var status_lbl: Label = cinfo["status"]
		var r_stat: Dictionary = rival_map.get(bid_id, {"cash": 30000, "nw": 60000, "ships": 1})
		cap_lbl.text = "💰 现金 %d Cr  |  🏛 净值 %d Cr  |  🚀 %d 艘" % [int(r_stat["cash"]), int(r_stat["nw"]), int(r_stat["ships"])]
		bbar.value = clampf(float(int(r_stat["cash"])) / 800.0, 8.0, 100.0)
		var is_top: bool = (active_mode != "idle" and highest_bidder == bid_id)
		card_panel.add_theme_stylebox_override("panel", _style(
			Color("162b26") if is_top else Color("09131d"),
			cinfo["color"] if is_top else Color("22384a"),
			5, 8
		))
		if is_top:
			status_lbl.text = "✋ 当前最高举牌：%s (领先中！)" % Rules.money(current_bid_cents)
			status_lbl.add_theme_color_override("font_color", GOLD)
		else:
			status_lbl.text = "正在席位评估出价上限 (≤32%现金)..." if active_mode != "idle" else "随时准备参与举牌"
			status_lbl.add_theme_color_override("font_color", MUTED)
