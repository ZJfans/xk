class_name EventSystem
extends RefCounted

## 深空随机事件与动态市场波动系统
## 消除纯静态计算的枯燥感，营造波澜壮阔的太空淘金真实感

const EVENT_TYPES: Array[String] = ["solar_flare", "metal_boom", "crystal_boom", "rich_vein", "salvage"]

static func check_tick_events(state: GameState, rng: RandomNumberGenerator) -> Dictionary:
	# 清理已过期的动态事件
	if not state.active_event.is_empty():
		if state.current_tick >= int(state.active_event.get("end_tick", 0)):
			var old_title := str(state.active_event.get("title", "深空事件"))
			state.active_event = {}
			state.add_log("【事件平息】%s影响已结束，航道与市场恢复常态。" % old_title)

	if not state.events_enabled:
		return {}

	if state.current_tick < 6 or (not state.endless_mode and state.current_tick >= int(state.balance.get("season_ticks", 60)) - 6):
		return {}

	if not state.active_event.is_empty():
		return {}

	if rng.randf() > 0.11:
		return {}

	var chosen: String = EVENT_TYPES[rng.randi() % EVENT_TYPES.size()]

	match chosen:
		"solar_flare":
			state.active_event = {
				"type": "solar_flare",
				"title": "恒星辐射耀斑",
				"end_tick": state.current_tick + 6
			}
			state.add_log("【深空通告】恒星耀斑爆发！中距航线电磁受扰，新发中距航程临时 +1 半日（持续 3 日）。")
			return {
				"type": "solar_flare",
				"title": "恒星辐射耀斑",
				"text": "深空耀斑爆发：中距航程临时 +1 半日（持续 3 日）",
				"kind": "stall",
				"cues": ["stall"]
			}
		"metal_boom":
			state.active_event = {
				"type": "metal_boom",
				"title": "金属扩建潮",
				"end_tick": state.current_tick + 8
			}
			state.add_log("【市场热潮】轨道船厂扩建，金属常驻收购价限时暴涨 30%（$130/箱，持续 4 日）！")
			return {
				"type": "metal_boom",
				"title": "金属采购狂潮",
				"text": "轨道船厂紧急收储：金属常驻价暴涨至 $130/箱（持续 4 日）",
				"kind": "order",
				"cues": ["order"]
			}
		"crystal_boom":
			state.active_event = {
				"type": "crystal_boom",
				"title": "高能晶体热潮",
				"end_tick": state.current_tick + 8
			}
			state.add_log("【科技急购】高能物理实验急需原料，晶体常驻收购价限时上浮 35%（$351/箱，持续 4 日）！")
			return {
				"type": "crystal_boom",
				"title": "高能晶体急购",
				"text": "科研院所特急采购：晶体常驻价飙升至 $351/箱（持续 4 日）",
				"kind": "order",
				"cues": ["order"]
			}
		"rich_vein":
			var valid_stars: Array[String] = []
			for sid in state.stars:
				if bool(state.stars[sid].get("has_miner", false)) and int(state.stars[sid].get("reserve", 0)) > 0:
					valid_stars.append(str(sid))
			if not valid_stars.is_empty():
				var target_id: String = valid_stars[rng.randi() % valid_stars.size()]
				var target_star: Dictionary = state.stars[target_id]
				var bonus_ore := rng.randi_range(6, 12)
				target_star["reserve"] = int(target_star["reserve"]) + bonus_ore
				target_star["initial_reserve"] = int(target_star["initial_reserve"]) + bonus_ore
				state.add_log("【地质惊喜】%s钻探接触隐秘富矿脉，可采储量增加 %d 箱！" % [target_star["name"], bonus_ore])
				return {
					"type": "rich_vein",
					"title": "地质大发现",
					"text": "%s发现深层富矿脉，储量 +%d 箱！" % [target_star["name"], bonus_ore],
					"kind": "cash",
					"cues": ["cash"]
				}
		"salvage":
			var salvage_cash := rng.randi_range(3, 6) * 10000
			state.cash_cents += salvage_cash
			state.stats["salvage_revenue"] = int(state.stats.get("salvage_revenue", 0)) + salvage_cash
			state.add_log("【深空打捞】巡航探测器捕获废弃通信卫星核心，变现 %s！" % MissionRules.money(salvage_cash))
			return {
				"type": "salvage",
				"title": "太空废墟打捞",
				"text": "回收废弃卫星高纯度芯片，变现 +%s！" % MissionRules.money(salvage_cash),
				"kind": "cash",
				"cues": ["cash"]
			}
	return {}
