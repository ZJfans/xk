extends RefCounted
## Single source of truth for UX prototype part/slot compatibility.
## M1 will replace text-only stats with balanced RocketBlueprint Resources.
const SLOTS := ["cargo", "fuel", "engine", "recovery"]
const LABELS := {
	"cargo": "货舱插槽", "fuel": "燃料插槽",
	"engine": "发动机插槽", "recovery": "回收组件"
}
const PARTS := [
	{"slot": "engine", "label": "标准引擎", "stat": "低价 · 适合近程"},
	{"slot": "engine", "label": "大推力引擎", "stat": "+ 推力 / + 成本"},
	{"slot": "fuel", "label": "标准燃料舱", "stat": "常规航程"},
	{"slot": "fuel", "label": "扩展燃料舱", "stat": "+ 航程 / - 载重"},
	{"slot": "cargo", "label": "基础货舱", "stat": "载荷稳定"},
	{"slot": "cargo", "label": "大型货舱", "stat": "+ 载荷 / + 自重"},
	{"slot": "recovery", "label": "回收支架", "stat": "可回收火箭专用"},
	{"slot": "recovery", "label": "简化尾舱", "stat": "一次性火箭专用"}
]

static func valid_part_for_slot(slot_id: String, part_name: String) -> bool:
	for item in PARTS:
		if str(item["slot"]) == slot_id and str(item["label"]) == part_name:
			return true
	return false

static func valid_part_for_craft(craft: String, slot_id: String, part_name: String) -> bool:
	if not valid_part_for_slot(slot_id, part_name):
		return false
	if slot_id == "recovery":
		return part_name == ("回收支架" if craft == "可回收轻型火箭" else "简化尾舱")
	return true
