extends Node
## Music loops with crossfade, a pool of sfx players, and per-speaker dialogue blips.

const MUSIC_DIR := "res://assets/music/"
const SFX_DIR := "res://assets/sfx/"
const POOL_SIZE := 8
const SILENT_DB := -40.0

var _music: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}
var _pitch: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	NightClock.minute_passed.connect(_on_minute)


func play_music(track: String, fade: float = 1.0) -> void:
	if track == _current:
		return
	_current = track
	var old := _music[_active]
	_active = 1 - _active
	var new := _music[_active]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", SILENT_DB, fade)
		tw.tween_callback(old.stop)
	if track == "" or track == "none":
		return
	var stream := _load_music(track)
	if stream == null:
		return
	new.stream = stream
	new.volume_db = SILENT_DB
	new.pitch_scale = _pitch
	new.play()
	create_tween().tween_property(new, "volume_db", 0.0, fade)


func _load_music(track: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "%s%s.%s" % [MUSIC_DIR, track, ext]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = w.data.size() / 2
			return s
	Game.report("music", track, "no file in assets/music/")
	return null


func sfx(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if sound == "":
		return
	if not _cache.has(sound):
		var path := "%s%s.wav" % [SFX_DIR, sound]
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
		if _cache[sound] == null:
			Game.report("sfx", sound, "no file in assets/sfx/")
	if _cache[sound] == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _cache[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func blip(pitch: float) -> void:
	sfx("blip", pitch, -8.0)


func set_volumes(music: int, effects: int) -> void:
	_set_bus("Music", music)
	_set_bus("SFX", effects)


func _set_bus(bus: String, level: int) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(idx, level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(level / 10.0, 0.001, 1.0)))


func _on_minute(minute: int) -> void:
	var pitch := 1.0
	for step: Dictionary in Game.tuning.get("music_tension", []):
		if minute >= int(step.get("minute", 99)):
			pitch = float(step.get("pitch", 1.0))
	_pitch = pitch
	for p in _music:
		p.pitch_scale = pitch
