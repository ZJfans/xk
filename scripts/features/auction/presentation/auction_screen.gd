extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")
const LOTS := [
	{"id":"F-01","name":"青岚碎星带","estimate":"富铁钛 · 勘探信心 65%","price":7600,"risk":"低风险"},
	{"id":"F-02","name":"赤曜外缘","estimate":"高价晶硅 · 勘探信心 42%","price":11200,"risk":"高波动"},
	{"id":"F-03","name":"霜环碎冰区","estimate":"富水冰 · 勘探信心 30%","price":5900,"risk":"低温环境"}
]
var selected_lot: String = "F-01"

func build() -> void:
	var base := UI.column(16)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("矿区经营权拍卖", "选择一块未知星域的经营权。信息有限，竞拍价格会影响进入矿区后的启动资金。"))
	var header := UI.row()
	base.add_child(header)
	header.add_child(UI.metric("本轮竞拍资金", "%d Cr" % session.cash, UI.GREEN))
	header.add_child(UI.metric("参与财团", "3 家", UI.CYAN))
	header.add_child(UI.metric("拍卖标的", "3 处", UI.AMBER))
	var grid := UI.row(16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(grid)
	for lot in LOTS:
		var id: String = str(lot["id"])
		var card := UI.pane(Color("173346") if selected_lot == id else UI.SURFACE, 18)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var col := UI.column(15)
		card.add_child(col)
		col.add_child(UI.txt("◆ 采矿扇区  " + id, 14, UI.CYAN))
		col.add_child(UI.txt(str(lot["name"]), 24, UI.TEXT))
		col.add_child(UI.separator())
		col.add_child(UI.txt(str(lot["estimate"]), 15, UI.SUB))
		col.add_child(UI.txt("地形风险：" + str(lot["risk"]), 14, UI.SUB))
		col.add_child(UI.txt("标价  %s Cr" % str(lot["price"]), 22, UI.AMBER))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		var select_btn := UI.action("选中该矿区" if selected_lot != id else "已选中 · 查看右下方", _select.bind(id), selected_lot == id)
		col.add_child(select_btn)
	var panel := UI.pane(Color("111d2a"), 13)
	base.add_child(panel)
	var r := UI.row()
	panel.add_child(r)
	r.add_child(UI.txt("当前选择：%s    /    注意：演示采用固定成交价；实时竞价 AI 尚未接入" % selected_lot, 15, UI.TEXT))
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(spacer2)
	r.add_child(UI.action("返回总部", go.bind("hq")))
	r.add_child(UI.action("确认竞拍并进入星域  →", _buy, session.chosen_lot == "", 210, session.chosen_lot == ""))

func _select(id: String) -> void:
	selected_lot = id
	render()

func _buy() -> void:
	for lot in LOTS:
		if str(lot["id"]) == selected_lot:
			do("win_lot", {"lot": selected_lot, "price": int(lot["price"])})
			return
