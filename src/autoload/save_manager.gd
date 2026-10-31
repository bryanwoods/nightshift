extends Node
## user://save.json holds what carries across nights. Settings live in their own file.

signal saved
signal loaded

const PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const TEXT_SPEEDS: Array[float] = [0.6, 1.0, 2.0]

var settings: Dictionary = {"music": 7, "sfx": 8, "text_speed": 1, "scale": 4, "fullscreen": false}


func _ready() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var s: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if s is Dictionary:
			settings.merge(s, true)


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game() -> void:
	var persistent := {}
	for f in Game.flags:
		if not str(f).begins_with(Game.TONIGHT):
			persistent[f] = true
	var data := {
		"night": Game.night,
		"flags": persistent,
		"items": Game.items,
		"friends": Game.friends(),
		"enemies": Game.enemies(),
		"seen_dialogue": Game.seen.keys(),
		"settings": settings,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		saved.emit()


func load_game() -> bool:
	if not has_save():
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		Game.report("save.json", "", "the save file could not be read")
		return false
	Game.night = int(d.get("night", 1))
	Game.flags = (d.get("flags", {}) as Dictionary).duplicate()
	Game.items.assign(d.get("items", []))
	Game.seen.clear()
	for id: Variant in d.get("seen_dialogue", []):
		Game.seen[str(id)] = true
	loaded.emit()
	return true


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
		var s := clampi(int(settings.get("scale", 4)), 1, 8)
		var target := Vector2i(320 * s, 180 * s)
		if w.size != target and not OS.has_feature("headless"):
			w.size = target
			w.move_to_center()
