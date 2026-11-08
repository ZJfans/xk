class_name SharedContracts
extends RefCounted

## 《星矿大亨 Rocket Prospectors》V2.0 架构 · 模块通信协议与共享数据契约 (Shared Contracts)
## 作用：
## 1. 明确 10 大核心模块的命令归属权 (Command Ownership) 与状态写入边界
## 2. 定义统一的 CommandResult 与 DomainEvent 结构，严禁 UI 或特效层直接修改经营账本
## 3. 提供标准化的 Mock 游戏状态生成器 (build_mock_state)，支持 3 个视觉 AI 独立启动 Demo 场景调试

const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const State = preload("res://scripts/state/game_state.gd")

const MODULE_IDS: PackedStringArray = [
	"00_kernel",
	"01_galaxy",
	"02_mining",
	"03_aerospace",
	"04_economy",
	"05_commerce",
	"06_research",
	"07_rivals",
	"08_progression",
	"09_ui_shell",
	"10_visual_audio"
]

const COMMAND_OWNERSHIP: Dictionary = {
	# 01 星系与探索
	"OrbitalSurvey": "01_galaxy",
	"AcquireLicense": "01_galaxy",
	"PlaceBid": "01_galaxy",
	"SetAutoBidLimit": "01_galaxy",
	"SettleCommercialAuction": "01_galaxy",
	# 02 采矿与设施
	"ScanArea": "02_mining",
	"BuildDrill": "02_mining",
	"PlaceMiningHead": "02_mining",
	"RelocateMiningHead": "02_mining",
	"UpgradeFacility": "02_mining",
	"SetMineStatus": "02_mining",
	"SellEquipment": "02_mining",
	"ToggleBoreRouteMode": "02_mining",
	"CancelLastOrder": "02_mining",
	"SaveSurfacePreset": "02_mining",
	"ApplySurfacePreset": "02_mining",
	"SimulateCapacityOverflow": "02_mining",
	# 03 航天与物流
	"PurchaseShip": "03_aerospace",
	"SellShip": "03_aerospace",
	"OverhaulShip": "03_aerospace",
	"AssignRoute": "03_aerospace",
	"ToggleSharedFleetPool": "03_aerospace",
	"SwitchActivePort": "03_aerospace",
	"TransferViaHub": "03_aerospace",
	"SelectLaunchWindow": "03_aerospace",
	"LaunchPadDispatch": "03_aerospace",
	# 04 市场与经济
	"SetSalePolicy": "04_economy",
	"ReserveInventory": "04_economy",
	"ToggleEmergencySale": "04_economy",
	"SellMineralNow": "04_economy",
	"BorrowLoan": "04_economy",
	"RepayLoan": "04_economy",
	"RestructureDebt": "04_economy",
	# 05 合同与商业
	"AcceptContract": "05_commerce",
	"DeliverContract": "05_commerce",
	"CancelContract": "05_commerce",
	"StartRefining": "05_commerce",
	"InvestStarport": "05_commerce",
	# 06 科研与科技
	"StartResearch": "06_research",
	"ToggleResearchPause": "06_research",
	# 08 进度与终局
	"ResolveSpecialEvent": "08_progression",
	"DeliverEndgame": "08_progression",
	"ToggleFamiliarMode": "08_progression"
}


static func get_command_owner(cmd_type: String) -> String:
	return str(COMMAND_OWNERSHIP.get(cmd_type, "00_kernel"))


## 生成供独立视觉 Demo 场景 (`mining_demo.tscn`, `launch_demo.tscn`, `galaxy_demo.tscn`, `corporate_demo.tscn`) 使用的模拟状态
static func build_mock_state(preset: String = "midgame_all") -> GameState:
	var st: GameState = State.new("A", 1, "standard")
	var v40: Dictionary = V40.ensure_v40_state(st)
	if preset in ["midgame_all", "busy_launch_pad", "endgame_corp"]:
		v40["game_day"] = 24.5
		v40["cash_cr"] = 96500
		v40["reserved_cash_cr"] = 6250
		v40["mines"]["dawn_1"]["silo_stock_t"] = 240
		v40["mines"]["dawn_1"]["silo_capacity_t"] = 800
		v40["mines"]["dawn_1"]["platform_upgraded"] = true
		v40["mines"]["dawn_2"]["license_owned"] = true
		v40["mines"]["dawn_2"]["platforms"] = 1
		v40["mines"]["dawn_2"]["silo_stock_t"] = 160
		v40["mines"]["crimson_1"]["survey_stage"] = 2
		for d in v40["mines"]["dawn_1"]["deposits"]:
			d["revealed"] = true
		v40["mines"]["dawn_1"]["deposits"][0]["heads"] = 2
		v40["mines"]["dawn_1"]["deposits"][1]["heads"] = 1
		v40["port_inventories"]["dawn_port"]["minerals"]["iron_titanium"] = 320
		v40["port_inventories"]["dawn_port"]["minerals"]["silicon_crystal"] = 140
		v40["research"]["unlocked"] = ["E1", "M1", "M2", "L1", "C1", "C2"]
		v40["ships"].append({
			"id": 2,
			"type_id": "peregrine_med",
			"name_zh": "游隼可回收 #2",
			"capacity_t": 350,
			"location": "dawn_1",
			"assigned_mine_id": "dawn_1",
			"pending_mine_id": "",
			"dest_port_id": "dawn_port",
			"phase": "inbound",
			"mineral_id": "iron_titanium",
			"cargo_t": 350,
			"wait_days": 0.0,
			"phase_days_left": 0.5,
			"prepaid_fee_cr": 0,
			"trips_completed": 6,
			"overhauled": true,
			"wear_reset_trips": 5
		})
	return st
