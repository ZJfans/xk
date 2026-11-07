class_name TechTree
extends RefCounted

## 航天科技研发管理体系：掌控科技升级、加成计算与跨航季生涯持久化

const TECH_FILE := "res://data/tech_tree.json"
const TECH_ORDER: Array[String] = [
	"orbital_radar",
	"titanium_structure",
	"automated_logistics",
	"aerospike_engine",
	"fleet_expansion",
	"laser_drill",
	"isru_refinery",
	"starship_heavy"
]

static func get_tech_definitions() -> Dictionary:
	if not FileAccess.file_exists(TECH_FILE):
		return {}
	var text: String = FileAccess.get_file_as_string(TECH_FILE)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("techs"):
		return (parsed as Dictionary)["techs"]
	return {}

static func is_unlocked(unlocked_list: Array, tech_id: String) -> bool:
	for item in unlocked_list:
		if str(item) == tech_id:
			return true
	return false

static func can_research(unlocked_list: Array, tech_id: String, current_cash: int) -> Dictionary:
	var defs: Dictionary = get_tech_definitions()
	if not defs.has(tech_id):
		return {"ok": false, "reason": "未知的科技项目。"}
	if is_unlocked(unlocked_list, tech_id):
		return {"ok": false, "reason": "该科技已完成研发。"}
	var node: Dictionary = defs[tech_id]
	var cost: int = int(node.get("cost_cents", 0))
	var prereqs: Array = node.get("requires", [])
	for req in prereqs:
		if not is_unlocked(unlocked_list, str(req)):
			var req_name: String = str(defs.get(str(req), {}).get("name_zh", req))
			return {"ok": false, "reason": "需前置：" + req_name}
	if current_cash < cost:
		return {"ok": false, "reason": "差 " + MissionRules.money(cost - current_cash)}
	return {"ok": true, "cost": cost}

static func research(state: GameState, tech_id: String) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束，无法研发科技。"}
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var check: Dictionary = can_research(unlocked, tech_id, state.cash_cents)
	if not check.get("ok", false):
		return {"ok": false, "error": str(check.get("reason", "无法研发。"))}
	var cost: int = int(check["cost"])
	state.cash_cents -= cost
	if not state.stats["expenses"].has("research"):
		state.stats["expenses"]["research"] = 0
	state.stats["expenses"]["research"] = int(state.stats["expenses"]["research"]) + cost
	unlocked.append(tech_id)
	state.stats["unlocked_techs"] = unlocked
	var defs: Dictionary = get_tech_definitions()
	var tech_name: String = str(defs[tech_id]["name_zh"])
	state.add_log("【科技突破】「%s」研发完成（已计入生涯永久科技）！投入经费 %s。" % [tech_name, MissionRules.money(cost)])
	SteamService.unlock_achievement("ACH_TECH_MASTER")
	apply_tech_effects(state)
	return {"ok": true, "tech_name": tech_name, "cost": cost}

static func apply_all_bonuses(state: GameState) -> void:
	apply_tech_effects(state)

static func apply_tech_effects(state: GameState) -> void:
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	if is_unlocked(unlocked, "automated_logistics"):
		state.balance["port_capacity"] = 32
	if is_unlocked(unlocked, "fleet_expansion"):
		state.balance["fleet_limit"] = 4
	if is_unlocked(unlocked, "laser_drill"):
		state.balance["production_ticks"]["crystal"] = 1
	if is_unlocked(unlocked, "orbital_radar"):
		state.balance["scan_price"] = 3000
		state.balance["scan_ticks"] = 1
	if is_unlocked(unlocked, "starship_heavy"):
		state.balance["hulls"]["heavy"] = {
			"price": 42000,
			"dry_mass": 8,
			"mass_cap": 32,
			"slots": 12,
			"travel_ticks": {"near": 2, "mid": 4, "far": 4}
		}
