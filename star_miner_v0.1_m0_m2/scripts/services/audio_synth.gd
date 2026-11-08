class_name AudioSynth
extends RefCounted

## 《星矿大亨 Rocket Prospectors》V4.0 · 44.1 kHz 高清程序化多谐波音效与星团自适应氛围音乐合成器
## 严格遵循 V4.0 方案第 16.7 节「声音反馈」：
## - 重点制作：扫描确认 (scan)、钻入矿体 (drill_hit)、持续采掘 (mining_hum)、装载完成 (load_done)、
##            多级火箭发射 (launch)、音爆与着陆回收 (recovery)、交易到账 (cash)
## - 多矿场后台声音不同时叠加，当前矿场外的活动用轻量提示音表现
## - 环境音乐随破晓星域五大星团区域变化（晨曦边境 / 赤沙星群 / 霜环星群 / 熔心星群 / 幽光深域）

const MIX_RATE := 44100

static func build_sound_bank() -> Dictionary:
	return {
		"launch": _synth_launch(),
		"recovery": _synth_recovery_sonic_boom(),
		"drill_hit": _synth_drill_into_vein(),
		"mining_hum": _synth_mining_pulse(),
		"load_done": _synth_cargo_lock(),
		"cash": _synth_cash_arpeggio(),
		"arrive": _synth_telemetry_ping(523.25, 659.25, 0.32),
		"return": _synth_recovery_sonic_boom(),
		"order": _synth_order_alert(),
		"scan": _synth_radar_sweep(),
		"stall": _synth_klaxon_warning(),
		"partial": _synth_telemetry_ping(440.0, 349.23, 0.28),
		"finish": _synth_fanfare(false),
		"tech": _synth_fanfare(true),
		"achievement": _synth_fanfare(true),
		"window_lock": _synth_window_lock_chime()
	}


static func build_ambient_drone() -> AudioStreamWAV:
	return build_cluster_ambient_drone("dawn_frontier")


## 按破晓星域五大星团生成 6 秒无缝循环的专属环境氛围背景音乐 (第 16.7 节)
static func build_cluster_ambient_drone(cluster_id: String = "dawn_frontier") -> AudioStreamWAV:
	var duration := 6.0
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)

	var freqs: Array = [73.42, 110.0, 146.83, 174.61, 220.0, 329.63] # 晨曦边境 D Minor 9
	match cluster_id:
		"crimson_sands":
			freqs = [65.41, 98.00, 130.81, 164.81, 196.00, 293.66] # 赤沙星群 C Maj9 暖金深沉
		"frost_ring":
			freqs = [82.41, 123.47, 164.81, 196.00, 246.94, 369.99] # 霜环星群 E Min9 冰晶清透
		"molten_core":
			freqs = [55.00, 82.41, 110.00, 130.81, 164.81, 246.94] # 熔心星群 A Min 低频重力脉动
		"glimmer_deep":
			freqs = [61.74, 92.50, 123.47, 146.83, 220.00, 329.63] # 幽光深域 B Min11 神秘深空

	var weights := [0.32, 0.24, 0.18, 0.12, 0.08, 0.06]
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var cycle_phase := TAU * t / duration
		var lfo := 0.82 + 0.18 * sin(cycle_phase)
		var val := 0.0
		for k in range(freqs.size()):
			var f: float = float(freqs[k])
			var cycles := roundf(f * duration)
			var exact_f := cycles / duration
			var detune := sin(cycle_phase * float(k + 1)) * 0.12
			val += sin(TAU * exact_f * t + detune) * float(weights[k])
		var pcm := clampi(int(val * lfo * 3800.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	stream.data = samples
	return stream


## 火箭点火升空：多台猛禽/海平面发动机低频共振 + 尾焰气流爆裂声 + 级间分离脉冲
static func _synth_launch() -> AudioStreamWAV:
	var duration := 0.68
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1048576
	var low_pass := 0.0
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var env := sin(progress * PI) * pow(1.0 - progress * 0.45, 0.75)
		var sweep_freq := lerpf(52.0, 158.0, pow(progress, 0.68))
		var sub_bass := sin(TAU * sweep_freq * t) * 0.52 + sin(TAU * sweep_freq * 2.0 * t) * 0.24 + sin(TAU * 1046.5 * t) * 0.05 * exp(-progress * 8.0)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		low_pass = lerpf(low_pass, raw_noise, 0.14)
		var rumble := (sub_bass + low_pass * 0.68) * env
		var pcm := clampi(int(rumble * 9600.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


## 助推器再入双音爆 (Double Sonic Boom) + 着陆点火确认和弦
static func _synth_recovery_sonic_boom() -> AudioStreamWAV:
	var duration := 0.52
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var boom1 := exp(-pow((progress - 0.12) * 18.0, 2.0)) * sin(TAU * 68.0 * t)
		var boom2 := exp(-pow((progress - 0.24) * 18.0, 2.0)) * sin(TAU * 62.0 * t)
		var chime_env := clampf((progress - 0.32) / 0.68, 0.0, 1.0)
		var chime := (sin(TAU * 587.33 * t) * 0.45 + sin(TAU * 880.0 * t) * 0.35) * pow(1.0 - chime_env, 1.6) if progress >= 0.32 else 0.0
		var wave := (boom1 + boom2) * 0.65 + chime * 0.55
		var pcm := clampi(int(wave * 8800.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


## 钻入矿体 (第 16.7 节)：钻头咬合岩层脉冲 + 矿脉晶簇高频泛音
static func _synth_drill_into_vein() -> AudioStreamWAV:
	var duration := 0.44
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var drill_mod := 0.5 + 0.5 * sin(TAU * 36.0 * t)
		var rock_bite := sin(TAU * lerpf(140.0, 95.0, progress) * t) * drill_mod * (1.0 - progress)
		var crystal_ring := (sin(TAU * 659.25 * t) * 0.4 + sin(TAU * 987.77 * t) * 0.3) * pow(1.0 - progress, 1.4)
		var pcm := clampi(int((rock_bite * 0.55 + crystal_ring * 0.45) * 8400.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


## 持续采掘轻量脉冲提示音 (第 16.7 节)
static func _synth_mining_pulse() -> AudioStreamWAV:
	var duration := 0.26
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var env := sin(progress * PI)
		var wave := sin(TAU * 110.0 * t) * 0.6 + sin(TAU * 220.0 * t) * 0.3
		var pcm := clampi(int(wave * env * 5200.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


## 装载完成气动锁扣与确认音 (第 16.7 节)
static func _synth_cargo_lock() -> AudioStreamWAV:
	return _synth_telemetry_ping(493.88, 739.99, 0.30)


## 货款到账：清脆四音阶琶音 + 金属泛音共鸣 (C5 - E5 - G5 - C6)
static func _synth_cash_arpeggio() -> AudioStreamWAV:
	var duration := 0.42
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var notes := [523.25, 659.25, 783.99, 1046.50]
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var note_idx := mini(notes.size() - 1, int(progress * float(notes.size())))
		var local_p := fmod(progress * float(notes.size()), 1.0)
		var env := pow(1.0 - local_p, 1.8) * (1.0 - progress * 0.25)
		var freq: float = notes[note_idx]
		var wave := sin(TAU * freq * t) * 0.65 + sin(TAU * freq * 2.0 * t) * 0.25 + sin(TAU * freq * 3.0 * t) * 0.10
		var pcm := clampi(int(wave * env * 8200.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _synth_telemetry_ping(f1: float, f2: float, duration: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var freq := f1 if progress < 0.45 else f2
		var local_p := (progress / 0.45) if progress < 0.45 else ((progress - 0.45) / 0.55)
		var env := pow(1.0 - local_p, 1.65)
		var wave := sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 2.0 * t) * 0.25
		var pcm := clampi(int(wave * env * 7400.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _synth_order_alert() -> AudioStreamWAV:
	var duration := 0.38
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var freqs := [740.0, 880.0, 1174.66]
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var idx := mini(2, int(progress * 3.0))
		var local_p := fmod(progress * 3.0, 1.0)
		var env := pow(1.0 - local_p, 1.5)
		var f: float = freqs[idx]
		var wave := sin(TAU * f * t) * 0.7 + sin(TAU * f * 1.5 * t) * 0.3
		var pcm := clampi(int(wave * env * 7600.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _synth_radar_sweep() -> AudioStreamWAV:
	var duration := 0.46
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var freq := lerpf(480.0, 920.0, sin(progress * PI * 0.5))
		var env := sin(progress * PI) * pow(1.0 - progress, 0.7)
		var shimmer := 1.0 + 0.25 * sin(TAU * 18.0 * t)
		var wave := sin(TAU * freq * t) * shimmer
		var pcm := clampi(int(wave * env * 7000.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _synth_klaxon_warning() -> AudioStreamWAV:
	var duration := 0.36
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var pulse := 1.0 if (progress < 0.42 or (progress > 0.52 and progress < 0.94)) else 0.0
		var env := pow(1.0 - progress * 0.4, 1.2) * pulse
		var f := 185.0 if progress < 0.5 else 155.0
		var wave := sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.3 + sin(TAU * f * 3.0 * t) * 0.1
		var pcm := clampi(int(wave * env * 7800.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _synth_fanfare(bright: bool) -> AudioStreamWAV:
	var duration := 0.55 if bright else 0.48
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var chord := [440.0, 554.37, 659.25, 880.0] if bright else [293.66, 369.99, 440.0, 587.33]
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var env := pow(1.0 - progress, 1.35)
		var wave := 0.0
		for k in range(chord.size()):
			var f: float = chord[k]
			wave += sin(TAU * f * t) * (0.35 / float(k + 1))
		var pcm := clampi(int(wave * env * 9600.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)


static func _make_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = samples
	return stream


## 发射窗口锁定与液氧加注气动确认音 (对标参考图 3 & 4 航天遥测交互)
static func _synth_window_lock_chime() -> AudioStreamWAV:
	var duration := 0.34
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 202604
	var lp := 0.0
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var f := 880.0 if progress < 0.42 else 1318.51
		var local_p := (progress / 0.42) if progress < 0.42 else ((progress - 0.42) / 0.58)
		var env := pow(1.0 - local_p, 1.55)
		var tone := (sin(TAU * f * t) * 0.72 + sin(TAU * f * 2.0 * t) * 0.22) * env
		var raw_n := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw_n, 0.22)
		var hiss := lp * 0.18 * sin(progress * PI)
		var pcm := clampi(int((tone + hiss) * 7800.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)
