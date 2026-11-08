extends RefCounted
## UI-only renderer extracted from main_screen.gd; no simulation or save writes.
## Call via V40CorporateRenderer.render(main_screen, v40, financial_summary).
const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Chart = preload("res://scripts/ui/cashflow_chart.gd")

const INK := Color("e5edf1")
const MUTED := Color("91a5b4")
const GOLD := Color("f2b55c")
const GREEN := Color("83c7a6")
const RED := Color("f08c82")
const CYAN := Color("49d6e4")
const EDGE := Color("304659")

# ui deliberately uses Variant because the game shell owns specialized helpers
# (_label, _button, _style) not declared on the Control base class.
# Stage 5: section slots are stable nodes; only changed slots are rebuilt.
const SECTION_KEYS := ["financial", "inventory", "contracts", "refining", "rivals", "events", "research", "fleet"]
const CACHE_KEY := "_v40_stage5_cache"
const OWNER_KEY := "_v40_stage5_owner"
const COUNTS_KEY := "_v40_stage5_counts"

static func render(ui: Variant, v40: Dictionary, fin: Dictionary) -> bool:
	var root: VBoxContainer = ui.v40_corp_box
	if not is_instance_valid(root) or ui.state == null:
		return false
	var owner_id: int = ui.state.get_instance_id()
	if int(root.get_meta(OWNER_KEY, -1)) != owner_id or root.get_child_count() != SECTION_KEYS.size() + 1:
		ui._clear(root)
		root.add_child(ui._label("🏢 破晓星域矿业集团总览（财务三口径 · 合同可行性与取消 · 单步精炼与星港扩建 · 20项研究 · 三大终局路线）", 16, GOLD))
		for key in SECTION_KEYS:
			var slot := VBoxContainer.new()
			slot.name = "Corp_" + str(key)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			root.add_child(slot)
		root.set_meta(OWNER_KEY, owner_id)
		root.set_meta(CACHE_KEY, {})
		root.set_meta(COUNTS_KEY, {})
	var cache: Dictionary = root.get_meta(CACHE_KEY, {})
	var counts: Dictionary = root.get_meta(COUNTS_KEY, {})
	var changed: bool = false
	for key in SECTION_KEYS:
		var section_id: String = str(key)
		var signature: String = _signature(section_id, v40, fin)
		if cache.get(section_id, null) == signature:
			continue
		var slot: VBoxContainer = root.get_node_or_null(NodePath("Corp_" + section_id)) as VBoxContainer
		if slot == null:
			push_error("V40 corporate section slot missing: " + section_id)
			continue
		match section_id:
			"financial":
				_build_financial(ui, v40, fin, slot)
			"inventory":
				_build_inventory(ui, v40, fin, slot)
			"contracts":
				_build_contracts(ui, v40, fin, slot)
			"refining":
				_build_refining(ui, v40, fin, slot)
			"rivals":
				_build_rivals(ui, v40, fin, slot)
			"events":
				_build_events(ui, v40, fin, slot)
			"research":
				_build_research(ui, v40, fin, slot)
			"fleet":
				_build_fleet(ui, v40, fin, slot)
		cache[section_id] = signature
		counts[section_id] = int(counts.get(section_id, 0)) + 1
		changed = true
	root.set_meta(CACHE_KEY, cache)
	root.set_meta(COUNTS_KEY, counts)
	return changed

static func _signature(section_id: String, v40: Dictionary, fin: Dictionary) -> String:
	# Only include inputs used by each panel. Do not hash the entire V4 state.
	match section_id:
		"financial":
			return JSON.stringify([fin, v40.get("cash_history_cr", []), v40.get("net_worth_history_cr", [])])
		"inventory":
			return JSON.stringify(V40.get_location_inventory_breakdown(v40))
		"contracts":
			var feasibilities: Array = []
			for c in v40.get("contracts", []):
				feasibilities.append(V40.calc_contract_feasibility(v40, c))
			return JSON.stringify([v40.get("contracts", []), feasibilities, v40.get("reserved_cash_cr", 0)])
		"refining":
			return JSON.stringify([v40.get("port_inventories", {}).get("dawn_port", {}), v40.get("market", {}).get("refined_quotas_left", {}), v40.get("starport_expansion_level", 0)])
		"rivals":
			return JSON.stringify([v40.get("rivals", {}), v40.get("endgame", {})])
		"events":
			return JSON.stringify(v40.get("special_events", []))
		"research":
			return JSON.stringify(v40.get("research", {}))
		"fleet":
			var mine_names: Array = []
			for mine_id in v40.get("mines", {}):
				var m: Dictionary = v40["mines"][mine_id]
				mine_names.append([mine_id, m.get("name_zh", ""), m.get("license_owned", false)])
			var comparisons: Array = []
			for mine_id in ["dawn_2", "crimson_1", "frost_1"]:
				comparisons.append(V40.calc_expansion_comparison(v40, mine_id))
			var logs: Array = v40.get("debug_logs", [])
			var latest: Dictionary = logs[0] if not logs.is_empty() else {}
			return JSON.stringify([v40.get("ships", []), mine_names, v40.get("active_mine_id", ""), v40.get("surface_preset", {}), comparisons, latest])
	return "unknown"

static func _build_financial(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# A. 三种财务口径与债务重整保护 (第 10 章)
	var fin_card: PanelContainer = PanelContainer.new()
	fin_card.add_theme_stylebox_override("panel", ui._style(Color("0e1d2c"), CYAN, 6, 8))
	parent.add_child(fin_card)
	var fin_vbox: VBoxContainer = VBoxContainer.new()
	fin_vbox.add_theme_constant_override("separation", 4)
	fin_card.add_child(fin_vbox)
	fin_vbox.add_child(ui._label("💰 财务三口径账本（第 10.2 节：净资产只计一次 cash，绝不重复计入冻结保证金 reserved_cash）", 13, GOLD))
	fin_vbox.add_child(ui._label("• 现金总额 (cash): %d Cr   |   冻结资金 (reserved_cash): %d Cr   |   可支配现金: %d Cr" % [
		int(fin["cash_cr"]), int(fin["reserved_cash_cr"]), int(fin["available_cash_cr"])
	], 12, GREEN))
	fin_vbox.add_child(ui._label("• 经营结余 (Operating Surplus): %d Cr   |   估计净资产 (Net Worth): %d Cr   |   剩余授信额度: %d Cr" % [
		int(fin["operating_surplus_cr"]), int(fin["estimated_net_worth_cr"]), int(fin["remaining_credit_cr"])
	], 12, INK))
	var fin_btn_row: HBoxContainer = HBoxContainer.new()
	fin_btn_row.add_theme_constant_override("separation", 8)
	fin_vbox.add_child(fin_btn_row)
	fin_btn_row.add_child(ui._button("💳 抵押授信借款 (+10,000 Cr)", ui._v40_cmd.bind("BorrowLoan", {"amount_cr": 10000}), 26))
	fin_btn_row.add_child(ui._button("💵 偿还贷款本息 (-10,000 Cr)", ui._v40_cmd.bind("RepayLoan", {"amount_cr": 10000}), 26))
	fin_btn_row.add_child(ui._button("⚖ 主动债务重整 (保留已探明世界情报)", ui._v40_cmd.bind("RestructureDebt", {}), 26))
	fin_btn_row.add_child(ui._button("📊 查看30日集团财报与排行", ui._show_settlement.bind({}), 26))
	var v40_chart: Control = Chart.new(v40.get("cash_history_cr", [30000, int(fin["available_cash_cr"])]), 30000, v40.get("net_worth_history_cr", [60000, int(fin["estimated_net_worth_cr"])]), true)
	fin_vbox.add_child(v40_chart)

static func _build_inventory(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# A2. 位置化库存分布与预留锁控台 (第 5.3, 5.5, 11.4 节：矿区仓 / 在途船舱 / 晨曦港 / 赤曜港，可用+预留=总库存不重算)
	var inv_card: PanelContainer = PanelContainer.new()
	inv_card.add_theme_stylebox_override("panel", ui._style(Color("0b1926"), Color("49d6e4"), 6, 8))
	parent.add_child(inv_card)
	var inv_vbox: VBoxContainer = VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 4)
	inv_card.add_child(inv_vbox)
	inv_vbox.add_child(ui._label("📦 位置化库存分布与预留锁控台（第 5.3 & 5.5 节：展开全部所在地 · 预留货物不被默认现货出售）", 13, CYAN))
	var breakdown: Dictionary = V40.get_location_inventory_breakdown(v40)
	for mid_inv in ["iron_titanium", "silicon_crystal", "energy_crystal", "phase_ore"]:
		var binfo: Dictionary = breakdown.get(mid_inv, {})
		var i_row: HBoxContainer = HBoxContainer.new()
		i_row.add_theme_constant_override("separation", 6)
		inv_vbox.add_child(i_row)
		var m_col_i: Color = Color(str(binfo.get("color", "e5edf1")))
		var i_txt: String = "%s%s  物理总计: %d t   |   矿区地表仓: %d t   |   在途船舱: %d t   |   晨曦港: %d t (可用 %d / 预留 %d t)   |   赤曜港: %d t" % [
			str(binfo.get("icon", "•")), str(binfo.get("name_zh", mid_inv)),
			int(binfo.get("physical_total_t", 0)), int(binfo.get("mine_silos_t", 0)), int(binfo.get("in_transit_t", 0)),
			int(binfo.get("dawn_total_t", 0)), int(binfo.get("dawn_free_t", 0)), int(binfo.get("dawn_reserved_t", 0)),
			int(binfo.get("crimson_total_t", 0))
		]
		var ilbl: Label = ui._label(i_txt, 11, m_col_i if int(binfo.get("physical_total_t", 0)) > 0 else INK)
		ilbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		i_row.add_child(ilbl)
		i_row.add_child(ui._button("🔒预留+50t", ui._v40_cmd.bind("ReserveInventory", {"port_id": "dawn_port", "mineral_id": mid_inv, "delta_t": 50}), 23))
		i_row.add_child(ui._button("🔓释放-50t", ui._v40_cmd.bind("ReserveInventory", {"port_id": "dawn_port", "mineral_id": mid_inv, "delta_t": -50}), 23))

static func _build_contracts(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# B. 合同系统与接单辅助/主动取消 (第 9.6–9.8 节)
	var cnt_card: PanelContainer = PanelContainer.new()
	cnt_card.add_theme_stylebox_override("panel", ui._style(Color("101e2b"), GOLD, 6, 8))
	parent.add_child(cnt_card)
	var cnt_vbox: VBoxContainer = VBoxContainer.new()
	cnt_vbox.add_theme_constant_override("separation", 4)
	cnt_card.add_child(cnt_vbox)
	cnt_vbox.add_child(ui._label("📜 商业供货合同（接单冻结 10% 保证金 · 保守交付可行性预测 · 主动取消扣未交部分 10% 罚金）", 13, GOLD))
	var min_cfg_cnt: Dictionary = V40.get_config().get("minerals", {})
	var state_zh_map: Dictionary = {"available": "🟡待承接", "active": "🟢履约中", "completed": "✅已完成", "cancelled": "⚪已取消", "defaulted": "🔴已违约"}
	for c in v40["contracts"]:
		var feas: Dictionary = V40.calc_contract_feasibility(v40, c)
		var c_min_id: String = str(c.get("mineral_id", "iron_titanium"))
		var c_mdef: Dictionary = min_cfg_cnt.get(c_min_id, {})
		var c_min_zh: String = "%s%s" % [str(c_mdef.get("icon", "•")), str(c_mdef.get("name_zh", c_min_id))]
		var c_state: String = str(c.get("state", "available"))
		var risk_lv: String = str(feas.get("risk_level", "safe"))
		var risk_col: Color = GREEN if (c_state == "completed" or risk_lv == "safe") else (GOLD if risk_lv == "tight" else RED)
		var risk_tag: String = "产能充足" if risk_lv == "safe" else ("排期偏紧" if risk_lv == "tight" else "预计缺口 %dt" % int(feas["shortfall_t"]))

		var c_item_panel: PanelContainer = PanelContainer.new()
		c_item_panel.add_theme_stylebox_override("panel", ui._style(Color("0b1824"), risk_col if c_state == "active" else Color("254058"), 5, 6))
		cnt_vbox.add_child(c_item_panel)
		var c_item_vbox: VBoxContainer = VBoxContainer.new()
		c_item_vbox.add_theme_constant_override("separation", 3)
		c_item_panel.add_child(c_item_vbox)

		var crow: HBoxContainer = HBoxContainer.new()
		crow.add_theme_constant_override("separation", 6)
		c_item_vbox.add_child(crow)
		var c_txt: String = "【%s】%s  %d / %d t  |  固定单价 %d Cr/t  |  截止 Day %.0f (最晚发船 D%.0f · %s)  |  保证金 %d Cr  |  %s" % [
			str(c["issuer"]), c_min_zh, int(c["delivered_t"]), int(c["target_t"]),
			int(c["fixed_price_cr"]), float(c["due_day"]), float(feas["latest_dispatch_day"]), risk_tag, int(c["deposit_cr"]),
			str(state_zh_map.get(c_state, c_state))
		]
		var clbl: Label = ui._label(c_txt, 11, GREEN if c_state == "completed" else INK)
		clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crow.add_child(clbl)
		if c_state == "available":
			crow.add_child(ui._button("✍ 承接(冻%dCr)" % int(c["deposit_cr"]), ui._v40_cmd.bind("AcceptContract", {"contract_id": str(c["id"])}), 25))
		elif c_state == "active":
			crow.add_child(ui._button("🚚 划拨交付", ui._v40_cmd.bind("DeliverContract", {"contract_id": str(c["id"])}), 25))
			crow.add_child(ui._button("✕ 取消合同", ui._v40_cmd.bind("CancelContract", {"contract_id": str(c["id"])}), 25))

		var c_prog: ProgressBar = ProgressBar.new()
		c_prog.custom_minimum_size.y = 6
		c_prog.max_value = float(maxi(1, int(c["target_t"])))
		c_prog.value = clampf(float(int(c["delivered_t"])), 0.0, c_prog.max_value)
		c_prog.show_percentage = false
		c_prog.add_theme_stylebox_override("background", ui._style(Color("060d14"), Color("1b3044"), 2, 0))
		c_prog.add_theme_stylebox_override("fill", ui._style(risk_col, risk_col, 2, 0))
		c_item_vbox.add_child(c_prog)

static func _build_refining(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# C. 单步骤精炼与晨曦星港扩建投资 (第 14.1 & 14.2 节)
	var ref_card: PanelContainer = PanelContainer.new()
	ref_card.add_theme_stylebox_override("panel", ui._style(Color("0f1d28"), GREEN, 6, 8))
	parent.add_child(ref_card)
	var ref_vbox: VBoxContainer = VBoxContainer.new()
	ref_vbox.add_theme_constant_override("separation", 5)
	ref_card.add_child(ref_vbox)
	var sp_lv: int = int(v40.get("starport_expansion_level", 0))
	var dawn_p_inv: Dictionary = v40.get("port_inventories", {}).get("dawn_port", {})
	var mkt_ref: Dictionary = v40.get("market", {})
	var ref_quotas: Dictionary = mkt_ref.get("refined_quotas_left", {"alloy_ingot": 150, "pure_wafer": 60})
	var fe_free_t: int = maxi(0, int(dawn_p_inv.get("minerals", {}).get("iron_titanium", 0)) - int(dawn_p_inv.get("reserved", {}).get("iron_titanium", 0)))
	var si_free_t: int = maxi(0, int(dawn_p_inv.get("minerals", {}).get("silicon_crystal", 0)) - int(dawn_p_inv.get("reserved", {}).get("silicon_crystal", 0)))
	var alloy_q_left: int = int(ref_quotas.get("alloy_ingot", 150))
	var wafer_q_left: int = int(ref_quotas.get("pure_wafer", 60))
	var disc_pct: float = float(dawn_p_inv.get("fee_discount_ratio", 0.0)) * 100.0
	ref_vbox.add_child(ui._label("⚙ 单步骤精炼与星港扩建（第 14 章 · 晨曦港第 %d/3 期：仓容 %dt | 泊位 %d | 运费减免 -%.0f%%）" % [
		sp_lv, int(dawn_p_inv.get("capacity_t", 500)), int(dawn_p_inv.get("berths", 2)), disc_pct
	], 13, GREEN))

	var ref_cards_row: HBoxContainer = HBoxContainer.new()
	ref_cards_row.add_theme_constant_override("separation", 8)
	ref_vbox.add_child(ref_cards_row)

	var ref_items: Array = [
		["alloy_ingot", "🔥 合金锭精炼线", "2t 铁钛矿 → 1t 合金锭 (处理费20Cr · 售价260Cr/t · 等效120Cr/t原矿)", "港内可用铁钛矿: %d t  |  今日剩余高价配额: %d / 150 t" % [fe_free_t, alloy_q_left], alloy_q_left, 150, Color("f0a04a"), 20],
		["pure_wafer", "💎 高纯晶片精炼线", "3t 晶硅矿 → 1t 高纯晶片 (处理费60Cr · 售价650Cr/t · 等效196.7Cr/t原矿)", "港内可用晶硅矿: %d t  |  今日剩余高价配额: %d / 60 t" % [si_free_t, wafer_q_left], wafer_q_left, 60, CYAN, 15],
		["starport", "🏗 晨曦星港扩建工程", "每期 +600t 港仓容量、+1 装卸泊位、干线运费 -8% (共 3 期)", "当前扩建阶段: 第 %d / 3 期  |  下期投资: %s" % [sp_lv, "已满级" if sp_lv >= 3 else "%d Cr" % (18000 + sp_lv * 8000)], sp_lv, 3, GOLD, 0]
	]
	for r_it in ref_items:
		var rc_p: PanelContainer = PanelContainer.new()
		rc_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rc_p.add_theme_stylebox_override("panel", ui._style(Color("0a1622"), r_it[6], 5, 6))
		ref_cards_row.add_child(rc_p)
		var rc_v: VBoxContainer = VBoxContainer.new()
		rc_v.add_theme_constant_override("separation", 3)
		rc_p.add_child(rc_v)
		rc_v.add_child(ui._label(str(r_it[1]), 12, r_it[6]))
		rc_v.add_child(ui._label(str(r_it[2]), 10, INK))
		rc_v.add_child(ui._label(str(r_it[3]), 10, MUTED))
		var rp_bar: ProgressBar = ProgressBar.new()
		rp_bar.custom_minimum_size.y = 6
		rp_bar.max_value = float(maxi(1, int(r_it[5])))
		rp_bar.value = clampf(float(int(r_it[4])), 0.0, rp_bar.max_value)
		rp_bar.show_percentage = false
		rp_bar.add_theme_stylebox_override("background", ui._style(Color("050b12"), Color("182c3e"), 2, 0))
		rp_bar.add_theme_stylebox_override("fill", ui._style(r_it[6], r_it[6], 2, 0))
		rc_v.add_child(rp_bar)
		if str(r_it[0]) == "starport":
			var sp_b: Button = ui._button("✓ 已完成全部3期扩建" if sp_lv >= 3 else "🏗 投资扩建下一期", ui._v40_cmd.bind("InvestStarport", {}), 25)
			sp_b.disabled = (sp_lv >= 3)
			rc_v.add_child(sp_b)
		else:
			rc_v.add_child(ui._button("⚡ 立即精炼并出售 (%d批)" % int(r_it[7]), ui._v40_cmd.bind("StartRefining", {"recipe_id": str(r_it[0]), "batches": int(r_it[7])}), 25))

static func _build_rivals(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# D. 三大竞争财团动态与三大终局路线 (第 13 & 15.6 节)
	var eg_card: PanelContainer = PanelContainer.new()
	eg_card.add_theme_stylebox_override("panel", ui._style(Color("111b27"), GOLD, 6, 8))
	parent.add_child(eg_card)
	var eg_vbox: VBoxContainer = VBoxContainer.new()
	eg_vbox.add_theme_constant_override("separation", 4)
	eg_card.add_child(eg_vbox)
	var eg: Dictionary = v40["endgame"]
	var achieved_str: String = "、".join(eg.get("achieved_routes", [])) if not (eg.get("achieved_routes", []) as Array).is_empty() else "进行中"
	eg_vbox.add_child(ui._label("🏆 三大终局目标与竞争财团周报（已达成路线: %s）" % achieved_str, 13, GOLD))
	var rivals: Dictionary = v40.get("rivals", {})
	for rk in rivals:
		var rv: Dictionary = rivals[rk]
		eg_vbox.add_child(ui._label("• [%s] 现金 %d Cr | 库存 %d t | 在役船 %d 艘 — %s" % [
			str(rv["name_zh"]), int(rv["cash_cr"]), int(rv["inventory_t"]), int(rv["ships"]), str(rv["last_news"])
		], 11, MUTED))
	var eg_routes_cfg: Array = [
		["tycoon", "👑 商业霸主旗舰供货", int(eg["flagship_delivered_t"]), int(eg["flagship_target_t"]), "t", GOLD],
		["pioneer", "🔭 深空先驱观测工程", int(eg["deep_observatory_stage"]), 3, "阶段", CYAN],
		["industrial", "🌐 星际工业干线工程", int(eg.get("industrial_delivered_t", 0)), int(eg.get("industrial_target_t", 2000)), "t", GREEN]
	]
	var eg_btn_row: HBoxContainer = HBoxContainer.new()
	eg_btn_row.add_theme_constant_override("separation", 8)
	eg_vbox.add_child(eg_btn_row)
	for er in eg_routes_cfg:
		var er_col: VBoxContainer = VBoxContainer.new()
		er_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		er_col.add_theme_constant_override("separation", 3)
		eg_btn_row.add_child(er_col)
		var pbar: ProgressBar = ProgressBar.new()
		pbar.custom_minimum_size.y = 8
		pbar.show_percentage = false
		pbar.max_value = float(maxi(1, int(er[3])))
		pbar.value = float(int(er[2]))
		pbar.add_theme_stylebox_override("fill", ui._style(er[5], er[5], 2, 0))
		er_col.add_child(pbar)
		er_col.add_child(ui._button("%s (%d/%d%s)" % [str(er[1]), int(er[2]), int(er[3]), str(er[4])], ui._v40_cmd.bind("DeliverEndgame", {"route_id": str(er[0])}), 26))

static func _build_events(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# D2. 特殊发现与商业预告事件决策台 (第 4.3, 8.9, 15.5 节：同一发现仅可兑现一次，含提前预告期)
	var ev_card: PanelContainer = PanelContainer.new()
	ev_card.add_theme_stylebox_override("panel", ui._style(Color("121b28"), Color("b888f8"), 6, 8))
	parent.add_child(ev_card)
	var ev_vbox: VBoxContainer = VBoxContainer.new()
	ev_vbox.add_theme_constant_override("separation", 4)
	ev_card.add_child(ev_vbox)
	ev_vbox.add_child(ui._label("⚡ 特殊发现与预告型商业事件（第 15.5 节：负面事件提前预告 · 特殊遗迹单次兑现保护）", 13, Color("b888f8")))
	for ev in v40.get("special_events", []):
		var ev_row: HBoxContainer = HBoxContainer.new()
		ev_row.add_theme_constant_override("separation", 6)
		ev_vbox.add_child(ev_row)
		var is_red: bool = bool(ev.get("redeemed", false))
		var st_tag: String = "✓已处置" if is_red else ("预告剩余%.1f日" % float(ev.get("notice_days", 0.0)) if str(ev.get("state", "")) == "forewarned" else "待决策")
		var ev_lbl: Label = ui._label("【%s (%s)】%s" % [str(ev["title_zh"]), st_tag, str(ev["desc_zh"])], 10, GREEN if is_red else INK)
		ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev_row.add_child(ev_lbl)
		if not is_red:
			ev_row.add_child(ui._button(str(ev["opt_a_label"]), ui._v40_cmd.bind("ResolveSpecialEvent", {"event_id": str(ev["id"]), "choice": str(ev["opt_a_id"])}), 25))
			ev_row.add_child(ui._button(str(ev["opt_b_label"]), ui._v40_cmd.bind("ResolveSpecialEvent", {"event_id": str(ev["id"]), "choice": str(ev["opt_b_id"])}), 25))

static func _build_research(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# E. 二十项主要研究 (第 12.2 节：E1–E5 勘探 / M1–M5 采矿 / L1–L5 物流 / C1–C5 商业)
	var res_card: PanelContainer = PanelContainer.new()
	res_card.add_theme_stylebox_override("panel", ui._style(Color("0d1a26"), Color("49d6e4"), 6, 8))
	parent.add_child(res_card)
	var res_vbox: VBoxContainer = VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 5)
	res_card.add_child(res_vbox)
	var unlocked: Array = v40["research"]["unlocked"]
	var res_paused: bool = bool(v40["research"].get("paused", false))

	var res_top_row: HBoxContainer = HBoxContainer.new()
	res_top_row.add_theme_constant_override("separation", 8)
	res_vbox.add_child(res_top_row)
	var res_title_lbl: Label = ui._label("🔬 总部二十项主要研究 (已突破 %d / 20 · 四大专精分支 E/M/L/C · 无循环样本锁)" % unlocked.size(), 13, CYAN)
	res_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_top_row.add_child(res_title_lbl)
	res_top_row.add_child(ui._button("▶ 恢复研究槽位" if res_paused else "⏸ 暂停研究槽位", ui._v40_cmd.bind("ToggleResearchPause", {}), 24))

	var branch_colors: Dictionary = {"勘探": CYAN, "采矿": Color("f0a04a"), "物流": GOLD, "商业": Color("b888f8")}
	var branch_counts: Dictionary = {"勘探": 0, "采矿": 0, "物流": 0, "商业": 0}
	var all_rnodes: Array = V40.get_config().get("research_20", [])
	for rn_c in all_rnodes:
		if str(rn_c["id"]) in unlocked:
			var bn_k: String = str(rn_c.get("branch", "勘探"))
			branch_counts[bn_k] = int(branch_counts.get(bn_k, 0)) + 1

	var branch_bar_row: HBoxContainer = HBoxContainer.new()
	branch_bar_row.add_theme_constant_override("separation", 8)
	res_vbox.add_child(branch_bar_row)
	for bn_key in ["勘探", "采矿", "物流", "商业"]:
		var b_cnt: int = int(branch_counts.get(bn_key, 0))
		var b_c: Color = branch_colors[bn_key]
		var b_box: VBoxContainer = VBoxContainer.new()
		b_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_box.add_theme_constant_override("separation", 2)
		branch_bar_row.add_child(b_box)
		b_box.add_child(ui._label("%s分支专精：%d / 5" % [bn_key, b_cnt], 10, b_c))
		var bp_bar: ProgressBar = ProgressBar.new()
		bp_bar.custom_minimum_size.y = 5
		bp_bar.max_value = 5.0
		bp_bar.value = float(b_cnt)
		bp_bar.show_percentage = false
		bp_bar.add_theme_stylebox_override("background", ui._style(Color("050b12"), Color("182c3e"), 2, 0))
		bp_bar.add_theme_stylebox_override("fill", ui._style(b_c, b_c, 2, 0))
		b_box.add_child(bp_bar)

	var res_grid: GridContainer = GridContainer.new()
	res_grid.columns = 2
	res_grid.add_theme_constant_override("h_separation", 8)
	res_grid.add_theme_constant_override("v_separation", 4)
	res_vbox.add_child(res_grid)

	var min_cfg_res: Dictionary = V40.get_config().get("minerals", {})
	for rnode in all_rnodes:
		var rid: String = str(rnode["id"])
		var is_done: bool = (rid in unlocked)
		var b_name: String = str(rnode.get("branch", "勘探"))
		var b_col: Color = branch_colors.get(b_name, CYAN)
		var req_arr: Array = rnode.get("req", [])
		var req_ok: bool = true
		var missing_reqs := PackedStringArray()
		for rq in req_arr:
			if not (str(rq) in unlocked):
				req_ok = false
				missing_reqs.append(str(rq))
		var req_tag: String = "前置:无" if req_arr.is_empty() else ("前置:%s ✓" % "/".join(req_arr) if req_ok else "🔒需前置:%s" % "/".join(missing_reqs))

		var smp_dict: Dictionary = rnode.get("samples", {})
		var smp_str: String = "无需样本"
		if not smp_dict.is_empty():
			var s_parts := PackedStringArray()
			for sk in smp_dict:
				var sm_def: Dictionary = min_cfg_res.get(str(sk), {})
				s_parts.append("%s%s×%dt" % [str(sm_def.get("icon", "•")), str(sm_def.get("name_zh", sk)), int(smp_dict[sk])])
			smp_str = "样本:" + "+".join(s_parts)

		var r_card_item: PanelContainer = PanelContainer.new()
		r_card_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_card_item.add_theme_stylebox_override("panel", ui._style(Color("0f241e") if is_done else Color("0a1520"), GREEN if is_done else (b_col if req_ok else Color("243646")), 4, 5))
		res_grid.add_child(r_card_item)
		var r_item: HBoxContainer = HBoxContainer.new()
		r_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_card_item.add_child(r_item)
		var r_lbl: Label = ui._label("[%s] %s  |  💰%dCr · 🕒%d日 · %s · %s\n%s" % [
			b_name, str(rnode["name_zh"]), int(rnode["cost_cr"]), int(rnode.get("days", 5)), smp_str, req_tag, str(rnode["effect_zh"])
		], 10, GREEN if is_done else (INK if req_ok else MUTED))
		r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_item.add_child(r_lbl)
		var btn_label: String = "✓已突破" if is_done else ("🔬研发" if req_ok else "🔒需%s" % "/".join(missing_reqs))
		var r_btn: Button = ui._button(btn_label, ui._v40_cmd.bind("StartResearch", {"tech_id": rid}), 25)
		r_btn.disabled = is_done
		r_item.add_child(r_btn)

static func _build_fleet(ui: Variant, v40: Dictionary, fin: Dictionary, parent: VBoxContainer) -> void:
	ui._clear(parent)
	# F. 第 10.4 节新矿项目投资对比、第 19.3 节仓容下调溢出保护与第 23.4 节结构化经营调试日志
	var diag_card: PanelContainer = PanelContainer.new()
	diag_card.add_theme_stylebox_override("panel", ui._style(Color("0b1620"), EDGE, 6, 8))
	parent.add_child(diag_card)
	var diag_vbox: VBoxContainer = VBoxContainer.new()
	diag_vbox.add_theme_constant_override("separation", 4)
	diag_card.add_child(diag_vbox)
	var preset_prev: Dictionary = V40.calc_surface_preset_preview(v40, str(v40.get("active_mine_id", "dawn_1")))
	diag_vbox.add_child(ui._label("🚢 集团船队集中改派/二手售船 & 第 7.5 节地表设施预设 (%s)" % str(preset_prev.get("desc_zh", "")), 13, CYAN))
	var owned_mine_ids: Array[String] = []
	for mk in v40["mines"]:
		if bool(v40["mines"][mk].get("license_owned", false)):
			owned_mine_ids.append(str(mk))
	if owned_mine_ids.size() < 2 and not ("dawn_2" in owned_mine_ids):
		owned_mine_ids.append("dawn_2")

	var phase_zh_map: Dictionary = {"idle": "⚓矿区待命", "inbound": "🚀满载返航", "port_blocked": "🚨港仓满滞留", "waiting": "⏳等待装船"}
	var ship_icon_map: Dictionary = {
		"falcon_light": "res://assets/custom/rocket_light.png",
		"peregrine_med": "res://assets/custom/rocket_reuse.png",
		"leviathan_heavy": "res://assets/custom/rocket_heavy.png"
	}
	for s_item in v40.get("ships", []):
		var sid_num: int = int(s_item.get("id", 1))
		var stype_k: String = str(s_item.get("type_id", "falcon_light"))
		var cur_m_id: String = str(s_item.get("assigned_mine_id", "dawn_1"))
		var pend_m_id: String = str(s_item.get("pending_mine_id", ""))
		var cur_idx: int = owned_mine_ids.find(cur_m_id)
		var next_m_id: String = owned_mine_ids[(cur_idx + 1) % owned_mine_ids.size()] if cur_idx >= 0 else owned_mine_ids[0]
		var cur_m_zh: String = str(v40["mines"].get(cur_m_id, {}).get("name_zh", cur_m_id))
		var next_m_zh: String = str(v40["mines"].get(next_m_id, {}).get("name_zh", next_m_id))
		var pend_str: String = (" (预定改派→%s)" % str(v40["mines"].get(pend_m_id, {}).get("name_zh", pend_m_id))) if pend_m_id != "" else ""
		var is_ovh: bool = bool(s_item.get("overhauled", false))

		var scard_p: PanelContainer = PanelContainer.new()
		scard_p.add_theme_stylebox_override("panel", ui._style(Color("0a1622"), GREEN if is_ovh else Color("2a4862"), 4, 5))
		diag_vbox.add_child(scard_p)
		var s_row_h: HBoxContainer = HBoxContainer.new()
		s_row_h.add_theme_constant_override("separation", 6)
		scard_p.add_child(s_row_h)

		var s_tex_p: String = str(ship_icon_map.get(stype_k, ""))
		if ResourceLoader.exists(s_tex_p):
			var s_ic := TextureRect.new()
			s_ic.texture = load(s_tex_p)
			s_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			s_ic.custom_minimum_size = Vector2(22, 34)
			s_row_h.add_child(s_ic)

		var s_info_lbl: Label = ui._label("【%s (%dt)】%s | 航线: %s%s | 货舱: %d/%dt | 累计 %d 趟 | %s" % [
			str(s_item["name_zh"]), int(s_item.get("capacity_t", 100)),
			str(phase_zh_map.get(str(s_item.get("phase", "idle")), "执飞中")),
			cur_m_zh, pend_str, int(s_item.get("cargo_t", 0)), int(s_item.get("capacity_t", 100)),
			int(s_item.get("trips_completed", 0)), "✓已检修(98.5%)" if is_ovh else "常规服役(96.8%)"
		], 11, GREEN if is_ovh else INK)
		s_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_row_h.add_child(s_info_lbl)
		s_row_h.add_child(ui._button("🔄 改派→%s" % next_m_zh, ui._v40_cmd.bind("AssignRoute", {"ship_id": sid_num, "mine_id": next_m_id}), 24))
		s_row_h.add_child(ui._button("✓已校准" if is_ovh else "✥检修(1200Cr)", ui._v40_cmd.bind("OverhaulShip", {"ship_id": sid_num}), 24))
		s_row_h.add_child(ui._button("♻ 60%售出", ui._v40_cmd.bind("SellShip", {"ship_id": sid_num}), 24))

	var preset_btn_row: HBoxContainer = HBoxContainer.new()
	preset_btn_row.add_theme_constant_override("separation", 8)
	diag_vbox.add_child(preset_btn_row)
	preset_btn_row.add_child(ui._button("📋 保存当前矿区地表设施为预设", ui._v40_cmd.bind("SaveSurfacePreset", {}), 24))
	preset_btn_row.add_child(ui._button("⚡ 一键应用地表预设 (%s)" % str(preset_prev.get("desc_zh", "")), ui._v40_request_mining_action.bind("ApplySurfacePreset", {}), 24))
	diag_vbox.add_child(ui._label("📋 第 10.4 节新矿区投资对比（含静态回本前提与改派原矿损失） & 第 19.3/23.4 节存档溢出校验与调试日志", 13, GOLD))
	for mid_cmp in ["dawn_2", "crimson_1", "frost_1"]:
		var c_info: Dictionary = V40.calc_expansion_comparison(v40, mid_cmp)
		if not c_info.is_empty():
			diag_vbox.add_child(ui._label("• 【%s】许可+基础设备 %d Cr | %s | 航线费 %d Cr/趟 (%.1f日) | 静态回本 ≈ %.1f 日 (%s) | %s" % [
				str(c_info["name_zh"]), int(c_info["initial_cash_needed_cr"]), str(c_info["conservative_rate_zh"]),
				int(c_info["trip_cost_cr"]), float(c_info["cycle_days"]), float(c_info["static_payback_days"]),
				str(c_info["premise_zh"]), str(c_info["reassignment_text_zh"])
			], 10, INK))
	var ovf_row: HBoxContainer = HBoxContainer.new()
	ovf_row.add_theme_constant_override("separation", 8)
	diag_vbox.add_child(ovf_row)
	ovf_row.add_child(ui._button("🛡 触发第 19.3 节旧档仓容下调溢出保护自检 (只出不进·不删货)", ui._v40_cmd.bind("SimulateCapacityOverflow", {}), 25))
	var dlogs: Array = v40.get("debug_logs", [])
	if not dlogs.is_empty():
		var l0: Dictionary = dlogs[0]
		ovf_row.add_child(ui._label("最新本地调试记录: [Tick %d / D%.1f] %s -> %s (%d) | %s" % [
			int(l0.get("tick", 0)), float(l0.get("day", 0.0)), str(l0.get("type", "")),
			str(l0.get("object_id", "")), int(l0.get("amount", 0)), str(l0.get("reason", ""))
		], 10, CYAN))

