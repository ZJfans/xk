class_name I18nService
extends RefCounted

## 国际化本地化管理服务：提供热加载多语言词条检索与格式化

const LOC_PATH := "res://data/localization.json"
static var locale_data: Dictionary = {}
static var current_lang: String = "zh_CN"

static func init_i18n(lang: String = "") -> void:
	if not FileAccess.file_exists(LOC_PATH):
		return
	var text := FileAccess.get_file_as_string(LOC_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		locale_data = parsed
	if lang != "":
		current_lang = lang
	else:
		current_lang = SettingsService.data.get("gameplay", {}).get("language", "zh_CN")

static func t(key: String, default_val: String = "") -> String:
	if locale_data.is_empty():
		init_i18n()
	var dict: Dictionary = locale_data.get(current_lang, {})
	if dict.has(key):
		return str(dict[key])
	# Fallback to zh_CN
	var fallback_dict: Dictionary = locale_data.get("zh_CN", {})
	if fallback_dict.has(key):
		return str(fallback_dict[key])
	return default_val if default_val != "" else key

static func set_language(lang: String) -> void:
	if lang in ["zh_CN", "en_US"]:
		current_lang = lang
		SettingsService.set_language(lang)
