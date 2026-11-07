class_name MissionRules
extends RefCounted

const MODES: Array[String] = ["light", "medium_once", "medium_reuse", "heavy_reuse"]

static func ceil_ratio(amount: int, numerator: int, denominator: int) -> int:
	return int((amount * numerator + denominator - 1) / denominator)

static func hull_id_for_mode(mode: String) -> String:
	if mode == "light":
		return "light"
	if mode == "heavy_reuse":
		return "heavy"
	return "medium"

static func is_reusable_mode(mode: String) -> bool:
	return mode in ["medium_reuse", "heavy_reuse"]

static func return_fuel(state: GameState, mode: String, route: String, environment: String, cargo: int) -> int:
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	if TechTree.is_unlocked(unlocked, "isru_refinery"):
		return 1
	var reusable := is_reusable_mode(mode)
	var hull_id := hull_id_for_mode(mode)
	var b := state.balance
	if not b["hulls"].has(hull_id):
		hull_id = "medium"
	var recovery: Dictionary = b["recovery"]
	var capsule: Dictionary = b["capsule"]
	var hull_dry := int(b["hulls"][hull_id]["dry_mass"])
	if TechTree.is_unlocked(unlocked, "titanium_structure"):
		hull_dry = maxi(1, hull_dry - 1)
	var dry := hull_dry + int(recovery["mass"]) if reusable else int(capsule["mass"])
	var ratio: Dictionary = b["routes"].get(route, b["routes"]["mid"])
	var landing := int(recovery["landing_fuel"]) if reusable else 0
	var gravity := int(b["environments"][environment]["extra_return_fuel"])
	var raw_fuel := maxi(1, ceil_ratio(dry + cargo, int(ratio["numerator"]), int(ratio["denominator"])) + landing + gravity)
	if TechTree.is_unlocked(unlocked, "aerospike_engine"):
		raw_fuel = maxi(1, int(floor(float(raw_fuel) * 0.85)))
	return raw_fuel

static func quote_mission(state: GameState, request: Dictionary, check_cash: bool = true) -> Dictionary:
	var errors: Array[String] = []
	var mode := str(request.get("mode", "light"))
	var star_id := str(request.get("star_id", ""))
	var cargo := int(request.get("cargo", 0))
	var owned_id := int(request.get("owned_ship_id", 0))
	var wants_miner := bool(request.get("miner", false))
	var wants_silo := bool(request.get("silo", false))
	if not mode in MODES:
		return {"ok": false, "errors": ["无效的火箭类型。"]}
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	if mode == "heavy_reuse" and not TechTree.is_unlocked(unlocked, "starship_heavy"):
		return {"ok": false, "errors": ["需要先研发「星舰级重型复用运载系统」科技。"]}
	if not state.stars.has(star_id):
		return {"ok": false, "errors": ["请选择目标星球。"]}
	var star: Dictionary = state.stars[star_id]
	var b := state.balance
	var reusable := is_reusable_mode(mode)
	var hull_id := hull_id_for_mode(mode)
	var hull: Dictionary = b["hulls"][hull_id]
	var equipment: Dictionary = b["recovery"] if reusable else b["capsule"]
	var route_key := str(star["route"])
	var route: Dictionary = b["routes"].get(route_key, b["routes"]["mid"])
	var environment: Dictionary = b["environments"][star["environment"]]
	var owned_ship: Dictionary = state.get_ship(owned_id) if owned_id > 0 else {}
	if state.season_ended:
		errors.append("本季已经结束。")
	if cargo < 0:
		errors.append("返程货物不能为负数。")
	if owned_id > 0 and (not reusable or owned_ship.is_empty() or str(owned_ship.get("mode", "")) != mode or str(owned_ship.get("state", "")) != "idle"):
		errors.append("所选复用箭不可用。")
	if owned_id == 0 and state.ships.size() >= int(b["fleet_limit"]):
		errors.append("船队已满，请等待或变卖母港复用箭。")
	if wants_miner and bool(star["has_miner"]):
		errors.append("该星已有矿机。")
	if wants_silo and bool(star["has_silo"]):
		errors.append("该星已有扩展料仓。")
	if wants_silo and not bool(star["has_miner"]) and not wants_miner:
		errors.append("扩展料仓需要已有矿机，或与矿机一起运输。")
	for ship in state.ships:
		if str(ship.get("state", "")) == "outbound" and str(ship.get("star_id", "")) == star_id:
			if wants_miner and bool(ship.get("deliver_miner", false)):
				errors.append("矿机已在运输中，不能重复部署。")
			if wants_silo and bool(ship.get("deliver_silo", false)):
				errors.append("扩展料仓已在运输中。")
	var module_mass := 0
	var module_slots := 0
	var miner_cost := 0
	var silo_cost := 0
	if wants_miner:
		module_mass += int(b["modules"]["miner"]["mass"])
		module_slots += int(b["modules"]["miner"]["slots"])
		miner_cost = int(b["modules"]["miner"]["price"])
	if wants_silo:
		module_mass += int(b["modules"]["silo"]["mass"])
		module_slots += int(b["modules"]["silo"]["slots"])
		silo_cost = int(b["modules"]["silo"]["price"])
	var hull_dry := int(hull["dry_mass"])
	if TechTree.is_unlocked(unlocked, "titanium_structure"):
		hull_dry = maxi(1, hull_dry - 1)
	var out_dry := hull_dry + int(equipment["mass"])
	var ret_dry := out_dry if reusable else int(equipment["mass"])
	var out_slots := module_slots + int(equipment["slots"])
	var ret_slots := cargo + (int(equipment["slots"]) if reusable else 0)
	var f_ret := return_fuel(state, mode, route_key, str(star["environment"]), maxi(0, cargo))
	var f_out := maxi(1, ceil_ratio(out_dry + module_mass + f_ret, int(route["numerator"]), int(route["denominator"])))
	var pipe_lvl := int(star.get("pipe_level", 1))
	if pipe_lvl > 1:
		f_out = maxi(1, f_out - (pipe_lvl - 1))
	if TechTree.is_unlocked(unlocked, "aerospike_engine"):
		f_out = maxi(1, int(floor(float(f_out) * 0.85)))
	var out_mass := out_dry + module_mass + f_ret + f_out
	var ret_mass := ret_dry + cargo + f_ret
	var return_limit := int(hull["mass_cap"]) - int(environment["return_cap_penalty"])
	var travel_ticks := int(hull["travel_ticks"].get(route_key, 4))
	if str(state.active_event.get("type", "")) == "solar_flare" and route_key != "near":
		travel_ticks += 1
	if out_slots > int(hull["slots"]):
		errors.append("去程货舱超出 %d 格。" % (out_slots - int(hull["slots"])))
	if ret_slots > int(hull["slots"]):
		errors.append("返程货舱超出 %d 格。" % (ret_slots - int(hull["slots"])))
	if out_mass > int(hull["mass_cap"]):
		errors.append("母港起飞超重 %d 单位。" % (out_mass - int(hull["mass_cap"])))
	if ret_mass > return_limit:
		errors.append("星面返航超重 %d 单位，请减少货物。" % (ret_mass - return_limit))
	if not state.endless_mode and state.current_tick + 2 * travel_ticks > int(b["season_ticks"]):
		errors.append("本季剩余时间不足以完成往返。")
	var costs := {
		"hull": 0 if owned_id > 0 else int(hull["price"]),
		"return_equipment": 0 if owned_id > 0 else int(equipment["price"]),
		"miner": miner_cost, "silo": silo_cost,
		"license": 0 if bool(star["licensed"]) else int(b["license_fee"]),
		"fuel": (f_out + f_ret) * int(b["fuel_unit_price"]),
		"launch": int(b["launch_fee"]),
		"refit": int(b["recovery"]["refit_fee"]) if reusable else 0
	}
	var total := 0
	for key in costs:
		total += int(costs[key])
	if check_cash and total > state.cash_cents:
		errors.append("资金不足，还差 %s。" % money(total - state.cash_cents))
	return {
		"ok": errors.is_empty(), "errors": errors, "mode": mode, "star_id": star_id,
		"owned_ship_id": owned_id, "cargo": cargo, "miner": wants_miner, "silo": wants_silo,
		"out_fuel": f_out, "ret_fuel": f_ret, "out_mass": out_mass, "out_cap": int(hull["mass_cap"]),
		"return_mass": ret_mass, "return_cap": return_limit,
		"out_slots": out_slots, "return_slots": ret_slots, "slot_cap": int(hull["slots"]),
		"travel_ticks": travel_ticks, "costs": costs, "total_cents": total
	}

static func max_feasible_cargo(state: GameState, request: Dictionary) -> int:
	var mode := str(request.get("mode", "light"))
	if not mode in MODES:
		return -1
	var hull_id := hull_id_for_mode(mode)
	if not state.balance["hulls"].has(hull_id):
		return -1
	var limit := int(state.balance["hulls"][hull_id]["slots"])
	for cargo in range(limit, -1, -1):
		var candidate := request.duplicate(true)
		candidate["cargo"] = cargo
		if quote_mission(state, candidate, false).get("ok", false):
			return cargo
	return -1

static func current_ore_price(state: GameState, ore: String) -> int:
	var base := int(state.balance["prices"][ore])
	if state.events_enabled and state.stats.has("tycoon"):
		var best_info := GalacticTycoon.best_buyer_price(state, ore)
		base = int(best_info["price"])
	var ev_type := str(state.active_event.get("type", ""))
	if ev_type == "metal_boom" and ore == "metal":
		return int(base * 13 / 10)
	if ev_type == "crystal_boom" and ore == "crystal":
		return int(base * 27 / 20)
	return base

static func estimate_mission(state: GameState, quote: Dictionary) -> Dictionary:
	if not quote.has("star_id") or not state.stars.has(quote["star_id"]):
		return {}
	var star: Dictionary = state.stars[quote["star_id"]]
	var known := state.public_reserve(star)
	var low := int(known["min"])
	var high := int(known["max"])
	if not bool(known["exact"]) and bool(star["has_miner"]):
		low = maxi(1, low)
	var lower_case := _estimate_with_reserve(state, quote, low)
	var upper_case := _estimate_with_reserve(state, quote, high)
	var competing := false
	for ship in state.ships:
		if str(ship.get("star_id", "")) == str(quote["star_id"]) and str(ship.get("state", "")) in ["outbound", "waiting"]:
			competing = true
	var price := current_ore_price(state, str(star["ore"]))
	return {"min_tick": mini(int(lower_case["arrival_tick"]), int(upper_case["arrival_tick"])),
		"max_tick": maxi(int(lower_case["arrival_tick"]), int(upper_case["arrival_tick"])),
		"min_cargo": mini(int(lower_case["cargo"]), int(upper_case["cargo"])),
		"max_cargo": maxi(int(lower_case["cargo"]), int(upper_case["cargo"])),
		"min_revenue": mini(int(lower_case["cargo"]), int(upper_case["cargo"])) * price,
		"max_revenue": maxi(int(lower_case["cargo"]), int(upper_case["cargo"])) * price,
		"competition": competing, "exact": bool(known["exact"])}

static func _estimate_with_reserve(state: GameState, quote: Dictionary, possible_reserve: int) -> Dictionary:
	var star: Dictionary = state.stars[quote["star_id"]]
	var stock := int(star["stock"])
	var remaining := possible_reserve
	var miner := bool(star["has_miner"])
	var silo := bool(star["has_silo"])
	var pipe_bonus := (int(star.get("pipe_level", 1)) - 1) * 6
	var next_production := int(star["next_production_tick"])
	var interval := int(state.balance["production_ticks"][star["ore"]])
	var destination_tick := state.current_tick + int(quote["travel_ticks"])
	var horizon := (state.current_tick + 60) if state.endless_mode else int(state.balance["season_ticks"])
	var last_departure := horizon - int(quote["travel_ticks"])
	var planned := int(quote["cargo"])
	var incoming_miner := -1
	var incoming_silo := -1
	for ship in state.ships:
		if str(ship.get("star_id", "")) == str(quote["star_id"]) and str(ship.get("state", "")) == "outbound":
			if bool(ship.get("deliver_miner", false)):
				incoming_miner = int(ship["event_tick"])
			if bool(ship.get("deliver_silo", false)):
				incoming_silo = int(ship["event_tick"])
	for tick in range(state.current_tick + 1, last_departure + 1):
		if miner and remaining > 0 and tick >= next_production:
			var cap := int(state.balance["planet_capacity"]) + (int(state.balance["modules"]["silo"]["extra_capacity"]) if silo else 0) + pipe_bonus
			if stock < cap:
				remaining -= 1
				stock += 1
			next_production = tick + interval
		if tick == incoming_miner:
			miner = true
			next_production = tick + interval
		if tick == incoming_silo:
			silo = true
		if tick == destination_tick:
			if bool(quote["miner"]):
				miner = true
				next_production = tick + interval
			if bool(quote["silo"]):
				silo = true
		if tick >= destination_tick:
			var exhausted := remaining == 0 and (miner or bool(star["revealed"]) or bool(star["exhausted_announced"]))
			if stock >= planned or exhausted or tick == last_departure:
				return {"cargo": mini(stock, planned), "arrival_tick": tick + int(quote["travel_ticks"])}
	return {"cargo": 0, "arrival_tick": horizon}

static func money(cents: int) -> String:
	var amount: int = absi(cents)
	var whole := int(amount / 100)
	var fraction: int = amount % 100
	var sign := "-" if cents < 0 else ""
	return "%s$%d" % [sign, whole] if fraction == 0 else "%s$%d.%02d" % [sign, whole, fraction]
