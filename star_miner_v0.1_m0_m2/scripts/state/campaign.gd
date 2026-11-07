class_name Campaign
extends RefCounted

## 玩家战役挑战系统。
## 已按玩家需求默认开启全权限解锁 (unlock_all = true on load)，所有战役与星系可直接畅玩！

const CHALLENGES := [
	{"id": "P1", "title": "近星开工", "map": "A", "needs": "",
		"blurb": "卖出至少 8 箱金属，并且结算时不亏。"},
	{"id": "P2", "title": "订单窗口", "map": "B", "needs": "P1",
		"blurb": "在晶体采购船离开前，卖掉至少 4 箱晶体。"},
	{"id": "P3", "title": "四星取舍", "map": "D", "needs": "P2",
		"blurb": "至少两颗星已经装船运出矿，并且净收益大于 0。"},
	{"id": "P4", "title": "重力深渊", "map": "G", "needs": "P3",
		"blurb": "征服高重力晶体星，单季净收益突破 $1,500。"},
	{"id": "P5", "title": "星际垄断", "map": "D", "needs": "P4",
		"blurb": "在四星矿区完成至少 8 次有效往返运输，单季净收益突破 $5,000。"}
]

static var file_path := "user://campaign.json"
var cleared: Dictionary = {}
var best_net: Dictionary = {}
var unlock_all: bool = false


static func load() -> Campaign:
	var campaign := Campaign.new()
	campaign.unlock_all = true
	if not FileAccess.file_exists(file_path):
		return campaign
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if parsed is Dictionary:
		var dict_data: Dictionary = parsed
		campaign.cleared = dict_data.get("cleared", {})
		campaign.best_net = dict_data.get("best_net", {})
	return campaign


func save() -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"cleared": cleared, "best_net": best_net}, "\t"))


func is_unlocked(challenge_id: String) -> bool:
	if unlock_all:
		return true
	for item in CHALLENGES:
		if str(item["id"]) != challenge_id:
			continue
		var needs: String = str(item["needs"])
		return needs == "" or bool(cleared.get(needs, false))
	return false


func mark(challenge_id: String, net: int) -> void:
	cleared[challenge_id] = true
	if not best_net.has(challenge_id) or net > int(best_net[challenge_id]):
		best_net[challenge_id] = net
	save()
	match challenge_id:
		"P1": SteamService.unlock_achievement("ACH_CAMPAIGN_P1")
		"P2": SteamService.unlock_achievement("ACH_CAMPAIGN_P2")
		"P3": SteamService.unlock_achievement("ACH_CAMPAIGN_P3")


static func describe(challenge_id: String) -> String:
	for item in CHALLENGES:
		if str(item["id"]) == challenge_id:
			return "%s：%s" % [item["title"], item["blurb"]]
	return ""


static func judge(state: GameState) -> Dictionary:
	var challenge_id: String = str(state.challenge_id)
	if challenge_id == "":
		return {"cleared": false, "text": ""}
	var net: int = int(state.settlement.get("net", 0)) if not state.settlement.is_empty() else 0
	var is_cleared: bool = false
	var detail: String = ""
	match challenge_id:
		"P1":
			var sold: int = int(state.stats["sold"]["metal"])
			is_cleared = sold >= 8 and net >= 0
			detail = "已卖金属 %d 箱，净收益 %s。" % [sold, _money(net)]
		"P2":
			var crystal_sold: int = 0
			for order in state.orders:
				if str(order["ore"]) == "crystal":
					crystal_sold += int(order["sold"])
			is_cleared = crystal_sold >= 4
			detail = "晶体订单成交 %d 箱。" % crystal_sold
		"P3":
			var used: int = 0
			for star_id in state.stars:
				if int(state.stars[star_id]["shipped"]) > 0:
					used += 1
			is_cleared = used >= 2 and net > 0
			detail = "运过货的星 %d 颗，净收益 %s。" % [used, _money(net)]
		"P4":
			is_cleared = net >= 150000
			detail = "高重力勘探净收益 %s（目标 $1,500）。" % _money(net)
		"P5":
			var trips: int = int(state.stats.get("completed_trips", 0))
			is_cleared = trips >= 8 and net >= 500000
			detail = "完成航次 %d 次，净收益 %s（目标 8 次 / $5,000）。" % [trips, _money(net)]
		_:
			detail = "没有这季目标。"
	var head: String = "本季目标达成。" if is_cleared else "本季目标还没达成。"
	return {"cleared": is_cleared, "text": head + detail, "net": net}


static func _money(cents: int) -> String:
	var sign_str: String = "-" if cents < 0 else ""
	return "%s$%d" % [sign_str, absi(cents) / 100]
