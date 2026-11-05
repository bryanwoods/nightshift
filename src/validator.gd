class_name Validator
extends RefCounted
## Checks every data file at startup. Each problem is reported as "file: field: problem"
## in the Godot output and on screen in debug builds.

const ROOMS := "res://data/rooms/"
const WORKERS := "res://data/workers/"


static func validate_all() -> void:
	var room_spawns := {}
	var rooms := {}
	for file in DirAccess.get_files_at(ROOMS):
		if not file.ends_with(".json"):
			continue
		var d: Variant = Game.load_json(ROOMS + file)
		if d is Dictionary:
			rooms[file.get_basename()] = d
			room_spawns[file.get_basename()] = (d as Dictionary).get("spawns", {})
	for id: String in rooms:
		_room(id + ".json", id, rooms[id], room_spawns)
	for file in DirAccess.get_files_at(WORKERS):
		if file.ends_with(".json"):
			_worker(file, Game.load_json(WORKERS + file))
	_dialogue()
	var hw: Variant = Game.load_json("res://data/help_wanted.json")
	if hw is Dictionary:
		for i in (hw.get("postings", []) as Array).size():
			var p: Dictionary = hw["postings"][i]
			for f in ["title", "posted_by", "text", "status"]:
				if not p.has(f):
					Game.report("help_wanted.json", "postings[%d].%s" % [i, f], "missing")
			if not str(p.get("status", "")) in ["open", "taken", "done"]:
				Game.report("help_wanted.json", "postings[%d].status" % i, "must be open, taken or done")


static func _room(file: String, id: String, d: Dictionary, spawns: Dictionary) -> void:
	if str(d.get("id", "")) != id:
		Game.report(file, "id", "must be \"%s\" to match the file name" % id)
	var ts := str(d.get("tileset", ""))
	if not Game.tilesets.has(ts):
		Game.report(file, "tileset", "\"%s\" is not in data/tilesets.json" % ts)
		return
	var tile_names: Array = Game.tilesets[ts].get("tiles", [])
	var legend: Dictionary = d.get("legend", {})
	for ch: String in legend:
		if not legend[ch] in tile_names:
			Game.report(file, "legend." + ch, "tile \"%s\" is not in tileset %s" % [legend[ch], ts])
	var layout: Array = d.get("layout", [])
	if layout.is_empty():
		Game.report(file, "layout", "is empty")
		return
	var w := str(layout[0]).length()
	for y in layout.size():
		var row := str(layout[y])
		if row.length() != w:
			Game.report(file, "layout[%d]" % y, "is %d wide, the first row is %d" % [row.length(), w])
		for ch in row:
			if not legend.has(ch):
				Game.report(file, "layout[%d]" % y, "\"%s\" is not in the legend" % ch)
	var size := Vector2i(w, layout.size())
	var sp: Dictionary = d.get("spawns", {})
	if not sp.has("default"):
		Game.report(file, "spawns", "needs a \"default\" spawn")
	for k: String in sp:
		_in_bounds(file, "spawns." + k, sp[k], size)
	var light_ids := (d.get("lights", []) as Array).map(func(l: Dictionary) -> String: return str(l.get("id", "")))
	var ents: Array = d.get("entities", [])
	for i in ents.size():
		var e: Dictionary = ents[i]
		var where := "entities[%d]" % i
		var kind := str(e.get("type", ""))
		if not kind in Entity.KINDS:
			Game.report(file, where + ".type", "\"%s\" must be one of %s" % [kind, ", ".join(Entity.KINDS)])
		_in_bounds(file, where, [e.get("x", -1), e.get("y", -1)], size)
		if kind == "door":
			var to := str(e.get("to", ""))
			if not spawns.has(to):
				Game.report(file, where + ".to", "no room \"%s\"" % to)
			elif not (spawns[to] as Dictionary).has(str(e.get("spawn", "default"))):
				Game.report(file, where + ".spawn", "room %s has no spawn \"%s\"" % [to, e.get("spawn", "default")])
		if kind == "lamp" and str(e.get("id", "")) == "":
			Game.report(file, where + ".id", "a lamp needs an id")
		if e.has("light") and not str(e["light"]) in light_ids:
			Game.report(file, where + ".light", "no light \"%s\" in this room" % e["light"])
		var dlg := str(e.get("dialogue", ""))
		if dlg != "" and not DialogueRunner.has(dlg):
			Game.report(file, where + ".dialogue", "no dialogue \"%s\"" % dlg)
		if kind in ["npc", "inspect", "hold", "trigger"] and dlg == "":
			Game.report(file, where + ".dialogue", "a %s needs a dialogue" % kind)
	for l: Dictionary in d.get("lights", []):
		if not l.has("id"):
			Game.report(file, "lights", "every light needs an id")
	if d.has("on_enter") and not DialogueRunner.has(str(d["on_enter"])):
		Game.report(file, "on_enter", "no dialogue \"%s\"" % d["on_enter"])


static func _in_bounds(file: String, field: String, v: Variant, size: Vector2i) -> void:
	if not v is Array or (v as Array).size() < 2:
		Game.report(file, field, "needs [x, y]")
		return
	var x := int(v[0])
	var y := int(v[1])
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		Game.report(file, field, "[%d, %d] is outside the %dx%d layout" % [x, y, size.x, size.y])


static func _worker(file: String, v: Variant) -> void:
	if not v is Dictionary:
		return
	var d: Dictionary = v
	var id := file.get_basename()
	if str(d.get("id", "")) != id:
		Game.report(file, "id", "must be \"%s\" to match the file name" % id)
	for f in ["name", "job", "sprite", "patience", "hit_damage", "patterns", "task", "dialogue"]:
		if not d.has(f):
			Game.report(file, f, "missing")
	var pats: Array = d.get("patterns", [])
	for i in pats.size():
		var p: Dictionary = pats[i]
		var type := str(p.get("type", ""))
		if not Pattern.exists(type):
			Game.report(file, "patterns[%d].type" % i, "no pattern \"%s\"" % type)
		if type == "dark" and not Pattern.exists(str(p.get("inner", {}).get("type", ""))):
			Game.report(file, "patterns[%d].inner.type" % i, "dark needs an inner pattern")
	for list_key in ["turn_lines", "flavor"]:
		for ref: Variant in d.get(list_key, []):
			if not DialogueRunner.has(str(ref)):
				Game.report(file, list_key, "no dialogue \"%s\"" % ref)
	var dlg: Dictionary = d.get("dialogue", {})
	for k: String in dlg:
		if not DialogueRunner.has(str(dlg[k])):
			Game.report(file, "dialogue." + k, "no dialogue \"%s\"" % dlg[k])
	var steps: Array = d.get("task", {}).get("steps", [])
	for i in steps.size():
		var s: Dictionary = steps[i]
		if s.has("bubble") and not DialogueRunner.has(str(s["bubble"])):
			Game.report(file, "task.steps[%d].bubble" % i, "no dialogue \"%s\"" % s["bubble"])
		if not DialogueRunner.has(str(s.get("line", ""))):
			Game.report(file, "task.steps[%d].line" % i, "no dialogue \"%s\"" % s.get("line", ""))
		if s.has("choice"):
			var c: Dictionary = s["choice"]
			if int(c.get("correct", -1)) < 0 or int(c.get("correct", -1)) >= (c.get("options", []) as Array).size():
				Game.report(file, "task.steps[%d].choice.correct" % i, "must point at one of the options (counting from 0)")
			_drawable(file, "task.steps[%d].choice" % i, str(c.get("prompt", "")) + "".join(c.get("options", [])))
			if c.has("wrong_line") and not DialogueRunner.has(str(c["wrong_line"])):
				Game.report(file, "task.steps[%d].choice.wrong_line" % i, "no dialogue \"%s\"" % c["wrong_line"])


static func _dialogue() -> void:
	var runner := DialogueRunner
	for id: String in runner.dialogues:
		var file := str(runner.sources[id])
		var lines: Array = runner.dialogues[id]["lines"]
		if runner.dialogues[id].has("seen_variant") and not runner.has(str(runner.dialogues[id]["seen_variant"])):
			Game.report(file, id + ".seen_variant", "no dialogue \"%s\"" % runner.dialogues[id]["seen_variant"])
		for i in lines.size():
			var line: Dictionary = lines[i]
			var where := "%s.lines[%d]" % [id, i]
			if line.has("speaker") and not runner.speakers.has(str(line["speaker"])):
				Game.report(file, where + ".speaker", "\"%s\" is not in _speakers.json" % line["speaker"])
			if line.has("cmd"):
				var cmd := str(line["cmd"])
				if not cmd in runner.COMMANDS:
					Game.report(file, where + ".cmd", "unknown command \"%s\"" % cmd)
				for key in ["goto", "else"]:
					var target := str(line.get(key, ""))
					if target != "" and not runner.has(target):
						Game.report(file, where + "." + key, "no dialogue \"%s\"" % target)
				if cmd == "battle" and not FileAccess.file_exists(WORKERS + str(line.get("worker", "")) + ".json"):
					Game.report(file, where + ".worker", "no worker file \"%s\"" % line.get("worker", ""))
			elif not line.has("text"):
				Game.report(file, where, "needs \"text\" or \"cmd\"")
			_drawable(file, where + ".text", str(line.get("text", "")))
			for c: Dictionary in line.get("choices", []):
				_drawable(file, where + ".choices", str(c.get("text", "")))
				var target := str(c.get("goto", ""))
				if target != "" and not runner.has(target):
					Game.report(file, where + ".choices", "no dialogue \"%s\"" % target)


## A character the font has no glyph for shows as a box. Report it so the writer can swap it.
static func _drawable(file: String, field: String, text: String) -> void:
	var font := ThemeDB.get_project_theme().default_font
	for ch in text:
		if not font.has_char(ch.unicode_at(0)):
			Game.report(file, field, "the font cannot draw \"%s\", use a plain character" % ch)
			return
