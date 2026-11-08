extends SceneTree
const Session = preload("res://scripts/core/ux_session.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	var s = Session.new()
	check(s.cash == 40000, "initial balance")
	check(not bool(s.apply("scan", {}).get("ok", true)), "cannot scan without license")
	check(bool(s.apply("win_lot", {"lot":"F-01","price":7600}).get("ok", false)), "win lot")
	check(s.cash == 32400, "bid deducted once")
	check(not bool(s.apply("win_lot", {"lot":"F-02","price":7600}).get("ok", true)), "duplicate bid rejected")
	check(s.cash == 32400, "duplicate bid never charges")
	check(bool(s.apply("scan", {"body":"A-03"}).get("ok", false)), "scan")
	check(s.cash == 31900, "scan cost")
	check(not bool(s.apply("scan", {}).get("ok", true)), "duplicate scan rejected")
	check(s.cash == 31900, "duplicate scan never charges")
	check(not bool(s.apply("deploy", {"body":"B-07"}).get("ok", true)), "cannot deploy on unsurveyed body")
	check(s.cash == 31900, "invalid deployment must not charge")
	check(bool(s.apply("deploy", {"body":"A-03"}).get("ok", false)), "deploy")
	check(s.mined_t == 80, "UX fixture production")
	check(bool(s.apply("dispatch", {}).get("ok", false)), "dispatch")
	check(s.mined_t == 0 and s.delivered_t == 80, "location inventory transferred")
	check(not bool(s.apply("dispatch", {"body":"A-03"}).get("ok", true)), "duplicate dispatch rejected")
	check(bool(s.apply("sell", {"buyer":"赤曜工业联盟"}).get("ok", false)), "sell")
	check(s.delivered_t == 0 and s.sold_t == 80, "no ghost inventory")
	check(s.revenue == 19200 and s.expenses == 12100 and s.cash == 47100, "correct demo ledger")
	check(not bool(s.apply("sell", {"buyer":"赤曜工业联盟"}).get("ok", true)), "double sale rejected")
	check(s.cash == 47100, "double sale never credits")
	check(not bool(s.apply("mount_part", {"slot":"cargo", "part":"大推力引擎"}).get("ok", true)), "wrong slot rejected")
	check(not bool(s.apply("mount_part", {"slot":"recovery", "part":"简化尾舱"}).get("ok", true)), "wrong craft recovery rejected")
	check(bool(s.apply("change_craft", {"craft":"一次性轻型火箭"}).get("ok", false)), "change to expendable")
	check(s.rocket_parts["recovery"] == "简化尾舱", "expendable tail synchronized")
	check(bool(s.apply("mount_part", {"slot":"fuel", "part":"扩展燃料舱"}).get("ok", false)), "valid slot accepted")
	check(bool(s.apply("reset_round", {}).get("ok", false)), "new mock round")
	check(s.cash == 47100 and s.chosen_lot == "", "reset keeps cash but resets round")
	if failures.is_empty():
		print("PASS: UX mock round and idempotence smoke checks")
		quit(0)
	else:
		printerr("FAILED: %d cases" % failures.size())
		quit(1)
