extends Node
## Loads data/dialogue/*.json and runs lines, choices and commands. Owns the textbox.
##
## A choice with "goto" runs that dialogue and then comes back. The goto and
## if_flag commands jump: the current dialogue stops after the target ends.

signal dialogue_started(id: String)
signal dialogue_ended(id: String)
signal room_command(cmd: Dictionary)

const DIR := "res://data/dialogue/"
const COMMANDS: PackedStringArray = [
	"set_flag", "clear_flag", "if_flag", "goto", "clock_add", "clock_set", "battle", "give_item",
	"light", "move", "face", "shake", "wait", "music", "sfx", "end_night", "help_wanted", "save",
]

var dialogues: Dictionary = {}
var sources: Dictionary = {}
var speakers: Dictionary = {}
var textbox: Textbox
var depth: int = 0
var last_end_msec: int = 0
## Tests set this: lines advance by themselves and choices take the first option.
var autoplay: bool = false
## With autoplay, what a fight picks each turn: "help" or "hustle".
var autoplay_fight: String = "help"

var _gen: int = 0


func _ready() -> void:
	textbox = Textbox.new()
	add_child(textbox)
	load_all()


func load_all() -> void:
	dialogues.clear()
	sources.clear()
	var sp: Variant = Game.load_json(DIR + "_speakers.json")
	speakers = sp.get("speakers", {}) if sp is Dictionary else {}
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".json") or file.begins_with("_"):
			continue
		var d: Variant = Game.load_json(DIR + file)
		if not d is Dictionary:
			continue
		var fid := file.get_basename()
		if str(d.get("id", "")) != fid:
			Game.report(file, "id", "must be \"%s\" to match the file name" % fid)
		if d.has("lines"):
			_add(file, fid, d)
		var bundle: Dictionary = d.get("dialogues", {})
		for key: String in bundle:
			_add(file, key, bundle[key])


func _add(file: String, id: String, d: Variant) -> void:
	if dialogues.has(id):
		Game.report(file, id, "this dialogue id is already used in " + str(sources[id]))
	if not d is Dictionary or not d.get("lines") is Array:
		Game.report(file, id, "needs a \"lines\" list")
		return
	dialogues[id] = d
	sources[id] = file


func has(id: String) -> bool:
	return dialogues.has(id)


func is_active() -> bool:
	return depth > 0


## True while a line is on screen. A battle started from a dialogue keeps is_active() true.
func showing() -> bool:
	return textbox.visible


func just_ended() -> bool:
	return Time.get_ticks_msec() - last_end_msec < 150


func abort() -> void:
	_gen += 1
	if depth > 0:
		last_end_msec = Time.get_ticks_msec()
	depth = 0
	textbox.close()


func run(id: String) -> void:
	if id == "":
		return
	var gen := _gen
	if not dialogues.has(id):
		Game.report("dialogue", id, "no dialogue has this id")
		return
	id = _resolve(id)
	var d: Dictionary = dialogues[id]
	Game.seen[id] = true
	Game.playtest("dialogue", {"id": id})
	depth += 1
	dialogue_started.emit(id)
	await _run_lines(d["lines"], gen)
	if gen != _gen:
		return
	depth -= 1
	textbox.hide_box()
	last_end_msec = Time.get_ticks_msec()
	dialogue_ended.emit(id)


func _run_lines(lines: Array, gen: int) -> void:
	for line: Dictionary in lines:
		if gen != _gen:
			return
		if not Game.cond_ok(line):
			continue
		if line.has("cmd"):
			var stop: bool = await _command(line)
			if stop:
				return
			continue
		var choices: Array = (line.get("choices", []) as Array).filter(func(c: Dictionary) -> bool: return Game.cond_ok(c))
		var labels: Array[String] = []
		for c: Dictionary in choices:
			labels.append(Game.fmt(str(c.get("text", ""))))
		var pick: int = await _show(line, labels)
		if gen != _gen:
			return
		if pick >= 0 and pick < labels.size():
			Game.playtest("choice", {"text": labels[pick]})
		if pick >= 0 and pick < choices.size():
			await run(str(choices[pick].get("goto", "")))


func _show(line: Dictionary, options: Array[String]) -> int:
	var speaker := str(line.get("speaker", "narrator"))
	var sp: Dictionary = speakers.get(speaker, {})
	var dark := bool(line.get("dark", false))
	var text := Game.fmt(str(line.get("text", "")))
	return await textbox.show_line(
		str(sp.get("name", "")),
		_portrait(speaker, str(line.get("portrait", ""))),
		_uneven(text) if dark else text,
		float(sp.get("pitch", 1.0)),
		options,
		float(line.get("auto", -1.0)),
		Game.color("hush" if dark else "moon"),
	)


static func _uneven(text: String) -> String:
	var out := ""
	var up := true
	for ch in text:
		if ch.to_upper() != ch.to_lower():
			out += ch.to_upper() if up else ch.to_lower()
			up = not up
		else:
			out += ch
	return out


func _portrait(speaker: String, name: String) -> Texture2D:
	for p in [name, speaker + "_neutral"]:
		var path := "res://assets/portraits/%s.png" % p
		if p != "" and ResourceLoader.exists(path):
			return load(path)
	return null


## Returns true when the current dialogue must stop (a jump or the end of the night).
func _command(line: Dictionary) -> bool:
	var gen := _gen
	match str(line["cmd"]):
		"set_flag":
			Game.set_flag(str(line.get("flag", "")))
		"clear_flag":
			Game.clear_flag(str(line.get("flag", "")))
		"if_flag":
			if Game.has_flag(str(line.get("flag", ""))):
				await run(str(line.get("goto", "")))
				return true
			if line.has("else"):
				await run(str(line["else"]))
				return true
		"goto":
			await run(str(line.get("goto", "")))
			return true
		"clock_add":
			NightClock.add(int(line.get("minutes", 0)))
		"clock_set":
			NightClock.set_minute(int(line.get("minute", 0)))
		"battle":
			textbox.hide_box()
			await Game.start_battle(str(line.get("worker", "")))
		"give_item":
			Game.give_item(str(line.get("item", "")))
		"light":
			Game.set_light(str(line.get("id", "")), bool(line.get("on", true)))
		"move":
			textbox.hide_box()
			room_command.emit(line)
			var tiles := absf(float(line.get("dx", 0))) + absf(float(line.get("dy", 0)))
			var speed := float(line.get("speed", Game.tuning.get("move_speed", 40)))
			await get_tree().create_timer(tiles * 16.0 / speed + 0.05, false).timeout
		"face", "shake":
			room_command.emit(line)
		"wait":
			textbox.hide_box()
			await get_tree().create_timer(float(line.get("seconds", 0.5)), false).timeout
		"music":
			AudioBus.play_music(str(line.get("track", "")))
		"sfx":
			AudioBus.sfx(str(line.get("name", "")), float(line.get("pitch", 1.0)))
		"end_night":
			Game.end_night_command()
			return true
		"help_wanted":
			textbox.hide_box()
			await Game.open_help_wanted()
		"save":
			SaveManager.commit()
	return gen != _gen


## A one-off question with options that are not in a dialogue file (worker task choices).
func ask(speaker: String, text: String, options: Array[String]) -> int:
	var gen := _gen
	depth += 1
	var pick: int = await _show({"speaker": speaker, "text": text}, options)
	if gen != _gen:
		return -1
	if pick >= 0 and pick < options.size():
		Game.playtest("choice", {"text": options[pick], "prompt": text})
	depth -= 1
	textbox.hide_box()
	last_end_msec = Time.get_ticks_msec()
	return pick


## Follows seen_variant links: a dialogue already seen plays its variant instead.
func _resolve(id: String) -> String:
	for _i in 8:
		var variant := str(dialogues[id].get("seen_variant", ""))
		if not Game.seen.has(id) or not dialogues.has(variant):
			break
		id = variant
	return id


## The first text line of a dialogue, for speech bubbles and flavor text. Marks it seen.
func first_line(id: String) -> Dictionary:
	if not dialogues.has(id):
		return {}
	id = _resolve(id)
	Game.seen[id] = true
	for line: Dictionary in dialogues[id]["lines"]:
		if line.has("text") and Game.cond_ok(line):
			return {"speaker": line.get("speaker", ""), "text": Game.fmt(str(line["text"]))}
	return {}
