class_name SaveService
extends RefCounted

## 正式档在 user://。测试把 folder 指到别的目录，避免碰玩家存档。
## v3.0 旗舰版新增：
## 1. 跨航季永久生涯档案 (career_profile.json)：永久保存【8大航天科技树】、【地球星舰母港股权%】、【火星阿瑞斯星城殖民阶段 (1~5)】！
## 2. 三槽位独立存档管理 (slot_1 / slot_2 / slot_3)：支持多档位随时保存与读取。
static var folder := "user://"

static func save_game(state: GameState) -> Dictionary:
	save_career_progress(state)
	return _write_safely(_file("season_save.json"), _file("season_save.tmp"), _file("season_save.backup.json"), JSON.stringify(state.to_dict(), "\t"))

static func load_game() -> Dictionary:
	var path: String = _file("season_save.json")
	if not FileAccess.file_exists(path) and FileAccess.file_exists(_file("season_save.backup.json")):
		path = _file("season_save.backup.json")
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "还没有进行中的存档。"}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		return {"ok": false, "error": "存档无法读取，请检查本地备份。"}
	var state := GameState.new()
	var result: Dictionary = state.load_dict(raw)
	if not result.get("ok", false):
		return result
	return {"ok": true, "state": state}

static func save_slot(slot_idx: int, state: GameState) -> Dictionary:
	var s_id: int = clampi(slot_idx, 1, 3)
	save_career_progress(state)
	var base_name: String = "season_slot_%d" % s_id
	return _write_safely(_file(base_name + ".json"), _file(base_name + ".tmp"), _file(base_name + ".bak.json"), JSON.stringify(state.to_dict(), "\t"))

static func load_slot(slot_idx: int) -> Dictionary:
	var s_id: int = clampi(slot_idx, 1, 3)
	var path: String = _file("season_slot_%d.json" % s_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "存档槽位 #%d 尚无记录。" % s_id}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		return {"ok": false, "error": "存档槽位 #%d 数据损坏。" % s_id}
	var state := GameState.new()
	var result: Dictionary = state.load_dict(raw)
	if not result.get("ok", false):
		return result
	return {"ok": true, "state": state}

static func slot_summary(slot_idx: int) -> String:
	var s_id: int = clampi(slot_idx, 1, 3)
	var path: String = _file("season_slot_%d.json" % s_id)
	if not FileAccess.file_exists(path):
		return "槽位 #%d：[空槽位]" % s_id
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		return "槽位 #%d：[无法读取]" % s_id
	var d: Dictionary = raw
	var sc: String = str(d.get("scenario_id", "A"))
	var day_v: float = float(int(d.get("current_tick", 0))) / 2.0
	var cash_v: int = int(d.get("cash_cents", 0)) / 100
	return "槽位 #%d：星区 %s · Day %.1f · $%d" % [s_id, sc, day_v, cash_v]

static func has_save() -> bool:
	return FileAccess.file_exists(_file("season_save.json")) or FileAccess.file_exists(_file("season_save.backup.json"))

static func keep_previous() -> void:
	_copy(_file("season_save.json"), _file("season_save.previous.json"))

static func quarantine() -> void:
	_copy(_file("season_save.json"), _file("season_save.quarantine.json"))

static func save_record(state: GameState) -> Dictionary:
	if not state.season_ended or state.settlement.is_empty():
		return {"ok": false, "error": "本季尚未结束。"}
	save_career_progress(state)
	var records: Dictionary = updated_records(read_records(), state)
	return _write_safely(_file("season_records.json"), _file("season_records.tmp"), _file("season_records.backup.json"), JSON.stringify(records, "\t"))

static func updated_records(previous: Dictionary, state: GameState) -> Dictionary:
	var records: Dictionary = previous.duplicate(true)
	var value: int = int(state.settlement["net"])
	if not records.has("best_net") or value > int(records["best_net"]):
		records["best_net"] = value
	records["last_net"] = value
	records["scenario"] = state.scenario_id
	records["rules_version"] = str(state.balance["version"])
	records["last_settlement"] = state.settlement.duplicate(true)
	records["seasons_completed"] = int(records.get("seasons_completed", 0)) + 1
	records["career_total_net"] = int(records.get("career_total_net", 0)) + maxi(0, value)
	return records

static func read_records() -> Dictionary:
	var path: String = _file("season_records.json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func read_career() -> Dictionary:
	var path: String = _file("career_profile.json")
	if not FileAccess.file_exists(path):
		return {"unlocked_techs": [], "player_shares": 5, "mars_stage": 0, "seasons_played": 1}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {"unlocked_techs": [], "player_shares": 5, "mars_stage": 0, "seasons_played": 1}

static func save_career_progress(state: GameState) -> void:
	if folder != "user://":
		return
	var current: Dictionary = read_career()
	var saved_techs: Array = current.get("unlocked_techs", [])
	var state_techs: Array = state.stats.get("unlocked_techs", [])
	for t in state_techs:
		if not (t in saved_techs):
			saved_techs.append(t)
	var cur_shares: int = int(current.get("player_shares", 5))
	var cur_mars: int = int(current.get("mars_stage", 0))
	if state.stats.has("tycoon"):
		var s_val: int = int(state.stats["tycoon"].get("shares", {}).get("player", 5))
		cur_shares = maxi(cur_shares, s_val)
		var m_val: int = int(state.stats["tycoon"].get("mars_stage", 0))
		cur_mars = maxi(cur_mars, m_val)
	var payload: Dictionary = {
		"unlocked_techs": saved_techs,
		"player_shares": cur_shares,
		"mars_stage": cur_mars,
		"seasons_played": int(current.get("seasons_played", 1))
	}
	var file := FileAccess.open(_file("career_profile.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()

static func apply_career_to_state(state: GameState) -> void:
	if folder != "user://" or state.challenge_id != "":
		return
	var career: Dictionary = read_career()
	var saved_techs: Array = career.get("unlocked_techs", [])
	var current_techs: Array = state.stats.get("unlocked_techs", [])
	for tid in saved_techs:
		var t_str: String = str(tid)
		if not (t_str in current_techs):
			current_techs.append(t_str)
	state.stats["unlocked_techs"] = current_techs
	TechTree.apply_all_bonuses(state)
	var saved_shares: int = int(career.get("player_shares", 5))
	var saved_mars: int = int(career.get("mars_stage", 0))
	if state.stats.has("tycoon"):
		if saved_shares > 5:
			var shares: Dictionary = state.stats["tycoon"]["shares"]
			var diff: int = mini(saved_shares - int(shares["player"]), int(shares["unowned"]))
			if diff > 0:
				shares["player"] = int(shares["player"]) + diff
				shares["unowned"] = int(shares["unowned"]) - diff
		if saved_mars > 0:
			state.stats["tycoon"]["mars_stage"] = saved_mars
			if saved_mars >= 3:
				state.balance["port_capacity"] = maxi(int(state.balance["port_capacity"]), 24)

static func _file(name: String) -> String:
	return folder + name

static func _copy(source: String, destination: String) -> void:
	if not FileAccess.file_exists(source):
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()

static func _write_safely(path: String, temp_path: String, backup_path: String, contents: String) -> Dictionary:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入本地存档。"}
	file.store_string(contents)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status != OK:
		return {"ok": false, "error": "写入本地存档失败。"}
	var destination: String = ProjectSettings.globalize_path(path)
	var temporary: String = ProjectSettings.globalize_path(temp_path)
	var backup: String = ProjectSettings.globalize_path(backup_path)
	var had_original: bool = FileAccess.file_exists(path)
	if had_original and FileAccess.file_exists(backup_path):
		var remove_status: Error = DirAccess.remove_absolute(backup)
		if remove_status != OK:
			return {"ok": false, "error": "无法轮换存档备份。"}
	if had_original:
		var old_status: Error = DirAccess.rename_absolute(destination, backup)
		if old_status != OK:
			return {"ok": false, "error": "无法备份当前存档。"}
	var result: Error = DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		if had_original:
			DirAccess.rename_absolute(backup, destination)
		return {"ok": false, "error": "无法完成存档替换。"}
	return {"ok": true}
