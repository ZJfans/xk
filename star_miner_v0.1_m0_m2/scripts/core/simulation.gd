class_name Simulation
extends RefCounted

const Rules = preload("res://scripts/core/mission_rules.gd")
const Events = preload("res://scripts/core/event_system.gd")
const ProcGen = preload("res://scripts/core/procedural_generator.gd")
const Tycoon = preload("res://scripts/core/galactic_tycoon.gd")

static func dispatch_mission(state: GameState, request: Dictionary) -> Dictionary:
	var quote: Dictionary = Rules.quote_mission(state, request)
	if not quote.get("ok", false):
		return {"ok": false, "error": "\n".join(quote.get("errors", [])), "quote": quote}
	var star: Dictionary = state.stars[quote["star_id"]]
	var owned_id: int = int(quote["owned_ship_id"])
	var ship: Dictionary = state.get_ship(owned_id) if owned_id > 0 else {}
	state.cash_cents -= int(quote["total_cents"])
	for key in quote["costs"]:
		state.stats["expenses"][key] = int(state.stats["expenses"][key]) + int(quote["costs"][key])
	star["licensed"] = true
	if ship.is_empty():
		ship = {"id": state.next_ship_id, "mode": quote["mode"], "trips": 0, "block_tier": 1}
		state.next_ship_id += 1
		state.ships.append(ship)
	ship["mission_id"] = state.next_mission_id
	state.next_mission_id += 1
	ship["star_id"] = str(quote["star_id"])
	ship["state"] = "outbound"
	ship["event_tick"] = state.current_tick + int(quote["travel_ticks"])
	ship["travel_ticks"] = int(quote["travel_ticks"])
	ship["planned_cargo"] = int(quote["cargo"])
	ship["cargo"] = 0
	ship["ret_fuel_budget"] = int(quote["ret_fuel"])
	ship["deliver_miner"] = bool(quote["miner"])
	ship["deliver_silo"] = bool(quote["silo"])
	ship["trips"] = int(ship["trips"]) + 1
	state.stats["fuel_bought"] = int(state.stats["fuel_bought"]) + int(quote["out_fuel"]) + int(quote["ret_fuel"])
	state.stats["fuel_burned"] = int(state.stats["fuel_burned"]) + int(quote["out_fuel"])
	state.add_log("%s #%d 飞往%s，计划运回 %d 箱，支付 %s。" % [mode_name(str(ship["mode"])), int(ship["id"]), star["name"], int(ship["planned_cargo"]), Rules.money(int(quote["total_cents"]))])
	if state.tutorial_stage == 0:
		state.tutorial_stage = 1
	elif state.tutorial_stage == 2:
		state.tutorial_stage = 3
	SteamService.check_gameplay_achievements(state)
	return {"ok": true, "ship_id": int(ship["id"]), "mission_id": int(ship["mission_id"]), "quote": quote}

static func toggle_auto_loop(state: GameState, ship_id: int) -> Dictionary:
	var ship: Dictionary = state.get_ship(ship_id)
	if ship.is_empty() or not Rules.is_reusable_mode(str(ship.get("mode", ""))):
		return {"ok": false, "error": "仅可回收复用箭支持自动往返巡航。"}
	var next_val: bool = not bool(ship.get("auto_loop", false))
	ship["auto_loop"] = next_val
	var star_name: String = str(state.stars.get(str(ship.get("star_id", "")), {}).get("name", "目标星"))
	state.add_log("%s #%d %s自动巡航（目标：%s）。" % [mode_name(str(ship["mode"])), ship_id, "已开启" if next_val else "已关闭", star_name])
	return {"ok": true, "auto_loop": next_val}

static func relaunch_ship_now(state: GameState, ship_id: int) -> Dictionary:
	var ship: Dictionary = state.get_ship(ship_id)
	if ship.is_empty() or str(ship.get("state", "")) != "idle":
		return {"ok": false, "error": "该复用箭当前不在待命状态。"}
	var target_id: String = str(ship.get("star_id", ""))
	if not state.stars.has(target_id):
		return {"ok": false, "error": "缺少上次航线目标。"}
	var desired_cargo: int = maxi(1, int(ship.get("planned_cargo", 6)))
	var base_req: Dictionary = {
		"mode": str(ship["mode"]),
		"owned_ship_id": ship_id,
		"star_id": target_id,
		"miner": false,
		"silo": false,
		"cargo": desired_cargo
	}
	var max_c: int = Rules.max_feasible_cargo(state, base_req)
	if max_c <= 0:
		return {"ok": false, "error": "本季剩余时间或载重不足以复飞该航线。"}
	base_req["cargo"] = mini(desired_cargo, max_c)
	return dispatch_mission(state, base_req)

static func return_now(state: GameState, ship_id: int) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已经结束。"}
	var ship: Dictionary = state.get_ship(ship_id)
	if ship.is_empty() or str(ship.get("state", "")) != "waiting":
		return {"ok": false, "error": "只有在星上等待的火箭可以提前返航。"}
	_depart_star(state, ship)
	return {"ok": true}

static func _depart_star(state: GameState, ship: Dictionary) -> void:
	var star: Dictionary = state.stars[ship["star_id"]]
	var planned: int = int(ship["planned_cargo"])
	var loaded: int = mini(planned, int(star["stock"]))
	var required: int = Rules.return_fuel(state, str(ship["mode"]), str(star["route"]), str(star["environment"]), loaded)
	var reserved: int = int(ship["ret_fuel_budget"])
	if required > reserved:
		push_error("返程燃料预算不足，拒绝返航。")
		return
	star["stock"] = int(star["stock"]) - loaded
	star["shipped"] = int(star["shipped"]) + loaded
	ship["cargo"] = loaded
	ship["ret_fuel_budget"] = 0
	ship["state"] = "inbound"
	ship["event_tick"] = state.current_tick + int(ship["travel_ticks"])
	state.stats["fuel_burned"] = int(state.stats["fuel_burned"]) + required
	state.stats["fuel_vented"] = int(state.stats["fuel_vented"]) + reserved - required
	if loaded < planned:
		state.stats["partial_returns"] = int(state.stats["partial_returns"]) + 1
	state.add_log("火箭 #%d 从%s返航：装载 %d/%d 箱，预计 Day %.1f 到港。" % [int(ship["id"]), star["name"], loaded, planned, float(int(ship["event_tick"])) / 2.0])

static func advance_tick(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "pause": true, "cues": []}
	state.current_tick += 1
	var pause_requested: bool = false
	var cues: Array[String] = []
	var notices: Array = []
	var cash_before: int = state.cash_cents
	var state_before: Dictionary = {}
	for ship in state.ships:
		state_before[int(ship["id"])] = str(ship.get("state", ""))
	state.accrued_interest_cents += int(state.principal_cents / int(state.balance["interest_divisor_per_tick"]))

	# 星链 V2 卫星星座每游戏日 (2 ticks) 被动通信宽带分红
	if state.stats.has("tycoon") and state.current_tick % 2 == 0:
		var sl_batches: int = int(state.stats["tycoon"].get("starlink_batches", 0))
		if sl_batches > 0:
			var sl_div: int = sl_batches * 2500 # 每批次每日 +$25
			state.cash_cents += sl_div
			state.stats["salvage_revenue"] = int(state.stats.get("salvage_revenue", 0)) + sl_div
			state.add_log("【📡 星链全球宽带分红】%d 颗在轨星链卫星结算今日订阅收益 +%s。" % [sl_batches * 12, Rules.money(sl_div)])

	if state.events_enabled:
		Tycoon.tick_market_fluctuation(state)
	if state.events_enabled or not state.active_event.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(state.sector_seed * 131 + state.current_tick * 997)
		var ev: Dictionary = Events.check_tick_events(state, rng)
		if not ev.is_empty():
			notices.append({"kind": str(ev.get("kind", "order")), "text": str(ev.get("text", ""))})
			for c in ev.get("cues", []):
				cues.append(str(c))
	if state.endless_mode and state.current_tick > 40 and state.current_tick % 14 == 0:
		var order_rng := RandomNumberGenerator.new()
		order_rng.seed = int(state.sector_seed * 313 + state.current_tick * 73)
		var generated: Array = ProcGen.generate_periodic_orders(state.current_tick, state.orders.size(), order_rng)
		for new_ord in generated:
			state.orders.append(new_ord)

	for star_id in state.stars:
		var star: Dictionary = state.stars[star_id]
		if not bool(star["has_miner"]) or int(star["reserve"]) <= 0:
			continue
		var capacity: int = star_capacity(state, star)
		if int(star["stock"]) >= capacity:
			star["stalled_ticks"] = int(star["stalled_ticks"]) + 1
		if state.current_tick >= int(star["next_production_tick"]):
			if int(star["stock"]) < capacity:
				star["stock"] = int(star["stock"]) + 1
				star["reserve"] = int(star["reserve"]) - 1
				star["produced"] = int(star["produced"]) + 1
				if int(star["stock"]) == capacity and int(star["reserve"]) > 0:
					state.add_log("%s的料仓已满，矿机暂时停工。" % star["name"])
					cues.append("stall")
					notices.append({"kind": "stall", "text": "%s仓满，矿机停工" % star["name"]})
				if int(star["reserve"]) == 0:
					if state.endless_mode:
						star["reserve"] = 24
						star["initial_reserve"] = int(star["initial_reserve"]) + 24
						state.add_log("【深层涌流】%s深部地质断层活跃，新矿脉补充 24 箱！" % star["name"])
					else:
						star["exhausted_announced"] = true
						state.add_log("%s地下矿藏已开采完。" % star["name"])
			star["next_production_tick"] = state.current_tick + int(state.balance["production_ticks"][star["ore"]])
	if not state.active_scan.is_empty() and state.current_tick >= int(state.active_scan["finish_tick"]):
		var scan_star: Dictionary = state.stars[state.active_scan["star_id"]]
		scan_star["revealed"] = true
		state.add_log("%s探测完成：地下余量 %d 箱。" % [scan_star["name"], int(scan_star["reserve"])])
		notices.append({"kind": "scan", "text": "探测完成：%s 地下 %d 箱" % [scan_star["name"], int(scan_star["reserve"])]})
		state.active_scan = {}
		pause_requested = true
		cues.append("scan")
		SteamService.unlock_achievement("ACH_PROSPECTING_RADAR")
	for ship in _ordered_ships(state, "id"):
		if state.current_tick < int(ship.get("event_tick", 0)):
			continue
		match str(ship["state"]):
			"outbound":
				var destination: Dictionary = state.stars[ship["star_id"]]
				var delivered_miner: bool = bool(ship["deliver_miner"])
				var delivered_silo: bool = bool(ship["deliver_silo"])
				if bool(ship["deliver_miner"]):
					destination["has_miner"] = true
					destination["next_production_tick"] = state.current_tick + int(state.balance["production_ticks"][destination["ore"]])
				if bool(ship["deliver_silo"]):
					destination["has_silo"] = true
				ship["deliver_miner"] = false
				ship["deliver_silo"] = false
				ship["state"] = "waiting"
				state.add_log("火箭 #%d 抵达%s%s。" % [int(ship["id"]), destination["name"], "，设施已部署" if delivered_miner or delivered_silo else ""])
				cues.append("arrive")
				if delivered_miner:
					notices.append({"kind": "arrive", "text": "火箭 #%d 抵达%s，矿机已部署" % [int(ship["id"]), destination["name"]]})
				else:
					notices.append({"kind": "arrive", "text": "火箭 #%d 抵达%s，准备取货" % [int(ship["id"]), destination["name"]]})
			"inbound":
				ship["state"] = "port"
				state.add_log("火箭 #%d 回到母港，等待卸货。" % int(ship["id"]))
				notices.append({"kind": "return", "text": "火箭 #%d 回到母港" % int(ship["id"])})
				pause_requested = true
				cues.append("return")
			"refurbishing":
				ship["state"] = "idle"
				state.add_log("复用箭 #%d 翻修完成，可再次派遣。" % int(ship["id"]))
				if bool(ship.get("auto_loop", false)) and not state.season_ended:
					var star_target: Dictionary = state.stars.get(str(ship.get("star_id", "")), {})
					if not star_target.is_empty() and (int(star_target.get("reserve", 0)) + int(star_target.get("stock", 0)) > 0):
						var auto_res: Dictionary = relaunch_ship_now(state, int(ship["id"]))
						if auto_res.get("ok", false):
							notices.append({"kind": "arrive", "text": "自动巡航：#%d 复飞前往%s" % [int(ship["id"]), str(star_target["name"])]})
							cues.append("launch")
	for ship in _ordered_ships(state, "mission_id"):
		if str(ship["state"]) != "waiting":
			continue
		var target: Dictionary = state.stars[ship["star_id"]]
		var has_enough: bool = int(target["stock"]) >= int(ship["planned_cargo"])
		var exhausted: bool = int(target["reserve"]) == 0 and (bool(target["has_miner"]) or bool(target["revealed"]))
		var last_departure: bool = not state.endless_mode and state.current_tick >= int(state.balance["season_ticks"]) - int(ship["travel_ticks"])
		if has_enough or exhausted or last_departure:
			_depart_star(state, ship)
	_resolve_port(state)
	for order in state.orders:
		if int(order["announce_tick"]) == state.current_tick:
			state.add_log("新采购单：%s %d 箱，每箱 %s，Day %.1f–%.1f。" % [ore_name(str(order["ore"])), int(order["quantity"]), Rules.money(int(order["price"])), float(int(order["open_tick"])) / 2.0, float(int(order["close_tick"])) / 2.0])
			notices.append({"kind": "order", "text": "新订单：%s %s/箱" % [ore_name(str(order["ore"])), Rules.money(int(order["price"]))]})
			pause_requested = true
			cues.append("order")
		if int(order["close_tick"]) == state.current_tick:
			order["closed"] = true
	if not state.endless_mode and state.current_tick >= int(state.balance["season_ticks"]):
		finish_season(state)
		pause_requested = true
		cues.append("finish")
	for ship in state.ships:
		var previous: String = str(state_before.get(int(ship["id"]), ""))
		if previous == "waiting" and str(ship["state"]) == "inbound" and int(ship["cargo"]) < int(ship["planned_cargo"]):
			notices.append({"kind": "partial", "text": "少装返航 %d/%d 箱" % [int(ship["cargo"]), int(ship["planned_cargo"])]})
			cues.append("partial")
		if previous == "inbound" and str(ship["state"]) == "port" and int(ship["cargo"]) > 0:
			notices.append({"kind": "portfull", "text": "母港仓满，船上还有 %d 箱没卸下" % int(ship["cargo"])})
			cues.append("portfull")
	var cash_gain: int = state.cash_cents - cash_before
	if cash_gain > 0:
		cues.append("cash")
		notices.append({"kind": "cash", "text": "到账 %s" % Rules.money(cash_gain)})
	var liquid_worth: int = state.cash_cents + int(state.port_storage["metal"]) * int(state.balance["prices"]["metal"]) + int(state.port_storage["crystal"]) * int(state.balance["prices"]["crystal"])
	state.cash_history.append(liquid_worth)
	var unlocked_now: Array = SteamService.check_gameplay_achievements(state)
	for ach_id in unlocked_now:
		var ach_info: Dictionary = SteamService.ACHIEVEMENTS.get(ach_id, {})
		notices.append({"kind": "order", "text": "解锁成就：%s" % str(ach_info.get("title_zh", ach_id))})
		cues.append("achievement")
	return {"ok": true, "pause": pause_requested, "cues": cues, "notices": notices}

static func _ordered_ships(state: GameState, key: String) -> Array:
	var sorted: Array = state.ships.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get(key, 0)) < int(b.get(key, 0)))
	return sorted

static func star_capacity(state: GameState, star: Dictionary) -> int:
	var pipe_bonus: int = (int(star.get("pipe_level", 1)) - 1) * 6
	return int(state.balance["planet_capacity"]) + (int(state.balance["modules"]["silo"]["extra_capacity"]) if bool(star["has_silo"]) else 0) + pipe_bonus

static func _resolve_port(state: GameState) -> void:
	_sell_available_stock(state)
	var complete: Array = []
	for ship in _ordered_ships(state, "id"):
		if str(ship["state"]) != "port":
			continue
		var star: Dictionary = state.stars[ship["star_id"]]
		var ore: String = str(star["ore"])
		while int(ship["cargo"]) > 0:
			var free: int = int(state.balance["port_capacity"]) - state.port_total()
			if free <= 0:
				break
			var unloaded: int = mini(free, int(ship["cargo"]))
			ship["cargo"] = int(ship["cargo"]) - unloaded
			state.port_storage[ore] = int(state.port_storage[ore]) + unloaded
			_sell_available_stock(state)
		if int(ship["cargo"]) == 0:
			state.stats["completed_trips"] = int(state.stats["completed_trips"]) + 1
			var mode: String = str(ship["mode"])
			state.stats["trips_by_mode"][mode] = int(state.stats["trips_by_mode"].get(mode, 0)) + 1
			if Rules.is_reusable_mode(mode):
				var b_tier: int = int(ship.get("block_tier", 1))
				if b_tier >= 3:
					var catch_bonus: int = 4000
					state.cash_cents += catch_bonus
					state.stats["salvage_revenue"] = int(state.stats.get("salvage_revenue", 0)) + catch_bonus
					state.add_log("【筷子塔精准捕获】Block 3 #%d 获回收燃料节余补贴 +$40！" % int(ship["id"]))
				if b_tier >= 2:
					ship["state"] = "idle"
					ship["event_tick"] = state.current_tick
					state.add_log("【筷子塔即夹即飞】Block %d #%d 零翻修直接待命！" % [b_tier, int(ship["id"])])
					if bool(ship.get("auto_loop", false)) and not state.season_ended:
						relaunch_ship_now(state, int(ship["id"]))
				else:
					ship["state"] = "refurbishing"
					ship["event_tick"] = state.current_tick + int(state.balance["recovery"]["refit_ticks"])
			else:
				complete.append(ship)
	for ship in complete:
		state.ships.erase(ship)

static func _sell_available_stock(state: GameState, only_ore: String = "") -> void:
	for ore in ["metal", "crystal"]:
		if not only_ore.is_empty() and ore != only_ore:
			continue
		var eligible: Array = []
		for order in state.orders:
			if str(order["ore"]) == ore and not bool(order["closed"]) and int(order["open_tick"]) <= state.current_tick and state.current_tick <= int(order["close_tick"]) and int(order["sold"]) < int(order["quantity"]):
				eligible.append(order)
		eligible.sort_custom(func(a, b):
			if int(a["price"]) != int(b["price"]):
				return int(a["price"]) > int(b["price"])
			if int(a["close_tick"]) != int(b["close_tick"]):
				return int(a["close_tick"]) < int(b["close_tick"])
			return int(a["id"]) < int(b["id"])
		)
		for order in eligible:
			var quantity: int = mini(int(state.port_storage[ore]), int(order["quantity"]) - int(order["sold"]))
			if quantity <= 0:
				break
			order["sold"] = int(order["sold"]) + quantity
			state.stats["order_sold"] = int(state.stats["order_sold"]) + quantity
			_sell(state, ore, quantity, int(order["price"]), "订单")
		if str(state.sale_policies[ore]) == "immediate":
			var quantity: int = int(state.port_storage[ore])
			if quantity > 0:
				_sell(state, ore, quantity, Rules.current_ore_price(state, ore), "常驻商")

static func _sell(state: GameState, ore: String, amount: int, price: int, buyer: String) -> void:
	var revenue: int = amount * price
	state.port_storage[ore] = int(state.port_storage[ore]) - amount
	state.cash_cents += revenue
	state.stats["revenue"] = int(state.stats["revenue"]) + revenue
	state.stats["sold"][ore] = int(state.stats["sold"][ore]) + amount
	state.add_log("%s卖出 %d 箱%s，收入 %s。" % [buyer, amount, ore_name(ore), Rules.money(revenue)])
	if state.tutorial_stage == 1:
		state.tutorial_stage = 2
	elif state.tutorial_stage == 3:
		state.tutorial_stage = 4

static func set_sale_policy(state: GameState, ore: String, policy: String) -> Dictionary:
	if state.season_ended or not ore in ["metal", "crystal"] or not policy in ["immediate", "hold"]:
		return {"ok": false, "error": "销售策略不可用。"}
	state.sale_policies[ore] = policy
	state.add_log("%s销售：%s。" % [ore_name(ore), "立即变现" if policy == "immediate" else "留货等单"])
	_resolve_port(state)
	return {"ok": true}

static func sell_port_stock(state: GameState, ore: String) -> Dictionary:
	if state.season_ended or not ore in ["metal", "crystal"]:
		return {"ok": false, "error": "当前不能出售矿石。"}
	var quantity: int = int(state.port_storage[ore])
	if quantity <= 0:
		return {"ok": false, "error": "母港没有这种矿石，星球上的矿石需要先运回。"}
	var before_cash: int = state.cash_cents
	_sell_available_stock(state, ore)
	var remaining: int = int(state.port_storage[ore])
	if remaining > 0:
		_sell(state, ore, remaining, Rules.current_ore_price(state, ore), "常驻商")
	var proceeds: int = state.cash_cents - before_cash
	_resolve_port(state)
	return {"ok": true, "quantity": quantity, "proceeds": proceeds}

static func start_scan(state: GameState, star_id: String) -> Dictionary:
	if state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "目标不可探测。"}
	var star: Dictionary = state.stars[star_id]
	if bool(star["revealed"]) or bool(star["exhausted_announced"]):
		return {"ok": false, "error": "该星的地下余量已知。"}
	if not state.active_scan.is_empty():
		return {"ok": false, "error": "已有探测任务正在进行。"}
	var fee: int = int(state.balance["scan_price"])
	if state.cash_cents < fee:
		return {"ok": false, "error": "探测需要 %s。" % Rules.money(fee)}
	var end_tick: int = state.current_tick + int(state.balance["scan_ticks"])
	if not state.endless_mode and end_tick >= int(state.balance["season_ticks"]):
		return {"ok": false, "error": "本季剩余时间不足以利用探测结果。"}
	state.cash_cents -= fee
	state.stats["expenses"]["scan"] = int(state.stats["expenses"]["scan"]) + fee
	state.active_scan = {"star_id": star_id, "finish_tick": end_tick}
	state.add_log("对%s启动远程探测，支付 %s。" % [star["name"], Rules.money(fee)])
	return {"ok": true}

static func borrow(state: GameState, amount: int) -> Dictionary:
	var step: int = int(state.balance["loan_step"])
	if state.season_ended or amount <= 0 or amount % step != 0 or state.principal_cents + amount > int(state.balance["loan_limit"]):
		return {"ok": false, "error": "借款超过额度或金额无效。"}
	state.cash_cents += amount
	state.principal_cents += amount
	state.add_log("借入 %s；借款不计收入。" % Rules.money(amount))
	return {"ok": true}

static func repay(state: GameState, amount: int) -> Dictionary:
	var step: int = int(state.balance["loan_step"])
	if state.season_ended or amount <= 0 or amount % step != 0 or amount > state.principal_cents:
		return {"ok": false, "error": "偿还本金金额无效。"}
	var due: int = amount + state.accrued_interest_cents
	if state.cash_cents < due:
		return {"ok": false, "error": "本次需支付本金与全部应付利息，共 %s。" % Rules.money(due)}
	state.cash_cents -= due
	state.principal_cents -= amount
	state.stats["expenses"]["interest"] = int(state.stats["expenses"]["interest"]) + state.accrued_interest_cents
	state.add_log("偿还本金 %s、利息 %s。" % [Rules.money(amount), Rules.money(state.accrued_interest_cents)])
	state.accrued_interest_cents = 0
	return {"ok": true}

static func sell_ship(state: GameState, ship_id: int) -> Dictionary:
	var ship: Dictionary = state.get_ship(ship_id)
	if state.season_ended or ship.is_empty() or not Rules.is_reusable_mode(str(ship.get("mode", ""))) or not str(ship.get("state", "")) in ["idle", "refurbishing"]:
		return {"ok": false, "error": "只能变卖已卸空的母港复用箭。"}
	var value: int = ship_resale_value(state, str(ship.get("mode", "medium_reuse")))
	state.ships.erase(ship)
	state.cash_cents += value
	state.stats["ship_sale_revenue"] = int(state.stats["ship_sale_revenue"]) + value
	state.add_log("变卖%s #%d，收入 %s。" % [mode_name(str(ship["mode"])), ship_id, Rules.money(value)])
	return {"ok": true}

static func ship_resale_value(state: GameState, mode: String = "medium_reuse") -> int:
	var hull_id: String = Rules.hull_id_for_mode(mode)
	if not state.balance["hulls"].has(hull_id):
		hull_id = "medium"
	var total: int = int(state.balance["hulls"][hull_id]["price"]) + int(state.balance["recovery"]["price"])
	return int(total * int(state.balance["resale_numerator"]) / int(state.balance["resale_denominator"]))

static func resale_value(state: GameState) -> int:
	return ship_resale_value(state, "medium_reuse")

static func preview_settlement(state: GameState) -> Dictionary:
	if state.season_ended and not state.settlement.is_empty():
		return state.settlement.duplicate(true)
	var port_ore: Dictionary = state.port_storage.duplicate(true)
	var ships_at_port: int = 0
	var resale: int = 0
	for ship in state.ships:
		if str(ship["state"]) == "port":
			var ore: String = str(state.stars[ship["star_id"]]["ore"])
			port_ore[ore] = int(port_ore[ore]) + int(ship["cargo"])
		if Rules.is_reusable_mode(str(ship["mode"])) and str(ship["state"]) in ["idle", "refurbishing", "port"]:
			ships_at_port += 1
			resale += ship_resale_value(state, str(ship["mode"]))
	var ore_value: int = int(port_ore["metal"]) * int(state.balance["prices"]["metal"]) + int(port_ore["crystal"]) * int(state.balance["prices"]["crystal"])
	var net: int = state.cash_cents + ore_value + resale - state.principal_cents - state.accrued_interest_cents - int(state.balance["starting_cash"])
	var remaining: Dictionary = {}
	for star_id in state.stars:
		var star: Dictionary = state.stars[star_id]
		remaining[star_id] = {"name": star["name"], "ore": star["ore"], "reserve": star["reserve"], "stock": star["stock"], "stalled_ticks": star["stalled_ticks"]}
	var visible_orders: Array = []
	for order in state.orders:
		if int(order["announce_tick"]) <= state.current_tick:
			visible_orders.append({"ore": order["ore"], "sold": order["sold"], "quantity": order["quantity"],
				"open_tick": order["open_tick"], "close_tick": order["close_tick"], "price": order["price"]})
	return {"tick": state.current_tick, "cash": state.cash_cents, "port_ore": port_ore,
		"ore_value": ore_value, "resale": resale, "resale_ships": ships_at_port,
		"principal": state.principal_cents, "interest": state.accrued_interest_cents,
		"starting_cash": int(state.balance["starting_cash"]), "net": net,
		"stats": state.stats.duplicate(true), "remaining": remaining, "orders": visible_orders}

static func finish_season(state: GameState) -> Dictionary:
	if state.season_ended:
		return state.settlement.duplicate(true)
	state.settlement = preview_settlement(state)
	state.season_ended = true
	state.add_log("本季结束，净收益 %s。" % Rules.money(int(state.settlement["net"])))
	SteamService.check_gameplay_achievements(state)
	return state.settlement.duplicate(true)

static func ore_name(ore: String) -> String:
	return "金属" if ore == "metal" else "晶体"

static func mode_name(mode: String) -> String:
	match mode:
		"light": return "轻型箭"
		"medium_once": return "中型一次性箭"
		"heavy_reuse": return "重型复用星舰"
		_: return "中型复用箭"
