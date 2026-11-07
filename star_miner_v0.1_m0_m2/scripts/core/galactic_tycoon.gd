class_name GalacticTycoon
extends RefCounted

## 《星矿大亨》v4.0 Steam $50 大师典藏版 · 核心玩法与经济博弈引擎：
## 1. 庞大三大恒星系地图（地月与近地轨道圈 / 火星与主小行星带 / 木星特洛伊外环带）
## 2. 探星与探矿 + 【地下三靶点定向激光微操钻探 (Directional Vein Pocket Drilling)】
## 3. SpaceX 致敬黑科技：
##    - 【🛰 近地轨道星舰在轨加注站 (LEO Orbital Propellant Depot Lv.1~Lv.3)】
##    - 【📡 全球星链卫星互联网组网 (Starlink V2 Mega-Constellation: 12 / 24 / 36 颗卫星列车 + 每日被动宽带现金流分红 + 自动揭盲星球)】
##    - 【🔧 星舰巨湾模块化改装工坊 (Starship Block 1 -> Block 2 筷子塔即夹即飞免翻修 -> Block 3 猛禽真空母舰 +$40 回收补贴)】
##    - 【🪐 火星阿瑞斯星城殖民大工程 (Occupy Mars 5-Stage Tera-Project)】
## 4. 地球基地工业深加工：【🔥 电弧精炼与氦-3同位素提纯厂 (Ore Smelter +35% 溢价)】
## 5. 对标《Offworld Trading Company》&《Turmoil》：【三大 AI 财团实时船队竞争】+【远期高价期货合约】+【100% 敌意收购控股】

const AI_RIVALS: Array[Dictionary] = [
	{"id": "rex", "name": "泰坦资源财团", "style": "竞拍积极 · 偏好高估值矿区", "color": "f08c82"},
	{"id": "victoria", "name": "星际航运财团", "style": "投资运输效率 · 重视规模经营", "color": "49d6e4"},
	{"id": "otto", "name": "量子投机财团", "style": "囤积矿石 · 擅长利用价格波动", "color": "f2b55c"}
]

const DISCOVERABLE_STARS: Array[Dictionary] = [
	{"id": "disc_psyche", "name": "灵神星·纯金铁核", "ore": "metal", "route": "near", "env": "normal", "reserve": 34, "deep": 36, "pos": [0.22, 0.28], "zone": "地月与近地轨道圈"},
	{"id": "disc_europa", "name": "木卫二·冰下晶海", "ore": "crystal", "route": "mid", "env": "normal", "reserve": 20, "deep": 32, "pos": [0.54, 0.22], "zone": "火星与主小行星带"},
	{"id": "disc_kepler", "name": "开普勒·超重钻星", "ore": "crystal", "route": "far", "env": "high_g", "reserve": 28, "deep": 48, "pos": [0.78, 0.14], "zone": "木星特洛伊外环带"},
	{"id": "disc_vesta", "name": "灶神星·富钛岩芯", "ore": "metal", "route": "mid", "env": "normal", "reserve": 38, "deep": 42, "pos": [0.38, 0.16], "zone": "火星与主小行星带"}
]

const MARS_STAGES: Array[Dictionary] = [
	{"stage": 1, "name": "第一阶段：星舰无人货运先遣着陆", "cost_cents": 80000, "bonus_desc": "火星全息灯塔点亮，全港矿石收购牌价永久 +$10/箱"},
	{"stage": 2, "name": "第二阶段：萨巴蒂尔大气制氧与甲烷站", "cost_cents": 140000, "bonus_desc": "解锁火星甲烷补给回馈，全港矿石收购牌价累计 +$22/箱"},
	{"stage": 3, "name": "第三阶段：阿瑞斯生态穹顶与水冰矿井", "cost_cents": 220000, "bonus_desc": "星际移民潮启动，母港立体仓额外扩容 +8 箱，矿价累计 +$35/箱"},
	{"stage": 4, "name": "第四阶段：火星赤道星舰太空港建成", "cost_cents": 320000, "bonus_desc": "地球-火星双母港联动，全部矿石收购牌价累计 +$50/箱"},
	{"stage": 5, "name": "第五阶段：百万人类自持火星星城 (OCCUPY MARS)", "cost_cents": 480000, "bonus_desc": "达成人类跨行星物种终极成就！全矿产溢价 +$75/箱！"}
]


static func generate_vast_galaxy(seed_val: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var stars: Dictionary = {}
	var templates: Array[Dictionary] = [
		{
			"id": "inner_ferrum", "name": "火星赤铁矿谷", "ore": "metal", "route": "near", "env": "normal",
			"reserve": 36, "deep_reserve": 40, "stock": 2, "revealed": true, "pos": [0.15, 0.36], "zone": "地月与近地轨道圈"
		},
		{
			"id": "inner_reef", "name": "近轨碎石星簇", "ore": "metal", "route": "near", "env": "normal",
			"reserve": 28, "deep_reserve": 32, "stock": 0, "revealed": true, "pos": [0.32, 0.40], "zone": "地月与近地轨道圈"
		},
		{
			"id": "mid_ceres", "name": "谷神星晶簇带", "ore": "crystal", "route": "near", "env": "normal",
			"reserve": 12, "deep_reserve": 24, "stock": 0, "revealed": false, "pos": [0.23, 0.20], "zone": "地月与近地轨道圈"
		},
		{
			"id": "mid_nebula", "name": "灶神星冰封彗核", "ore": "crystal", "route": "mid", "env": "normal",
			"reserve": 18, "deep_reserve": 30, "stock": 4, "revealed": false, "pos": [0.46, 0.25], "zone": "火星与主小行星带"
		},
		{
			"id": "mid_magnetar", "name": "潘多拉高重铁星", "ore": "metal", "route": "mid", "env": "high_g",
			"reserve": 44, "deep_reserve": 50, "stock": 8, "revealed": true, "pos": [0.62, 0.38], "zone": "火星与主小行星带"
		},
		{
			"id": "mid_prism", "name": "灵神星富金晶核", "ore": "crystal", "route": "mid", "env": "normal",
			"reserve": 16, "deep_reserve": 28, "stock": 0, "revealed": true, "pos": [0.66, 0.20], "zone": "火星与主小行星带"
		},
		{
			"id": "far_titan", "name": "泰坦极寒深空核", "ore": "crystal", "route": "far", "env": "normal",
			"reserve": 26, "deep_reserve": 48, "stock": 6, "revealed": false, "pos": [0.48, 0.08], "zone": "木星特洛伊外环带"
		},
		{
			"id": "far_abyss", "name": "木卫二深海晶星", "ore": "crystal", "route": "far", "env": "high_g",
			"reserve": 32, "deep_reserve": 60, "stock": 10, "revealed": true, "pos": [0.86, 0.12], "zone": "木星特洛伊外环带"
		}
	]

	for tpl in templates:
		var tid: String = str(tpl["id"])
		var base_res: int = int(tpl["reserve"]) + rng.randi_range(-4, 6)
		var deep_res: int = int(tpl["deep_reserve"]) + rng.randi_range(-4, 8)
		var rev: bool = bool(tpl["revealed"])
		var p_min: int = base_res if rev else maxi(4, base_res - 8)
		var p_max: int = base_res if rev else (base_res + 14)
		var pos_arr: Array = tpl["pos"]
		stars[tid] = {
			"id": tid,
			"name": str(tpl["name"]),
			"ore": str(tpl["ore"]),
			"route": str(tpl["route"]),
			"environment": str(tpl["env"]),
			"zone": str(tpl["zone"]),
			"reserve": base_res,
			"initial_reserve": base_res,
			"deep_reserve": deep_res,
			"deep_unlocked": false,
			"vein_prospected": false,
			"active_pocket": 1,
			"pockets_drilled": [],
			"pipe_level": 1,
			"initial_stock": int(tpl["stock"]),
			"stock": int(tpl["stock"]),
			"public_min": p_min,
			"public_max": p_max,
			"revealed": rev,
			"licensed": false,
			"has_miner": false,
			"has_silo": false,
			"next_production_tick": 0,
			"produced": 0,
			"shipped": 0,
			"stalled_ticks": 0,
			"exhausted_announced": false,
			"map_position": [float(pos_arr[0]), float(pos_arr[1])]
		}
	return stars


static func init_tycoon_meta() -> Dictionary:
	return {
		"left_buyer": {
			"name": "西盟航天重工 (采购商A)",
			"metal_price": 10500,
			"crystal_price": 25000,
			"trend": 1
		},
		"right_buyer": {
			"name": "东联星际矿业 (采购商B)",
			"metal_price": 9500,
			"crystal_price": 27500,
			"trend": -1
		},
		"active_buyer": "best",
		"saloon_bribe_until": 0,
		"futures_until": 0,
		"orbital_depot_level": 0,
		"starlink_batches": 0,
		"mars_stage": 0,
		"rival_activity": "雷克斯重工正在筹备近轨勘探船队",
		"shares": {
			"player": 5,
			"rex": 5,
			"victoria": 5,
			"otto": 5,
			"unowned": 80
		},
		"share_price_cents": 60000,
		"season_number": 1
	}


static func tick_market_fluctuation(state: GameState) -> void:
	if not state.stats.has("tycoon"):
		return
	var tycoon: Dictionary = state.stats["tycoon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int((state.sector_seed + 17) * 313 + state.current_tick * 101)

	var bribed: bool = state.current_tick < int(tycoon.get("saloon_bribe_until", 0))
	var futures_locked: bool = state.current_tick < int(tycoon.get("futures_until", 0))
	var mars_bonus: int = _mars_price_bonus_cents(int(tycoon.get("mars_stage", 0)))

	for side_key in ["left_buyer", "right_buyer"]:
		var buyer: Dictionary = tycoon[side_key]
		var delta_m: int = rng.randi_range(-12, 14) * 100
		var delta_c: int = rng.randi_range(-28, 32) * 100
		var m_val: int = clampi(int(buyer["metal_price"]) + delta_m, 7200, 15500) + mars_bonus
		var c_val: int = clampi(int(buyer["crystal_price"]) + delta_c, 19500, 39500) + mars_bonus * 2
		if bribed or futures_locked:
			m_val = maxi(m_val, 14200 + mars_bonus)
			c_val = maxi(c_val, 36000 + mars_bonus * 2)
		buyer["metal_price"] = m_val
		buyer["crystal_price"] = c_val
		buyer["trend"] = 1 if (delta_m + delta_c) >= 0 else -1

	if state.current_tick % 3 == 0:
		var actions: Array[String] = [
			"雷克斯重工向近轨铁星派出了重型采矿船，左港金属库存上升",
			"维多利亚星环资本大举收购半人马星系高能晶簇，右港晶价走强",
			"奥托勘探团在天鹅座外环引爆深岩震源弹，发现高纯度伴生矿脉",
			"星舰大宗商品交易所买盘涌入，火星殖民工程拉动钛钢需求"
		]
		tycoon["rival_activity"] = actions[rng.randi() % actions.size()]


## 📡 发射「星链 V2 Mini 一箭 12 星组网批次 (Launch Starlink Batch)」
## 效果：
## 1. 在地球低轨平流层形成可视化「星链卫星列车 (Starlink Train)」(12 -> 24 -> 36 颗)
## 2. 立即自动扫描并揭盲当前星系中 1 颗未探明储量的星球！
## 3. 每游戏日 (每 2 ticks) 自动产生全球宽带与深空通信订阅现金流分红（每批次 +$25/日，最高 +$75/日）！
static func launch_starlink_batch(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var cur_batches: int = int(tycoon.get("starlink_batches", 0))
	if cur_batches >= 3:
		return {"ok": false, "error": "地球低轨星链星座已达满额 36 颗在轨卫星（每日分红 +$75）。"}
	var cost: int = 9000 # $90
	if state.cash_cents < cost:
		return {"ok": false, "error": "发射星链 V2 Mini 一箭12星组网需 $90。"}
	state.cash_cents -= cost
	state.stats["expenses"]["launch"] = int(state.stats["expenses"]["launch"]) + cost
	var next_batches: int = cur_batches + 1
	tycoon["starlink_batches"] = next_batches
	state.events_enabled = true

	# 自动揭盲一颗未探明星球
	var revealed_star_name: String = ""
	for sid in state.stars:
		var s: Dictionary = state.stars[sid]
		if not bool(s.get("revealed", true)):
			s["revealed"] = true
			revealed_star_name = str(s["name"])
			break

	var total_sats: int = next_batches * 12
	var daily_div: int = next_batches * 25
	var scan_msg: String = ("，且顺带遥测探明了「%s」的地下储量" % revealed_star_name) if revealed_star_name != "" else ""
	state.add_log("【📡 星链一箭12星入轨】在轨星链卫星达 %d 颗！每日自动产生 +$%d 全球通信现金流分红%s！" % [total_sats, daily_div, scan_msg])
	return {"ok": true, "batches": next_batches, "satellites": total_sats, "daily_dividend": daily_div, "revealed_star": revealed_star_name}


## 🔧 星舰巨湾「模块化专精改装工坊 (Upgrade Ship Block Tier: Block 1 -> Block 2 -> Block 3)」
## 对指定可回收火箭/星舰进行专精升级：
## - Block 2 ($70)：加装筷子塔机械臂捕获销与快卸舱门，返港卸货后【0 翻修耗时】直接待命复飞！
## - Block 3 ($110)：换装猛禽3代真空喷管与六角隔热瓦，每次成功返港卸货额外发放 +$40 回收燃料节余补贴！
static func upgrade_ship_block(state: GameState, ship_id: int) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	var ship: Dictionary = state.get_ship(ship_id)
	if ship.is_empty() or not MissionRules.is_reusable_mode(str(ship.get("mode", ""))):
		return {"ok": false, "error": "仅可回收复用箭或不锈钢星舰支持模块化 Block 改装。"}
	var cur_tier: int = int(ship.get("block_tier", 1))
	if cur_tier >= 3:
		return {"ok": false, "error": "该舰已达最高 Block 3 终极星际母舰规格。"}
	var cost: int = 7000 if cur_tier == 1 else 11000
	if state.cash_cents < cost:
		return {"ok": false, "error": "改装 #%d 至 Block %d 需 %s。" % [ship_id, cur_tier + 1, MissionRules.money(cost)]}
	state.cash_cents -= cost
	state.stats["expenses"]["refit"] = int(state.stats["expenses"]["refit"]) + cost
	var next_tier: int = cur_tier + 1
	ship["block_tier"] = next_tier
	if str(ship.get("state", "")) == "refurbishing":
		ship["state"] = "idle"
	var desc: String = "筷子塔机械臂即夹即飞（免除翻修等待时间！）" if next_tier == 2 else "猛禽3代真空母舰（每次返港额外奖励 +$40 燃料节余补贴！）"
	state.add_log("【🔧 星舰巨湾改装】#%d %s已升级至 Block %d：%s" % [ship_id, Simulation.mode_name(str(ship["mode"])), next_tier, desc])
	return {"ok": true, "ship_id": ship_id, "block_tier": next_tier, "desc": desc}


static func _mars_price_bonus_cents(stage: int) -> int:
	match stage:
		1: return 1000
		2: return 2200
		3: return 3500
		4: return 5000
		5: return 7500
		_: return 0


static func best_buyer_price(state: GameState, ore: String) -> Dictionary:
	var base: int = int(state.balance["prices"][ore])
	if not state.stats.has("tycoon") or not state.events_enabled:
		return {"price": base, "buyer": "常驻商"}
	var tycoon: Dictionary = state.stats["tycoon"]
	var key: String = "metal_price" if ore == "metal" else "crystal_price"
	var l_price: int = int(tycoon["left_buyer"][key])
	var r_price: int = int(tycoon["right_buyer"][key])
	var pref: String = str(tycoon.get("active_buyer", "best"))
	if pref == "left":
		return {"price": l_price, "buyer": "左港·星舰重工"}
	if pref == "right":
		return {"price": r_price, "buyer": "右港·火星财团"}
	if l_price >= r_price:
		return {"price": l_price, "buyer": "左港·星舰重工"}
	return {"price": r_price, "buyer": "右港·火星财团"}


static func drill_vein_pocket(state: GameState, star_id: String, pocket_idx: int) -> Dictionary:
	if state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "当前无法操控该星球钻头。"}
	var star: Dictionary = state.stars[star_id]
	star["active_pocket"] = clampi(pocket_idx, 0, 2)
	if not bool(star.get("revealed", true)):
		return {"ok": false, "error": "请先发射探矿卫星探明地下岩层，再点击矿囊定向钻探。"}
	if not bool(star.get("has_miner", false)):
		return {"ok": true, "aimed_only": true, "pocket": pocket_idx, "msg": "已预设激光钻头靶向至 #%d 矿囊（部署矿机后自动爆破采掘）。" % (pocket_idx + 1)}

	var drilled: Array = star.get("pockets_drilled", [])
	for d in drilled:
		if int(d) == pocket_idx:
			return {"ok": true, "aimed_only": true, "pocket": pocket_idx, "msg": "激光钻头已转向 #%d 号矿脉分支持续采掘。" % (pocket_idx + 1)}

	drilled.append(pocket_idx)
	star["pockets_drilled"] = drilled
	var added_res: int = 4
	star["reserve"] = int(star["reserve"]) + added_res
	star["initial_reserve"] = int(star["initial_reserve"]) + added_res
	var cap: int = Simulation.star_capacity(state, star)
	var instant_crate: int = 0
	if int(star["stock"]) < cap and int(star["reserve"]) > 0:
		star["stock"] = int(star["stock"]) + 1
		star["reserve"] = int(star["reserve"]) - 1
		star["produced"] = int(star["produced"]) + 1
		instant_crate = 1
	var pocket_names: Array[String] = ["左翼高纯金属核", "中轴高压主矿脉", "右翼伴生富晶洞"]
	var p_name: String = pocket_names[clampi(pocket_idx, 0, 2)]
	state.add_log("【定向激光钻探】%s钻头精准击穿「%s」！探明储量 +%d 箱%s！" % [str(star["name"]), p_name, added_res, "，且立即爆出 1 箱原矿入仓" if instant_crate > 0 else ""])
	return {"ok": true, "aimed_only": false, "pocket": pocket_idx, "pocket_name": p_name, "added": added_res, "instant": instant_crate}


static func prospect_star_veins(state: GameState, star_id: String) -> Dictionary:
	if state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "目标不可探矿。"}
	var star: Dictionary = state.stars[star_id]
	if not bool(star.get("revealed", true)):
		return Simulation.start_scan(state, star_id)
	if bool(star.get("vein_prospected", false)):
		return {"ok": false, "error": "该星球的深部伴生富矿夹层已全部探明。"}
	var fee: int = int(state.balance["scan_price"])
	if state.cash_cents < fee:
		return {"ok": false, "error": "发射地质探矿卫星需 %s。" % MissionRules.money(fee)}
	var bonus_ore: int = 8 if str(star["ore"]) == "metal" else 6
	state.cash_cents -= fee
	state.stats["expenses"]["scan"] = int(state.stats["expenses"]["scan"]) + fee
	star["vein_prospected"] = true
	star["reserve"] = int(star["reserve"]) + bonus_ore
	star["initial_reserve"] = int(star["initial_reserve"]) + bonus_ore
	star["exhausted_announced"] = false
	var ore_label: String = "高品位赤铁钛富矿脉" if str(star["ore"]) == "metal" else "高纯度氦-3能量晶簇"
	state.add_log("【卫星地质探矿】%s声呐扫描完成！在表层岩壳下方发现%s，新增储量 +%d 箱！" % [str(star["name"]), ore_label, bonus_ore])
	SteamService.unlock_achievement("ACH_PROSPECTING_RADAR")
	return {"ok": true, "mode": "vein_bonus", "bonus": bonus_ore, "ore_label": ore_label}


static func discover_new_star(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if state.stars.size() >= 9:
		return {"ok": false, "error": "当前星域巡天雷达已达最大天体容量 (9 颗)。"}
	var cost: int = 10000
	if state.cash_cents < cost:
		return {"ok": false, "error": "启动深空巡天望远镜搜寻新矿星需 $100。"}
	var chosen: Dictionary = {}
	for candidate in DISCOVERABLE_STARS:
		var cid: String = str(candidate["id"])
		if not state.stars.has(cid):
			chosen = candidate
			break
	if chosen.is_empty():
		return {"ok": false, "error": "附近星域所有隐藏天体已全部被您发现！"}

	state.cash_cents -= cost
	state.stats["expenses"]["scan"] = int(state.stats["expenses"]["scan"]) + cost
	var new_id: String = str(chosen["id"])
	var res_amt: int = int(chosen["reserve"])
	var deep_amt: int = int(chosen["deep"])
	var pos_arr: Array = chosen["pos"]
	state.stars[new_id] = {
		"id": new_id,
		"name": str(chosen["name"]),
		"ore": str(chosen["ore"]),
		"route": str(chosen["route"]),
		"environment": str(chosen["env"]),
		"zone": str(chosen["zone"]),
		"reserve": res_amt,
		"initial_reserve": res_amt,
		"deep_reserve": deep_amt,
		"deep_unlocked": false,
		"vein_prospected": false,
		"active_pocket": 1,
		"pockets_drilled": [],
		"pipe_level": 1,
		"initial_stock": 2,
		"stock": 2,
		"public_min": maxi(6, res_amt - 6),
		"public_max": res_amt + 10,
		"revealed": false,
		"licensed": false,
		"has_miner": false,
		"has_silo": false,
		"next_production_tick": 0,
		"produced": 0,
		"shipped": 0,
		"stalled_ticks": 0,
		"exhausted_announced": false,
		"map_position": [float(pos_arr[0]), float(pos_arr[1])]
	}
	state.add_log("【深空巡天重大发现】望远镜在%s捕获新天体「%s」！快派探测卫星探查其地下矿脉！" % [str(chosen["zone"]), str(chosen["name"])])
	return {"ok": true, "star_id": new_id, "star_name": str(chosen["name"]), "zone": str(chosen["zone"])}


static func upgrade_orbital_depot(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var cur_lvl: int = int(tycoon.get("orbital_depot_level", 0))
	if cur_lvl >= 3:
		return {"ok": false, "error": "近地轨道星舰加注站已达最高 Lv.3 规模。"}
	var costs: Array[int] = [11000, 16000, 22000]
	var cost: int = costs[cur_lvl]
	if state.cash_cents < cost:
		return {"ok": false, "error": "建设 Lv.%d 近地轨道加注站需 %s。" % [cur_lvl + 1, MissionRules.money(cost)]}
	state.cash_cents -= cost
	state.stats["expenses"]["research"] = int(state.stats["expenses"].get("research", 0)) + cost
	var next_lvl: int = cur_lvl + 1
	tycoon["orbital_depot_level"] = next_lvl
	if next_lvl == 1:
		state.balance["hulls"]["medium"]["travel_ticks"]["mid"] = maxi(2, int(state.balance["hulls"]["medium"]["travel_ticks"]["mid"]) - 1)
		if state.balance["hulls"]["medium"]["travel_ticks"].has("far"):
			state.balance["hulls"]["medium"]["travel_ticks"]["far"] = maxi(3, int(state.balance["hulls"]["medium"]["travel_ticks"]["far"]) - 1)
	elif next_lvl == 2:
		state.balance["hulls"]["light"]["travel_ticks"]["mid"] = maxi(2, int(state.balance["hulls"]["light"]["travel_ticks"]["mid"]) - 1)
		state.balance["fuel_unit_price"] = maxi(1000, int(state.balance["fuel_unit_price"]) - 300)
	elif next_lvl == 3:
		state.balance["launch_fee"] = maxi(2000, int(state.balance["launch_fee"]) - 2000)
		if state.balance["hulls"].has("heavy"):
			state.balance["hulls"]["heavy"]["travel_ticks"]["mid"] = 3
			state.balance["hulls"]["heavy"]["travel_ticks"]["far"] = 3
	state.add_log("【近地轨道在轨加注站 Lv.%d】已部署至地球平流层上方！中远距星舰在轨满油加速，航程与推进剂成本大幅降低！" % next_lvl)
	return {"ok": true, "level": next_lvl, "cost": cost}


static func smelt_and_sell_port_ore(state: GameState, ore: String) -> Dictionary:
	if state.season_ended or not (ore in ["metal", "crystal"]):
		return {"ok": false, "error": "当前无法启动电弧精炼。"}
	var qty: int = int(state.port_storage.get(ore, 0))
	if qty <= 0:
		return {"ok": false, "error": "母港立体仓中没有可精炼的%s原矿（需先用火箭从星球运回母港）。" % Simulation.ore_name(ore)}
	var base_unit_price: int = MissionRules.current_ore_price(state, ore)
	var refined_unit_price: int = int(round(float(base_unit_price) * 1.35))
	var total_proceeds: int = qty * refined_unit_price
	state.port_storage[ore] = 0
	state.cash_cents += total_proceeds
	state.stats["revenue"] = int(state.stats["revenue"]) + total_proceeds
	state.stats["sold"][ore] = int(state.stats["sold"][ore]) + qty
	var product_name: String = "304L航天不锈钢卷材" if ore == "metal" else "高纯度氦-3聚变燃料棒"
	state.add_log("【电弧精炼出厂】已将 %d 箱%s精炼为「%s」（溢价 +35%%），入账 %s！" % [qty, Simulation.ore_name(ore), product_name, MissionRules.money(total_proceeds)])
	Simulation._resolve_port(state)
	return {"ok": true, "quantity": qty, "proceeds": total_proceeds, "product": product_name}


static func invest_mars_colony(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var cur_stage: int = int(tycoon.get("mars_stage", 0))
	if cur_stage >= MARS_STAGES.size():
		return {"ok": false, "error": "人类已建成百万人口自给自足火星星城！"}
	var stage_info: Dictionary = MARS_STAGES[cur_stage]
	var cost: int = int(stage_info["cost_cents"])
	if state.cash_cents < cost:
		return {"ok": false, "error": "推进「%s」需资金 %s。" % [str(stage_info["name"]), MissionRules.money(cost)]}
	state.cash_cents -= cost
	state.stats["expenses"]["research"] = int(state.stats["expenses"].get("research", 0)) + cost
	var next_stage: int = cur_stage + 1
	tycoon["mars_stage"] = next_stage
	if next_stage == 3:
		state.balance["port_capacity"] = int(state.balance["port_capacity"]) + 8
	state.events_enabled = true
	tick_market_fluctuation(state)
	state.add_log("【🪐 火星殖民里程碑达成】%s 完成！%s！" % [str(stage_info["name"]), str(stage_info["bonus_desc"])])
	if next_stage >= 3:
		SteamService.unlock_achievement("ACH_TECH_MASTER")
	return {"ok": true, "stage": next_stage, "name": str(stage_info["name"]), "bonus": str(stage_info["bonus_desc"]), "cost": cost}


static func sign_futures_contract(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	if state.current_tick < int(tycoon.get("futures_until", 0)):
		return {"ok": false, "error": "远期保底高价期货合约仍在生效期内。"}
	var fee: int = 6000
	if state.cash_cents < fee:
		return {"ok": false, "error": "签署远期锁价期货合约需保证金 $60。"}
	state.cash_cents -= fee
	state.stats["expenses"]["license"] = int(state.stats["expenses"]["license"]) + fee
	tycoon["futures_until"] = state.current_tick + 10
	state.events_enabled = true
	tick_market_fluctuation(state)
	state.add_log("【星际期货锁价】已签署 5 日远期高价交割合约：金属保底 $142+/箱，晶体保底 $360+/箱！")
	return {"ok": true, "cost": fee}


static func upgrade_deep_drill(state: GameState, star_id: String) -> Dictionary:
	if state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "无法升级该星球钻机。"}
	var star: Dictionary = state.stars[star_id]
	if not bool(star.get("has_miner", false)):
		return {"ok": false, "error": "需先在该星球部署基础矿机，才能加装深岩穿甲钻头。"}
	if bool(star.get("deep_unlocked", false)):
		return {"ok": false, "error": "该星球深层岩芯矿脉已凿通。"}
	var deep_amount: int = int(star.get("deep_reserve", 24))
	if deep_amount <= 0:
		deep_amount = 24
	var cost: int = 12000
	if state.cash_cents < cost:
		return {"ok": false, "error": "深岩钻头改造需 %s。" % MissionRules.money(cost)}
	state.cash_cents -= cost
	state.stats["expenses"]["miner"] = int(state.stats["expenses"]["miner"]) + cost
	star["deep_unlocked"] = true
	star["deep_reserve"] = 0
	star["reserve"] = int(star["reserve"]) + deep_amount
	star["initial_reserve"] = int(star["initial_reserve"]) + deep_amount
	star["revealed"] = true
	star["exhausted_announced"] = false
	state.add_log("【深岩破壁】%s成功钻透玄武岩层！深层地核富矿脉并入 +%d 箱！" % [str(star["name"]), deep_amount])
	return {"ok": true, "added": deep_amount, "cost": cost}


static func upgrade_star_pipe(state: GameState, star_id: String) -> Dictionary:
	if state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "无法升级该星球轨道设施。"}
	var star: Dictionary = state.stars[star_id]
	var cur_lvl: int = int(star.get("pipe_level", 1))
	if cur_lvl >= 3:
		return {"ok": false, "error": "该星球星轨弹射导轨已达最高 Lv.3 等级。"}
	var cost: int = 9000 if cur_lvl == 1 else 15000
	if state.cash_cents < cost:
		return {"ok": false, "error": "升级 Lv.%d 星轨弹射导轨需 %s。" % [cur_lvl + 1, MissionRules.money(cost)]}
	state.cash_cents -= cost
	state.stats["expenses"]["silo"] = int(state.stats["expenses"]["silo"]) + cost
	star["pipe_level"] = cur_lvl + 1
	state.add_log("【星轨弹射导轨升级】%s升级至 Lv.%d：星表矿仓容量 +6 箱，去程燃料减耗！" % [str(star["name"]), cur_lvl + 1])
	return {"ok": true, "level": cur_lvl + 1, "cost": cost}


static func bribe_saloon_official(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	var cost: int = 8000
	if state.cash_cents < cost:
		return {"ok": false, "error": "沙龙公关需 %s 招待费。" % MissionRules.money(cost)}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	state.cash_cents -= cost
	state.stats["expenses"]["license"] = int(state.stats["expenses"]["license"]) + cost
	state.stats["tycoon"]["saloon_bribe_until"] = state.current_tick + 8
	state.events_enabled = true
	tick_market_fluctuation(state)
	state.add_log("【星港沙龙密约】已招待贸易专员（$80）：未来 4 日左右双港收购价锁定高位溢价！")
	return {"ok": true, "cost": cost}


static func buy_starport_shares(state: GameState) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var shares: Dictionary = tycoon["shares"]
	var unowned: int = int(shares.get("unowned", 0))
	var price: int = int(tycoon.get("share_price_cents", 60000))

	if int(shares.get("player", 5)) >= 100:
		return {"ok": false, "error": "您已 100% 绝对控股地球星舰母港！"}

	if unowned < 5:
		var target_rival: String = ""
		for r_key in ["rex", "victoria", "otto"]:
			if int(shares.get(r_key, 0)) >= 5:
				target_rival = r_key
				break
		if target_rival == "":
			return {"ok": false, "error": "母港股权已全部归属您麾下！"}
		if state.cash_cents < price:
			return {"ok": false, "error": "敌意收购对手 5%% 股权需 %s。" % MissionRules.money(price)}
		state.cash_cents -= price
		state.stats["expenses"]["research"] = int(state.stats["expenses"].get("research", 0)) + price
		shares[target_rival] = int(shares[target_rival]) - 5
		shares["player"] = int(shares.get("player", 5)) + 5
		tycoon["share_price_cents"] = int(price * 1.12)
		state.add_log("【敌意并购】您斥资 %s 强行收购了竞争对手手中的 5%% 股权（当前持股 %d%%）！" % [MissionRules.money(price), int(shares["player"])])
		if int(shares["player"]) >= 50:
			SteamService.unlock_achievement("ACH_GALACTIC_MONOPOLY")
		return {"ok": true, "player_shares": int(shares["player"]), "cost": price}

	if state.cash_cents < price:
		return {"ok": false, "error": "认购 5%% 母港股权需 %s。" % MissionRules.money(price)}
	state.cash_cents -= price
	state.stats["expenses"]["research"] = int(state.stats["expenses"].get("research", 0)) + price
	shares["player"] = int(shares.get("player", 5)) + 5
	shares["unowned"] = unowned - 5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.current_tick * 97 + int(shares["player"]))
	if int(shares["unowned"]) >= 5 and rng.randf() < 0.65:
		var rivals: Array[String] = ["rex", "victoria", "otto"]
		var chosen_r: String = rivals[rng.randi() % rivals.size()]
		shares[chosen_r] = int(shares.get(chosen_r, 5)) + 5
		shares["unowned"] = int(shares["unowned"]) - 5
	tycoon["share_price_cents"] = int(price * 1.15)
	state.add_log("【股权竞拍】您成功增持 5%% 地球星舰母港股权（当前持股 %d%%）！" % int(shares["player"]))
	if int(shares["player"]) >= 50:
		SteamService.unlock_achievement("ACH_GALACTIC_MONOPOLY")
	return {"ok": true, "player_shares": int(shares["player"]), "cost": price}


## ============================================================================
## v6.0 《石油大亨 (Turmoil)》极简爽感闭环 & 双舞台实时举牌拍卖系统
## ============================================================================

const SECTOR_PLOT_TEMPLATES: Array[Dictionary] = [
	{"code": "A1", "name": "奥尔特富铁扇区", "ore": "metal", "base_richness": 68, "zone": "地月与近地轨道圈"},
	{"code": "A2", "name": "水星炙热钛核带", "ore": "metal", "base_richness": 79, "zone": "地月与近地轨道圈"},
	{"code": "A3", "name": "谷神星冰封晶脉", "ore": "crystal", "base_richness": 74, "zone": "地月与近地轨道圈"},
	{"code": "A4", "name": "灵神星纯金铁核", "ore": "metal", "base_richness": 92, "zone": "地月与近地轨道圈"},
	{"code": "B1", "name": "半人马α伴星矿床", "ore": "metal", "base_richness": 64, "zone": "火星与主小行星带"},
	{"code": "B2", "name": "比邻星棱镜晶洞", "ore": "crystal", "base_richness": 85, "zone": "火星与主小行星带"},
	{"code": "B3", "name": "潘多拉超重磁核", "ore": "metal", "base_richness": 88, "zone": "火星与主小行星带"},
	{"code": "B4", "name": "木卫二深海晶簇", "ore": "crystal", "base_richness": 94, "zone": "火星与主小行星带"},
	{"code": "C1", "name": "天鹅座星云外滩", "ore": "crystal", "base_richness": 72, "zone": "木星特洛伊外环带"},
	{"code": "C2", "name": "泰坦极寒液烷海", "ore": "crystal", "base_richness": 83, "zone": "木星特洛伊外环带"},
	{"code": "C3", "name": "开普勒超重钻星", "ore": "crystal", "base_richness": 91, "zone": "木星特洛伊外环带"},
	{"code": "C4", "name": "天鹅座黑洞伴生脉", "ore": "crystal", "base_richness": 98, "zone": "木星特洛伊外环带"}
]


static func ensure_auction_plots(state: GameState) -> Array:
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	if tycoon.has("auction_plots") and (tycoon["auction_plots"] is Array) and (tycoon["auction_plots"] as Array).size() == 12:
		return tycoon["auction_plots"]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(state.sector_seed * 73 + 1999)
	var plots: Array = []
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var has_radar_tech: bool = TechTree.is_unlocked(unlocked, "orbital_radar")
	var err_range: int = 8 if has_radar_tech else 22

	for idx in range(SECTOR_PLOT_TEMPLATES.size()):
		var tpl: Dictionary = SECTOR_PLOT_TEMPLATES[idx]
		var est_rich: int = clampi(int(tpl["base_richness"]) + rng.randi_range(-10, 8), 44, 96)
		# 真实储量带有地质预测误差：高预估区可能遭遇玄武岩贫化，便宜低分矿区可能藏有意外富矿！
		var delta_err: int = rng.randi_range(-err_range, err_range + 6)
		if est_rich < 68 and rng.randf() < 0.42:
			delta_err = rng.randi_range(16, 32) # 便宜矿区藏有意外发现！
		var true_rich: int = clampi(est_rich + delta_err, 36, 99)
		var bonus_boxes: int = 6 + int(float(true_rich - 30) * 0.36)
		var base_price: int = (50 + int(float(est_rich - 40) * 1.9)) * 100
		var dist_label: String = "近地月球轨(运费低)" if idx < 4 else ("火星中轨(运费中)" if idx < 8 else "小行星带(运费高)")
		plots.append({
			"index": idx,
			"code": str(tpl["code"]),
			"name": str(tpl["name"]),
			"ore": str(tpl["ore"]),
			"zone": str(tpl["zone"]),
			"distance_label": dist_label,
			"richness": est_rich,
			"error_margin": err_range,
			"true_richness": true_rich,
			"bonus_boxes": bonus_boxes,
			"free_miner": true_rich >= 86,
			"base_price_cents": base_price,
			"owner": "",
			"final_price_cents": 0
		})
	tycoon["auction_plots"] = plots
	return plots


static func claim_auction_plot(state: GameState, plot_idx: int, winner_id: String, price_cents: int, preferred_star_id: String = "") -> Dictionary:
	var plots: Array = ensure_auction_plots(state)
	if plot_idx < 0 or plot_idx >= plots.size():
		return {"ok": false, "error": "无效的星区地块编号。"}
	var plot: Dictionary = plots[plot_idx]
	if str(plot.get("owner", "")) != "":
		return {"ok": false, "error": "该星区采矿权已被拍出。"}

	if winner_id == "player":
		if state.cash_cents < price_cents:
			return {"ok": false, "error": "现金不足以支付竞拍成交价 %s。" % MissionRules.money(price_cents)}
		state.cash_cents -= price_cents
		state.stats["expenses"]["license"] = int(state.stats["expenses"]["license"]) + price_cents
		plot["owner"] = "player"
		plot["final_price_cents"] = price_cents

		# 将拍下的高产星区储量与钻机加成注入对应矿星
		var target_sid: String = preferred_star_id
		if target_sid == "" or not state.stars.has(target_sid):
			target_sid = str(state.stars.keys()[0])
		for sid in state.stars:
			var s: Dictionary = state.stars[sid]
			if str(s.get("ore", "")) == str(plot["ore"]):
				target_sid = str(sid)
				break
		var star: Dictionary = state.stars[target_sid]
		var added_boxes: int = int(plot["bonus_boxes"])
		star["reserve"] = int(star["reserve"]) + added_boxes
		star["initial_reserve"] = int(star["initial_reserve"]) + added_boxes
		star["revealed"] = true
		star["stock"] = mini(Simulation.star_capacity(state, star), int(star["stock"]) + 3)
		var miner_gifted: bool = false
		if bool(plot.get("free_miner", false)) and not bool(star.get("has_miner", false)):
			star["has_miner"] = true
			star["next_production_tick"] = state.current_tick + int(state.balance["production_ticks"][star["ore"]])
			miner_gifted = true
		var gift_txt: String = "，并获赠 1 座已激活的星表自动钻机" if miner_gifted else ""
		state.add_log("【🔨 星区拍卖落槌】您以 %s 拍下「%s (热力 %d)」采矿权！「%s」储量 +%d 箱、现矿 +3 箱%s！" % [
			MissionRules.money(price_cents), str(plot["code"]) + "·" + str(plot["name"]), int(plot["richness"]),
			str(star["name"]), added_boxes, gift_txt
		])
		return {
			"ok": true, "winner": "player", "plot": plot, "star_id": target_sid,
			"star_name": str(star["name"]), "added_boxes": added_boxes, "miner_gifted": miner_gifted
		}
	else:
		plot["owner"] = winner_id
		plot["final_price_cents"] = price_cents
		var rival_name: String = "AI 财团"
		for r in AI_RIVALS:
			if str(r["id"]) == winner_id:
				rival_name = str(r["name"])
				break
		state.add_log("【🔨 星区拍卖情报】%s 以 %s 拍下了「%s·%s」采矿权。" % [
			rival_name, MissionRules.money(price_cents), str(plot["code"]), str(plot["name"])
		])
		return {"ok": true, "winner": winner_id, "rival_name": rival_name, "plot": plot}


static func award_live_stock_lot(state: GameState, winner_id: String, bid_cents: int) -> Dictionary:
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var shares: Dictionary = tycoon["shares"]
	var unowned: int = int(shares.get("unowned", 0))

	if winner_id == "player":
		if int(shares.get("player", 5)) >= 100:
			return {"ok": false, "error": "您已持有 100% 股权！"}
		if state.cash_cents < bid_cents:
			return {"ok": false, "error": "现金不足以支付股权竞拍成交价 %s。" % MissionRules.money(bid_cents)}
		state.cash_cents -= bid_cents
		state.stats["expenses"]["research"] = int(state.stats["expenses"].get("research", 0)) + bid_cents
		if unowned >= 5:
			shares["unowned"] = unowned - 5
		else:
			for r_key in ["rex", "victoria", "otto"]:
				if int(shares.get(r_key, 0)) >= 5:
					shares[r_key] = int(shares[r_key]) - 5
					break
		shares["player"] = int(shares.get("player", 5)) + 5
		tycoon["share_price_cents"] = maxi(int(tycoon.get("share_price_cents", 60000)), int(float(bid_cents) * 1.08))
		if int(shares["player"]) >= 50:
			SteamService.unlock_achievement("ACH_GALACTIC_MONOPOLY")
		state.add_log("【🏛 母港股权拍卖落槌】您以 %s 竞拍夺得 5%% 地球星舰母港永久股权（当前持股 %d%%）！" % [
			MissionRules.money(bid_cents), int(shares["player"])
		])
		return {"ok": true, "winner": "player", "player_shares": int(shares["player"]), "cost": bid_cents}
	else:
		if unowned >= 5:
			shares["unowned"] = unowned - 5
			shares[winner_id] = int(shares.get(winner_id, 5)) + 5
		var rival_name: String = winner_id
		for r in AI_RIVALS:
			if str(r["id"]) == winner_id:
				rival_name = str(r["name"])
				break
		state.add_log("【🏛 母港股权拍卖】%s 以 %s 拍下 5%% 母港股权（当前持股 %d%%）。" % [
			rival_name, MissionRules.money(bid_cents), int(shares.get(winner_id, 5))
		])
		return {"ok": true, "winner": winner_id, "rival_name": rival_name, "cost": bid_cents}


## 💰 对标《石油大亨》：向指定买方港口（左港/右港）一键开闸倾销母港全部库存！
static func sell_port_to_buyer(state: GameState, side_key: String) -> Dictionary:
	if state.season_ended:
		return {"ok": false, "error": "本季已结束。"}
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	var buyer: Dictionary = tycoon.get(side_key, tycoon["left_buyer"])
	var buyer_name: String = str(buyer.get("name", "星港买方"))

	var m_qty: int = int(state.port_storage.get("metal", 0))
	var c_qty: int = int(state.port_storage.get("crystal", 0))
	if m_qty + c_qty <= 0:
		# 自动帮玩家把销售策略切换为「留货入母港仓」，方便下一船到港后直接高价开闸倾销
		state.sale_policies["metal"] = "hold"
		state.sale_policies["crystal"] = "hold"
		return {
			"ok": false,
			"switched_to_hold": true,
			"error": "当前母港立体仓暂无囤矿。已为您自动开启【📦 返港囤矿模式】，火箭卸货入仓后即可点击左/右港高价开闸倾销！"
		}

	var mayor_mult: float = 1.15 if int(tycoon["shares"].get("player", 5)) >= 50 else 1.0
	var m_unit: int = int(round(float(buyer.get("metal_price", 10000)) * mayor_mult))
	var c_unit: int = int(round(float(buyer.get("crystal_price", 25000)) * mayor_mult))
	var total_proceeds: int = m_qty * m_unit + c_qty * c_unit

	state.port_storage["metal"] = 0
	state.port_storage["crystal"] = 0
	state.cash_cents += total_proceeds
	state.stats["regular_revenue"] = int(state.stats["regular_revenue"]) + total_proceeds
	state.stats["sold"]["metal"] = int(state.stats["sold"]["metal"]) + m_qty
	state.stats["sold"]["crystal"] = int(state.stats["sold"]["crystal"]) + c_qty

	var mayor_tag: String = "（含 50%+ 控股执政官 +15% 垄断溢价！）" if mayor_mult > 1.0 else ""
	state.add_log("【💥 开闸倾销暴富】向「%s」一键倾销 %d 箱矿石，入账 %s%s！" % [
		buyer_name, m_qty + c_qty, MissionRules.money(total_proceeds), mayor_tag
	])
	return {
		"ok": true,
		"buyer_name": buyer_name,
		"quantity": m_qty + c_qty,
		"proceeds": total_proceeds
	}


## ⚡ 对标《石油大亨》极简一鼠流：为当前选中星球智能计算最佳“一键派遣方案”
static func build_smart_mission(state: GameState, star_id: String) -> Dictionary:
	if state == null or state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "error": "当前星球不可派遣。"}
	var star: Dictionary = state.stars[star_id]
	var pending_miner: bool = false
	for ship in state.ships:
		if str(ship.get("state", "")) == "outbound" and str(ship.get("star_id", "")) == star_id and bool(ship.get("deliver_miner", false)):
			pending_miner = true
			break

	var public_res: Dictionary = state.public_reserve(star)
	var has_reserve: bool = (not bool(public_res["exact"])) or int(public_res["max"]) > 0
	var wants_miner: bool = (not bool(star["has_miner"])) and (not pending_miner) and has_reserve

	# 候选箭体列表：优先使用机库里待命的可回收星舰/猎鹰复用箭，其次按性价比选择新购火箭
	var candidates: Array[Dictionary] = []
	for ship in state.ships:
		if MissionRules.is_reusable_mode(str(ship["mode"])) and str(ship["state"]) == "idle":
			candidates.append({"mode": str(ship["mode"]), "owned_ship_id": int(ship["id"]), "priority": 100})

	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var active_reusable_count: int = state.active_reusable_ships()
	var fleet_limit: int = int(state.balance["fleet_limit"])
	if active_reusable_count < fleet_limit:
		if TechTree.is_unlocked(unlocked, "starship_heavy"):
			candidates.append({"mode": "heavy_reuse", "owned_ship_id": 0, "priority": 85})
		candidates.append({"mode": "medium_reuse", "owned_ship_id": 0, "priority": 75})
	candidates.append({"mode": "medium_once", "owned_ship_id": 0, "priority": 60})
	candidates.append({"mode": "light", "owned_ship_id": 0, "priority": 50})

	var best_req: Dictionary = {}
	var best_quote: Dictionary = {}
	var best_score: int = -999999

	for cand in candidates:
		var mode: String = str(cand["mode"])
		var owned_id: int = int(cand["owned_ship_id"])
		var req: Dictionary = {
			"mode": mode,
			"owned_ship_id": owned_id,
			"star_id": star_id,
			"miner": wants_miner,
			"silo": false,
			"cargo": 10 if mode == "heavy_reuse" else 8
		}
		var max_c: int = MissionRules.max_feasible_cargo(state, req)
		if max_c < 0 and wants_miner:
			# 如果带矿机超重，尝试不带矿机仅抢运现矿
			if int(star["stock"]) > 0:
				req["miner"] = false
				max_c = MissionRules.max_feasible_cargo(state, req)
		if max_c < 0:
			continue
		req["cargo"] = max_c
		var quote: Dictionary = MissionRules.quote_mission(state, req)
		if not bool(quote.get("ok", false)):
			continue
		var score: int = int(cand["priority"]) * 10 + max_c * 25 - int(int(quote["total_cents"]) / 1000)
		if owned_id > 0:
			score += 500
		if score > best_score:
			best_score = score
			best_req = req
			best_quote = quote

	if best_req.is_empty():
		# 返回最接近的一套方案供提示差多少钱
		var fallback_req: Dictionary = {
			"mode": "light",
			"owned_ship_id": 0,
			"star_id": star_id,
			"miner": wants_miner,
			"silo": false,
			"cargo": 2 if wants_miner else 4
		}
		var fb_max: int = MissionRules.max_feasible_cargo(state, fallback_req)
		if fb_max >= 0:
			fallback_req["cargo"] = fb_max
		var fb_quote: Dictionary = MissionRules.quote_mission(state, fallback_req, false)
		var need_cents: int = int(fb_quote.get("total_cents", 20000))
		return {
			"ok": false,
			"request": fallback_req,
			"quote": fb_quote,
			"button_text": "⚡ 资金不足 (需 %s)" % MissionRules.money(need_cents),
			"error": "派遣火箭前往「%s」需 %s（当前现金 %s，可先卖矿或点顶部 +$5000 特权金）。" % [
				str(star["name"]), MissionRules.money(need_cents), MissionRules.money(state.cash_cents)
			]
		}

	var cost_str: String = MissionRules.money(int(best_quote["total_cents"]))
	var cargo_cnt: int = int(best_req["cargo"])
	var action_title: String = ""
	if bool(best_req["miner"]):
		action_title = "⚡ 一键建矿并发射 (%s · 带回%d箱)" % [cost_str, cargo_cnt]
	elif int(best_req["owned_ship_id"]) > 0:
		action_title = "🚀 一键复飞 #%d 运矿 (%s · 装%d箱)" % [int(best_req["owned_ship_id"]), cost_str, cargo_cnt]
	else:
		action_title = "🚀 一键满载抢运 (%s · 运回%d箱)" % [cost_str, cargo_cnt]

	return {
		"ok": true,
		"request": best_req,
		"quote": best_quote,
		"button_text": action_title
	}


## 🚀 方案 A 核心抉择 B：分别计算「便宜一次性火箭」与「昂贵可回收星舰」的最优配载方案，供玩家同屏直接博弈取舍！
static func build_typed_mission(state: GameState, star_id: String, want_reusable: bool) -> Dictionary:
	if state == null or state.season_ended or not state.stars.has(star_id):
		return {"ok": false, "button_text": "不可派遣"}
	var star: Dictionary = state.stars[star_id]
	var pending_miner: bool = false
	for ship in state.ships:
		if str(ship.get("state", "")) == "outbound" and str(ship.get("star_id", "")) == star_id and bool(ship.get("deliver_miner", false)):
			pending_miner = true
			break
	var public_res: Dictionary = state.public_reserve(star)
	var has_reserve: bool = (not bool(public_res["exact"])) or int(public_res["max"]) > 0
	var wants_miner: bool = (not bool(star["has_miner"])) and (not pending_miner) and has_reserve

	var candidates: Array[Dictionary] = []
	if want_reusable:
		for ship in state.ships:
			if MissionRules.is_reusable_mode(str(ship["mode"])) and str(ship["state"]) == "idle":
				candidates.append({"mode": str(ship["mode"]), "owned_ship_id": int(ship["id"]), "priority": 100})
		var unlocked: Array = state.stats.get("unlocked_techs", [])
		if state.active_reusable_ships() < int(state.balance["fleet_limit"]):
			if TechTree.is_unlocked(unlocked, "starship_heavy"):
				candidates.append({"mode": "heavy_reuse", "owned_ship_id": 0, "priority": 85})
			candidates.append({"mode": "medium_reuse", "owned_ship_id": 0, "priority": 75})
	else:
		candidates.append({"mode": "light", "owned_ship_id": 0, "priority": 80})
		candidates.append({"mode": "medium_once", "owned_ship_id": 0, "priority": 70})

	var best_req: Dictionary = {}
	var best_quote: Dictionary = {}
	for cand in candidates:
		var mode: String = str(cand["mode"])
		var owned_id: int = int(cand["owned_ship_id"])
		var req: Dictionary = {
			"mode": mode, "owned_ship_id": owned_id, "star_id": star_id,
			"miner": wants_miner, "silo": false, "cargo": 10 if mode == "heavy_reuse" else 8
		}
		var max_c: int = MissionRules.max_feasible_cargo(state, req)
		if max_c < 0 and wants_miner and int(star["stock"]) > 0:
			req["miner"] = false
			max_c = MissionRules.max_feasible_cargo(state, req)
		if max_c < 0:
			continue
		req["cargo"] = max_c
		var quote: Dictionary = MissionRules.quote_mission(state, req)
		if bool(quote.get("ok", false)):
			best_req = req
			best_quote = quote
			break

	if best_req.is_empty():
		var fb_mode: String = "medium_reuse" if want_reusable else "light"
		var fb_req: Dictionary = {
			"mode": fb_mode, "owned_ship_id": 0, "star_id": star_id,
			"miner": wants_miner, "silo": false, "cargo": 4
		}
		var fb_max: int = MissionRules.max_feasible_cargo(state, fb_req)
		if fb_max >= 0:
			fb_req["cargo"] = fb_max
		var fb_q: Dictionary = MissionRules.quote_mission(state, fb_req, false)
		var need_str: String = MissionRules.money(int(fb_q.get("total_cents", 20000)))
		var prefix: String = "♻复用星舰" if want_reusable else "🚀一次性箭"
		return {
			"ok": false,
			"button_text": "%s (需%s)" % [prefix, need_str],
			"error": "资金或机库席位不足，需 %s（可点击顶部 💳借贷+$100 应急或先卖矿回血）。" % need_str
		}

	var cost_s: String = MissionRules.money(int(best_quote["total_cents"]))
	var c_cnt: int = int(best_req["cargo"])
	var m_tag: String = "+建矿" if bool(best_req["miner"]) else ""
	if want_reusable:
		if int(best_req["owned_ship_id"]) > 0:
			return {"ok": true, "request": best_req, "quote": best_quote, "button_text": "♻复飞#%d%s (%s·%d箱)" % [int(best_req["owned_ship_id"]), m_tag, cost_s, c_cnt]}
		return {"ok": true, "request": best_req, "quote": best_quote, "button_text": "♻新购复用舰%s (%s·%d箱)" % [m_tag, cost_s, c_cnt]}
	else:
		return {"ok": true, "request": best_req, "quote": best_quote, "button_text": "🚀一次性箭%s (%s·%d箱)" % [m_tag, cost_s, c_cnt]}


## ============================================================================
## V1.0 官方定稿版核心机制：
## 1. 带有地质勘探误差的星区竞拍 (公开预估热力 != 真实储量，低价矿区可能藏有意外发现)
## 2. 囤货仓储维护成本 (等待高价需承担仓储费，仓储科技可减免)
## 3. 三家 AI 财团（资源财团 / 航运财团 / 投机财团）实时资金、库存与净利润竞争
## 4. 三类核心火箭（轻型一次性 / 可回收火箭 / 重型星舰）极简参数与一键派遣
## ============================================================================

static func ensure_rival_ledgers(state: GameState) -> Dictionary:
	if not state.stats.has("tycoon"):
		state.stats["tycoon"] = init_tycoon_meta()
	var tycoon: Dictionary = state.stats["tycoon"]
	if not tycoon.has("rival_ledgers"):
		tycoon["rival_ledgers"] = {
			"rex": {"name": "泰坦资源财团", "strategy": "竞拍积极，偏好高价值矿区", "cash_cents": 200000, "ore_stock": 2, "net_profit_cents": 12000},
			"victoria": {"name": "星际航运财团", "strategy": "投资运输效率，重视规模经营", "cash_cents": 200000, "ore_stock": 3, "net_profit_cents": 15000},
			"otto": {"name": "量子投机财团", "strategy": "囤积矿石，擅长利用价格波动", "cash_cents": 200000, "ore_stock": 5, "net_profit_cents": 10000}
		}
	return tycoon["rival_ledgers"]


static func tick_v10_economy(state: GameState) -> Dictionary:
	var report: Dictionary = {"storage_fee_cents": 0, "ai_dump_msg": ""}
	if state == null or state.season_ended:
		return report
	ensure_rival_ledgers(state)
	var tycoon: Dictionary = state.stats["tycoon"]
	var ledgers: Dictionary = tycoon["rival_ledgers"]
	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var has_storage_tech: bool = TechTree.is_unlocked(unlocked, "automated_logistics")

	# 1. 玩家囤货仓储成本 (V1.0 第 2.4 节：暂时囤货等待高价，但承担仓储成本)
	var stored_boxes: int = state.port_total()
	if stored_boxes > 0:
		var fee_per_box: int = 100 if has_storage_tech else 250 # $1.00 or $2.50 per box per tick
		var fee: int = stored_boxes * fee_per_box
		state.cash_cents = maxi(0, state.cash_cents - fee)
		state.stats["expenses"]["silo"] = int(state.stats["expenses"]["silo"]) + fee
		report["storage_fee_cents"] = fee

	# 2. 三家 AI 财团受到同样的资金、仓储与运力约束进行生产与抛售
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(state.sector_seed * 41 + state.current_tick * 193)
	var lb: Dictionary = tycoon["left_buyer"]
	var rb: Dictionary = tycoon["right_buyer"]

	for r_id in ["rex", "victoria", "otto"]:
		var r_data: Dictionary = ledgers[r_id]
		var mined: int = rng.randi_range(1, 2)
		var transport_cost: int = 3500 if r_id == "victoria" else 5000
		r_data["ore_stock"] = mini(18, int(r_data["ore_stock"]) + mined)
		r_data["cash_cents"] = maxi(10000, int(r_data["cash_cents"]) - transport_cost)

		# 投机财团 (otto) 只在价格高企时集中抛售，并压低市场价！
		var best_m_price: int = maxi(int(lb["metal_price"]), int(rb["metal_price"]))
		var should_sell: bool = (r_id != "otto" and int(r_data["ore_stock"]) >= 4) or (r_id == "otto" and (best_m_price >= 12500 or int(r_data["ore_stock"]) >= 12))
		if should_sell and int(r_data["ore_stock"]) > 0:
			var sold_qty: int = int(r_data["ore_stock"])
			var rev: int = sold_qty * best_m_price
			r_data["ore_stock"] = 0
			r_data["cash_cents"] = int(r_data["cash_cents"]) + rev
			r_data["net_profit_cents"] = int(r_data["net_profit_cents"]) + rev - sold_qty * 4200
			if r_id == "otto" and sold_qty >= 5:
				lb["metal_price"] = maxi(7200, int(lb["metal_price"]) - 1400)
				rb["crystal_price"] = maxi(19500, int(rb["crystal_price"]) - 2600)
				report["ai_dump_msg"] = "【市场波动】量子投机财团逢高抛售 %d 箱囤矿，采购商报价受供需影响回落！" % sold_qty
				tycoon["rival_activity"] = report["ai_dump_msg"]
	return report


## 🚀 V1.0 第 2.3 节：返回三类核心火箭（轻型一次性火箭 / 可回收火箭 / 重型星舰）的清晰参数与派遣状态
static func get_v10_three_rockets(state: GameState, star_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if state == null or not state.stars.has(star_id):
		return results
	var star: Dictionary = state.stars[star_id]
	var pending_miner: bool = false
	for ship in state.ships:
		if str(ship.get("state", "")) == "outbound" and str(ship.get("star_id", "")) == star_id and bool(ship.get("deliver_miner", false)):
			pending_miner = true
			break
	var public_res: Dictionary = state.public_reserve(star)
	var has_reserve: bool = (not bool(public_res["exact"])) or int(public_res["max"]) > 0
	var wants_miner: bool = (not bool(star["has_miner"])) and (not pending_miner) and has_reserve

	var unlocked: Array = state.stats.get("unlocked_techs", [])
	var has_aero: bool = TechTree.is_unlocked(unlocked, "aerospike_engine")
	var has_heavy: bool = TechTree.is_unlocked(unlocked, "starship_heavy")

	var specs: Array[Dictionary] = [
		{
			"key": "light",
			"title": "① 轻型一次性火箭",
			"mode": "light",
			"reusable": false,
			"capacity": 4,
			"reliability": "一次性消耗",
			"desc": "便宜、运力小、无法回收 · 适合初期快速投产或救急"
		},
		{
			"key": "reuse",
			"title": "② 猎鹰可回收火箭",
			"mode": "medium_reuse",
			"reusable": true,
			"capacity": 6,
			"reliability": "98%" if has_aero else "94%",
			"desc": "购置较高、可多次复用 · 显著降低中长期单趟运输成本"
		},
		{
			"key": "heavy",
			"title": "③ 重型星舰 (Starship)",
			"mode": "heavy_reuse",
			"reusable": true,
			"capacity": 10,
			"reliability": "99%" if has_aero else "96%",
			"desc": "载货量大、前期投入高 · 适合远距离大规模矿业经营"
		}
	]

	for sp in specs:
		var mode: String = str(sp["mode"])
		if mode == "heavy_reuse" and not has_heavy:
			results.append({
				"key": str(sp["key"]),
				"title": str(sp["title"]),
				"locked": true,
				"summary": "运力 10 箱 | 需在【科技升级 -> 航天科技】中解锁重型星舰 ($280)",
				"button_text": "🔒 需解锁航天科技",
				"ok": false
			})
			continue

		# 查找是否已有待命的同型可回收火箭
		var idle_ship_id: int = 0
		if bool(sp["reusable"]):
			for s in state.ships:
				if str(s.get("mode", "")) == mode and str(s.get("state", "")) == "idle":
					idle_ship_id = int(s["id"])
					break

		var req: Dictionary = {
			"mode": mode,
			"owned_ship_id": idle_ship_id,
			"star_id": star_id,
			"miner": wants_miner,
			"silo": false,
			"cargo": int(sp["capacity"])
		}
		var max_c: int = MissionRules.max_feasible_cargo(state, req)
		if max_c < 0 and wants_miner and int(star["stock"]) > 0:
			req["miner"] = false
			max_c = MissionRules.max_feasible_cargo(state, req)
		if max_c >= 0:
			req["cargo"] = max_c
		var quote: Dictionary = MissionRules.quote_mission(state, req, false)
		var is_ok: bool = bool(quote.get("ok", false)) and max_c >= 0
		var total_c: int = int(quote.get("total_cents", 15000))
		var travel_days: float = float(int(quote.get("travel_ticks", 2)))
		var miner_tag: String = "+带钻机" if bool(req["miner"]) else ""

		var btn_label: String = ""
		if idle_ship_id > 0:
			btn_label = "♻ 复飞#%d%s (%s · 装%d箱)" % [idle_ship_id, miner_tag, MissionRules.money(total_c), maxi(0, max_c)]
		else:
			btn_label = "🚀 购置并发射%s (%s · 装%d箱)" % [miner_tag, MissionRules.money(total_c), maxi(0, max_c)]

		var param_line: String = "运力: %d箱  |  往返: %.0f日  |  本趟成本: %s  |  可靠性: %s" % [
			maxi(0, max_c), travel_days, MissionRules.money(total_c), str(sp["reliability"])
		]
		results.append({
			"key": str(sp["key"]),
			"title": str(sp["title"]),
			"locked": false,
			"ok": is_ok,
			"request": req,
			"quote": quote,
			"summary": param_line,
			"button_text": btn_label,
			"error": "资金或机库席位不足（需 %s）" % MissionRules.money(total_c) if not is_ok else ""
		})
	return results
