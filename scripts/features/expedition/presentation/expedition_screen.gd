extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")
const Field = preload("res://scripts/features/expedition/presentation/space_field.gd")
var selected_body: String = "A-03"

func build() -> void:
	var base := UI.column(13)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("太空采矿 · %s" % (session.chosen_lot if session.chosen_lot != "" else "未取得许可"), "场景为主、信息随选择出现；拖动左下角探测器到矿星，扫描后部署采矿舱。"))
	var r := UI.row(14)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(r)
	var view_pane := UI.pane(Color("071321"), 0)
	view_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_pane.size_flags_stretch_ratio = 3.0
	r.add_child(view_pane)
	var field: Variant = Field.new()
	field.custom_minimum_size = Vector2(560,400)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.set("selected_body", selected_body)
	field.set("surveyed", session.surveyed and session.surveyed_body == selected_body)
	field.set("deployed", session.deployed and session.deployed_body == selected_body)
	field.body_selected.connect(_select_body)
	field.probe_dropped.connect(_probe_drop)
	view_pane.add_child(field)
	var side := UI.pane(UI.SURFACE, 18)
	side.custom_minimum_size.x = 320
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(side)
	var panel := UI.column(14)
	side.add_child(panel)
	panel.add_child(UI.txt("当前目标  /  " + selected_body, 13, UI.CYAN))
	var target_name: String = selected_body
	for body_data in Field.BODIES:
		if str(body_data["id"]) == selected_body:
			target_name = str(body_data["t"])
			break
	panel.add_child(UI.txt(target_name + " · 候选矿点", 22, UI.TEXT))
	panel.add_child(UI.separator())
	panel.add_child(UI.txt("探测状态：" + ("已完成扫描" if session.surveyed and session.surveyed_body == selected_body else "未探测"), 14, UI.SUB))
	panel.add_child(UI.txt("采矿设备：" + ("正在工作" if session.deployed and session.deployed_body == selected_body else "尚未部署"), 14, UI.SUB))
	var visible_stock: int = session.mined_t if session.deployed_body == selected_body else 0
	panel.add_child(UI.txt("本目标矿石：%d t    港口：%d t" % [visible_stock, session.delivered_t], 14, UI.SUB))
	panel.add_child(UI.separator())
	panel.add_child(UI.txt("一键操作用于方便 UX 原型测试；正式版本优先通过场景拖拽部署。", 12, UI.SUB))
	panel.add_child(UI.action("1   发射探测器  ·  500 Cr", _scan, not session.surveyed, 0, not session.surveyed))
	var can_deploy: bool = session.surveyed and not session.deployed and selected_body == session.surveyed_body
	panel.add_child(UI.action("2   部署采矿舱  ·  3,200 Cr", _deploy, can_deploy, 0, can_deploy))
	var can_dispatch: bool = session.deployed and session.mined_t > 0 and selected_body == session.deployed_body
	panel.add_child(UI.action("3   发射运输火箭  →", _dispatch, can_dispatch, 0, can_dispatch))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(gap)
	panel.add_child(UI.txt("已配火箭：" + session.craft, 14, UI.AMBER))
	panel.add_child(UI.action("更换火箭方案 / 装配", go.bind("assembly")))
	var foot := UI.row(10)
	base.add_child(foot)
	foot.add_child(UI.metric("库存位置", "矿区 %d t" % session.mined_t))
	foot.add_child(UI.metric("装卸进度", "示范阶段", UI.AMBER))
	foot.add_child(UI.metric("贸易港库存", "%d t" % session.delivered_t, UI.GREEN))
	foot.add_child(UI.action("查看市场 →", go.bind("market")))

func _select_body(body_id: String) -> void:
	selected_body = body_id
	render()

func _probe_drop(body_id: String) -> void:
	selected_body = body_id
	do("scan", {"body": body_id})

func _scan() -> void:
	do("scan", {"body": selected_body})

func _deploy() -> void:
	do("deploy", {"body": selected_body})

func _dispatch() -> void:
	do("dispatch", {"body": selected_body})
