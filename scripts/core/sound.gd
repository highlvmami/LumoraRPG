## Sound effects and music, all made in code (no audio files): short
## synthesized blips, pops and chimes, and two music loops (a calm one for
## the menu and the tavern, a quicker one for runs). The game owns one
## (main.sound): sound.play("coin"), sound.music("run").
## Volumes come from the settings (musicVolume, sfxVolume, 0..1).
extends Node

const RATE := 22050
const MUSIC_RATE := 16000
const VOICES := 10
## Shortest time between two plays of the same sound (many hits per frame
## would otherwise stack into noise).
const GAP := {"hit": 0.06, "shoot": 0.07, "kill": 0.05, "coin": 0.06, "exp": 0.08, "click": 0.03, "hurt": 0.25}
const LEVELS := {"hit": 0.35, "shoot": 0.3, "kill": 0.45, "coin": 0.5, "exp": 0.3, "click": 0.35,
	"hurt": 0.6, "levelup": 0.6, "boss": 0.9, "chest": 0.6, "ult": 0.7, "gate": 0.6, "quest": 0.55, "trade": 0.55}

var music_volume := 0.5
var sfx_volume := 0.7
## The music playing now ("calm", "run" or "").
var current := ""

var _sounds := {}
var _tracks := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _fade := 1.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## Tracks being made, a little each frame.
var _jobs: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_build_sounds()
	get_tree().node_added.connect(_on_node_added)
	_queue_track("calm")
	_queue_track("run")


func set_volumes(music_v: float, sfx_v: float) -> void:
	music_volume = clampf(music_v, 0.0, 1.0)
	sfx_volume = clampf(sfx_v, 0.0, 1.0)
	_apply_music_volume()


## Plays a sound effect; `pitch` varies it a little (1.0 = as made).
func play(id: String, pitch := 1.0) -> void:
	if not _sounds.has(id) or sfx_volume <= 0.0:
		return
	var gap := float(GAP.get(id, 0.0))
	if gap > 0.0 and _time - float(_last.get(id, -10.0)) < gap:
		return
	_last[id] = _time
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _sounds[id]
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.volume_db = linear_to_db(maxf(sfx_volume * float(LEVELS.get(id, 0.5)), 0.0001))
	p.play()


## Switches the music ("calm", "run" or "" for silence) with a short fade.
func music(id: String) -> void:
	if id == current:
		return
	current = id
	if id != "" and not _tracks.has(id):
		# Still being made: it starts as soon as it is ready.
		_queue_track(id)
		_swap()
		return
	_start(id)


## The old music fades out on the second player.
func _swap() -> void:
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stop()
	_fade = 0.0
	_apply_music_volume()


## Queues a track to be made; the one asked for last comes first.
func _queue_track(id: String) -> void:
	for job: Dictionary in _jobs:
		if job.id == id:
			if current == id:
				_jobs.erase(job)
				_jobs.push_front(job)
			return
	if current == id:
		_jobs.push_front(_begin_track(id))
	else:
		_jobs.append(_begin_track(id))


func _start(id: String) -> void:
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_fade = 0.0
	if id != "":
		_music_a.stream = _tracks[id]
		_music_a.play()
	else:
		_music_a.stop()
	_apply_music_volume()


func is_playing_music() -> bool:
	return _music_a.playing


func has_sound(id: String) -> bool:
	return _sounds.has(id)


func _process(delta: float) -> void:
	_time += delta
	if not _jobs.is_empty():
		var job: Dictionary = _jobs[0]
		if _step_track(job, 4.0):
			_jobs.pop_front()
			_tracks[job.id] = _finish_track(job)
			if current == job.id:
				_start(job.id)
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / 1.2)
		_apply_music_volume()
		if _fade >= 1.0:
			_music_b.stop()


func _apply_music_volume() -> void:
	if _music_a == null:
		return
	var v := music_volume * 0.6
	_music_a.volume_db = linear_to_db(maxf(v * _fade, 0.0001))
	_music_b.volume_db = linear_to_db(maxf(v * (1.0 - _fade), 0.0001))


## Every button in the game clicks.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play.bind("click"))


# --- Sound effects --------------------------------------------------------------

func _build_sounds() -> void:
	_sounds.shoot = _wav(_sweep(0.09, 900.0, 260.0, "tri", 0.0, 0.25))
	_sounds.hit = _wav(_sweep(0.05, 260.0, 120.0, "square", 0.0, 0.7))
	_sounds.kill = _wav(_sweep(0.13, 620.0, 140.0, "sine", 0.0, 0.25))
	_sounds.coin = _wav(_notes([988.0, 1319.0], 0.06, "square", 0.5))
	_sounds.exp = _wav(_sweep(0.07, 1100.0, 1700.0, "sine", 0.0, 0.0))
	_sounds.click = _wav(_sweep(0.025, 1500.0, 1200.0, "sine", 0.0, 0.0))
	_sounds.hurt = _wav(_sweep(0.18, 230.0, 90.0, "saw", 0.0, 0.3))
	_sounds.levelup = _wav(_notes([523.0, 659.0, 784.0, 1047.0], 0.09, "tri", 1.0))
	_sounds.quest = _wav(_notes([784.0, 988.0, 1175.0], 0.08, "tri", 0.9))
	_sounds.trade = _wav(_notes([659.0, 988.0], 0.1, "tri", 0.8))
	_sounds.chest = _wav(_notes([523.0, 784.0, 1047.0, 1319.0, 1568.0], 0.07, "square", 1.2))
	_sounds.boss = _wav(_rumble(1.1))
	_sounds.ult = _wav(_whoosh(0.55))
	_sounds.gate = _wav(_shimmer(0.9))


## One tone gliding from `f0` to `f1` Hz with a quick attack and a fade.
func _sweep(length: float, f0: float, f1: float, wave: String, _vib: float, noise: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var env := minf(1.0, i / (0.004 * RATE)) * pow(1.0 - t, 2.0)
		out[i] = (_osc(wave, phase) * (1.0 - noise) + _rng.randf_range(-1.0, 1.0) * noise) * env
	return out


## Notes one after another, the last one rings longer.
func _notes(freqs: Array, step: float, wave: String, tail: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in freqs.size():
		var length := step * (1.0 + tail * 3.0 if k == freqs.size() - 1 else 1.0)
		var n := int(length * RATE)
		var phase := 0.0
		for i in n:
			phase += float(freqs[k]) / RATE
			var env := minf(1.0, i / (0.003 * RATE)) * pow(1.0 - float(i) / n, 1.6)
			out.append(_osc(wave, phase) * env * 0.8)
	return out


## A deep growl with rumbling noise (a boss appears).
func _rumble(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := float(i) / n
		phase += (70.0 - 25.0 * t + sin(t * 40.0) * 6.0) / RATE
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.05)
		var env := minf(1.0, t * 8.0) * (1.0 - t)
		out[i] = (_osc("saw", phase) * 0.55 + low * 2.0) * env
	return out


## Filtered noise rising then falling (an ultimate).
func _whoosh(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / n
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.02 + 0.25 * sin(t * PI))
		out[i] = low * sin(t * PI) * 1.6
	return out


## Two slightly detuned bell tones with a wobble (a magic gate).
func _shimmer(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / n
		var wob := sin(t * 30.0) * 8.0
		a += (660.0 + wob) / RATE
		b += (663.0 + wob * 1.5 + 330.0) / RATE
		out[i] = (sin(a * TAU) * 0.5 + sin(b * TAU) * 0.3) * minf(1.0, t * 10.0) * pow(1.0 - t, 1.5)
	return out


func _osc(wave: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		"square":
			return 0.6 if p < 0.5 else -0.6
		"saw":
			return (p * 2.0 - 1.0) * 0.7
		"tri":
			return 1.0 - 4.0 * absf(p - 0.5)
	return sin(p * TAU)


func _wav(samples: PackedFloat32Array, rate := RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# --- Music ---------------------------------------------------------------------

## A music loop made from chords: a soft pad, a bass and a plucked melody
## from the chord's notes. "calm" is slow and gentle, "run" is quicker.
## Made a little each frame (see _process) so the game never stutters.
func _begin_track(id: String) -> Dictionary:
	var calm := id != "run"
	# A minor: Am F C G (calm) / Am F G Em (run); MIDI note numbers.
	var chords: Array = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]] if calm else [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]]
	var chord_len := 4.0 if calm else 2.0
	var beat := chord_len / 8.0
	var total := chord_len * chords.size() * (1 if calm else 2)
	var n := int(total * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if calm else 11
	var steps := int(total / (beat if calm else beat * 0.5))
	return {"id": id, "calm": calm, "chords": chords, "chord_len": chord_len, "beat": beat, "total": total,
		"n": n, "out": out, "rng": rng, "i": 0, "pad": [0.0, 0.0, 0.0], "bass": 0.0, "st": 0, "steps": steps, "step_len": total / steps}


## Works on a track for about `budget_ms`. Returns true when it is done.
func _step_track(job: Dictionary, budget_ms: float) -> bool:
	var end_at := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var calm: bool = job.calm
	var chords: Array = job.chords
	var chord_len: float = job.chord_len
	var beat: float = job.beat
	var n: int = job.n
	var out: PackedFloat32Array = job.out
	var rng: RandomNumberGenerator = job.rng
	var pad_phase: Array = job.pad
	# Pad and bass, chord by chord.
	while int(job.i) < n and Time.get_ticks_usec() < end_at:
		var stop := mini(int(job.i) + 2000, n)
		for i in range(int(job.i), stop):
			var t := float(i) / MUSIC_RATE
			var chord: Array = chords[int(t / chord_len) % chords.size()]
			var in_chord := fmod(t, chord_len) / chord_len
			var s := 0.0
			for k in 3:
				pad_phase[k] += _hz(int(chord[k]) + 12) / MUSIC_RATE
				s += sin(float(pad_phase[k]) * TAU) * 0.09
			s *= minf(1.0, in_chord * 6.0) * minf(1.0, (1.0 - in_chord) * 10.0) * (1.0 if calm else 0.6)
			var in_beat := fmod(t, beat) / beat
			job.bass = float(job.bass) + _hz(int(chord[0]) - 12) / MUSIC_RATE
			var bass_env := pow(1.0 - in_beat, 2.0 if calm else 3.0)
			if calm and int(t / beat) % 2 == 1:
				bass_env = 0.0
			s += (1.0 - 4.0 * absf(fposmod(float(job.bass), 1.0) - 0.5)) * bass_env * (0.16 if calm else 0.2)
			if not calm and int(t / (beat * 0.5)) % 2 == 1:
				# A soft hi-hat on the off-beats.
				s += rng.randf_range(-1.0, 1.0) * pow(1.0 - fmod(t, beat * 0.5) / (beat * 0.5), 8.0) * 0.05
			out[i] = s
		job.i = stop
	# Plucked melody: chord tones two octaves up, now and then a rest.
	var step_len: float = job.step_len
	while int(job.i) >= n and int(job.st) < int(job.steps) and Time.get_ticks_usec() < end_at:
		var st: int = job.st
		job.st = st + 1
		if rng.randf() < (0.35 if calm else 0.2):
			continue
		var t0 := st * step_len
		var chord: Array = chords[int(t0 / chord_len) % chords.size()]
		var f := _hz(int(chord[rng.randi() % 3]) + 24 + (12 if rng.randf() < 0.15 else 0))
		var start := int(t0 * MUSIC_RATE)
		var length := int((step_len * (2.5 if calm else 1.5)) * MUSIC_RATE)
		var phase := 0.0
		var decay := 3.0 if calm else 6.0
		var level := 0.12 if calm else 0.1
		for i in length:
			phase += f / MUSIC_RATE
			out[(start + i) % n] += (sin(phase * TAU) * 0.7 + sin(phase * TAU * 2.0) * 0.2) * minf(1.0, i / 60.0) * exp(-float(i) / MUSIC_RATE * decay) * level
	job.out = out
	return int(job.i) >= n and int(job.st) >= int(job.steps)


func _finish_track(job: Dictionary) -> AudioStreamWAV:
	var wav := _wav(job.out, MUSIC_RATE)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(job.n)
	return wav


## Makes a whole track at once (tests).
func _make_track(id: String) -> AudioStreamWAV:
	var job := _begin_track(id)
	while not _step_track(job, 1000.0):
		pass
	return _finish_track(job)


func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
