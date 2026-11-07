class_name SteamService
extends RefCounted

## Steamworks API 适配层与离线成就系统
## 为游戏在 Steam 正式发布提供原生接口封装，同时支持离线环境 Graceful Fallback。

const SAVE_PATH := "user://steam_stats.json"

static var is_steam_active: bool = false
static var app_id: int = 0
static var user_name: String = "Prospector"
static var achievements_cache: Dictionary = {}
static var stats_cache: Dictionary = {}

## 商业版 17 项核心成就定义表
const ACHIEVEMENTS := {
	"ACH_FIRST_LAUNCH": {
		"title_zh": "初次点火",
		"title_en": "First Ignition",
		"desc_zh": "配置并发射你的第一枚采矿火箭。",
		"desc_en": "Equip and launch your very first prospector rocket."
	},
	"ACH_FIRST_PROFIT": {
		"title_zh": "第一桶金",
		"title_en": "First Profit",
		"desc_zh": "成功将第一批开采矿石运回母港并变现。",
		"desc_en": "Safely return and sell your first batch of space ore."
	},
	"ACH_REUSABLE_PIONEER": {
		"title_zh": "复用先行者",
		"title_en": "Reusability Pioneer",
		"desc_zh": "成功完成一次中型复用火箭的往返与翻修作业。",
		"desc_en": "Complete a full return & refurbishment cycle with a reusable medium rocket."
	},
	"ACH_CRYSTAL_RUSH": {
		"title_zh": "晶体狂潮",
		"title_en": "Crystal Rush",
		"desc_zh": "单局售出至少 10 箱高价值晶体矿石。",
		"desc_en": "Sell at least 10 containers of precious crystals in a season."
	},
	"ACH_SPOTLESS_CONTRACTOR": {
		"title_zh": "金牌承包商",
		"title_en": "Spotless Contractor",
		"desc_zh": "100% 满额履约一次限时采购订单。",
		"desc_en": "100% fulfill a time-limited commercial purchase order."
	},
	"ACH_DEEP_SPACE_MINER": {
		"title_zh": "远征勘探",
		"title_en": "Deep Space Miner",
		"desc_zh": "从中距深空星体成功运回矿产。",
		"desc_en": "Successfully transport ore back from a mid-range celestial body."
	},
	"ACH_HIGH_G_SURVIVOR": {
		"title_zh": "重力征服者",
		"title_en": "High-G Conqueror",
		"desc_zh": "在高重力严酷星球成功采矿并运回母港。",
		"desc_en": "Successfully mine and return cargo from a high-gravity world."
	},
	"ACH_FULL_FLEET": {
		"title_zh": "航运大亨",
		"title_en": "Fleet Commander",
		"desc_zh": "同时调度满编 3 艘火箭执行任务。",
		"desc_en": "Operate a full fleet of 3 rockets simultaneously."
	},
	"ACH_PROSPECTING_RADAR": {
		"title_zh": "地质透视",
		"title_en": "Deep Scan",
		"desc_zh": "对未知星球成功执行一次远程地质勘探。",
		"desc_en": "Execute a remote orbital scan to unveil mysterious reserves."
	},
	"ACH_TECH_MASTER": {
		"title_zh": "首席总师",
		"title_en": "Chief Engineer",
		"desc_zh": "成功研发并突破一项航天前沿科技。",
		"desc_en": "Successfully research and unlock an aerospace breakthrough technology."
	},
	"ACH_DEBT_FREE_MAGNATE": {
		"title_zh": "财务自律",
		"title_en": "Debt-Free Magnate",
		"desc_zh": "在开采季结算时还清全部贷款，且净利润超过 $3,000。",
		"desc_en": "Finish a season completely debt-free with net profit exceeding $3,000."
	},
	"ACH_TEN_GRAND": {
		"title_zh": "星际垄断者",
		"title_en": "Ten Grand",
		"desc_zh": "单季净收益突破 $5,000。",
		"desc_en": "Surpass $5,000 in net seasonal profit."
	},
	"ACH_ZERO_VENTING": {
		"title_zh": "精准调度",
		"title_en": "Zero Waste",
		"desc_zh": "单季完成至少 5 趟运输，且没有浪费任何返程燃料配额。",
		"desc_en": "Complete at least 5 round-trips with zero vented return fuel."
	},
	"ACH_CAMPAIGN_P1": {
		"title_zh": "近星起航",
		"title_en": "Near Orbit Pioneer",
		"desc_zh": "通关战役第一季：近星开工。",
		"desc_en": "Clear Campaign Season 1: Near Orbit."
	},
	"ACH_CAMPAIGN_P2": {
		"title_zh": "订单主宰",
		"title_en": "Contract Master",
		"desc_zh": "通关战役第二季：订单窗口。",
		"desc_en": "Clear Campaign Season 2: Order Window."
	},
	"ACH_CAMPAIGN_P3": {
		"title_zh": "群星交响",
		"title_en": "Cosmic Symphony",
		"desc_zh": "通关战役第三季：四星取舍。",
		"desc_en": "Clear Campaign Season 3: Four Worlds."
	},
	"ACH_ENDLESS_EXPLORER": {
		"title_zh": "永无止境",
		"title_en": "Endless Frontier",
		"desc_zh": "在无尽沙盒模式中持续开拓超过 80 个半日周期（Day 40+）。",
		"desc_en": "Survive and prosper over 80 ticks (Day 40+) in Endless Mode."
	}
}

static func init_steam(target_app_id: int = 480) -> bool:
	app_id = target_app_id
	_load_local_data()
	if Engine.has_singleton("Steam"):
		var steam_singleton = Engine.get_singleton("Steam")
		var init_result = steam_singleton.steamInit()
		if init_result is Dictionary and int(init_result.get("status", 0)) == 1:
			is_steam_active = true
			user_name = str(steam_singleton.getPersonaName())
			return true
	is_steam_active = false
	return false

static func unlock_achievement(ach_id: String) -> bool:
	_load_local_data()
	if not ACHIEVEMENTS.has(ach_id):
		return false
	if bool(achievements_cache.get(ach_id, false)):
		return false
	achievements_cache[ach_id] = true
	_save_local_data()
	if is_steam_active and Engine.has_singleton("Steam"):
		var steam_singleton = Engine.get_singleton("Steam")
		steam_singleton.setAchievement(ach_id)
		steam_singleton.storeStats()
	return true

static func is_unlocked(ach_id: String) -> bool:
	if achievements_cache.is_empty():
		_load_local_data()
	return bool(achievements_cache.get(ach_id, false))

static func unlocked_count() -> int:
	if achievements_cache.is_empty():
		_load_local_data()
	var count := 0
	for k in ACHIEVEMENTS:
		if bool(achievements_cache.get(k, false)):
			count += 1
	return count

static func total_count() -> int:
	return ACHIEVEMENTS.size()

static func check_gameplay_achievements(state: GameState) -> Array[String]:
	var newly_unlocked: Array[String] = []
	if state.ships.size() > 0 or int(state.stats.get("completed_trips", 0)) > 0:
		if unlock_achievement("ACH_FIRST_LAUNCH"):
			newly_unlocked.append("ACH_FIRST_LAUNCH")
	
	var sold_metal: int = int(state.stats.get("sold", {}).get("metal", 0))
	var sold_crystal: int = int(state.stats.get("sold", {}).get("crystal", 0))
	if sold_metal > 0 or sold_crystal > 0:
		if unlock_achievement("ACH_FIRST_PROFIT"):
			newly_unlocked.append("ACH_FIRST_PROFIT")
	
	if sold_crystal >= 10:
		if unlock_achievement("ACH_CRYSTAL_RUSH"):
			newly_unlocked.append("ACH_CRYSTAL_RUSH")
			
	var trips_by_mode: Dictionary = state.stats.get("trips_by_mode", {})
	if int(trips_by_mode.get("medium_reuse", 0)) >= 1:
		if unlock_achievement("ACH_REUSABLE_PIONEER"):
			newly_unlocked.append("ACH_REUSABLE_PIONEER")
			
	if state.ships.size() >= 3:
		if unlock_achievement("ACH_FULL_FLEET"):
			newly_unlocked.append("ACH_FULL_FLEET")
			
	for order in state.orders:
		if int(order.get("quantity", 0)) > 0 and int(order.get("sold", 0)) >= int(order.get("quantity", 0)):
			if unlock_achievement("ACH_SPOTLESS_CONTRACTOR"):
				newly_unlocked.append("ACH_SPOTLESS_CONTRACTOR")
			
	for star_id in state.stars:
		var s: Dictionary = state.stars[star_id]
		if int(s.get("shipped", 0)) > 0:
			if str(s.get("route", "")) == "mid":
				if unlock_achievement("ACH_DEEP_SPACE_MINER"):
					newly_unlocked.append("ACH_DEEP_SPACE_MINER")
			if str(s.get("environment", "")) == "high_g":
				if unlock_achievement("ACH_HIGH_G_SURVIVOR"):
					newly_unlocked.append("ACH_HIGH_G_SURVIVOR")
					
	if state.endless_mode and state.current_tick >= 80:
		if unlock_achievement("ACH_ENDLESS_EXPLORER"):
			newly_unlocked.append("ACH_ENDLESS_EXPLORER")
					
	if state.season_ended and not state.settlement.is_empty():
		var net: int = int(state.settlement.get("net", 0))
		var principal: int = int(state.settlement.get("principal", 0))
		if principal == 0 and net >= 300000:
			if unlock_achievement("ACH_DEBT_FREE_MAGNATE"):
				newly_unlocked.append("ACH_DEBT_FREE_MAGNATE")
		if net >= 500000:
			if unlock_achievement("ACH_TEN_GRAND"):
				newly_unlocked.append("ACH_TEN_GRAND")
		var completed_trips: int = int(state.stats.get("completed_trips", 0))
		var vented: int = int(state.stats.get("fuel_vented", 0))
		if completed_trips >= 5 and vented == 0:
			if unlock_achievement("ACH_ZERO_VENTING"):
				newly_unlocked.append("ACH_ZERO_VENTING")
	return newly_unlocked

static func _load_local_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		achievements_cache = parsed.get("achievements", {})
		stats_cache = parsed.get("stats", {})

static func _save_local_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		var data := {
			"achievements": achievements_cache,
			"stats": stats_cache
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
