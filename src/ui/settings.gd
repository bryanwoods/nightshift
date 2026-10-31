extends Control
## Music and sfx volume, text speed, window scale, fullscreen. Left and right change a value.

const ROWS: Array[String] = ["music", "sfx", "text_speed", "scale", "fullscreen", "back"]

var _menu: MenuList


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.color("ink")
	bg.size = Vector2(320, 180)
	add_child(bg)
	var title := Label.new()
	title.text = Game.text("settings")
	title.position = Vector2(0, 24)
	title.size = Vector2(320, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Game.color("lamp"))
	add_child(title)
	_menu = MenuList.new()
	_menu.centered = false
	_menu.position = Vector2(90, 50)
	_menu.size = Vector2(160, 80)
	add_child(_menu)
	_menu.chosen.connect(_on_chosen)
	_menu.changed.connect(_on_changed)
	_menu.cancelled.connect(_close)
	_render()


func _render() -> void:
	var s := SaveManager.settings
	var speeds: Array = Game.ui.get("text", {}).get("text_speeds", ["Slow", "Normal", "Fast"])
	var labels: Array[String] = []
	for r in ROWS:
		var v := ""
		match r:
			"music", "sfx":
				v = "%d/10" % int(s.get(r, 8))
			"text_speed":
				v = str(speeds[clampi(int(s.get(r, 1)), 0, speeds.size() - 1)])
			"scale":
				v = "%dx" % int(s.get(r, 4))
			"fullscreen":
				v = Game.text("on") if bool(s.get(r, false)) else Game.text("off")
		labels.append(Game.text("set_" + r) + ("   < %s >" % v if v != "" else ""))
	_menu.set_items(labels)


func _on_changed(i: int, dir: int) -> void:
	var s := SaveManager.settings
	match ROWS[i]:
		"music", "sfx":
			s[ROWS[i]] = clampi(int(s.get(ROWS[i], 8)) + dir, 0, 10)
		"text_speed":
			s["text_speed"] = clampi(int(s.get("text_speed", 1)) + dir, 0, 2)
		"scale":
			s["scale"] = clampi(int(s.get("scale", 4)) + dir, 1, 6)
		"fullscreen":
			s["fullscreen"] = not bool(s.get("fullscreen", false))
		_:
			return
	AudioBus.sfx("cursor")
	SaveManager.apply_settings()
	SaveManager.save_settings()
	_render()


func _on_chosen(i: int) -> void:
	if ROWS[i] == "back":
		_close()
	else:
		_on_changed(i, 1)


func _close() -> void:
	queue_free()
