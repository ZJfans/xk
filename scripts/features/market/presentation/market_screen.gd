extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")
const Graph = preload("res://scripts/features/market/presentation/market_graph.gd")

func build() -> void:
	var base := UI.column(15)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("矿石交易中心", "只有两家报价和一个明确的库存选择：立即卖出，或等候更好价格。"))
	var summary := UI.row(12)
	base.add_child(summary)
	summary.add_child(UI.metric("可售矿石", "%d t" % session.delivered_t, UI.GREEN))
	summary.add_child(UI.metric("累计销售", "%d t" % session.sold_t))
	summary.add_child(UI.metric("累计营收", "%d Cr" % session.revenue, UI.AMBER))
	var content := UI.row(18)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(content)
	var chart_card := UI.pane(UI.SURFACE, 16)
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_card.size_flags_stretch_ratio = 2.0
	content.add_child(chart_card)
	var v := UI.column(13)
	chart_card.add_child(v)
	v.add_child(UI.txt("市场走势与仓储决策", 19, UI.TEXT))
	var chart: Control = Graph.new()
	chart.custom_minimum_size.y = 290
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(chart)
	v.add_child(UI.txt("操作提示：高价并不一定总在远方；正式版需要考虑运费、收购配额与等待成本。", 14, UI.SUB))
	var offers := UI.column(12)
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(offers)
	for buyer in [
		{"name":"晨曦交易所","price":200,"desc":"低价稳定 · 港口近"},
		{"name":"赤曜工业联盟","price":240,"desc":"高价订单 · 市场波动"}
	]:
		var card := UI.pane(UI.SURFACE, 17)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		offers.add_child(card)
		var c := UI.column(15)
		card.add_child(c)
		c.add_child(UI.txt(str(buyer["name"]), 19, UI.TEXT))
		c.add_child(UI.txt(str(buyer["desc"]), 13, UI.SUB))
		c.add_child(UI.txt("%s Cr / t" % str(buyer["price"]), 27, UI.CYAN if str(buyer["name"]) == "晨曦交易所" else UI.AMBER))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.add_child(spacer)
		c.add_child(UI.txt("预计收入  %d Cr" % (session.delivered_t * int(buyer["price"])), 15, UI.GREEN))
		c.add_child(UI.action("出售全部可售库存", do.bind("sell",{"buyer":buyer["name"]}), session.delivered_t > 0, 0, session.delivered_t > 0))
	var foot := UI.row(12)
	base.add_child(foot)
	foot.add_child(UI.action("← 返回采矿场景", go.bind("expedition")))
	foot.add_child(UI.txt("囤货：当前演示中可暂不出售；自动时间/价格波动未接入", 13, UI.SUB))
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer2)
	foot.add_child(UI.action("查看本轮结算 →", go.bind("settlement"), true))
