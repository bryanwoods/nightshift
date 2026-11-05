extends Node
## Night number, live state (flags, items, hours, tallies), scene routing, fades, data errors
## and debug keys. SaveManager commits live state to disk and reverts to it.

signal flag_set(name: String)
signal flag_cleared(name: String)
signal scene_changed(kind: String)
signal room_requested
signal battle_requested(worker_id: String)
signal battle_finished(result: String)
signal light_changed(id: String, on: bool)
signal charges_changed

const WORLD := "res://src/overworld/world.tscn"
const TITLE := "res://src/ui/title_screen.tscn"
const NIGHT_END := "res://src/ui/night_end_screen.tscn"
const LAMPS := "res://src/ui/lamps_screen.tscn"
const BOARD := "res://src/ui/help_wanted_board.gd"
const TONIGHT := "tonight_"
const FIRST_ROOM := "bedroom"
const MORNING_ROOM := "bedroom_morning"

enum TimeState { EVENING, NIGHT, MORNING }

var night: int = 1
var flags: Dictionary = {}
var items: Array[String] = []
var hours: int = 0
var tally: Dictionary = {"helper_count": 0, "hustler_count": 0, "finished_count": 0}
var seen: Dictionary = {}
## Evening is the house before 2:00, night is the running clock, morning is after the night ends.
var time_state: TimeState:
	get:
		if night_over:
			return TimeState.MORNING
		return TimeState.NIGHT if NightClock.started else TimeState.EVENING
var room_id: String = FIRST_ROOM
var spawn: String = "default"
var lights: Dictionary = {}
var flashlight: bool = true
var tuning: Dictionary = {}
var ui: Dictionary = {}
var palette: Dictionary = {}
var item_info: Dictionary = {}
var last_forgotten: Dictionary = {}
var tilesets: Dictionary = {}
var in_battle: bool = false
var night_over: bool = false
var busy: bool = false
var overlay_open: bool = false
var last_night_minutes: int = 0
var last_night_reason: String = ""
var rewind_charges: int = 0
var errors: PackedStringArray = []
var playtest_path: String = ""

var _log: FileAccess
var _log_start: int = 0

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _error_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_build_overlays()
	tuning = _dict(load_json("res://data/tuning.json"))
	ui = _dict(load_json("res://data/ui.json"))
	palette = _dict(load_json("res://data/palette.json"))
	tilesets = _dict(_dict(load_json("res://data/tilesets.json")).get("tilesets", {}))
	item_info = _dict(_dict(load_json("res://data/items.json")).get("items", {}))
	rewind_charges = int(tuning.get("rewind_charges", 3))
	_late_ready.call_deferred()


func _late_ready() -> void:
	NightClock.hour_ended.connect(func() -> void: end_night("time"))
	SaveManager.apply_settings()
	Validator.validate_all()


# ------------------------------------------------------------------ data

func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		report(path.get_file(), "", "file not found")
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		report(path.get_file(), "line %d" % j.get_error_line(), j.get_error_message())
		return null
	return j.data


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func report(file: String, field: String, problem: String) -> void:
	var msg := "%s: %s: %s" % [file, field, problem]
	if msg in errors:
		return
	errors.append(msg)
	push_error(msg)
	if _error_label and OS.is_debug_build():
		_error_label.text = "DATA ERRORS (fix the file, then F5)\n" + "\n".join(errors.slice(-8))
		_error_label.visible = true


## One line per event, flushed at once, so a quit or a crash keeps the session.
## Read it with tools/playtest_report.py. Lines: real seconds, clock, room, event, JSON fields.
func playtest(event: String, fields: Dictionary = {}) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute("user://playtest")
		playtest_path = "user://playtest/%s.log" % Time.get_datetime_string_from_system().replace(":", "-")
		_log = FileAccess.open(playtest_path, FileAccess.WRITE)
		_log_start = Time.get_ticks_msec()
		if _log == null:
			return
	_log.store_line("%.1f\t%s\t%s\t%s\t%s" % [(Time.get_ticks_msec() - _log_start) / 1000.0, NightClock.text(), room_id, event, JSON.stringify(fields)])
	_log.flush()


func color(name: String) -> Color:
	for set_name in ["night", "morning"]:
		var p: Dictionary = palette.get(set_name, {})
		if p.has(name):
			return Color.html(str(p[name]))
	return Color.MAGENTA


func text(key: String) -> String:
	return fmt(str(ui.get("text", {}).get(key, key)))


func fmt(s: String) -> String:
	if not "{" in s:
		return s
	var keys: Dictionary = ui.get("keys", {})
	for k in keys:
		s = s.replace("{%s}" % k, str(keys[k]))
	var costs: Dictionary = tuning.get("costs", {})
	for k in costs:
		s = s.replace("{cost_%s}" % k, str(int(costs[k])))
	return s


# ------------------------------------------------------------------ flags and items

func has_flag(name: String) -> bool:
	return flags.has(name)


func set_flag(name: String) -> void:
	if flags.has(name):
		return
	flags[name] = true
	flag_set.emit(name)


func clear_flag(name: String) -> void:
	if flags.erase(name):
		flag_cleared.emit(name)


## if_flag / unless_flag take flag names; if_gone / unless_gone take worker ids.
func cond_ok(d: Dictionary) -> bool:
	for f in _names(d.get("if_flag", [])) + _names(d.get("if_gone", [])).map(func(w: String) -> String: return "gone_" + w):
		if not has_flag(f):
			return false
	for f in _names(d.get("unless_flag", [])) + _names(d.get("unless_gone", [])).map(func(w: String) -> String: return "gone_" + w):
		if has_flag(f):
			return false
	return true


func _names(v: Variant) -> Array:
	if v is Array:
		return v
	return [] if str(v) == "" else [str(v)]


func give_item(item: String) -> void:
	if item != "" and not item in items:
		items.append(item)


func item_name(item: String) -> String:
	return str(item_info.get(item, {}).get("name", item.capitalize()))


func set_light(id: String, on: bool) -> void:
	lights[id] = on
	light_changed.emit(id, on)


## A speaker's name, else the worker file's name, else the id.
func display_name(id: String) -> String:
	var n := str(DialogueRunner.speakers.get(id, {}).get("name", ""))
	var path := "res://data/workers/%s.json" % id
	if n == "" and FileAccess.file_exists(path):
		n = str(_dict(load_json(path)).get("name", ""))
	return n if n != "" else id.capitalize()


func friends() -> Array[String]:
	return _flag_names("friend_")


func enemies() -> Array[String]:
	return _flag_names("enemy_")


func gone() -> Array[String]:
	return _flag_names("gone_")


## Shift Level 1 to 5 from the hours thresholds in tuning.json.
func shift_level() -> int:
	var lv := 0
	for t: Variant in tuning.get("shift_levels", [0]):
		if hours >= int(t):
			lv += 1
	return maxi(1, lv)


func hours_text(n: int) -> String:
	return text("hours_one" if n == 1 else "hours_many").replace("{n}", str(n))


## The tally with the most, ties to the later one: helper, hustler, finished.
func path_name() -> String:
	var best := "none"
	var top := 0
	for k: String in ["helper", "hustler", "finished"]:
		var n := int(tally[k + "_count"])
		if n > 0 and n >= top:
			best = k
			top = n
	return text("path_" + best)


func _flag_names(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for f in flags:
		if str(f).begins_with(prefix):
			out.append(str(f).trim_prefix(prefix))
	return out


# ------------------------------------------------------------------ routing

func start_night(new_game: bool) -> void:
	if new_game:
		night = 1
		flags.clear()
		items.clear()
		seen.clear()
		hours = 0
		for k: String in tally:
			tally[k] = 0
		SaveManager.erase()
		SaveManager.committed = SaveManager.snapshot()
	else:
		SaveManager.load_game()
	for f in flags.keys():
		if str(f).begins_with(TONIGHT):
			flags.erase(f)
	playtest("night_start", {"night": night, "new_game": new_game})
	lights.clear()
	flashlight = true
	night_over = false
	in_battle = false
	busy = true
	overlay_open = false
	rewind_charges = int(tuning.get("rewind_charges", 3))
	charges_changed.emit()
	NightClock.reset()
	DialogueRunner.abort()
	room_id = FIRST_ROOM
	spawn = "default"
	get_tree().paused = false
	_fade.color = Color(color("ink"), 1.0)
	get_tree().change_scene_to_file(WORLD)
	scene_changed.emit("world")


func go_to_room(id: String, spawn_name: String, minutes: int, dialogue: String = "") -> void:
	if night_over or busy:
		return
	busy = true
	NightClock.add(minutes)
	if night_over:
		return
	if dialogue != "":
		await DialogueRunner.run(dialogue)
		if night_over:
			return
	room_id = id
	spawn = spawn_name
	AudioBus.sfx("door")
	room_requested.emit()
	scene_changed.emit("room")


func reload_room() -> void:
	errors.clear()
	_error_label.visible = false
	DialogueRunner.load_all()
	Validator.validate_all()
	room_requested.emit()


func start_battle(worker_id: String) -> String:
	in_battle = true
	battle_requested.emit(worker_id)
	var result: String = await battle_finished
	in_battle = false
	return result


func end_night(reason: String) -> void:
	if night_over:
		return
	night_over = true
	last_night_reason = reason
	last_night_minutes = clampi(NightClock.minute, 0, NightClock.HOUR)
	playtest("night_end", {"reason": reason, "minutes": last_night_minutes})
	NightClock.paused = true
	DialogueRunner.abort()
	get_tree().paused = true
	await fade_to(color("white"), float(tuning.get("white_fade_seconds", 1.5)))
	get_tree().paused = false
	in_battle = false
	busy = true
	overlay_open = false
	last_forgotten = SaveManager.pending()
	SaveManager.revert()
	get_tree().change_scene_to_file(LAMPS)
	scene_changed.emit("lamps")


func go_to_morning() -> void:
	room_id = MORNING_ROOM
	spawn = "default"
	get_tree().change_scene_to_file(WORLD)
	scene_changed.emit("morning")


## The end_night dialogue command. At night it rings 3:00 now; in the morning it shows the summary.
func end_night_command() -> void:
	if night_over:
		get_tree().change_scene_to_file(NIGHT_END)
		scene_changed.emit("night_end")
	else:
		NightClock.set_minute(NightClock.HOUR)


func finish_night() -> void:
	night += 1
	SaveManager.commit()
	go_to_title()


func go_to_title() -> void:
	get_tree().paused = false
	busy = false
	DialogueRunner.abort()
	get_tree().change_scene_to_file(TITLE)
	scene_changed.emit("title")


func open_help_wanted() -> void:
	overlay_open = true
	var board: CanvasLayer = load(BOARD).new()
	get_tree().current_scene.add_child(board)
	await board.tree_exited
	overlay_open = false


# ------------------------------------------------------------------ fades

func fade_to(c: Color, seconds: float) -> void:
	_fade.color = Color(c, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, seconds)
	await tw.finished


func fade_from(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, seconds)
	await tw.finished


func _build_overlays() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade_layer.add_child(_fade)
	_error_label = Label.new()
	_error_label.position = Vector2(2, 2)
	_error_label.size = Vector2(316, 0)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	_error_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_error_label.add_theme_constant_override("outline_size", 2)
	_error_label.visible = false
	_fade_layer.add_child(_error_label)


# ------------------------------------------------------------------ input

func _register_inputs() -> void:
	var map := {
		"move_left": [["key", KEY_LEFT], ["key", KEY_A], ["pad", JOY_BUTTON_DPAD_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0]],
		"move_right": [["key", KEY_RIGHT], ["key", KEY_D], ["pad", JOY_BUTTON_DPAD_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0]],
		"move_up": [["key", KEY_UP], ["key", KEY_W], ["pad", JOY_BUTTON_DPAD_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
		"move_down": [["key", KEY_DOWN], ["key", KEY_S], ["pad", JOY_BUTTON_DPAD_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
		"confirm": [["key", KEY_Z], ["key", KEY_SPACE], ["key", KEY_ENTER], ["pad", JOY_BUTTON_A]],
		"cancel": [["key", KEY_X], ["key", KEY_ESCAPE], ["pad", JOY_BUTTON_B]],
		"rewind": [["key", KEY_R], ["key", KEY_SHIFT], ["pad", JOY_BUTTON_LEFT_SHOULDER]],
		"menu": [["key", KEY_C], ["key", KEY_TAB], ["pad", JOY_BUTTON_Y]],
		"fullscreen": [["key", KEY_F11]],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.4)
		for e: Array in map[action]:
			var ev: InputEvent
			match str(e[0]):
				"key":
					var k := InputEventKey.new()
					k.physical_keycode = e[1]
					ev = k
				"pad":
					var b := InputEventJoypadButton.new()
					b.button_index = e[1]
					b.device = -1
					ev = b
				_:
					var m := InputEventJoypadMotion.new()
					m.axis = e[1]
					m.axis_value = e[2]
					m.device = -1
					ev = m
			InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		SaveManager.settings["fullscreen"] = not bool(SaveManager.settings.get("fullscreen", false))
		SaveManager.apply_settings()
		SaveManager.save_settings()
		return
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			if not NightClock.started:
				NightClock.set_minute(0)
			NightClock.add(10)
		KEY_F2:
			set_flag("has_watch")
		KEY_F3:
			if get_tree().current_scene and get_tree().current_scene.scene_file_path == WORLD and not in_battle and not DialogueRunner.is_active():
				start_battle("curfew")
		KEY_F4:
			for f in FileAccess.get_file_as_string("res://dev/flags.txt").split("\n"):
				var name := f.strip_edges()
				if name == "" or name.begins_with("#"):
					continue
				if has_flag(name):
					clear_flag(name)
				else:
					set_flag(name)
		KEY_F5:
			if get_tree().current_scene and get_tree().current_scene.scene_file_path == WORLD and not in_battle:
				reload_room()
		KEY_F6:
			SaveManager.commit()
			AudioBus.sfx("chime")
