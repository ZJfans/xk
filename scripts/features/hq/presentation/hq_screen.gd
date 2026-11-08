extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")

func build() -> void:
	var base := UI.column(18)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("星际总部", "轮次之间的决策中心：升级、竞拍、融资与股份；这里只展示当前最重要的动作"))
	var hero := UI.pane(Color("142b3b"), 24)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(hero)
	var hero_row := UI.row(24)
	hero.add_child(hero_row)
	var info := UI.column(20)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(info)
	info.add_child(UI.txt("晨曦星域  /  拓荒者计划", 15, UI.CYAN))
	info.add_child(UI.txt("从一座发射基地，\n建立你的第一条矿业航线。", 37, UI.TEXT))
	info.add_child(UI.txt("先竞拍采矿权，再进入星域部署探测器与矿机。火箭和市场将在生产形成后派上用场。", 17, UI.SUB))
	var actions := UI.row(12)
	info.add_child(actions)
	actions.add_child(UI.action("开始矿区竞拍  →", go.bind("auction"), true, 200))
	actions.add_child(UI.action("参观装配车间", go.bind("assembly"), false, 170))
	var graphic := PanelContainer.new()
	graphic.custom_minimum_size = Vector2(300, 200)
	graphic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphic.add_theme_stylebox_override("panel", UI.skin(Color("0d1b28"), UI.STROKE, 8, 20))
	hero_row.add_child(graphic)
	var g := UI.column(15)
	graphic.add_child(g)
	g.add_child(UI.txt("◆ 轨道指挥网络", 15, UI.AMBER))
	g.add_child(UI.txt("01    探测未知星域", 18, UI.TEXT))
	g.add_child(UI.separator())
	g.add_child(UI.txt("02    建立采矿与运力", 18, UI.TEXT))
	g.add_child(UI.separator())
	g.add_child(UI.txt("03    交易 · 盈利 · 扩张", 18, UI.TEXT))
	base.add_child(UI.txt("总部设施  /  本阶段保留入口，详细功能按 GDD 分期实现", 15, UI.SUB))
	var tiles := UI.row(12)
	base.add_child(tiles)
	for item in [
		["矿区竞拍", "获取本轮经营权", "auction"],
		["科技与升级", "永久升级 · 后续里程碑", "hq"],
		["银行与情报", "贷款 / 交易 · 后续里程碑", "hq"],
		["公司股权", "长期战役目标 · 后续里程碑", "hq"]
	]:
		var card := UI.pane()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tiles.add_child(card)
		var v := UI.column(8)
		card.add_child(v)
		v.add_child(UI.txt(str(item[0]), 18, UI.AMBER))
		v.add_child(UI.txt(str(item[1]), 13, UI.SUB))
		if str(item[2]) == "auction":
			v.add_child(UI.action("进入 →", go.bind("auction")))
		else:
			v.add_child(UI.txt("规划中 · 暂无模拟操作", 12, UI.SUB))
