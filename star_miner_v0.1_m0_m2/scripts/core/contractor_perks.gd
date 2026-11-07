class_name ContractorPerks
extends RefCounted

## 星际承包商财团流派系统 (Contractor Corporations / Starting Doctrines)
## 为 Steam 玩家提供多维度的开局策略流派，极大丰富重玩价值；默认 "standard" 保持基准算术不变。

const PERKS: Array[Dictionary] = [
	{
		"id": "standard",
		"name_zh": "标准独立承包商",
		"name_en": "Standard Prospector",
		"desc_zh": "均衡标准配置：开局现金 $1,000，无特殊修正（官方基准挑战配置）。"
	},
	{
		"id": "titan_heavy",
		"name_zh": "泰坦重工集团",
		"name_en": "Titan Heavy Industries",
		"desc_zh": "开局机库自带 1 艘待命的「中型复用箭 #1」（价值 $400），开局现金调整为 $600。"
	},
	{
		"id": "vanguard_survey",
		"name_zh": "先锋深空勘探局",
		"name_en": "Vanguard Survey Corp",
		"desc_zh": "全星图未知矿藏开局直接探明（免除遥感探测费与等待），且星球开发许可费减半至 $50。"
	},
	{
		"id": "hyperion_lab",
		"name_zh": "海伯利安推进实验室",
		"name_en": "Hyperion Propulsion Lab",
		"desc_zh": "开局免费掌握「钛铝合金轻量结构」科技（全箭体干重 -1），释放起飞载荷极限。"
	},
	{
		"id": "venture_capital",
		"name_zh": "银河风险投资基金",
		"name_en": "Galactic Venture Capital",
		"desc_zh": "开局获得 $400 额外信贷注资（开局现金 $1,400，附带 $400 初始贷款），信贷上限提至 $800。"
	}
]

static func get_perk(perk_id: String) -> Dictionary:
	for item in PERKS:
		if str(item["id"]) == perk_id:
			return item
	return PERKS[0]

static func apply_to_state(state: GameState, perk_id: String) -> void:
	if perk_id == "" or perk_id == "standard":
		return
	match perk_id:
		"titan_heavy":
			# 注入 1 艘待命的中型复用箭，同时扣除 $400 购置成本并记入账本以保持现金守恒
			var hull_cost := int(state.balance["hulls"]["medium"]["price"])
			var rec_cost := int(state.balance["recovery"]["price"])
			var total_cost := hull_cost + rec_cost
			state.cash_cents -= total_cost
			state.stats["expenses"]["hull"] = int(state.stats["expenses"]["hull"]) + hull_cost
			state.stats["expenses"]["return_equipment"] = int(state.stats["expenses"]["return_equipment"]) + rec_cost
			var first_star := str(state.stars.keys()[0]) if not state.stars.is_empty() else "near_metal"
			var ship := {
				"id": state.next_ship_id,
				"mode": "medium_reuse",
				"trips": 0,
				"mission_id": 0,
				"star_id": first_star,
				"state": "idle",
				"event_tick": 0,
				"travel_ticks": 3,
				"planned_cargo": 6,
				"cargo": 0,
				"ret_fuel_budget": 0,
				"deliver_miner": false,
				"deliver_silo": false
			}
			state.next_ship_id += 1
			state.ships.append(ship)
			state.add_log("【流派特性：泰坦重工】机库已预置中型复用箭 #1，随时可派遣！")
		"vanguard_survey":
			state.balance["license_fee"] = 5000
			for star_id in state.stars:
				state.stars[star_id]["revealed"] = true
			state.add_log("【流派特性：先锋勘探】全星域地下储量已探明，星球许可费减半至 $50！")
		"hyperion_lab":
			var unlocked: Array = state.stats.get("unlocked_techs", [])
			if not TechTree.is_unlocked(unlocked, "titanium_structure"):
				unlocked.append("titanium_structure")
				state.stats["unlocked_techs"] = unlocked
			TechTree.apply_tech_effects(state)
			state.add_log("【流派特性：海伯利安】已预装钛铝合金轻量结构，全箭体干重 -1！")
		"venture_capital":
			state.balance["loan_limit"] = 80000
			var initial_loan := 40000
			state.cash_cents += initial_loan
			state.principal_cents += initial_loan
			state.add_log("【流派特性：银河风投】已注入 $400 风险信贷资金，信贷总额度提升至 $800！")
	state.cash_history = [state.cash_cents]
