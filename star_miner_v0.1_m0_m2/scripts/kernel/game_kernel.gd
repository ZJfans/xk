class_name GameKernel
extends RefCounted

## 《星矿大亨 Rocket Prospectors》V2.0 架构 · 核心基础设施 (Game Kernel)
## 职责：
## - 统一命令派发器 (CommandDispatcher)：所有 UI/视图只通过 Kernel.dispatch() 发起状态变更请求
## - 统一事件总线 (EventBus)：向视觉层 (10_visual_audio) 与 UI 层 (09_ui_shell) 广播只读事件，实现表现与经济彻底解耦
## - 统一模拟步进入口 (step_clock)：独占管理 V4 权威时钟与经典挑战兼容时钟

signal command_dispatched(cmd_type: String, params: Dictionary, result: Dictionary, owner_module: String)
signal simulation_stepped(game_day: float, step_result: Dictionary)
signal visual_effect_requested(effect_id: String, payload: Dictionary)
signal audio_cue_requested(cue_id: String)

const V40 = preload("res://scripts/core/v40_dawn_engine.gd")
const Contracts = preload("res://scripts/contracts/shared_contracts.gd")


func dispatch(state: GameState, cmd_type: String, params: Dictionary = {}) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "GameState 为空"}
	var owner_mod: String = Contracts.get_command_owner(cmd_type)
	var res: Dictionary = V40.execute_command(state, cmd_type, params)
	command_dispatched.emit(cmd_type, params, res, owner_mod)
	if bool(res.get("ok", false)):
		visual_effect_requested.emit(cmd_type, {"params": params, "result": res, "module": owner_mod})
	return res


func step_clock(state: GameState, dt_days: float = 0.5) -> Dictionary:
	if state == null:
		return {"ok": false}
	var res: Dictionary = V40.step_v40_simulation(state, dt_days)
	simulation_stepped.emit(float(res.get("game_day", 0.0)), res)
	return res
