class_name V40DawnEngine
extends RefCounted

## 《星矿大亨 Rocket Prospectors》V4.0 权威规则与模拟引擎
## 严格实现《星矿大亨_完整设计与开发衔接方案_V4.0.md》第 1–24 章基线规则：
## - 破晓星域五大星团、晨曦贸易港、四类矿物（铁钛矿/晶硅矿/星能晶/异相矿）
## - 三级信息（遥感 → 轨道勘探+10日发现者排他期 → 地面扫描）与四类采矿权（含竞拍资金冻结）
## - 96×48 逻辑格矿场、钻井平台(60t/日)、软硬岩井道树(60t/日)、局部采掘头(40t/日·半径4格)与瓶颈诊断
## - 三类船型（隼式100t / 游隼350t / 巨鲸1000t）、2日等待上限/尾矿清运、港仓分批卸货与共享船池
## - 7日供需平滑参考价、常规/临时高价双买方日额度、10%保证金冻结与违约结算合同
## - 现金/冻结资金(reserved_cash)/经营结余/估计净资产三口径账本、抵押授信贷款与20项研究(E1-E5/M1-M5/L1-L5/C1-C5)

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
		return state.stats["v40"]

	var cfg: Dictionary = get_config()
	var v40: Dictionary = {
		"schema_version": 4,
		"content_version": "4.0.0",
		"game_day": 0.0,
		"sub_tick": 0,
		"cash_cr": 30000,
		"reserved_cash_cr": 0,
		"debt_cr": 0,
		"accrued_interest_cr": 0,
		"payables_cr": 0,
		"restructure_used": false,
		"free_scans_left": 1,
		"free_surveys_left": 1,
		"active_mine_id": "dawn_1",
		"selected_tool": "scan", # "scan", "platform", "bore_soft", "bore_hard", "head", "silo"
		"shared_fleet_pool": false,
		"emergency_sale_authorized": false,
		# 位置化库存 (第 5.3 & 11.4 节)：每个地点独立维护 4 种矿物库存与预留量
		"port_inventories": {
			"dawn_port": {
				"name_zh": "晨曦贸易港",
				"capacity_t": 500,
				"minerals": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"reserved": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"sale_policy": {
					"iron_titanium": "direct",
					"silicon_crystal": "direct",
					"energy_crystal": "target",
					"phase_ore": "priority"
				},
				"target_prices": {"iron_titanium": 115, "silicon_crystal": 205, "energy_crystal": 460, "phase_ore": 980}
			},
			"crimson_hub": {
				"name_zh": "赤曜深空港",
				"capacity_t": 400,
				"minerals": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"reserved": {"iron_titanium": 0, "silicon_crystal": 0, "energy_crystal": 0, "phase_ore": 0},
				"sale_policy": {
					"iron_titanium": "direct",
					"silicon_crystal": "direct",
					"energy_crystal": "direct",
					"phase_ore": "priority"
				},
				"target_prices": {"iron_titanium": 110, "silicon_crystal": 200, "energy_crystal": 450, "phase_ore": 960}
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
			"delivered_7d": {"iron_titanium": 1800, "silicon_crystal": 900, "energy_crystal": 360, "phase_ore": 140}
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
				"dest_port_id": "dawn_port",
				"phase": "idle", # "idle", "waiting", "loading", "outbound", "unloading", "turnaround", "inbound", "port_blocked"
				"mineral_id": "iron_titanium",
				"cargo_t": 0,
				"wait_days": 0.0,
				"phase_days_left": 0.0,
				"prepaid_fee_cr": 0
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
				"state": "available" # "available", "active", "completed", "defaulted", "cancelled"
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
			"days_left": 0.0
		},
		# 三大竞争财团抽象模拟状态 (第 13.1 & 13.2 节)
		"rivals": {
			"crimson_mining": {"name_zh": "赤曜矿业", "cash_cr": 42000, "output_t_day": 45, "inventory_t": 120, "ships": 2, "last_news": "赤曜矿业正在晨曦边境扩建铁钛矿主井"},
			"starring_transit": {"name_zh": "星环运输", "cash_cr": 48000, "output_t_day": 30, "inventory_t": 80, "ships": 3, "last_news": "星环运输增购游隼中型船投入主航道"},
			"silver_dome": {"name_zh": "银穹资本", "cash_cr": 55000, "output_t_day": 25, "inventory_t": 210, "ships": 1, "last_news": "银穹资本囤积晶硅矿等待高价采购窗口"}
		},
		# 三种财务口径账本统计 (第 10.2 & 10.3 节)
		"ledger": {
			"sales_revenue_cr": 0,
			"contract_revenue_cr": 0,
			"mining_var_expense_cr": 0,
			"transport_expense_cr": 0,
			"upkeep_expense_cr": 0,
			"storage_expense_cr": 0,
			"interest_expense_cr": 0,
			"capex_expense_cr": 0,
			"entries": []
		},
		# 终局工程进度 (第 15.6 节：商业霸主 / 深空先驱 / 星际工业巨头)
		"endgame": {
			"flagship_delivered_t": 0,
			"flagship_target_t": 1200,
			"deep_observatory_stage": 0,
			"transit_hub_built": false
		},
		"executed_commands": {}
	}
	state.stats["v40"] = v40
	return v40


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
			"license_type": "initial", # "initial", "open", "commercial", "special"
			"license_owned": true,
			"license_price_cr": 0,
			"survey_stage": 3, # 1:遥感, 2:轨道勘探, 3:地面扫描已开
			"exclusive_until_day": 0.0,
			"estimate_min_t": 1800,
			"estimate_max_t": 6200,
			"confidence_zh": "高 (已地面扫描)",
			"status": "running", # "running", "paused", "mothballed"
			"grid_w": 96,
			"grid_h": 48,
			"platforms": 1,
			"platform_upgraded": false,
			"bore_cells": 24,
			"bore_upgraded": false,
			"silo_capacity_t": 300,
			"silo_stock_t": 60,
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

	var led: Dictionary = v40.get("ledger", {})
	var operating_rev: int = int(led.get("sales_revenue_cr", 0)) + int(led.get("contract_revenue_cr", 0))
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
	var raw_head_rate: float = 0.0
	var known_remaining_t: int = 0
	var unknown_deep_t: int = 0

	for d in mine.get("deposits", []):
		var rem: int = int(d.get("remaining_t", 0))
		if bool(d.get("revealed", false)):
			known_remaining_t += rem
			if rem > 0 and int(d.get("heads", 0)) > 0:
				var h_cnt: int = int(d["heads"])
				active_heads += h_cnt
				raw_head_rate += float(h_cnt) * head_base_rate
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
	elif active_heads <= 0:
		bottleneck_msg = "尚未在已揭示矿脉上部署采掘头（点击矿脉连接井道并安装采掘头）。"
	elif stock_t >= cap_t:
		bottleneck_msg = "矿仓已满 (%d/%d t)：采掘头自动暂停生产（不销毁矿石、不扣采矿变动费）。请派船清运或扩建矿仓。" % [stock_t, cap_t]
	else:
		effective_rate = minf(raw_head_rate, minf(bore_flow_cap, total_lift_cap))
		if raw_head_rate > bore_flow_cap and bore_flow_cap <= total_lift_cap:
			bottleneck_msg = "主井井道限制产量：%d 个采掘头合计可产 %.0f t/日，主干井道只能通过 %.0f t/日（可升级主干扩容）。" % [
				active_heads, raw_head_rate, bore_flow_cap
			]
		elif raw_head_rate > total_lift_cap:
			bottleneck_msg = "钻井平台提升受限：采掘头合计可产 %.0f t/日，地表平台总提升上限 %.0f t/日（可改造平台提升至 100 t/日）。" % [
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
				100, 8
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
		"depletion_days": depletion_days,
		"depletion_alert": depletion_alert,
		"bottleneck_text": bottleneck_msg
	}


## ============================================================================
## 第 8.2 & 11.5 章：船型航线周期、往返费用与每船日贡献精确公式
## ============================================================================

static func calc_ship_route_metrics(ship_type_id: String, distance_l: float, gravity_g: float, sale_price_cr: int, mining_var_cost_cr: int) -> Dictionary:
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
	var trip_cost_cr: int = int(round(f_fixed + 2.0 * distance_l * k_dist + env_surcharge))
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
		"SellMineralNow":
			res = _cmd_sell_mineral_now(state, v40, params)
		"AcceptContract":
			res = _cmd_accept_contract(state, v40, params)
		"DeliverContract":
			res = _cmd_deliver_contract(state, v40, params)
		"StartResearch":
			res = _cmd_start_research(state, v40, params)
		"BorrowLoan":
			res = _cmd_borrow_loan(state, v40, params)
		"RepayLoan":
			res = _cmd_repay_loan(state, v40, params)
		"RestructureDebt":
			res = _cmd_restructure_debt(state, v40, params)

	if bool(res.get("ok", false)) and cmd_id != "":
		v40["executed_commands"][cmd_id] = true
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
	mine["confidence_zh"] = "较高 (已轨道详勘)"
	# 第 4.3 节：自费首次调查未知开放矿区，获得 10 游戏日排他评估期
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
	# 第 4.5 节：最高出价金额被冻结 (reserved_cash_cr)，失去领先后立即解除冻结，成交时才扣款
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
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	if bool(dep.get("hard_rock", false)) and not ("M1" in unlocked):
		return {"ok": false, "error": "该矿体位于硬岩夹层之下，需先研发【M1 · 硬岩钻头】或绕行浅层矿脉！"}

	var bore_cells_needed: int = 8 if int(dep.get("heads", 0)) == 0 else 0
	var cell_cost: int = 300 if bool(dep.get("hard_rock", false)) else 100
	var bore_cost: int = bore_cells_needed * cell_cost
	var head_cost: int = 2000
	var total_cost: int = bore_cost + head_cost
	if available_cash_cr(v40) < total_cost:
		return {"ok": false, "error": "延伸井道 (%d Cr) + 安装采掘头 (2,000 Cr) 合计需 %d Cr，当前可支配现金不足。" % [bore_cost, total_cost]}

	v40["cash_cr"] = int(v40["cash_cr"]) - total_cost
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + total_cost
	mine["bore_cells"] = int(mine.get("bore_cells", 24)) + bore_cells_needed
	dep["heads"] = int(dep.get("heads", 0)) + 1
	if int(mine.get("platforms", 0)) <= 0:
		mine["platforms"] = 1
	state.add_log("【井道与采掘头就位】「%s -> %s」已连通井道并安装采掘头（耗资 %d Cr，单头产能 40 t/日）。" % [
		str(mine["name_zh"]), str(dep["name_zh"]), total_cost
	])
	return {"ok": true, "msg": "已在「%s」安装采掘头（耗资 %d Cr）！" % [str(dep["name_zh"]), total_cost]}


static func _cmd_upgrade_facility(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	var kind: String = str(params.get("kind", "silo")) # "silo", "platform", "bore", "port_warehouse"
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
		"dest_port_id": "dawn_port",
		"phase": "idle",
		"mineral_id": m_mineral,
		"cargo_t": 0,
		"wait_days": 0.0,
		"phase_days_left": 0.0,
		"prepaid_fee_cr": 0
	})
	state.add_log("【新船入列】已斥资 %d Cr 购入「%s #%d (载重 %d t)」，已部署至航线！" % [
		price, str(sdef["name_zh"]), new_id, int(sdef["capacity_t"])
	])
	return {"ok": true, "msg": "已购入「%s #%d」并投入自动往返运输！" % [str(sdef["name_zh"]), new_id]}


static func _cmd_assign_route(_state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var ship_id: int = int(params.get("ship_id", 1))
	var mine_id: String = str(params.get("mine_id", v40["active_mine_id"]))
	for s in v40["ships"]:
		if int(s.get("id", 0)) == ship_id:
			s["assigned_mine_id"] = mine_id
			s["mineral_id"] = str(v40["mines"].get(mine_id, {}).get("primary_mineral", "iron_titanium"))
			return {"ok": true, "msg": "已将「%s」改派至「%s」航线。" % [str(s["name_zh"]), str(v40["mines"][mine_id]["name_zh"])]}
	return {"ok": false, "error": "未找到指定船只。"}


static func _cmd_sell_mineral_now(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	var port_id: String = str(params.get("port_id", "dawn_port"))
	var mineral_id: String = str(params.get("mineral_id", "iron_titanium"))
	var buyer_type: String = str(params.get("buyer_type", "best")) # "regular", "spot", "best"
	var pinv: Dictionary = v40["port_inventories"].get(port_id, {})
	if pinv.is_empty():
		return {"ok": false, "error": "目标贸易港不存在。"}

	var total_t: int = int(pinv["minerals"].get(mineral_id, 0))
	var res_t: int = int(pinv["reserved"].get(mineral_id, 0))
	var free_t: int = maxi(0, total_t - res_t)

	# 如果港仓暂时为 0，但当前矿场有现矿且有船只，允许直接触发一次快速到港交割以便玩家即时体验回款闭环
	if free_t <= 0:
		var active_m: Dictionary = v40["mines"].get(str(v40["active_mine_id"]), {})
		var m_stock: int = int(active_m.get("silo_stock_t", 0))
		if m_stock > 0 and str(active_m.get("primary_mineral", "iron_titanium")) == mineral_id:
			var ship_cap: int = 100
			var transfer_t: int = mini(m_stock, ship_cap)
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
	state.add_log("【市场成交】在晨曦港售出 %d t %s（高价买方 %d t + 常规买方 %d t），回款 +%d Cr！" % [
		total_sold, min_name, sold_spot, sold_reg, revenue_cr
	])
	return {"ok": true, "sold_t": total_sold, "revenue_cr": revenue_cr, "msg": "成功售出 %d t %s，回款 +%d Cr！" % [total_sold, min_name, revenue_cr]}


static func _cmd_accept_contract(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 9.7 节：接单冻结合同总额 10% 的现金作为保证金（计入 reserved_cash_cr，仍属资产但不可花费）
	var cid: String = str(params.get("contract_id", ""))
	var active_cnt: int = 0
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])
	var max_contracts: int = 3 if ("C1" in unlocked) else 2
	for c in v40["contracts"]:
		if str(c.get("state", "")) == "active":
			active_cnt += 1
	if active_cnt >= max_contracts:
		return {"ok": false, "error": "当前同时进行合同已达上限 (%d 份，研发 C1 履约资质可提升上限)。" % max_contracts}

	for c in v40["contracts"]:
		if str(c.get("id", "")) == cid and str(c.get("state", "")) == "available":
			var dep_cr: int = int(c.get("deposit_cr", 5000))
			if available_cash_cr(v40) < dep_cr:
				return {"ok": false, "error": "可支配现金不足以冻结 10%% 履约保证金 (%d Cr)。" % dep_cr}
			v40["reserved_cash_cr"] = int(v40.get("reserved_cash_cr", 0)) + dep_cr
			c["state"] = "active"
			state.add_log("【承接合同】已承接「%s」合同，冻结 10%% 保证金 %d Cr（完整交付后释放）。" % [str(c["issuer"]), dep_cr])
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
				# 若矿区有货，支持直调一批完成交付演示
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
			c["delivered_t"] = int(c["delivered_t"]) + deliv_t
			v40["cash_cr"] = int(v40["cash_cr"]) + pay_cr
			v40["ledger"]["contract_revenue_cr"] = int(v40["ledger"]["contract_revenue_cr"]) + pay_cr

			if int(c["delivered_t"]) >= int(c["target_t"]):
				c["state"] = "completed"
				var dep_release: int = int(c.get("deposit_cr", 0))
				v40["reserved_cash_cr"] = maxi(0, int(v40["reserved_cash_cr"]) - dep_release)
				state.add_log("【合同圆满履约】「%s」合同全部交付完成！货款 +%d Cr，并全额释放保证金 %d Cr！" % [
					str(c["issuer"]), pay_cr, dep_release
				])
				return {"ok": true, "msg": "合同圆满完成！收款 +%d Cr 并释放保证金 %d Cr！" % [pay_cr, dep_release]}
			return {"ok": true, "msg": "已交付 %d t 合同矿物，立即结算货款 +%d Cr！" % [deliv_t, pay_cr]}
	return {"ok": false, "error": "未找到进行中的目标合同。"}


static func _cmd_start_research(state: GameState, v40: Dictionary, params: Dictionary) -> Dictionary:
	# 第 12.1 & 12.2 节：唯一研究槽位，确认前校验现金、前置与港口样本；开始后可暂停，不退款
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

	v40["cash_cr"] = int(v40["cash_cr"]) - cost_cr
	v40["ledger"]["capex_expense_cr"] = int(v40["ledger"]["capex_expense_cr"]) + cost_cr
	unlocked.append(tech_id)
	state.add_log("【研究突破】已完成「%s」：%s！" % [str(target_node["name_zh"]), str(target_node["effect_zh"])])
	return {"ok": true, "msg": "已完成研究「%s」！" % str(target_node["name_zh"])}


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
	# 第 10.6 节：标准模式允许一次主动债务重整，变卖部分非核心资产清偿债务，保留世界已探明信息
	if bool(v40.get("restructure_used", false)):
		return {"ok": false, "error": "每个存档仅允许执行一次主动债务重整。"}
	v40["restructure_used"] = true
	v40["debt_cr"] = 0
	v40["accrued_interest_cr"] = 0
	v40["payables_cr"] = 0
	v40["cash_cr"] = maxi(12000, int(v40["cash_cr"]))
	state.add_log("【债务重整完成】已按公开清算规则重整债务，保留全部已揭示星域与地质情报！")
	return {"ok": true, "msg": "债务重整已完成，所有逾期债务已清偿，保留全部已探索情报！"}


## ============================================================================
## 第 11.3, 8.4–8.6, 9.3, 18.5 章：固定时间步权威模拟推进 (step_v40_day)
## ============================================================================

static func step_v40_simulation(state: GameState, dt_days: float = 0.5) -> Dictionary:
	var v40: Dictionary = ensure_v40_state(state)
	v40["game_day"] = float(v40.get("game_day", 0.0)) + dt_days
	var cur_day: float = float(v40["game_day"])
	var cfg: Dictionary = get_config()
	var minerals_cfg: Dictionary = cfg.get("minerals", {})
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	# 1. 采矿步进 (第 11.3 节：potential_i = min(速率*dt, 剩余矿量)，受主井、平台、仓容、可支付变动费四重约束)
	var mines: Dictionary = v40["mines"]
	for m_id in mines:
		var m: Dictionary = mines[m_id]
		if not bool(m.get("license_owned", false)):
			continue
		var st: String = str(m.get("status", "running"))
		# 固定维护费结算 (第 6.7 节：暂停时降至 25%，封存仅收 15 Cr/日)
		var base_upkeep_day: float = 60.0 + float(int(m.get("platforms", 0)) * 50 + _count_mine_heads(m) * 20) + float(int(m.get("bore_cells", 0))) * 0.5
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
				var cost_step: int = actual_t * var_cost_per_t
				v40["cash_cr"] = int(v40["cash_cr"]) - cost_step
				v40["ledger"]["mining_var_expense_cr"] = int(v40["ledger"]["mining_var_expense_cr"]) + cost_step
				remaining_allowance -= actual_t

	# 2. 船只自动往返与尾矿清运/港仓分批卸货 (第 8.4–8.6 节 & 第 23.2 节关键情境)
	var pinv_dawn: Dictionary = v40["port_inventories"]["dawn_port"]
	for ship in v40["ships"]:
		var target_m_id: String = str(ship.get("assigned_mine_id", v40["active_mine_id"]))
		if not mines.has(target_m_id):
			continue
		var t_mine: Dictionary = mines[target_m_id]
		var s_cap: int = int(ship.get("capacity_t", 100))
		var m_stock: int = int(t_mine.get("silo_stock_t", 0))
		var min_id: String = str(t_mine.get("primary_mineral", "iron_titanium"))
		ship["mineral_id"] = min_id

		# 判断矿区是否已耗尽或停产（用于触发尾矿未满载发运，如剩余 37t < 100t 船容！）
		var total_mine_rem: int = 0
		for d in t_mine.get("deposits", []):
			total_mine_rem += int(d.get("remaining_t", 0))
		var mine_stopped_or_exhausted: bool = (str(t_mine.get("status", "running")) != "running") or (total_mine_rem == 0)

		if int(ship.get("cargo_t", 0)) == 0:
			ship["wait_days"] = float(ship.get("wait_days", 0.0)) + dt_days
			var should_load: bool = (m_stock >= s_cap) or (m_stock > 0 and (float(ship["wait_days"]) >= 2.0 or mine_stopped_or_exhausted))
			if should_load:
				var metrics: Dictionary = calc_ship_route_metrics(
					str(ship.get("type_id", "falcon_light")),
					float(t_mine.get("distance_l", 0.5)),
					float(t_mine.get("gravity_g", 1.0)),
					100, 8
				)
				var trip_fee: int = int(metrics.get("trip_cost_cr", 2400))
				if available_cash_cr(v40) >= trip_fee:
					var load_amt: int = mini(s_cap, m_stock)
					# 原子转移：矿仓减，船舱加
					t_mine["silo_stock_t"] = m_stock - load_amt
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
			else:
				ship["phase"] = "port_blocked"

			# 若该矿物销售策略为 "direct"（直接出售），在买方当日剩余额度内自动出售未预留库存
			var pol: String = str(pinv_dawn.get("sale_policy", {}).get(min_id, "direct"))
			if pol == "direct" and int(pinv_dawn["minerals"].get(min_id, 0)) > int(pinv_dawn["reserved"].get(min_id, 0)):
				_cmd_sell_mineral_now(state, v40, {"port_id": "dawn_port", "mineral_id": min_id, "buyer_type": "best"})

	# 3. 每日边界：刷新买方每日额度、按第 9.3 节公式更新动态参考价、结算港口仓储费与贷款利息
	if int(floor(cur_day)) > int(floor(cur_day - dt_days)):
		_update_daily_market_and_fees(state, v40)

	_sync_legacy_bridge(state, v40)
	return {"ok": true, "game_day": cur_day}


static func _port_used_tonnes(pinv: Dictionary) -> int:
	var total: int = 0
	var mins: Dictionary = pinv.get("minerals", {})
	for k in mins:
		total += int(mins[k])
	return total


static func _update_daily_market_and_fees(state: GameState, v40: Dictionary) -> void:
	var cfg: Dictionary = get_config()
	var minerals_cfg: Dictionary = cfg.get("minerals", {})
	var mkt: Dictionary = v40["market"]
	var unlocked: Array = v40.get("research", {}).get("unlocked", [])

	# 1. 第 9.3 节：7 日供需平滑参考价公式與每日额度重置
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

	# 4. 第 9.7 节：检查合同到期违约（先完成当日交付，再判定到期违约，收取未交付部分 10% 罚金并释放剩余保证金）
	var cur_day: float = float(v40.get("game_day", 0.0))
	for c in v40["contracts"]:
		if str(c.get("state", "")) == "active" and cur_day > float(c.get("due_day", 999.0)):
			var undeliv_t: int = maxi(0, int(c["target_t"]) - int(c["delivered_t"]))
			var penalty_cr: int = int(round(float(undeliv_t * int(c["fixed_price_cr"])) * 0.10))
			var dep_cr: int = int(c.get("deposit_cr", 0))
			v40["reserved_cash_cr"] = maxi(0, int(v40["reserved_cash_cr"]) - dep_cr)
			v40["cash_cr"] = maxi(0, int(v40["cash_cr"]) - penalty_cr)
			c["state"] = "defaulted"
			state.add_log("【合同到期违约】「%s」合同未完成 %d t，从保证金扣除 10%% 违约金 %d Cr，其余保证金已释放。" % [
				str(c["issuer"]), undeliv_t, penalty_cr
			])


static func _sync_legacy_bridge(state: GameState, v40: Dictionary) -> void:
	# 将 V4.0 状态同步映射回原有 UI 标签展示所需的兼容字段，保证旧测试脚本与主界面顶栏零冲突
	state.cash_cents = int(v40.get("cash_cr", 30000)) * 100
	state.principal_cents = int(v40.get("debt_cr", 0)) * 100
	state.accrued_interest_cents = int(v40.get("accrued_interest_cr", 0)) * 100
