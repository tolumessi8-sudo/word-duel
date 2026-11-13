extends Node
## Tiny procedural sound effects (no audio files needed).

var _streams: Dictionary = {}
var _players: Dictionary = {}


func _ready() -> void:
	_streams["tap"] = _tone([700.0], 0.05, 0.25)
	_streams["good"] = _tone([660.0, 880.0], 0.14, 0.3)
	_streams["bad"] = _tone([180.0, 140.0], 0.22, 0.3, true)
	_streams["tick"] = _tone([520.0], 0.07, 0.3)
	_streams["go"] = _tone([523.0, 659.0, 784.0], 0.3, 0.3)
	_streams["win"] = _tone([523.0, 659.0, 784.0, 1046.0], 0.6, 0.3)
	_streams["lose"] = _tone([392.0, 330.0, 262.0], 0.6, 0.3)
	_streams["draw"] = _tone([440.0, 440.0], 0.35, 0.3)
	_streams["coin"] = _tone([988.0, 1319.0], 0.2, 0.25)
	for k in _streams.keys():
		var p := AudioStreamPlayer.new()
		p.stream = _streams[k]
		add_child(p)
		_players[k] = p


func play(sound: String) -> void:
	if not Game.sound_on or not _players.has(sound):
		return
	var p: AudioStreamPlayer = _players[sound]
	p.play()


func _tone(freqs: Array, dur: float, vol: float, square := false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var seg := mini(int(float(i) / n * freqs.size()), freqs.size() - 1)
		var f: float = freqs[seg]
		var attack := minf(1.0, float(i) / (rate * 0.005))
		var release := minf(1.0, float(n - i) / (rate * 0.04))
		var s := sin(TAU * f * t)
		if square:
			s = signf(s) * 0.6
		var v := int(clampf(s * vol * attack * release, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
