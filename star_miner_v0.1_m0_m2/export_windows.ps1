# 用本机 Godot 4.7.2 导出 Windows 试玩包。
# 先在编辑器里安装与 4.7.2 匹配的 Export Templates，再在本目录执行：
#   powershell -ExecutionPolicy Bypass -File .\export_windows.ps1
$ErrorActionPreference = "Stop"
$godot = "C:\Users\zhangjie42067\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\RocketProspectors\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
	Write-Error "找不到 Godot：$godot"
}
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot "build") | Out-Null
& $godot --headless --path $PSScriptRoot --export-release "Windows Desktop" (Join-Path $PSScriptRoot "build\StarMiner.exe")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "已导出 build\StarMiner.exe 。请与同目录的 StarMiner.pck 一起分发。"
