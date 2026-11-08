class_name UXSession
extends RefCounted
## DEMO ONLY: finite, deterministic presentation fixture; not the V4 economy engine.
## Replace this adapter with the authoritative Frontier command service at M1.
const START_CREDITS := 40000
const Contracts = preload("res://scripts/contracts/frontier_contracts.gd")
const Catalog = preload("res://scripts/features/assembly/assembly_catalog.gd")
var cash: int = START_CREDITS
var chosen_lot: String = ""
var surveyed: bool = false
var surveyed_body: String = ""
var deployed: bool = false
var deployed_body: String = ""
var mined_t: int = 0
var delivered_t: int = 0
var sold_t: int = 0
var revenue: int = 0
var expenses: int = 0
var craft: String = "可回收轻型火箭"
var rocket_parts: Dictionary = {"engine": "标准引擎", "fuel": "标准燃料舱", "cargo": "基础货舱", "recovery": "回收支架"}
var selected_body: String = "A-03"
var audit: Array[String] = []

func objective() -> String:
	if chosen_lot == "": return "下一步：竞拍第一处星域采矿权"
	if not surveyed: return "下一步：选择天体，拖动探测器进行扫描"
	if not deployed: return "下一步：在已扫描的天体部署采矿设备"
	if delivered_t <= 0 and sold_t == 0: return "下一步：发射运输火箭，把矿石运回港口"
	if sold_t <= 0: return "下一步：比较两家收购商报价并出售"
	return "首轮核心操作已完成，可以查看结算"

func apply(action_id: String, payload: Dictionary = {}) -> Dictionary:
	if not Contracts.is_known_action(action_id):
		return _err("未知演示命令：" + action_id)
	match action_id:
		"win_lot":
			if chosen_lot != "": return _err("本轮已经取得一处采矿权")
			var price: int = int(payload.get("price", 7600))
			if price < 0 or cash < price: return _err("资金不足，无法获得采矿权")
			chosen_lot = str(payload.get("lot", "F-01"))
			_spend(price)
			return _ok("竞拍成功：获得 %s 的经营许可" % chosen_lot, "expedition")
		"scan":
			if chosen_lot == "": return _err("需要先取得采矿权")
			if surveyed: return _err("本轮已有扫描数据")
			if cash < 500: return _err("扫描资金不足")
			selected_body = str(payload.get("body", selected_body))
			_spend(500)
			surveyed = true
			surveyed_body = selected_body
			return _ok("完成扫描：%s 发现晶硅矿和铁钛矿" % selected_body)
		"deploy":
			if not surveyed: return _err("请先扫描天体")
			if str(payload.get("body", selected_body)) != surveyed_body:
				return _err("请先切回已扫描的 %s" % surveyed_body)
			if deployed: return _err("本轮已部署示范采矿舱")
			if cash < 3200: return _err("采矿设备预算不足")
			_spend(3200)
			deployed = true
			deployed_body = surveyed_body
			mined_t += 80 # UX fixture: does not model continuous production.
			return _ok("采矿舱部署完毕，示范产出 80 t")
		"dispatch":
			if not deployed or mined_t <= 0: return _err("需要先部署采矿设备并获取矿石")
			if str(payload.get("body", deployed_body)) != deployed_body:
				return _err("请先选择有库存的矿区：%s" % deployed_body)
			var fee: int = 800 if craft == "可回收轻型火箭" else 2300
			if cash < fee: return _err("发射资金不足")
			_spend(fee)
			delivered_t += mined_t
			mined_t = 0
			return _ok("运输完成：矿石已到达贸易港（演示数据）", "market")
		"sell":
			if delivered_t <= 0: return _err("贸易港还没有可出售的矿石")
			var buyer: String = str(payload.get("buyer", "晨曦交易所"))
			var price_per_t: int = 200 if buyer == "晨曦交易所" else 240
			var t: int = delivered_t
			revenue += t * price_per_t
			cash += t * price_per_t
			sold_t += t
			delivered_t = 0
			return _ok("向 %s 出售 %d t，收入 %d Cr" % [buyer, t, t * price_per_t])
		"change_craft":
			var next_craft: String = str(payload.get("craft", ""))
			if next_craft not in ["可回收轻型火箭", "一次性轻型火箭"]: return _err("未知火箭方案")
			craft = next_craft
			rocket_parts["recovery"] = "回收支架" if craft == "可回收轻型火箭" else "简化尾舱"
			return _ok("启用装配蓝图：%s" % craft)
		"mount_part":
			var slot: String = str(payload.get("slot", ""))
			var part: String = str(payload.get("part", ""))
			if slot not in rocket_parts: return _err("未知装配插槽")
			if not Catalog.valid_part_for_craft(craft, slot, part):
				return _err("该组件不适用于 %s 的 %s 插槽" % [craft, slot])
			rocket_parts[slot] = part
			return _ok("%s 已安装到 %s 插槽（UX 演示）" % [part, slot])
		"reset_round":
			chosen_lot = ""
			surveyed = false
			surveyed_body = ""
			deployed = false
			deployed_body = ""
			mined_t = 0
			delivered_t = 0
			sold_t = 0
			revenue = 0
			expenses = 0
			return _ok("开始新一轮演示（长期成长尚未接入）", "hq")
	return _err("未知演示命令：" + action_id)

func _spend(value: int) -> void:
	cash -= value
	expenses += value

func _ok(message: String, route: String = "") -> Dictionary:
	audit.append("OK: " + message)
	return {"ok": true, "message": message, "route": route}

func _err(message: String) -> Dictionary:
	audit.append("ERR: " + message)
	return {"ok": false, "message": message, "route": ""}
