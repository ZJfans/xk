class_name SettingsService
extends RefCounted

## 商业版玩家系统设置服务：显示、分轨音频、本地化、游戏操作偏好持久化

const SETTINGS_FILE := "user://settings.json"

static var data: Dictionary = {
	"graphics": {
		"window_mode": 0, # 0: 窗口化, 1: 全屏, 2: 独占全屏/无边框
		"resolution_width": 1440,
		"resolution_height": 900,
		"vsync": true,
		"screen_shake": true
	},
	"audio": {
		"master_volume": 80,
		"music_volume": 70,
		"sfx_volume": 85,
		"muted": false
	},
	"gameplay": {
		"language": "zh_CN", # "zh_CN" | "en_US"
		"auto_pause_on_order": true,
		"auto_pause_on_arrival": true,
		"auto_pause_on_stall": true,
		"fast_forward_speed": 2
	}
}

static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		save_settings()
		return
	var text := FileAccess.get_file_as_string(SETTINGS_FILE)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for category in ["graphics", "audio", "gameplay"]:
			if parsed.has(category) and parsed[category] is Dictionary:
				for key in parsed[category]:
					data[category][key] = parsed[category][key]
	apply_all()

static func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func apply_all() -> void:
	apply_graphics()
	apply_audio()

static func apply_graphics() -> void:
	var mode: int = int(data["graphics"]["window_mode"])
	match mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var w: int = int(data["graphics"]["resolution_width"])
			var h: int = int(data["graphics"]["resolution_height"])
			if w > 0 and h > 0:
				DisplayServer.window_set_size(Vector2i(w, h))
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	var vsync: bool = bool(data["graphics"]["vsync"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

static func apply_audio() -> void:
	var muted: bool = bool(data["audio"]["muted"])
	var master_vol: float = float(data["audio"]["master_volume"]) / 100.0
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, muted)
		var db := linear_to_db(maxf(0.0001, master_vol))
		AudioServer.set_bus_volume_db(master_bus, db)

static func set_volume(bus_name: String, percent: int) -> void:
	percent = clampi(percent, 0, 100)
	match bus_name:
		"master":
			data["audio"]["master_volume"] = percent
		"music":
			data["audio"]["music_volume"] = percent
		"sfx":
			data["audio"]["sfx_volume"] = percent
	apply_audio()
	save_settings()

static func toggle_mute() -> bool:
	data["audio"]["muted"] = not bool(data["audio"]["muted"])
	apply_audio()
	save_settings()
	return bool(data["audio"]["muted"])

static func set_language(lang_code: String) -> void:
	if lang_code in ["zh_CN", "en_US"]:
		data["gameplay"]["language"] = lang_code
		TranslationServer.set_locale(lang_code)
		save_settings()
