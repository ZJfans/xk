class_name AssetLoader
extends RefCounted

## 高清美术资产动态加载与缓存服务
## 直接通过 PNG 字节流构建 GPU ImageTexture，无需等待编辑器重新生成 .ctex 缓存即可即刻渲染高清贴图。

static var _cache: Dictionary = {}

static func get_tex(res_path: String, fallback: Texture2D = null) -> Texture2D:
	if _cache.has(res_path):
		return _cache[res_path]
	if FileAccess.file_exists(res_path):
		var bytes := FileAccess.get_file_as_bytes(res_path)
		if not bytes.is_empty():
			var img := Image.new()
			var err := img.load_png_from_buffer(bytes)
			if err == OK and not img.is_empty():
				var tex := ImageTexture.create_from_image(img)
				_cache[res_path] = tex
				return tex
	var global_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_p):
		var img2 := Image.load_from_file(global_p)
		if img2 != null and not img2.is_empty():
			var tex2 := ImageTexture.create_from_image(img2)
			_cache[res_path] = tex2
			return tex2
	if ResourceLoader.exists(res_path):
		var loaded = load(res_path)
		if loaded is Texture2D:
			_cache[res_path] = loaded
			return loaded
	return fallback
