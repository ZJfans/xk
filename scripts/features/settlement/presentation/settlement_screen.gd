extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")

func build() -> void:
	var base := UI.column(16)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("本轮经营结算", "一次完整的决策反馈：收入、投入、结果和下一轮可改进的方向。"))
	var summary := UI.row(14)
	base.add_child(summary)
	summary.add_child(UI.metric("矿石营收", "%d Cr" % session.revenue, UI.GREEN))
	summary.add_child(UI.metric("综合投入", "%d Cr" % session.expenses, UI.AMBER))
	summary.add_child(UI.metric("本轮现金利润", "%d Cr" % (session.revenue-session.expenses), UI.CYAN))
	var r := UI.row(16)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(r)
	var main := UI.pane(UI.SURFACE, 20)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 2.0
	r.add_child(main)
	var v := UI.column(16)
	main.add_child(v)
	v.add_child(UI.txt("经营回顾  /  第一轮", 21, UI.TEXT))
	v.add_child(UI.separator())
	for item in [
		["获得经营权", session.chosen_lot if session.chosen_lot != "" else "未取得"],
		["扫描天体", "已完成" if session.surveyed else "未完成"],
		["建成采矿设备", "已完成" if session.deployed else "未完成"],
		["矿石售出", "%d t" % session.sold_t],
		["剩余可售库存", "%d t" % session.delivered_t],
		["当前现金", "%d Cr" % session.cash]
	]:
		var line := UI.row()
		line.add_child(UI.txt(str(item[0]), 15, UI.SUB))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		line.add_child(UI.txt(str(item[1]), 15, UI.TEXT))
		v.add_child(line)
	var side := UI.pane(Color("132b39"), 21)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(side)
	var s := UI.column(18)
	side.add_child(s)
	s.add_child(UI.txt("下一轮应该改进什么？", 20, UI.AMBER))
	s.add_child(UI.txt("• 更早发现高价值矿体\n\n• 判断一次性与可回收火箭的盈亏临界点\n\n• 观察价格再出售，而不是总卖给同一家", 15, UI.TEXT))
	s.add_child(UI.separator())
	s.add_child(UI.txt("注意：这是 UX 演示报表。真实轮次结算、AI 排名、奖金与股权拍卖将在后续实现。", 13, UI.SUB))
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.add_child(spacer2)
	s.add_child(UI.action("返回总部 / 开始新轮 →", do.bind("reset_round",{}), true))
