extends Node
## Live state is Game: flags, items, hours, tallies and seen dialogue for this session.
## Committed state is what is on disk. A save at a lamp commits live state, and the end of
## the night reverts live state to it. Pending is what live has that committed does not.
## Settings live in their own file.

signal saved
signal loaded

const PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const TEXT_SPEEDS: Array[float] = [0.6, 1.0, 2.0]
const KINDS: Array[String] = ["friend", "enemy", "gone", "lamp"]

var settings: Dictionary = {"music": 7, "sfx": 8, "text_speed": 1, "scale": 4, "fullscreen": false}
var committed: Dictionary = {}


func _ready() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var s: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if s is Dictionary:
			settings.merge(s, true)


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func snapshot() -> Dictionary:
	var persistent := {}
	for f in Game.flags:
		if not str(f).begins_with(Game.TONIGHT):
			persistent[f] = true
	return {
		"night": Game.night,
		"flags": persistent,
		"items": Game.items.duplicate(),
		"hours": Game.hours,
		"tally": Game.tally.duplicate(),
		"seen_dialogue": Game.seen.keys(),
	}


func commit() -> void:
	committed = snapshot()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(committed, "  "))
		Game.playtest("save", {})
		saved.emit()


func revert() -> void:
	_apply(committed)


func load_game() -> bool:
	if not has_save():
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		Game.report("save.json", "", "the save file could not be read")
		return false
	committed = d
	_apply(d)
	loaded.emit()
	return true


func _apply(d: Dictionary) -> void:
	Game.night = int(d.get("night", 1))
	Game.flags = (d.get("flags", {}) as Dictionary).duplicate()
	Game.items.assign(d.get("items", []))
	Game.hours = int(d.get("hours", 0))
	var t: Dictionary = d.get("tally", {})
	for k: String in Game.tally:
		Game.tally[k] = int(t.get(k, 0))
	Game.seen.clear()
	for id: Variant in d.get("seen_dialogue", []):
		Game.seen[str(id)] = true


## What `state` holds that `minus` does not, by kind: friend, enemy, gone and lamp ids, items, hours.
func difference(state: Dictionary, minus: Dictionary) -> Dictionary:
	var out := {"items": [], "hours": int(state.get("hours", 0)) - int(minus.get("hours", 0))}
	for k in KINDS:
		out[k] = []
	var old: Dictionary = minus.get("flags", {})
	for f: String in state.get("flags", {}):
		var kind := f.get_slice("_", 0)
		if kind in KINDS and not old.has(f):
			out[kind].append(f.trim_prefix(kind + "_"))
	for it: Variant in state.get("items", []):
		if not it in minus.get("items", []):
			out["items"].append(str(it))
	return out


func pending() -> Dictionary:
	return difference(snapshot(), committed)


func kept() -> Dictionary:
	return difference(committed, {})


func erase() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))


func text_speed() -> float:
	return TEXT_SPEEDS[clampi(int(settings.get("text_speed", 1)), 0, TEXT_SPEEDS.size() - 1)]


func apply_settings() -> void:
	AudioBus.set_volumes(int(settings.get("music", 7)), int(settings.get("sfx", 8)))
	var w := get_window()
	if bool(settings.get("fullscreen", false)):
		w.mode = Window.MODE_FULLSCREEN
	else:
		if w.mode == Window.MODE_FULLSCREEN:
			w.mode = Window.MODE_WINDOWED
		var dpi := DisplayServer.screen_get_scale()
		var usable := Vector2(DisplayServer.screen_get_usable_rect().size)
		var s := clampi(int(settings.get("scale", 4)), 1, 8)
		while s > 1 and (Vector2(320 * s, 180 * s) * dpi).x > usable.x:
			s -= 1
		var target := Vector2i(Vector2(320 * s, 180 * s) * dpi)
		if w.size != target and not OS.has_feature("headless"):
			w.size = target
			w.move_to_center()
