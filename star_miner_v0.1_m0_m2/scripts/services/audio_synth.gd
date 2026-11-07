class_name AudioSynth
extends RefCounted

## 工业级程序化多谐波音频合成器 (Procedural Multi-Harmonic Synthesizer)
## 无需外部大型音频资产，实时合成高品质立体声 SFX 与太空环境氛围音乐 (Ambient Drone BGM)

const MIX_RATE := 22050

static func build_sound_bank() -> Dictionary:
	return {
		"launch": _synth_launch(),
		"cash": _synth_cash_arpeggio(),
		"arrive": _synth_telemetry_ping(523.25, 659.25, 0.32),
		"return": _synth_telemetry_ping(587.33, 880.0, 0.36),
		"order": _synth_order_alert(),
		"scan": _synth_radar_sweep(),
		"stall": _synth_klaxon_warning(),
		"partial": _synth_telemetry_ping(440.0, 349.23, 0.28),
		"finish": _synth_fanfare(false),
		"tech": _synth_fanfare(true),
		"achievement": _synth_fanfare(true)
	}

## 合成 6 秒无缝循环的深空微重力环境氛围背景音乐 (D Minor 9th Cosmic Pad)
static func build_ambient_drone() -> AudioStreamWAV:
	var duration := 6.0
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	# D2 (73.42Hz), A2 (110Hz), D3 (146.83Hz), F3 (174.61Hz), A3 (220Hz), E4 (329.63Hz)
	var freqs := [73.42, 110.0, 146.83, 174.61, 220.0, 329.63]
	var weights := [0.32, 0.24, 0.18, 0.12, 0.08, 0.06]
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		# 使用周期正弦调制确保首尾相位平滑衔接
		var cycle_phase := TAU * t / duration
		var lfo := 0.82 + 0.18 * sin(cycle_phase)
		var val := 0.0
		for k in range(freqs.size()):
			var f: float = freqs[k]
			# 调整频率使其在 duration 内恰好完成整数个周期，消除循环爆音
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

## 火箭点火升空：低频推进器轰鸣 + 谐波扫频 + 尾焰气流噪声
static func _synth_launch() -> AudioStreamWAV:
	var duration := 0.58
	var count := int(MIX_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1048576
	var low_pass := 0.0
	for i in range(count):
		var progress := float(i) / float(count)
		var t := float(i) / float(MIX_RATE)
		var env := sin(progress * PI) * pow(1.0 - progress * 0.55, 0.8)
		var sweep_freq := lerpf(58.0, 145.0, pow(progress, 0.7))
		var sub_bass := sin(TAU * sweep_freq * t) * 0.55 + sin(TAU * sweep_freq * 2.0 * t) * 0.25
		var raw_noise := rng.randf_range(-1.0, 1.0)
		low_pass = lerpf(low_pass, raw_noise, 0.18)
		var rumble := (sub_bass + low_pass * 0.65) * env
		var pcm := clampi(int(rumble * 9200.0), -32767, 32767)
		var u := pcm & 0xffff
		samples[i * 2] = u & 255
		samples[i * 2 + 1] = (u >> 8) & 255
	return _make_wav(samples)

## 货款到账：清脆双音阶琶音 + 金属泛音共鸣 (C5 - E5 - G5 - C6)
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

## 遥测通讯双音提示
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

## 紧急采购订单到港：三连高频脉冲电报音
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

## 深空雷达扫描声呐
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

## 工业仓满/堵塞低频双脉冲告警
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

## 结算/科技/成就达成和弦号角
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
