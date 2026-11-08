extends "res://scripts/ui/ux_screen.gd"
const UI = preload("res://scripts/ui/design_system.gd")
const PartTile = preload("res://scripts/features/assembly/presentation/part_tile.gd")
const DropSlot = preload("res://scripts/features/assembly/presentation/drop_slot.gd")
const Catalog = preload("res://scripts/features/assembly/assembly_catalog.gd")
var chosen_part: Dictionary = {}

func build() -> void:
	var base := UI.column(13)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	base.add_child(UI.title("火箭装配车间", "把左侧组件拖到中央对应插槽，自动吸附；也支持点击组件再点插槽。配置可以复用，不必每次运输重新组装。"))
	var tabs := UI.row(10)
	base.add_child(tabs)
	tabs.add_child(UI.action("可回收轻型", do.bind("change_craft", {"craft":"可回收轻型火箭"}), session.craft == "可回收轻型火箭"))
	tabs.add_child(UI.action("一次性轻型", do.bind("change_craft", {"craft":"一次性轻型火箭"}), session.craft == "一次性轻型火箭"))
	tabs.add_child(UI.txt("当前蓝图  /  " + session.craft, 15, UI.AMBER))
	var r := UI.row(15)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(r)
	var left := UI.pane(UI.SURFACE, 16)
	left.custom_minimum_size.x = 295
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(left)
	var catalog := UI.column(11)
	left.add_child(catalog)
	catalog.add_child(UI.txt("组件仓库  /  拖动选配", 18, UI.TEXT))
	for entry in Catalog.PARTS:
		var tile: Button = PartTile.new()
		tile.set("slot_id", str(entry["slot"]))
		tile.set("part_name", str(entry["label"]))
		tile.text = "%s\n%s" % [str(entry["label"]), str(entry["stat"])]
		tile.custom_minimum_size.y = 54
		tile.add_theme_stylebox_override("normal", UI.skin(UI.SURFACE_HIGH, UI.STROKE, 5, 8))
		tile.pressed.connect(_choose.bind(str(entry["slot"]),str(entry["label"])))
		catalog.add_child(tile)
	var center := UI.pane(Color("0a1927"), 20)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.5
	r.add_child(center)
	var mount := UI.column(17)
	center.add_child(mount)
	mount.add_child(UI.txt("装配架  /  4 个模块化插槽", 17, UI.CYAN))
	for slot_id in Catalog.SLOTS:
		var target: Variant = DropSlot.new()
		target.set("slot_id", slot_id)
		target.custom_minimum_size.y = 76
		target.add_theme_stylebox_override("panel", UI.skin(Color("1c3546"), UI.CYAN if chosen_part.get("slot","") == slot_id else UI.STROKE, 6, 12))
		var content := UI.column(4)
		target.add_child(content)
		content.add_child(UI.txt(str(Catalog.LABELS[slot_id]), 12, UI.SUB))
		content.add_child(UI.txt(str(session.rocket_parts.get(slot_id,"空槽")), 18, UI.TEXT))
		target.part_dropped.connect(_install)
		target.slot_clicked.connect(_slot_clicked)
		mount.add_child(target)
	var right := UI.pane(UI.SURFACE, 16)
	right.custom_minimum_size.x = 275
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(right)
	var metrics := UI.column(12)
	right.add_child(metrics)
	metrics.add_child(UI.txt("设计评估", 18, UI.TEXT))
	metrics.add_child(UI.separator())
	metrics.add_child(UI.txt("方案：" + session.craft, 15, UI.CYAN))
	metrics.add_child(UI.txt("发动机：" + str(session.rocket_parts["engine"]), 13, UI.SUB))
	metrics.add_child(UI.txt("航程：" + ("提升" if session.rocket_parts["fuel"] == "扩展燃料舱" else "标准"), 14, UI.TEXT))
	metrics.add_child(UI.txt("有效载重：" + ("提升" if session.rocket_parts["cargo"] == "大型货舱" else "标准"), 14, UI.TEXT))
	metrics.add_child(UI.txt("回收：" + ("可复用" if session.craft == "可回收轻型火箭" else "一次性"), 14, UI.AMBER))
	metrics.add_child(UI.separator())
	metrics.add_child(UI.txt("仅为 UX 配置预览；真实质量、航程、价格计算在 Balance/M1 阶段接入。", 12, UI.SUB))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	metrics.add_child(spacer)
	metrics.add_child(UI.action("采用该蓝图并返回矿区 →", go.bind("expedition"), true))

func _choose(slot_id: String, part_name: String) -> void:
	chosen_part = {"slot":slot_id, "part":part_name}
	render()

func _slot_clicked(slot_id: String) -> void:
	if str(chosen_part.get("slot", "")) == slot_id:
		_install(slot_id,str(chosen_part.get("part", "")))

func _install(slot_id: String, part_name: String) -> void:
	chosen_part = {}
	do("mount_part", {"slot":slot_id, "part":part_name})
