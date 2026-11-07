class_name GameState
extends RefCounted

const BALANCE_PATH := "res://data/balance_v01.json"
const SAVE_FORMAT := 1
const ProcGen = preload("res://scripts/core/procedural_generator.gd")
const Perks = preload("res://scripts/core/contractor_perks.gd")
const Tycoon = preload("res://scripts/core/galactic_tycoon.gd")

var _base_balance: Dictionary = {}
var balance: Dictionary = {}
var scenario_id: String = "A"
var perk_id: String = "standard"
var current_tick: int = 0
var cash_cents: int = 100000
var principal_cents: int = 0
var accrued_interest_cents: int = 0
var stars: Dictionary = {}
var ships: Array = []
var port_storage: Dictionary = {"metal": 0, "crystal": 0}
var sale_policies: Dictionary = {"metal": "immediate", "crystal": "immediate"}
var orders: Array = []
var active_scan: Dictionary = {}
var active_event: Dictionary = {}
var cash_history: Array = []
var next_ship_id: int = 1
var next_mission_id: int = 1
var season_ended: bool = false
var settlement: Dictionary = {}
var event_log: Array = []
var tutorial_stage: int = 0
var tutorial_dismissed: bool = false
var auto_pause: bool = true
var sound_enabled: bool = true
var events_enabled: bool = false
var endless_mode: bool = false
var sector_seed: int = 0
var stats: Dictionary = {}
var challenge_id: String = ""

func _init(which: String = "A", custom_seed: int = 0, chosen_perk: String = "standard") -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if not (parsed is Dictionary):
		push_error("无法读取规则参数 " + BALANCE_PATH)
		return
	_base_balance = parsed.duplicate(true)
	balance = _base_balance.duplicate(true)
	reset(which, custom_seed, chosen_perk)

func _inject_far_route() -> void:
	balance["routes"]["far"] = {"numerator": 9, "denominator": 20}
	balance["hulls"]["light"]["travel_ticks"]["far"] = 5
	balance["hulls"]["medium"]["travel_ticks"]["far"] = 7
	if balance["hulls"].has("heavy"):
		balance["hulls"]["heavy"]["travel_ticks"]["far"] = 4

func reset(which: String = "A", custom_seed: int = 0, chosen_perk: String = "standard") -> void:
	balance = _base_balance.duplicate(true)
	_inject_far_route()
	scenario_id = which if which in ["A", "B", "C2", "C20", "G", "D", "S", "E", "X"] else "A"
	perk_id = chosen_perk if chosen_perk != "" else "standard"
	current_tick = 0
	cash_cents = int(balance.get("starting_cash", 100000))
	principal_cents = 0
	accrued_interest_cents = 0
	stars = {}
	ships = []
	port_storage = {"metal": 0, "crystal": 0}
	sale_policies = {"metal": "immediate", "crystal": "immediate"}
	orders = []
	active_scan = {}
	active_event = {}
	cash_history = [cash_cents]
	next_ship_id = 1
	next_mission_id = 1
	season_ended = false
	settlement = {}
	event_log = []
	tutorial_stage = 0
	tutorial_dismissed = false
	challenge_id = ""
	endless_mode = (scenario_id == "E")
	events_enabled = (scenario_id in ["S", "E", "X"])
	if endless_mode:
		balance["season_ticks"] = 9999
	elif scenario_id == "X":
		balance["season_ticks"] = 90 # 星系霸权模式每季 45 日 (90 ticks)，纵深经营大星系
	sector_seed = custom_seed
	stats = {
		"expenses": {"hull": 0, "return_equipment": 0, "miner": 0, "silo": 0,
			"license": 0, "fuel": 0, "launch": 0, "refit": 0, "scan": 0, "interest": 0, "research": 0},
		"revenue": 0, "ship_sale_revenue": 0, "salvage_revenue": 0,
		"sold": {"metal": 0, "crystal": 0},
		"order_sold": 0, "completed_trips": 0, "partial_returns": 0,
		"trips_by_mode": {"light": 0, "medium_once": 0, "medium_reuse": 0, "heavy_reuse": 0},
		"fuel_bought": 0, "fuel_burned": 0, "fuel_vented": 0,
		"unlocked_techs": [],
		"tycoon": Tycoon.init_tycoon_meta()
	}
	if scenario_id == "B":
		stars["cache"] = _make_star("cache", "遗留晶体仓", "crystal", "near", "normal", 0, 8, true, 0, 0)
		stars["near_metal"] = _make_star("near_metal", "铁砾星", "metal", "near", "normal", 48, 0, true, 48, 48)
	elif scenario_id == "D":
		stars["near_metal"] = _make_star("near_metal", "铁砾星", "metal", "near", "normal", 40, 0, true, 40, 40)
		stars["veil_crystal"] = _make_star("veil_crystal", "薄晶带", "crystal", "near", "normal", 6, 0, false, 4, 12)
		stars["mid_crystal"] = _make_star("mid_crystal", "晶芒星", "crystal", "mid", "normal", 14, 0, true, 14, 14)
		stars["anchor_metal"] = _make_star("anchor_metal", "沉锚星", "metal", "mid", "high_g", 48, 8, true, 48, 48)
		stars["near_metal"]["map_position"] = [0.28, 0.18]
		stars["veil_crystal"]["map_position"] = [0.42, 0.38]
		stars["mid_crystal"]["map_position"] = [0.66, 0.36]
		stars["anchor_metal"]["map_position"] = [0.86, 0.15]
	elif scenario_id == "X":
		if sector_seed == 0:
			sector_seed = int(Time.get_unix_time_from_system()) % 1000000 + 2026
		stars = Tycoon.generate_vast_galaxy(sector_seed)
	elif scenario_id in ["S", "E"]:
		if sector_seed == 0:
			sector_seed = int(Time.get_unix_time_from_system()) % 1000000 + 1000
		var p_count := 4 if sector_seed == 424242 else 7
		stars = ProcGen.generate_sector(sector_seed, p_count)
	else:
		stars["near_metal"] = _make_star("near_metal", "铁砾星", "metal", "near", "normal", 48, 0, true, 48, 48)
		if scenario_id == "G":
			stars["mid_crystal"] = _make_star("mid_crystal", "重力晶核", "crystal", "near", "high_g", 20, 0, true, 20, 20)
		elif scenario_id == "C2" or scenario_id == "C20":
			var reserve_amount := 2 if scenario_id == "C2" else 20
			stars["mid_crystal"] = _make_star("mid_crystal", "未明晶星", "crystal", "mid", "normal", reserve_amount, 0, false, 2, 20)
		else:
			stars["mid_crystal"] = _make_star("mid_crystal", "晶芒星", "crystal", "mid", "normal", 12, 0, true, 12, 12)
	for opening in [8, 16, 24]:
		orders.append(_make_order(orders.size() + 1, "metal", (opening - 3) * 2, opening * 2, (opening + 3) * 2, 6, 15000))
	if scenario_id == "B":
		orders.append(_make_order(4, "crystal", 0, 3, 5, 4, 40000))
	elif scenario_id == "C2" or scenario_id == "C20":
		orders.append(_make_order(4, "crystal", 0, 24, 30, 6, 40000))
	elif scenario_id in ["D", "S", "E", "X"]:
		orders.append(_make_order(4, "crystal", 12, 20, 32, 6, 40000))
		if scenario_id == "X":
			orders.append(_make_order(5, "crystal", 36, 44, 62, 10, 44000))
			orders.append(_make_order(6, "metal", 52, 60, 78, 12, 18000))
	add_log("开采季开始。先选择目标，再配置你的第一枚火箭。")
	Perks.apply_to_state(self, perk_id)

func _make_star(id: String, title: String, ore: String, route: String, env: String,
		reserve_amount: int, initial_stock: int, revealed: bool, low: int, high: int) -> Dictionary:
	return {
		"id": id, "name": title, "ore": ore, "route": route, "environment": env,
		"zone": "近轨行星带" if route == "near" else "中距小行星带",
		"reserve": reserve_amount, "initial_reserve": reserve_amount, "initial_stock": initial_stock,
		"deep_reserve": 28 if ore == "metal" else 18, "deep_unlocked": false, "pipe_level": 1,
		"stock": initial_stock, "public_min": low, "public_max": high,
		"revealed": revealed, "licensed": false, "has_miner": false, "has_silo": false,
		"next_production_tick": 0, "produced": 0, "shipped": 0, "stalled_ticks": 0,
		"exhausted_announced": revealed and reserve_amount == 0
	}

func _make_order(id: int, ore: String, announce: int, opening: int, closing: int, quantity: int, price: int) -> Dictionary:
	return {"id": id, "ore": ore, "announce_tick": announce, "open_tick": opening,
		"close_tick": closing, "quantity": quantity, "sold": 0, "price": price, "closed": false}

func add_log(message: String) -> void:
	event_log.append({"tick": current_tick, "text": message})
	if event_log.size() > 100:
		event_log.pop_front()

func get_ship(ship_id: int) -> Dictionary:
	for ship in ships:
		if int(ship.get("id", -1)) == ship_id:
			return ship
	return {}

func active_reusable_ships() -> int:
	var count: int = 0
	for s in ships:
		if MissionRules.is_reusable_mode(str(s.get("mode", ""))):
			count += 1
	return count

func port_total() -> int:
	return int(port_storage.get("metal", 0)) + int(port_storage.get("crystal", 0))

func public_reserve(star: Dictionary) -> Dictionary:
	if bool(star["revealed"]) or bool(star["exhausted_announced"]):
		var exact := int(star["reserve"])
		return {"min": exact, "max": exact, "exact": true}
	var produced := int(star["produced"])
	return {"min": maxi(0, int(star["public_min"]) - produced),
		"max": maxi(0, int(star["public_max"]) - produced), "exact": false}

func to_dict() -> Dictionary:
	return {
		"save_format": SAVE_FORMAT, "rules_version": str(balance.get("version", "")),
		"balance_hash": FileAccess.get_sha256(BALANCE_PATH), "scenario_id": scenario_id,
		"perk_id": perk_id,
		"current_tick": current_tick, "cash_cents": cash_cents,
		"principal_cents": principal_cents, "accrued_interest_cents": accrued_interest_cents,
		"stars": stars.duplicate(true), "ships": ships.duplicate(true),
		"port_storage": port_storage.duplicate(true), "sale_policies": sale_policies.duplicate(true),
		"orders": orders.duplicate(true), "active_scan": active_scan.duplicate(true),
		"active_event": active_event.duplicate(true),
		"cash_history": cash_history.duplicate(true),
		"next_ship_id": next_ship_id, "next_mission_id": next_mission_id,
		"season_ended": season_ended, "settlement": settlement.duplicate(true),
		"event_log": event_log.duplicate(true), "stats": stats.duplicate(true),
		"tutorial_stage": tutorial_stage, "tutorial_dismissed": tutorial_dismissed,
		"auto_pause": auto_pause, "sound_enabled": sound_enabled,
		"events_enabled": events_enabled, "endless_mode": endless_mode, "sector_seed": sector_seed,
		"challenge_id": challenge_id
	}

func load_dict(raw: Dictionary) -> Dictionary:
	var source = _normalize_numbers(raw)
	if int(source.get("save_format", -1)) != SAVE_FORMAT:
		return {"ok": false, "error": "存档格式不兼容，请开始新局。"}
	if str(source.get("rules_version", "")) != str(_base_balance.get("version", "")) or str(source.get("balance_hash", "")) != FileAccess.get_sha256(BALANCE_PATH):
		return {"ok": false, "error": "规则参数已改变，旧存档不能直接套用，请开始新局。"}
	for key in ["stars", "ships", "port_storage", "sale_policies", "orders", "stats"]:
		if not source.has(key):
			return {"ok": false, "error": "存档缺少必要数据：" + key}
	if not (source["stars"] is Dictionary) or source["stars"].is_empty() or not (source["ships"] is Array) or not (source["orders"] is Array) or not (source["port_storage"] is Dictionary) or not (source["sale_policies"] is Dictionary) or not (source["stats"] is Dictionary):
		return {"ok": false, "error": "存档结构不完整，无法安全恢复。"}
	var is_endless := bool(source.get("endless_mode", false)) or str(source.get("scenario_id", "A")) == "E"
	var is_galaxy := str(source.get("scenario_id", "A")) == "X"
	var max_allowed_ticks := 9999 if is_endless else (90 if is_galaxy else int(_base_balance["season_ticks"]))
	if int(source.get("current_tick", -1)) < 0 or int(source.get("current_tick", -1)) > max_allowed_ticks or int(source.get("cash_cents", -1)) < 0:
		return {"ok": false, "error": "存档中的日期或现金无效。"}
	for ore in ["metal", "crystal"]:
		if not source["port_storage"].has(ore) or not source["sale_policies"].has(ore):
			return {"ok": false, "error": "存档缺少矿产数据。"}
	for star_id in source["stars"]:
		var candidate = source["stars"][star_id]
		if not (candidate is Dictionary):
			return {"ok": false, "error": "存档中的星球数据无效。"}
		for field_name in ["name", "ore", "route", "environment", "reserve", "stock", "revealed", "has_miner", "has_silo", "licensed", "next_production_tick", "public_min", "public_max", "produced", "shipped", "exhausted_announced", "stalled_ticks"]:
			if not candidate.has(field_name):
				return {"ok": false, "error": "存档中的星球数据不完整。"}
	for ship in source["ships"]:
		if not (ship is Dictionary) or not ship.has("star_id") or not source["stars"].has(str(ship["star_id"])):
			return {"ok": false, "error": "存档中的火箭数据无效。"}
	balance = _base_balance.duplicate(true)
	_inject_far_route()
	scenario_id = str(source.get("scenario_id", "A"))
	perk_id = str(source.get("perk_id", "standard"))
	if perk_id == "vanguard_survey":
		balance["license_fee"] = 5000
	elif perk_id == "venture_capital":
		balance["loan_limit"] = 80000
	current_tick = int(source.get("current_tick", 0))
	cash_cents = int(source.get("cash_cents", 0))
	principal_cents = int(source.get("principal_cents", 0))
	accrued_interest_cents = int(source.get("accrued_interest_cents", 0))
	stars = source["stars"].duplicate(true)
	ships = source["ships"].duplicate(true)
	port_storage = source["port_storage"].duplicate(true)
	sale_policies = source["sale_policies"].duplicate(true)
	orders = source["orders"].duplicate(true)
	active_scan = source.get("active_scan", {}).duplicate(true)
	active_event = source.get("active_event", {}).duplicate(true)
	cash_history = source.get("cash_history", [cash_cents]).duplicate(true)
	next_ship_id = int(source.get("next_ship_id", 1))
	next_mission_id = int(source.get("next_mission_id", 1))
	season_ended = bool(source.get("season_ended", false))
	settlement = source.get("settlement", {}).duplicate(true)
	event_log = source.get("event_log", []).duplicate(true)
	stats = source["stats"].duplicate(true)
	if not stats.has("trips_by_mode"):
		stats["trips_by_mode"] = {"light": 0, "medium_once": 0, "medium_reuse": 0, "heavy_reuse": 0}
	elif not stats["trips_by_mode"].has("heavy_reuse"):
		stats["trips_by_mode"]["heavy_reuse"] = 0
	if not stats.has("unlocked_techs"):
		stats["unlocked_techs"] = []
	if not stats.has("salvage_revenue"):
		stats["salvage_revenue"] = 0
	if not stats.has("tycoon"):
		stats["tycoon"] = Tycoon.init_tycoon_meta()
	if not stats["expenses"].has("research"):
		stats["expenses"]["research"] = 0
	tutorial_stage = int(source.get("tutorial_stage", 0))
	tutorial_dismissed = bool(source.get("tutorial_dismissed", false))
	auto_pause = bool(source.get("auto_pause", true))
	sound_enabled = bool(source.get("sound_enabled", true))
	events_enabled = bool(source.get("events_enabled", scenario_id in ["S", "E", "X"]))
	endless_mode = is_endless
	if endless_mode:
		balance["season_ticks"] = 9999
	elif is_galaxy:
		balance["season_ticks"] = 90
	sector_seed = int(source.get("sector_seed", 0))
	challenge_id = str(source.get("challenge_id", ""))
	TechTree.apply_tech_effects(self)
	_inject_far_route()
	return {"ok": true}

static func _normalize_numbers(value):
	if value is Dictionary:
		var output := {}
		for key in value:
			output[key] = _normalize_numbers(value[key])
		return output
	if value is Array:
		var output := []
		for item in value:
			output.append(_normalize_numbers(item))
		return output
	if value is float and value == floor(value):
		return int(value)
	return value
