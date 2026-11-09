extends Node
class_name AudioFx
## All sounds are synthesised at runtime: engine hum, parking-sensor beeps,
## crash thud, horn, checkpoint and success chimes.

const RATE := 22050.0

var enabled := true
var _engine: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _freq := 40.0
var _amp := 0.0
var _players := {}
var _beep_timer := 0.0

func _ready() -> void:
    _engine = AudioStreamPlayer.new()
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = RATE
    gen.buffer_length = 0.12
    _engine.stream = gen
    _engine.volume_db = -8.0
    add_child(_engine)
    _engine.play()
    _playback = _engine.get_stream_playback()
    _players.beep = _make("beep", _tone([1750.0], 0.07, 0.5, false))
    _players.crash = _make("crash", _noise_burst(0.38))
    _players.horn = _make("horn", _tone([415.0, 523.0], 0.5, 0.35, true))
    _players.check = _make("check", _tone([1320.0, 1760.0], 0.16, 0.35, false))
    _players.win = _make("win", _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.12))
    _players.tick = _make("tick", _tone([880.0], 0.12, 0.4, false))
    _players.go = _make("go", _tone([1320.0], 0.4, 0.45, false))

func _make(n: String, stream: AudioStreamWAV) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.name = n
    p.stream = stream
    add_child(p)
    return p

func play(n: String, volume_db := 0.0) -> void:
    if not enabled or not _players.has(n):
        return
    var p: AudioStreamPlayer = _players[n]
    p.volume_db = volume_db
    p.play()

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in samples.size():
        bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = int(RATE)
    w.stereo = false
    w.data = bytes
    return w

static func _tone(freqs: Array, dur: float, vol: float, square: bool) -> AudioStreamWAV:
    var n := int(dur * RATE)
    var s := PackedFloat32Array()
    s.resize(n)
    for i in n:
        var t := float(i) / RATE
        var env := minf(1.0, t * 80.0) * minf(1.0, (dur - t) * 30.0)
        var v := 0.0
        for f in freqs:
            var x := sin(TAU * float(f) * t)
            v += (signf(x) * 0.6 + x * 0.4) if square else x
        s[i] = v / float(freqs.size()) * vol * env
    return _wav(s)

static func _noise_burst(dur: float) -> AudioStreamWAV:
    var n := int(dur * RATE)
    var s := PackedFloat32Array()
    s.resize(n)
    var rng := RandomNumberGenerator.new()
    var lp := 0.0
    for i in n:
        var t := float(i) / RATE
        lp = lerpf(lp, rng.randf_range(-1, 1), 0.18)
        s[i] = (lp * 1.6 + sin(TAU * 70.0 * t) * 0.5) * exp(-t * 9.0) * 0.8
    return _wav(s)

static func _arpeggio(freqs: Array, step: float) -> AudioStreamWAV:
    var n := int((step * freqs.size() + 0.4) * RATE)
    var s := PackedFloat32Array()
    s.resize(n)
    for i in n:
        var t := float(i) / RATE
        var v := 0.0
        for k in freqs.size():
            var t0 := float(k) * step
            if t >= t0:
                v += sin(TAU * float(freqs[k]) * (t - t0)) * exp(-(t - t0) * 4.0)
        s[i] = v * 0.22
    return _wav(s)

## Called every frame with the car state.
func update_engine(speed: float, throttle: float) -> void:
    if _playback == null:
        return
    var target_f := 34.0 + absf(speed) * 7.5 + absf(throttle) * 10.0
    var target_a := 0.0 if not enabled else 0.1 + absf(throttle) * 0.08 + minf(absf(speed) * 0.006, 0.06)
    var frames := _playback.get_frames_available()
    for i in frames:
        _freq = lerpf(_freq, target_f, 0.0006)
        _amp = lerpf(_amp, target_a, 0.0008)
        _phase = fmod(_phase + _freq / RATE, 1.0)
        var x := _phase * TAU
        var v := sin(x) * 0.55 + sin(x * 2.0) * 0.28 + sin(x * 3.0 + 0.6) * 0.14 + (randf() - 0.5) * 0.05
        _playback.push_frame(Vector2(v, v) * _amp)

## Parking sensor: beeps faster as the obstacle gets closer; solid tone < 0.3 m.
func update_sensor(dist: float, active: bool, delta: float) -> void:
    if not active or dist > 1.8 or not enabled:
        _beep_timer = 0.0
        return
    _beep_timer -= delta
    if _beep_timer <= 0.0:
        play("beep", -4.0)
        _beep_timer = 0.07 if dist < 0.3 else lerpf(0.12, 0.6, clampf((dist - 0.3) / 1.5, 0.0, 1.0))
