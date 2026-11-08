# 10 视觉与音效系统 (Visuals, Shaders & Procedural Audio) — 模块边界与 AI 协作契约

## 1. 模块职责
负责赛博工业主题、CRT 扫描线覆盖层、星云 Shader、操作 Toast、F8 降低动效开关与 44.1 kHz 程序化音效/星团环境音。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `visual_theme.gd`
- `cyber_fx_director.gd`
- `cyber_overlay.gd`
- `audio_synth.gd`
