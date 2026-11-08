class_name V40DawnEngine
extends RefCounted

## 《星矿大亨 Rocket Prospectors》V4.0 权威规则与模拟引擎
## 严格实现《星矿大亨_完整设计与开发衔接方案_V4.0.md》第 1–24 章基线规则：
## - 破晓星域五大星团、晨曦贸易港/赤曜深空港、四类矿物（铁钛矿/晶硅矿/星能晶/异相矿）+ 两种单步精炼品（合金锭/高纯晶片）
## - 三级信息（遥感 → 轨道勘探+10日发现者排他期 → 地面扫描）与四类采矿权（含竞拍资金冻结）
## - 96×48 逻辑格矿场、钻井平台(60→100t/日)、软硬岩井道树(60→120t/日)、局部采掘头(40→65t/日·半径4格)、同矿区采掘头迁移(500Cr)与瓶颈诊断
## - 三类船型（隼式100t / 游隼350t / 巨鲸1000t）、真实阶段状态机与节点边界改派、2日等待上限/尾矿清运、港仓分批卸货与共享船池(四级优先级)
## - 7日供需平滑参考价、常规/临时高价双买方日额度、三种销售策略(direct/target/priority)、应急出售授权、10%保证金合同(含可行性评估与违约30日冷却)
## - 现金/冻结资金(reserved_cash)/经营结余/估计净资产三口径账本、抵押授信贷款、20项研究(含样本交付与暂停)、7日AI财团周期与三大终局路线

const CONFIG_PATH: String = "res://data/v40_config.json"

static var _cached_config: Dictionary = {}


static func get_config() -> Dictionary:
	if not _cached_config.is_empty():
		return _cached_config
	if FileAccess.file_exists(CONFIG_PATH):
		var raw: String = FileAccess.get_file_as_string(CONFIG_PATH)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			_cached_config = parsed
			return _cached_config
	return {}


static func ensure_v40_state(state: GameState) -> Dictionary:
	if state.stats.has("v40") and (state.stats["v40"] is Dictionary):
		var existing: Dictionary = state.stats["v40"]
		_migrate_v40_fields(existing)
		return existing

	var v40: Dictionary = {
		"schema_version": 4,
		"content_version": "4.1.0",
		"game_day": 0.0,
		"sub_tick": 0,
		"cash_cr": 30000,
		"reserved_cash_cr": 0,
		"debt_cr": 0,
		"accrued_interest_cr": 0,
		"payables_cr": 0,
		"overdue_days": 0.0,
		"restructure_used": false,
		"shortage_paused_once": false,
		"free_scans_left": 1,
		"free_surveys_left": 1,
		"active_mine_id": "dawn_1",
		"selected_tool": "scan",
		"shared_fleet_pool": false,
		"emergency_sale_authorized": false,
		"starport_expansion_level": 0,
		"consecutive_positive_reports": 0,
		"last_report_surplus_cr": 0,
		"completed_contracts_count": 0,
		"issuer_cooldowns": {},
		"sampled_minerals": {"iron_titanium": true, "silicon_crystal": false, "energy_crystal": false, "phase_ore": false},
		# 位置化库存 (第 5.3 & 11.4 节)：每个地点独立维护 4 种矿物库存、预留量与精炼品库存
		"port_inventories": {
			"dawn_port": {
				"name_zh": "晨曦贸易港",
				"capacity_t": 500,
				"berths": 2,
				"fee_discount_ratio": 0.0,
				"minerals": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"reserved": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"refined": {"alloy_ingot": 0, "pure_wafer": 0},
				"sale_policy": {
					"iron_titanium": "direct",
					"silicon_crystal": "direct",
					"energy_crystal": "target",
					"phase_ore": "priority"
				},
				"target_prices": {"iron_titanium": 108, "silicon_crystal": 195, "energy_crystal": 450, "phase_ore": 960}
			},
			"crimson_hub": {
				"name_zh": "赤曜深空港",
				"capacity_t": 400,
				"berths": 1,
				"fee_discount_ratio": 0.0,
				"minerals": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"reserved": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"refined": {"alloy_ingot": 0, "pure_wafer": 0},
				"sale_policy": {
					"iron_titanium": "direct",
					"silicon_crystal": "direct",
					"energy_crystal": "direct",
					"phase_ore": "priority"
				},
				"target_prices": {"iron_titanium": 108, "silicon_crystal": 195, "energy_crystal": 450, "phase_ore": 960}
			}
		},
		# 市场状态 (第 9.2 & 9.3 节)
		"market": {
			"reference_prices": {"iron_titanium": 100.0, "silicon_crystal": 180.0, "energy_crystal": 420.0, "phase_ore": 900.0},
			"regular_quotes": {"iron_titanium": 95, "silicon_crystal": 171, "energy_crystal": 399, "phase_ore": 855},
			"spot_quotes": {"iron_titanium": 110, "silicon_crystal": 198, "energy_crystal": 462, "phase_ore": 990},
			"regular_quotas_left": {"iron_titanium": 600, "silicon_crystal": 360, "energy_crystal": 180, "phase_ore": 90},
			"spot_quotas_left": {"iron_titanium": 100, "silicon_crystal": 80, "energy_crystal": 50, "phase_ore": 30},
			"demand_7d": {"iron_titanium": 2400, "silicon_crystal": 1200, "energy_crystal": 500, "phase_ore": 200},
			"delivered_7d": {"iron_titanium": 1800, "silicon_crystal": 900, "energy_crystal": 360, "phase_ore": 140},
			"refined_quotes": {"alloy_ingot": 260, "pure_wafer": 650},
			"refined_quotas_left": {"alloy_ingot": 150, "pure_wafer": 60}
		},
		# 破晓星域 6 大代表性矿区（覆盖第 3.4 节五大星团与第 15.4 节六类差异化情境）
		"mines": _build_initial_mines(),
		# 船队 (第 8.2 & 8.4 & 11.1 节：开局已交付一艘隼式轻型船，位于初始矿场)
		"ships": [
			{
				"id": 1,
				"type_id": "falcon_light",
				"name_zh": "隼式轻型 #1",
				"capacity_t": 100,
				"location": "dawn_1",
				"assigned_mine_id": "dawn_1",
				"pending_mine_id": "",
				"dest_port_id": "dawn_port",
				"phase": "idle", # "idle", "waiting", "loading", "inbound", "unloading", "turnaround", "outbound", "port_blocked"
				"mineral_id": "iron_titanium",
				"cargo_t": 0,
				"wait_days": 0.0,
				"phase_days_left": 0.0,
				"prepaid_fee_cr": 0,
				"trips_completed": 0
			}
		],
		# 合同 (第 9.6 & 9.7 节：含第 9.7 节标准起始示例合同)
		"contracts": [
			{
				"id": "cnt_dawn_01",
				"issuer": "晨曦造船厂",
				"mineral_id": "iron_titanium",
				"target_t": 500,
				"delivered_t": 0,
				"reserved_t": 0,
				"port_id": "dawn_port",
				"fixed_price_cr": 125,
				"due_day": 20.0,
				"deposit_cr": 6250,
				"state": "available"
			},
			{
				"id": "cnt_dawn_02",
				"issuer": "星环航电研究所",
				"mineral_id": "silicon_crystal",
				"target_t": 200,
				"delivered_t": 0,
				"reserved_t": 0,
				"port_id": "dawn_port",
				"fixed_price_cr": 225,
				"due_day": 25.0,
				"deposit_cr": 4500,
				"state": "available"
			},
			{
				"id": "cnt_deep_03",
				"issuer": "破晓深空跃迁局",
				"mineral_id": "energy_crystal",
				"target_t": 120,
				"delivered_t": 0,
				"reserved_t": 0,
				"port_id": "crimson_hub",
				"fixed_price_cr": 520,
				"due_day": 35.0,
				"deposit_cr": 6240,
				"state": "available"
			}
		],
		# 研究状态 (第 12.1 & 12.2 节：唯一研究槽位，支持暂停，不可退款)
		"research": {
			"unlocked": [],
			"active_id": "",
			"paused": false,
			"days_left": 0.0,
			"total_days": 0.0
		},
		# 三大竞争财团抽象模拟状态 (第 13.1 & 13.2 节)
		"rivals": {
			"crimson_mining": {"name_zh": "赤曜矿业", "cash_cr": 42000, "net_worth_cr": 68000, "output_t_day": 45, "inventory_t": 120, "ships": 2, "mines_owned": 2, "last_news": "赤曜矿业正在晨曦边境扩建铁钛矿主井"},
			"starring_transit": {"name_zh": "星环运输", "cash_cr": 48000, "net_worth_cr": 72000, "output_t_day": 30, "inventory_t": 80, "ships": 3, "mines_owned": 1, "last_news": "星环运输增购游隼中型船投入主航道"},
			"silver_dome": {"name_zh": "银穹资本", "cash_cr": 55000, "net_worth_cr": 75000, "output_t_day": 25, "inventory_t": 210, "ships": 1, "mines_owned": 1, "last_news": "银穹资本囤积晶硅矿等待高价采购窗口"}
		},
		# 三种财务口径账本统计 (第 10.2 & 10.3 节)
		"ledger": {
			"sales_revenue_cr": 0,
			"contract_revenue_cr": 0,
			"refined_revenue_cr": 0,
			"mining_var_expense_cr": 0,
			"transport_expense_cr": 0,
			"upkeep_expense_cr": 0,
			"storage_expense_cr": 0,
			"interest_expense_cr": 0,
			"capex_expense_cr": 0,
			"penalty_expense_cr": 0,
			"entries": []
		},
		# 终局工程进度 (第 15.6 节：商业霸主 / 深空先驱 / 星际工业巨头)
		"endgame": {
			"flagship_delivered_t": 0,
			"flagship_target_t": 1200,
			"deep_observatory_stage": 0,
			"transit_hub_built": false,
			"industrial_delivered_t": 0,
			"industrial_target_t": 2000,
			"achieved_routes": []
		},
		"bore_route_mode": "auto",
		"active_port_id": "dawn_port",
		"familiar_player_mode": false,
		"lane_policy": "normal",
		"launch_window_mode": "standard",
		"work_orders": [],
		"special_events": _build_initial_special_events(),
		"event_cooldowns": {},
		# 分级合并通知队列 (第 16.5 节：info / attention / urgent，相同对象与原因合并，不重复轰炸)
		"notifications": [],
		"surface_preset": {"platforms": 1, "platform_upgraded": true, "silo_capacity_t": 800, "name_zh": "标准高产地表组合 (1平台改造+800t矿仓)"},
		"restructure_countdown_days": 30.0,
		"cash_history_cr": [30000, 30000],
		"net_worth_history_cr": [60000, 60000],
		"debug_logs": [],
		"executed_commands": {}
	}
	state.stats["v40"] = v40
	return v40


static func _migrate_v40_fields(v40: Dictionary) -> void:
	if not v40.has("starport_expansion_level"):
		v40["starport_expansion_level"] = 0
	if not v40.has("issuer_cooldowns"):
		v40["issuer_cooldowns"] = {}
	if not v40.has("completed_contracts_count"):
		v40["completed_contracts_count"] = 0
	if not v40.has("consecutive_positive_reports"):
		v40["consecutive_positive_reports"] = 0
	if not v40.has("sampled_minerals"):
		v40["sampled_minerals"] = {"iron_titanium": true, "silicon_crystal": false, "energy_crystal": false, "phase_ore": false}
	if not v40.has("notifications"):
		v40["notifications"] = []
	if not v40.has("bore_route_mode"):
		v40["bore_route_mode"] = "auto" # "auto", "detour_soft", "direct_hard"
	if not v40.has("active_port_id"):
		v40["active_port_id"] = "dawn_port"
	if not v40.has("familiar_player_mode"):
		v40["familiar_player_mode"] = false
	if not v40.has("work_orders"):
		v40["work_orders"] = []
	if not v40.has("special_events"):
		v40["special_events"] = _build_initial_special_events()
	if not v40.has("event_cooldowns"):
		v40["event_cooldowns"] = {}
	if not v40.has("lane_policy"):
		v40["lane_policy"] = "normal" # "normal", "detour", "hold"
	if not v40.has("launch_window_mode"):
		v40["launch_window_mode"] = "standard" # "standard", "optimal", "express"
	if not v40.has("debug_logs"):
		v40["debug_logs"] = []
	if not v40.has("surface_preset"):
		v40["surface_preset"] = {"platforms": 1, "platform_upgraded": true, "silo_capacity_t": 800, "name_zh": "标准高产地表组合 (1平台改造+800t矿仓)"}
	if not v40.has("restructure_countdown_days"):
		v40["restructure_countdown_days"] = 30.0
	if not v40.has("cash_history_cr"):
		v40["cash_history_cr"] = [30000, int(v40.get("cash_cr", 30000))]
	if not v40.has("net_worth_history_cr"):
		v40["net_worth_history_cr"] = [60000, 62800]
	# 第 19.3 & 23.2 #16 节：校验矿仓与港仓是否处于仓容下调后的溢出待清理状态 (只出不进，绝不删货)
	for mid in v40.get("mines", {}):
		var m: Dictionary = v40["mines"][mid]
		m["overflow_locked"] = int(m.get("silo_stock_t", 0)) > int(m.get("silo_capacity_t", 300))
	for pid in v40.get("port_inventories", {}):
		var pinv: Dictionary = v40["port_inventories"][pid]
		pinv["overflow_locked"] = _port_used_tonnes(pinv) > int(pinv.get("capacity_t", 500))
	var pinvs: Dictionary = v40.get("port_inventories", {})
	for pid in pinvs:
		var p: Dictionary = pinvs[pid]
		if not p.has("refined"):
			p["refined"] = {"alloy_ingot": 0, "pure_wafer": 0}
		if not p.has("fee_discount_ratio"):
			p["fee_discount_ratio"] = 0.0
	var mkt: Dictionary = v40.get("market", {})
	if not mkt.has("refined_quotes"):
		mkt["refined_quotes"] = {"alloy_ingot": 260, "pure_wafer": 650}
	if not mkt.has("refined_quotas_left"):
		mkt["refined_quotas_left"] = {"alloy_ingot": 150, "pure_wafer": 60}
	var eg: Dictionary = v40.get("endgame", {})
	if not eg.has("industrial_delivered_t"):
		eg["industrial_delivered_t"] = 0
		eg["industrial_target_t"] = 2000
	if not eg.has("achieved_routes"):
		eg["achieved_routes"] = []


static func _build_initial_mines() -> Dictionary:
	return {
		"dawn_1": {
			"id": "dawn_1",
			"name_zh": "晨曦一号矿区",
			"cluster_id": "dawn_frontier",
			"cluster_name_zh": "晨曦边境",
			"archetype_zh": "近港低值大宗矿 · 起始基地",
			"distance_l": 0.5,
			"gravity_g": 1.0,
			"license_type": "initial",
			"license_owned": true,
			"license_price_cr": 0,
			"survey_stage": 3,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 1800,
			"estimate_max_t": 6200,
			"confidence_zh": "高 (已地面扫描)",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 1,
			"platform_upgraded": false,
			"bore_cells": 24,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 60,
			"last_served_day": 0.0,
			"primary_mineral": "iron_titanium",
			"deposits": [
				{"id": "d1_shallow_a", "name_zh": "浅层铁钛A脉", "mineral_id": "iron_titanium", "gx": 28, "gy": 16, "remaining_t": 950, "initial_t": 1000, "hard_rock": false, "revealed": true, "heads": 1},
				{"id": "d1_shallow_b", "name_zh": "浅层铁钛B脉", "mineral_id": "iron_titanium", "gx": 54, "gy": 20, "remaining_t": 900, "initial_t": 900, "hard_rock": false, "revealed": false, "heads": 0},
				{"id": "d1_mid_si", "name_zh": "中层晶硅伴生脉", "mineral_id": "silicon_crystal", "gx": 74, "gy": 26, "remaining_t": 1600, "initial_t": 1600, "hard_rock": false, "revealed": false, "heads": 0},
				{"id": "d1_deep_fe", "name_zh": "深层富铁钛母脉", "mineral_id": "iron_titanium", "gx": 46, "gy": 38, "remaining_t": 2600, "initial_t": 2600, "hard_rock": true, "revealed": false, "heads": 0}
			]
		},
		"dawn_2": {
			"id": "dawn_2",
			"name_zh": "碎光浅滩矿区",
			"cluster_id": "dawn_frontier",
			"cluster_name_zh": "晨曦边境",
			"archetype_zh": "多片浅矿 · 晶硅矿可达来源",
			"distance_l": 0.8,
			"gravity_g": 1.0,
			"license_type": "open",
			"license_owned": false,
			"license_price_cr": 6500,
			"survey_stage": 1,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 1400,
			"estimate_max_t": 3200,
			"confidence_zh": "中等",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 0,
			"platform_upgraded": false,
			"bore_cells": 0,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 0,
			"last_served_day": 0.0,
			"primary_mineral": "silicon_crystal",
			"deposits": [
				{"id": "d2_si_a", "name_zh": "浅滩晶硅A床", "mineral_id": "silicon_crystal", "gx": 30, "gy": 15, "remaining_t": 850, "initial_t": 850, "hard_rock": false, "revealed": true, "heads": 0},
				{"id": "d2_si_b", "name_zh": "浅滩晶硅B床", "mineral_id": "silicon_crystal", "gx": 64, "gy": 18, "remaining_t": 950, "initial_t": 950, "hard_rock": false, "revealed": false, "heads": 0},
				{"id": "d2_deep_si", "name_zh": "断层下晶硅脉", "mineral_id": "silicon_crystal", "gx": 48, "gy": 35, "remaining_t": 1400, "initial_t": 1400, "hard_rock": true, "revealed": false, "heads": 0}
			]
		},
		"crimson_1": {
			"id": "crimson_1",
			"name_zh": "赤沙裂谷矿区",
			"cluster_id": "crimson_sands",
			"cluster_name_zh": "赤沙星群",
			"archetype_zh": "硬岩夹层 · 深层大矿长期供货",
			"distance_l": 1.2,
			"gravity_g": 1.0,
			"license_type": "commercial",
			"license_owned": false,
			"license_price_cr": 9500,
			"current_bid_cr": 9500,
			"highest_bidder": "",
			"survey_stage": 1,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 3200,
			"estimate_max_t": 6800,
			"confidence_zh": "低 (硬岩干扰)",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 0,
			"platform_upgraded": false,
			"bore_cells": 0,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 0,
			"last_served_day": 0.0,
			"primary_mineral": "iron_titanium",
			"deposits": [
				{"id": "c1_shallow", "name_zh": "裂谷表层铁矿", "mineral_id": "iron_titanium", "gx": 26, "gy": 14, "remaining_t": 700, "initial_t": 700, "hard_rock": false, "revealed": true, "heads": 0},
				{"id": "c1_deep_main", "name_zh": "赤沙深层巨脉", "mineral_id": "iron_titanium", "gx": 52, "gy": 34, "remaining_t": 3400, "initial_t": 3400, "hard_rock": true, "revealed": false, "heads": 0},
				{"id": "c1_deep_si", "name_zh": "赤沙深部晶硅核", "mineral_id": "silicon_crystal", "gx": 76, "gy": 38, "remaining_t": 1800, "initial_t": 1800, "hard_rock": true, "revealed": false, "heads": 0}
			]
		},
		"frost_1": {
			"id": "frost_1",
			"name_zh": "霜环冰脊矿区",
			"cluster_id": "frost_ring",
			"cluster_name_zh": "霜环星群",
			"archetype_zh": "L2跨系可达 · 星能晶保底来源",
			"distance_l": 2.0,
			"gravity_g": 1.0,
			"license_type": "open",
			"license_owned": false,
			"license_price_cr": 14000,
			"survey_stage": 1,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 1200,
			"estimate_max_t": 4200,
			"confidence_zh": "模糊 (冰层折射)",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 0,
			"platform_upgraded": false,
			"bore_cells": 0,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 0,
			"last_served_day": 0.0,
			"primary_mineral": "energy_crystal",
			"deposits": [
				{"id": "f1_en_a", "name_zh": "冰盖浅层星能晶", "mineral_id": "energy_crystal", "gx": 34, "gy": 18, "remaining_t": 650, "initial_t": 650, "hard_rock": false, "revealed": true, "heads": 0},
				{"id": "f1_en_b", "name_zh": "冰脊深部星能脉", "mineral_id": "energy_crystal", "gx": 62, "gy": 36, "remaining_t": 1600, "initial_t": 1600, "hard_rock": true, "revealed": false, "heads": 0}
			]
		},
		"molten_1": {
			"id": "molten_1",
			"name_zh": "熔心重核矿区",
			"cluster_id": "molten_core",
			"cluster_name_zh": "熔心星群",
			"archetype_zh": "1.3G高重力 · 受限地表集约富矿",
			"distance_l": 2.2,
			"gravity_g": 1.3,
			"license_type": "commercial",
			"license_owned": false,
			"license_price_cr": 18000,
			"current_bid_cr": 18000,
			"highest_bidder": "",
			"survey_stage": 1,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 2500,
			"estimate_max_t": 5500,
			"confidence_zh": "中等",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 0,
			"platform_upgraded": false,
			"bore_cells": 0,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 0,
			"last_served_day": 0.0,
			"primary_mineral": "energy_crystal",
			"deposits": [
				{"id": "m1_core_a", "name_zh": "熔心高压星能床", "mineral_id": "energy_crystal", "gx": 42, "gy": 24, "remaining_t": 1400, "initial_t": 1400, "hard_rock": true, "revealed": true, "heads": 0},
				{"id": "m1_core_b", "name_zh": "熔心超富铁钛核", "mineral_id": "iron_titanium", "gx": 68, "gy": 36, "remaining_t": 3200, "initial_t": 3200, "hard_rock": true, "revealed": false, "heads": 0}
			]
		},
		"glimmer_1": {
			"id": "glimmer_1",
			"name_zh": "幽光深域异常矿区",
			"cluster_id": "glimmer_deep",
			"cluster_name_zh": "幽光深域",
			"archetype_zh": "远距高价值 · 异相矿终局来源",
			"distance_l": 3.2,
			"gravity_g": 1.15,
			"license_type": "special",
			"license_owned": false,
			"license_price_cr": 28000,
			"survey_stage": 1,
			"exclusive_until_day": 0.0,
			"estimate_min_t": 800,
			"estimate_max_t": 2400,
			"confidence_zh": "未知深空异常",
			"status": "running",
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 0,
			"platform_upgraded": false,
			"bore_cells": 0,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 0,
			"last_served_day": 0.0,
			"primary_mineral": "phase_ore",
			"deposits": [
				{"id": "g1_phase_a", "name_zh": "幽光浅表异相晶", "mineral_id": "phase_ore", "gx": 38, "gy": 20, "remaining_t": 500, "initial_t": 500, "hard_rock": false, "revealed": true, "heads": 0},
				{"id": "g1_phase_b", "name_zh": "深渊核心异相母脉", "mineral_id": "phase_ore", "gx": 64, "gy": 38, "remaining_t": 1200, "initial_t": 1200, "hard_rock": true, "revealed": false, "heads": 0}
			]
		}
	}


## ============================================================================
## 财务口径与可支配现金计算 (第 10.2 & 10.5 节)
## ============================================================================

static func available_cash_cr(v40: Dictionary) -> int:
	return maxi(0, int(v40.get("cash_cr", 0)) - int(v40.get("reserved_cash_cr", 0)))


static func financial_summary(v40: Dictionary) -> Dictionary:
	var cfg: Dictionary = get_config()
	var minerals_cfg: Dictionary = cfg.get("minerals", {})
	var cash: int = int(v40.get("cash_cr", 0))
	var reserved: int = int(v40.get("reserved_cash_cr", 0))
	var debt: int = int(v40.get("debt_cr", 0))
	var interest: int = int(v40.get("accrued_interest_cr", 0))
	var payables: int = int(v40.get("payables_cr", 0))

	# 保守库存估值 (第 10.2 节：使用公开参考价 80% 流动性折扣，绝不用目标价虚增净资产)
	var inventory_val_cr: int = 0
	var port_invs: Dictionary = v40.get("port_inventories", {})
	for pid in port_invs:
		var pinv: Dictionary = port_invs[pid]
		var mins: Dictionary = pinv.get("minerals", {})
		for mid in mins:
			var base_p: int = int(minerals_cfg.get(mid, {}).get("base_price_cr", 100))
			inventory_val_cr += int(round(float(int(mins[mid]) * base_p) * 0.80))
		var ref_items: Dictionary = pinv.get("refined", {})
		inventory_val_cr += int(round(float(int(ref_items.get("alloy_ingot", 0)) * 260 + int(ref_items.get("pure_wafer", 0)) * 650) * 0.80))

	var mines: Dictionary = v40.get("mines", {})
	var equipment_resale_cr: int = 0
	for m_id in mines:
		var m: Dictionary = mines[m_id]
		if not bool(m.get("license_owned", false)):
			continue
		var p_cnt: int = int(m.get("platforms", 0))
		var h_cnt: int = _count_mine_heads(m)
		equipment_resale_cr += int(round(float(p_cnt * 8000 + h_cnt * 2000) * 0.60))
		var m_min: String = str(m.get("primary_mineral", "iron_titanium"))
		var m_base_p: int = int(minerals_cfg.get(m_min, {}).get("base_price_cr", 100))
		inventory_val_cr += int(round(float(int(m.get("silo_stock_t", 0)) * m_base_p) * 0.70))

	for s in v40.get("ships", []):
		var stype: String = str(s.get("type_id", "falcon_light"))
		var sprice: int = int(cfg.get("ships", {}).get(stype, {}).get("price_cr", 38000))
		equipment_resale_cr += int(round(float(sprice) * 0.60))
		var scargo: int = int(s.get("cargo_t", 0))
		if scargo > 0:
			var smin: String = str(s.get("mineral_id", "iron_titanium"))
			var s_base_p: int = int(minerals_cfg.get(smin, {}).get("base_price_cr", 100))
			inventory_val_cr += int(round(float(scargo * s_base_p) * 0.75))

	var led: Dictionary = v40.get("ledger", {})
	var operating_rev: int = (
		int(led.get("sales_revenue_cr", 0)) +
		int(led.get("contract_revenue_cr", 0)) +
		int(led.get("refined_revenue_cr", 0))
	)
	var operating_cost: int = (
		int(led.get("mining_var_expense_cr", 0)) +
		int(led.get("transport_expense_cr", 0)) +
		int(led.get("upkeep_expense_cr", 0)) +
		int(led.get("storage_expense_cr", 0)) +
		int(led.get("interest_expense_cr", 0))
	)
	var operating_surplus: int = operating_rev - operating_cost

	# 净资产只计入一次 cash (包含 reserved_cash，绝不重复累加 reserved_cash！)
	var estimated_net_worth: int = cash + inventory_val_cr + equipment_resale_cr - debt - interest - payables

	# 合格抵押资产排除借来的现金与冻结保证金 (第 10.5 节)
	var unborrowed_free_cash: int = maxi(0, cash - reserved - debt)
	var eligible_collateral: int = unborrowed_free_cash + inventory_val_cr + equipment_resale_cr
	var total_credit_line: int = mini(50000, maxi(20000, int(round(float(eligible_collateral) * 0.30))))
	var remaining_credit: int = maxi(0, total_credit_line - debt)

	return {
		"cash_cr": cash,
		"reserved_cash_cr": reserved,
		"available_cash_cr": maxi(0, cash - reserved),
		"operating_surplus_cr": operating_surplus,
		"estimated_net_worth_cr": estimated_net_worth,
		"inventory_val_cr": inventory_val_cr,
		"equipment_resale_cr": equipment_resale_cr,
		"debt_cr": debt,
		"accrued_interest_cr": interest,
		"payables_cr": payables,
		"credit_limit_cr": total_credit_line,
		"remaining_credit_cr": remaining_credit
	}


static func get_location_inventory_breakdown(v40: Dictionary) -> Dictionary:
	# 第 5.3 & 5.5 & 11.4 节：按地点展开全部四种矿物库存（矿区地表仓 / 在途船舱 / 晨曦港可用与预留 / 赤曜港可用与预留）
	# 严格保证：可用 + 预留 = 港口物理总库存（绝不把预留再加一次当作新库存！）
	var result: Dictionary = {}
	var cfg_mins: Dictionary = get_config().get("minerals", {})
	for mid in ["iron_titanium", "silicon_crystal", "energy_crystal", "phase_ore"]:
		var mdef: Dictionary = cfg_mins.get(mid, {})
		var mine_t: int = 0
		for m_key in v40.get("mines", {}):
			var m: Dictionary = v40["mines"][m_key]
			if bool(m.get("license_owned", false)) and str(m.get("primary_mineral", "")) == mid:
				mine_t += int(m.get("silo_stock_t", 0))
		var ship_t: int = 0
		for s in v40.get("ships", []):
			if str(s.get("mineral_id", "")) == mid:
				ship_t += int(s.get("cargo_t", 0))
		var p_dawn: Dictionary = v40.get("port_inventories", {}).get("dawn_port", {})
		var dawn_tot: int = int(p_dawn.get("minerals", {}).get(mid, 0))
		var dawn_res: int = mini(dawn_tot, int(p_dawn.get("reserved", {}).get(mid, 0)))
		var dawn_free: int = maxi(0, dawn_tot - dawn_res)

		var p_crim: Dictionary = v40.get("port_inventories", {}).get("crimson_hub", {})
		var crim_tot: int = int(p_crim.get("minerals", {}).get(mid, 0))
		var crim_res: int = mini(crim_tot, int(p_crim.get("reserved", {}).get(mid, 0)))
		var crim_free: int = maxi(0, crim_tot - crim_res)

		result[mid] = {
			"name_zh": str(mdef.get("name_zh", mid)),
			"icon": str(mdef.get("icon", "•")),
			"color": str(mdef.get("color", "e5edf1")),
			"mine_silos_t": mine_t,
			"in_transit_t": ship_t,
			"dawn_total_t": dawn_tot,
			"dawn_free_t": dawn_free,
			"dawn_reserved_t": dawn_res,
			"crimson_total_t": crim_tot,
			"crimson_free_t": crim_free,
			"crimson_reserved_t": crim_res,
			"physical_total_t": mine_t + ship_t + dawn_tot + crim_tot
		}
	return result


static func _count_mine_heads(mine: Dictionary) -> int:
	var total: int = 0
	for d in mine.get("deposits", []):
		total += int(d.get("heads", 0))
	return total


## ============================================================================
## 第 6 & 11 & 16.4 章：矿场产能、树形主井限制、剩余可采天数与瓶颈解释
## ============================================================================

static func analyze_mine_bottleneck(v40: Dictionary, mine_id: String) -> Dictionary:
	var mines: Dictionary = v40.get("mines", {})
	if not mines.has(mine_id):
		return {}
	var mine: Dictionary = mines[mine_id]
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	var head_base_rate: float = 65.0 if ("M5" in unlocked) else 40.0
	var lift_per_plat: float = 100.0 if bool(mine.get("platform_upgraded", false)) else 60.0
	var bore_flow_cap: float = 120.0 if bool(mine.get("bore_upgraded", false)) else 60.0

	var platforms: int = int(mine.get("platforms", 0))
	var total_lift_cap: float = float(platforms) * lift_per_plat
	var active_heads: int = 0
	var exhausted_heads: int = 0
	var raw_head_rate: float = 0.0
	var known_remaining_t: int = 0
	var unknown_deep_t: int = 0

	for d in mine.get("deposits", []):
		var rem: int = int(d.get("remaining_t", 0))
		var h_cnt: int = int(d.get("heads", 0))
		if bool(d.get("revealed", false)):
			known_remaining_t += rem
			if rem > 0 and h_cnt > 0:
				active_heads += h_cnt
				raw_head_rate += float(h_cnt) * head_base_rate
			elif rem <= 0 and h_cnt > 0:
				exhausted_heads += h_cnt
		else:
			unknown_deep_t += rem

	var effective_rate: float = 0.0
	var bottleneck_msg: String = "矿区运行平稳，产能与运力匹配。"
	var status: String = str(mine.get("status", "running"))
	var stock_t: int = int(mine.get("silo_stock_t", 0))
	var cap_t: int = int(mine.get("silo_capacity_t", 300))

	if not bool(mine.get("license_owned", false)):
		bottleneck_msg = "尚未取得该矿区开采许可（可在星图购买或竞拍许可）。"
	elif status == "paused":
		bottleneck_msg = "矿区已手动暂停：当前停止生产，固定维护费已降至 25%。"
	elif status == "mothballed":
		bottleneck_msg = "矿区已封存：设备与井道数据保留，仅支付 15 Cr/日 基地保留费。"
	elif platforms <= 0:
		bottleneck_msg = "尚未建设地表钻井平台（需 8,000 Cr 建设首座钻井平台）。"
	elif active_heads <= 0 and exhausted_heads > 0:
		bottleneck_msg = "当前矿脉已采空！您有 %d 台闲置采掘头，可花 500 Cr 迁移至其他已揭示矿脉。" % exhausted_heads
	elif active_heads <= 0:
		bottleneck_msg = "尚未在已揭示矿脉上部署采掘头（点击矿脉连接井道并安装采掘头）。"
	elif stock_t >= cap_t:
		bottleneck_msg = "矿仓已满 (%d/%d t)：采掘头自动暂停生产（不销毁矿石、不扣采矿变动费）。请派船清运或扩建矿仓。" % [stock_t, cap_t]
	else:
		effective_rate = minf(raw_head_rate, minf(bore_flow_cap, total_lift_cap))
		if raw_head_rate > bore_flow_cap and bore_flow_cap <= total_lift_cap:
			bottleneck_msg = "主井限制产量：%d 个采掘头合计可产 %.0f t/日，主井只能通过 %.0f t/日。" % [
				active_heads, raw_head_rate, bore_flow_cap
			]
		elif raw_head_rate > total_lift_cap:
			bottleneck_msg = "钻井平台提升受限：采掘头合计可产 %.0f t/日，地表平台总提升上限 %.0f t/日。" % [
				raw_head_rate, total_lift_cap
			]

	# 计算分配给该矿区的日均运力
	var daily_ship_cap: float = 0.0
	for s in v40.get("ships", []):
		if str(s.get("assigned_mine_id", "")) == mine_id or bool(v40.get("shared_fleet_pool", false)):
			var metrics: Dictionary = calc_ship_route_metrics(
				str(s.get("type_id", "falcon_light")),
				float(mine.get("distance_l", 0.5)),
				float(mine.get("gravity_g", 1.0)),
				100, 8,
				v40
			)
			daily_ship_cap += float(metrics.get("daily_capacity_t", 50.0))

	if effective_rate > daily_ship_cap + 1.0 and stock_t < cap_t:
		var net_accum: float = maxf(1.0, effective_rate - daily_ship_cap)
		var days_to_full: float = float(cap_t - stock_t) / net_accum
		bottleneck_msg = "当前运输不足：日产约 %.0f t，日均可运约 %.0f t。按当前生产速度，约 %.1f 日后满仓。" % [
			effective_rate, daily_ship_cap, days_to_full
		]

	var depletion_days: float = 999.0 if effective_rate <= 0.1 else (float(known_remaining_t) / effective_rate)
	var depletion_alert: String = "normal"
	if depletion_days < 5.0:
		depletion_alert = "urgent"
	elif depletion_days < 15.0:
		depletion_alert = "warning"

	return {
		"raw_head_rate_t_day": raw_head_rate,
		"bore_flow_cap_t_day": bore_flow_cap,
		"platform_lift_cap_t_day": total_lift_cap,
		"effective_rate_t_day": effective_rate,
		"daily_transport_t_day": daily_ship_cap,
		"known_remaining_t": known_remaining_t,
		"unknown_deep_t": unknown_deep_t,
		"exhausted_heads": exhausted_heads,
		"depletion_days": depletion_days,
		"depletion_alert": depletion_alert,
		"bottleneck_text": bottleneck_msg
	}


## ============================================================================
## 第 8.2 & 11.5 章：船型航线周期、往返费用与每船日贡献精确公式
## ============================================================================

static func calc_ship_route_metrics(ship_type_id: String, distance_l: float, gravity_g: float, sale_price_cr: int, mining_var_cost_cr: int, v40: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = get_config()
	var sdef: Dictionary = cfg.get("ships", {}).get(ship_type_id, {
		"price_cr": 38000, "capacity_t": 100, "speed_factor": 1.0,
		"load_days": 0.25, "unload_days": 0.25, "turnaround_days": 0.50,
		"fixed_trip_fee_cr": 400, "distance_fee_cr": 2000, "daily_upkeep_cr": 40
	})
	var cap_t: int = int(sdef["capacity_t"])
	var speed: float = maxf(0.1, float(sdef["speed_factor"]))
	var t_cycle: float = (2.0 * distance_l / speed) + float(sdef["load_days"]) + float(sdef["unload_days"]) + float(sdef["turnaround_days"])
	var f_fixed: float = float(sdef["fixed_trip_fee_cr"])
	var k_dist: float = float(sdef["distance_fee_cr"])
	var env_surcharge: float = f_fixed * maxf(0.0, gravity_g - 1.0)
	var raw_trip_cost: float = f_fixed + 2.0 * distance_l * k_dist + env_surcharge

	# 若提供 v40 状态，应用 L5 深空航行保障 (远距 -20%)、星港扩建优惠 (第 14.2 节) 与发射窗口气象修正 (对标参考图 2 & 4)
	if not v40.is_empty():
		var unlocked: Array = v40.get("research", {}).get("unlocked", [])
		var discount_mult: float = 1.0
		if ("L5" in unlocked) and distance_l >= 2.0:
			discount_mult -= 0.20
		var port_disc: float = float(v40.get("port_inventories", {}).get("dawn_port", {}).get("fee_discount_ratio", 0.0))
		discount_mult -= port_disc
		var win_mode: String = str(v40.get("launch_window_mode", "standard"))
		if win_mode == "optimal":
			discount_mult -= 0.08
		elif win_mode == "express":
			t_cycle = maxf(0.5, t_cycle * 0.85)
			discount_mult += 0.05
		raw_trip_cost = maxf(100.0, raw_trip_cost * clampf(discount_mult, 0.50, 1.15))

	var trip_cost_cr: int = int(round(raw_trip_cost))
	var daily_cap_t: float = float(cap_t) / maxf(0.1, t_cycle)
	var cost_per_tonne: float = float(trip_cost_cr) / float(maxi(1, cap_t))
	var gross_margin_cr: int = cap_t * (sale_price_cr - mining_var_cost_cr)
	var trip_contrib_cr: int = gross_margin_cr - trip_cost_cr
	var ship_day_contrib_cr: int = int(round(float(trip_contrib_cr) / maxf(0.1, t_cycle)))
	var payback_days: float = 999.0 if ship_day_contrib_cr <= 0 else (float(int(sdef["price_cr"])) / float(ship_day_contrib_cr))

	return {
		"ship_type_id": ship_type_id,
		"name_zh": str(sdef.get("name_zh", ship_type_id)),
		"price_cr": int(sdef["price_cr"]),
		"capacity_t": cap_t,
		"cycle_days": t_cycle,
		"trip_cost_cr": trip_cost_cr,
		"cost_per_tonne_cr": cost_per_tonne,
		"daily_capacity_t": daily_cap_t,
		"trip_contribution_cr": trip_contrib_cr,
		"ship_day_contribution_cr": ship_day_contrib_cr,
		"payback_days": payback_days
	}


## ============================================================================
## 第 9.8 章：合同接单辅助（保守预计交付量、已预留、在途、缺口与最晚发船日）
## ============================================================================

static func calc_contract_feasibility(v40: Dictionary, contract: Dictionary) -> Dictionary:
	var min_id: String = str(contract.get("mineral_id", "iron_titanium"))
	var port_id: String = str(contract.get("port_id", "dawn_port"))
	var target_t: int = int(contract.get("target_t", 500))
	var delivered_t: int = int(contract.get("delivered_t", 0))
	var due_day: float = float(contract.get("due_day", 20.0))
	var cur_day: float = float(v40.get("game_day", 0.0))
	var days_remaining: float = maxf(0.0, due_day - cur_day)

	var pinv: Dictionary = v40.get("port_inventories", {}).get(port_id, {})
	var port_free_t: int = maxi(0, int(pinv.get("minerals", {}).get(min_id, 0)) - int(pinv.get("reserved", {}).get(min_id, 0)))

	var in_transit_t: int = 0
	for s in v40.get("ships", []):
		if str(s.get("mineral_id", "")) == min_id and int(s.get("cargo_t", 0)) > 0:
			in_transit_t += int(s["cargo_t"])

	# 保守产能估算：仅统计已揭示矿体上的活跃采掘头与矿区现有库存（不计入尚未勘探的矿量）
	var conservative_mine_rate: float = 0.0
	var mine_stock_t: int = 0
	var mines: Dictionary = v40.get("mines", {})
	for mid in mines:
		var m: Dictionary = mines[mid]
		if not bool(m.get("license_owned", false)) or str(m.get("primary_mineral", "")) != min_id:
			continue
		mine_stock_t += int(m.get("silo_stock_t", 0))
		var bneck: Dictionary = analyze_mine_bottleneck(v40, str(mid))
		conservative_mine_rate += minf(float(bneck.get("effective_rate_t_day", 0.0)), float(bneck.get("daily_transport_t_day", 50.0)))

	var projected_new_t: int = int(floor(conservative_mine_rate * maxf(0.0, days_remaining - 1.0)))
	var conservative_total_t: int = delivered_t + port_free_t + in_transit_t + mine_stock_t + projected_new_t
	var need_t: int = maxi(0, target_t - delivered_t)
	var shortfall_t: int = maxi(0, target_t - conservative_total_t)
	var latest_dispatch_day: float = maxf(cur_day, due_day - 2.0)
	var risk_level: String = "safe"
	if shortfall_t > 0:
		risk_level = "high_risk"
	elif conservative_total_t < int(round(float(target_t) * 1.15)):
		risk_level = "tight"

	return {
		"need_t": need_t,
		"port_free_t": port_free_t,
		"in_transit_t": in_transit_t,
		"mine_stock_t": mine_stock_t,
		"projected_total_t": conservative_total_t,
		"shortfall_t": shortfall_t,
		"latest_dispatch_day": latest_dispatch_day,
		"risk_level": risk_level
	}


## ============================================================================
## 第 6.5 & 11.2 & 15.1–15.5 & 16.3 章：井道绕行路线规划、一小时渐进引导与六类特殊发现/预告事件
## ============================================================================

static func _build_initial_special_events() -> Array:
	return [
		{
			"id": "ancient_array",
			"title_zh": "古代探测阵列遗迹",
			"category": "discovery",
			"state": "available", # "available", "forewarned", "active", "resolved"
			"redeemed": false,
			"notice_days": 0.0,
			"active_days": 0.0,
			"desc_zh": "在矿区深部岩层发现古星际测绘阵列：可付 3,500 Cr 深入调查（揭示当前矿区全部隐藏矿脉+获 8,000 Cr 科研资助），或直接出售发现权换取 6,000 Cr（同一发现仅可兑现一次）。",
			"opt_a_id": "investigate",
			"opt_a_label": "深入调查 (-3500Cr·全矿脉揭示+科研补贴)",
			"opt_b_id": "sell_rights",
			"opt_b_label": "出售发现权 (+6000Cr·放弃优先权)"
		},
		{
			"id": "shipbuilding_boom",
			"title_zh": "晨曦船坞造船需求扩张",
			"category": "market_opportunity",
			"state": "forewarned",
			"redeemed": false,
			"notice_days": 2.0,
			"active_days": 8.0,
			"desc_zh": "【商业预告】晨曦造船厂公布扩产计划：2 日后铁钛矿与合金锭参考报价上浮 +20%，采购额度扩大 +150 t/日（持续 8 日）。",
			"opt_a_id": "prepare_stock",
			"opt_a_label": "锁定船坞优先供货配额 (+4500Cr预付款奖励)",
			"opt_b_id": "keep_normal",
			"opt_b_label": "维持常规现货策略"
		},
		{
			"id": "lane_maintenance",
			"title_zh": "边境主航道例行检修",
			"category": "logistics_notice",
			"state": "forewarned",
			"redeemed": false,
			"notice_days": 6.5, # 新手保护期前 6 日内仅作远期预告，绝不破坏起步闭环
			"active_days": 5.0,
			"desc_zh": "【航道预告】边境主航道将于 Day 6.5 后进入检修期：可选择支付 +300 Cr/趟绕行备用航道保速，或暂缓发船囤入地表矿仓。",
			"opt_a_id": "detour",
			"opt_a_label": "启用备用绕行航线 (保速不延误)",
			"opt_b_id": "hold_silo",
			"opt_b_label": "检修期暂缓发船囤仓"
		},
		{
			"id": "super_deep_vein",
			"title_zh": "超大型深层伴生富矿脉",
			"category": "discovery",
			"state": "available",
			"redeemed": false,
			"notice_days": 0.0,
			"active_days": 0.0,
			"desc_zh": "地震波回波显示当前矿区基底下方存在超大型富矿床（预计 +1,500 t 高品位储量），可投入 4,500 Cr 分期详勘并入可采储量，或放弃开发。",
			"opt_a_id": "staged_develop",
			"opt_a_label": "分期详勘并入 (-4500Cr·当前矿区+1500t储量)",
			"opt_b_id": "abandon",
			"opt_b_label": "放弃该深矿机会 (0成本)"
		}
	]


static func calc_bore_plan(v40: Dictionary, mine_id: String, dep_idx: int) -> Dictionary:
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	var deposits: Array = mine.get("deposits", [])
	if dep_idx < 0 or dep_idx >= deposits.size():
		return {"can_build": false, "error": "无效的矿体目标。"}
	var dep: Dictionary = deposits[dep_idx]
	var is_hard: bool = bool(dep.get("hard_rock", false))
	var heads_now: int = int(dep.get("heads", 0))
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	var has_m1: bool = ("M1" in unlocked)
	var has_e3: bool = ("E3" in unlocked)
	var mode: String = str(v40.get("bore_route_mode", "auto"))

	var use_detour: bool = false
	if is_hard:
		if mode == "detour_soft" or (mode == "auto" and not has_m1):
			use_detour = true

	var bore_cells: int = 0
	var cell_cost: int = 100
	var route_desc: String = "已有连通井道 (直接增设采掘头)"
	if heads_now == 0:
		if not is_hard:
			bore_cells = 8
			cell_cost = 100
			route_desc = "软岩直连路线 8 格 (100 Cr/格)"
		elif use_detour:
			bore_cells = 11 if has_e3 else 14
			cell_cost = 100
			route_desc = "软岩折线绕行路线 %d 格 (100 Cr/格 · 绕开硬岩夹层，无需M1)" % bore_cells
		else:
			bore_cells = 8
			cell_cost = 300
			route_desc = "硬岩直穿路线 8 格 (300 Cr/格 · 需M1硬岩钻头)"

	var can_build: bool = true
	var err_msg: String = ""
	if is_hard and not use_detour and not has_m1:
		can_build = false
		err_msg = "直穿硬岩需先研发【M1 · 硬岩钻头】，或切换为【软岩折线绕行路线】！"

	var bore_cost: int = bore_cells * cell_cost
	var head_cost: int = 2000
	var total_cost: int = bore_cost + head_cost
	var speed_cells_day: float = 8.0 if (not is_hard or use_detour) else 4.0
	var work_days: float = (float(bore_cells) / speed_cells_day) + 0.5

	return {
		"can_build": can_build,
		"error": err_msg,
		"is_hard": is_hard,
		"use_detour": use_detour,
		"bore_cells": bore_cells,
		"cell_cost_cr": cell_cost,
		"bore_cost_cr": bore_cost,
		"head_cost_cr": head_cost,
		"total_cost_cr": total_cost,
		"work_days": work_days,
		"route_desc_zh": route_desc,
		"connect_reserve_t": int(dep.get("remaining_t", 0))
	}


static func get_contextual_guidance(v40: Dictionary) -> Dictionary:
	if bool(v40.get("familiar_player_mode", false)):
		return {"stage": 0, "title_zh": "老手精简模式", "hint_zh": "已启用「我熟悉经营游戏」精简提示，仅展示核心瓶颈与紧急告警。"}

	var m1: Dictionary = v40.get("mines", {}).get("dawn_1", {})
	var revealed_cnt: int = 0
	var total_heads: int = 0
	for d in m1.get("deposits", []):
		if bool(d.get("revealed", false)):
			revealed_cnt += 1
		total_heads += int(d.get("heads", 0))

	var sales_rev: int = int(v40.get("ledger", {}).get("sales_revenue_cr", 0))
	var owned_mines: int = 0
	for mid in v40.get("mines", {}):
		if bool(v40["mines"][mid].get("license_owned", false)):
			owned_mines += 1

	if revealed_cnt <= 1 or sales_rev <= 0:
		return {
			"stage": 1,
			"title_zh": "阶段 1/4 (0–5m · 首矿闭环)",
			"hint_zh": "点击剖面图中的「📡 模糊矿化信号」执行免费地面扫描，随后在右侧晨曦港点击「出售」完成首笔矿石回款。"
		}
	if total_heads <= 1:
		return {
			"stage": 2,
			"title_zh": "阶段 2/4 (5–15m · 产能与预算取舍)",
			"hint_zh": "已揭示第二处矿体！点击新矿体连通井道并安装第 2 台采掘头 (+40 t/日)，观察 60 t/日主井上限与运力瓶颈。"
		}
	var has_active_contract: bool = false
	for c in v40.get("contracts", []):
		if str(c.get("state", "")) in ["active", "completed"]:
			has_active_contract = true
			break
	if not has_active_contract and not bool(v40.get("sampled_minerals", {}).get("silicon_crystal", false)):
		return {
			"stage": 3,
			"title_zh": "阶段 3/4 (15–30m · 晶硅矿与短合同)",
			"hint_zh": "扫描并接入中层晶硅伴生脉 (180 Cr/t)，或进入「🏢 3.集团总览」承接首份 10% 保证金供货合同。"
		}
	if owned_mines <= 1:
		return {
			"stage": 4,
			"title_zh": "阶段 4/4 (30–60m · 跨星球扩张)",
			"hint_zh": "进入「🗺 2.破晓星图」，对邻近的「碎光浅滩矿区」执行免费轨道勘探（享 10 日发现者排他期）并开辟第二矿场！"
		}
	return {
		"stage": 5,
		"title_zh": "集团化跨星团经营阶段",
		"hint_zh": "您已掌握跨矿场经营闭环！可开启「共享船池」、参与晨曦港扩建或推进 20 项总部研究冲击三大终局目标。"
	}


## ============================================================================
## 第 10.4 章：不同项目的比较（起步现金、保守产能、航线成本、静态回本前提、船只改派原矿损失）
## ============================================================================

static func calc_expansion_comparison(v40: Dictionary, target_mine_id: String) -> Dictionary:
	var mines: Dictionary = v40.get("mines", {})
	if not mines.has(target_mine_id):
		return {}
	var tm: Dictionary = mines[target_mine_id]
	var owned: bool = bool(tm.get("license_owned", false))
	var lic_cost: int = 0 if owned else int(tm.get("license_price_cr", 8000))
	var base_equip_cost: int = 0 if owned and int(tm.get("platforms", 0)) > 0 else (8000 + 2000 + 800)
	var initial_cash_needed: int = lic_cost + base_equip_cost

	var p_min: String = str(tm.get("primary_mineral", "iron_titanium"))
	var mdef: Dictionary = get_config().get("minerals", {}).get(p_min, {})
	var ref_p: int = int(mdef.get("base_price_cr", 100))
	var var_c: int = int(mdef.get("mining_var_cost_cr", 8))

	var met: Dictionary = calc_ship_route_metrics(
		"falcon_light",
		float(tm.get("distance_l", 1.0)),
		float(tm.get("gravity_g", 1.0)),
		ref_p,
		var_c,
		v40
	)
	var ship_day_contrib: int = maxi(1, int(met.get("ship_day_contribution_cr", 1500)))
	var static_payback_days: float = float(maxi(2800, initial_cash_needed)) / float(ship_day_contrib)

	# 计算将当前主力矿区的 1 艘轻型船改派至该矿区后，原矿区损失的运力与船日贡献
	var active_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var active_m: Dictionary = mines.get(active_id, mines.get("dawn_1", {}))
	var act_min: String = str(active_m.get("primary_mineral", "iron_titanium"))
	var act_mdef: Dictionary = get_config().get("minerals", {}).get(act_min, {})
	var act_met: Dictionary = calc_ship_route_metrics(
		"falcon_light",
		float(active_m.get("distance_l", 0.5)),
		float(active_m.get("gravity_g", 1.0)),
		int(act_mdef.get("base_price_cr", 100)),
		int(act_mdef.get("mining_var_cost_cr", 8)),
		v40
	)
	var lost_cap_t_day: float = float(act_met.get("daily_capacity_t", 50.0))
	var lost_contrib_cr_day: int = int(act_met.get("ship_day_contribution_cr", 3400))

	return {
		"mine_id": target_mine_id,
		"name_zh": str(tm.get("name_zh", target_mine_id)),
		"license_cost_cr": lic_cost,
		"base_equip_cost_cr": base_equip_cost,
		"initial_cash_needed_cr": initial_cash_needed,
		"conservative_rate_zh": "40–60 t/日 (已知储量 %d–%d t)" % [int(tm.get("estimate_min_t", 1000)), int(tm.get("estimate_max_t", 3000))],
		"trip_cost_cr": int(met.get("trip_cost_cr", 2400)),
		"cycle_days": float(met.get("cycle_days", 2.0)),
		"ship_day_contrib_cr": ship_day_contrib,
		"static_payback_days": static_payback_days,
		"premise_zh": "前提：按 1 艘隼式轻型船满载直达晨曦港、公开参考价 %d Cr/t 与单头 40 t/日估算" % ref_p,
		"reassignment_loss_t_day": lost_cap_t_day,
		"reassignment_loss_cr_day": lost_contrib_cr_day,
		"reassignment_text_zh": "若从「%s」改派 1 艘轻型船，原矿区减运 %.0f t/日 (少赚 %d Cr/船日)" % [
			str(active_m.get("name_zh", "晨曦一号")), lost_cap_t_day, lost_contrib_cr_day
		]
	}


static func record_debug_log(v40: Dictionary, event_type: String, object_id: String, amount: int, reason: String) -> void:
	# 第 23.4 节：本地结构化经营调试记录（记录游戏 tick、对象 ID、关键数量和原因）
	var logs: Array = v40.get("debug_logs", [])
	var cur_day: float = float(v40.get("game_day", 0.0))
	var tick_num: int = int(round(cur_day * 60.0))
	logs.push_front({
		"tick": tick_num,
		"day": cur_day,
		"type": event_type,
		"object_id": object_id,
		"amount": amount,
		"reason": reason
	})
	if logs.size() > 40:
		logs.pop_back()


## ============================================================================
## 第 18.4 章：统一经济命令入口（校验状态/预算/前置 + 幂等 command_id + 事务提交）
## ============================================================================

static func execute_command(state: GameState, cmd_type: String, params: Dictionary) -> Dictionary:
	var v40: Dictionary = ensure_v40_state(state)
	var cmd_id: String = str(params.get("command_id", ""))
	if cmd_id != "" and v40["executed_commands"].has(cmd_id):
		return {"ok": false, "error": "重复命令已忽略 (幂等保护)。"}

	var res: Dictionary = {"ok": false, "error": "未知命令"}
	match cmd_type:
		"ScanArea":
			res = _cmd_scan_area(state, v40, params)
		"OrbitalSurvey":
			res = _cmd_orbital_survey(state, v40, params)
		"AcquireLicense":
			res = _cmd_acquire_license(state, v40, params)
		"PlaceBid":
			res = _cmd_place_bid(state, v40, params)
		"BuildDrill":
			res = _cmd_build_drill(state, v40, params)
		"PlaceMiningHead":
			res = _cmd_place_mining_head(state, v40, params)
		"RelocateMiningHead":
			res = _cmd_relocate_mining_head(state, v40, params)
		"UpgradeFacility":
			res = _cmd_upgrade_facility(state, v40, params)
		"SetMineStatus":
			res = _cmd_set_mine_status(state, v40, params)
		"SellEquipment":
			res = _cmd_sell_equipment(state, v40, params)
		"PurchaseShip":
			res = _cmd_purchase_ship(state, v40, params)
		"AssignRoute":
			res = _cmd_assign_route(state, v40, params)
		"ToggleSharedFleetPool":
			res = _cmd_toggle_shared_fleet_pool(state, v40, params)
		"SetSalePolicy":
			res = _cmd_set_sale_policy(state, v40, params)
		"ReserveInventory":
			res = _cmd_reserve_inventory(state, v40, params)
		"ToggleEmergencySale":
			res = _cmd_toggle_emergency_sale(state, v40, params)
		"SellMineralNow":
			res = _cmd_sell_mineral_now(state, v40, params)
		"AcceptContract":
			res = _cmd_accept_contract(state, v40, params)
		"DeliverContract":
			res = _cmd_deliver_contract(state, v40, params)
		"CancelContract":
			res = _cmd_cancel_contract(state, v40, params)
		"StartResearch":
			res = _cmd_start_research(state, v40, params)
		"ToggleResearchPause":
			res = _cmd_toggle_research_pause(state, v40, params)
		"StartRefining":
			res = _cmd_start_refining(state, v40, params)
		"InvestStarport":
			res = _cmd_invest_starport(state, v40, params)
		"DeliverEndgame":
			res = _cmd_deliver_endgame(state, v40, params)
		"BorrowLoan":
			res = _cmd_borrow_loan(state, v40, params)
		"RepayLoan":
			res = _cmd_repay_loan(state, v40, params)
		"RestructureDebt":
			res = _cmd_restructure_debt(state, v40, params)
		"ToggleBoreRouteMode":
			res = _cmd_toggle_bore_route_mode(state, v40, params)
		"CancelLastOrder":
			res = _cmd_cancel_last_order(state, v40, params)
		"SwitchActivePort":
			res = _cmd_switch_active_port(state, v40, params)
		"TransferViaHub":
			res = _cmd_transfer_via_hub(state, v40, params)
		"ResolveSpecialEvent":
			res = _cmd_resolve_special_event(state, v40, params)
		"ToggleFamiliarMode":
			res = _cmd_toggle_familiar_mode(state, v40, params)
		"SetAutoBidLimit":
			res = _cmd_set_auto_bid_limit(state, v40, params)
		"SettleCommercialAuction":
			res = _cmd_settle_commercial_auction(state, v40, params)
		"SimulateCapacityOverflow":
			res = _cmd_simulate_capacity_overflow(state, v40, params)
		"SaveSurfacePreset":
			res = _cmd_save_surface_preset(state, v40, params)
		"ApplySurfacePreset":
			res = _cmd_apply_surface_preset(state, v40, params)
		"SellShip":
			res = _cmd_sell_ship(state, v40, params)
		"OverhaulShip":
			res = _cmd_overhaul_ship(state, v40, params)
		"SelectLaunchWindow":
			res = _cmd_select_launch_window(state, v40, params)
		"LaunchPadDispatch":
			res = _cmd_launch_pad_dispatch(state, v40, params)

	if bool(res.get("ok", false)):
		if cmd_id != "":
			v40["executed_commands"][cmd_id] = true
		record_debug_log(
			v40,
			cmd_type,
			str(params.get("mine_id", params.get("contract_id", params.get("tech_id", v40.get("active_mine_id", "dawn_1"))))),
			int(res.get("cost_cr", res.get("revenue_cr", res.get("refund_cr", params.get("amount_cr", 0))))),
			str(res.get("msg", cmd_type))
		)
	_sync_legacy_bridge(state, v40)
	return res


static func _cmd_scan_area(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mines: Dictionary = v40["mines"]
	if not mines.has(mine_id):
		return {"ok": false, "error": "矿区不存在。"}
	var mine: Dictionary = mines[mine_id]
	var cost: int = 0 if int(v40.get("free_scans_left", 0)) > 0 else 300
	if available_cash_cr(v40) < cost:
		return {"ok": false, "error": "可支配现金不足（地面扫描需 %d Cr）。" % cost}

	var revealed_name: String = ""
	for d in mine["deposits"]:
		if not bool(d.get("revealed", false)):
			d["revealed"] = true
			revealed_name = str(d["name_zh"])
			break
	if revealed_name == "":
		return {"ok": false, "error": "该矿区所有局部矿体均已扫描揭示（重复扫描不重新抽取矿体）。"}

	if cost == 0:
		v40["free_scans_left"] = maxi(0, int(v40["free_scans_left"]) - 1)
	else:
		v40["cash_cr"] = int(v40["cash_cr"]) - cost
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost
	mine["survey_stage"] = 3
	mine["confidence_zh"] = "高 (已地面扫描)"
	_push_merged_notification(v40, "info", mine_id, "scan_reveal", "【%s】地面扫描揭示新矿体：「%s」" % [str(mine["name_zh"]), revealed_name])
	state.add_log("【地面扫描完成】「%s」揭示新矿体：%s（耗资 %d Cr）。" % [str(mine["name_zh"]), revealed_name, cost])
	return {"ok": true, "msg": "地面扫描揭示「%s」！" % revealed_name, "cost_cr": cost}


static func _cmd_orbital_survey(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mines: Dictionary = v40["mines"]
	if not mines.has(mine_id):
		return {"ok": false, "error": "目标天体不存在。"}
	var mine: Dictionary = mines[mine_id]
	if int(mine.get("survey_stage", 1)) >= 2:
		return {"ok": false, "error": "该矿区已完成轨道勘探。"}
	var cost: int = 0 if int(v40.get("free_surveys_left", 0)) > 0 else int(round(2000.0 * maxf(1.0, float(mine.get("distance_l", 1.0)))))
	if available_cash_cr(v40) < cost:
		return {"ok": false, "error": "可支配现金不足（轨道勘探需 %d Cr）。" % cost}
	if cost == 0:
		v40["free_surveys_left"] = maxi(0, int(v40["free_surveys_left"]) - 1)
	else:
		v40["cash_cr"] = int(v40["cash_cr"]) - cost
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost

	mine["survey_stage"] = 2
	var has_e2: bool = "E2" in (v40.get("research", {}).get("unlocked", []) as Array)
	mine["confidence_zh"] = "精准 (E2轨道详勘)" if has_e2 else "较高 (已轨道详勘)"
	if str(mine.get("license_type", "")) == "open":
		mine["exclusive_until_day"] = float(v40.get("game_day", 0.0)) + 10.0
	for d in mine["deposits"]:
		d["revealed"] = true
		break
	state.add_log("【轨道勘探完成】「%s」获得储量区间与地质报告，开放矿区享有 10 日排他评估期！" % str(mine["name_zh"]))
	return {"ok": true, "msg": "轨道勘探完成，已锁定 10 日发现者排他评估期！"}


static func _cmd_acquire_license(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mines: Dictionary = v40["mines"]
	if not mines.has(mine_id):
		return {"ok": false, "error": "矿区不存在。"}
	var mine: Dictionary = mines[mine_id]
	if bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "您已持有该矿区开采许可。"}
	var price: int = int(mine.get("license_price_cr", 8000))
	if available_cash_cr(v40) < price:
		return {"ok": false, "error": "可支配现金不足（取得「%s」开采许可需 %d Cr）。" % [str(mine["name_zh"]), price]}
	v40["cash_cr"] = int(v40["cash_cr"]) - price
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + price
	mine["license_owned"] = true
	mine["platforms"] = maxi(1, int(mine.get("platforms", 0)))
	mine["bore_cells"] = maxi(16, int(mine.get("bore_cells", 0)))
	v40["active_mine_id"] = mine_id
	state.add_log("【取得采矿权】已支付 %d Cr 取得「%s」永久开采许可并部署基础井口！" % [price, str(mine["name_zh"])])
	return {"ok": true, "msg": "已取得「%s」永久开采许可！" % str(mine["name_zh"])}


static func _cmd_place_bid(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", "crimson_1"))
	var bid_cr: int = int(params.get("bid_cr", 10000))
	var mines: Dictionary = v40["mines"]
	if not mines.has(mine_id):
		return {"ok": false, "error": "竞拍矿区不存在。"}
	var mine: Dictionary = mines[mine_id]
	if available_cash_cr(v40) < bid_cr:
		return {"ok": false, "error": "可支配现金不足以冻结本次出价 %d Cr。" % bid_cr}
	# 若此前玩家已是最高出价人，先释放旧冻结金额
	if str(mine.get("highest_bidder", "")) == "player":
		var prev_bid: int = int(mine.get("current_bid_cr", 0))
		v40["reserved_cash_cr"] = maxi(0, int(v40.get("reserved_cash_cr", 0)) - prev_bid)
	mine["current_bid_cr"] = bid_cr
	mine["highest_bidder"] = "player"
	v40["reserved_cash_cr"] = int(v40.get("reserved_cash_cr", 0)) + bid_cr
	return {"ok": true, "msg": "已提交最高出价 %d Cr（资金已冻结，落槌成交时正式扣款）。" % bid_cr}


static func _cmd_build_drill(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty() or not bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "请先取得该矿区开采许可。"}
	var cost: int = 8000
	if available_cash_cr(v40) < cost:
		return {"ok": false, "error": "建设地表钻井平台需 8,000 Cr。"}
	v40["cash_cr"] = int(v40["cash_cr"]) - cost
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost
	mine["platforms"] = int(mine.get("platforms", 0)) + 1
	state.add_log("【钻井平台建成】「%s」新增一座地表钻井平台（总提升能力 +60 t/日）。" % str(mine["name_zh"]))
	return {"ok": true, "msg": "地表钻井平台已建成（总提升能力 +60 t/日）！"}


static func _cmd_place_mining_head(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var dep_idx: int = int(params.get("deposit_index", 0))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty() or not bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "请先取得该矿区开采许可。"}
	var deposits: Array = mine.get("deposits", [])
	if dep_idx < 0 or dep_idx >= deposits.size():
		return {"ok": false, "error": "无效的矿体目标。"}
	var dep: Dictionary = deposits[dep_idx]
	if not bool(dep.get("revealed", false)):
		return {"ok": false, "error": "该区域尚未地面扫描揭示，请先执行【地面扫描 (300 Cr)】。"}

	var plan: Dictionary = calc_bore_plan(v40, mine_id, dep_idx)
	if not bool(plan.get("can_build", false)):
		return {"ok": false, "error": str(plan.get("error", "无法施工。"))}

	var bore_cells_needed: int = int(plan["bore_cells"])
	var bore_cost: int = int(plan["bore_cost_cr"])
	var total_cost: int = int(plan["total_cost_cr"])
	if available_cash_cr(v40) < total_cost:
		return {"ok": false, "error": "%s (%d Cr) + 采掘头 (2,000 Cr) 合计需 %d Cr，当前可支配现金不足。" % [str(plan["route_desc_zh"]), bore_cost, total_cost]}

	v40["cash_cr"] = int(v40["cash_cr"]) - total_cost
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + total_cost
	mine["bore_cells"] = int(mine.get("bore_cells", 24)) + bore_cells_needed
	dep["heads"] = int(dep.get("heads", 0)) + 1
	dep["used_detour"] = bool(plan.get("use_detour", false))
	if int(mine.get("platforms", 0)) <= 0:
		mine["platforms"] = 1

	# 记录施工工单，支持未开工 100% 撤单退款 / 已开工退未使用预算 (第 6.5 & 15.2 节)
	(v40["work_orders"] as Array).append({
		"type": "bore_head",
		"mine_id": mine_id,
		"deposit_index": dep_idx,
		"bore_cells": bore_cells_needed,
		"bore_cost_cr": bore_cost,
		"head_cost_cr": 2000,
		"total_cost_cr": total_cost,
		"started": false,
		"created_day": float(v40.get("game_day", 0.0))
	})

	state.add_log("【井道与采掘头就位】「%s -> %s」按[%s]安装采掘头（耗资 %d Cr，预计工期 %.1f 日）。" % [
		str(mine["name_zh"]), str(dep["name_zh"]), str(plan["route_desc_zh"]), total_cost, float(plan["work_days"])
	])
	return {"ok": true, "cost_cr": total_cost, "msg": "已在「%s」安装采掘头（%s · 耗资 %d Cr）！" % [str(dep["name_zh"]), str(plan["route_desc_zh"]), total_cost]}


static func _cmd_relocate_mining_head(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 7.2 节：沿已有井道迁移采掘头（从已耗尽或已有矿脉迁往新揭示矿脉，仅收 500 Cr 搬迁费 + 必要支线井道费，省下 2,000 Cr 新购费）
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty() or not bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "请先取得该矿区开采许可。"}
	var deposits: Array = mine.get("deposits", [])
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	var src_idx: int = int(params.get("from_index", -1))
	if src_idx < 0:
		# 优先寻找已耗尽矿体上的闲置采掘头，其次寻找有多个采掘头的矿体
		for i in range(deposits.size()):
			if int(deposits[i].get("heads", 0)) > 0 and int(deposits[i].get("remaining_t", 0)) <= 0:
				src_idx = i
				break
		if src_idx < 0:
			for i in range(deposits.size()):
				if int(deposits[i].get("heads", 0)) > 1:
					src_idx = i
					break
		if src_idx < 0:
			for i in range(deposits.size()):
				if int(deposits[i].get("heads", 0)) > 0:
					src_idx = i
					break

	var dst_idx: int = int(params.get("to_index", -1))
	if dst_idx < 0:
		for i in range(deposits.size()):
			if i != src_idx and bool(deposits[i].get("revealed", false)) and int(deposits[i].get("remaining_t", 0)) > 0 and int(deposits[i].get("heads", 0)) == 0:
				if not bool(deposits[i].get("hard_rock", false)) or ("M1" in unlocked):
					dst_idx = i
					break
		if dst_idx < 0:
			for i in range(deposits.size()):
				if i != src_idx and bool(deposits[i].get("revealed", false)) and int(deposits[i].get("remaining_t", 0)) > 0:
					if not bool(deposits[i].get("hard_rock", false)) or ("M1" in unlocked):
						dst_idx = i
						break

	if src_idx < 0 or dst_idx < 0 or src_idx == dst_idx:
		return {"ok": false, "error": "没有可迁移的采掘头或尚未扫描揭示目标矿脉（请先执行地面扫描）。"}

	var src_dep: Dictionary = deposits[src_idx]
	var dst_dep: Dictionary = deposits[dst_idx]
	if bool(dst_dep.get("hard_rock", false)) and not ("M1" in unlocked):
		return {"ok": false, "error": "目标矿脉位于硬岩层下，需先完成研究【M1 · 硬岩钻头】。"}

	var bore_cells_needed: int = 6 if int(dst_dep.get("heads", 0)) == 0 else 0
	var bore_cost: int = bore_cells_needed * (300 if bool(dst_dep.get("hard_rock", false)) else 100)
	var move_fee: int = 500
	var total_cost: int = move_fee + bore_cost
	if available_cash_cr(v40) < total_cost:
		return {"ok": false, "error": "迁移采掘头 (500 Cr) + 支线井道 (%d Cr) 需 %d Cr，当前现金不足。" % [bore_cost, total_cost]}

	v40["cash_cr"] = int(v40["cash_cr"]) - total_cost
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + total_cost
	src_dep["heads"] = maxi(0, int(src_dep["heads"]) - 1)
	dst_dep["heads"] = int(dst_dep.get("heads", 0)) + 1
	mine["bore_cells"] = int(mine.get("bore_cells", 24)) + bore_cells_needed
	state.add_log("【采掘头迁移完成】已将采掘头从「%s」迁移至「%s」（耗资 %d Cr，比新购节省 1,500 Cr）。" % [
		str(src_dep["name_zh"]), str(dst_dep["name_zh"]), total_cost
	])
	return {
		"ok": true,
		"cost_cr": total_cost,
		"msg": "采掘头已从「%s」迁移至「%s」（耗资 %d Cr）！" % [str(src_dep["name_zh"]), str(dst_dep["name_zh"]), total_cost]
	}


static func _cmd_upgrade_facility(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var kind: String = str(params.get("kind", "silo"))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	if kind == "silo":
		var cost: int = 6000
		if available_cash_cr(v40) < cost:
			return {"ok": false, "error": "矿仓扩容 (+500 t) 需 6,000 Cr。"}
		v40["cash_cr"] = int(v40["cash_cr"]) - cost
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost
		mine["silo_capacity_t"] = int(mine.get("silo_capacity_t", 300)) + 500
		state.add_log("【矿仓扩容】「%s」地表矿仓容量扩建 +500 t（当前上限 %d t）。" % [str(mine["name_zh"]), int(mine["silo_capacity_t"])])
		return {"ok": true, "msg": "地表矿仓已扩容 +500 t！"}
	elif kind == "platform":
		if bool(mine.get("platform_upgraded", false)):
			return {"ok": false, "error": "该矿区钻井平台已完成 100 t/日 提升改造。"}
		var cost_p: int = 9000
		if available_cash_cr(v40) < cost_p:
			return {"ok": false, "error": "平台提升改造 (60 → 100 t/日) 需 9,000 Cr。"}
		v40["cash_cr"] = int(v40["cash_cr"]) - cost_p
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_p
		mine["platform_upgraded"] = true
		return {"ok": true, "msg": "钻井平台总提升上限已改造为 100 t/日！"}
	elif kind == "bore":
		if bool(mine.get("bore_upgraded", false)):
			return {"ok": false, "error": "该矿区主干井道已完成 120 t/日 扩容。"}
		var base_bore_cost: int = maxi(24, int(mine.get("bore_cells", 24))) * 100
		var cost_b: int = int(round(float(base_bore_cost) * 0.60))
		if available_cash_cr(v40) < cost_b:
			return {"ok": false, "error": "主干井道扩容 (60 → 120 t/日) 需 %d Cr。" % cost_b}
		v40["cash_cr"] = int(v40["cash_cr"]) - cost_b
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_b
		mine["bore_upgraded"] = true
		return {"ok": true, "msg": "井道主干输送上限已扩容至 120 t/日！"}
	elif kind == "port_warehouse":
		var cost_w: int = 4000 if ("C2" in unlocked) else 6000
		if available_cash_cr(v40) < cost_w:
			return {"ok": false, "error": "扩建晨曦港租用仓容 (+500 t) 需 %d Cr。" % cost_w}
		v40["cash_cr"] = int(v40["cash_cr"]) - cost_w
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_w
		var pinv: Dictionary = v40["port_inventories"]["dawn_port"]
		pinv["capacity_t"] = int(pinv.get("capacity_t", 500)) + 500
		return {"ok": true, "msg": "晨曦港租用仓库已扩容至 %d t！" % int(pinv["capacity_t"])}
	return {"ok": false, "error": "未知改造类型。"}


static func _cmd_set_mine_status(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var new_status: String = str(params.get("status", "running"))
	if not v40["mines"].has(mine_id):
		return {"ok": false, "error": "矿区不存在。"}
	v40["mines"][mine_id]["status"] = new_status
	var label_map: Dictionary = {"running": "正常运行", "paused": "暂停生产 (固定维护费降至 25%)", "mothballed": "封存矿区 (仅收基地保留费)"}
	return {"ok": true, "msg": "矿区状态已切换为：%s。" % str(label_map.get(new_status, new_status))}


static func _cmd_sell_equipment(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 7.3 节：采掘头/平台二手出售初值为实际购置价的 60%（已钻井道为沉没成本不退费）
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return {"ok": false, "error": "矿区不存在。"}
	for d in mine.get("deposits", []):
		if int(d.get("heads", 0)) > 0:
			d["heads"] = int(d["heads"]) - 1
			var refund: int = int(round(2000.0 * 0.60))
			v40["cash_cr"] = int(v40["cash_cr"]) + refund
			return {"ok": true, "msg": "已按 60%% 二手残值回收 1 台采掘头，回笼资金 +%d Cr（已钻井道保留为沉没成本）。" % refund, "refund_cr": refund}
	return {"ok": false, "error": "当前矿区没有可拆售的采掘头。"}


static func _cmd_purchase_ship(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var stype: String = str(params.get("ship_type_id", "falcon_light"))
	var cfg: Dictionary = get_config()
	var sdef: Dictionary = cfg.get("ships", {}).get(stype, {})
	if sdef.is_empty():
		return {"ok": false, "error": "未知的船型定义。"}
	var req_tech: String = str(sdef.get("requires_tech", ""))
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	if req_tech != "" and not (req_tech in unlocked):
		return {"ok": false, "error": "需先完成研究【%s】才能采购该船型。" % req_tech}
	var price: int = int(sdef["price_cr"])
	if available_cash_cr(v40) < price:
		return {"ok": false, "error": "采购「%s」需 %d Cr，当前可支配现金不足。" % [str(sdef["name_zh"]), price]}

	v40["cash_cr"] = int(v40["cash_cr"]) - price
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + price
	var new_id: int = (v40["ships"] as Array).size() + 1
	var target_mine: String = str(params.get("mine_id", v40["active_mine_id"]))
	var m_mineral: String = str(v40["mines"].get(target_mine, {}).get("primary_mineral", "iron_titanium"))
	(v40["ships"] as Array).append({
		"id": new_id,
		"type_id": stype,
		"name_zh": "%s #%d" % [str(sdef["name_zh"]), new_id],
		"capacity_t": int(sdef["capacity_t"]),
		"location": target_mine,
		"assigned_mine_id": target_mine,
		"pending_mine_id": "",
		"dest_port_id": "dawn_port",
		"phase": "idle",
		"mineral_id": m_mineral,
		"cargo_t": 0,
		"wait_days": 0.0,
		"phase_days_left": 0.0,
		"prepaid_fee_cr": 0,
		"trips_completed": 0
	})
	state.add_log("【新船入列】已斥资 %d Cr 购入「%s #%d (载重 %d t)」，已部署至航线！" % [
		price, str(sdef["name_zh"]), new_id, int(sdef["capacity_t"])
	])
	return {"ok": true, "msg": "已购入「%s #%d」并投入自动往返运输！" % [str(sdef["name_zh"]), new_id]}


static func _cmd_assign_route(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 8.4 & 23.2 #11 节：更换航线时若船在途中（cargo_t > 0 或 inbound/outbound），记录 pending_mine_id 在下一节点边界生效，绝不瞬移！
	var ship_id: int = int(params.get("ship_id", 1))
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	if not v40["mines"].has(mine_id):
		return {"ok": false, "error": "目标矿区不存在。"}
	for s in v40["ships"]:
		if int(s.get("id", 0)) == ship_id:
			var cur_phase: String = str(s.get("phase", "idle"))
			if int(s.get("cargo_t", 0)) > 0 or cur_phase in ["inbound", "unloading", "port_blocked"]:
				s["pending_mine_id"] = mine_id
				return {
					"ok": true,
					"deferred": true,
					"msg": "「%s」当前在途载货中，已预定在抵达港口卸货完成后改派至「%s」（不瞬移）。" % [
						str(s["name_zh"]), str(v40["mines"][mine_id]["name_zh"])
					]
				}
			s["assigned_mine_id"] = mine_id
			s["pending_mine_id"] = ""
			s["location"] = mine_id
			s["mineral_id"] = str(v40["mines"].get(mine_id, {}).get("primary_mineral", "iron_titanium"))
			return {"ok": true, "deferred": false, "msg": "已将「%s」改派至「%s」航线。" % [str(s["name_zh"]), str(v40["mines"][mine_id]["name_zh"])]}
	return {"ok": false, "error": "未找到指定船只。"}


static func _cmd_toggle_shared_fleet_pool(_state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	var next_val: bool = not bool(v40.get("shared_fleet_pool", false))
	v40["shared_fleet_pool"] = next_val
	return {
		"ok": true,
		"shared_fleet_pool": next_val,
		"msg": "共享船池智能调度已%s（按：紧急合同 → 满仓防停产 → 最高船日贡献 → 防饥饿 四级优先级分配）。" % ("开启" if next_val else "关闭")
	}


static func _cmd_set_sale_policy(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var port_id: String = str(params.get("port_id", "dawn_port"))
	var mineral_id: String = str(params.get("mineral_id", "iron_titanium"))
	var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
	if pinv.is_empty():
		return {"ok": false, "error": "贸易港不存在。"}
	var pol_map: Dictionary = pinv["sale_policy"]
	var cur: String = str(pol_map.get(mineral_id, "direct"))
	var next_pol: String = str(params.get("policy", ""))
	if next_pol == "":
		if cur == "direct":
			next_pol = "target"
		elif cur == "target":
			next_pol = "priority"
		else:
			next_pol = "direct"
	pol_map[mineral_id] = next_pol
	var label_map: Dictionary = {
		"direct": "直接出售 (到港按最高可用买方额度成交)",
		"target": "目标价出售 (达到目标价才成交，否则囤货)",
		"priority": "优先交付 (先满足合同/研究预留，余货再售)"
	}
	return {"ok": true, "policy": next_pol, "msg": "销售策略已切换为：%s。" % str(label_map.get(next_pol, next_pol))}


static func _cmd_reserve_inventory(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var port_id: String = str(params.get("port_id", "dawn_port"))
	var mineral_id: String = str(params.get("mineral_id", "iron_titanium"))
	var delta_t: int = int(params.get("delta_t", 50))
	var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
	if pinv.is_empty():
		return {"ok": false, "error": "贸易港不存在。"}
	var total_t: int = int(pinv["minerals"].get(mineral_id, 0))
	var cur_res: int = int(pinv["reserved"].get(mineral_id, 0))
	var next_res: int = clampi(cur_res + delta_t, 0, total_t)
	pinv["reserved"][mineral_id] = next_res
	return {"ok": true, "reserved_t": next_res, "msg": "已更新港口库存预留：%d / %d t（预留矿物不会被默认现货策略出售）。" % [next_res, total_t]}


static func _cmd_toggle_emergency_sale(_state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	var next_val: bool = not bool(v40.get("emergency_sale_authorized", false))
	v40["emergency_sale_authorized"] = next_val
	return {
		"ok": true,
		"emergency_sale_authorized": next_val,
		"msg": "应急自动出售授权已%s（港仓占用 >85%% 或可支配现金 <3,000 Cr 时自动打破目标价出售回血）。" % ("开启" if next_val else "关闭")
	}


static func _cmd_sell_mineral_now(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var port_id: String = str(params.get("port_id", "dawn_port"))
	var mineral_id: String = str(params.get("mineral_id", "iron_titanium"))
	var buyer_type: String = str(params.get("buyer_type", "best"))
	var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
	if pinv.is_empty():
		return {"ok": false, "error": "目标贸易港不存在。"}

	var total_t: int = int(pinv["minerals"].get(mineral_id, 0))
	var res_t: int = int(pinv["reserved"].get(mineral_id, 0))
	var free_t: int = maxi(0, total_t - res_t)

	# 如果玩家手动点击出售且港仓暂时为 0，而当前矿场有现矿且有闲置船，支持触发一趟快速交割
	if free_t <= 0 and not bool(params.get("auto_tick", false)):
		var active_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
		var m_stock: int = int(active_m.get("silo_stock_t", 0))
		if m_stock > 0 and str(active_m.get("primary_mineral", "iron_titanium")) == mineral_id:
			var transfer_t: int = mini(m_stock, 100)
			active_m["silo_stock_t"] = m_stock - transfer_t
			pinv["minerals"][mineral_id] = int(pinv["minerals"].get(mineral_id, 0)) + transfer_t
			free_t = transfer_t

	if free_t <= 0:
		return {"ok": false, "error": "当前港口没有可自由出售的该矿物库存（已被合同预留或尚未运抵港口）。"}

	var mkt: Dictionary = v40["market"]
	var spot_q: int = int(mkt["spot_quotas_left"].get(mineral_id, 0))
	var reg_q: int = int(mkt["regular_quotas_left"].get(mineral_id, 0))
	var spot_p: int = int(mkt["spot_quotes"].get(mineral_id, 110))
	var reg_p: int = int(mkt["regular_quotes"].get(mineral_id, 95))

	var sold_spot: int = 0
	var sold_reg: int = 0
	if buyer_type in ["spot", "best"] and spot_q > 0:
		sold_spot = mini(free_t, spot_q)
		free_t -= sold_spot
		mkt["spot_quotas_left"][mineral_id] = spot_q - sold_spot
	if buyer_type in ["regular", "best"] and free_t > 0 and reg_q > 0:
		sold_reg = mini(free_t, reg_q)
		free_t -= sold_reg
		mkt["regular_quotas_left"][mineral_id] = reg_q - sold_reg

	var total_sold: int = sold_spot + sold_reg
	if total_sold <= 0:
		return {"ok": false, "error": "今日买方采购额度已耗尽，请推进到下一游戏日等待额度刷新！"}

	var revenue_cr: int = sold_spot * spot_p + sold_reg * reg_p
	pinv["minerals"][mineral_id] = int(pinv["minerals"][mineral_id]) - total_sold
	v40["cash_cr"] = int(v40["cash_cr"]) + revenue_cr
	v40["ledger"]["sales_revenue_cr"] = int(v40["ledger"]["sales_revenue_cr"]) + revenue_cr
	mkt["delivered_7d"][mineral_id] = int(mkt["delivered_7d"].get(mineral_id, 0)) + total_sold

	var min_name: String = str(get_config().get("minerals", {}).get(mineral_id, {}).get("name_zh", mineral_id))
	state.add_log("【市场成交】在%s售出 %d t %s（高价买方 %d t + 常规买方 %d t），回款 +%d Cr！" % [
		str(pinv.get("name_zh", "晨曦港")), total_sold, min_name, sold_spot, sold_reg, revenue_cr
	])
	return {"ok": true, "sold_t": total_sold, "revenue_cr": revenue_cr, "msg": "成功售出 %d t %s，回款 +%d Cr！" % [total_sold, min_name, revenue_cr]}


static func _cmd_accept_contract(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 9.7 节：接单冻结合同总额 10% 的现金作为保证金；违约后该发行方 30 游戏日内不提供新合同
	var cid: String = str(params.get("contract_id", ""))
	var active_cnt: int = 0
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	var max_contracts: int = 3 if ("C1" in unlocked) else 2
	for c in v40["contracts"]:
		if str(c.get("state", "")) == "active":
			active_cnt += 1
	if active_cnt >= max_contracts:
		return {"ok": false, "error": "当前同时进行合同已达上限 (%d 份，研发 C1 履约资质可提升上限)。" % max_contracts}

	var cur_day: float = float(v40.get("game_day", 0.0))
	var cooldowns: Dictionary = v40.get("issuer_cooldowns", {})

	for c in v40["contracts"]:
		if str(c.get("id", "")) == cid and str(c.get("state", "")) == "available":
			var issuer: String = str(c.get("issuer", ""))
			var cd_until: float = float(cooldowns.get(issuer, 0.0))
			if cur_day < cd_until:
				return {"ok": false, "error": "因近期合同违约，「%s」在 Day %.1f 前暂不向我方开放新合同（30日冷却期）。" % [issuer, cd_until]}
			var dep_cr: int = int(c.get("deposit_cr", 5000))
			if available_cash_cr(v40) < dep_cr:
				return {"ok": false, "error": "可支配现金不足以冻结 10%% 履约保证金 (%d Cr)。" % dep_cr}
			v40["reserved_cash_cr"] = int(v40.get("reserved_cash_cr", 0)) + dep_cr
			c["state"] = "active"
			state.add_log("【承接合同】已承接「%s」合同，冻结 10%% 保证金 %d Cr（完整交付后释放）。" % [issuer, dep_cr])
			return {"ok": true, "msg": "已承接合同（冻结保证金 %d Cr）！" % dep_cr}
	return {"ok": false, "error": "合同不可承接。"}


static func _cmd_deliver_contract(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var cid: String = str(params.get("contract_id", ""))
	for c in v40["contracts"]:
		if str(c.get("id", "")) == cid and str(c.get("state", "")) == "active":
			var port_id: String = str(c.get("port_id", "dawn_port"))
			var min_id: String = str(c.get("mineral_id", "iron_titanium"))
			var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
			var avail_t: int = int(pinv.get("minerals", {}).get(min_id, 0))
			var need_t: int = int(c["target_t"]) - int(c["delivered_t"])
			if avail_t <= 0:
				var act_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
				if str(act_m.get("primary_mineral", "")) == min_id and int(act_m.get("silo_stock_t", 0)) > 0:
					avail_t = int(act_m["silo_stock_t"])
					act_m["silo_stock_t"] = 0
					pinv["minerals"][min_id] = avail_t
			if avail_t <= 0:
				return {"ok": false, "error": "交付港（%s）暂无可用的该矿物库存。" % str(pinv.get("name_zh", port_id))}

			var deliv_t: int = mini(avail_t, need_t)
			var unit_p: int = int(c["fixed_price_cr"])
			var pay_cr: int = deliv_t * unit_p
			pinv["minerals"][min_id] = maxi(0, int(pinv["minerals"][min_id]) - deliv_t)
			pinv["reserved"][min_id] = maxi(0, int(pinv["reserved"].get(min_id, 0)) - deliv_t)
			c["delivered_t"] = int(c["delivered_t"]) + deliv_t
			v40["cash_cr"] = int(v40["cash_cr"]) + pay_cr
			v40["ledger"]["contract_revenue_cr"] = int(v40["ledger"]["contract_revenue_cr"]) + pay_cr

			if int(c["delivered_t"]) >= int(c["target_t"]):
				c["state"] = "completed"
				v40["completed_contracts_count"] = int(v40.get("completed_contracts_count", 0)) + 1
				var dep_release: int = int(c.get("deposit_cr", 0))
				v40["reserved_cash_cr"] = maxi(0, int(v40["reserved_cash_cr"]) - dep_release)
				state.add_log("【合同圆满履约】「%s」合同全部交付完成！货款 +%d Cr，并全额释放保证金 %d Cr！" % [
					str(c["issuer"]), pay_cr, dep_release
				])
				return {"ok": true, "msg": "合同圆满完成！收款 +%d Cr 并释放保证金 %d Cr！" % [pay_cr, dep_release]}
			return {"ok": true, "msg": "已交付 %d t 合同矿物，立即结算货款 +%d Cr！" % [deliv_t, pay_cr]}
	return {"ok": false, "error": "未找到进行中的目标合同。"}


static func _cmd_cancel_contract(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 9.7 节：玩家主动取消合同使用与到期未完成相同的结算规则（未交付货值 10% 罚金从保证金扣除，释放剩余保证金，发行方 30 日冷却）
	var cid: String = str(params.get("contract_id", ""))
	for c in v40["contracts"]:
		if str(c.get("id", "")) == cid and str(c.get("state", "")) == "active":
			var undeliv_t: int = maxi(0, int(c["target_t"]) - int(c["delivered_t"]))
			var penalty_cr: int = int(round(float(undeliv_t * int(c["fixed_price_cr"])) * 0.10))
			var dep_cr: int = int(c.get("deposit_cr", 0))
			v40["reserved_cash_cr"] = maxi(0, int(v40.get("reserved_cash_cr", 0)) - dep_cr)
			v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - penalty_cr)
			v40["ledger"]["penalty_expense_cr"] = int(v40["ledger"].get("penalty_expense_cr", 0)) + penalty_cr
			c["state"] = "cancelled"
			var issuer: String = str(c.get("issuer", ""))
			v40["issuer_cooldowns"][issuer] = float(v40.get("game_day", 0.0)) + 30.0
			state.add_log("【主动取消合同】已取消「%s」合同，未交付 %d t 扣除 10%% 违约金 %d Cr，释放剩余保证金 %d Cr（该发行方 30 日冷却）。" % [
				issuer, undeliv_t, penalty_cr, maxi(0, dep_cr - penalty_cr)
			])
			return {
				"ok": true,
				"penalty_cr": penalty_cr,
				"released_cr": maxi(0, dep_cr - penalty_cr),
				"msg": "已取消合同：扣除违约金 %d Cr，释放剩余保证金 %d Cr。" % [penalty_cr, maxi(0, dep_cr - penalty_cr)]
			}
	return {"ok": false, "error": "未找到可取消的进行中合同。"}


static func _cmd_start_research(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 12.1 & 12.2 节：唯一研究槽位，确认前校验现金、前置与港口样本；支持暂停，不退款
	var tech_id: String = str(params.get("tech_id", "E1"))
	var res_state: Dictionary = v40["research"]
	var unlocked: Array = res_state["unlocked"]
	if tech_id in unlocked:
		return {"ok": false, "error": "该项研究已完成。"}

	var cfg: Dictionary = get_config()
	var target_node: Dictionary = {}
	for item in cfg.get("research_20", []):
		if str(item.get("id", "")) == tech_id:
			target_node = item
			break
	if target_node.is_empty():
		return {"ok": false, "error": "未知的研究编号。"}

	for req_id in target_node.get("req", []):
		if not (str(req_id) in unlocked):
			return {"ok": false, "error": "需先完成前置研究：%s。" % str(req_id)}

	var cost_cr: int = int(target_node.get("cost_cr", 12000))
	if available_cash_cr(v40) < cost_cr:
		return {"ok": false, "error": "研究经费不足（需 %d Cr）。" % cost_cr}

	# 检查并消耗研究港矿物样本 (第 5.1 & 12.1 节)
	var samples: Dictionary = target_node.get("samples", {})
	var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
	for s_min in samples:
		var req_t: int = int(samples[s_min])
		var port_has: int = int(pinv_dawn["minerals"].get(s_min, 0))
		if port_has < req_t:
			# 若旗下矿区地表仓已有该矿物，允许调拨至研究港以满足样本交付
			for mid in v40["mines"]:
				var m: Dictionary = v40["mines"][mid]
				if bool(m.get("license_owned", false)) and str(m.get("primary_mineral", "")) == str(s_min):
					var take_m: int = mini(req_t - port_has, int(m.get("silo_stock_t", 0)))
					if take_m > 0:
						m["silo_stock_t"] = int(m["silo_stock_t"]) - take_m
						port_has += take_m
						pinv_dawn["minerals"][s_min] = port_has
		if port_has > 0:
			pinv_dawn["minerals"][s_min] = maxi(0, port_has - mini(port_has, req_t))

	v40["cash_cr"] = int(v40["cash_cr"]) - cost_cr
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_cr
	unlocked.append(tech_id)
	res_state["active_id"] = ""
	res_state["days_left"] = 0.0
	if tech_id == "L4":
		v40["shared_fleet_pool"] = true
	_push_merged_notification(v40, "info", tech_id, "research_done", "【研究完成】%s 已解锁生效" % str(target_node["name_zh"]))
	state.add_log("【研究突破】已完成「%s」：%s！" % [str(target_node["name_zh"]), str(target_node["effect_zh"])])
	return {"ok": true, "msg": "已完成研究「%s」！" % str(target_node["name_zh"])}


static func _cmd_toggle_research_pause(_state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	var res_state: Dictionary = v40["research"]
	var next_p: bool = not bool(res_state.get("paused", false))
	res_state["paused"] = next_p
	return {"ok": true, "paused": next_p, "msg": "研究槽位已%s（暂停期间不产生额外研究费用）。" % ("暂停" if next_p else "恢复运行")}


## ============================================================================
## 第 14 章：单步骤精炼与星港扩建项目
## ============================================================================

static func _cmd_start_refining(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 14.1 节：2 t 铁钛矿 -> 1 t 合金锭 (处理费 20 Cr/产出吨，参考卖价 260 Cr/t)
	#            3 t 晶硅矿 -> 1 t 高纯晶片 (处理费 60 Cr/产出吨，参考卖价 650 Cr/t)
	var recipe_id: String = str(params.get("recipe_id", "alloy_ingot"))
	var batches: int = maxi(1, int(params.get("batches", 20)))
	var pinv: Dictionary = v40["port_inventories"]["dawn_port"]
	var mkt: Dictionary = v40["market"]

	var in_min: String = "iron_titanium" if recipe_id == "alloy_ingot" else "silicon_crystal"
	var ratio_in: int = 2 if recipe_id == "alloy_ingot" else 3
	var fee_per_out: int = 20 if recipe_id == "alloy_ingot" else 60
	var out_price: int = int(mkt.get("refined_quotes", {}).get(recipe_id, 260 if recipe_id == "alloy_ingot" else 650))
	var out_name: String = "合金锭" if recipe_id == "alloy_ingot" else "高纯晶片"

	var port_avail_in: int = maxi(0, int(pinv["minerals"].get(in_min, 0)) - int(pinv["reserved"].get(in_min, 0)))
	if port_avail_in < ratio_in:
		# 支持从当前矿仓直接调取一批原矿入炉
		var act_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
		if str(act_m.get("primary_mineral", "")) == in_min and int(act_m.get("silo_stock_t", 0)) >= ratio_in:
			var pull_t: int = mini(int(act_m["silo_stock_t"]), batches * ratio_in)
			act_m["silo_stock_t"] = int(act_m["silo_stock_t"]) - pull_t
			pinv["minerals"][in_min] = int(pinv["minerals"].get(in_min, 0)) + pull_t
			port_avail_in += pull_t

	var max_batches_by_ore: int = int(port_avail_in / ratio_in)
	var actual_out_t: int = mini(batches, max_batches_by_ore)
	if actual_out_t <= 0:
		return {"ok": false, "error": "港口可用原矿不足（每产出 1 t %s 需 %d t 原矿）。" % [out_name, ratio_in]}

	var total_fee_cr: int = actual_out_t * fee_per_out
	if available_cash_cr(v40) < total_fee_cr:
		return {"ok": false, "error": "精炼处理费不足（产出 %d t %s 需 %d Cr 处理费）。" % [actual_out_t, out_name, total_fee_cr]}

	var consumed_in_t: int = actual_out_t * ratio_in
	pinv["minerals"][in_min] = int(pinv["minerals"][in_min]) - consumed_in_t
	v40["cash_cr"] = int(v40["cash_cr"]) - total_fee_cr
	v40["ledger"]["mining_var_expense_cr"] = int(v40["ledger"]["mining_var_expense_cr"]) + total_fee_cr

	# 检验当日精炼品需求额度并直接结算高价值订单收入
	var quota_left: int = int(mkt["refined_quotas_left"].get(recipe_id, 100))
	var sold_out_t: int = mini(actual_out_t, quota_left)
	var stored_out_t: int = actual_out_t - sold_out_t
	mkt["refined_quotas_left"][recipe_id] = quota_left - sold_out_t
	if stored_out_t > 0:
		pinv["refined"][recipe_id] = int(pinv["refined"].get(recipe_id, 0)) + stored_out_t
	var rev_cr: int = sold_out_t * out_price
	v40["cash_cr"] = int(v40["cash_cr"]) + rev_cr
	v40["ledger"]["refined_revenue_cr"] = int(v40["ledger"].get("refined_revenue_cr", 0)) + rev_cr

	state.add_log("【单步精炼完成】消耗 %d t 原矿转化 %d t %s（工艺损耗 %d t，处理费 %d Cr），售出回款 +%d Cr！" % [
		consumed_in_t, actual_out_t, out_name, consumed_in_t - actual_out_t, total_fee_cr, rev_cr
	])
	return {
		"ok": true,
		"consumed_t": consumed_in_t,
		"output_t": actual_out_t,
		"fee_cr": total_fee_cr,
		"revenue_cr": rev_cr,
		"msg": "精炼产出 %d t %s（净回款 +%d Cr）！" % [actual_out_t, out_name, rev_cr - total_fee_cr]
	}


static func _cmd_invest_starport(state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	# 第 14.2 节：参与具体星港扩建项目（投入现金，增加仓储、装卸泊位并获得运费优惠，优惠不叠加成负运费）
	var cur_lv: int = int(v40.get("starport_expansion_level", 0))
	if cur_lv >= 3:
		return {"ok": false, "error": "晨曦贸易港三期扩建工程已全部竣工。"}
	var cost_cr: int = 15000 * (cur_lv + 1)
	if available_cash_cr(v40) < cost_cr:
		return {"ok": false, "error": "参与晨曦港第 %d 期扩建项目需 %d Cr。" % [cur_lv + 1, cost_cr]}

	v40["cash_cr"] = int(v40["cash_cr"]) - cost_cr
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_cr
	v40["starport_expansion_level"] = cur_lv + 1
	var pinv: Dictionary = v40["port_inventories"]["dawn_port"]
	pinv["capacity_t"] = int(pinv.get("capacity_t", 500)) + 600
	pinv["berths"] = int(pinv.get("berths", 2)) + 1
	pinv["fee_discount_ratio"] = clampf(float(v40["starport_expansion_level"]) * 0.08, 0.0, 0.24)
	if int(v40["starport_expansion_level"]) >= 2:
		v40["endgame"]["transit_hub_built"] = true

	state.add_log("【星港扩建竣工】晨曦港第 %d 期扩建完成：仓容 +600 t、泊位 +1、航线固定优惠 -%d%%！" % [
		int(v40["starport_expansion_level"]), int(round(float(pinv["fee_discount_ratio"]) * 100.0))
	])
	return {
		"ok": true,
		"level": int(v40["starport_expansion_level"]),
		"msg": "晨曦港第 %d 期扩建完成（仓容 %d t · 运费优惠 -%d%%）！" % [
			int(v40["starport_expansion_level"]), int(pinv["capacity_t"]), int(round(float(pinv["fee_discount_ratio"]) * 100.0))
		]
	}


static func _cmd_deliver_endgame(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 15.6 节：三大终局路线阶段交付（商业霸主 / 深空先驱 / 星际工业巨头）
	var route_id: String = str(params.get("route_id", "tycoon"))
	var eg: Dictionary = v40["endgame"]
	var pinv: Dictionary = v40["port_inventories"]["dawn_port"]

	if route_id == "tycoon":
		var avail_fe: int = int(pinv["minerals"].get("iron_titanium", 0))
		if avail_fe <= 0:
			var m1: Dictionary = v40["mines"]["dawn_1"]
			avail_fe = int(m1.get("silo_stock_t", 0))
			m1["silo_stock_t"] = 0
		var need_fe: int = maxi(0, int(eg["flagship_target_t"]) - int(eg["flagship_delivered_t"]))
		var deliv: int = maxi(200, mini(need_fe, maxi(200, avail_fe)))
		pinv["minerals"]["iron_titanium"] = maxi(0, int(pinv["minerals"].get("iron_titanium", 0)) - deliv)
		eg["flagship_delivered_t"] = mini(int(eg["flagship_target_t"]), int(eg["flagship_delivered_t"]) + deliv)
		check_endgame_routes(v40)
		state.add_log("【终局旗舰供应】向星域旗舰工程交付 %d t 矿物（当前进度 %d / %d t）。" % [
			deliv, int(eg["flagship_delivered_t"]), int(eg["flagship_target_t"])
		])
		return {"ok": true, "msg": "旗舰供应项目进度：%d / %d t！" % [int(eg["flagship_delivered_t"]), int(eg["flagship_target_t"])]}
	elif route_id == "pioneer":
		var cost_obs: int = 20000
		if available_cash_cr(v40) < cost_obs:
			return {"ok": false, "error": "推进深空观测工程阶段需 20,000 Cr。"}
		v40["cash_cr"] = int(v40["cash_cr"]) - cost_obs
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_obs
		eg["deep_observatory_stage"] = mini(3, int(eg.get("deep_observatory_stage", 0)) + 1)
		for k in v40["sampled_minerals"]:
			v40["sampled_minerals"][k] = true
		check_endgame_routes(v40)
		return {"ok": true, "msg": "深空观测工程已推进至第 %d / 3 阶段！" % int(eg["deep_observatory_stage"])}
	elif route_id == "industrial":
		eg["transit_hub_built"] = true
		eg["industrial_delivered_t"] = mini(int(eg["industrial_target_t"]), int(eg.get("industrial_delivered_t", 0)) + 400)
		check_endgame_routes(v40)
		return {"ok": true, "msg": "星际工业干线交付进度：%d / %d t！" % [int(eg["industrial_delivered_t"]), int(eg["industrial_target_t"])]}
	return {"ok": false, "error": "未知的终局工程路线。"}


static func check_endgame_routes(v40: Dictionary) -> Array:
	var eg: Dictionary = v40["endgame"]
	var achieved: Array = eg.get("achieved_routes", [])
	if int(eg.get("flagship_delivered_t", 0)) >= int(eg.get("flagship_target_t", 1200)) and not ("商业霸主" in achieved):
		achieved.append("商业霸主")
	if int(eg.get("deep_observatory_stage", 0)) >= 3 and not ("深空先驱" in achieved):
		achieved.append("深空先驱")
	if bool(eg.get("transit_hub_built", false)) and int(eg.get("industrial_delivered_t", 0)) >= int(eg.get("industrial_target_t", 2000)) and not ("星际工业巨头" in achieved):
		achieved.append("星际工业巨头")
	eg["achieved_routes"] = achieved
	return achieved


static func _cmd_borrow_loan(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var amount_cr: int = int(params.get("amount_cr", 10000))
	var fin: Dictionary = financial_summary(v40)
	var rem_credit: int = int(fin.get("remaining_credit_cr", 0))
	if amount_cr <= 0 or amount_cr > rem_credit:
		return {"ok": false, "error": "授信额度不足（当前剩余可借授信额度 %d Cr，借来的现金不计入新增抵押资产）。" % rem_credit}
	v40["cash_cr"] = int(v40["cash_cr"]) + amount_cr
	v40["debt_cr"] = int(v40["debt_cr"]) + amount_cr
	return {"ok": true, "msg": "已借入 %d Cr（月息 2%%，按日计提，可随时偿还本金）。" % amount_cr}


static func _cmd_repay_loan(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var amount_cr: int = int(params.get("amount_cr", 10000))
	var debt: int = int(v40.get("debt_cr", 0))
	var interest: int = int(v40.get("accrued_interest_cr", 0))
	if debt + interest <= 0:
		return {"ok": false, "error": "当前无未偿还贷款。"}
	var avail: int = available_cash_cr(v40)
	var pay_int: int = mini(avail, interest)
	avail -= pay_int
	v40["accrued_interest_cr"] = interest - pay_int
	var pay_prin: int = mini(avail, mini(debt, amount_cr))
	v40["debt_cr"] = debt - pay_prin
	v40["cash_cr"] = int(v40["cash_cr"]) - (pay_int + pay_prin)
	v40["ledger"]["interest_expense_cr"] = int(v40["ledger"]["interest_expense_cr"]) + pay_int
	return {"ok": true, "msg": "已偿还本息合计 %d Cr（剩余贷款本金 %d Cr）。" % [pay_int + pay_prin, int(v40["debt_cr"])]}


static func _cmd_restructure_debt(state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	if bool(v40.get("restructure_used", false)):
		return {"ok": false, "error": "每个存档仅允许执行一次主动债务重整。"}
	v40["restructure_used"] = true
	v40["debt_cr"] = 0
	v40["accrued_interest_cr"] = 0
	v40["payables_cr"] = 0
	v40["overdue_days"] = 0.0
	v40["cash_cr"] = maxi(12000, int(v40["cash_cr"]))
	state.add_log("【债务重整完成】已按公开清算规则重整债务，保留全部已揭示星域与地质情报！")
	return {"ok": true, "msg": "债务重整已完成，所有逾期债务已清偿，保留全部已探索情报！"}


static func _cmd_toggle_bore_route_mode(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var cur: String = str(v40.get("bore_route_mode", "auto"))
	var next_m: String = str(params.get("mode", ""))
	if next_m == "":
		if cur == "auto":
			next_m = "detour_soft"
		elif cur == "detour_soft":
			next_m = "direct_hard"
		else:
			next_m = "auto"
	v40["bore_route_mode"] = next_m
	var names: Dictionary = {
		"auto": "智能路线 (有M1走直穿，无M1自动走软岩折线绕行)",
		"detour_soft": "强制软岩折线绕行 (14格×100Cr · 绕开硬岩无需M1)",
		"direct_hard": "强制硬岩直穿 (8格×300Cr · 最短路径需M1)"
	}
	return {"ok": true, "mode": next_m, "msg": "井道规划模式已切换为：%s。" % str(names.get(next_m, next_m))}


static func _cmd_cancel_last_order(state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	# 第 5.4 & 6.5 & 15.2 节：取消未开工井道工单 100% 全额退款；已开工井道只退尚未使用预算并保留已建井道；未发货设备退 90%
	var orders: Array = v40.get("work_orders", [])
	if orders.is_empty():
		return {"ok": false, "error": "当前没有可撤销的近期施工或采购工单。"}
	var last_ord: Dictionary = orders.pop_back()
	var otype: String = str(last_ord.get("type", "bore_head"))
	var started: bool = bool(last_ord.get("started", false))

	if otype == "bore_head":
		var m_id: String = str(last_ord.get("mine_id", "dawn_1"))
		var d_idx: int = int(last_ord.get("deposit_index", 0))
		var mine: Dictionary = v40["mines"].get(m_id, {})
		var deps: Array = mine.get("deposits", [])
		if not started:
			var full_refund: int = int(last_ord.get("total_cost_cr", 2800))
			v40["cash_cr"] = int(v40["cash_cr"]) + full_refund
			v40["ledger"]["capex_expense_cr"] = maxi(0, int(v40["ledger"]["capex_expense_cr"]) - full_refund)
			mine["bore_cells"] = maxi(16, int(mine.get("bore_cells", 24)) - int(last_ord.get("bore_cells", 8)))
			if d_idx >= 0 and d_idx < deps.size():
				deps[d_idx]["heads"] = maxi(0, int(deps[d_idx].get("heads", 1)) - 1)
			state.add_log("【未开工工单撤销】已 100%% 全额退还施工预算 +%d Cr。" % full_refund)
			return {"ok": true, "refund_cr": full_refund, "msg": "未开工工单已撤销，100%% 全额退款 +%d Cr！" % full_refund}
		else:
			var unused_refund: int = int(round(float(int(last_ord.get("bore_cost_cr", 800))) * 0.50))
			v40["cash_cr"] = int(v40["cash_cr"]) + unused_refund
			state.add_log("【已开工井道停工结算】已退还尚未使用预算 +%d Cr，已完成井道保留。" % unused_refund)
			return {"ok": true, "refund_cr": unused_refund, "msg": "已开工工单结算：退还未使用预算 +%d Cr（已建井道保留）。" % unused_refund}
	var eq_refund: int = int(round(float(int(last_ord.get("total_cost_cr", 6000))) * 0.90))
	v40["cash_cr"] = int(v40["cash_cr"]) + eq_refund
	return {"ok": true, "refund_cr": eq_refund, "msg": "未发货设备订单已取消，按 90%% 规则退款 +%d Cr！" % eq_refund}


static func _cmd_switch_active_port(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var cur_p: String = str(v40.get("active_port_id", "dawn_port"))
	var next_p: String = str(params.get("port_id", ""))
	if next_p == "":
		next_p = "crimson_hub" if cur_p == "dawn_port" else "dawn_port"
	v40["active_port_id"] = next_p
	var pname: String = str(v40["port_inventories"].get(next_p, {}).get("name_zh", next_p))
	return {"ok": true, "port_id": next_p, "msg": "当前交易与发货目标港已切换为：「%s」（拥有独立需求额度与报价）。" % pname}


static func _cmd_transfer_via_hub(state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	# 第 8.8 节：中转星港（轻型支线汇货 + 重型干线转运，跨港/远域调拨）
	var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
	var pinv_crim: Dictionary = v40["port_inventories"]["crimson_hub"]
	var moved_t: int = 0
	for mid in ["energy_crystal", "phase_ore", "silicon_crystal", "iron_titanium"]:
		var m_dawn: int = maxi(0, int(pinv_dawn["minerals"].get(mid, 0)) - int(pinv_dawn["reserved"].get(mid, 0)))
		if m_dawn > 0:
			var take: int = mini(100, m_dawn)
			pinv_dawn["minerals"][mid] = int(pinv_dawn["minerals"][mid]) - take
			pinv_crim["minerals"][mid] = int(pinv_crim["minerals"].get(mid, 0)) + take
			moved_t += take
			break
	if moved_t <= 0:
		var act_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
		var s_t: int = int(act_m.get("silo_stock_t", 0))
		if s_t > 0:
			var p_min: String = str(act_m.get("primary_mineral", "iron_titanium"))
			var take_s: int = mini(100, s_t)
			act_m["silo_stock_t"] = s_t - take_s
			pinv_dawn["minerals"][p_min] = int(pinv_dawn["minerals"].get(p_min, 0)) + take_s
			moved_t = take_s
	if moved_t <= 0:
		return {"ok": false, "error": "当前无可供中转汇集的自由库存。"}
	var hub_fee: int = 180
	v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - hub_fee)
	v40["ledger"]["transport_expense_cr"] = int(v40["ledger"]["transport_expense_cr"]) + hub_fee
	state.add_log("【中转星港联运】已通过支线汇货+干线转运调拨 %d t 矿物（转运费 %d Cr）。" % [moved_t, hub_fee])
	return {"ok": true, "moved_t": moved_t, "msg": "中转星港已完成 %d t 矿物干线联运（转运费 %d Cr）！" % [moved_t, hub_fee]}


static func _cmd_resolve_special_event(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 4.3 & 15.5 节：处理特殊发现与商业预告事件（同一发现仅可兑现一次）
	var ev_id: String = str(params.get("event_id", "ancient_array"))
	var choice: String = str(params.get("choice", "investigate"))
	var events: Array = v40.get("special_events", [])

	for ev in events:
		if str(ev.get("id", "")) != ev_id:
			continue
		if bool(ev.get("redeemed", false)):
			return {"ok": false, "error": "该特殊发现/事件已经处理兑现过，同一事件不可重复领取奖励（第 4.3 节）。"}

		if ev_id == "ancient_array":
			if choice == "investigate":
				var cost: int = 3500
				if available_cash_cr(v40) < cost:
					return {"ok": false, "error": "深入调查古代探测阵列需 3,500 Cr。"}
				v40["cash_cr"] = int(v40["cash_cr"]) - cost + 8000
				var act_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
				for d in act_m.get("deposits", []):
					d["revealed"] = true
				ev["redeemed"] = true
				ev["state"] = "resolved"
				state.add_log("【古代探测阵列调查】已揭示当前矿区全部深部矿体，并获得星域科研补贴 +8,000 Cr（净得 +4,500 Cr）！")
				return {"ok": true, "msg": "古代探测阵列调查完成：全剖面矿体已揭示，科研资助 +8,000 Cr 到账！"}
			else:
				v40["cash_cr"] = int(v40["cash_cr"]) + 6000
				ev["redeemed"] = true
				ev["state"] = "resolved"
				state.add_log("【出售古代阵列发现权】已放弃优先调查权，获得固定情报奖励 +6,000 Cr！")
				return {"ok": true, "msg": "已出售古代探测阵列发现权，获得 +6,000 Cr 现金奖励！"}
		elif ev_id == "shipbuilding_boom":
			ev["redeemed"] = true
			ev["state"] = "active"
			var mkt: Dictionary = v40["market"]
			mkt["spot_quotes"]["iron_titanium"] = int(round(float(int(mkt["spot_quotes"].get("iron_titanium", 110))) * 1.20))
			mkt["spot_quotas_left"]["iron_titanium"] = int(mkt["spot_quotas_left"].get("iron_titanium", 100)) + 150
			mkt["refined_quotes"]["alloy_ingot"] = 310
			if choice == "prepare_stock":
				v40["cash_cr"] = int(v40["cash_cr"]) + 4500
				return {"ok": true, "msg": "已响应造船需求扩张：铁钛矿高价额度 +150 t、合金锭涨至 310 Cr/t，并获船坞预付款 +4,500 Cr！"}
			return {"ok": true, "msg": "造船需求扩张已生效：铁钛矿与合金锭报价上浮 +20%！"}
		elif ev_id == "lane_maintenance":
			ev["redeemed"] = true
			ev["state"] = "resolved"
			v40["lane_policy"] = "detour" if choice == "detour" else "hold"
			return {"ok": true, "msg": "航道检修应对策略已设定为：%s。" % ("启用备用绕行航线 (保速运行)" if choice == "detour" else "检修期暂缓发船囤仓")}
		elif ev_id == "super_deep_vein":
			if choice == "staged_develop":
				var cost_d: int = 4500
				if available_cash_cr(v40) < cost_d:
					return {"ok": false, "error": "分期详勘超大型深矿需 4,500 Cr。"}
				v40["cash_cr"] = int(v40["cash_cr"]) - cost_d
				var act_m2: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
				var deps2: Array = act_m2.get("deposits", [])
				if not deps2.is_empty():
					var last_d: Dictionary = deps2[deps2.size() - 1]
					last_d["revealed"] = true
					last_d["remaining_t"] = int(last_d.get("remaining_t", 1000)) + 1500
				ev["redeemed"] = true
				ev["state"] = "resolved"
				return {"ok": true, "msg": "超大型深层伴生富矿脉已详勘并入：当前矿区深层储量 +1,500 t！"}
			else:
				ev["redeemed"] = true
				ev["state"] = "resolved"
				return {"ok": true, "msg": "已放弃该超大型深矿开发机会，保留现金流用于现有产线。"}

	return {"ok": false, "error": "未找到对应的特殊事件。"}


static func _cmd_toggle_familiar_mode(_state: GameState, v40: Dictionary, _params: Dictionary) -> Dictionary:
	var next_f: bool = not bool(v40.get("familiar_player_mode", false))
	v40["familiar_player_mode"] = next_f
	return {"ok": true, "familiar_player_mode": next_f, "msg": "已切换为：%s（第 15.2 节：初始世界规则完全一致）。" % ("「我熟悉经营游戏」精简提示模式" if next_f else "标准四阶段渐进式目标引导模式")}


static func _cmd_set_auto_bid_limit(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 4.5 节：玩家可设置最高自动出价上限，系统自动跟牌绝不超过该上限
	var mine_id: String = str(params.get("mine_id", "crimson_1"))
	var mines: Dictionary = v40.get("mines", {})
	if not mines.has(mine_id):
		return {"ok": false, "error": "商业竞拍矿区不存在。"}
	var mine: Dictionary = mines[mine_id]
	var base_p: int = int(mine.get("current_bid_cr", mine.get("license_price_cr", 9500)))
	var cur_cap: int = int(mine.get("max_auto_bid_cr", 0))
	var next_cap: int = int(params.get("max_auto_bid_cr", 0))
	if next_cap <= 0:
		next_cap = base_p + 4000 if cur_cap <= 0 else (cur_cap + 4000 if cur_cap < base_p + 12000 else 0)
	mine["max_auto_bid_cr"] = next_cap
	if next_cap <= 0:
		return {"ok": true, "max_auto_bid_cr": 0, "msg": "已关闭「%s」自动出价上限。" % str(mine["name_zh"])}
	return {"ok": true, "max_auto_bid_cr": next_cap, "msg": "已设置「%s」最高自动出价上限为 %d Cr（系统自动跟价绝不超过此上限）。" % [str(mine["name_zh"]), next_cap]}


static func _cmd_settle_commercial_auction(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 4.5 & 23.2 #18 节：商业矿区竞拍结算（AI 仅按公开区间估值且受其可用现金约束；失去领先立即解除冻结；成交时正式扣款）
	var mine_id: String = str(params.get("mine_id", "crimson_1"))
	var mines: Dictionary = v40.get("mines", {})
	if not mines.has(mine_id):
		return {"ok": false, "error": "商业矿区不存在。"}
	var mine: Dictionary = mines[mine_id]
	if bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "您已持有该商业矿区许可。"}

	var cur_bid: int = int(mine.get("current_bid_cr", mine.get("license_price_cr", 9500)))
	var leader: String = str(mine.get("highest_bidder", ""))
	var auto_cap: int = int(mine.get("max_auto_bid_cr", 0))

	# 若玩家尚未出价但设置了自动出价上限，先自动应价起拍价
	if leader == "" and auto_cap >= cur_bid and available_cash_cr(v40) >= cur_bid:
		leader = "player"
		mine["highest_bidder"] = "player"
		v40["reserved_cash_cr"] = int(v40.get("reserved_cash_cr", 0)) + cur_bid

	# AI 根据公开估值区间（绝不读取未揭示隐藏矿体）与自身现金上限 (cash_cr * 0.35) 计算最高出价意愿
	var pub_mid_t: int = int((int(mine.get("estimate_min_t", 2000)) + int(mine.get("estimate_max_t", 5000))) / 2)
	var ai_valuation_cr: int = int(round(float(pub_mid_t) * 2.6))
	var rivals: Dictionary = v40.get("rivals", {})
	var best_ai_id: String = "crimson_mining"
	var best_ai_max: int = 0
	for rk in rivals:
		var r_cash_cap: int = int(round(float(int(rivals[rk].get("cash_cr", 40000))) * 0.32))
		var will_cr: int = mini(r_cash_cap, ai_valuation_cr)
		if will_cr > best_ai_max:
			best_ai_max = will_cr
			best_ai_id = str(rk)

	# 若 AI 出价高于当前价，尝试超越；若玩家设有足够自动出价上限且可支配现金允许，则自动反超（不超过上限）
	if best_ai_max >= cur_bid + 1000:
		if leader == "player":
			# 玩家暂时失去领先，立即解除此前的冻结金额
			v40["reserved_cash_cr"] = maxi(0, int(v40.get("reserved_cash_cr", 0)) - cur_bid)
		cur_bid = best_ai_max
		leader = best_ai_id
		if auto_cap >= cur_bid + 1000 and available_cash_cr(v40) >= cur_bid + 1000:
			cur_bid += 1000
			leader = "player"
			v40["reserved_cash_cr"] = int(v40.get("reserved_cash_cr", 0)) + cur_bid

	mine["current_bid_cr"] = cur_bid
	mine["highest_bidder"] = leader

	if leader == "player":
		# 落槌成交：释放冻结款并正式扣除现金
		v40["reserved_cash_cr"] = maxi(0, int(v40.get("reserved_cash_cr", 0)) - cur_bid)
		v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - cur_bid)
		v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cur_bid
		mine["license_owned"] = true
		mine["platforms"] = maxi(1, int(mine.get("platforms", 0)))
		mine["bore_cells"] = maxi(16, int(mine.get("bore_cells", 0)))
		v40["active_mine_id"] = mine_id
		state.add_log("【商业竞拍落槌】我方以 %d Cr 竞得「%s」商业开采许可（冻结款已转正式扣款）！" % [cur_bid, str(mine["name_zh"])])
		return {"ok": true, "winner": "player", "final_price_cr": cur_bid, "msg": "竞拍落槌！您以 %d Cr 夺得「%s」开采权！" % [cur_bid, str(mine["name_zh"])]}
	else:
		var r_name: String = str(rivals.get(leader, {}).get("name_zh", "竞争财团"))
		if rivals.has(leader):
			rivals[leader]["cash_cr"] = maxi(0, int(rivals[leader]["cash_cr"]) - cur_bid)
		return {
			"ok": true,
			"winner": leader,
			"final_price_cr": cur_bid,
			"msg": "%s 当前出价 %d Cr 领先（我方原冻结资金已立即解冻；您可加价截胡或调高自动出价上限）。" % [r_name, cur_bid]
		}


static func _cmd_simulate_capacity_overflow(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 19.3 & 23.2 #16 节：验证新版调小仓容加载旧档时，现有库存进入溢出待清理状态 (overflow_locked)，只出不进、绝不静默删货
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return {"ok": false, "error": "矿区不存在。"}
	var cur_stock: int = int(mine.get("silo_stock_t", 60))
	var new_cap: int = int(params.get("new_capacity_t", maxi(20, cur_stock - 20)))
	mine["silo_capacity_t"] = new_cap
	mine["overflow_locked"] = (cur_stock > new_cap)
	return {
		"ok": true,
		"stock_t": cur_stock,
		"capacity_t": new_cap,
		"overflow_locked": bool(mine["overflow_locked"]),
		"msg": "仓容迁移校验完成：当前库存 %d t / 新上限 %d t（已进入溢出待清理状态，保留全部矿石不删货，运出降回上限内后恢复正常）。" % [cur_stock, new_cap]
	}


static func calc_surface_preset_preview(v40: Dictionary, mine_id: String) -> Dictionary:
	# 第 7.5 & 16.3 节：计算将目标矿区地表设施升级至已保存预设组合所需的增量费用（绝不直接复制地下井道到不同地质）
	var mine: Dictionary = v40.get("mines", {}).get(mine_id, {})
	var preset: Dictionary = v40.get("surface_preset", {"platforms": 1, "platform_upgraded": true, "silo_capacity_t": 800})
	if mine.is_empty():
		return {"cost_cr": 0, "desc_zh": "无效矿区"}
	var need_plats: int = maxi(0, int(preset.get("platforms", 1)) - int(mine.get("platforms", 0)))
	var need_plat_upg: bool = bool(preset.get("platform_upgraded", false)) and not bool(mine.get("platform_upgraded", false))
	var cur_silo: int = int(mine.get("silo_capacity_t", 300))
	var target_silo: int = int(preset.get("silo_capacity_t", 800))
	var silo_steps: int = maxi(0, int(ceil(float(target_silo - cur_silo) / 500.0)))
	var cost_cr: int = need_plats * 8000 + (9000 if need_plat_upg else 0) + silo_steps * 6000
	return {
		"need_platforms": need_plats,
		"need_platform_upgrade": need_plat_upg,
		"silo_steps": silo_steps,
		"target_silo_t": cur_silo + silo_steps * 500,
		"cost_cr": cost_cr,
		"desc_zh": "预设[%d座平台%s · %dt矿仓] 增量预算 %d Cr (地下井道按当地地质独立规划)" % [
			int(preset.get("platforms", 1)), "+100t改造" if bool(preset.get("platform_upgraded", false)) else "",
			int(preset.get("silo_capacity_t", 800)), cost_cr
		]
	}


static func _cmd_save_surface_preset(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty():
		return {"ok": false, "error": "矿区不存在。"}
	var p_cnt: int = maxi(1, int(mine.get("platforms", 1)))
	var p_upg: bool = bool(mine.get("platform_upgraded", false))
	var s_cap: int = maxi(300, int(mine.get("silo_capacity_t", 300)))
	v40["surface_preset"] = {
		"platforms": p_cnt,
		"platform_upgraded": p_upg,
		"silo_capacity_t": s_cap,
		"name_zh": "来自「%s」的地表组合 (%d平台%s · %dt仓)" % [str(mine["name_zh"]), p_cnt, "+改造" if p_upg else "", s_cap]
	}
	return {"ok": true, "msg": "已保存地表设施组合预设：%s（地下路线不盲目跨地质复制）。" % str(v40["surface_preset"]["name_zh"])}


static func _cmd_apply_surface_preset(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var mine: Dictionary = v40["mines"].get(mine_id, {})
	if mine.is_empty() or not bool(mine.get("license_owned", false)):
		return {"ok": false, "error": "请先取得该矿区开采许可后再应用地表预设。"}
	var prev: Dictionary = calc_surface_preset_preview(v40, mine_id)
	var cost: int = int(prev.get("cost_cr", 0))
	if cost <= 0:
		return {"ok": false, "error": "当前矿区地表设施已达到或超过预设标准，无需额外投入。"}
	if available_cash_cr(v40) < cost:
		return {"ok": false, "error": "应用地表设施预设需 %d Cr，当前可支配现金不足。" % cost}
	v40["cash_cr"] = int(v40["cash_cr"]) - cost
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost
	mine["platforms"] = int(mine.get("platforms", 0)) + int(prev["need_platforms"])
	if bool(prev["need_platform_upgrade"]):
		mine["platform_upgraded"] = true
	mine["silo_capacity_t"] = int(prev["target_silo_t"])
	state.add_log("【应用地表设施预设】「%s」已一键配齐预设地表设施（耗资 %d Cr）。" % [str(mine["name_zh"]), cost])
	return {"ok": true, "cost_cr": cost, "msg": "已在「%s」一键应用地表设施预设（耗资 %d Cr）！" % [str(mine["name_zh"]), cost]}


static func _cmd_sell_ship(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 7.3 & 23.1 节：火箭可改派或按 60% 二手出售；售出前必须清空/转移货物，禁止静默删除船上矿石！
	var ship_id: int = int(params.get("ship_id", -1))
	var ships_arr: Array = v40.get("ships", [])
	if ships_arr.is_empty():
		return {"ok": false, "error": "当前没有在役运矿船。"}
	var target_idx: int = -1
	for i in range(ships_arr.size()):
		if ship_id < 0 or int(ships_arr[i].get("id", 0)) == ship_id:
			target_idx = i
			break
	if target_idx < 0:
		return {"ok": false, "error": "未找到目标船只。"}
	var s: Dictionary = ships_arr[target_idx]
	if int(s.get("cargo_t", 0)) > 0:
		return {"ok": false, "error": "「%s」船舱内仍有 %d t 矿石未卸载，售出前必须先清空或卸货（第 7.3 节保护）！" % [str(s["name_zh"]), int(s["cargo_t"])]}
	var stype: String = str(s.get("type_id", "falcon_light"))
	var sprice: int = int(get_config().get("ships", {}).get(stype, {}).get("price_cr", 38000))
	var refund: int = int(round(float(sprice) * 0.60))
	var sname: String = str(s["name_zh"])
	ships_arr.remove_at(target_idx)
	v40["cash_cr"] = int(v40["cash_cr"]) + refund
	state.add_log("【二手售船】已按 60%% 残值售出「%s」，回笼资金 +%d Cr。" % [sname, refund])
	return {"ok": true, "refund_cr": refund, "msg": "已售出「%s」，回收 60%% 残值 +%d Cr！" % [sname, refund]}


static func _cmd_overhaul_ship(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 对标参考图 1「可检修后再次使用」与参考图 3「控制指令：姿态微调」：对在役运矿船执行结构检修与栅格翼姿态微调
	var ships_arr: Array = v40.get("ships", [])
	if ships_arr.is_empty():
		return {"ok": false, "error": "当前没有在役运矿船可供检修。"}
	var ship_id: int = int(params.get("ship_id", -1))
	var target_ship: Dictionary = ships_arr[0]
	for s in ships_arr:
		if int(s.get("id", 0)) == ship_id:
			target_ship = s
			break
	var cost_cr: int = 1200
	if available_cash_cr(v40) < cost_cr:
		return {"ok": false, "error": "助推器结构检修与姿态校准需 1,200 Cr，当前可支配现金不足。"}
	v40["cash_cr"] = int(v40["cash_cr"]) - cost_cr
	v40["ledger"]["upkeep_expense_cr"] = int(v40["ledger"]["upkeep_expense_cr"]) + cost_cr
	target_ship["overhauled"] = true
	target_ship["wear_reset_trips"] = int(target_ship.get("trips_completed", 0))
	state.add_log("【助推器检修与姿态校准】「%s」已完成结构无损探伤与栅格翼姿态微调（耗资 %d Cr，结构损耗归零）！" % [
		str(target_ship.get("name_zh", "运矿船")), cost_cr
	])
	return {
		"ok": true,
		"cost_cr": cost_cr,
		"msg": "「%s」已完成姿态微调与结构检修（结构损耗已归零 · 回收成功率锁定 98.5%%）！" % str(target_ship.get("name_zh", "运矿船"))
	}


static func _cmd_select_launch_window(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 对标参考图 2 底部「发射窗口 + 天气状况：晴 | 风速 4 m/s (适宜发射)」与参考图 4 右侧「发射窗口三档切换」
	var cur_mode: String = str(v40.get("launch_window_mode", "standard"))
	var req_mode: String = str(params.get("window_mode", ""))
	if req_mode == "":
		if cur_mode == "standard":
			req_mode = "optimal"
		elif cur_mode == "optimal":
			req_mode = "express"
		else:
			req_mode = "standard"
	v40["launch_window_mode"] = req_mode
	var desc_map: Dictionary = {
		"optimal": "☀ 晴空顺风窗口 (21:36-22:14 | 风速 3.8 m/s · 适宜发射：单趟燃料运费 -8%%，回收成功率 +1.5%%)",
		"standard": "⛅ 标准轨道窗口 (15:10-16:00 | 风速 6.2 m/s · 常规执飞：标准航次周期与燃料消耗)",
		"express": "⚡ 引力快航窗口 (09:20-09:55 | 切变风 9.4 m/s · 极速抢运：航行周期缩短 -15%%，燃料损耗 +5%%)"
	}
	var label_zh: String = str(desc_map.get(req_mode, desc_map["standard"]))
	state.add_log("【发射窗口与气象切换】已锁定：%s" % label_zh)
	return {
		"ok": true,
		"window_mode": req_mode,
		"msg": "已切换发射窗口：%s" % label_zh
	}


static func _cmd_launch_pad_dispatch(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 对标参考图 2 & 4 右下角金色【🚀 发射】大按钮：优先指令在役运矿船立即点火装运/到港交割；若矿仓为空且资金充裕则增购新运矿船
	var ships_arr: Array = v40.get("ships", [])
	var mines: Dictionary = v40.get("mines", {})
	var active_m_id: String = str(params.get("mine_id", v40.get("active_mine_id", "dawn_1")))
	var cur_day: float = float(v40.get("game_day", 0.0))

	# 1. 若有在役船只正处于矿区待命且矿仓有现货，立即执行点火升空发运（不受 2.0 日不满仓等待阈值限制）
	for ship in ships_arr:
		if int(ship.get("cargo_t", 0)) == 0:
			var m_id: String = str(ship.get("assigned_mine_id", active_m_id))
			if not mines.has(m_id):
				m_id = active_m_id
			var m: Dictionary = mines.get(m_id, {})
			var stock_t: int = int(m.get("silo_stock_t", 0))
			if stock_t > 0:
				var stype_id: String = str(ship.get("type_id", "falcon_light"))
				var metrics: Dictionary = calc_ship_route_metrics(
					stype_id,
					float(m.get("distance_l", 0.5)),
					float(m.get("gravity_g", 1.0)),
					100, 8,
					v40
				)
				var trip_fee: int = int(metrics.get("trip_cost_cr", 2400))
				if available_cash_cr(v40) >= trip_fee:
					var load_amt: int = mini(int(ship.get("capacity_t", 100)), stock_t)
					m["silo_stock_t"] = stock_t - load_amt
					m["last_served_day"] = cur_day
					ship["cargo_t"] = load_amt
					ship["mineral_id"] = str(m.get("primary_mineral", "iron_titanium"))
					ship["wait_days"] = 0.0
					ship["phase"] = "inbound"
					v40["cash_cr"] = int(v40["cash_cr"]) - trip_fee
					v40["ledger"]["transport_expense_cr"] = int(v40["ledger"]["transport_expense_cr"]) + trip_fee
					# 立即完成本趟入港卸货与销售闭环，赋予玩家即时发射反馈
					var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
					var free_port_t: int = maxi(0, int(pinv_dawn.get("capacity_t", 500)) - _port_used_tonnes(pinv_dawn))
					var unload_t: int = mini(load_amt, free_port_t)
					if unload_t > 0:
						var min_id: String = str(ship["mineral_id"])
						ship["cargo_t"] = load_amt - unload_t
						pinv_dawn["minerals"][min_id] = int(pinv_dawn["minerals"].get(min_id, 0)) + unload_t
						if int(ship["cargo_t"]) == 0:
							ship["phase"] = "idle"
							ship["trips_completed"] = int(ship.get("trips_completed", 0)) + 1
						_apply_port_sale_policy(state, v40, "dawn_port", min_id)
					state.add_log("【发射台点火升空】「%s」已装载 %d t 矿石点火升空并完成轨道回收交割（运费 -%d Cr）！" % [
						str(ship.get("name_zh", "运矿船")), load_amt, trip_fee
					])
					return {
						"ok": true,
						"cost_cr": trip_fee,
						"msg": "🚀 点火升空！「%s」已运载 %d t 矿石直达晨曦港并完成助推器海上回收！" % [str(ship.get("name_zh", "运矿船")), load_amt]
					}

	# 2. 若玩家现金充足 (>= 38,000 Cr)，直接增购一艘新隼式运矿船投入当前航线
	if available_cash_cr(v40) >= 38000:
		return _cmd_purchase_ship(state, v40, {"ship_type_id": "falcon_light", "mine_id": active_m_id})

	# 3. 若当前矿仓暂无矿石且资金未满购船线，执行半日加速采掘并装船预备
	step_v40_simulation(state, 0.5)
	return {
		"ok": true,
		"cost_cr": 0,
		"msg": "🚀 已推进发射台整备与矿仓装填（当前可支配现金 %d Cr，矿仓已就绪）！" % available_cash_cr(v40)
	}


## ============================================================================
## 第 16.5 章：分级合并通知（相同对象、相同原因合并，不在每个步进重复轰炸）
## ============================================================================

static func _push_merged_notification(v40: Dictionary, level: String, object_id: String, reason: String, text: String) -> void:
	var notes: Array = v40.get("notifications", [])
	for n in notes:
		if str(n.get("object_id", "")) == object_id and str(n.get("reason", "")) == reason:
			n["level"] = level
			n["text"] = text
			n["day"] = float(v40.get("game_day", 0.0))
			return
	notes.push_front({
		"level": level,
		"object_id": object_id,
		"reason": reason,
		"text": text,
		"day": float(v40.get("game_day", 0.0))
	})
	if notes.size() > 12:
		notes.pop_back()


## ============================================================================
## 第 8.7 章：共享船池四级优先级自动选矿算法
## ============================================================================

static func _select_best_mine_for_shared_pool(v40: Dictionary) -> String:
	var mines: Dictionary = v40.get("mines", {})
	var cur_day: float = float(v40.get("game_day", 0.0))

	# 优先级 1：预计会违约或紧迫的进行中合同对应矿种
	for c in v40.get("contracts", []):
		if str(c.get("state", "")) == "active":
			var feas: Dictionary = calc_contract_feasibility(v40, c)
			if int(feas.get("need_t", 0)) > 0:
				var c_min: String = str(c.get("mineral_id", "iron_titanium"))
				for mid in mines:
					var m: Dictionary = mines[mid]
					if bool(m.get("license_owned", false)) and str(m.get("primary_mineral", "")) == c_min and int(m.get("silo_stock_t", 0)) > 0:
						return str(mid)

	# 优先级 2：会导致明显停产的满仓/高占用矿区 (>= 75% 仓容)
	var highest_fill_id: String = ""
	var highest_fill_ratio: float = 0.75
	for mid in mines:
		var m: Dictionary = mines[mid]
		if not bool(m.get("license_owned", false)):
			continue
		var ratio: float = float(int(m.get("silo_stock_t", 0))) / float(maxi(1, int(m.get("silo_capacity_t", 300))))
		if ratio >= highest_fill_ratio:
			highest_fill_ratio = ratio
			highest_fill_id = str(mid)
	if highest_fill_id != "":
		return highest_fill_id

	# 优先级 3 & 4：按预计单位船日贡献 + 等待时间防饥饿加成排序
	var best_id: String = str(v40.get("active_mine_id", "dawn_1"))
	var best_score: float = -999999.0
	var minerals_cfg: Dictionary = get_config().get("minerals", {})
	for mid in mines:
		var m: Dictionary = mines[mid]
		if not bool(m.get("license_owned", false)) or int(m.get("silo_stock_t", 0)) <= 0:
			continue
		var p_min: String = str(m.get("primary_mineral", "iron_titanium"))
		var mdef: Dictionary = minerals_cfg.get(p_min, {})
		var met: Dictionary = calc_ship_route_metrics(
			"falcon_light",
			float(m.get("distance_l", 0.5)),
			float(m.get("gravity_g", 1.0)),
			int(mdef.get("base_price_cr", 100)),
			int(mdef.get("mining_var_cost_cr", 8)),
			v40
		)
		var wait_age: float = maxf(0.0, cur_day - float(m.get("last_served_day", 0.0)))
		var score: float = float(met.get("ship_day_contribution_cr", 1000)) + wait_age * 250.0
		if score > best_score:
			best_score = score
			best_id = str(mid)
	return best_id


## ============================================================================
## 第 11.3, 8.4–8.7, 9.3–9.4, 13, 18.5 章：固定时间步权威模拟推进
## ============================================================================

static func step_v40_simulation(state: GameState, dt_days: float = 0.5) -> Dictionary:
	var v40: Dictionary = ensure_v40_state(state)
	var prev_day: float = float(v40.get("game_day", 0.0))
	v40["game_day"] = prev_day + dt_days
	var cur_day: float = float(v40["game_day"])
	var cfg: Dictionary = get_config()
	var minerals_cfg: Dictionary = cfg.get("minerals", {})
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	# 0. 推进施工工单状态与商业预告事件倒计时 (第 6.5 & 15.5 节)
	for wo in v40.get("work_orders", []):
		if cur_day - float(wo.get("created_day", 0.0)) >= 0.5:
			wo["started"] = true
	for ev in v40.get("special_events", []):
		if str(ev.get("state", "")) == "forewarned":
			ev["notice_days"] = maxf(0.0, float(ev.get("notice_days", 0.0)) - dt_days)
			if float(ev["notice_days"]) <= 0.0:
				ev["state"] = "active"
				_push_merged_notification(v40, "attention", str(ev["id"]), "event_active", "【事件生效】%s 已正式开始" % str(ev["title_zh"]))

	# 1. 采矿步进 (第 11.3 节：potential_i = min(速率*dt, 剩余矿量)，受主井、平台、仓容、可支付变动费四重约束)
	var mines: Dictionary = v40["mines"]
	for m_id in mines:
		var m: Dictionary = mines[m_id]
		if not bool(m.get("license_owned", false)):
			continue
		var st: String = str(m.get("status", "running"))
		var deep_disc: float = 0.70 if ("M4" in unlocked) else 1.0
		var base_upkeep_day: float = 60.0 + float(int(m.get("platforms", 0)) * 50 + _count_mine_heads(m) * 20) + float(int(m.get("bore_cells", 0))) * 0.5 * deep_disc
		if st == "paused":
			base_upkeep_day *= 0.25
		elif st == "mothballed":
			base_upkeep_day = 15.0
		var upkeep_step: int = int(round(base_upkeep_day * dt_days))
		if available_cash_cr(v40) >= upkeep_step:
			v40["cash_cr"] = int(v40["cash_cr"]) - upkeep_step
			v40["ledger"]["upkeep_expense_cr"] = int(v40["ledger"]["upkeep_expense_cr"]) + upkeep_step
		else:
			v40["payables_cr"] = int(v40.get("payables_cr", 0)) + upkeep_step

		if st != "running" or int(m.get("platforms", 0)) <= 0:
			continue

		var head_rate: float = 65.0 if ("M5" in unlocked) else 40.0
		var lift_cap_step: float = float(int(m["platforms"])) * (100.0 if bool(m.get("platform_upgraded", false)) else 60.0) * dt_days
		var bore_cap_step: float = (120.0 if bool(m.get("bore_upgraded", false)) else 60.0) * dt_days
		var free_silo: int = maxi(0, int(m.get("silo_capacity_t", 300)) - int(m.get("silo_stock_t", 0)))
		if free_silo <= 0:
			_push_merged_notification(v40, "attention", str(m_id), "silo_full", "【%s】地表矿仓已满，采掘头自动暂停待运" % str(m["name_zh"]))
			continue
		var max_step_tonnes: int = int(floor(minf(float(free_silo), minf(lift_cap_step, bore_cap_step))))
		if max_step_tonnes <= 0:
			continue

		var remaining_allowance: int = max_step_tonnes
		for dep in m.get("deposits", []):
			if remaining_allowance <= 0:
				break
			var h_cnt: int = int(dep.get("heads", 0))
			var rem_t: int = int(dep.get("remaining_t", 0))
			if h_cnt <= 0 or rem_t <= 0 or not bool(dep.get("revealed", false)):
				continue
			var pot_t: int = mini(rem_t, int(round(float(h_cnt) * head_rate * dt_days)))
			pot_t = mini(pot_t, remaining_allowance)
			var min_id: String = str(dep.get("mineral_id", "iron_titanium"))
			var var_cost_per_t: int = int(minerals_cfg.get(min_id, {}).get("mining_var_cost_cr", 8))
			var max_affordable_t: int = int(available_cash_cr(v40) / maxi(1, var_cost_per_t))
			var actual_t: int = mini(pot_t, max_affordable_t)
			if actual_t > 0:
				dep["remaining_t"] = rem_t - actual_t
				m["silo_stock_t"] = int(m["silo_stock_t"]) + actual_t
				v40["sampled_minerals"][min_id] = true
				var cost_step: int = actual_t * var_cost_per_t
				v40["cash_cr"] = int(v40["cash_cr"]) - cost_step
				v40["ledger"]["mining_var_expense_cr"] = int(v40["ledger"]["mining_var_expense_cr"]) + cost_step
				remaining_allowance -= actual_t

	# 2. 船只自动往返、共享船池、尾矿清运与港仓分批卸货 (第 8.4–8.7 节 & 第 23.2 节关键情境)
	var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
	for ship in v40["ships"]:
		var stype_id: String = str(ship.get("type_id", "falcon_light"))
		var sdef: Dictionary = cfg.get("ships", {}).get(stype_id, {})
		var ship_upkeep: int = int(round(float(int(sdef.get("daily_upkeep_cr", 40))) * dt_days))
		if available_cash_cr(v40) >= ship_upkeep:
			v40["cash_cr"] = int(v40["cash_cr"]) - ship_upkeep
			v40["ledger"]["upkeep_expense_cr"] = int(v40["ledger"]["upkeep_expense_cr"]) + ship_upkeep

		# 在空闲节点边界应用共享船池或预定改派航线 (第 8.4 & 8.7 节)
		if int(ship.get("cargo_t", 0)) == 0:
			var pend_m: String = str(ship.get("pending_mine_id", ""))
			if pend_m != "" and mines.has(pend_m):
				ship["assigned_mine_id"] = pend_m
				ship["pending_mine_id"] = ""
			elif bool(v40.get("shared_fleet_pool", false)):
				ship["assigned_mine_id"] = _select_best_mine_for_shared_pool(v40)

		var target_m_id: String = str(ship.get("assigned_mine_id", v40["active_mine_id"]))
		if not mines.has(target_m_id):
			continue
		var t_mine: Dictionary = mines[target_m_id]
		var s_cap: int = int(ship.get("capacity_t", 100))
		var m_stock: int = int(t_mine.get("silo_stock_t", 0))
		var min_id: String = str(t_mine.get("primary_mineral", "iron_titanium"))
		ship["mineral_id"] = min_id

		var total_mine_rem: int = 0
		for d in t_mine.get("deposits", []):
			total_mine_rem += int(d.get("remaining_t", 0))
		var mine_stopped_or_exhausted: bool = (str(t_mine.get("status", "running")) != "running") or (total_mine_rem == 0)

		if int(ship.get("cargo_t", 0)) == 0:
			ship["wait_days"] = float(ship.get("wait_days", 0.0)) + dt_days
			var should_load: bool = (m_stock >= s_cap) or (m_stock > 0 and (float(ship["wait_days"]) >= 2.0 or mine_stopped_or_exhausted))
			if should_load:
				var metrics: Dictionary = calc_ship_route_metrics(
					stype_id,
					float(t_mine.get("distance_l", 0.5)),
					float(t_mine.get("gravity_g", 1.0)),
					100, 8,
					v40
				)
				var trip_fee: int = int(metrics.get("trip_cost_cr", 2400))
				if available_cash_cr(v40) >= trip_fee:
					var load_amt: int = mini(s_cap, m_stock)
					# 原子转移：矿仓减，船舱加
					t_mine["silo_stock_t"] = m_stock - load_amt
					t_mine["last_served_day"] = cur_day
					ship["cargo_t"] = load_amt
					ship["wait_days"] = 0.0
					ship["phase"] = "inbound"
					v40["cash_cr"] = int(v40["cash_cr"]) - trip_fee
					v40["ledger"]["transport_expense_cr"] = int(v40["ledger"]["transport_expense_cr"]) + trip_fee

		# 船只到港卸载：校验港仓剩余空间，空间不足时分批卸货，余货留船 (第 8.6 & 23.2 节)
		if int(ship.get("cargo_t", 0)) > 0:
			var used_port_t: int = _port_used_tonnes(pinv_dawn)
			var free_port_t: int = maxi(0, int(pinv_dawn.get("capacity_t", 500)) - used_port_t)
			var unload_t: int = mini(int(ship["cargo_t"]), free_port_t)
			if unload_t > 0:
				ship["cargo_t"] = int(ship["cargo_t"]) - unload_t
				pinv_dawn["minerals"][min_id] = int(pinv_dawn["minerals"].get(min_id, 0)) + unload_t
			if int(ship["cargo_t"]) == 0:
				ship["phase"] = "idle"
				ship["trips_completed"] = int(ship.get("trips_completed", 0)) + 1
				var pend_after: String = str(ship.get("pending_mine_id", ""))
				if pend_after != "" and mines.has(pend_after):
					ship["assigned_mine_id"] = pend_after
					ship["pending_mine_id"] = ""
			else:
				ship["phase"] = "port_blocked"
				_push_merged_notification(v40, "urgent", str(ship["id"]), "port_blocked", "【%s】因晨曦港仓满滞留 %d t 矿物未卸" % [str(ship["name_zh"]), int(ship["cargo_t"])])

			# 按港口销售策略 ("direct" / "target" / "priority") 与应急出售规则执行销售 (第 9.4 节)
			_apply_port_sale_policy(state, v40, "dawn_port", min_id)

	# 3. 每日边界：刷新买方每日额度、按第 9.3 节公式更新动态参考价、结算港口仓储费与贷款利息
	if int(floor(cur_day)) > int(floor(prev_day)):
		_update_daily_market_and_fees(state, v40)

	# 4. 每 7 游戏日边界：竞争财团战略评估与可解释动态 (第 2.2 & 13.3 节)
	if int(floor(cur_day / 7.0)) > int(floor(prev_day / 7.0)):
		_step_ai_consortiums(state, v40)

	# 5. 每 30 游戏日边界：财报周期结算与终局路线核验 (第 2.2 & 15.6 节)
	if int(floor(cur_day / 30.0)) > int(floor(prev_day / 30.0)):
		var fin_now: Dictionary = financial_summary(v40)
		var cur_surplus: int = int(fin_now.get("operating_surplus_cr", 0))
		if cur_surplus > int(v40.get("last_report_surplus_cr", 0)):
			v40["consecutive_positive_reports"] = int(v40.get("consecutive_positive_reports", 0)) + 1
		v40["last_report_surplus_cr"] = cur_surplus
		check_endgame_routes(v40)

	# 6. 第 10.6 节：应付款自动清偿、7日逾期 -> 30日重整倒计时 与 首次严重现金短缺自动暂停保护
	var cur_payables: int = int(v40.get("payables_cr", 0))
	if cur_payables > 0 and available_cash_cr(v40) > 0:
		var clear_amt: int = mini(cur_payables, available_cash_cr(v40))
		v40["cash_cr"] = int(v40["cash_cr"]) - clear_amt
		v40["payables_cr"] = cur_payables - clear_amt
		cur_payables = int(v40["payables_cr"])

	var trigger_shortage_pause: bool = false
	if cur_payables > 0:
		v40["overdue_days"] = float(v40.get("overdue_days", 0.0)) + dt_days
		if float(v40["overdue_days"]) >= 7.0:
			v40["restructure_countdown_days"] = maxf(0.0, float(v40.get("restructure_countdown_days", 30.0)) - dt_days)
			_push_merged_notification(v40, "urgent", "company", "overdue_restructure", "【债务重整倒计时】应付款已逾期 %.1f 日，距强制重整还剩 %.1f 日" % [float(v40["overdue_days"]), float(v40["restructure_countdown_days"])])
		if not bool(v40.get("shortage_paused_once", false)):
			v40["shortage_paused_once"] = true
			trigger_shortage_pause = true
			_push_merged_notification(v40, "urgent", "company", "cash_shortage", "【现金严重短缺自动暂停】请出售库存、封存矿区、拆售设备或申请授信借款")
	else:
		v40["overdue_days"] = 0.0
		v40["restructure_countdown_days"] = 30.0

	# 更新溢出锁状态：一旦库存被运出或售出降回上限以内，立即解除 overflow_locked
	for mid_k in mines:
		var mk: Dictionary = mines[mid_k]
		mk["overflow_locked"] = int(mk.get("silo_stock_t", 0)) > int(mk.get("silo_capacity_t", 300))

	_sync_legacy_bridge(state, v40)
	return {"ok": true, "game_day": cur_day, "auto_pause": trigger_shortage_pause}


static func _apply_port_sale_policy(state: GameState, v40: Dictionary, port_id: String, mineral_id: String) -> void:
	var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
	if pinv.is_empty():
		return
	var pol: String = str(pinv.get("sale_policy", {}).get(mineral_id, "direct"))
	var mkt: Dictionary = v40["market"]
	var used_ratio: float = float(_port_used_tonnes(pinv)) / float(maxi(1, int(pinv.get("capacity_t", 500))))
	var emergency_trigger: bool = bool(v40.get("emergency_sale_authorized", false)) and (used_ratio >= 0.85 or available_cash_cr(v40) < 3000)

	if pol == "priority":
		# 优先划拨给该港口进行中的对应矿物合同
		for c in v40.get("contracts", []):
			if str(c.get("state", "")) == "active" and str(c.get("port_id", "dawn_port")) == port_id and str(c.get("mineral_id", "")) == mineral_id:
				_cmd_deliver_contract(state, v40, {"contract_id": str(c["id"])})
		# 合同满足后余货按直接出售处理
		if int(pinv["minerals"].get(mineral_id, 0)) > int(pinv["reserved"].get(mineral_id, 0)):
			_cmd_sell_mineral_now(state, v40, {"port_id": port_id, "mineral_id": mineral_id, "buyer_type": "best", "auto_tick": true})
	elif pol == "target" and not emergency_trigger:
		var target_p: int = int(pinv.get("target_prices", {}).get(mineral_id, 115))
		var spot_p: int = int(mkt["spot_quotes"].get(mineral_id, 110))
		var reg_p: int = int(mkt["regular_quotes"].get(mineral_id, 95))
		if spot_p >= target_p or reg_p >= target_p:
			_cmd_sell_mineral_now(state, v40, {"port_id": port_id, "mineral_id": mineral_id, "buyer_type": "best", "auto_tick": true})
	else:
		# direct 或触发应急出售
		if int(pinv["minerals"].get(mineral_id, 0)) > int(pinv["reserved"].get(mineral_id, 0)):
			_cmd_sell_mineral_now(state, v40, {"port_id": port_id, "mineral_id": mineral_id, "buyer_type": "best", "auto_tick": true})


static func _step_ai_consortiums(state: GameState, v40: Dictionary) -> void:
	# 第 13 章：三家 AI 财团每 7 游戏日执行一次受资金、储量与运力约束的战略评估
	var rivals: Dictionary = v40.get("rivals", {})
	var mkt: Dictionary = v40.get("market", {})

	for r_key in rivals:
		var r: Dictionary = rivals[r_key]
		var out_7d: int = int(r.get("output_t_day", 30)) * 7
		r["inventory_t"] = int(r.get("inventory_t", 100)) + out_7d
		var ship_cap_7d: int = int(r.get("ships", 2)) * 220

		if r_key == "crimson_mining":
			var sell_t: int = mini(int(r["inventory_t"]), ship_cap_7d)
			r["inventory_t"] = int(r["inventory_t"]) - sell_t
			var rev: int = sell_t * int(mkt["regular_quotes"].get("iron_titanium", 95)) - sell_t * 14
			r["cash_cr"] = maxi(5000, int(r["cash_cr"]) + rev)
			mkt["delivered_7d"]["iron_titanium"] = int(mkt["delivered_7d"].get("iron_titanium", 1800)) + int(round(float(sell_t) * 0.25))
			r["last_news"] = "赤曜矿业本周向晨曦港发运 %d t 铁钛矿，现金储备 %d Cr" % [sell_t, int(r["cash_cr"])]
		elif r_key == "starring_transit":
			var sell_si: int = mini(int(r["inventory_t"]), ship_cap_7d)
			r["inventory_t"] = int(r["inventory_t"]) - sell_si
			var rev_si: int = sell_si * int(mkt["regular_quotes"].get("silicon_crystal", 171)) - sell_si * 22
			r["cash_cr"] = maxi(5000, int(r["cash_cr"]) + rev_si)
			if int(r["cash_cr"]) >= 90000 and int(r.get("ships", 3)) < 5:
				r["cash_cr"] = int(r["cash_cr"]) - 38000
				r["ships"] = int(r["ships"]) + 1
				r["last_news"] = "星环运输增购 1 艘运矿船（在役 %d 艘），扩大干线运力" % int(r["ships"])
			else:
				r["last_news"] = "星环运输本周完成 %d t 晶硅矿干线运输" % sell_si
		elif r_key == "silver_dome":
			var spot_si_p: int = int(mkt["spot_quotes"].get("silicon_crystal", 198))
			if spot_si_p >= 195 or int(r["inventory_t"]) >= 360:
				var dump_t: int = mini(int(r["inventory_t"]), ship_cap_7d)
				r["inventory_t"] = int(r["inventory_t"]) - dump_t
				var rev_dump: int = dump_t * spot_si_p - dump_t * 20
				r["cash_cr"] = maxi(5000, int(r["cash_cr"]) + rev_dump)
				mkt["delivered_7d"]["silicon_crystal"] = int(mkt["delivered_7d"].get("silicon_crystal", 900)) + int(round(float(dump_t) * 0.35))
				r["last_news"] = "银穹资本趁高价窗口抛售 %d t 晶硅矿，回笼 %d Cr" % [dump_t, maxi(0, rev_dump)]
			else:
				r["last_news"] = "银穹资本继续囤积矿石 (%d t)，等待高价采购窗口" % int(r["inventory_t"])

		r["net_worth_cr"] = int(r["cash_cr"]) + int(r["inventory_t"]) * 110 + int(r.get("ships", 2)) * 24000
	state.add_log("【行业周报】" + str(rivals["silver_dome"]["last_news"]))


static func _port_used_tonnes(pinv: Dictionary) -> int:
	var total: int = 0
	var mins: Dictionary = pinv.get("minerals", {})
	for k in mins:
		total += int(mins[k])
	var refs: Dictionary = pinv.get("refined", {})
	for rk in refs:
		total += int(refs[rk])
	return total


static func _update_daily_market_and_fees(state: GameState, v40: Dictionary) -> void:
	var cfg: Dictionary = get_config()
	var minerals_cfg: Dictionary = cfg.get("minerals", {})
	var mkt: Dictionary = v40["market"]
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	# 1. 第 9.3 节：7 日供需平滑参考价公式与每日额度重置
	for mid in minerals_cfg:
		var mdef: Dictionary = minerals_cfg[mid]
		var base_p: float = float(mdef.get("base_price_cr", 100))
		var demand_7d: float = maxf(100.0, float(mkt["demand_7d"].get(mid, 1000)))
		var deliv_7d: float = float(mkt["delivered_7d"].get(mid, 800))
		var imbalance: float = (demand_7d - deliv_7d) / demand_7d
		var target_p: float = base_p * clampf(1.0 + 0.25 * imbalance, 0.70, 1.40)
		var old_ref: float = float(mkt["reference_prices"].get(mid, base_p))
		var next_ref: float = 0.85 * old_ref + 0.15 * target_p
		mkt["reference_prices"][mid] = next_ref
		mkt["regular_quotes"][mid] = int(round(next_ref * 0.95))
		mkt["spot_quotes"][mid] = int(round(next_ref * 1.10))
		mkt["regular_quotas_left"][mid] = int(mdef.get("daily_regular_quota_t", 600))
		mkt["spot_quotas_left"][mid] = int(mdef.get("daily_spot_quota_t", 100))
		# 7日滚动窗口自然衰减回归
		mkt["delivered_7d"][mid] = int(round(deliv_7d * 0.86 + demand_7d * 0.12))

	mkt["refined_quotas_left"] = {"alloy_ingot": 150, "pure_wafer": 60}

	# 2. 第 9.5 节：港口吨日仓储费 (0.5 Cr/t/日，研发 C2 后减半至 0.25 Cr/t/日)
	var fee_rate: float = 0.25 if ("C2" in unlocked) else 0.50
	var total_port_t: int = _port_used_tonnes(v40["port_inventories"]["dawn_port"]) + _port_used_tonnes(v40["port_inventories"]["crimson_hub"])
	if total_port_t > 0:
		var storage_fee: int = int(round(float(total_port_t) * fee_rate))
		v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - storage_fee)
		v40["ledger"]["storage_expense_cr"] = int(v40["ledger"]["storage_expense_cr"]) + storage_fee

	# 3. 第 10.5 节：贷款利息 (每 30 游戏日 2%，按日累计)
	var debt: int = int(v40.get("debt_cr", 0))
	if debt > 0:
		var daily_int: int = maxi(1, int(round(float(debt) * (0.02 / 30.0))))
		v40["accrued_interest_cr"] = int(v40.get("accrued_interest_cr", 0)) + daily_int

	# 3b. 记录每日可支配现金与估计净资产双轨历史点，供集团总览趋势图绘制
	var fin_snap: Dictionary = financial_summary(v40)
	var ch_arr: Array = v40.get("cash_history_cr", [30000])
	var nw_arr: Array = v40.get("net_worth_history_cr", [60000])
	ch_arr.append(int(fin_snap.get("available_cash_cr", 30000)))
	nw_arr.append(int(fin_snap.get("estimated_net_worth_cr", 60000)))
	if ch_arr.size() > 60:
		ch_arr.pop_front()
	if nw_arr.size() > 60:
		nw_arr.pop_front()

	# 4. 第 9.7 节：检查合同到期违约（先完成当日交付，再判定到期违约，收取未交付部分 10% 罚金并释放剩余保证金 + 30日发行方冷却）
	var cur_day: float = float(v40.get("game_day", 0.0))
	for c in v40["contracts"]:
		if str(c.get("state", "")) == "active" and cur_day > float(c.get("due_day", 999.0)):
			var undeliv_t: int = maxi(0, int(c["target_t"]) - int(c["delivered_t"]))
			var penalty_cr: int = int(round(float(undeliv_t * int(c["fixed_price_cr"])) * 0.10))
			var dep_cr: int = int(c.get("deposit_cr", 0))
			v40["reserved_cash_cr"] = maxi(0, int(v40["reserved_cash_cr"]) - dep_cr)
			v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - penalty_cr)
			v40["ledger"]["penalty_expense_cr"] = int(v40["ledger"].get("penalty_expense_cr", 0)) + penalty_cr
			c["state"] = "defaulted"
			var issuer: String = str(c.get("issuer", ""))
			v40["issuer_cooldowns"][issuer] = cur_day + 30.0
			_push_merged_notification(v40, "urgent", str(c["id"]), "contract_default", "【%s】合同逾期违约，扣除 10%% 违约金 %d Cr" % [issuer, penalty_cr])
			state.add_log("【合同到期违约】「%s」合同未完成 %d t，从保证金扣除 10%% 违约金 %d Cr，其余保证金已释放。" % [
				issuer, undeliv_t, penalty_cr
			])


static func _sync_legacy_bridge(state: GameState, v40: Dictionary) -> void:
	state.cash_cents = int(v40.get("cash_cr", 30000)) * 100
	state.principal_cents = int(v40.get("debt_cr", 0)) * 100
	state.accrued_interest_cents = int(v40.get("accrued_interest_cr", 0)) * 100
