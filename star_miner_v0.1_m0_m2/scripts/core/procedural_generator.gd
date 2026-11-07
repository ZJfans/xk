class_name ProceduralGenerator
extends RefCounted

## 程序化星区与无尽模式生成器
## 支持生成跨越三大恒星系（太阳系内环星系 / 半人马α双星系 / 天鹅座深渊星云系）的随机星系（6-8 颗天体 + 深层岩芯富矿）

const STAR_NAME_PREFIXES: Array[String] = ["开普勒", "半人马", "天鹅座", "猎户", "织女", "海山二", "天狼", "毕宿", "角宿", "天枢", "仙女座", "波江"]
const STAR_NAME_SUFFIXES: Array[String] = ["α", "β", "γ", "δ", "ε", "原矿星", "结晶核", "碎石带", "荒原", "高重渊", "极寒核", "双星带"]

static func generate_sector(seed_val: int = 0, planet_count: int = 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var stars: Dictionary = {}

	# 确保至少有 1 颗近距金属星作为初期启动盘
	var starter_id: String = "proc_starter"
	var starter_res: int = rng.randi_range(36, 52)
	stars[starter_id] = {
		"id": starter_id,
		"name": "火星赤铁谷 · 近星",
		"ore": "metal",
		"route": "near",
		"environment": "normal",
		"zone": "太阳系内环星系",
		"reserve": starter_res,
		"initial_reserve": starter_res,
		"deep_reserve": 36,
		"deep_unlocked": false,
		"vein_prospected": false,
		"pipe_level": 1,
		"initial_stock": 0,
		"stock": 0,
		"public_min": starter_res,
		"public_max": starter_res,
		"revealed": true,
		"licensed": false,
		"has_miner": false,
		"has_silo": false,
		"next_production_tick": 0,
		"produced": 0,
		"shipped": 0,
		"stalled_ticks": 0,
		"exhausted_announced": false,
		"map_position": [0.18, 0.38]
	}

	for i in range(1, planet_count):
		var pid: String = "proc_star_%d" % i
		var is_crystal: bool = (i % 2 == 1) or rng.randf() > 0.45
		var ore_type: String = "crystal" if is_crystal else "metal"
		var route_type: String = "near"
		var zone_name: String = "太阳系内环星系"
		if i >= planet_count - 2:
			route_type = "far"
			zone_name = "天鹅座深渊星云系"
		elif i >= 2:
			route_type = "mid"
			zone_name = "半人马α双星系"
		var env_type: String = "high_g" if (route_type != "near" and rng.randf() < 0.42) else "normal"

		var prefix: String = STAR_NAME_PREFIXES[rng.randi() % STAR_NAME_PREFIXES.size()]
		var suffix: String = STAR_NAME_SUFFIXES[rng.randi() % STAR_NAME_SUFFIXES.size()]
		var star_name: String = "%s %s" % [prefix, suffix]

		var reserve: int = rng.randi_range(16, 44) if is_crystal else rng.randi_range(30, 60)
		var deep_res: int = rng.randi_range(24, 52)
		var is_revealed: bool = rng.randf() > 0.45
		var low_estimate: int = maxi(2, reserve - rng.randi_range(4, 12))
		var high_estimate: int = reserve + rng.randi_range(6, 18)

		var ring_y: float = 0.36 if route_type == "near" else (0.22 if route_type == "mid" else 0.08)
		var pos_x: float = 0.16 + (float(i) / float(maxi(1, planet_count - 1))) * 0.74 + rng.randf_range(-0.04, 0.04)
		var pos_y: float = clampf(ring_y + rng.randf_range(-0.05, 0.05), 0.05, 0.44)

		stars[pid] = {
			"id": pid,
			"name": star_name,
			"ore": ore_type,
			"route": route_type,
			"environment": env_type,
			"zone": zone_name,
			"reserve": reserve,
			"initial_reserve": reserve,
			"deep_reserve": deep_res,
			"deep_unlocked": false,
			"vein_prospected": false,
			"pipe_level": 1,
			"initial_stock": 0,
			"stock": 0,
			"public_min": reserve if is_revealed else low_estimate,
			"public_max": reserve if is_revealed else high_estimate,
			"revealed": is_revealed,
			"licensed": false,
			"has_miner": false,
			"has_silo": false,
			"next_production_tick": 0,
			"produced": 0,
			"shipped": 0,
			"stalled_ticks": 0,
			"exhausted_announced": false,
			"map_position": [pos_x, pos_y]
		}

	return stars

static func generate_periodic_orders(current_tick: int, existing_count: int, rng: RandomNumberGenerator) -> Array:
	var new_orders: Array = []
	var ore_choice: String = "crystal" if rng.randf() < 0.45 else "metal"
	var open_t: int = current_tick + rng.randi_range(4, 8)
	var close_t: int = open_t + rng.randi_range(6, 12)
	var qty: int = rng.randi_range(4, 8)
	var base_price: int = 26000 if ore_choice == "crystal" else 10000
	var premium_rate: float = rng.randf_range(1.25, 1.65)
	var order_price: int = int(float(base_price) * premium_rate)

	new_orders.append({
		"id": existing_count + 1,
		"ore": ore_choice,
		"announce_tick": current_tick,
		"open_tick": open_t,
		"close_tick": close_t,
		"quantity": qty,
		"sold": 0,
		"price": order_price,
		"closed": false
	})
	return new_orders
